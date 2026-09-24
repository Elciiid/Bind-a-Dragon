--!strict
-- Dragon and roost numbers, shared by server (payouts) and client (display) so they always agree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Constellations = require(ReplicatedStorage.Shared.Config.Constellations)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Evolution = require(ReplicatedStorage.Shared.Config.Evolution)
local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.Rebirth)
local RoostConfig = require(ReplicatedStorage.Shared.Config.Roost)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

type Dragon = PlayerDataTypes.Dragon
type PlayerData = PlayerDataTypes.PlayerData

local rarityById: { [string]: Rarities.Rarity } = {}
for _, rarity in Rarities do
	rarityById[rarity.Id] = rarity
end

local constellationById: { [string]: Constellations.Constellation } = {}
for _, constellation in Constellations do
	constellationById[constellation.Id] = constellation
end

local DragonStats = {}

function DragonStats.GetRarity(rarityId: string): Rarities.Rarity?
	return rarityById[rarityId]
end

-- The highest stage whose MinLevel the dragon has reached.
function DragonStats.GetStage(level: number): Evolution.Stage
	local current = Evolution.Stages[1]
	for _, stage in Evolution.Stages do
		if level >= stage.MinLevel then
			current = stage
		end
	end
	return current
end

-- Income multiplier from evolution branches: +BranchIncomeBonus per branch earned under a night constellation,
-- +MatchingBranchIncomeBonus instead when that constellation's element matches the dragon's. Day branches add nothing.
function DragonStats.GetBranchMultiplier(dragon: Dragon): number
	local species = Dragons[dragon.SpeciesId]
	local bonus = 0
	for _, constellationId in dragon.Evolutions or {} do
		local constellation = constellationById[constellationId]
		if constellation then
			local matches = species ~= nil and constellation.Element == species.Element
			bonus += if matches then Evolution.MatchingBranchIncomeBonus else Evolution.BranchIncomeBonus
		end
	end
	return 1 + bonus
end

-- Element of the dragon's most recent night branch (for its accent color), or nil if it has none.
function DragonStats.GetBranchElement(dragon: Dragon): string?
	local evolutions = dragon.Evolutions
	if evolutions == nil then
		return nil
	end
	local element: string? = nil
	for _, stage in Evolution.Stages do -- stage order, so the latest evolution wins
		local constellation = constellationById[evolutions[stage.Id] or ""]
		if constellation and constellation.Element then
			element = constellation.Element
		end
	end
	return element
end

function DragonStats.GetGoldPerSecond(dragon: Dragon): number
	local species = Dragons[dragon.SpeciesId]
	local rarity = species and rarityById[species.Rarity]
	if rarity == nil then
		return 0
	end
	local levelMultiplier = 1 + RoostConfig.IncomePerLevel * (dragon.Level - 1)
	return rarity.GoldPerSecond
		* levelMultiplier
		* DragonStats.GetStage(dragon.Level).IncomeMultiplier
		* DragonStats.GetBranchMultiplier(dragon)
end

-- Gold needed to go from the dragon's current level to the next.
function DragonStats.GetLevelUpCost(dragon: Dragon): number
	local species = Dragons[dragon.SpeciesId]
	local base = species and Leveling.BaseCost[species.Rarity]
	if base == nil then
		return math.huge
	end
	return math.floor(base * Leveling.CostGrowth ^ (dragon.Level - 1))
end

-- Max dragon level: the highest LevelCap among areas the player has unlocked with rebirths.
function DragonStats.GetLevelCap(data: PlayerData): number
	local cap = 1
	for _, area in Areas do
		if data.Rebirths >= area.RebirthsRequired then
			cap = math.max(cap, area.LevelCap)
		end
	end
	return cap
end

function DragonStats.GetRebirthCost(rebirths: number): number
	return RebirthConfig.BaseCost * RebirthConfig.CostGrowth ^ rebirths
end

-- True if the player has enough rebirths for the area (areas stay unlocked since rebirths never go down).
function DragonStats.IsAreaUnlocked(data: PlayerData, areaId: string): boolean
	local area = Areas[areaId]
	return area ~= nil and data.Rebirths >= area.RebirthsRequired
end

function DragonStats.GetRoostSlots(_data: PlayerData): number
	-- TODO(Economy): add roost upgrade slots here.
	return math.min(RoostConfig.BaseSlots, RoostConfig.MaxSlots)
end

-- Total gold/sec from every dragon placed in the roost.
function DragonStats.GetRoostIncome(data: PlayerData): number
	local total = 0
	for _, dragonId in data.RoostDragonIds do
		local dragon = data.Dragons[dragonId]
		if dragon then
			total += DragonStats.GetGoldPerSecond(dragon)
		end
	end
	return total
end

return DragonStats
