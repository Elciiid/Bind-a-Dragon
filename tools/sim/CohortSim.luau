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

local Sim = {}

export type Profile = {
	Name: string,
	Active: { { number } }, -- { startMinuteOfDay, minutes }: playing (binds every night, spends gold, Spire, quests)
	Idle: { { number } }?, -- in the game but idle: earns the offline rate, Auto-bind works (only with the pass)
	Jitter: number, -- minutes each session start moves around
	SkipDay: number, -- chance of playing no active session on a day
	SpireMinutes: number, -- Spire time inside the first active session
	QuestRate: number, -- chance each daily quest gets done
	AutoBind: boolean,
	Afk2x: boolean,
	SpendK: number, -- buy an upgrade only if it pays back within this share of the time left to the next rebirth
}

Sim.Profiles = {
	Dedicated = {
		Name = "Dedicated", Active = { { 660, 110 }, { 1140, 100 } }, Jitter = 60, SkipDay = 0.03,
		SpireMinutes = 25, QuestRate = 0.95, AutoBind = false, Afk2x = false, SpendK = 0.6,
	},
	Casual = {
		Name = "Casual", Active = { { 1140, 60 } }, Jitter = 90, SkipDay = 0.25,
		SpireMinutes = 8, QuestRate = 0.6, AutoBind = false, Afk2x = false, SpendK = 0.6,
	},
	AfkOnly = {
		Name = "AfkOnly", Active = { { 1140, 12 } }, Jitter = 120, SkipDay = 0.10,
		SpireMinutes = 0, QuestRate = 0.25, AutoBind = false, Afk2x = false, SpendK = 0.6,
	},
	PaidAfk = {
		-- Auto-bind + 2x AFK Income: in the game ~12 h a day, 12 five-minute check-ins.
		Name = "PaidAfk", Active = {}, Jitter = 45, SkipDay = 0.05,
		SpireMinutes = 5, QuestRate = 0.5, AutoBind = true, Afk2x = true, SpendK = 0.6,
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
}

local rarityRank: { [string]: number } = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }

local function newState(profile: Profile, seed: number, cap: number): State
	local data = {
		Dragons = {}, RoostDragonIds = {}, Rebirths = 0, Gold = 0,
		RoostSlotUpgrades = 0, RoostIncomeLevel = 0, Index = {}, MutationIndex = {}, ActiveBoosts = {},
	}
	local S: State = {
		Rng = Random.new(seed), Profile = profile, Data = data, Cap = cap, Time = 0, Runes = 0, Stones = 0, Sigils = 0,
		GildedMin = 0, HoardMin = 0, Charges = {}, WyrmbloodMin = 0, SpireRecord = 0, Streak = 0, SpireWinsToday = 0,
		SigilFromQuests = false, SigilFromSpire = false, NightConst = {}, Binds = 0, RebirthDay = {},
		IndexMilestones = 0, ElementsRewarded = {}, NextId = 1, WeekBank = 0, LastBindNight = -1, CostRebirths = -1, CostValue = 0, LastSpend = -1e9,
	}
	return S
end

local function newDragon(S: State, speciesId: string, mutationId: string?): Dragon
	local d: Dragon = { Id = tostring(S.NextId), SpeciesId = speciesId, Level = 1, MutationId = mutationId }
	S.NextId += 1
	S.Data.Dragons[d.Id] = d
	return d
end

-- Level-independent value of a dragon (what it would earn at equal levels).
local function quality(d: Dragon): number
	local probe = table.clone(d)
	probe.Level = 1
	probe.Evolutions = nil
	return DragonStats.GetGoldPerSecond(probe :: any)
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

-- Keeps the roost filled with the best dragons; a replacement must be clearly better than the dragon it replaces.
local function equip(S: State)
	local data = S.Data
	local n = slots(S)
	local inRoost: { [string]: boolean } = {}
	for _, id in data.RoostDragonIds do
		inRoost[id] = true
	end
	local others: { Dragon } = {}
	for id, d in data.Dragons do
		if not inRoost[id] then
			table.insert(others, d)
		end
	end
	table.sort(others, function(a, b)
		return quality(a) > quality(b)
	end)
	for _, d in others do
		if #data.RoostDragonIds < n then
			table.insert(data.RoostDragonIds, d.Id)
		else
			-- the weakest roost dragon by quality
			local weakIndex, weakQ = 0, math.huge
			for i, id in data.RoostDragonIds do
				local q = quality(data.Dragons[id])
				if q < weakQ then
					weakIndex, weakQ = i, q
				end
			end
			if quality(d) > weakQ * 1.5 then
				data.RoostDragonIds[weakIndex] = d.Id
			else
				break
			end
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
	local outcome = BindingOdds.Roll(S.Rng, areaId, element, luck)
	if outcome == nil then
		return
	end
	S.Binds += 1
	local mutationId = if outcome.MutationId ~= Mutations.NormalId then outcome.MutationId else nil
	local d = newDragon(S, outcome.SpeciesId, mutationId)
	recordIndex(S, d)
	equip(S)
end

---------------------------------------------------------------------------------------------------------------------
-- Income and spending

local function roostMultiplier(S: State): number
	return DragonStats.GetRoostIncomeMultiplier(S.Data)
		* DragonStats.GetRebirthBonus(S.Data.Rebirths)
		* DragonStats.GetIndexMultiplier(S.Data)
end

local function income(S: State): number
	return DragonStats.GetRoostIncome(S.Data)
end

local function potionMultiplier(S: State): number
	if S.HoardMin > 0 then
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
		local w = Luck.GetTierWeights(entries, 1)
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
	end
	while S.Stones > 0 do
		local g = DragonStats.GetGrade(best :: any)
		if g and g.Multiplier >= 1.5 then
			break
		end
		S.Stones -= 1
		best.Grade = roll(Traits.Grades).Id
	end
end

local function levelUpTo(S: State, d: Dragon, newLevel: number, t: number)
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
	table.insert(S.RebirthDay, S.Time / DAY)
	S.Data.Rebirths += 1
	S.Data.Gold = 0
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
				local unit = DragonStats.GetLevelUpCost(d :: any, data.Rebirths)
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
					local c = unit * n
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
	end
end

-- One Spire session of `minutes`; returns floors fought.
local function spire(S: State, t: number, minutes: number)
	local data = S.Data
	local seconds = minutes * 60
	if S.WyrmbloodMin > 0 then
		-- use a stored Wyrmblood for this session if we have one (10 min); good enough for the model
	end
	while seconds > 0 do
		local best, power = DragonStats.GetBestDragon(data)
		if best == nil then
			return
		end
		if S.WyrmbloodMin > 0 then
			power *= 2
			S.WyrmbloodMin = math.max(0, S.WyrmbloodMin - seconds / 60)
		end
		local floor = 1
		local fastUntil = math.max(0, S.SpireRecord - SpireConfig.TopWindow)
		seconds -= fastUntil * SpireConfig.FastFloorSeconds
		floor = fastUntil + 1
		local climbed = false
		while floor <= SpireConfig.MaxFloors and seconds > 0 do
			local enemy = DragonStats.GetEnemyPower(floor)
			local fast = power >= enemy * SpireConfig.PowerFastRatio
			seconds -= if fast then SpireConfig.FastFloorSeconds else SpireConfig.FightSeconds
			if power < enemy then
				break
			end
			climbed = true
			local first = floor > S.SpireRecord
			if first then
				S.SpireRecord = floor
				giveDrops(S, SpireConfig.FirstClearDrops, floor, 1)
				if not fast then
					local gold = income(S) * SpireConfig.FirstClearIncomeSeconds
					local limit = DragonStats.GetGoldBankLimit(data)
					if limit then
						gold = math.max(0, math.min(gold, limit - data.Gold))
					end
					data.Gold += gold
				end
			elseif not fast then
				giveDrops(S, SpireConfig.ReclearDrops, floor, 1)
			end
			if not fast then
				S.SpireWinsToday += 1
				if S.SpireWinsToday >= BindingConfig.EchoSigilSpireWins and not S.SigilFromSpire then
					S.SigilFromSpire = true
					S.Sigils = math.min(S.Sigils + 1, BindingConfig.EchoSigilCap)
				end
			end
			floor += 1
		end
		if not climbed then
			seconds -= 60 -- walked up and lost straight away: time passes
		else
			seconds -= 20 -- walk back to start the next climb
		end
	end
end

---------------------------------------------------------------------------------------------------------------------
-- One day

local function dailyQuests(S: State)
	local p = S.Profile
	local done = 0
	for _ = 1, Quests.DailyCount do
		if S.Rng:NextNumber() < p.QuestRate then
			done += 1
		end
	end
	for slot = 1, done do
		local r = Quests.DailyRewards[slot]
		if r then
			S.Runes += r.WyrmRunes or 0
			S.Stones += r.Dragonstones or 0
			if r.Potions and r.Potions.GildedDraught then
				S.GildedMin += 5 * r.Potions.GildedDraught
			end
		end
	end
	if done >= Quests.DailyCount and not S.SigilFromQuests then
		S.SigilFromQuests = true
		S.Sigils = math.min(S.Sigils + 1, BindingConfig.EchoSigilCap)
	end
	-- login streak
	S.Streak += 1
	local reward = Quests.StreakRewards[(S.Streak - 1) % #Quests.StreakRewards + 1]
	S.Runes += reward.WyrmRunes or 0
	S.Stones += reward.Dragonstones or 0
	if reward.Potions then
		S.GildedMin += 5 * (reward.Potions.GildedDraught or 0)
		S.HoardMin += 5 * (reward.Potions.HoardElixir or 0)
		if reward.Potions.MoonfireTonic then
			table.insert(S.Charges, Boosts.ById.MoonfireTonic.Multiplier)
		end
	end
end

local function weeklyQuests(S: State)
	local p = S.Profile
	for slot = 1, Quests.WeeklyCount do
		if S.Rng:NextNumber() < math.min(1, p.QuestRate * 1.2) then
			local r = Quests.WeeklyRewards[slot]
			if r then
				S.Runes += r.WyrmRunes or 0
				S.Stones += r.Dragonstones or 0
				if r.Potions and r.Potions.HoardElixir then
					S.HoardMin += 5 * r.Potions.HoardElixir
				end
			end
		end
	end
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
	local spired = false
	local function away(toSec: number, inGameIdle: boolean)
		local from = cursor
		if toSec <= from then
			return
		end
		local seconds = math.min(toSec - from, allowance)
		allowance -= seconds
		-- income is flat while away; use the current value
		data.Gold += income(S) * offlineRate * seconds
		local limit = DragonStats.GetGoldBankLimit(data)
		if limit and data.Gold > limit then
			data.Gold = limit
		end
		-- Auto-bind while in the game: once per night, 60 s before it ends (idle in game, base luck)
		if inGameIdle and p.AutoBind then
			local t0, t1 = startT + from, startT + toSec
			local n = nightIndex(t0)
			while true do
				local when = (n + 1) * CYCLE - Products.AutoBindSecondsLeft
				if when > t1 then
					break
				end
				if when >= t0 then
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
			if not spired and p.SpireMinutes > 0 then
				spired = true
				spire(S, t, p.SpireMinutes)
				equip(S)
			end
			local lastBound = -1
			local sinceAuto = false
			while t < tEnd do
				local dt = math.min(STEP, tEnd - t)
				local mult = potionMultiplier(S)
				data.Gold += income(S) * mult * dt
				local limit = DragonStats.GetGoldBankLimit(data)
				if limit and data.Gold > limit then
					data.Gold = limit
				end
				local minutes = dt / 60
				S.HoardMin = math.max(0, S.HoardMin - minutes)
				if S.HoardMin == 0 then
					S.GildedMin = math.max(0, S.GildedMin - minutes)
				end
				t += dt
				S.Time = t
				-- bind once per night while it is night
				if isNight(t) then
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

local function autoBindWindow(S: State, day: number)
	local p = S.Profile
	if not p.AutoBind or p.Idle == nil then
		return
	end
	for _, w in p.Idle do
		local t0, t1 = day * DAY + w[1] * 60, day * DAY + (w[1] + w[2]) * 60
		local n = nightIndex(t0)
		while true do
			local when = (n + 1) * CYCLE - Products.AutoBindSecondsLeft
			if when > t1 then
				break
			end
			if when >= t0 then
				bind(S, when, true)
			end
			n += 1
		end
	end
end

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
		equip(S)
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
		autoBindWindow(S, day)
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
	result.Rebirths = S.Data.Rebirths
	result.Binds = S.Binds
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
	for seed = 1, runs do
		local r = Sim.Run(profileName, seed * 7919, maxDays, weeks)
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
		autoBindWindow(S, day)
		runDay(S, day)
		local best = DragonStats.GetBestDragon(S.Data)
		table.insert(lines, string.format(
			"day %2d R%-3d gold %.2e income %.2e/s binds %d slots %d incLv %d runes %d sig %d spire %d best %s L%d",
			day + 1, S.Data.Rebirths, S.Data.Gold, income(S), S.Binds, slots(S), S.Data.RoostIncomeLevel, S.Runes,
			S.Sigils, S.SpireRecord, if best then best.SpeciesId else "-", if best then best.Level else 0))
	end
	return lines
end

return Sim
