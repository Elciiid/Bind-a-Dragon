--!strict
-- Dragon leveling with gold (the main gold sink).
--   Level cap           = CapBase + CapPerRebirth x rebirths
--   Income at level L   = base x IncomePerLevel ^ (L - 1)        (compounding)
--   Power at level L    = base x PowerPerLevel ^ (L - 1)
--   Cost of next level  = rebirth-relative baseline x CostGrowthPerLevel ^ band-relative level
-- After rebirth, the baseline also floors the latest five-level band's price at retained unboosted income x900s.
-- The server snapshots the strongest legal owned roost once per rebirth; moving dragons cannot discount prices.

return {
	CapBase = 50,
	CapPerRebirth = 5,

	IncomePerLevel = 1.06, -- income x1.06 per level
	PowerPerLevel = 1.05, -- Spire power x1.05 per level
	CostGrowthPerLevel = 1.08, -- each successive level costs 8% more within the current rebirth
	RetainedIncomeBandSeconds = 900, -- latest five-level band costs at least 15 minutes of snapshotted unboosted income

	CostFractionOfNextRebirth = {
		Common = 0.0020,
		Rare = 0.0025,
		Epic = 0.0030,
		Legendary = 0.0035,
		Mythic = 0.0040,
	} :: { [string]: number },

	MaxLevelsPerRequest = 100, -- most levels one "level up xN" request can buy
}
