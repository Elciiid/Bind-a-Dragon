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
-- scaled by WeeklyGrowthStep. Retuned with tools/sim (docs/Economy_Retune_Proposal.md).
-- PLACEHOLDER numbers.

return {
	FirstCost = 50e6, -- R1: a new player rebirths ~5 min into their first session
	EarlyGrowth = 5.0, -- R2..R10: quick early rebirths (R10 within the first day)
	EarlyUntil = 10,
	LateGrowth = 2.55, -- R11..R30: tuned with tools/sim for ~8 days to R30 for a Dedicated player (very sensitive: +0.05 = +2-3 days)

	-- The launch curve ends here. NEVER change this after launch: weekly updates raise RebirthCap instead.
	CurveEnd = 30,
	-- The highest rebirth currently allowed. Raise by WeeklyRebirths with each weekly update.
	RebirthCap = 30,
	WeeklyRebirths = 3, -- each weekly release adds exactly three rebirths
	-- Past CurveEnd: a one-time extra step, then growth equal to income growth.
	WeeklyJump = 4.8, -- the first rebirth of each weekly block costs this much more (then WeeklyGrowth twice)
	-- Multiplies the weekly growth of the two cheaper rebirths in each block. Below 1 because the big jump carries most of
	-- the block (sim: each weekly +3 takes a Dedicated player ~5-6 days).
	WeeklyGrowthStep = 0.72,

	IncomeBonusPerRebirth = 1.59, -- permanent roost income x1.59 per rebirth, multiplying (R10 ≈ x103, R50 ≈ x11.6B)
}
