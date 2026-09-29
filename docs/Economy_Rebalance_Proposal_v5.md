# Bind A Dragon: economy rebalance v5 (final proposal + build order)

Status: all targets met in simulation (20 runs per player type). Not coded yet: waiting for build-order approval.

**Changes since v4:**
- Fast early rebirths.
- Day/night cycle of 4 min day + 3 min night.
- Star Merchant price and Starborn odds rescaled for the faster cycle.
- Starter dragon on first join.
- A message when the weekly rebirth cap is reached.

## 1. Rebirth curve (open-ended)

| | R1 | R5 | R10 | R20 | R30 | R40 | R50 (week-1 cap) | R55 (update 1) |
|---|---|---|---|---|---|---|---|---|
| Cost | 50M | 9.4B | 6.6T | 117Qa | 2.1Sx | 37Sp | 640Oc | 31No |
| Rebirth bonus (×1.59 each, multiplying) | ×1.59 | ×10 | ×103 | ×10.6K | ×1.1M | ×110M | ×11.6B | ×118B |
| Level cap (50 + 5 per rebirth) | 55 | 75 | 100 | 150 | 200 | 250 | 300 | 325 |

How the cost grows:
- **R2–R10:** ×3.71 per rebirth.
- **R11–R50:** ×2.66 per rebirth (income growth × 1.25).
- **First rebirth past each weekly cap:** a one-time ×2.2.
- **After that:** ×2.17 per rebirth, the same as income growth.

At the cap, banked gold stops at one rebirth's cost, and the game shows: "Rebirth cap reached. More rebirths in the next update!"

## 2. Income

| Setting | Value |
|---|---|
| Base gold/s (C/R/E/L/M) | 750 / 1.8K / 4.4K / 11K / 29K (Mythic ≈ 40× Common) |
| Income per level | ×1.06 (compounding) |
| Level cost | base 1K / 5K / 20K / 100K / 500K × 1.08 per level × 1.59 per rebirth done |
| Offline | 50% of online, capped at 8 h (the 2x AFK Income pass doubles it) |
| Extra roost slots | 250K, 25M, 2.5B, 250B, 25T |
| Roost income upgrade | +10% × 25 levels, 100K ×3.5 per level |
| Star Merchant | 0.06% of the next rebirth cost per bundle, ×1.5 per buy, resets at dawn (every 7 min) |
| Starter dragon | free Common Hatchling on first join (which dragon: to discuss) |

## 3. Pacing (median, with fastest-10% to slowest-10% in brackets)

| Reach | R1 | R5 | R10 | R20 | R30 | R40 | R50 |
|---|---|---|---|---|---|---|---|
| Dedicated | 6 min | 18 min | 36 min | 3.5 h | 1.1 d | 3.6 d | **8.5 d (7.0–11.0)** |
| Casual | 6 min | 18 min | 54 min | 1 d | 4 d | 9 d | **19 d (16–24)** |
| AFK-only | 12 h | 3 d | 6 d | 11.5 d | 17 d | 24.8 d | **43 d (40–54)** |

**Play time for each rebirth (Dedicated, median):**

| R11 | R15 | R20 | R25 | R30 | R35 | R40 | R45 | R50 |
|---|---|---|---|---|---|---|---|---|
| 8 min | 10 min | 18 min | 10 min* | 32 min | 47 min | 73 min | 86 min | 3.4 h |

*The dip at R25 is sampling noise around the first day boundary; the cost curve keeps rising.

**Weekly update test** (a veteran at R50 gets +5 rebirths): **19 play hours ≈ 5.0 days** (fastest 10%: 4.0 days). ✓

## 4. Spire

| Setting | Value |
|---|---|
| Enemy power | 10 × 1.21^floor; bosses ×1.5 |
| Floors | 150 at launch, +10 per weekly update |
| Week-1 floor (Dedicated) | median 116, fastest 10% 122 |
| Moonfire Tonic (×2 luck charge) | every 50th floor from 50 |
| Starlight Tonic (×1.5 luck charge) | every 20th floor |

**Drops per Spire hour:** 5.2 ×2 gold, 2.9 ×5 gold, 2.1 Wyrm Runes, 2.1 Dragonstones, 0.8 luck charges.

**Share of play time with a gold boost:** ×2 only 11.4%, ×5 only 2.5%, ×10 (both) 5.8%.

## 5. Day/night: 4 min day + 3 min night

| Check | Result |
|---|---|
| Binds per hour | 8.6 (was 5) |
| Is 3 min of night enough? | Yes. The altar is about 11 s from the spawn and from the farthest roost; the merchant is about 7 s away. Add a "Night falls in 30s" warning. |
| Moon phases | Keep 8. A full moon now comes every 56 min, so short sessions still see one; the x20 cap limits its effect. |
| Stardust offerings | Unchanged (5 / 15 / 40 per night). |
| Star Merchant | 0.1% → 0.06% of the next rebirth cost, so gold spent per hour is unchanged. |
| Starborn | 1/500 → 1/850, keeping about one per ~100 play-hours. |

## 6. Luck, traits/grades, Dragon Index, long-term goals

Unchanged from v4:
- **Luck:** scaling 0.3, cap x10, x20 with potions; Mythic 7.1% at x20.
- **Traits and grades:** multipliers.
- **Dragon Index:** +1% per species, ×1.3 per complete element, ×1.5 for all 20, items at milestones. Median after week 1: ×2.6.
- **Event dragons:** one model for all stages.

---

## Build order (exact config changes and new modules)

### Phase 1: Economy core (rebalance only, no new systems)

| File | Change |
|---|---|
| `Config/Rebirth` | Replace with: `FirstCost = 50e6`, `EarlyGrowth = 3.71`, `EarlyUntil = 10`, `LateGrowth = 2.66`, `WeeklyCap = 50`, `WeeklyJump = 2.2`, `WeeklyGrowthStep = 1.02`, `IncomeBonusPerRebirth = 1.59` |
| `Config/Leveling` | `CapBase = 50`, `CapPerRebirth = 5`, `IncomePerLevel = 1.06` (compounding), `PowerPerLevel = 1.05`, `BaseCost = {1K, 5K, 20K, 100K, 500K}`, `CostGrowth = 1.08`, costs × rebirth bonus^rebirths |
| `Config/Rarities` | `GoldPerSecond = 750 / 1.8K / 4.4K / 11K / 29K` |
| `Config/Areas` | Remove `LevelCap` (areas keep luck + unlocks) |
| `Config/Roost` | `OfflineIncomeMultiplier = 0.5`; remove `IncomePerLevel` (moves to Leveling) |
| `Config/Economy` | Merchant `PriceFractionOfNextRebirth = 0.0006`; slot costs `250K … 25T`; income upgrade `MaxLevel = 25`, `BaseCost = 100K`, `Growth = 3.5` |
| `Config/Traits` | Traits and grades become multipliers (v3 table) |
| `Config/Luck` | `TierScaling = 0.3`, `PotionCap = 20` |
| `Config/DayNight` | `DaySeconds = 240`, `NightSeconds = 180`, `DuskWarningSeconds = 30` |
| `Config/Data` | `StarterDragon = "Cinderwing"` (placeholder until decided) |
| `Shared/DragonStats` | Compounding level income/power, trait/grade multipliers, level cap from rebirths, open-ended `GetRebirthCost`, rebirth income bonus |
| `Shared/Format` | Add suffixes past Dc (Ud, Dd, Td, Qad …) |
| `RebirthService` / `RoostService` | Weekly cap: banked gold stops at one rebirth; "Rebirth cap reached" message |
| `DataService` | Starter dragon on first join. Bump the data version (reset the Studio test store). |
| `DayNightController` | Dusk warning |

### Phase 2: Boosts and potions

- **New `Config/Boosts`:** potions (Gilded Draught, Hoard Elixir, Starlight, Moonfire, Wyrmblood, Conqueror's Brew, Runebright), durations, stacking rules, `MaxStoredMinutes = 60`, `PremiumDurationBonus = 0.10`.
- **Data:** new fields `Potions` (id → count) and `ActiveBoosts` (id → remaining seconds). Luck potions are counts used by the next bind.
- **New `BoostService`:** activates boosts, ticks them only while online, and provides multipliers to `RoostService`, `BindingService` and later the Spire. New remote `UseBoost`.
- **New `BoostController`:** a Boosts panel plus active-boost timers on the HUD.

### Phase 3: Dragon Index and Starborn

- **New `Config/Index`:** species bonus, element and all-species multipliers, milestone rewards.
- **New `IndexService`:** records discoveries and hands out milestones.
- **`BindingService`:** Starborn roll (`StarbornChance = 1/850`, ×3 income, ×2 power). New dragon field `Starborn`; tint and sparkle on the model.
- **New `IndexController`:** the Index UI (extends the Star Atlas).

### Phase 4: Quests and login streak

- New `Config/Quests`, `QuestService`, `QuestController`. Rewards as in v3.

### Phase 5: Dragon Spire (its own task)

- New `Config/Spire` (curve, floors, drop table from section 4), `SpireService` and `SpireController`.
- Auto-battle with the player's most powerful dragon. Drops feed `BoostService` and the Rune/Stone currencies.

### Later weekly updates

- Spire leaderboard, then weekly event constellations (single-model dragons).
- Ascension: design only.

## Questions (default in bold)

1. **Starter dragon:** to discuss later, as you asked. The placeholder is **a fixed Cinderwing**.
2. **Approve this build order?** **Phases 1–4 now, then the Spire as its own task.**
3. **Once approved, record everything in CLAUDE.md** (changed decisions in "Pending design doc updates", new systems as "Proposed")? **Yes, as the first step of Phase 1.**
