--!strict
-- Dragon leveling with gold (the main gold sink).
--   Level cap           = CapBase + CapPerRebirth x rebirths
--   Income at level L   = base x IncomePerLevel ^ (L - 1)        (compounding)
--   Power at level L    = base x PowerPerLevel ^ (L - 1)
--   Cost of next level  = BaseCost[rarity] x CostGrowth ^ (L - 1) x Rebirth.IncomeBonusPerRebirth ^ rebirths
-- Costs scale with the rebirth bonus so each rebirth's new levels cost about the same share of income:
-- levelling stays a real gold sink instead of snowballing.
-- PLACEHOLDER numbers.

return {
	CapBase = 50,
	CapPerRebirth = 5,

	IncomePerLevel = 1.06, -- income x1.06 per level
	PowerPerLevel = 1.05, -- Spire power x1.05 per level

	BaseCost = {
		Common = 1_000,
		Rare = 5_000,
		Epic = 20_000,
		Legendary = 100_000,
		Mythic = 500_000,
	} :: { [string]: number },
	CostGrowth = 1.08, -- each level costs 8% more than the last (just above income growth)

	MaxLevelsPerRequest = 100, -- most levels one "level up xN" request can buy
}
