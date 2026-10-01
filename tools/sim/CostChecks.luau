--!strict
-- Deterministic assertions against the same shared calculations used by server purchases and UI quotes.
local Shared = game:GetService("ReplicatedStorage").Shared
local Stats = require(Shared.DragonStats)
local Dragons = require(Shared.Config.Dragons)
local Leveling = require(Shared.Config.Leveling)
local Spire = require(Shared.Config.Spire)

return function()
	local checked = 0
	for speciesId in Dragons do
		for _, r in {0, 1, 10, 20, 30} do
			local cap = Leveling.CapBase + Leveling.CapPerRebirth * r
			local dragon: any = {Id = "1", SpeciesId = speciesId, Level = 1, ObtainedAt = 0}
			local anchor = 1e6
			local previous, total = 0, 0
			for level = 1, cap - 1 do
				dragon.Level = level
				local cost = Stats.GetLevelUpCost(dragon, r, anchor)
				assert(cost > previous and cost < math.huge, "level costs must rise")
				previous, total = cost, total + cost
				checked += 1
			end
			dragon.Level = 1
			local levels, bulk = Stats.GetBulkLevelCost(dragon, cap, cap, r, anchor)
			assert(levels == cap - 1 and bulk == total, "bulk quote differs from individual purchases")
			if r > 0 then
				dragon.Level = cap - 5
				local _, band = Stats.GetBulkLevelCost(dragon, 5, cap, r, anchor)
				assert(band >= anchor * Leveling.RetainedIncomeBandSeconds, "band income floor")
			end
		end
	end
	local data: any = {
		Rebirths = 10, Dragons = { ["1"] = {Id = "1", SpeciesId = "Solflare", Level = 90, ObtainedAt = 0, MutationId = "Hoardscale", Trait = "Gilded", Grade = "A"}},
		RoostDragonIds = {"1"}, RoostSlotUpgrades = 0, RoostIncomeLevel = 5, Index = {Solflare = 0}, ActiveBoosts = {},
		LevelingIncomeAnchor = 0, LevelingAnchorRebirth = -1,
	}
	Stats.EnsureLevelingAnchor(data)
	local anchor = data.LevelingIncomeAnchor
	data.RoostDragonIds = {}
	data.ActiveBoosts.HoardElixir = 600
	assert(Stats.GetRetainedIncomeAnchor(data) == anchor, "placement/potions changed hypothetical income")
	data.Dragons["1"].Level = 95
	Stats.EnsureLevelingAnchor(data)
	assert(data.LevelingIncomeAnchor == anchor, "anchor changed within a rebirth")
	data.Rebirths += 1
	Stats.EnsureLevelingAnchor(data)
	assert(data.LevelingIncomeAnchor > anchor and data.LevelingAnchorRebirth == 11, "rebirth did not refresh retained anchor")
	local function sumCurrency(drops: {any}): (number, number)
		local runes, stones = 0, 0
		for floor = 1, Spire.MaxFloors do
			for _, drop in drops do
				if floor % drop.Every == (drop.Offset or 0) % drop.Every and not (drop.SkipBosses and floor % Spire.BossEvery == 0) then
					runes += drop.WyrmRunes or 0
					stones += drop.Dragonstones or 0
				end
			end
		end
		return runes, stones
	end
	local repeatRunes, repeatStones = sumCurrency(Spire.VictoryDrops)
	local firstRunes, firstStones = sumCurrency(Spire.FirstClearDrops)
	assert(repeatRunes == 10 and repeatStones == 10, "repeat run currency differs from approved 10 each")
	assert(firstRunes + repeatRunes == 30 and firstStones + repeatStones == 30, "first run currency differs from approved 30 each")
	return {PerLevelChecks = checked, Scenarios = 100, AnchorChecks = 3, SpireRewardChecks = 2}
end
