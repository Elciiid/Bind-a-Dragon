--!strict
-- Cohort economy simulation for Bind A Dragon. Reads the LIVE Config modules and the real Shared code
-- (DragonStats, BindingOdds, Luck.GetTierWeights), so any Config edit is simulated without touching this file.
-- See tools/sim/README.md for how to load and run it.
--
-- One run = one simulated player living day by day (60 s resolution while active, closed form while away).
-- Cohorts (Sim.Profiles): Dedicated, Casual, AfkOnly, PaidAfk. Results are medians / percentiles over many runs.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Shared = ReplicatedStorage.Shared
local Config = Shared.Config

local Areas = require(Config.Areas)
local BindingConfig = require(Config.Binding)
local Boosts = require(Config.Boosts)
local Constellations = require(Config.Constellations)
local DayNight = require(Config.DayNight)
local Dragons = require(Config.Dragons)
local Economy = require(Config.Economy)
local Evolution = require(Config.Evolution)
local IndexConfig = require(Config.Index)
local Leveling = require(Config.Leveling)
local LuckConfig = require(Config.Luck)
local Mutations = require(Config.Mutations)
local Products = require(Config.Products)
local Quests = require(Config.Quests)
local RebirthConfig = require(Config.Rebirth)
local RoostConfig = require(Config.Roost)
local SpireConfig = require(Config.Spire)
local Traits = require(Config.Traits)
local BindingOdds = require(Shared.BindingOdds)
local DragonStats = require(Shared.DragonStats)
local Luck = require(Shared.Luck)
local Milestones = require(Config.RebirthMilestones)

local Sim = {}

export type Profile = {
	Name: string,
	Active: { { number } }, -- { startMinuteOfDay, minutes }: playing (binds every night, spends gold, Spire, quests)
	Idle: { { number } }?, -- in the game but idle: earns the offline rate, Auto-bind works (only with the pass)
	Jitter: number, -- minutes each session start moves around
	SkipDay: number, -- chance of playing no active session on a day
	SpireMinutes: number, -- Spire time inside the first active session
	AutoBind: boolean,
	Afk2x: boolean,
	SpendK: number, -- buy an upgrade only if it pays back within this share of the time left to the next rebirth
}

Sim.Profiles = {
	Dedicated = {
		Name = "Dedicated", Active = { { 660, 110 }, { 1140, 100 } }, Jitter = 60, SkipDay = 0.03,
		SpireMinutes = 25, AutoBind = false, Afk2x = false, SpendK = 0.6,
	},
	Casual = {
		Name = "Casual", Active = { { 1140, 60 } }, Jitter = 90, SkipDay = 0.25,
		SpireMinutes = 8, AutoBind = false, Afk2x = false, SpendK = 0.6,
	},
	AfkOnly = {
		Name = "AfkOnly", Active = { { 1140, 12 } }, Jitter = 120, SkipDay = 0.10,
		SpireMinutes = 0, AutoBind = false, Afk2x = false, SpendK = 0.6,
	},
	PaidAfk = {
		-- Auto-bind + 2x AFK Income: in the game ~12 h a day, 12 five-minute check-ins.
		Name = "PaidAfk", Active = {}, Jitter = 45, SkipDay = 0.05,
		SpireMinutes = 5, AutoBind = true, Afk2x = true, SpendK = 0.6,
	},
} :: { [string]: Profile }

do
	-- PaidAfk check-ins: 12 of 5 minutes, one every hour from 08:00 to 19:00; in the game from 08:00 to 20:00.
	local p = Sim.Profiles.PaidAfk
	for hour = 8, 19 do
		table.insert(p.Active, { hour * 60, 5 })
	end
	p.Idle = { { 480, 720 } }
end

-- Switches for the "Old" preset (the economy approved before the mutation branch); all off = the live Config.
local Variant = { OldBind = false, OldLevelCost = false, StackPotions = false, FlatLevelCost = false }
local progress: (any, string, number) -> ()

local DAY = 86400
local CYCLE = DayNight.DaySeconds + DayNight.NightSeconds
local STEP = 60 -- seconds per decision step while active

---------------------------------------------------------------------------------------------------------------------
-- State

type Dragon = {
	Id: string,
	SpeciesId: string,
	Level: number,
	MutationId: string?,
	Trait: string?,
	Grade: string?,
	Evolutions: { [string]: string }?,
	Q: number?, -- cached quality
}

type State = {
	Rng: Random,
	Profile: Profile,
	Data: any, -- PlayerData-shaped table that DragonStats understands
	Cap: number, -- current rebirth cap (launch cap, +WeeklyRebirths per update)
	Time: number, -- seconds since the start
	Runes: number,
	Stones: number,
	Sigils: number,
	GildedMin: number, HoardMin: number, -- stored gold potion minutes (only ticks while active)
	Charges: { number }, -- armed luck charges waiting for a bind (multipliers)
	WyrmbloodMin: number,
	SpireRecord: number,
	Streak: number,
	SpireWinsToday: number,
	SigilFromQuests: boolean, SigilFromSpire: boolean,
	NightConst: { [number]: any },
	Binds: number,
	RebirthDay: { number }, -- Time (days) of each rebirth
	IndexMilestones: number,
	ElementsRewarded: { [string]: boolean },
	NextId: number,
	WeekBank: number,
	LastBindNight: number,
	CostRebirths: number, CostValue: number, -- cache of the next rebirth cost
	LastSpend: number,
	Origin: number, -- seconds: when the player starts (the first session of day 0); day counts start here
	Daily: {any}, Weekly: {any}, Floor: number, FightLeft: number,
	ConquerorMin: number, RunebrightMin: number, RuneEarned: number, StoneEarned: number, UpgradeSpent: number,
	LevelCosts: {[string]: {number}},
	BandMinutes: {number},
	ReinvestedBandMinutes: {number},
	OfferingNight: number, OfferingLuck: number,
}

local rarityRank: { [string]: number } = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }

local function sigilCap(S: State): number
	local cap = BindingConfig.EchoSigilCap
	for _, milestone in Milestones.Milestones do
		if S.Data.Rebirths >= milestone.Rebirths then cap += milestone.Perks.EchoSigilCap or 0 end
	end
	return cap
end

local function ascendedLuck(S: State): number
	local luck = 1
	for _, milestone in Milestones.Milestones do
		if S.Data.Rebirths >= milestone.Rebirths then luck *= milestone.Perks.AscendedLuck or 1 end
	end
	return luck
end

local function newState(profile: Profile, seed: number, cap: number): State
	local data = {
		Dragons = {}, RoostDragonIds = {}, Rebirths = 0, Gold = 0,
		RoostSlotUpgrades = 0, RoostIncomeLevel = 0, Index = {}, MutationIndex = {}, ActiveBoosts = {},
		Stardust = 0, MerchantDay = -1, MerchantPurchases = 0, LevelingIncomeAnchor = 0, LevelingAnchorRebirth = 0,
	}
	local S: State = {
		Rng = Random.new(seed), Profile = profile, Data = data, Cap = cap, Time = 0, Runes = 0, Stones = 0, Sigils = 0,
		GildedMin = 0, HoardMin = 0, Charges = {}, WyrmbloodMin = 0, SpireRecord = 0, Streak = 0, SpireWinsToday = 0,
		SigilFromQuests = false, SigilFromSpire = false, NightConst = {}, Binds = 0, RebirthDay = {},
		IndexMilestones = 0, ElementsRewarded = {}, NextId = 1, WeekBank = 0, LastBindNight = -1, CostRebirths = -1, CostValue = 0, LastSpend = -1e9, Origin = 0,
		Daily = {}, Weekly = {}, Floor = 1, FightLeft = 12, ConquerorMin = 0, RunebrightMin = 0, RuneEarned = 0, StoneEarned = 0, UpgradeSpent = 0,
		LevelCosts = {},
		BandMinutes = {},
		ReinvestedBandMinutes = {},
		OfferingNight = -1, OfferingLuck = 1,
	}
	return S
end

local function newDragon(S: State, speciesId: string, mutationId: string?): Dragon
	local d: Dragon = { Id = tostring(S.NextId), SpeciesId = speciesId, Level = 1, MutationId = mutationId }
	S.NextId += 1
	S.Data.Dragons[d.Id] = d
	return d
end

-- Level-independent value of a dragon (what it would earn at equal levels). Cached on the dragon (Q); call
-- refreshQuality after its trait/grade changes.
local function refreshQuality(d: Dragon): number
	local probe = table.clone(d)
	probe.Level = 1
	probe.Evolutions = nil
	d.Q = DragonStats.GetGoldPerSecond(probe :: any)
	return d.Q
end

local function quality(d: Dragon): number
	return d.Q or refreshQuality(d)
end

local function rebirthCost(S: State): number
	if S.CostRebirths ~= S.Data.Rebirths then
		S.CostRebirths = S.Data.Rebirths
		S.CostValue = DragonStats.GetRebirthCost(S.Data.Rebirths)
	end
	return S.CostValue
end

local function slots(S: State): number
	return DragonStats.GetRoostSlots(S.Data)
end

local BENCH = 12 -- dragons kept outside the roost (the rest are dropped; they never matter for income)

-- Keeps the roost filled with the best dragons; a newcomer must be clearly better (1.5x) than the dragon it replaces.
local function equip(S: State, newcomer: Dragon?)
	local data = S.Data
	local n = slots(S)
	local ids = data.RoostDragonIds
	local function weakest(): (number, number)
		local index, q = 0, math.huge
		for i, id in ids do
			local x = quality(data.Dragons[id])
			if x < q then
				index, q = i, x
			end
		end
		return index, q
	end
	if newcomer then
		if #ids < n then
			table.insert(ids, newcomer.Id)
		else
			local i, q = weakest()
			if i > 0 and quality(newcomer) > q * 1.5 then
				ids[i] = newcomer.Id
			end
		end
	end
	-- free slots (a slot upgrade): the best dragons on the bench
	while #ids < n do
		local inRoost: { [string]: boolean } = {}
		for _, id in ids do
			inRoost[id] = true
		end
		local best: Dragon? = nil
		for id, d in data.Dragons do
			if not inRoost[id] and (best == nil or quality(d) > quality(best)) then
				best = d
			end
		end
		if best == nil then
			break
		end
		table.insert(ids, best.Id)
	end
	-- trim the bench
	local inRoost: { [string]: boolean } = {}
	for _, id in ids do
		inRoost[id] = true
	end
	local bench: { Dragon } = {}
	for id, d in data.Dragons do
		if not inRoost[id] then
			table.insert(bench, d)
		end
	end
	if #bench > BENCH then
		table.sort(bench, function(a, b)
			return quality(a) > quality(b)
		end)
		for i = BENCH + 1, #bench do
			data.Dragons[bench[i].Id] = nil
		end
	end
end

local function recordIndex(S: State, d: Dragon)
	local data = S.Data
	if data.Index[d.SpeciesId] == nil then
		data.Index[d.SpeciesId] = S.Time
		local count = DragonStats.GetIndexEntryCount(data)
		while count >= (S.IndexMilestones + 1) * IndexConfig.MilestoneEvery do
			S.IndexMilestones += 1
			local r = IndexConfig.MilestoneReward
			S.Runes += (r.WyrmRunes or 0)
			S.HoardMin += (if r.Potions and r.Potions.HoardElixir then r.Potions.HoardElixir else 0) * 5
		end
		local complete = DragonStats.GetIndexCompletion(data)
		for _, element in complete do
			if not S.ElementsRewarded[element] then
				S.ElementsRewarded[element] = true
				local r = IndexConfig.ElementReward
				S.Runes += (r.WyrmRunes or 0)
				S.Stones += (r.Dragonstones or 0)
				table.insert(S.Charges, Boosts.ById.MoonfireTonic.Multiplier)
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Time: night cycle, constellation, moon

local function nightIndex(t: number): number
	return math.floor(t / CYCLE)
end

local function isNight(t: number): boolean
	return t % CYCLE >= DayNight.DaySeconds
end

local totalWeight = 0
for _, c in Constellations do
	totalWeight += c.Weight
end

local function constellationOf(S: State, night: number): any
	local c = S.NightConst[night]
	if c == nil then
		local roll = S.Rng:NextNumber() * totalWeight
		for _, k in Constellations do
			roll -= k.Weight
			if roll < 0 then
				c = k
				break
			end
		end
		S.NightConst[night] = c or Constellations[1]
		c = S.NightConst[night]
	end
	return c
end

---------------------------------------------------------------------------------------------------------------------
-- Binding

-- The old bind: a rarity roll (weights 600/250/110/35/5, luck ^ 0.3 per step) then a species of that rarity; 1/850 Starborn.
local function oldRoll(S: State, areaId: string, element: string?, luck: number): any
	local weights = { Common = 600, Rare = 250, Epic = 110, Legendary = 35, Mythic = 5 }
	local order = { "Common", "Rare", "Epic", "Legendary", "Mythic" }
	local present: { [string]: { string } } = {}
	for _, id in Areas[areaId].Species do
		local sp = Dragons[id]
		if element == nil or sp.Element == element then
			present[sp.Rarity] = present[sp.Rarity] or {}
			table.insert(present[sp.Rarity], id)
		end
	end
	local total = 0
	local w: { [string]: number } = {}
	for i, r in order do
		w[r] = if present[r] then weights[r] * luck ^ (0.3 * (i - 1)) else 0
		total += w[r]
	end
	local roll = S.Rng:NextNumber() * total
	for _, r in order do
		roll -= w[r]
		if roll < 0 then
			local list = present[r]
			table.sort(list)
			return {
				SpeciesId = list[S.Rng:NextInteger(1, #list)],
				MutationId = if S.Rng:NextNumber() < 1 / 850 then "Starborn" else Mutations.NormalId,
			}
		end
	end
	return nil
end

local function pickArea(S: State, constellation: any): string
	local best, bestLuck = "StarterMeadow", -1
	for id, area in Areas do
		if S.Data.Rebirths >= area.RebirthsRequired then
			local score = area.BindLuck
			if area.Element ~= nil and area.Element == constellation.Element then
				score *= 10 -- the favored area: x1.5 luck and its element is tonight's
			end
			if score > bestLuck then
				best, bestLuck = id, score
			end
		end
	end
	return best
end

local function highestArea(S: State): string
	local best, order = "StarterMeadow", 0
	for id, area in Areas do
		if S.Data.Rebirths >= area.RebirthsRequired and area.Order > order then
			best, order = id, area.Order
		end
	end
	return best
end

local function bind(S: State, t: number, auto: boolean, extra: boolean?)
	local night = nightIndex(t)
	if not extra and S.LastBindNight == night then
		return -- one bind per night; Echo Sigils are the extra ones
	end
	S.LastBindNight = night
	local constellation = constellationOf(S, night)
	local areaId, luck
	if auto then
		areaId, luck = highestArea(S), Products.AutoBindLuck
	else
		areaId = pickArea(S, constellation)
		local area = Areas[areaId]
		local moon = LuckConfig.MoonPhases[night % #LuckConfig.MoonPhases + 1].Luck
		luck = area.BindLuck * constellation.Luck * moon
		local offeringLuck = if S.OfferingNight == night then S.OfferingLuck else 1
		for _, offering in if S.OfferingNight == night then {} else LuckConfig.Offerings do
			if S.Data.Stardust < offering.Cost then
				local price = DragonStats.GetMerchantPrice(S.Data, night)
				if S.Data.Gold >= price and price < rebirthCost(S) * 0.01 then
					S.Data.Gold -= price
					S.Data.Stardust += Economy.Merchant.BundleSize
					if S.Data.MerchantDay ~= night then S.Data.MerchantPurchases = 0 end
					S.Data.MerchantDay = night
					S.Data.MerchantPurchases += 1
				end
			end
			if S.Data.Stardust < offering.Cost then break end
			S.Data.Stardust -= offering.Cost
			offeringLuck += offering.Luck
			progress(S, "Offer", 1)
		end
		S.OfferingNight, S.OfferingLuck = night, offeringLuck
		luck *= offeringLuck * ascendedLuck(S)
		if area.Element ~= nil and area.Element == constellation.Element then
			luck *= LuckConfig.FavoredAreaLuck
		end
		luck = math.min(luck, LuckConfig.Cap)
		if #S.Charges > 0 then
			luck = math.min(luck * table.remove(S.Charges, 1), LuckConfig.PotionCap)
		end
	end
	local area = Areas[areaId]
	local element = if area.Element then area.Element else constellation.Element
	local outcome = if Variant.OldBind then oldRoll(S, areaId, element, luck) else BindingOdds.Roll(S.Rng, areaId, element, luck)
	if outcome == nil then
		return
	end
	S.Binds += 1
	progress(S, "Bind", 1)
	if area.Element and area.Element == constellation.Element then progress(S, "FavoredBind", 1) end
	local mutationId = if outcome.MutationId ~= Mutations.NormalId then outcome.MutationId else nil
	local d = newDragon(S, outcome.SpeciesId, mutationId)
	recordIndex(S, d)
	equip(S, d)
end

---------------------------------------------------------------------------------------------------------------------
-- Income and spending

local function roostMultiplier(S: State): number
	return DragonStats.GetRoostIncomeMultiplier(S.Data)
		* DragonStats.GetRebirthBonus(S.Data.Rebirths)
		* DragonStats.GetIndexMultiplier(S.Data)
end

local function levelCost(d: Dragon, rebirths: number, anchor: number?): number
	if Variant.OldLevelCost then
		local base = ({ Common = 1000, Rare = 5000, Epic = 20000, Legendary = 100000, Mythic = 500000 })[Dragons[d.SpeciesId].Rarity]
		return base * 1.08 ^ (d.Level - 1) * RebirthConfig.IncomeBonusPerRebirth ^ rebirths
	end
	if Variant.FlatLevelCost then return DragonStats.GetRebirthCost(rebirths) * Leveling.CostFractionOfNextRebirth[Dragons[d.SpeciesId].Rarity] end
	return DragonStats.GetLevelUpCost(d :: any, rebirths, anchor)
end

local function income(S: State): number
	return DragonStats.GetRoostIncome(S.Data)
end

-- Prefix sums cache the exact shared per-level calculation; never approximate bulk costs as unit x count.
local function bulkCost(S: State, d: Dragon, count: number): number
	local prefix = S.LevelCosts[d.SpeciesId]
	if prefix == nil then
		prefix = {0}
		local probe = table.clone(d)
		for level = 1, DragonStats.GetLevelCap(S.Data) do
			probe.Level = level
			prefix[level + 1] = prefix[level] + levelCost(probe, S.Data.Rebirths, S.Data.LevelingIncomeAnchor)
		end
		S.LevelCosts[d.SpeciesId] = prefix
	end
	return prefix[d.Level + count] - prefix[d.Level]
end

local function potionMultiplier(S: State): number
	if Variant.StackPotions and S.HoardMin > 0 and S.GildedMin > 0 then
		return 10
	elseif S.HoardMin > 0 then
		return 5
	elseif S.GildedMin > 0 then
		return 2
	end
	return 1
end

local function applyRunes(S: State)
	-- Rune/Stone on the best roost dragon (level-independent value), re-rolling until the result is good enough.
	local data = S.Data
	local best: Dragon? = nil
	local bestQ = -1
	for _, id in data.RoostDragonIds do
		local d = data.Dragons[id]
		local q = quality(d)
		if q > bestQ then
			best, bestQ = d, q
		end
	end
	if best == nil then
		return
	end
	local function roll(entries: { any }): any
		local w = Luck.GetTierWeights(entries, if S.RunebrightMin > 0 then Boosts.ById.RunebrightTonic.Multiplier else 1)
		local total = 0
		for _, x in w do
			total += x
		end
		local r = S.Rng:NextNumber() * total
		for i, e in entries do
			r -= w[i]
			if r < 0 then
				return e
			end
		end
		return entries[#entries]
	end
	-- stop re-rolling at a trait >= x1.3 income-ish or a grade >= x1.25
	while S.Runes > 0 do
		local t = DragonStats.GetTrait(best :: any)
		if t and t.Income * t.Power >= 1.5 then
			break
		end
		S.Runes -= 1
		best.Trait = roll(Traits.Traits).Id
		refreshQuality(best)
	end
	while S.Stones > 0 do
		local g = DragonStats.GetGrade(best :: any)
		if g and g.Multiplier >= 1.5 then
			break
		end
		S.Stones -= 1
		best.Grade = roll(Traits.Grades).Id
		refreshQuality(best)
	end
end

local function levelUpTo(S: State, d: Dragon, newLevel: number, t: number)
	progress(S, "Levels", newLevel - d.Level)
	while d.Level < newLevel do
		d.Level += 1
		for _, stage in Evolution.Stages do
			if stage.MinLevel == d.Level and stage.MinLevel > 1 then
				local evo = d.Evolutions or {}
				d.Evolutions = evo
				local const = constellationOf(S, nightIndex(t))
				evo[stage.Id] = if isNight(t) then const.Id else Evolution.DayBranchId
			end
		end
	end
end

local function rebirth(S: State)
	table.insert(S.RebirthDay, (S.Time - S.Origin) / DAY)
	S.Data.Rebirths += 1
	S.Data.Gold = 0
	for _, milestone in Milestones.Milestones do
		if S.Data.Rebirths == milestone.Rebirths and milestone.Perks.Champion then
			local champion: any = newDragon(S, Milestones.Champion.SpeciesId, nil)
			champion.Champion = true
			equip(S, champion) -- optional collection dragon, never adds an Index entry
		end
	end
	DragonStats.EnsureLevelingAnchor(S.Data)
	table.clear(S.LevelCosts)
	if S.Data.Rebirths >= 10 then
		local d = DragonStats.GetBestDragon(S.Data)
		if d and S.Data.LevelingIncomeAnchor > 0 then
			local probe = table.clone(d)
			probe.Level = DragonStats.GetLevelCap(S.Data) - Leveling.CapPerRebirth
			local _, c = DragonStats.GetBulkLevelCost(probe, Leveling.CapPerRebirth, DragonStats.GetLevelCap(S.Data), S.Data.Rebirths, S.Data.LevelingIncomeAnchor)
			table.insert(S.BandMinutes, c / S.Data.LevelingIncomeAnchor / 60)
			local hypothetical = table.clone(S.Data)
			hypothetical.Dragons = table.clone(S.Data.Dragons)
			hypothetical.Dragons[d.Id] = probe
			local seconds = 0
			for i = 1, Leveling.CapPerRebirth do
				seconds += DragonStats.GetLevelUpCost(probe, S.Data.Rebirths, S.Data.LevelingIncomeAnchor) / DragonStats.GetRetainedIncomeAnchor(hypothetical)
				probe.Level += 1
			end
			table.insert(S.ReinvestedBandMinutes, seconds / 60)
		end
	end
end

-- Spends gold: rebirth when affordable, otherwise the best-paying upgrade if it pays back soon enough.
local function spend(S: State, t: number, rate: number)
	local data = S.Data
	for _ = 1, 200 do
		local cost = rebirthCost(S)
		local atCap = data.Rebirths >= S.Cap
		if not atCap and data.Gold >= cost then
			rebirth(S)
			continue
		end
		if atCap and S.WeekBank == 0 then
			-- banked gold stops at one rebirth's cost
			data.Gold = math.min(data.Gold, cost)
		end
		local base = income(S)
		local mult = roostMultiplier(S)
		local perSec = base * potionMultiplier(S) -- what we really earn now (potions)
		local horizon = if atCap then 2 * DAY else math.max(0, cost - data.Gold) / math.max(perSec, 1e-9)
		horizon *= S.Profile.SpendK
		local cap = DragonStats.GetLevelCap(data)

		local bestPayback, bestCost = math.huge, 0
		local bestAction: any = nil
		-- levels
		for _, id in data.RoostDragonIds do
			local d: Dragon = data.Dragons[id]
			if d.Level < cap then
				local before = DragonStats.GetGoldPerSecond(d :: any)
				local stepsList = { 1 }
				for _, stage in Evolution.Stages do
					if stage.MinLevel > d.Level and stage.MinLevel <= cap then
						table.insert(stepsList, stage.MinLevel - d.Level)
						break
					end
				end
				table.insert(stepsList, cap - d.Level)
				for _, n in stepsList do
					local probe = table.clone(d)
					probe.Level = d.Level + n
					local gain = (DragonStats.GetGoldPerSecond(probe :: any) - before) * mult * potionMultiplier(S)
					local c = bulkCost(S, d, n)
					if gain > 0 then
						local pb = c / gain
						if pb < bestPayback then
							bestPayback, bestCost = pb, c
							bestAction = { Kind = "Level", Dragon = d, To = d.Level + n }
						end
					end
				end
			end
		end
		-- roost income upgrade
		local incomeCost = DragonStats.GetNextIncomeUpgradeCost(data)
		if incomeCost then
			local raw = base / math.max(roostMultiplier(S) / DragonStats.GetRoostIncomeMultiplier(data), 1e-9)
			local gain = raw * Economy.RoostUpgrades.IncomeBonusPerLevel * DragonStats.GetRebirthBonus(data.Rebirths)
				* DragonStats.GetIndexMultiplier(data) * potionMultiplier(S)
			if gain > 0 and incomeCost / gain < bestPayback then
				bestPayback, bestCost = incomeCost / gain, incomeCost
				bestAction = { Kind = "Income" }
			end
		end
		-- roost slot
		local slotCost = DragonStats.GetNextSlotCost(data)
		if slotCost then
			-- the next best dragon outside the roost
			local inRoost: { [string]: boolean } = {}
			for _, id in data.RoostDragonIds do
				inRoost[id] = true
			end
			local nextIncome = 0
			for id, d in data.Dragons do
				if not inRoost[id] then
					nextIncome = math.max(nextIncome, DragonStats.GetGoldPerSecond(d))
				end
			end
			local gain = nextIncome * mult * potionMultiplier(S)
			if gain > 0 and slotCost / gain < bestPayback then
				bestPayback, bestCost = slotCost / gain, slotCost
				bestAction = { Kind = "Slot" }
			end
		end

		if bestAction == nil or bestPayback > horizon or data.Gold < bestCost then
			break
		end
		data.Gold -= bestCost
		if bestAction.Kind == "Level" then
			S.UpgradeSpent += bestCost
			levelUpTo(S, bestAction.Dragon, bestAction.To, t)
		elseif bestAction.Kind == "Income" then
			data.RoostIncomeLevel += 1
		else
			data.RoostSlotUpgrades += 1
			equip(S)
		end
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Spire

local function matches(drop: any, floor: number): boolean
	if floor % drop.Every ~= (drop.Offset or 0) % drop.Every then
		return false
	end
	if drop.SkipBosses and DragonStats.IsBossFloor(floor) then
		return false
	end
	return true
end

local function giveDrops(S: State, drops: { any }, floor: number, mult: number)
	for _, drop in drops do
		if not matches(drop, floor) or S.Rng:NextNumber() >= (drop.Chance or 1) then
			continue
		end
		if drop.Potion then
			local potion = Boosts.ById[drop.Potion]
			if potion.Kind == "LuckCharge" then
				table.insert(S.Charges, potion.Multiplier)
			elseif potion.Stat == "Gold" then
				if potion.Id == "HoardElixir" then
					S.HoardMin = math.min(S.HoardMin + (potion.Minutes or 0), Boosts.MaxStoredMinutes)
				else
					S.GildedMin = math.min(S.GildedMin + (potion.Minutes or 0), Boosts.MaxStoredMinutes)
				end
			elseif potion.Stat == "SpirePower" then
				S.WyrmbloodMin = math.min(S.WyrmbloodMin + (potion.Minutes or 0), Boosts.MaxStoredMinutes)
			elseif potion.Stat == "SpireRewards" then
				S.ConquerorMin = math.min(S.ConquerorMin + (potion.Minutes or 0), Boosts.MaxStoredMinutes)
			elseif potion.Stat == "RollLuck" then
				S.RunebrightMin = math.min(S.RunebrightMin + (potion.Minutes or 0), Boosts.MaxStoredMinutes)
			end
		end
		local runes, stones = drop.WyrmRunes or 0, drop.Dragonstones or 0
		if drop.RuneOrStone then
			if S.Rng:NextNumber() < 0.5 then
				runes += 1
			else
				stones += 1
			end
		end
		S.Runes += runes * mult
		S.Stones += stones * mult
		S.RuneEarned += runes * mult
		S.StoneEarned += stones * mult
		S.Data.Stardust += (drop.Stardust or 0) * mult
	end
end

-- One Spire session of `minutes`; returns floors fought.
local function spire(S: State, t: number, minutes: number)
	local data = S.Data
	local seconds = minutes * 60
	while seconds >= S.FightLeft do
		local best, power = DragonStats.GetBestDragon(data)
		if best == nil then
			return
		end
		if S.WyrmbloodMin > 0 then
			power *= 2
		end
		local floor = S.Floor
		seconds -= S.FightLeft
		S.FightLeft = SpireConfig.FightSeconds
		local climbed = false
		do
			local enemy = DragonStats.GetEnemyPower(floor)
			if power < enemy then
				S.Floor = 1
				return
			end
			climbed = true
			local first = floor > S.SpireRecord
			local rewardMult = if S.ConquerorMin > 0 then Boosts.ById.ConquerorsBrew.Multiplier else 1
			giveDrops(S, SpireConfig.VictoryDrops, floor, rewardMult)
			if first then
				S.SpireRecord = floor
				giveDrops(S, SpireConfig.FirstClearDrops, floor, rewardMult)
				do
					local gold = income(S) * SpireConfig.FirstClearIncomeSeconds * rewardMult
					local limit = DragonStats.GetGoldBankLimit(data)
					if limit then
						gold = math.max(0, math.min(gold, limit - data.Gold))
					end
					data.Gold += gold
				end
			else
				giveDrops(S, SpireConfig.ReclearDrops, floor, rewardMult)
			end
			do
				S.SpireWinsToday += 1
				if S.SpireWinsToday >= BindingConfig.EchoSigilSpireWins and not S.SigilFromSpire then
					S.SigilFromSpire = true
					S.Sigils = math.min(S.Sigils + 1, sigilCap(S))
				end
			end
			S.Floor = if floor >= SpireConfig.MaxFloors then 1 else floor + 1
		end
	end
	S.FightLeft -= seconds
end

---------------------------------------------------------------------------------------------------------------------
-- One day

local function grantReward(S: State, r: any)
	S.Runes += r.WyrmRunes or 0
	S.Stones += r.Dragonstones or 0
	S.RuneEarned += r.WyrmRunes or 0
	S.StoneEarned += r.Dragonstones or 0
	S.Data.Stardust += r.Stardust or 0
	if r.Potions then
		S.GildedMin += 5 * (r.Potions.GildedDraught or 0)
		S.HoardMin += 5 * (r.Potions.HoardElixir or 0)
		for id, count in r.Potions do
			local p = Boosts.ById[id]
			if p and p.Kind == "LuckCharge" then for i = 1, count do table.insert(S.Charges, p.Multiplier) end end
		end
	end
end

local function chooseQuests(S: State, pool: {any}, count: number): {any}
	local available = table.clone(pool)
	local selected = {}
	for i = 1, count do
		local q = table.remove(available, S.Rng:NextInteger(1, #available))
		table.insert(selected, { Kind = q.Kind, Target = q.Target or math.max(1, income(S) * q.IncomeSeconds), Progress = 0, Done = false, Slot = i })
	end
	return selected
end

progress = function(S: State, kind: string, amount: number)
	for _, pair in {{S.Daily, Quests.DailyRewards}, {S.Weekly, Quests.WeeklyRewards}} do
		for _, q in pair[1] do
			if not q.Done and q.Kind == kind then
				q.Progress += amount
				if q.Progress >= q.Target then q.Done = true; grantReward(S, pair[2][q.Slot]) end
			end
		end
	end
	local all = #S.Daily > 0
	for _, q in S.Daily do all = all and q.Done end
	if all and not S.SigilFromQuests then
		S.SigilFromQuests = true
		S.Sigils = math.min(S.Sigils + 1, sigilCap(S))
	end
end

local function dailyQuests(S: State)
	local p = S.Profile
	S.Daily = chooseQuests(S, Quests.DailyPool, Quests.DailyCount)
	-- login streak
	S.Streak += 1
	local reward = Quests.StreakRewards[(S.Streak - 1) % #Quests.StreakRewards + 1]
	grantReward(S, reward)
end

local function weeklyQuests(S: State)
	S.Weekly = chooseQuests(S, Quests.WeeklyPool, Quests.WeeklyCount)
end

local function runDay(S: State, day: number)
	local p = S.Profile
	local data = S.Data
	local rng = S.Rng
	local startT = day * DAY
	S.SigilFromQuests, S.SigilFromSpire, S.SpireWinsToday = false, false, 0

	-- build today's timeline of segments
	local segs: { { Kind: string, From: number, To: number } } = {}
	local playing = rng:NextNumber() >= p.SkipDay
	if playing then
		for _, s in p.Active do
			local jitter = rng:NextInteger(-p.Jitter, p.Jitter)
			local from = math.clamp(s[1] + jitter, 0, 1380) * 60
			local len = s[2] * 60 * (0.85 + rng:NextNumber() * 0.3)
			table.insert(segs, { Kind = "Active", From = from, To = math.min(from + len, DAY) })
		end
		for _, s in p.Idle or {} do
			table.insert(segs, { Kind = "Idle", From = s[1] * 60, To = (s[1] + s[2]) * 60 })
		end
	end
	table.sort(segs, function(a, b)
		return a.From < b.From
	end)

	if playing then
		dailyQuests(S)
		if day % 7 == 0 then
			weeklyQuests(S)
		end
	end

	-- walk the day; gaps between segments are away time
	local allowance = RoostConfig.OfflineCapHours * 3600
	local offlineRate = RoostConfig.OfflineIncomeMultiplier * (if p.Afk2x then Products.AfkIncomeMultiplier else 1)
	local cursor = 0
	if day == 0 then
		S.Origin = if #segs > 0 then segs[1].From else 0 -- a new player starts playing at once: no offline time before
		cursor = S.Origin
	end
	local spireBudget = p.SpireMinutes * 60
	local function away(toSec: number, inGameIdle: boolean)
		local from = cursor
		if toSec <= from then
			return
		end
		local seconds = math.min(toSec - from, allowance)
		allowance -= seconds
		data.Gold += income(S) * offlineRate * seconds
		local limit = DragonStats.GetGoldBankLimit(data)
		if limit and data.Gold > limit then
			data.Gold = limit
		end
		-- Auto-bind while in the game: once per night, 60 s before it ends (idle in game, base luck)
		if p.AutoBind then
			local t0, t1 = startT + from, startT + toSec
			local n = nightIndex(t0)
			while true do
				local when = (n + 1) * CYCLE - Products.AutoBindSecondsLeft
				if when > t1 then
					break
				end
				local inWindow = false
				for _, w in p.Idle or {} do
					if when >= startT + w[1] * 60 and when < startT + (w[1] + w[2]) * 60 then inWindow = true end
				end
				if when >= t0 and inWindow then
					bind(S, when, true)
				end
				n += 1
			end
		end
		cursor = toSec
	end

	for _, seg in segs do
		away(seg.From, false)
		if seg.Kind == "Idle" then
			-- idle in the game: covered by the Active check-ins cutting it into pieces; count as idle away time
			cursor = math.max(cursor, seg.From)
			-- the Active check-ins inside split this; handled by treating idle as the background: nothing to do here
		else
			-- Active: income at the full rate, binds each night, spending
			local t = startT + seg.From
			local tEnd = startT + seg.To
			S.Time = t
			applyRunes(S)
			S.Floor, S.FightLeft = 1, SpireConfig.FightSeconds
			local lastBound = -1
			local sinceAuto = false
			while t < tEnd do
				local dt = math.min(STEP, tEnd - t)
				local mult = potionMultiplier(S)
				data.Gold += income(S) * mult * dt
				progress(S, "Gold", income(S) * mult * dt)
				if spireBudget > 0 then
					local fought = math.min(dt, spireBudget)
					spire(S, t, fought / 60)
					spireBudget -= fought
				end
				applyRunes(S)
				local limit = DragonStats.GetGoldBankLimit(data)
				if limit and data.Gold > limit then
					data.Gold = limit
				end
				local minutes = dt / 60
				S.HoardMin = math.max(0, S.HoardMin - minutes)
				S.GildedMin = math.max(0, S.GildedMin - minutes)
				S.WyrmbloodMin = math.max(0, S.WyrmbloodMin - minutes)
				S.ConquerorMin = math.max(0, S.ConquerorMin - minutes)
				S.RunebrightMin = math.max(0, S.RunebrightMin - minutes)
				t += dt
				S.Time = t
				-- bind once per night while it is night
				if isNight(t) and spireBudget <= 0 then
					local n = nightIndex(t)
					if lastBound ~= n then
						lastBound = n
						bind(S, t, false)
						if S.Sigils > 0 and rng:NextNumber() < 0.9 then
							S.Sigils -= 1
							bind(S, t, false, true)
						end
					end
				end
				if t - S.LastSpend >= 300 or data.Gold >= rebirthCost(S) then
					S.LastSpend = t
					spend(S, t, 1)
				end
			end
			cursor = seg.To
			-- leftover allowance logic continues below
		end
	end
	if playing then
		-- Auto-bind while idle in the game between check-ins: nights that fell in gaps within the Idle window
		-- (handled by away(...) only when the gap lies inside an Idle segment; see Sim.autoBindIdle)
	end
	away(DAY, false)
	S.Time = (day + 1) * DAY
end

---------------------------------------------------------------------------------------------------------------------
-- Idle auto-bind: PaidAfk is in the game between check-ins, so nights inside its Idle window bind at base luck.

---------------------------------------------------------------------------------------------------------------------
-- Public

export type Result = {
	DaysToCap: number?, -- fractional days until Rebirths reached Cap (nil if not within MaxDays)
	RebirthsAt: { [number]: number }, -- rebirth count at the end of day 1, 3, 7, 14, 28
	SpireAt7: number,
	Final: any,
}

local yieldClock = os.clock()

local function startRun(profileName: string, seed: number, cap: number?): State
	local profile = Sim.Profiles[profileName]
	local S = newState(profile, seed, cap or RebirthConfig.RebirthCap)
	-- the starter dragon (Config/Data.StarterDragon): a free Common
	local DataConfig = require(Config.Data)
	local starter = DataConfig.StarterDragon
	if starter then
		local d = newDragon(S, starter, nil)
		recordIndex(S, d)
		equip(S, d)
	end
	return S
end

-- Runs one player until Cap or MaxDays. If `weeks` is given, the update then raises the cap by WeeklyRebirths and the
-- player keeps going; returns the days each of those weekly bumps took.
function Sim.Run(profileName: string, seed: number, maxDays: number, weeks: number?): any
	local S = startRun(profileName, seed, nil)
	local result: any = { DaysToCap = nil, RebirthsAt = {}, Weekly = {}, Seed = seed }
	local checkpoints = { [1] = true, [3] = true, [7] = true, [14] = true, [28] = true }
	local capHitDay: number? = nil
	local weeksDone = 0
	for day = 0, maxDays - 1 do
		if os.clock() - yieldClock > 0.25 then
			task.wait() -- keep Studio responsive; the job runs in the background
			yieldClock = os.clock()
		end
		runDay(S, day)
		-- the cap may have been reached inside the day: find when
		if capHitDay == nil and S.Data.Rebirths >= S.Cap then
			capHitDay = S.RebirthDay[S.Cap] or (day + 1)
			result.DaysToCap = capHitDay
			if weeks == nil then
				break
			end
		end
		if checkpoints[day + 1] then
			result.RebirthsAt[day + 1] = S.Data.Rebirths
		end
		if day + 1 == 7 then
			result.SpireAt7 = S.SpireRecord
		end
		-- weekly updates: when the cap was hit, release +WeeklyRebirths and time the next block
		if weeks and capHitDay ~= nil and S.Data.Rebirths >= S.Cap and weeksDone < weeks then
			weeksDone += 1
			local t0 = S.RebirthDay[S.Cap] or (day + 1)
			S.Cap += RebirthConfig.WeeklyRebirths
			result.Weekly[weeksDone] = { Start = t0, Target = S.Cap }
		end
		for i, w in result.Weekly do
			if w.Days == nil and S.Data.Rebirths >= w.Target then
				w.Days = (S.RebirthDay[w.Target] or (day + 1)) - w.Start
			end
		end
		if weeks and weeksDone >= weeks and result.Weekly[weeks].Days ~= nil then
			break
		end
	end
	result.SpireRecord = S.SpireRecord
	result.RebirthDay = S.RebirthDay -- the day (fractional) of each rebirth, for the pacing curve
	for checkpoint in checkpoints do
		local count = 0
		for _, reached in S.RebirthDay do if reached <= checkpoint then count += 1 end end
		result.RebirthsAt[checkpoint] = count
	end
	result.Rebirths = S.Data.Rebirths
	result.Binds = S.Binds
	result.RunesEarned, result.StonesEarned, result.UpgradeSpent = S.RuneEarned, S.StoneEarned, S.UpgradeSpent
	result.BandMinutes = S.BandMinutes
	result.ReinvestedBandMinutes = S.ReinvestedBandMinutes
	return result
end

local function percentile(sorted: { number }, p: number): number
	if #sorted == 0 then
		return 0 / 0
	end
	local i = math.clamp(math.ceil(#sorted * p), 1, #sorted)
	return sorted[i]
end

-- Runs `runs` seeds of a cohort and summarizes days to the launch cap.
function Sim.Cohort(profileName: string, runs: number, maxDays: number, weeks: number?): any
	local days: { number } = {}
	local fails = 0
	local spire: { number } = {}
	local weekly: { { number } } = {}
	local rebirthsAt: { [number]: { number } } = {}
	local runes, stones, spent = {}, {}, {}
	local bands = {}
	local reinvested = {}
	for seed = 1, runs do
		local r = Sim.Run(profileName, seed * 7919, maxDays, weeks)
		table.insert(runes, r.RunesEarned); table.insert(stones, r.StonesEarned); table.insert(spent, r.UpgradeSpent)
		for _, minutes in r.BandMinutes do table.insert(bands, minutes) end
		for _, minutes in r.ReinvestedBandMinutes do table.insert(reinvested, minutes) end
		if r.DaysToCap then
			table.insert(days, r.DaysToCap)
		else
			fails += 1
		end
		table.insert(spire, r.SpireAt7 or r.SpireRecord or 0)
		for k, w in r.Weekly do
			weekly[k] = weekly[k] or {}
			table.insert(weekly[k], w.Days or maxDays)
		end
		for d, n in r.RebirthsAt do
			rebirthsAt[d] = rebirthsAt[d] or {}
			table.insert(rebirthsAt[d], n)
		end
	end
	table.sort(days)
	table.sort(spire)
	table.sort(runes); table.sort(stones); table.sort(spent)
	table.sort(bands)
	table.sort(reinvested)
	local summary: any = {
		Profile = profileName,
		Runs = runs,
		NotCapped = fails,
		MedianDays = percentile(days, 0.5),
		P10Days = percentile(days, 0.1),
		P90Days = percentile(days, 0.9),
		SpireDay7Median = percentile(spire, 0.5),
		Weekly = {},
		RebirthsDay7 = nil,
		MedianRunesEarned = percentile(runes, 0.5), MedianStonesEarned = percentile(stones, 0.5), MedianUpgradeSpent = percentile(spent, 0.5),
		BandMinutesMedian = percentile(bands, 0.5), BandMinutesP10 = percentile(bands, 0.1), BandMinutesP90 = percentile(bands, 0.9),
		ReinvestedBandMinutesMedian = percentile(reinvested, 0.5), ReinvestedBandMinutesP10 = percentile(reinvested, 0.1), ReinvestedBandMinutesP90 = percentile(reinvested, 0.9),
	}
	for k, list in weekly do
		table.sort(list)
		summary.Weekly[k] = percentile(list, 0.5)
	end
	for d, list in rebirthsAt do
		table.sort(list)
		summary["RebirthsDay" .. d] = percentile(list, 0.5)
	end
	return summary
end

-- Median day of every rebirth number (the pacing curve): { [rebirthNumber] = days }.
function Sim.Curve(profileName: string, runs: number, maxDays: number): { [number]: number }
	local per: { [number]: { number } } = {}
	for seed = 1, runs do
		local r = Sim.Run(profileName, seed * 7919, maxDays)
		for n, day in r.RebirthDay do
			per[n] = per[n] or {}
			table.insert(per[n], day)
		end
	end
	local curve = {}
	for n, list in per do
		table.sort(list)
		curve[n] = math.floor(percentile(list, 0.5) * 100 + 0.5) / 100
	end
	return curve
end

-- Background job: runs a cohort without blocking Studio and stores the JSON summary in a StringValue
-- ServerStorage.SimTools.Result_<jobName> ("running" until it is done).
function Sim.Start(jobName: string, profileName: string, runs: number, maxDays: number, weeks: number?)
	local folder = ServerStorage:FindFirstChild("SimTools") :: Folder
	local out = folder:FindFirstChild("Result_" .. jobName) :: StringValue?
	if out == nil then
		out = Instance.new("StringValue")
		out.Name = "Result_" .. jobName
		out.Parent = folder
	end
	local box = out :: StringValue
	box.Value = "running"
	task.spawn(function()
		local started = os.clock()
		local ok, result = pcall(Sim.Cohort, profileName, runs, maxDays, weeks)
		if ok then
			result.Seconds = math.floor(os.clock() - started)
			box.Value = HttpService:JSONEncode(result)
		else
			box.Value = "ERR " .. tostring(result)
		end
	end)
end

-- A single run with a daily log (for debugging a profile).
function Sim.Trace(profileName: string, seed: number, days: number): { string }
	local S = startRun(profileName, seed, nil)
	local lines = {}
	for day = 0, days - 1 do
		runDay(S, day)
		local best = DragonStats.GetBestDragon(S.Data)
		table.insert(lines, string.format(
			"day %2d R%-3d gold %.2e income %.2e/s binds %d slots %d incLv %d runes %d sig %d spire %d best %s L%d",
			day + 1, S.Data.Rebirths, S.Data.Gold, income(S), S.Binds, slots(S), S.Data.RoostIncomeLevel, S.Runes,
			S.Sigils, S.SpireRecord, if best then best.SpeciesId else "-", if best then best.Level else 0))
	end
	return lines
end

---------------------------------------------------------------------------------------------------------------------
-- Config patching (in memory only; nothing is saved). Sim.Set("Rebirth", "LateGrowth", 2.2) edits the live module
-- table until Sim.Reset(). Sim.Preset("Old") loads the economy approved before the mutation branch.

local undo: { () -> () } = {}

local modules: { [string]: any } = {
	Rebirth = RebirthConfig, Leveling = Leveling, Index = IndexConfig, Economy = Economy, Boosts = Boosts, Luck = LuckConfig,
	Roost = RoostConfig, Spire = SpireConfig, Binding = BindingConfig, Evolution = Evolution,
}

function Sim.Set(moduleName: string, key: string, value: any)
	local t = modules[moduleName]
	local old = t[key]
	t[key] = value
	table.insert(undo, function()
		t[key] = old
	end)
end

-- Species stats by id (or by rarity with Sim.SetRarity).
function Sim.SetSpecies(speciesId: string, field: string, value: number)
	local sp = (Dragons :: any)[speciesId]
	local old = sp[field]
	sp[field] = value
	table.insert(undo, function()
		sp[field] = old
	end)
end

function Sim.SetRarity(rarity: string, field: string, value: number)
	for id, sp in Dragons do
		if sp.Rarity == rarity then
			Sim.SetSpecies(id, field, value)
		end
	end
end

function Sim.SetTrait(id: string, income: number, power: number)
	for _, t in Traits.Traits do
		if t.Id == id then
			local oi, op = t.Income, t.Power
			t.Income, t.Power = income, power
			table.insert(undo, function()
				t.Income, t.Power = oi, op
			end)
		end
	end
end

function Sim.SetGrade(id: string, multiplier: number)
	for _, g in Traits.Grades do
		if g.Id == id then
			local old = g.Multiplier
			g.Multiplier = multiplier
			table.insert(undo, function()
				g.Multiplier = old
			end)
		end
	end
end

function Sim.SetMutation(id: string, field: string, value: number)
	for _, m in Mutations.Mutations do
		if m.Id == id then
			local old = (m :: any)[field]
			;(m :: any)[field] = value
			table.insert(undo, function()
				(m :: any)[field] = old
			end)
		end
	end
end

function Sim.SetVariant(key: string, value: boolean)
	local old = (Variant :: any)[key]
	;(Variant :: any)[key] = value
	table.insert(undo, function()
		(Variant :: any)[key] = old
	end)
end

function Sim.Reset()
	for i = #undo, 1, -1 do
		undo[i]()
	end
	table.clear(undo)
end

function Sim.Preset(name: string)
	Sim.Reset()
	if name ~= "Old" then
		return
	end
	-- the economy approved in the economy rebalance (before the mutation branch)
	Sim.SetRarity("Common", "BaseGoldPerSecond", 750); Sim.SetRarity("Rare", "BaseGoldPerSecond", 1800)
	Sim.SetRarity("Epic", "BaseGoldPerSecond", 4400); Sim.SetRarity("Legendary", "BaseGoldPerSecond", 11000)
	Sim.SetRarity("Mythic", "BaseGoldPerSecond", 29000)
	Sim.SetRarity("Common", "BasePower", 10); Sim.SetRarity("Rare", "BasePower", 25); Sim.SetRarity("Epic", "BasePower", 60)
	Sim.SetRarity("Legendary", "BasePower", 150); Sim.SetRarity("Mythic", "BasePower", 400)
	local traitsOld = {
		Hoarder = { 1.25, 1 }, Scalebound = { 1, 1.25 }, Swiftwing = { 1.15, 1.15 }, Gilded = { 1.75, 1 }, Ironhide = { 1, 1.75 },
		Emberheart = { 1.5, 1.5 }, Goldhoard = { 3, 1 }, Stormcaller = { 1, 3 }, Ancient = { 5, 5 }, Celestial = { 10, 10 },
		Dragonlord = { 25, 25 },
	}
	for id, v in traitsOld do
		Sim.SetTrait(id, v[1], v[2])
	end
	for id, m in { D = 1, C = 1.5, B = 2, A = 3, S = 5, SS = 10, SSS = 25 } do
		Sim.SetGrade(id, m)
	end
	Sim.Set("Rebirth", "LateGrowth", 2.69); Sim.Set("Rebirth", "CurveEnd", 50); Sim.Set("Rebirth", "RebirthCap", 50)
	Sim.Set("Rebirth", "WeeklyRebirths", 5); Sim.Set("Rebirth", "WeeklyJump", 2.2)
	Sim.Set("Index", "IncomePerEntry", 0.01); Sim.Set("Index", "ElementMultiplier", 1.3); Sim.Set("Index", "AllSpeciesMultiplier", 1.5)
	local up = Economy.RoostUpgrades
	local old = up.IncomeBonusPerLevel
	up.IncomeBonusPerLevel = 0.10
	table.insert(undo, function()
		up.IncomeBonusPerLevel = old
	end)
	Sim.Set("Boosts", "GoldPotionCap", math.huge)
	Sim.SetVariant("OldBind", true)
	Sim.SetVariant("OldLevelCost", true)
	Sim.SetVariant("StackPotions", true)
	-- Starborn as a mutation id (x3 income, x2 power)
	local byId: any = Mutations.ById
	byId.Starborn = { Id = "Starborn", IncomeMultiplier = 3, PowerMultiplier = 2 }
	table.insert(undo, function()
		byId.Starborn = nil
	end)
end

return Sim
