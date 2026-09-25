--!strict
-- Rebirth: resets gold only (dragons, levels, evolutions, traits, grades, Stardust, roost upgrades are kept).
-- Each rebirth gives a permanent income bonus and +5 level cap (Config/Leveling), and counts toward area unlocks
-- (Config/Areas RebirthsRequired). Tuned by simulation for ~8 days to this week's cap for a dedicated player.
--
-- Cost of rebirth number r (1-based), open-ended:
--   r <= EarlyUntil:            FirstCost x EarlyGrowth ^ (r - 1)
--   EarlyUntil < r <= CurveEnd: ... x LateGrowth ^ (r - EarlyUntil)            (R50 ≈ 640 Oc)
--   r > CurveEnd:               ... x WeeklyJump x WeeklyGrowth ^ (r - CurveEnd)
-- WeeklyGrowth = IncomeBonusPerRebirth x Leveling.IncomePerLevel ^ Leveling.CapPerRebirth x WeeklyGrowthStep,
-- i.e. the same as income growth per rebirth, so each post-launch rebirth takes about the same play time.
-- PLACEHOLDER numbers.

return {
	FirstCost = 50e6, -- R1: a new player rebirths ~5 min into their first session
	EarlyGrowth = 3.71, -- R2..R10: fast early rebirths (R5 ~20 min, R10 ~35 min)
	EarlyUntil = 10,
	LateGrowth = 2.69, -- R11..R50: above income growth per rebirth, so each rebirth takes a bit longer than the last (re-simulated with the built game)

	-- The launch curve ends here. NEVER change this after launch: weekly updates raise RebirthCap instead.
	CurveEnd = 50,
	-- The highest rebirth currently allowed. Raise by 5 with each weekly update.
	RebirthCap = 50,
	-- Past CurveEnd: a one-time extra step, then growth equal to income growth.
	WeeklyJump = 2.2,
	-- Extra 2% per post-launch rebirth. Offsets slow income growth that doesn't come from rebirths (traits, grades,
	-- Dragon Index), so post-launch rebirths don't get shorter week after week.
	WeeklyGrowthStep = 1.02,

	IncomeBonusPerRebirth = 1.59, -- permanent roost income x1.59 per rebirth, multiplying (R10 ≈ x103, R50 ≈ x11.6B)
}
