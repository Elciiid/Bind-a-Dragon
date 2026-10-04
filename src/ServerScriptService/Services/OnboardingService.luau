--!strict
-- Saved tutorial progress and the welcome bind (first-time flow, Config/Onboarding). Clients can only opt out, never
-- advance or grant.
--
-- Every brand-new player (no dragons, no rebirth, never bound) starts at Steps.Start: their first bind at the Valley altar
-- is a WELCOME BIND that always hatches the Common starter dragon (Config/Data.StarterDragon), by day or night, without an
-- Echo Sigil, armed potion or offerings, and without using up the night's normal bind (BindingService). The starter is
-- no longer granted at join: it comes from this bind. Skip grants it at once so nobody is left without a dragon; a player
-- who leaves before the welcome bind gets the same step again on rejoin. Saves that already have a dragon, a rebirth or a
-- bind are classified Skipped and never get a welcome bind. Steps after it: Home (reach your sanctuary) -> Upgrade (one
-- free manual level) -> Night (the next night lets you bind normally) -> Complete.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)
local RoostService = require(script.Parent.RoostService)
local Config = require(ReplicatedStorage.Shared.Config.Onboarding)
local DataConfig = require(ReplicatedStorage.Shared.Config.Data)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Types = require(ReplicatedStorage.Shared.Types.PlayerData)
local skip = ReplicatedStorage.Remotes.SkipTutorial :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent
local lastRequest: { [Player]: number } = {}
local afterBindNight: { [Player]: number } = {}
local OnboardingService = {}

local function hasDragons(data: Types.PlayerData): boolean
	return next(data.Dragons) ~= nil
end

local function starterSpecies(): string?
	local speciesId = DataConfig.StarterDragon
	return if speciesId and Dragons[speciesId] then speciesId else nil
end

-- Classifies an unclassified save once: brand-new -> Start, anything with progress -> Skipped (never touched again).
function OnboardingService:Ensure(data: Types.PlayerData)
	if data.OnboardingStep ~= 0 then return end
	if data.Rebirths > 0 or hasDragons(data) or data.LastBindNight >= 0 or starterSpecies() == nil then
		data.OnboardingStep = Config.Steps.Skipped
		data.OnboardingFirstBindUsed = true
		data.OnboardingFreeLevelUsed = true
	else
		data.OnboardingStep = Config.Steps.Start
	end
end

-- The welcome bind is open to a player at Steps.Start with no dragon yet, at the starter area's altar.
function OnboardingService:CanWelcomeBind(data: Types.PlayerData, areaId: string): boolean
	self:Ensure(data)
	return data.OnboardingStep == Config.Steps.Start and not data.OnboardingFirstBindUsed and not hasDragons(data)
		and data.Rebirths == 0 and areaId == Config.StarterArea and starterSpecies() ~= nil
end

-- Adds the starter dragon (Config/Data.StarterDragon) to the roost and the Index. Marked Starter = true so the Rarest
-- leaderboard never counts it. Returns the dragon id (nil if no starter is configured).
function OnboardingService:GrantStarter(player: Player, data: Types.PlayerData): string?
	local speciesId = starterSpecies()
	if speciesId == nil then return nil end
	local dragonId = tostring(data.NextDragonId)
	data.NextDragonId += 1
	data.Dragons[dragonId] = { Id = dragonId, SpeciesId = speciesId, Level = 1, ObtainedAt = os.time(), Starter = true }
	table.insert(data.RoostDragonIds, dragonId)
	IndexService:Sync(player, data)
	return dragonId
end

-- The welcome bind happened (BindingService): the starter is granted, the tutorial moves to Home.
function OnboardingService:DidWelcomeBind(player: Player, data: Types.PlayerData, bindState: Cycle.State?): string?
	if data.OnboardingFirstBindUsed then return nil end
	data.OnboardingFirstBindUsed = true
	data.OnboardingStep = Config.Steps.Home
	local state = bindState or Cycle.GetState()
	-- The welcome bind never uses up a night, so the Night step waits for the next night that starts after it: by day
	-- NightIndex is the upcoming night (eligible), at night it is the current one (already started, so the next).
	afterBindNight[player] = state.NightIndex - (if state.IsNight then 0 else 1)
	return self:GrantStarter(player, data)
end

-- Called only from a manual, ownership/cap-validated request; never Auto-Upgrade.
function OnboardingService:UseFreeLevel(data: Types.PlayerData): boolean
	self:Ensure(data)
	if data.OnboardingStep ~= Config.Steps.Upgrade or data.OnboardingFreeLevelUsed then return false end
	data.OnboardingFreeLevelUsed = true
	data.OnboardingStep = Config.Steps.Night
	return true
end

-- Skip: no further tutorial; a player who has not had the welcome bind gets the starter right away.
function OnboardingService:Skip(player: Player, data: Types.PlayerData)
	self:Ensure(data)
	if data.OnboardingStep == Config.Steps.Skipped or data.OnboardingStep == Config.Steps.Complete then return end
	local grant = not data.OnboardingFirstBindUsed and not hasDragons(data)
	data.OnboardingStep = Config.Steps.Skipped
	data.OnboardingFirstBindUsed = true
	data.OnboardingFreeLevelUsed = true
	if grant then
		local dragonId = self:GrantStarter(player, data)
		local speciesId = if dragonId then data.Dragons[dragonId].SpeciesId else nil
		if speciesId then
			notify:FireClient(player, Text.Format(Text.Onboarding.StarterHatched, { name = Dragons[speciesId].Name }), "moment", {
				Moment = "NewDragon", SpeciesId = speciesId, Level = 1, Welcome = true,
			})
		end
	end
end

local function hint(player: Player, data: Types.PlayerData, key: string)
	if data.OnboardingHints[key] then return end
	data.OnboardingHints[key] = true
	-- RevealGate defers notifications until the new dragon has actually been revealed.
	notify:FireClient(player, Text.Onboarding[key], "info")
end

function OnboardingService:Start()
	DataService:OnDataLoaded(function(player, data)
		self:Ensure(data)
		if data.OnboardingStep > Config.Steps.Start and data.OnboardingStep < Config.Steps.Complete then
			local state = Cycle.GetState()
			afterBindNight[player] = if data.LastBindNight >= 0 then data.LastBindNight else state.NightIndex - 1
		end
	end)
	skip.OnServerEvent:Connect(function(player, value: unknown)
		if value ~= true then return end
		local now = os.clock()
		if now - (lastRequest[player] or -math.huge) < Config.RequestInterval then return end
		lastRequest[player] = now
		local data = DataService:GetData(player)
		if data == nil then return end
		self:Skip(player, data)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player], afterBindNight[player] = nil, nil
	end)
	while true do
		local state = Cycle.GetState()
		for _, player in Players:GetPlayers() do
			local data = DataService:GetData(player)
			if data == nil then continue end
			self:Ensure(data)
			if data.OnboardingStep <= 0 then continue end
			if data.OnboardingStep == Config.Steps.Start and hasDragons(data) and not data.OnboardingFirstBindUsed then
				-- got a dragon some other way first (e.g. a test save from the old flow): no welcome bind, go on
				data.OnboardingFirstBindUsed = true
				data.OnboardingStep = Config.Steps.Home
				afterBindNight[player] = state.NightIndex - (if state.IsNight then 0 else 1)
			elseif data.OnboardingStep == Config.Steps.Home then
				local plot = RoostService:GetPlot(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if plot and root and root:IsA("BasePart")
					and (root.Position - plot:GetPivot().Position).Magnitude <= Config.HomeArrivalRange then
					data.OnboardingStep = Config.Steps.Upgrade
				end
			elseif data.OnboardingStep == Config.Steps.Night and state.IsNight
				and data.LastBindNight ~= state.NightIndex
				and state.NightIndex > (afterBindNight[player] or state.NightIndex - 1) then
				data.OnboardingStep = Config.Steps.Complete
				hint(player, data, "Night")
			end
			if data.OnboardingStep >= Config.Steps.Night then hint(player, data, "Quests") end
			if data.Gold >= DragonStats.GetRebirthCost(data.Rebirths) * Config.RebirthHintFraction then
				hint(player, data, "Rebirth")
			end
			for _, dragon in data.Dragons do
				if dragon.Level >= Config.SpireHintLevel then hint(player, data, "Spire"); break end
			end
		end
		task.wait(Config.PollSeconds)
	end
end

return OnboardingService
