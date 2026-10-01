# Cohort economy simulation

`CohortSim.luau` simulates whole players (days of play) against the **live Config** and the real shared code
(`DragonStats`, `BindingOdds`, `Luck.GetTierWeights`), so any edit to a Config file is simulated without touching the
sim. It runs inside Studio (no Luau runtime outside it).

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
- **Spire:** a climb restarts from floor 1; fast/fought floors, first-clear drops, re-clear drops, first-clear gold,
  Wyrmblood x2 power; Spire minutes per day per profile. Drops feed runes/stones/potions/luck charges.
- **Runes/Dragonstones:** applied to the best roost dragon, re-rolling until the result is decent.
- **Quests/streak/Index:** daily quests (`QuestRate`), the login streak, weekly quests, Index milestone rewards.
- Not simulated: Stardust offerings and the merchant, group luck, event nights, boss-specific tactics, selling or
  trading, session quirks. Numbers are therefore relative: compare cohorts and configs, not exact days.

Results are medians/percentiles over seeds (`seed * 7919`), so a run is reproducible.
