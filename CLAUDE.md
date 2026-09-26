# CLAUDE.md — Bind A Dragon (Roblox)

This file gives Claude Code the context for this project. Read it before making changes.
Keep it updated: when a system is finished or a design decision changes, edit the relevant section.

## Project summary

A cooperative Roblox dragon-collecting idle game built by a 3-person team.
Players bind to constellations in the night sky to hatch dragons, level them with gold,
earn AFK income in a roost, rebirth to unlock new areas, and climb a tower (the Dragon Spire).
Ranked PvP comes after launch.

Full design doc (source of truth for game design):
https://claude.ai/code/artifact/a97e00fd-8305-4a44-b04a-663db52ab491

**Core loop:** bind for a dragon → earn gold in the roost → spend gold to level/evolve →
climb the Spire for rewards → rebirth to unlock areas and raise level cap → repeat.

## Current status

**Phase:** Production. The core loop is playable in Studio; the approved economy rebalance (Phases 1–6) is built; next are the weekly-update systems and UI polish.
_Update this section as work progresses._

| System | Status |
| --- | --- |
| Project setup (Rojo, Git, folder structure) | Done (Rojo 7.6.1, `default.project.json`, Init/Start bootstraps) |
| Player data / DataStore | Done: `DataService` (ProfileStore), template + migrations, types in `Shared/Types/PlayerData`. Studio uses a separate `PlayerData_Studio` store |
| Client data sync | Done: snapshot + auto-diffed changes (`DataService` → `DataController`); `PRIVATE_KEYS` stay server-only. Gold/Stardust HUD in `CurrencyController` |
| Day/night + constellation cycle | Done: `Shared/Cycle` (global clock, same night on every server; `GetNightBlend` for visuals), `DayNightService`, `DayNightController` (clock + sky HUD) |
| Atmosphere (meadow wow pass, phase 1) | Done: per-area Day/Night looks in `Config/Atmosphere` (`AtmosphereController`: ambient, haze, bloom, color correction, sun rays, far blur; blends at dusk/dawn and on area change; night tint by element), tonight's constellation drawn in the sky + shooting stars (`SkyController`, drawings in `Config/Constellations` Stars/Lines), lanterns (tag `Lantern`, Atomic) lit at dusk with flicker, max 8 lights (`WorldLifeController`), drifting particles per area (petals/fireflies, embers, snow...), music + ambience crossfade and 3D world sounds (`AudioController`, `Config/Audio`). `EffectsQuality` = Low effects (setting or low graphics quality). Lighting uses `Lighting.LightingStyle = Realistic` (set in Studio; replaces the old Future technology) |
| Altar glow + binding ceremony (wow pass, phase 2) | Done: `AltarGlowController` (every `StarAltar`: beam from the main crystal, glow sprites on `Glow/GlowAnchor` parts (Rank 1 = main crystal; only `MaxLights` cast light), rising sparkles, pulsing Highlight up close; element color, brighter when favored; `Config/AltarGlow`). `CeremonyController` (`Config/Ceremony`): after the server's BindResult, camera eases in, tonight's sky stars streak into the altar, rarity burst + flash, the dragon rises with its name; Legendary/Mythic/Starborn = big (second ring, sky flash, longer); skippable; no ceremony for Auto-bind or idle players (toast only); "Quick binds" (LocalPlayer attribute `QuickBinds`) = burst + reveal only |
| In-world UI (wow pass, phase 3) | Done (`Config/WorldUI`): `PromptController` draws every ProximityPrompt in the UI theme (Style = Custom; key badge, icon, hold ring, tap/click to use). Portal warp in `PortalController` (whoosh, FOV kick, color flash). `RoostFXController`: owner banners with avatar (replace the server sign locally), "+gold" pops from your roost dragons, level-up/evolve bursts. `StationFXController`: rune/stone count boards, shrine glow and forge flare while you own runes/stones, merchant price board, Spire door record board (`UI/WorldBoard`). Note: Studio screenshots don't show `AlwaysOnTop` billboards (prompts); they do show in play |
| Binding (RNG, rarity, per-player rolls) | Done: `BindingService` (altars tagged `StarAltar` + `AreaId` attribute), placeholder roster in `Config/Dragons`. Area rosters: `Config/Areas` `Element` + `Species` per area (Meadow = Common/Rare, element areas = all 5 of their element; rolls only over rarities in the roster, `Luck.GetAreaRarityWeights`); favored area ×`FavoredAreaLuck` (`Luck.IsFavored`), shown on the sky HUD and luck panel; Auto-bind uses the nearest unlocked altar's area |
| Luck system | Done: `Shared/Luck` (same math on server + client), `Config/Luck`; Stardust offerings (F at altar), moon phases, constellation luck, group luck, area luck, capped. Panel in `LuckController` |
| Dragons: leveling + evolution | Done: `DragonService` (LevelUpDragon remote, bulk-capable), costs and the level cap (50 + 5 per rebirth) in `Config/Leveling`, evolution branches in `dragon.Evolutions` give income bonus + accent color. Level up in the Dragons panel (`InventoryController`) or via the E prompt on own roost dragons (`DragonPromptController`); one evolution toast per level-up |
| Roost + AFK income | Done: `RoostService` (payouts, offline capped, auto-fill slots, plot visuals), `Shared/DragonStats`, `Config/Roost`, `Config/Evolution`. Roost is a pen where dragons roam (`RoostAnimationController`); "Place in roost" in the Dragons panel |
| Gold sinks (Stardust shop, roost upgrades) | Done: `EconomyService` (Star Merchant prompt on `StarMerchant` tag, price resets at dawn; BuyRoostUpgrade Slots/Income), `Config/Economy`, `MerchantController`; roost upgrades are bought at stands in front of the roost (`RoostUpgradeController`) |
| Rebirth + area unlocks | Done: `RebirthService` (RequestRebirth, cost in `Config/Rebirth`, ★ badge), `AreaService` (portals tagged `AreaPortal` → `AreaSpawn`, server-checked), `RebirthController` button + confirm panel. Volcano Peak built; Frozen Cliffs, Storm Canyon and Eclipse Isles are placeholder shells (see World) |
| Traits + grades | Done: `Config/Traits` (11 traits, 7 grades), rolls in `DragonService` (RollTrait/RollGrade, must be at the station), `RollStationController` panel at the Rune Shrine ("Inscribe a Rune") / Dragonstone Forge ("Temper"); wording in `Config/Text`, no dice/gacha words in player-facing text. Dragons have Power (`DragonStats.GetPower`). Wyrm Runes/Dragonstones come from the Spire, quests, streak and Index |
| Economy rebalance (big numbers, open-ended rebirths) | Done (Phases 1–6). Phase 1: new configs, multiplicative levels/traits/grades, rebirth curve + weekly cap (`DragonStats.GetRebirthCost`, `IsAtRebirthCap`, gold clamps at the cap), ×1.59 rebirth income bonus, level cap 50 + 5/rebirth, idle >20 min = offline rate from the 8 h/day allowance (`RoostService`), starter dragon (`Config/Data.StarterDragon`), dusk warning. Phases 2–6 in the rows below |
| Boosts / potions + Boosts panel | Done: `Config/Boosts` (7 potions), `BoostService` (UseBoost remote, timers tick only in game, 60 min max stored, Premium +10%, `GetMultiplier`/`GrantPotion`), gold boosts in `RoostService` (in game only), Runebright roll luck in `DragonService` (`Luck.GetTierWeights`), luck charges armed via Boosts panel or the altar luck panel and used up by the next bind (`Luck.GetArmedPotionLuck`, up to `PotionCap`). `BoostController` panel + HUD timers, count badge + pulse on the Boosts button, one-time potion hint. Potions come from the Spire, quests, streak and Index |
| Dragon Index + Starborn variants | Done: `Config/Index`, `IndexService` (Sync: records owned species incl. `<SpeciesId>_Starborn`, backfills old saves, auto-grants 5-entry + complete-element rewards once), Index income in `DragonStats.GetIndexMultiplier` (roost income). Starborn rolled in `BindingService` (1/850, ×3 income, ×2 power, announcement, tint + sparkles + ★ nameplate). `IndexController` panel (grid + Star Atlas) |
| Daily/weekly quests + login streak | Done (streak: Gilded, 30 Stardust, Rune+Stone, 2 Gilded, Hoard, 2 Runes+2 Stones, Moonfire): `Config/Quests` (pools, per-slot rewards, streak rewards), `QuestService` (3 daily / 2 weekly picked per UTC day / Monday week, auto-granted on completion, `Progress(player, kind, amount)` from Binding/Dragon/Roost services; Gold targets = minutes of roost income), login streak on first join per UTC day. `Shared/Rewards` (Describe/Apply) shared with the Index. `QuestController` panel |
| Dragon Spire (tower) | Done: `Config/Spire` (curve, 150 floors, drop tables from the simulation), `SpireService` (prompt on `DragonSpire` tag or SpireAction Start/Stop; server-run floors: far-below floors fast with no drops, top-10 window + new floors fought 20 s each; must stay within `EntranceRange`; first clear = 30 s of income + guaranteed drops; Wyrmblood power, Conqueror's Brew rewards; floors where power ≥ `PowerFastRatio` (3) × the enemy also go fast: a new one keeps its drops but gives no gold, a cleared one gives nothing), `data.SpireRecord`, `SpireController` fight panel (opens at the tower). Elevator via `getStartFloor`. Placeholder tower only; no interior/arena yet |
| Game passes + developer products | Done: `Config/Products` (IDs are 0 = not created yet; paste real IDs), `MonetizationService` (pass cache + `Pass_<Key>` player attributes, `WaitForPasses`, `ProcessReceipt` grants, records PurchaseId, confirms only after ProfileStore saved it). Tower Elevator / Elevator Skip start Spire climbs above the record (`data.ElevatorSkips`); 2x AFK Income doubles offline + idle income only; Auto-bind binds at base luck with `AutoBindSecondsLeft` of night left. `ShopController`. Studio: server-side Player attribute `TestPass_<Key>` grants a pass |
| Weekly Spire leaderboard | Proposed (weekly update) |
| Weekly event constellation (event-only dragon, single model) | Proposed (weekly update) |
| Ascension (second prestige) | Proposed (design only, post-launch) |
| UI | Themed UI kit. World text: `UITheme.WorldLabels` (every BillboardGui: 40-stud MaxDistance, 80 for the ★ rebirth badge, not AlwaysOnTop, sizes); empty roost signs are hidden. Designer-editable wording in `Config/Text` (station words, results, tips; `Text.Format` fills `{placeholders}`). `Config/UITheme` holds every color (incl. per rarity/element), font (Luckiest Guy titles, Builder Sans body), size, motion timing, sound ID, icon ID and art slot; empty icon = styled fallback tile, empty sound = silent, empty art slot = procedural look. Kit in `Controllers/UI` (Style, Icon, Button, IconButton, Window, ProgressBar, Toast, Tooltip, CurrencyPill, RarityTag, RewardRow); every panel uses it. `HudLayout`: menu tiles, currency pills, popups (Windows register themselves), `OnLayoutChanged`; one window at a time (`ClaimFocus`/`ReleaseFocus`: every Window, and station panels via `TrackPanel`, close whatever else is open; clicking a menu tile again closes its window). Phones show at most `UITheme.PhoneMaxTimers` boost timers, then a "+N" chip that opens Boosts. The Dragons panel keeps its cards and only writes changed values. PC = icon grid left-middle + currency bottom-left; phone (short side ≤ 500 px) = same grid smaller, currency top-left, luck pill + boost timers top-right, Spire card top-center; thumbstick/jump corners stay clear. Landscape only. ScreenGuis use Sibling ZIndex. Studio test: LocalPlayer attribute `ForceLayout` = "Phone"/"PC"; `ReplicatedStorage.DevTools.PhoneMock` (Studio only, not in Git) renders the UI in a phone frame. Shop cards use the pass icons (`UITheme.ShopIcons`). Waiting on art: panel frame (dragon scales), title ornament, panel texture |
| Ranked PvP | Post-launch |

**Next up: approved build order** (full numbers in `E:\Roblox\Bind A Dragon - Economy Rebalance Proposal v5.md`,
plus the changes approved after it, listed under Decisions made). Work phase by phase: after each phase, playtest in
Studio, fix, commit, and send the user a short summary before starting the next.
1. Economy core rebalance (configs, DragonStats, weekly rebirth cap, idle rule, starter dragon, dusk warning).
2. Boosts and potions (`Config/Boosts`, `BoostService`, `BoostController`, UseBoost remote; luck potions are
   charges the player arms for the next bind).
3. Dragon Index + Starborn (`Config/Index`, `IndexService`, `IndexController`, Starborn roll in `BindingService`).
4. Quests + login streak (`Config/Quests`, `QuestService`, `QuestController`).
5. Dragon Spire (`Config/Spire`, `SpireService`, `SpireController`).
6. Monetization (Tower Elevator Pass, Single Elevator Skip, 2x AFK Income, Auto-bind; `ProcessReceipt` with receipt IDs).
Later weekly updates: Spire leaderboard, event constellations, then Ascension (design only).
UI polish after the core loop is playable. **UI polish list (in order):**
1. ~~Phone layout of the left button column~~ Done: `HudLayout` (phone grid, popups above the HUD, luck pill, Spire
   card, scaled Rebirth confirm, scrolling station odds). Menu buttons still use text labels until the artist's icons.
2. ~~Full UI styling pass~~ Done: `Config/UITheme` + the `Controllers/UI` kit (all panels migrated). Remaining: the artist's panel frame / title ornament / texture art (`UITheme.Art`). Shop pass icons done.
3. Spire battle visuals (see Open questions): a visible dragon-vs-dragon fight instead of the timer bar.

**Luck scaling (decided):** luck boosts rarer tiers harder via `Config/Luck.TierScaling` (0.3):
Mythic 0.5% at x1 → 4.2% at the x10 cap → 7.1% at the x20 hard cap with a potion.

**World (built in Studio, lives in the place file, not Git):** `Workspace.StarterMeadow` (rebuilt 2026-09-26 from the
concept art with the builder's models; north = -Z) is grouped as:
- `Plaza`: the Star Altar model `StarAltar` (tag `StarAltar`, `AreaId = "StarterMeadow"`, PrimaryPart `Core` = invisible
  part on its top platform; Bind prompt range 20) on a round stepped stone `Floor` (radius 42) at the center, `Lanterns`.
  Any new altar just needs the tag + `AreaId` attribute; the Bind prompt is added by code.
- `Pens`: 8 plots on a ring 110 studs out (4 per side; north and south left open): fenced grass pens (Models tagged
  `RoostPlot`, PrimaryPart `Base`) with attributes `RoamCenter` (floor top center) and `RoamRadius`, a gate with the
  owner `Sign` facing the plaza, and upgrade stands `UpgradeSlots` / `UpgradeIncome` in front of the gate. Dragons roam
  client-side (`RoostAnimationController`): Hatchlings hop, Drakes walk, Dragons/Elders fly (per-stage
  Movement/MoveSpeed/FlyHeight in `Config/Evolution`). Keep server max players ≤ 8, or add plots. If a pen moves,
  update its `RoamCenter`.
- `Spire`: the builder's `DragonSpire` (tag `DragonSpire`, PrimaryPart `Entrance` = invisible part in front of the
  door, facing the altar; `EntranceRange` is measured from it) on a terrain hill (top y = 16, center (0, -175)) with
  stone `Stairs` down to the plaza.
- `Buildings` (south, along the cross path at z ≈ 118): `StarMerchant` stall bottom-left (tag `StarMerchant`, PrimaryPart
  `Counter`), `RuneShrine` and `DragonstoneForge` bottom-right (tags `RuneShrine` / `DragonstoneForge`, PrimaryPart
  `PromptPoint` = invisible part at the front at standing height; station prompts have a 12-stud range).
- `Portals`: `Portal_VolcanoPeak` (NE), `Portal_EclipseIsles` (NW), `Portal_FrozenCliffs` (E), `Portal_StormCanyon` (W),
  180 studs out between the pens, facing the plaza. Each is the builder's arch `Art` (anchored, collidable ramp) plus
  a `Surface` part filling the opening (PrimaryPart, tag `AreaPortal`, `AreaId` = destination, CanCollide off): touching
  it teleports (`AreaService`, server-checked). The return portals (`Portal_StarterMeadow` in VolcanoPeak and each
  placeholder area) use that area's own arch. `PortalController` draws the Surface per client: destination color,
  light, swirl and particles when unlocked; dim gray with a lock + "Rebirth X" (close up) when locked (`Config/Portals`).
- `Scenery`: trees and rocks at the edges, `Flowers`, path `Lanterns`. Paths are terrain painted `Ground`.
- `SpawnLocation` at the south entrance (0, 2, 160), `AreaSpawn` (arrivals from other areas) just north of it.
- Dev: `Controllers/Dev/DragonRigDemo.client.luau` animates any Model tagged `DragonRigDemo` (walk -> take off -> fly
  -> land by moving bones). No such model is in the place now (all dragon art was cleared on 2026-09-26).
The building meshes use the default CollisionFidelity (a script can't change it; set `PreciseConvexDecomposition`
by hand in Properties if a building blocks players). The only dragon model in the place is
`ReplicatedStorage.Assets.Dragons.Placeholder` (keep it: every dragon uses it until real art is added).
**Placeholder areas:** `Workspace.FrozenCliffs_Placeholder` (x ≈ +900), `StormCanyon_Placeholder` (x ≈ -900) and
`EclipseIsles_Placeholder` (z ≈ +900): flat platform, cloned Star Altar (`AreaId`), `AreaSpawn`, portal back, and a
"PLACEHOLDER" sign; their Meadow portals are in `StarterMeadow.Portals`.
The builder replaces each with the real area (keep the altar tag + `AreaId`, the `AreaSpawn`, and the portals).
Eclipse Isles should be themed to match the Shadow dragons.
StreamingEnabled is on: tagged models use `ModelStreamingMode = Atomic`, and client code that sets up prompts on
streamed models must retry until the parts arrive.
`Workspace.VolcanoPeak` (at z ≈ -900, past the meadow hills): basalt plateau, volcano, lava, red Star Altar
(`AreaId = "VolcanoPeak"`), `AreaSpawn`, and a portal back. New areas: build far away, add a `StarAltar` + `AreaSpawn`
with the AreaId, and a portal in `StarterMeadow.Portals`.
**Dragon art:** `ReplicatedStorage/Assets/Dragons/<SpeciesId>/<StageId>` (or `<SpeciesId>` for one model for all
stages) replaces the tinted `Placeholder` model automatically. Assets live in the place file, not Git.
To test night in Studio, set a number attribute `CycleTimeOffset` (seconds) on Workspace.

## Team

- **Scripter** — all Luau systems, DataStores, monetization, anti-exploit. Main Claude Code user.
- **Builder/Artist** — dragon models (one per evolution stage), areas, Spire interior, roost, UI art.
- **Designer/Producer** — odds, costs, balancing, UI implementation, sound, marketing.

## Tech stack

- Roblox Studio + Luau
- Rojo (file sync between repo and Studio), VS Code, Git/GitHub
- Roblox Studio MCP server (Claude can inspect and edit the open place)

### Dev setup
- Dev tools live on drive E, not C: `E:\Roblox\Tools\bin` (on the user PATH).
- **Rojo is pinned to 7.6.1.** 7.7.0 crashes `rojo serve` when files are saved via temp-file rename (how Claude's
  edit tools write), see rojo-rbx/rojo#1314 (fix in PR #1319). Don't upgrade until a release includes that fix.
  The Studio plugin must match: `rojo plugin install` with the same version.
- `rojo serve` from the repo root, then click Connect in the Rojo Studio plugin.
- `default.project.json` maps `src/ReplicatedStorage`, `src/ServerScriptService` and
  `src/StarterPlayer/StarterPlayerScripts` with `$ignoreUnknownInstances`, so anything built directly in
  Studio (Workspace, models in ReplicatedStorage, etc.) is not deleted by Rojo syncs. New folders under those
  sync automatically; editing `default.project.json` itself needs a `rojo serve` restart + reconnect.
  Workspace/builds are owned in Studio; code lives in the repo.
- Third-party code is copied into `src/ServerScriptService/Packages` with its license, no package manager. ProfileStore is there, from MadStudioRoblox/ProfileStore @ 45c9847.
- Services/Controllers are ModuleScripts that may expose `Init()` (setup) and `Start()` (run).
  `ServerScriptService/Main.server.luau` and `StarterPlayerScripts/Main.client.luau` load them all automatically.
- File naming: `*.server.luau` = Script, `*.client.luau` = LocalScript, `*.luau` = ModuleScript.
  `.gitkeep` files keep empty folders in Git; Rojo ignores them.

## Architecture rules

- **Server-authoritative.** All RNG, currency, levels, rebirths, and rewards are decided on the server.
  Never trust values sent from the client. Clients only send requests (e.g., "bind", "level up dragon X").
- **Validate every RemoteEvent/RemoteFunction** on the server: type-check arguments, check the player
  owns the dragon, has enough gold, meets rebirth requirements, and rate-limit requests.
- **Data:** use a session-locking DataStore wrapper (e.g., ProfileStore). Save on leave, autosave
  periodically, and handle BindToClose. Include a data version number for future migrations.
- **Config-driven balancing:** all tunable numbers (odds, costs, rates, caps, prices) live in
  config ModuleScripts in `ReplicatedStorage/Shared/Config`, never hard-coded in systems.
  The designer should be able to rebalance without touching logic.
- **One module per system** (Binding, Luck, Dragons, Roost, Economy, Rebirth, Spire, Monetization).
- Use `--!strict` type checking where practical.
- AFK/offline income is calculated on the server from saved timestamps, with a cap on offline time.

## Suggested folder structure (Rojo)

```
src/
  ServerScriptService/
    Services/        -- BindingService, LuckService, DragonService, RoostService,
                     -- EconomyService, RebirthService, SpireService, MonetizationService, DataService
  ReplicatedStorage/
    Shared/
      Config/        -- Rarities, Dragons, Constellations, Areas, Costs, Spire, Products
      Types/
    Remotes/
  StarterPlayer/
    StarterPlayerScripts/
      Controllers/   -- UI and client-side visuals only
```

## Game systems (current design, as built)

Numbers live in Config; this section only summarizes the rules. **Config is the source of truth** for every number.
The design doc/PDF is older (see Pending design doc updates).

### Constellation binding
- Day/night cycle (`Config/DayNight`: 4 min day + 3 min night, "Night falls in 30s" warning). Each night one
  constellation (`Config/Constellations`), the same on every server.
- Players bind at a Star Altar. **Each player gets a separate server-side roll**; nobody competes for dragons.
- One bind per player per night. Rare constellations trigger a server-wide announcement and sky change.
- **Area rosters** (`Config/Areas` `Element` + `Species`): Starter Meadow = Common + Rare of every element (tonight's
  constellation picks the element); each element area is that element's home with all 5 rarities. A roll only picks
  rarities in the area's roster, so Epic/Legendary/Mythic are only bindable in their home area.
- The constellation in the sky when a dragon evolves decides its evolution branch (`Config/Evolution`).
- The Star Atlas and Dragon Index track constellations bound and species found (`Config/Index`).
- Starborn variants: a rare roll on any bind (`Config/Index` StarbornChance), x income / x power, own Index entry.

### Dragons
- Rarities: Common, Rare, Epic, Legendary, Mythic. Launch elements: Fire, Ice, Storm, Shadow (`Config/Dragons`).
- **No training.** Dragons level up by spending gold (`Config/Leveling`): income and power compound per level; costs
  rise per level, are higher for rarer dragons, and scale with rebirths done.
- **Level cap = 50 + 5 per rebirth** (`Config/Leveling` CapBase / CapPerRebirth). Areas do not set level caps.
- Evolution by level: Hatchling (1), Drake (10), Dragon (25), Elder (50) (`Config/Evolution` stage multipliers).
- Traits (Wyrm Runes, Rune Shrine) and grades (Dragonstones, Dragonstone Forge) are income/power multipliers
  (`Config/Traits`).

### Luck
Stacked as multipliers with a **cap** (`Config/Luck` Cap), and a higher **PotionCap** with an armed luck charge.
The altar luck panel shows the current luck before binding.
- Stardust offerings at the altar, moon phases, constellation luck (server-wide: e.g. Eclipse Serpent, Dragon King).
- Group binding: more players at the same altar = better odds.
- Area luck (`Config/Areas` BindLuck) and the **favored area**: an element area's altar gets `FavoredAreaLuck` on a
  night of its element (shown on the sky HUD and the luck panel).
- Luck boosts rarer tiers harder (`TierScaling`, see "Luck scaling" above).

### Roost / AFK income
- Dragons in the roost earn gold over time. Base gold/sec by rarity: `Config/Rarities` GoldPerSecond.
- Multiplied by level, evolution stage, branches, trait, grade, Starborn, the roost income upgrade, the rebirth bonus
  (`Config/Rebirth` IncomeBonusPerRebirth per rebirth) and the Dragon Index (`DragonStats.GetRoostIncome`).
- Offline and idle (20+ min without moving) earn `Config/Roost` OfflineIncomeMultiplier from a shared daily
  allowance (OfflineCapHours). Gold potions apply in game only; the 2x AFK Income pass applies offline/idle only.

### Economy (gold sinks)
- Leveling dragons (main sink); roost upgrades (slots and income, `Config/Economy`, bought at the stands in front of
  the roost); Stardust from the Star Merchant (price = a share of the next rebirth cost, rises per buy, resets at dawn).

### Rebirth + areas
- Rebirth resets **gold only**. Dragons, levels, evolutions, traits, grades, Stardust and roost upgrades are kept.
- Cost curve in `Config/Rebirth`: open-ended, with a weekly cap (`RebirthCap`, +5 per weekly update); at the cap,
  banked gold stops at one rebirth's cost. Each rebirth gives a permanent income bonus and +5 level cap, and counts
  toward area unlocks. Areas stay unlocked permanently.

| Area | Rebirths needed | Bind luck | Roster |
| --- | --- | --- | --- |
| Starter Meadow | 0 | 1x | Common + Rare of every element |
| Volcano Peak | 1 | 1.25x | Fire, all 5 rarities |
| Frozen Cliffs | 3 | 1.5x | Ice, all 5 (placeholder shell) |
| Storm Canyon | 5 | 2x | Storm, all 5 (placeholder shell) |
| Eclipse Isles (Shadow-themed) | 10 | 3x | Shadow, all 5 (placeholder shell) |

(`Config/Areas` is the source of truth for these numbers.)

### Dragon Spire (tower)
- Auto-battle with the player's most powerful dragon, one enemy per floor, every 10th floor a boss (`Config/Spire`).
- Each climb starts at floor 1. Floors far below the record, or far below the dragon's power (PowerFastRatio), go
  fast; the re-clear window near the record and new floors are real fights. The player must stay at the Spire.
- Rewards: first clears pay gold (seconds of roost income) plus guaranteed drops (potions, Wyrm Runes, Dragonstones,
  Stardust from bosses); re-clears near the record roll small chances; far-below floors give nothing.
- The Tower Elevator pass / Elevator Skip start a climb above the record.
- **No cosmetic rewards.** Enemies reuse existing dragon models.

### Boosts, quests, Index
- Potions and luck charges (`Config/Boosts`), daily/weekly quests + login streak (`Config/Quests`), Dragon Index
  bonuses and milestone rewards (`Config/Index`). The status table above says how each works.

### Monetization
Game passes and developer products in `Config/Products` (IDs are 0 until created in the Creator Dashboard).

| Feature | Type | What it does |
| --- | --- | --- |
| Tower Elevator Pass | Game pass | Spire climbs start above the record |
| Single Elevator Skip | Developer product | One such climb |
| 2x AFK Income | Game pass | Doubles offline and idle income only |
| Auto-bind | Game pass | Binds near the end of each night while in game, base luck, at the player's current area |

- Developer products go through `MarketplaceService.ProcessReceipt`; grant only after data is saved, and record
  receipt IDs to prevent double-granting.
- Paid features are convenience only; they must not beat active play, and nothing paid should affect PvP directly.

### Ranked PvP (post-launch, do not build yet)
- Rank tiers: Hatchling, Drake, Wyvern, Dragon, Elder, Celestial.
- Monthly seasons, matchmaking by rank and team power, top-100 lobby leaderboard.

## Open questions (ask before assuming)

- Evolution branch Spire battle perk: the Spire is built; the perk is still undefined (branches only boost income).
- Spire battle visuals: a fight is currently a 20 s timer bar in the Spire panel. Needs a visible dragon-vs-dragon
  fight (reusing dragon models) during UI polish.
- Starter dragon: `Cinderwing` is a placeholder in config; the user will decide later.

## Decisions made

- Title: **Bind A Dragon**.
- Spire/PvP combat: **auto-battle**, **one dragon** (the player's best).
- Rebirth should be **expensive** to lengthen play.
- Evolution branches (option B): each evolution under a night constellation gives +10% income (+20% if the
  constellation's element matches the dragon's) and tints the dragon's accent in that element. Evolving during
  the day gives a plain "Day" branch with no bonus. Numbers in `Config/Evolution`.
- `E:\Roblox\Bind A Dragon.pdf` is the team's copy of the design doc (exported from the Claude Doc linked above).
  **Only revise the doc/PDF when the user asks.** Until then, track changes in "Pending design doc updates" below.
- **Economy rebalance approved** (proposal v5 + follow-ups). Pacing targets: Dedicated (3–4 h/day + offline)
  reaches this week's rebirth cap in a median ~8 days, fastest 10% ≥ 6 days; Casual clearly slower; AFK-only and
  paying AFK (Auto-bind + 2x AFK) slower than Dedicated; the rebirth cost curve always rises; short dips from potion bursts are fine as long as the weekly-update and week-1 targets hold; a weekly
  update's +5 rebirths lasts a veteran most of the week. Simulation scripts are not in the repo (scratchpad only). Re-simulated with the built game (LateGrowth 2.69,
  Spire EnemyGrowth 1.215, power fast-forward): Dedicated R50 median 8.1 d (fastest 10% 6.0 d), Casual 18.5 d,
  paying AFK 12.3 d (12 check-ins), weekly update 6.1 d, Spire week-1 floor median 114.
- Paid passes must not beat active play: idling in game counts as offline after 20 min without input
  (`IdleAfterSeconds`); Auto-bind binds every night while in game at base luck, no offerings or potions.
- Luck potions are charges the player arms for the next bind (toggle in the Boosts panel or at the altar),
  not auto-consumed.
- Event dragons use ONE model for all stages (`Assets/Dragons/<SpeciesId>`), 1 model per weekly update.

## Pending design doc updates (apply when the user asks to revise the doc)

Doc and PDF last revised 2026-09-25. Changes since then (economy rebalance, approved):
- **Luck:** rare-tier scaling 0.4 → 0.3. Cap x10 without potions, **x20 hard cap** with one luck potion charge
  (Starlight ×1.5, Moonfire ×2), armed by the player for the next bind.
- **Offline income:** 100% → **50%** of online, still capped at 8 h/day; idling in game >20 min counts as offline.
  The 2x AFK Income pass doubles it.
- **Rebirth cost:** 10M ×5 → first 50M, ×3.71 per rebirth to R10, ×2.69 to R50, then weekly steps:
  one-time ×2.2 past each weekly cap, then ×2.17 per rebirth (bonus × level gain × 1.02). Open-ended; each weekly
  update adds +5 rebirths. At the cap, banked gold stops at one rebirth's cost ("Rebirth cap reached" message).
- **Rebirth reward:** new permanent income bonus **×1.59 per rebirth** (multiplying), plus +5 level cap per rebirth.
- **Level cap:** per-area caps (50/60/70/80/100) → **50 + 5 per rebirth**. Areas keep luck bonus + unlocks.
- **Levels:** income +15% of base per level → ×1.06 per level (compounding); power ×1.05 per level; cost base
  1K/5K/20K/100K/500K × 1.08 per level × 1.59 per rebirth done.
- **Base income** compressed: 750 / 1.8K / 4.4K / 11K / 29K gold/s (Mythic ≈ 40× Common, was 500×).
- **Traits and grades** become multipliers (e.g. Hoarder ×1.25 … Dragonlord ×25; grades D ×1 … SSS ×25).
- **Roost upgrades:** slots 250K / 25M / 2.5B / 250B / 25T; income +10% × 25 levels, 100K ×3.5 per level.
- **Star Merchant:** bundle price = 0.06% of the next rebirth cost, ×1.5 per buy, resets at dawn.
- **Day/night:** 8+4 min → **4 min day + 3 min night** (~8.6 binds/hour), "Night falls in 30s" warning,
  moon stays 8 phases (full moon every ~56 min). Starborn odds 1/850.
- **Starter dragon:** free Common Hatchling on first join (placeholder Cinderwing).
- **New systems:** timed Spire boosts (×2 / ×5 gold potions, luck charges, Wyrmblood, Conqueror's Brew,
  Runebright; stacking extends up to 60 min; timers pause offline; Premium +10% duration) with a Boosts panel;
  Dragon Index (+1%/species, ×1.3 per complete element, ×1.5 all 20, milestone items); Starborn variants
  (1/850, ×3 income, ×2 power); daily/weekly quests + login streak; weekly Spire leaderboard; weekly event
  constellation; Ascension (design only).
- **Spire:** enemy power 10 × 1.215^floor (bosses ×1.5), 150 floors at launch + 10 per weekly update, first-clear
  drops guaranteed, re-clears only near the record; Moonfire from floor 50, Starlight every 20th floor.
- **Build order** adds Phase 6 Monetization after the Spire.
- **Area rosters (approved and built 2026-09-26):** each element area is that element's home.
  Starter Meadow = Common + Rare of every element (tonight's constellation picks the element, rolls capped at Rare);
  Volcano Peak (R1) = all 5 Fire, Frozen Cliffs (R3) = all 5 Ice, Storm Canyon (R5) = all 5 Storm, Eclipse Isles
  (R10, renamed from Sky Isles, Shadow-themed) = all 5 Shadow. Epic/Legendary/Mythic only in their home area.
  In element areas a night of the same element gives that altar x1.5 luck. Constellation luck stays server-wide:
  the Eclipse Serpent's x1.5 applies at every altar (Eclipse Isles also gets the favored x1.5), the Dragon King x2
  everywhere. The HUD/luck panel show which area tonight favors. Auto-bind uses the altar of the area the player is
  in, at base luck. New daily quest "Bind in tonight's favored area". Event dragons: event nights, home-area altar.

When revising: update the Claude Doc via the docs connector, export the tab as PDF, and overwrite
`E:\Roblox\Bind A Dragon.pdf`.

## Working agreements for Claude Code

- Read the relevant config and service before editing a system.
- Keep changes scoped to the task; don't refactor unrelated systems.
- Put any new tunable number in Config, with a comment explaining it.
- When using Studio MCP to edit the place, describe the changes before making large ones.
- After finishing a system, update the **Current status** table above.
