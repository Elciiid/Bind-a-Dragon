--!strict
-- Dragon leveling with gold (the main gold sink).
--   Level cap           = CapBase + CapPerRebirth x rebirths
--   Income at level L   = base x IncomePerLevel ^ (L - 1)        (compounding)
--   Power at level L    = base x PowerPerLevel ^ (L - 1)
--   Cost of next level  = next rebirth cost x CostFractionOfNextRebirth[rarity]
-- This keeps each newly unlocked five-level band meaningful at every point in progression.
-- PLACEHOLDER numbers.

return {
	CapBase = 50,
	CapPerRebirth = 5,

	IncomePerLevel = 1.06, -- income x1.06 per level
	PowerPerLevel = 1.05, -- Spire power x1.05 per level

	CostFractionOfNextRebirth = {
		Common = 0.0020,
		Rare = 0.0025,
		Epic = 0.0030,
		Legendary = 0.0035,
		Mythic = 0.0040,
	} :: { [string]: number },

	MaxLevelsPerRequest = 100, -- most levels one "level up xN" request can buy
}
