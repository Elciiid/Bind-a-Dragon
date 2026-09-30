--!strict
-- Studio-only test hooks (does nothing in a live server). Creates ServerStorage.DevTools.GiveDragons, a
-- BindableFunction that Studio tools (command bar, the MCP) can invoke on the server during Play:
--   GiveDragons:Invoke(player, { "Solflare", "Borealis" }, level, placeInRoost?)
-- adds one dragon per species id at that level (capped at the player's level cap) and, with placeInRoost, puts the
-- new dragons first in the roost (the roost redraws on the next payout). Returns the new dragon ids.
--   SetRoostSlots:Invoke(player, slots) sets the roost slot upgrades so the roost has that many slots (max MaxSlots).
-- A BindableFunction in ServerStorage can't be reached by clients; it is never created outside Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local BindingOdds = require(ReplicatedStorage.Shared.BindingOdds)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local RoostConfig = require(ReplicatedStorage.Shared.Config.Roost)

local DevService = {}

local function giveDragons(player: Player, speciesIds: { string }, level: number, placeInRoost: boolean?, mutationId: string?): { string }
	assert(typeof(player) == "Instance" and player:IsA("Player"), "GiveDragons: player expected")
	local data = DataService:GetData(player)
	assert(data, "GiveDragons: player data not loaded yet")
	local cap = DragonStats.GetLevelCap(data)
	local ids = {}
	local mutation = Mutations.Get(mutationId)
	assert(mutationId == nil or Mutations.ById[mutationId] ~= nil, `GiveDragons: unknown mutation {mutationId}`)
	for _, speciesId in speciesIds do
		assert(Dragons[speciesId], `GiveDragons: unknown species {speciesId}`)
		local dragonId = tostring(data.NextDragonId)
		data.NextDragonId += 1
		data.Dragons[dragonId] = {
			Id = dragonId,
			SpeciesId = speciesId,
			Level = math.clamp(math.floor(level), 1, cap),
			ObtainedAt = os.time(),
			MutationId = if mutation.Id ~= Mutations.NormalId then mutation.Id else nil,
		}
		table.insert(ids, dragonId)
	end
	if placeInRoost then
		local slots = DragonStats.GetRoostSlots(data)
		local roost = table.clone(ids)
		for _, id in data.RoostDragonIds do
			if #roost < slots and not table.find(roost, id) then
				table.insert(roost, id)
			end
		end
		while #roost > slots do
			table.remove(roost)
		end
		table.clear(data.RoostDragonIds)
		for _, id in roost do
			table.insert(data.RoostDragonIds, id)
		end
	end
	IndexService:Sync(player, data)
	return ids
end

local function simulateBinding(areaId: string, element: string?, luck: number, samples: number, seed: number?): any
	local count = math.clamp(math.floor(samples), 1, 5_000_000)
	local rng = Random.new(seed or 12345)
	local results: { [string]: number } = {}
	for _ = 1, count do
		local outcome = BindingOdds.Roll(rng, areaId, element, luck)
		assert(outcome, "SimulateBinding: empty eligible pool")
		local key = `{outcome.SpeciesId}:{outcome.MutationId}`
		results[key] = (results[key] or 0) + 1
	end
	return { Samples = count, Counts = results, Expected = BindingOdds.GetPool(areaId, element, luck) }
end

local function setRoostSlots(player: Player, slots: number): number
	local data = DataService:GetData(player)
	assert(data, "SetRoostSlots: player data not loaded yet")
	data.RoostSlotUpgrades = math.clamp(math.floor(slots) - RoostConfig.BaseSlots, 0, RoostConfig.MaxSlots - RoostConfig.BaseSlots)
	return DragonStats.GetRoostSlots(data)
end

function DevService:Start()
	if not RunService:IsStudio() then
		return
	end
	local folder = ServerStorage:FindFirstChild("DevTools") or Instance.new("Folder")
	folder.Name = "DevTools"
	folder.Parent = ServerStorage
	local give = Instance.new("BindableFunction")
	give.Name = "GiveDragons"
	give.OnInvoke = giveDragons
	give.Parent = folder
	local slots = Instance.new("BindableFunction")
	slots.Name = "SetRoostSlots"
	slots.OnInvoke = setRoostSlots
	slots.Parent = folder
	local simulate = Instance.new("BindableFunction")
	simulate.Name = "SimulateBinding"
	simulate.OnInvoke = simulateBinding
	simulate.Parent = folder
end

return DevService
