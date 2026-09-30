# Mutation and economy implementation

Implementation source of truth for the `codex/mutation-economy` branch. The older economy v5 proposal is historical.

## Binding

- Broad rarity remains presentation metadata.
- `Config/Dragons` owns each species' bind weight, base gold/s, and base Spire power.
- `Config/Mutations` defines Normal (90%), Hoardscale (4%), Warcrest (4%), Aetherwing (1.5%), and Primordial (0.5%).
- `Shared/BindingOdds` enumerates eligible species/mutation pairs in stable order and performs one normalized server roll.
- Pair effective weight is `speciesWeight * mutationShare * luck^min(1, speciesExponent + mutationExponent)`.
- The UI labels canonical Index odds as home-altar x1 odds and current altar results as base/current odds.
- Undiscovered Index entries show only a broad tier odds band. Exact home odds and optional mutation badges unlock after discovery.
- Starborn is not a feature. Data version 3 maps any dormant prototype record to Primordial only for compatibility.

## Economy

- Mutation multipliers: Hoardscale 1.60 gold/1.05 power; Warcrest 1.05/1.60; Aetherwing 1.30/1.30; Primordial 1.45/1.45.
- Trait and grade maximums are each 3x (9x combined).
- Index: +0.5% per species, 1.10x per complete element, 1.20x for all 20; mutations add no income.
- Roost upgrades remain 25 persisted levels at +4% each (2x maximum).
- Only the strongest active gold potion applies, capped at 5x.
- Level costs are 0.20/0.25/0.30/0.35/0.40% of the next rebirth cost for Common through Mythic.
- Launch rebirth cap is 30: 50M first cost, 3.71 early growth through R10, 2.95 through R30. Weekly releases add three: 3.0 first jump, then approximately 2.17.

## Collection and extra binds

- Duplicates retain ordinary roost/build value; there is no consumption system.
- Mutation discoveries are optional badges and never gate Index completion or rewards.
- Echo Sigils cap at six. Completing all three daily quests and winning five non-fast Spire fights each award at most one per UTC day. Auto-bind never consumes them.
- Echo Sigil binds deliberately reuse the current altar pool and current luck; they do not create a separate paid or guaranteed acquisition path.

## Validation record

- Official Rojo 7.6.1 build succeeds.
- All 36 changed Luau sources compile with the Luau CLI.
- 32 probability scenarios (four elements, home and Meadow pools, luck x1/x5/x10/x20) were independently sampled at one million rolls each: 32 million total, worst deviation 3.436 sigma, no 5-sigma failures.
- Server validation rejects dead/distant altar users, and Spire gold is clamped at the weekly rebirth-cap grant boundary.
- Static/UI audit fixes include live mutation badge refresh, visible auto-bind odds, Echo Sigils in Items, and one shared distance-culling loop for mutation auras.
- Roblox Studio playtesting must occur only in `Hakai test`, on the feature checkout, using `PlayerData_Studio`, after a recoverable place backup. Never publish without explicit approval.
