# Economy retune proposal (after the mutation branch)

Status: **approved and applied (2026-10-02); the sim on the applied Config reproduces the table.** Everything below was simulated with
`tools/sim/CohortSim.luau` (see `tools/sim/README.md`) against the live Config plus in-memory overrides.

## How to read the numbers

- Sim-days are slower than the real days of the approved v5 sim: the same simulator on the **approved-old** economy
  gives Dedicated R50 in 17.0 sim-days, where v5 reported 8.1 days. So **calibrated days = sim-days x 0.476**
  (8.1 / 17.0). Ratios between cohorts match v5 reasonably (Casual 2.8x vs 2.3x, paid AFK 1.6x vs 1.5x).
- 30-50 simulated players per cell; median / fastest 10% (p10) / slowest 10% (p90).
- Late rebirth days come in whole-day steps (players rebirth at their next session).

## Results (days to the launch cap; calibrated in brackets)

| Cohort | Approved-old (R50) | Kyle (R30) | Proposed (R30) |
| --- | --- | --- | --- |
| Dedicated median | 17.0 (8.1) | 47.0 (22.4) | **17.0 (8.1)** |
| Dedicated fastest 10% / slowest 10% | 12.0 / 22.0 | 35.0 / 72.4 | **12.3 (5.9)** / 31.0 |
| Casual | 47.8 (22.8) | 112.7 (53.6) | 46.8 (22.3), 2.75x Dedicated |
| AFK-only | 91.1 (43.4) | 144.0 (68.5) | 69.0 (32.8), 4.1x Dedicated |
| Paid AFK (Auto-bind + 2x AFK) | 27.0 (12.9) | 52.2 (24.8) | 24.0 (11.4), 1.4x Dedicated |
| Weekly update (+rebirths) block, Dedicated | 7.9 / 9.0 (3.8 / 4.3) for +5 | 44 / 62 / 91 (21 / 30 / 43) for +3 | 10.3 / 10.9 / 12.0 (4.9 / 5.2 / 5.7) for +3 |
| Spire floor on day 7 (median) | 98 | 69 | 98 |

Findings on Kyle's numbers: Dedicated needs ~22 real days to the R30 cap (target ~8), and a weekly +3 takes weeks
and keeps getting longer (the weekly step is steeper than income growth). Kyle's cohort ratios (Casual 2.4x, AFK-only
3.1x, paid AFK 1.1x Dedicated) were fine except that paid AFK was barely slower than Dedicated.

## Config values (approved-old -> Kyle -> proposed)

| Config | Old | Kyle | Proposed |
| --- | --- | --- | --- |
| Rebirth cap at launch / per weekly update | 50 / +5 | 30 / +3 | 30 / +3 (kept) |
| `Rebirth.EarlyGrowth` (R2..R10) | 3.71 | 3.71 | **5.0** |
| `Rebirth.LateGrowth` (R11..R30) | 2.69 | 2.95 | **2.55** |
| `Rebirth.WeeklyJump` (first rebirth of each weekly block) | 2.2 | 3.0 | **4.8** |
| `Rebirth.WeeklyGrowthStep` (multiplies the weekly growth) | 1.02 | 1.02 | **0.72** (a big first step, then cheap) |
| Gold/s Common / Rare / Epic / Legendary / Mythic | 750 / 1.8k / 4.4k / 11k / 29k | 700-900 / 1.2-1.5k / 2.1-2.7k / 3.5-4.7k / 4.6-6.2k | 700-900 / 1.5-2.0k / 3.5-4.6k / 8.5-12k / 20-30k |
| Mythic vs Common gold/s | 39x | 6-7x | **~29-38x** (per species: Solflare 26k, Aurorynth 24k, Stormcrown 20k, Eclipsar 30k) |
| Best trait (Dragonlord) | x25 | x3 | **x15** (Celestial x8, Ancient x4, Goldhoard/Stormcaller x2.2, Gilded/Ironhide x1.5, Emberheart x1.35, commons x1.12-1.2) |
| Best grade (SSS) | x25 | x3 | **x15** (SS x7, S x3.5, A x2.2, B x1.5, C x1.2, D x1) |
| `Spire.EnemyGrowth` | 1.215 | 1.215 | **1.15** (week-1 floor ~98 instead of 69; Kyle's lower base power made the old curve too steep) |
| Kept from Kyle | | species-specific stats and roles, mutations (Normal 90 / Hoardscale 4 / Warcrest 4 / Aetherwing 1.5 / Primordial 0.5), Index +0.5% / x1.10 / x1.20, roost income +4% x 25, level cost 0.20-0.40% of the next rebirth cost, gold potion max x5, Echo Sigils, offline 50% | unchanged |

Power values stay Kyle's (Mythic 175-340). Mutation odds and bonuses stay Kyle's: the sim does not call for changes.

## Trade-offs

- Pacing is very sensitive to `LateGrowth`: +0.05 moves the Dedicated median by ~2-3 sim-days late in the curve (and
  +0.1 doubles it). Re-run the sim after any change to species gold, traits, level costs or the curve.
- "Rare must feel HUGE": a Mythic earns ~30x a Common at the same level; with the +1.5 quality threshold for swapping
  dragons into the roost, a single early Mythic is worth roughly 2-3 rebirths of tail time. The fastest 10% still
  land at 0.72 of the median (target: >= 0.75 would need smaller Mythic gaps).
- AFK-only at 4.1x Dedicated is a hair over the 3-4x ask; lifting the offline rate 0.5 -> 0.6 would give 3.8x but
  changes an approved rule (and the 2x AFK pass), so it is not in the proposal.
- Not simulated: Stardust offerings/merchant, group luck, event nights, player skill. Treat the numbers as
  relative, not absolute.
