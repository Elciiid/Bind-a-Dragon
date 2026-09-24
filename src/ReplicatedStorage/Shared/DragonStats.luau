--!strict
-- Dragon and roost numbers, shared by server (payouts) and client (display) so they always agree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Evolution = require(ReplicatedStorage.Shared.Config.Evolution)
local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local RoostConfig = require(ReplicatedStorage.Shared.Config.Roost)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

type Dragon = PlayerDataTypes.Dragon
type PlayerData = PlayerDataTypes.PlayerData

local rarityById: { [string]: Rarities.Rarity } = {}
for _, rarity in Rarities do
	rarityById[rarity.Id] = rarity
end

local DragonStats = {}

function DragonStats.GetRarity(rarityId: string): Rarities.Rarity?
	return rarityById[rarityId]
end

-- The highest stage whose MinLevel the dragon has reached.
function DragonStats.GetStage(level: number): Evolution.Stage
	local current = Evolution[1]
	for _, stage in Evolution do
		if level >= stage.MinLevel then
			current = stage
		end
	end
	return current
end

function DragonStats.GetGoldPerSecond(dragon: Dragon): number
	local species = Dragons[dragon.SpeciesId]
	local rarity = species and rarityById[species.Rarity]
	if rarity == nil then
		return 0
	end
	local levelMultiplier = 1 + RoostConfig.IncomePerLevel * (dragon.Level - 1)
	return rarity.GoldPerSecond * levelMultiplier * DragonStats.GetStage(dragon.Level).IncomeMultiplier
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
