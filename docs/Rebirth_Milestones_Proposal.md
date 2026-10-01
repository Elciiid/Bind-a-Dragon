# Rebirth Milestone Ladder (design proposal, not built)

Goal: every rebirth feels like progress, and each milestone unlocks something you can see or use. Nothing is paid.
Build only after approval. All numbers in `Config/RebirthMilestones`, all wording in `Config/Text`.

## The ladder

| Rebirth | Milestone | What the player gets |
| --- | --- | --- |
| every | **Title rank** on the nameplate | R1-5 Star Apprentice, R6-10 Binder, R11-15 Warden, R16-20 Sage, R21+ Celestial (a new rank every 5; past the last, a numeral every 5: Celestial II...) |
| R12 | **Auto-Upgrade** toggle | with it on, the server levels your roost dragons for you with gold above a reserve (best income per gold first) |
| R15 | **Star Throne** constellation | a rare night (own constellation, drawn in the sky) that only R15+ players can bind under; its pool holds an exclusive Mythic |
| R18 | **+1 Echo Sigil cap**, **Altar Travel** | cap 6 -> 7; the Travel menu can take you to any unlocked area's altar |
| R20 | **Ascended altars** | +25% bind luck for that player (a luck source, still under the caps); a gold glow on the altar that others see while an Ascended player is binding |
| R25 | **Astral Throne** look | a 4th sanctuary look (above Celestial Sanctum) for rebirthers; shown instead of the upgrade-point look |
| R30 | **Rebirth Champion** | a champion dragon (gold-trimmed, a free pick of a Mythic species they own or a fixed Champion dragon) + a **gold title** |
| each weekly update | one new milestone | a new config entry of an existing type (title, cosmetic, cap, travel, ...) |

Only the milestone's own rebirth number matters; areas keep unlocking at R1/3/5/10 as today.

## Config (`Config/RebirthMilestones`)

```
Titles   = { { From = 1, Name = "Star Apprentice" }, { From = 6, Name = "Binder" }, ... }   -- text via Config/Text
Milestones = {
  { Id = "AutoUpgrade", Rebirths = 12, Kind = "Feature" },
  { Id = "StarThrone", Rebirths = 15, Kind = "Constellation", ConstellationId = "StarThrone" },
  { Id = "EchoCap", Rebirths = 18, Kind = "EchoSigilCap", Extra = 1 },
  { Id = "AltarTravel", Rebirths = 18, Kind = "Travel" },
  { Id = "Ascended", Rebirths = 20, Kind = "Luck", Luck = 1.25 },
  { Id = "AstralThrone", Rebirths = 25, Kind = "Look", LookId = "AstralThrone" },
  { Id = "Champion", Rebirths = 30, Kind = "Champion" },
}
AutoUpgrade = { Reserve = 0.5 (share of the next rebirth cost kept), Interval = 1 (s) }
```
Wording, pop-up texts and the title names in `Config/Text` (no hard-coded strings in systems).

## What it takes to build (rough sizes)

| Piece | Work | Size |
| --- | --- | --- |
| Config + Text + `RebirthService` hook (grant on rebirth, `data.MilestonesSeen`, reward pop-up `Moment = "Milestone"`) + title on the nameplate/badge | server + a small client | S |
| Milestone track in the Rebirth window (row of nodes with icons, next one highlighted, reached ones lit) | UI (`RebirthController`, `UI` kit) | M |
| R12 Auto-Upgrade | toggle remote (type-checked, rate-limited, per player), server loop in `RoostService`/`DragonService` using the sim's buy rule; data flag; Settings or Dragons-panel switch | M |
| R15 Star Throne | constellation config entry (+ stars/lines), `Cycle` weight and an R15 gate in `BindingService` (pool + `BindingOdds`), exclusive Mythic species in `Config/Dragons` (placeholder art until a model exists), sky drawing, announcement, Index/Areas wiring | L |
| R18 sigil cap + Altar Travel | config change; new Travel destinations per area altar, server check against unlocked areas and streaming | M |
| R20 Ascended altars | a luck source in `Shared/Luck`, the player attribute for the glow, `AltarGlowController` gold glow | M |
| R25 Astral Throne look | a **new look kit** (a full Remaster checkpoint like checkpoints 3-4: code-built pieces + a few AI meshes, ~65k triangle budget, 6 plots), look rule change (rebirths, not points), tier-art hiding, transition polish | XL |
| R30 Champion dragon + gold title | a reward dragon (new mutation-like cosmetic or a fixed species), nameplate/title colour, reward pop-up | M |

Suggested order: foundation (S + track UI) -> R12 -> R18 -> R20 -> R30 -> R15 -> R25 (the two heavy art/system items last).

## Risks and notes

- Balance: Ascended (+25% luck) and Auto-Upgrade are power; the sim (`tools/sim`) can evaluate both before launch
  (Auto-Upgrade as a better spending policy; Ascended as a luck source).
- Star Throne is exclusive but not paid; it must not change the 1-bind-per-night rule, and it rarely occurs.
- R25 look is the one expensive item. If it must be cheaper: reuse Celestial pieces with a recolor and a new centerpiece.
- Weekly milestones: one config entry per update; the track and pop-up code are generic.
