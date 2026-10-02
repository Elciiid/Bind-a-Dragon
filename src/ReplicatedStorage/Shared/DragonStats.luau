--!strict
-- Dragon and roost numbers, shared by server (payouts) and client (display) so they always agree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local Constellations = require(ReplicatedStorage.Shared.Config.Constellations)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local IndexConfig = require(ReplicatedStorage.Shared.Config.Index)
local Evolution = require(ReplicatedStorage.Shared.Config.Evolution)
local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local MilestoneConfig = require(ReplicatedStorage.Shared.Config.RebirthMilestones)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.Rebirth)
local RoostConfig = require(ReplicatedStorage.Shared.Config.Roost)
local SpireConfig = require(ReplicatedStorage.Shared.Config.Spire)
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
	if species == nil then
		return 0
	end
	local trait = DragonStats.GetTrait(dragon)
	local grade = DragonStats.GetGrade(dragon)
	local mutation = Mutations.Get(dragon.MutationId)
	return species.BaseGoldPerSecond
		* Leveling.IncomePerLevel ^ (dragon.Level - 1)
		* DragonStats.GetStage(dragon.Level).IncomeMultiplier
		* DragonStats.GetBranchMultiplier(dragon)
		* (if trait then trait.Income else 1)
		* (if grade then grade.Multiplier else 1)
		* mutation.IncomeMultiplier
		* (if dragon.Champion then MilestoneConfig.Champion.IncomeMultiplier else 1)
end

-- Spire battle power: rarity base x level x stage x trait x grade.
function DragonStats.GetPower(dragon: Dragon): number
	local species = Dragons[dragon.SpeciesId]
	if species == nil then
		return 0
	end
	local trait = DragonStats.GetTrait(dragon)
	local grade = DragonStats.GetGrade(dragon)
	local mutation = Mutations.Get(dragon.MutationId)
	return species.BasePower
		* Leveling.PowerPerLevel ^ (dragon.Level - 1)
		* DragonStats.GetStage(dragon.Level).PowerMultiplier
		* (if trait then trait.Power else 1)
		* (if grade then grade.Multiplier else 1)
		* mutation.PowerMultiplier
		* (if dragon.Champion then MilestoneConfig.Champion.PowerMultiplier else 1)
end

-- The player's most powerful dragon (fights in the Spire), or nil if they have none.
function DragonStats.GetBestDragon(data: PlayerData): (Dragon?, number)
	local best, bestPower = nil, 0
	for _, dragon in data.Dragons do
		local power = DragonStats.GetPower(dragon)
		if best == nil or power > bestPower or (power == bestPower and dragon.Id < best.Id) then
			best, bestPower = dragon, power
		end
	end
	return best, bestPower
end

function DragonStats.IsBossFloor(floor: number): boolean
	return floor % SpireConfig.BossEvery == 0
end

-- Enemy power on a Spire floor (Config/Spire). `difficulty` = a key of SpireConfig.Difficulties (default Easy, the original ladder).
function DragonStats.GetEnemyPower(floor: number, difficulty: string?): number
	local def = SpireConfig.Difficulties[difficulty or "Easy"]
	local scale = if def then def.EnemyScale else 1
	local offset = if def then def.FloorOffset or 0 else 0
	local power = SpireConfig.EnemyBase * scale * SpireConfig.EnemyGrowth ^ (floor + offset)
	return if DragonStats.IsBossFloor(floor) then power * SpireConfig.BossMultiplier else power
end

-- How a fight against `enemyPower` goes for a dragon of `power` that has ALREADY cleared the floor: (seconds, rewardShare).
-- Far below the enemy (Config/Spire.FastFloors) it resolves fast and pays only a share of the boss currency drops, so quick
-- repeat runs cannot out-earn the original 20-minute run. A floor not yet cleared always takes FightSeconds at full pay.
function DragonStats.GetFloorTier(power: number, enemyPower: number, alreadyCleared: boolean): (number, number)
	if alreadyCleared then
		for _, tier in SpireConfig.FastFloors do
			if power >= enemyPower * tier.PowerRatio then
				return tier.Seconds, tier.RewardShare
			end
		end
	end
	return SpireConfig.FightSeconds, 1
end

-- The player's record (highest floor cleared) in a difficulty.
function DragonStats.GetSpireRecord(data: PlayerData, difficulty: string): number
	return data.SpireRecords[difficulty] or 0
end

-- A difficulty is open when it has no UnlockFrom, or the floor MaxFloors of that difficulty was cleared.
function DragonStats.IsDifficultyUnlocked(data: PlayerData, difficulty: string): boolean
	local def = SpireConfig.Difficulties[difficulty]
	if def == nil or difficulty == "Order" then
		return false
	end
	local from = def.UnlockFrom
	if from == nil then
		return true
	end
	local fromDef = SpireConfig.Difficulties[from]
	return fromDef ~= nil and DragonStats.GetSpireRecord(data, from) >= (fromDef.MaxFloors or math.huge)
end

-- Reward multiplier of a boss victory / first clear on `floor` of a difficulty (Infinite grows with depth).
function DragonStats.GetSpireRewardMultiplier(difficulty: string, floor: number): number
	local def = SpireConfig.Difficulties[difficulty]
	if def == nil then
		return 1
	end
	local multiplier = def.RewardMultiplier
	if def.DepthRewardEvery then
		multiplier *= 1 + floor / def.DepthRewardEvery
	end
	return multiplier
end

---------------------------------------------------------------------------------------------------------------
-- Dragon Index (Config/Index)

function DragonStats.GetIndexEntryId(dragon: Dragon): string
	return dragon.SpeciesId
end

-- Elements whose every normal species is in the Index, and whether every normal species is.
function DragonStats.GetIndexCompletion(data: PlayerData): ({ string }, boolean)
	local missing: { [string]: boolean } = {}
	local elements: { [string]: boolean } = {}
	local all = true
	for speciesId, species in Dragons do
		elements[species.Element] = true
		if data.Index[speciesId] == nil then
			missing[species.Element] = true
			all = false
		end
	end
	local complete = {}
	for element in elements do
		if not missing[element] then
			table.insert(complete, element)
		end
	end
	table.sort(complete)
	return complete, all
end

function DragonStats.GetIndexEntryCount(data: PlayerData): number
	local count = 0
	for _ in data.Index do
		count += 1
	end
	return count
end

-- Roost income multiplier from the Index.
function DragonStats.GetIndexMultiplier(data: PlayerData): number
	local complete, all = DragonStats.GetIndexCompletion(data)
	return (1 + IndexConfig.IncomePerEntry * DragonStats.GetIndexEntryCount(data))
		* IndexConfig.ElementMultiplier ^ #complete
		* (if all then IndexConfig.AllSpeciesMultiplier else 1)
end

-- Gold uses only the strongest active potion to prevent multiplicative inflation; other stats retain product behavior.
function DragonStats.GetBoostMultiplier(data: PlayerData, stat: string): number
	local multiplier = 1
	for potionId, seconds in data.ActiveBoosts do
		local potion = Boosts.ById[potionId]
		if potion and potion.Stat == stat and seconds > 0 then
			if stat == "Gold" then
				multiplier = math.max(multiplier, potion.Multiplier)
			else
				multiplier *= potion.Multiplier
			end
		end
	end
	return if stat == "Gold" then math.min(multiplier, Boosts.GoldPotionCap) else multiplier
end

-- Permanent roost income multiplier from rebirths (x IncomeBonusPerRebirth per rebirth, multiplying).
function DragonStats.GetRebirthBonus(rebirths: number): number
	return RebirthConfig.IncomeBonusPerRebirth ^ rebirths
end

-- Rising next-level cost. The latest five-level band has a retained-income floor; earlier levels get a geometric
-- catch-up discount. Optional anchor keeps existing callers compatible, but player UI/server pass the saved anchor.
function DragonStats.GetLevelUpCost(dragon: Dragon, rebirths: number, incomeAnchor: number?): number
	local species = Dragons[dragon.SpeciesId]
	local share = species and Leveling.CostFractionOfNextRebirth[species.Rarity]
	if share == nil then
		return math.huge
	end
	local growth = Leveling.CostGrowthPerLevel
	local baseline = DragonStats.GetRebirthCost(rebirths) * share
	local exponent = dragon.Level - 1
	if rebirths > 0 then
		local bandSum = 0
		for i = 0, Leveling.CapPerRebirth - 1 do bandSum += growth ^ i end
		local anchor = if incomeAnchor and incomeAnchor == incomeAnchor and incomeAnchor < math.huge then math.max(0, incomeAnchor) else 0
		baseline = math.max(baseline, anchor * Leveling.RetainedIncomeBandSeconds / bandSum)
		exponent = dragon.Level - (Leveling.CapBase + Leveling.CapPerRebirth * rebirths - Leveling.CapPerRebirth)
	end
	return math.max(1, math.ceil(baseline * growth ^ exponent))
end

-- Levels and total gold for buying up to `count` levels (stops at the cap). Doesn't change the dragon.
function DragonStats.GetBulkLevelCost(dragon: Dragon, count: number, cap: number, rebirths: number, incomeAnchor: number?): (number, number)
	local levels, total = 0, 0
	local probe = table.clone(dragon)
	while levels < count and probe.Level < cap do
		total += DragonStats.GetLevelUpCost(probe, rebirths, incomeAnchor)
		probe.Level += 1
		levels += 1
	end
	return levels, total
end

-- Hypothetical strongest legal roost, independent of placement, includes retained permanent bonuses only.
function DragonStats.GetRetainedIncomeAnchor(data: PlayerData): number
	local incomes = {}
	for _, dragon in data.Dragons do table.insert(incomes, DragonStats.GetGoldPerSecond(dragon)) end
	table.sort(incomes, function(a, b) return a > b end)
	local total = 0
	for i = 1, math.min(#incomes, DragonStats.GetRoostSlots(data)) do total += incomes[i] end
	return total * DragonStats.GetRoostIncomeMultiplier(data) * DragonStats.GetRebirthBonus(data.Rebirths) * DragonStats.GetIndexMultiplier(data)
end

-- Initialized once per rebirth; clients receive the number but can never submit an anchor.
function DragonStats.EnsureLevelingAnchor(data: PlayerData)
	if data.LevelingAnchorRebirth ~= data.Rebirths or type(data.LevelingIncomeAnchor) ~= "number"
		or data.LevelingIncomeAnchor ~= data.LevelingIncomeAnchor or data.LevelingIncomeAnchor < 0 or data.LevelingIncomeAnchor == math.huge then
		data.LevelingIncomeAnchor = DragonStats.GetRetainedIncomeAnchor(data)
		data.LevelingAnchorRebirth = data.Rebirths
	end
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
		local postLaunch = r - config.CurveEnd
		local weeklyJumps = math.ceil(postLaunch / config.WeeklyRebirths)
		local normalSteps = postLaunch - weeklyJumps
		cost *= config.WeeklyJump ^ weeklyJumps * weeklyGrowth ^ normalSteps
	end
	return cost
end

-- True once the player has done every rebirth this week's update allows (Config/Rebirth RebirthCap).
function DragonStats.IsAtRebirthCap(data: PlayerData): boolean
	return data.Rebirths >= RebirthConfig.RebirthCap
end

-- Gold that may be banked at the weekly cap. Nil means there is no bank limit yet.
function DragonStats.GetGoldBankLimit(data: PlayerData): number?
	return if DragonStats.IsAtRebirthCap(data) then DragonStats.GetRebirthCost(data.Rebirths) else nil
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

-- Total gold/sec from every dragon placed in the roost, including the roost income upgrade, the rebirth bonus
-- and the Dragon Index.
-- Selling to the Star Merchant (Config/Economy.Selling), shared so the client shows exactly what the server pays.
-- Gold = the dragon's own earning rate with every permanent multiplier x seconds for its rarity x mutation multiplier;
-- Wyrm Runes / Dragonstones by rarity (doubled for mutated dragons).
function DragonStats.GetSellValue(dragon: Dragon, data: PlayerData): (number, { WyrmRunes: number, Dragonstones: number })
	local selling = Economy.Selling.Dragons
	local species = Dragons[dragon.SpeciesId]
	if species == nil then
		return 0, { WyrmRunes = 0, Dragonstones = 0 }
	end
	local rate = DragonStats.GetGoldPerSecond(dragon)
		* DragonStats.GetRoostIncomeMultiplier(data)
		* DragonStats.GetRebirthBonus(data.Rebirths)
		* DragonStats.GetIndexMultiplier(data)
	local mutation = Mutations.Get(dragon.MutationId)
	local mutated = mutation.Id ~= Mutations.NormalId
	local gold = math.floor(rate * (selling.Seconds[species.Rarity] or 0) * (if mutated then selling.MutationMultiplier[mutation.Id] or 1 else 1))
	local base = selling.Rewards[species.Rarity]
	local factor = if mutated then selling.RewardMutatedMultiplier else 1
	return gold, {
		WyrmRunes = math.floor((if base then base.WyrmRunes else 0) * factor),
		Dragonstones = math.floor((if base then base.Dragonstones else 0) * factor),
	}
end

-- Why a dragon can't be sold (nil = it can): "Favorite", "Roost" or "Champion". The hotbar and the carried dragon are NOT protected:
-- the hotbar only shows backpack dragons, and "I want to sell this!" sells the carried one.
function DragonStats.GetSellProtection(dragon: Dragon, data: PlayerData): string?
	if dragon.Champion then
		return "Champion"
	elseif dragon.Favorite then
		return "Favorite"
	elseif table.find(data.RoostDragonIds, dragon.Id) then
		return "Roost"
	end
	return nil
end

-- The backpack = every dragon NOT placed in the roost (sanctuary).
function DragonStats.IsInBackpack(dragon: Dragon, data: PlayerData): boolean
	return table.find(data.RoostDragonIds, dragon.Id) == nil
end

-- Backpack dragons the inventory sale would take: not in the roost, not favorited, not the champion. Sorted by id for a stable order.
function DragonStats.GetSellableInventory(data: PlayerData): { Dragon }
	local list: { Dragon } = {}
	for _, dragon in data.Dragons do
		if DragonStats.GetSellProtection(dragon, data) == nil then
			table.insert(list, dragon)
		end
	end
	table.sort(list, function(a, b)
		local na, nb = tonumber(a.Id), tonumber(b.Id)
		if na and nb then
			return na < nb
		end
		return a.Id < b.Id
	end)
	return list
end

-- Does selling this dragon need the extra confirmation (Epic or better, or mutated)?
function DragonStats.IsRiskySale(dragon: Dragon): boolean
	local species = Dragons[dragon.SpeciesId]
	local selling = Economy.Selling.Dragons
	return (species ~= nil and selling.ConfirmRarities[species.Rarity] == true)
		or (selling.ConfirmMutated and Mutations.Get(dragon.MutationId).Id ~= Mutations.NormalId)
end

function DragonStats.GetRoostIncome(data: PlayerData): number
	local total = 0
	for _, dragonId in data.RoostDragonIds do
		local dragon = data.Dragons[dragonId]
		if dragon then
			total += DragonStats.GetGoldPerSecond(dragon)
		end
	end
	return total
		* DragonStats.GetRoostIncomeMultiplier(data)
		* DragonStats.GetRebirthBonus(data.Rebirths)
		* DragonStats.GetIndexMultiplier(data)
end

return DragonStats
