--!strict
-- Dragon and roost numbers, shared by server (payouts) and client (display) so they always agree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Constellations = require(ReplicatedStorage.Shared.Config.Constellations)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Evolution = require(ReplicatedStorage.Shared.Config.Evolution)
local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.Rebirth)
local RoostConfig = require(ReplicatedStorage.Shared.Config.Roost)
local TraitConfig = require(ReplicatedStorage.Shared.Config.Traits)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

type Dragon = PlayerDataTypes.Dragon
type PlayerData = PlayerDataTypes.PlayerData

local rarityById: { [string]: Rarities.Rarity } = {}
for _, rarity in Rarities do
	rarityById[rarity.Id] = rarity
end

local traitById: { [string]: TraitConfig.Trait } = {}
for _, trait in TraitConfig.Traits do
	traitById[trait.Id] = trait
end

local gradeById: { [string]: TraitConfig.Grade } = {}
for _, grade in TraitConfig.Grades do
	gradeById[grade.Id] = grade
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

function DragonStats.GetTrait(dragon: Dragon): TraitConfig.Trait?
	return if dragon.Trait then traitById[dragon.Trait] else nil
end

function DragonStats.GetGrade(dragon: Dragon): TraitConfig.Grade?
	return if dragon.Grade then gradeById[dragon.Grade] else nil
end

function DragonStats.GetGoldPerSecond(dragon: Dragon): number
	local species = Dragons[dragon.SpeciesId]
	local rarity = species and rarityById[species.Rarity]
	if rarity == nil then
		return 0
	end
	local trait = DragonStats.GetTrait(dragon)
	local grade = DragonStats.GetGrade(dragon)
	return rarity.GoldPerSecond
		* Leveling.IncomePerLevel ^ (dragon.Level - 1)
		* DragonStats.GetStage(dragon.Level).IncomeMultiplier
		* DragonStats.GetBranchMultiplier(dragon)
		* (if trait then trait.Income else 1)
		* (if grade then grade.Multiplier else 1)
end

-- Spire battle power: rarity base x level x stage x trait x grade.
function DragonStats.GetPower(dragon: Dragon): number
	local species = Dragons[dragon.SpeciesId]
	local rarity = species and rarityById[species.Rarity]
	if rarity == nil then
		return 0
	end
	local trait = DragonStats.GetTrait(dragon)
	local grade = DragonStats.GetGrade(dragon)
	return rarity.BasePower
		* Leveling.PowerPerLevel ^ (dragon.Level - 1)
		* DragonStats.GetStage(dragon.Level).PowerMultiplier
		* (if trait then trait.Power else 1)
		* (if grade then grade.Multiplier else 1)
end

-- Permanent roost income multiplier from rebirths (x IncomeBonusPerRebirth per rebirth, multiplying).
function DragonStats.GetRebirthBonus(rebirths: number): number
	return RebirthConfig.IncomeBonusPerRebirth ^ rebirths
end

-- Gold needed to go from the dragon's current level to the next. Scales with the rebirth bonus so levelling stays
-- a real gold sink after every rebirth (see Config/Leveling).
function DragonStats.GetLevelUpCost(dragon: Dragon, rebirths: number): number
	local species = Dragons[dragon.SpeciesId]
	local base = species and Leveling.BaseCost[species.Rarity]
	if base == nil then
		return math.huge
	end
	return base * Leveling.CostGrowth ^ (dragon.Level - 1) * DragonStats.GetRebirthBonus(rebirths)
end

-- Levels and total gold for buying up to `count` levels (stops at the cap). Doesn't change the dragon.
function DragonStats.GetBulkLevelCost(dragon: Dragon, count: number, cap: number, rebirths: number): (number, number)
	local levels, total = 0, 0
	local probe = table.clone(dragon)
	while levels < count and probe.Level < cap do
		total += DragonStats.GetLevelUpCost(probe, rebirths)
		probe.Level += 1
		levels += 1
	end
	return levels, total
end

-- Max dragon level: CapBase + CapPerRebirth per rebirth.
function DragonStats.GetLevelCap(data: PlayerData): number
	return Leveling.CapBase + Leveling.CapPerRebirth * data.Rebirths
end

-- Gold cost of the NEXT rebirth for a player who has done `rebirths` so far. Open-ended (see Config/Rebirth).
function DragonStats.GetRebirthCost(rebirths: number): number
	local r = rebirths + 1
	local config = RebirthConfig
	local cost = config.FirstCost * config.EarlyGrowth ^ (math.min(r, config.EarlyUntil) - 1)
	if r > config.EarlyUntil then
		cost *= config.LateGrowth ^ (math.min(r, config.CurveEnd) - config.EarlyUntil)
	end
	if r > config.CurveEnd then
		local weeklyGrowth = config.IncomeBonusPerRebirth
			* Leveling.IncomePerLevel ^ Leveling.CapPerRebirth
			* config.WeeklyGrowthStep
		cost *= config.WeeklyJump * weeklyGrowth ^ (r - config.CurveEnd)
	end
	return cost
end

-- True once the player has done every rebirth this week's update allows (Config/Rebirth RebirthCap).
function DragonStats.IsAtRebirthCap(data: PlayerData): boolean
	return data.Rebirths >= RebirthConfig.RebirthCap
end

-- True if the player has enough rebirths for the area (areas stay unlocked since rebirths never go down).
function DragonStats.IsAreaUnlocked(data: PlayerData, areaId: string): boolean
	local area = Areas[areaId]
	return area ~= nil and data.Rebirths >= area.RebirthsRequired
end

function DragonStats.GetRoostSlots(data: PlayerData): number
	return math.min(RoostConfig.BaseSlots + data.RoostSlotUpgrades, RoostConfig.MaxSlots)
end

-- Cost of the next extra roost slot, or nil when no more can be bought.
function DragonStats.GetNextSlotCost(data: PlayerData): number?
	if DragonStats.GetRoostSlots(data) >= RoostConfig.MaxSlots then
		return nil
	end
	return Economy.RoostUpgrades.SlotCosts[data.RoostSlotUpgrades + 1]
end

function DragonStats.GetRoostIncomeMultiplier(data: PlayerData): number
	return 1 + Economy.RoostUpgrades.IncomeBonusPerLevel * data.RoostIncomeLevel
end

-- Cost of the next roost income level, or nil at the max level.
function DragonStats.GetNextIncomeUpgradeCost(data: PlayerData): number?
	local upgrades = Economy.RoostUpgrades
	if data.RoostIncomeLevel >= upgrades.MaxIncomeLevel then
		return nil
	end
	return math.floor(upgrades.IncomeBaseCost * upgrades.IncomeCostGrowth ^ data.RoostIncomeLevel)
end

-- Gold price of the next Stardust bundle from the Star Merchant: a share of the next rebirth cost, rising per
-- purchase, resetting at dawn.
function DragonStats.GetMerchantPrice(data: PlayerData, dayIndex: number): number
	local merchant = Economy.Merchant
	local bought = if data.MerchantDay == dayIndex then data.MerchantPurchases else 0
	-- Round, not floor: 50M * 0.0006 is 29999.99... in floating point.
	return math.round(
		DragonStats.GetRebirthCost(data.Rebirths) * merchant.PriceFractionOfNextRebirth * merchant.PriceGrowth ^ bought
	)
end

-- Total gold/sec from every dragon placed in the roost, including the roost income upgrade and the rebirth bonus.
function DragonStats.GetRoostIncome(data: PlayerData): number
	local total = 0
	for _, dragonId in data.RoostDragonIds do
		local dragon = data.Dragons[dragonId]
		if dragon then
			total += DragonStats.GetGoldPerSecond(dragon)
		end
	end
	return total * DragonStats.GetRoostIncomeMultiplier(data) * DragonStats.GetRebirthBonus(data.Rebirths)
end

return DragonStats
