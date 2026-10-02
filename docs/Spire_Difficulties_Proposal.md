# Spire difficulties (checkpoint 4): PROPOSAL, nothing is wired into SpireService yet (2026-10-03)

Config (proposed, `Config/Spire.Difficulties` + `FastFloors`), shared maths (`DragonStats.GetEnemyPower(floor, difficulty)`, `GetFloorTier`,
`GetSpireRewardMultiplier`) and the sim variant `SpireDifficulties` (`tools/sim/CohortSim.luau`) exist; the live game is unchanged.

| Difficulty | Enemy power | Boss runes/stones | First-clear gold | Extra drops |
| --- | --- | --- | --- | --- |
| Easy | x1 (original) | x1 (Kyle's values) | 30 s | none |
| Medium | x20 | x2 | 30 s | none |
| Hard | x400 | x4 | 30 s | Moonfire every 25 floors, Runebright 25% on bosses |
| Infinite | Hard's curve from floor 101 on, no top | x4, growing +x4/50 floors with depth | 30 s | + Conqueror's Brew every 50 floors |

Unlock: clear the previous difficulty's floor 100. Medium/Hard/Infinite first clears give the boss rewards, the extras and gold, not another full set of Easy's first-clear potions (`SkipBaseFirstClear`).
Raw sim (Dedicated, median day): Easy 100 cleared ~5.5, Medium 100 ~9.5, Hard 100 not within 80 days (long-term goal).

## Fast floors (already-cleared floors only; new floors always take 12 s)
Sim, mean days to R30 (100 paired seeds; base Dedicated 7.70 / Casual 26.25 / Paid AFK 15.31):
| Setting | Dedicated | Casual | Paid AFK |
| --- | --- | --- | --- |
| Difficulties only, no fast floors | 7.42 (-0%) | same as base | same |
| **25x power -> 6 s, 25% boss reward share (recommended)** | 7.52 (-2%) | 24.74 (-6%) | 14.74 (-4%) |
| 100x -> 1.5 s plus 25x -> 6 s | 7.00 (-9%) | 23.9 (-9%) | 12.66 (-17%) |
| 25x -> 1.5 s, 4x -> 5 s (as first asked) | -11% | -20% | -16% |
Fast floors speed everyone's first clears (runs reset to floor 1), not runes (runes stay ~equal). 1.5 s tiers need a LateGrowth bump to compensate.

## Open
Your OK on: scales 20/400, rewards x2/x4, the fast-floor option, Infinite weekly leaderboard (OrderedDataStore, top 10 in the HUD).
Then build: data v5 records per difficulty, SpireService difficulty argument, HUD picker, Spire Haste pass replacing the Elevator, leaderboard.
