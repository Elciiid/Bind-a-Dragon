--!strict
-- Potions and timed boosts (numbers in Config/Boosts).
--
-- UseBoost(potionId): a timed potion is used up and adds its duration to that potion's timer (data.ActiveBoosts);
-- a luck charge is armed/disarmed for the next bind (data.ArmedLuckPotion; BindingService uses it up).
-- Timers tick once per second while the player is in the game, so they pause offline.
-- Other services ask GetMultiplier(player, stat) (Roost gold, trait/grade roll luck, later the Spire) and
-- GrantPotion to hand potions out (Spire, quests, Index).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local useBoost = ReplicatedStorage.Remotes.UseBoost :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local TICK_SECONDS = 1

local lastUse: { [Player]: number } = {}

local BoostService = {}

local function getDuration(player: Player, potion: Boosts.Potion): number
	local seconds = (potion.Minutes or 0) * 60
	if player.MembershipType == Enum.MembershipType.Premium then
		seconds *= 1 + Boosts.PremiumDurationBonus
	end
	return math.floor(seconds)
end

local function onUseBoost(player: Player, potionId: unknown)
	if typeof(potionId) ~= "string" or #potionId > 40 then
		return
	end
	local now = os.clock()
	if now - (lastUse[player] or 0) < Boosts.UseCooldown then
		return
	end
	lastUse[player] = now

	local data = DataService:GetData(player)
	local potion = Boosts.ById[potionId]
	if data == nil or potion == nil then
		return
	end

	if potion.Kind == "LuckCharge" then
		if data.ArmedLuckPotion == potion.Id then
			data.ArmedLuckPotion = ""
			notify:FireClient(player, `{potion.Name} disarmed.`, "info")
		elseif (data.Potions[potion.Id] or 0) > 0 then
			data.ArmedLuckPotion = potion.Id
			notify:FireClient(player, `{potion.Name} armed: {potion.Description}.`, "success")
		else
			notify:FireClient(player, `You don't have a {potion.Name}.`, "error")
		end
		return
	end

	local count = data.Potions[potion.Id] or 0
	if count <= 0 then
		notify:FireClient(player, `You don't have a {potion.Name}.`, "error")
		return
	end
	local left = data.ActiveBoosts[potion.Id] or 0
	local added = getDuration(player, potion)
	if left + added > Boosts.MaxStoredMinutes * 60 then
		notify:FireClient(player, `{potion.Name} can store at most {Boosts.MaxStoredMinutes} minutes.`, "error")
		return
	end
	data.Potions[potion.Id] = if count > 1 then count - 1 else nil
	data.ActiveBoosts[potion.Id] = left + added
	notify:FireClient(player, `{potion.Name}: {potion.Description} for {math.ceil((left + added) / 60)} min.`, "success")
end

-- Product of all active timed boosts on this stat (1 if none).
function BoostService:GetMultiplier(player: Player, stat: string): number
	local data = DataService:GetData(player)
	return if data then DragonStats.GetBoostMultiplier(data, stat) else 1
end

function BoostService:GrantPotion(player: Player, potionId: string, count: number)
	local data = DataService:GetData(player)
	if data == nil or Boosts.ById[potionId] == nil or count <= 0 then
		return
	end
	data.Potions[potionId] = (data.Potions[potionId] or 0) + count
end

-- Called by BindingService after a bind: uses up the armed luck charge. Returns its multiplier (1 if none).
function BoostService:ConsumeLuckCharge(data: PlayerDataTypes.PlayerData): number
	local potion = Boosts.ById[data.ArmedLuckPotion]
	data.ArmedLuckPotion = ""
	if potion == nil or potion.Kind ~= "LuckCharge" then
		return 1
	end
	local count = data.Potions[potion.Id] or 0
	if count <= 0 then
		return 1
	end
	data.Potions[potion.Id] = if count > 1 then count - 1 else nil
	return potion.Multiplier
end

function BoostService:Start()
	useBoost.OnServerEvent:Connect(onUseBoost)
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)

	while true do
		task.wait(TICK_SECONDS)
		for _, player in Players:GetPlayers() do
			local data = DataService:GetData(player)
			if data == nil then
				continue
			end
			for potionId, seconds in data.ActiveBoosts do
				local left = seconds - TICK_SECONDS
				data.ActiveBoosts[potionId] = if left > 0 then left else nil
			end
		end
	end
end

return BoostService
