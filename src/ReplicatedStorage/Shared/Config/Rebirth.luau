--!strict
-- Rebirth: resets gold only (dragons, levels, evolutions, Stardust are kept). Each rebirth raises the level cap and
-- unlocks areas (see Config/Areas: RebirthsRequired, LevelCap).
-- Cost of the next rebirth = BaseCost x CostGrowth ^ (rebirths done so far)
-- With these numbers: 10M, 50M, 250M, 1.25B, ... ~19.5T for the 10th. Deliberately expensive to lengthen play.
-- PLACEHOLDER numbers.

return {
	BaseCost = 10_000_000,
	CostGrowth = 5,
}
