--!strict
-- Dragon leveling and evolution. The client asks to level a dragon (LevelUpDragon: dragonId, count);
-- the server checks ownership, the level cap and gold, and buys as many of the requested levels as it can afford.
-- Crossing a stage's MinLevel evolves the dragon; the constellation in the sky at that moment is recorded
-- as that stage's branch in dragon.Evolutions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Evolution = require(ReplicatedStorage.Shared.Config.Evolution)
local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)

local levelUpDragon = ReplicatedStorage.Remotes.LevelUpDragon :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local MIN_REQUEST_INTERVAL = 0.1 -- seconds between level-up requests per player (anti-spam)
local MAX_ID_LENGTH = 20

local lastRequest: { [Player]: number } = {}

local DragonService = {}

local function onLevelUp(player: Player, dragonId: unknown, count: unknown)
	-- Validate the request shape before touching any data.
	if typeof(dragonId) ~= "string" or #dragonId > MAX_ID_LENGTH then
		return
	end
	local wanted = 1
	if typeof(count) == "number" and count == count then -- count == count rejects NaN
		wanted = math.clamp(math.floor(count), 1, Leveling.MaxLevelsPerRequest)
	end

	local now = os.clock()
	if now - (lastRequest[player] or 0) < MIN_REQUEST_INTERVAL then
		return
	end
	lastRequest[player] = now

	local data = DataService:GetData(player)
	local dragon = data and data.Dragons[dragonId]
	if data == nil or dragon == nil then
		return
	end

	local cap = DragonStats.GetLevelCap(data)
	if dragon.Level >= cap then
		notify:FireClient(player, `Level cap reached ({cap}). Rebirth to raise it!`, "error")
		return
	end

	local species = Dragons[dragon.SpeciesId]
	local leveled = 0
	while leveled < wanted and dragon.Level < cap do
		local cost = DragonStats.GetLevelUpCost(dragon)
		if data.Gold < cost then
			break
		end
		local stageBefore = DragonStats.GetStage(dragon.Level)
		data.Gold -= cost
		dragon.Level += 1
		leveled += 1

		local stageAfter = DragonStats.GetStage(dragon.Level)
		if stageAfter.Id ~= stageBefore.Id then
			-- The constellation in the sky becomes this stage's branch; during the day there is none.
			local state = Cycle.GetState()
			local evolutions = dragon.Evolutions or {}
			evolutions[stageAfter.Id] = if state.IsNight then state.Constellation.Id else Evolution.DayBranchId
			dragon.Evolutions = evolutions
			local name = if species then species.Name else "Your dragon"
			local under = if state.IsNight then ` under {state.Constellation.Name}` else " in daylight (no branch bonus)"
			notify:FireClient(player, `{name} evolved into a {stageAfter.Name}{under}!`, "success")
		end
	end

	if leveled == 0 then
		local cost = DragonStats.GetLevelUpCost(dragon)
		notify:FireClient(player, `Not enough gold. You need {Format.Number(cost)}.`, "error")
	end
end

function DragonService:Start()
	levelUpDragon.OnServerEvent:Connect(onLevelUp)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return DragonService
