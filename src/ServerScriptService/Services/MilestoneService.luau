--!strict
-- Rebirth Milestone Ladder (Config/RebirthMilestones, Shared/RebirthMilestones). Server side:
--   * celebrates every milestone once (data.MilestonesSeen): a reward pop-up ("moment" Notify) and its grants (the
--     champion dragon at R30). Runs on each rebirth (RebirthService) and when data loads, so a milestone added by a
--     weekly update pops up for players who already qualify;
--   * sets the player attribute "Ascended" (the gold altar glow others see, AltarGlowController);
--   * Auto-Upgrade (R12): SetAutoUpgrade(boolean) switches data.AutoUpgrade; while on, every Interval seconds the
--     server buys roost-dragon levels (best income per gold, with the stage jumps in view) using only gold above
--     Reserve x the next rebirth cost. Everything is checked here; the client only asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local DragonService = require(script.Parent.DragonService)
local IndexService = require(script.Parent.IndexService)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local RebirthMilestones = require(ReplicatedStorage.Shared.RebirthMilestones)
local Evolution = require(ReplicatedStorage.Shared.Config.Evolution)
local Config = require(ReplicatedStorage.Shared.Config.RebirthMilestones)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

type PlayerData = PlayerDataTypes.PlayerData

local setAutoUpgrade = ReplicatedStorage.Remotes.SetAutoUpgrade :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local POPUP_DELAY = 3 -- seconds after the data loads before milestone pop-ups (so the client is ready)

local lastToggle: { [Player]: number } = {}

local MilestoneService = {}

local function refreshAttributes(player: Player, data: PlayerData)
	player:SetAttribute("Ascended", RebirthMilestones.GetAscendedLuck(data.Rebirths) > 1)
end

-- The champion dragon (placeholder art): once per player, placed in the roost when a slot is free.
local function grantChampion(player: Player, data: PlayerData)
	for _, dragon in data.Dragons do
		if dragon.Champion then
			return
		end
	end
	local id = tostring(data.NextDragonId)
	data.NextDragonId += 1
	data.Dragons[id] = {
		Id = id,
		SpeciesId = Config.Champion.SpeciesId,
		Level = 1,
		ObtainedAt = os.time(),
		Champion = true,
	}
	if #data.RoostDragonIds < DragonStats.GetRoostSlots(data) then
		table.insert(data.RoostDragonIds, id)
	end
	IndexService:Sync(player, data)
end

-- Celebrates every reached milestone not celebrated yet.
function MilestoneService:Check(player: Player, data: PlayerData)
	refreshAttributes(player, data)
	for _, milestone in RebirthMilestones.All do
		if data.Rebirths >= milestone.Rebirths and not data.MilestonesSeen[milestone.Id] then
			data.MilestonesSeen[milestone.Id] = true
			if milestone.Perks.Champion then
				grantChampion(player, data)
			end
			local name = RebirthMilestones.NameOf(milestone)
			notify:FireClient(player, `{Text.Milestones.PopupTitle} {name}`, "moment", {
				Moment = "Milestone",
				Id = milestone.Id,
				Name = name,
				Info = RebirthMilestones.InfoOf(milestone),
				Rebirths = milestone.Rebirths,
				Champion = milestone.Perks.Champion == true,
			})
		end
	end
end

-- Called by RebirthService right after a rebirth (and by the Studio dev tools).
function MilestoneService:OnRebirth(player: Player, data: PlayerData)
	self:Check(player, data)
end

---------------------------------------------------------------------------------------------------------------
-- Auto-Upgrade

-- The best purchase for the spare gold: (dragon, levels) or nil. Options per roost dragon: the next level, the levels
-- to its next evolution stage, and the levels to the cap; the best income gain per gold wins, and nothing is bought
-- while the winner is unaffordable (it saves up for it, like a player would).
local function chooseUpgrade(data: PlayerData, spare: number): (PlayerDataTypes.Dragon?, number)
	local cap = DragonStats.GetLevelCap(data)
	local bestDragon: PlayerDataTypes.Dragon? = nil
	local bestLevels, bestRatio, bestCost = 0, 0, 0
	for _, dragonId in data.RoostDragonIds do
		local dragon = data.Dragons[dragonId]
		if dragon and dragon.Level < cap then
			local unit = DragonStats.GetLevelUpCost(dragon, data.Rebirths)
			local before = DragonStats.GetGoldPerSecond(dragon)
			local options = { 1, cap - dragon.Level }
			for _, stage in Evolution.Stages do
				if stage.MinLevel > dragon.Level and stage.MinLevel <= cap then
					table.insert(options, stage.MinLevel - dragon.Level)
					break
				end
			end
			for _, levels in options do
				local probe = table.clone(dragon)
				probe.Level = dragon.Level + levels
				local ratio = (DragonStats.GetGoldPerSecond(probe) - before) / (unit * levels)
				if ratio > bestRatio then
					bestDragon, bestLevels, bestRatio, bestCost = dragon, levels, ratio, unit * levels
				end
			end
		end
	end
	if bestDragon == nil or bestCost > spare then
		return nil, 0
	end
	return bestDragon, bestLevels
end

local function autoUpgradeTick(player: Player)
	local data = DataService:GetData(player)
	if data == nil or not data.AutoUpgrade or not RebirthMilestones.Has(data.Rebirths, "AutoUpgrade") then
		return
	end
	local reserve = Config.AutoUpgrade.Reserve * DragonStats.GetRebirthCost(data.Rebirths)
	local spare = data.Gold - reserve
	if spare <= 0 then
		return
	end
	local dragon, levels = chooseUpgrade(data, spare)
	if dragon then
		DragonService:BuyLevels(player, data, dragon, math.min(levels, Config.AutoUpgrade.MaxLevelsPerTick), true)
	end
end

local function onSetAutoUpgrade(player: Player, value: unknown)
	if typeof(value) ~= "boolean" then
		return
	end
	local now = os.clock()
	if now - (lastToggle[player] or 0) < Config.AutoUpgrade.ToggleCooldown then
		return
	end
	lastToggle[player] = now
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	if not RebirthMilestones.Has(data.Rebirths, "AutoUpgrade") then
		notify:FireClient(player, "Auto-Upgrade unlocks with a rebirth milestone.", "error")
		return
	end
	data.AutoUpgrade = value
end

function MilestoneService:Start()
	setAutoUpgrade.OnServerEvent:Connect(onSetAutoUpgrade)
	Players.PlayerRemoving:Connect(function(player)
		lastToggle[player] = nil
	end)
	DataService:OnDataLoaded(function(player, data)
		refreshAttributes(player, data)
		task.delay(POPUP_DELAY, function()
			if player.Parent == Players then
				self:Check(player, data)
			end
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AutoUpgrade.Interval)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(autoUpgradeTick, player)
				if not ok then
					warn(`[MilestoneService] Auto-Upgrade failed for {player.Name}: {err}`)
				end
			end
		end
	end)
end

return MilestoneService
