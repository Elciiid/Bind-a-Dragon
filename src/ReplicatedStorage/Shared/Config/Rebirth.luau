--!strict
-- Rebirth: resets gold only (dragons, levels, evolutions, traits, grades, Stardust, roost upgrades are kept).
-- Each rebirth gives a permanent income bonus and +5 level cap (Config/Leveling), and counts toward area unlocks
-- (Config/Areas RebirthsRequired). Tuned by simulation for ~8 days to this week's cap for a dedicated player.
--
-- Cost of rebirth number r (1-based), open-ended:
--   r <= EarlyUntil:            FirstCost x EarlyGrowth ^ (r - 1)
--   EarlyUntil < r <= CurveEnd: ... x LateGrowth ^ (r - EarlyUntil)
--   r > CurveEnd: each three-rebirth weekly band starts with WeeklyJump, then uses WeeklyGrowth twice
-- WeeklyGrowth = IncomeBonusPerRebirth x Leveling.IncomePerLevel ^ Leveling.CapPerRebirth x WeeklyGrowthStep,
-- i.e. the same as income growth per rebirth, so each post-launch rebirth takes about the same play time.
-- PLACEHOLDER numbers.

return {
	FirstCost = 50e6, -- R1: a new player rebirths ~5 min into their first session
	EarlyGrowth = 3.71, -- R2..R10: fast early rebirths (R5 ~20 min, R10 ~35 min)
	EarlyUntil = 10,
	LateGrowth = 2.95, -- R11..R30: tuned for a ~10-day dedicated launch curve

	-- The launch curve ends here. NEVER change this after launch: weekly updates raise RebirthCap instead.
	CurveEnd = 30,
	-- The highest rebirth currently allowed. Raise by WeeklyRebirths with each weekly update.
	RebirthCap = 30,
	WeeklyRebirths = 3, -- each weekly release adds exactly three rebirths
	-- Past CurveEnd: a one-time extra step, then growth equal to income growth.
	WeeklyJump = 3.0,
	-- Extra 2% per post-launch rebirth. Offsets slow income growth that doesn't come from rebirths (traits, grades,
	-- Dragon Index), so post-launch rebirths don't get shorter week after week.
	WeeklyGrowthStep = 1.02,

	IncomeBonusPerRebirth = 1.59, -- permanent roost income x1.59 per rebirth, multiplying (R10 ≈ x103, R50 ≈ x11.6B)
}
