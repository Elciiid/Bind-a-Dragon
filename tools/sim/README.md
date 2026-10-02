# Cohort economy simulation

`CohortSim.luau` simulates whole players (days of play) against the **live Config** and the real shared code
(`DragonStats`, `BindingOdds`, `Luck.GetTierWeights`), so any edit to a Config file is simulated without touching the
sim. It runs in Studio or with the portable CLI harness. All results are **raw elapsed days**; the historical
`0.476` calibration is deliberately excluded.

## Portable reproducible runs

```powershell
./tools/sim/RunCli.ps1 -Luau C:/path/to/luau.exe -Runs 1000 -Profile Dedicated -MaxDays 180
./tools/sim/RunCli.ps1 -Luau C:/path/to/luau.exe -Runs 1000 -Profile Casual -MaxDays 180
./tools/sim/RunCli.ps1 -Luau C:/path/to/luau.exe -Runs 1000 -Profile AfkOnly -MaxDays 180
./tools/sim/RunCli.ps1 -Luau C:/path/to/luau.exe -Runs 1000 -Profile PaidAfk -MaxDays 180
./tools/sim/RunCli.ps1 -Luau C:/path/to/luau.exe -Runs 1000 -Baseline -Profile Dedicated -MaxDays 180
./tools/sim/RunCli.ps1 -Luau C:/path/to/luau.exe -Check -Runs 0
```

The harness bundles real repository modules without replacing economic formulas. It substitutes inert Roblox value
constructors/services and deterministic Park–Miller RNG (`seed * 7919`). Studio uses Roblox `Random`, so equivalent
distributions are expected, not identical individual outcomes. `-Baseline` isolates flat level prices and LateGrowth
2.55 under the same repaired timeline and new Spire reward policy: a controlled comparison, not an exact replay of old
skipping. `-LateGrowth` supports deterministic parameter sweeps. Runs do not change repository files.

`CostChecks.luau` tests every species at R0/R1/R10/R20/R30: increasing prices, exact bulk sums, newest-band income floor,
and anchor invariance under placement/potions/upgrades within one rebirth.

## Run it

1. In Studio create `ServerStorage.SimTools.CohortSim` (ModuleScript) and paste `CohortSim.luau` into it (Claude can
   do this through the Studio MCP; Rojo does not sync `tools/`).
2. Rojo must be connected so the Config in Studio matches the repo.
3. In the command bar / `execute_luau` (it blocks Studio while it runs: ~1-3 s per simulated run; use 10-30 runs):

```lua
local Sim = require(game.ServerStorage.SimTools.CohortSim)
print(Sim.Cohort("Dedicated", 20, 60))            -- days to the launch cap (median, p10, p90), rebirths on day 1/3/7/14/28, Spire floor at day 7
print(Sim.Cohort("Dedicated", 20, 120, 3))        -- + the next 3 weekly updates (each raises the cap by Rebirth.WeeklyRebirths)
print(table.concat(Sim.Trace("Casual", 1, 30), "\n")) -- one player, one line per day (for debugging)
```

Profiles: `Dedicated`, `Casual`, `AfkOnly`, `PaidAfk` (`Sim.Profiles`; edit the numbers there).

## Running it through the Studio dev channel

The Studio MCP's own threads can't `require` game modules any more, so run cohorts on the server during Play: copy
`tools/sim/CohortSim.luau` to `src/ReplicatedStorage/TempCohortSim.luau` (git-ignored, delete it afterwards), start Play, then set the
Workspace attribute `DevCommand` (see `DevService`): `{"Op":"SimStart","Job":"x","Profile":"Dedicated","Runs":24,"Days":30,
"Variants":{"SellSurplus":true}}` and read `{"Op":"SimResult","Job":"x"}` until it is not "running". Run one job at a time (a job
reads the variants set when it started, and `SimStart` resets them). `Variants.SpireDifficulties` = the Spire difficulties + fast floors (`Config/Spire`; the player climbs the unlocked difficulty paying the most runes + stones per second; results `Clear<Difficulty>DayMedian`, `Record<Difficulty>Median`, `InfiniteDepthMedian`; pass `"Weeks": 16` to release a weekly update as soon as the cap is hit, so it overstates speed: real updates come weekly, see `docs/Spire_Difficulties_Proposal.md`). `Variants.SellSurplus` = the Star Merchant selling model
(`docs/Merchant_Selling_Proposal.md`).

## The model (what is and is not simulated)

- Day by day; active sessions step 60 s (income x potions, a bind each night, spending every 5 min); away time is
  closed-form at the offline rate, limited to `Roost.OfflineCapHours` per day (x2 for the 2x AFK pass).
- **Binding:** the real `BindingOdds.Roll` (species x mutation), luck = area x constellation x moon x favored area,
  cap `Luck.Cap`, armed charges up to `PotionCap`. The player picks the favored/best unlocked area. Auto-bind: base luck
  at the highest unlocked area, once per night, only while in the game. Echo Sigils give extra binds.
- **Roost:** best dragons by level-independent quality (a replacement must be 1.5x better); real
  `GetRoostIncome`, slot/income upgrades, level costs, evolution branches (night = the sky's constellation).
- **Spending:** rebirth the moment it is affordable; otherwise buy the best-paying upgrade (level, next stage,
  cap, income level, slot) if it pays back within `SpendK` x the time left to the next rebirth.
- **Spire:** all stages cost 12 seconds inside active-session budgets (25/8/0/5 minutes daily by profile). Runs start
  at 1 and finish at 100, then repeat; failed attempts restart. Drops arrive on completion, using live configuration.
  No manual altar binds occur during reserved Spire time. Wyrmblood/Conqueror boosts and first-clear gold are included.
- **Runes/Dragonstones:** applied to the best roost dragon, re-rolling until the result is decent.
- **Quests/streak/Index:** actual randomly selected daily/weekly quests complete from bind/favored bind/level/offering/
  active gold counters. No random completion grants. Login streak and Index rewards are included.
- **Merchant/offerings:** buy affordable 10-Stardust bundles under a 1%-rebirth-cost price ceiling and make the three
  offerings. Sigil binds reuse that night's offerings. Earned Ascended luck and R18 sigil-cap perk are included.
- **Boosts/retention:** strongest gold potion wins; all timed boosts tick together during active time. Exact per-level
  and bulk costs use the real shared code. Post-rebirth anchors include retained dragons/permanent bonuses, excluding
  temporary boosts. Dedicated sessions total 3.5 hours/day, +/-15% length variation and 3% skipped days.
- Not simulated: group luck, event nights, Premium duration, travel time, or human decision delays. Offline gaps
  use current-income closed-form payouts; idle Auto-binds occur between check-ins. Results describe the stated strategy,
  not a guarantee for every human player. See `Hakai_Polish_Results.md` for measurements and limitations.

Results are medians/percentiles over seeds (`seed * 7919`), so a run is reproducible.
