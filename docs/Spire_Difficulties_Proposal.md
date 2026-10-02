# Spire difficulties (checkpoint 4): BUILT (2026-10-03)

Numbers approved by the user, built in `Config/Spire` (`Difficulties`, `FastFloors`, `Haste`, `Leaderboard`), `DragonStats` (`GetEnemyPower(floor, difficulty)`,
`GetFloorTier`, `GetSpireRewardMultiplier`, `GetSpireRecord`, `IsDifficultyUnlocked`), `SpireService`, `SpireLeaderboardService`, `SpireController`.

| Difficulty | Enemy power | Boss runes/stones | First-clear gold | Extra drops | Unlock |
| --- | --- | --- | --- | --- | --- |
| Easy | x1 (original ladder) | x1 (Kyle's values) | 30 s of roost income | none | always |
| Medium | x20 | x2 | 30 s | none | Easy floor 100 |
| Hard | **x100** (was proposed x400) | x4 | 30 s | Moonfire every 25 floors, Runebright 25% on bosses | Medium floor 100 |
| Infinite | Medium's curve from floor 101 on (EnemyScale 20, FloorOffset 100), no top | x4, growing +x4 per 50 floors of depth | 30 s | + Conqueror's Brew every 50 floors | **Medium floor 100** (was Hard) |

Medium / Hard / Infinite first clears give the boss rewards (runes, stones), the extras and the gold, not another full set of Easy's first-clear potions
(`SkipBaseFirstClear`). Records are per difficulty (`data.SpireRecords`, data version 6 migrates the old `SpireRecord` into Easy). Stardust and
potions are never multiplied by the difficulty.

**Why Infinite continues Medium's curve, not Hard's:** with Infinite unlocked by Medium 100, Hard's curve (x100) would put Infinite floor 1 about 4x above
Medium floor 100's boss, so nobody could climb it for weeks and the leaderboard would sit empty. On Medium's curve floor 1 is Medium floor 101 and the
board is live from day ~9.

## Fast floors (already-cleared floors only; new floors always take the full 12 s)
A floor you already cleared, with your power at least 25x the enemy's, takes 6 s (not 12) and pays 25% of the boss Wyrm Runes / Dragonstones / Stardust of
that floor (a fraction is a chance of one more, so the average is exact). Sim, mean days to R30 (100 paired seeds; base Dedicated 7.70 / Casual 26.25 /
Paid AFK 15.31): Dedicated 7.52 (-2%), Casual 24.74 (-6%), Paid AFK 14.74 (-4%). No LateGrowth retune needed.

## Sim: when does Dedicated clear each difficulty (raw days, 30 paired seeds, 120 days, weekly updates released as soon as the previous cap is hit)
| Milestone | Median day |
| --- | --- |
| Easy 100 | 5.5 |
| Medium 100 | 9.5 |
| Hard 100 (x100) | 12.5 |
| Infinite depth after 120 days | floor 79 |

The sim releases each weekly update the moment the player hits the cap, so it overstates speed: the real game releases +3 rebirths per week. Hard 100's boss
needs about 1.8e9 power; Dedicated has 1.7e8 at R30 and gains about x1.28 per rebirth, so Hard 100 needs about **R40-R42**, which is the **4th weekly update
(real day ~28-31, i.e. about 4 weeks)**: inside the 3-5 week target. Medium 100 (3.5e8) needs R~33: the first weekly update, about day 8-10. After that Infinite
climbs about 5 floors per weekly update for a Dedicated player.

## Spire Haste (game pass, replaces the retired Elevator in the Shop)
`Config/Products.Passes.SpireHaste` (Id 0 until created: the card shows "Coming soon"), `Config/Spire.Haste.FightSpeed = 2`: every fight takes half the time
(fast floors too), on every difficulty. Same floors, same drops per win, so it only shortens the wait. Studio: server-side Player attribute
`TestPass_SpireHaste = true`. The HUD shows "HASTE x2" while it is active. Paid-vs-active note: this is a time convenience like Auto-bind; it does not
raise power or drops per win.

## Infinite weekly leaderboard
`SpireLeaderboardService`: the deepest Infinite floor reached this week, an `OrderedDataStore` (`SpireInfinite_Weekly`, `_Studio` suffix in Studio) with one
scope per week (weeks start Monday 00:00 UTC; old weeks are not cleaned up). Writes are throttled (`WriteIntervalSeconds` 20, plus on leave / server close,
`UpdateAsync` keeps the max), the top 10 is cached 60 s, the HUD asks for it every 30 s while Infinite is picked and shows it beside the Spire HUD with
"Resets in 2d 4h" and "Your best: floor N" (5 rows on phones). With no DataStore access the board falls back to a per-server memory table and says
"Test board (offline)". Tuning numbers are all in `Config/Spire.Leaderboard`.
