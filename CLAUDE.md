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

**Phase:** Pre-production. Game design is complete. Project scaffolding is in place; no game systems yet.
_Update this section as work progresses._

| System | Status |
| --- | --- |
| Project setup (Rojo, Git, folder structure) | Done (Rojo 7.7.0, `default.project.json`, Init/Start bootstraps) |
| Player data / DataStore | Done: `DataService` (ProfileStore), template + migrations, types in `Shared/Types/PlayerData`. Studio uses a separate `PlayerData_Studio` store |
| Client data sync | Done: snapshot + auto-diffed changes (`DataService` → `DataController`); `PRIVATE_KEYS` stay server-only. Gold/Stardust HUD in `CurrencyController` |
| Day/night + constellation cycle | Done: `Shared/Cycle` (global clock, same night on every server), `DayNightService`, `DayNightController` |
| Binding (RNG, rarity, per-player rolls) | Done: `BindingService` (altars tagged `StarAltar` + `AreaId` attribute), placeholder roster in `Config/Dragons` |
| Luck system | Done: `Shared/Luck` (same math on server + client), `Config/Luck`; Stardust offerings (F at altar), moon phases, constellation luck, group luck, area luck, capped. Panel in `LuckController` |
| Dragons: leveling + evolution | Done: `DragonService` (LevelUpDragon remote, bulk-capable), costs in `Config/Leveling`, cap from areas, evolution branches in `dragon.Evolutions` give income bonus + accent color. Level up via E prompt on own roost dragons (`DragonPromptController`) until inventory UI exists |
| Roost + AFK income | Done: `RoostService` (payouts, offline capped, auto-fill slots, plot visuals), `Shared/DragonStats`, `Config/Roost`, `Config/Evolution`. No manual roost management UI yet |
| Gold sinks (Stardust shop, roost upgrades) | Not started |
| Rebirth + area unlocks | Done: `RebirthService` (RequestRebirth, cost in `Config/Rebirth`, ★ badge), `AreaService` (portals tagged `AreaPortal` → `AreaSpawn`, server-checked), `RebirthController` button + confirm panel. Volcano Peak built; other areas not yet |
| Dragon Spire (tower) | Not started |
| Game passes + developer products | Not started |
| UI | Not started |
| Ranked PvP | Post-launch |

**Next up:** dragon inventory UI (see all dragons, swap roost dragons, bulk level up), then Star Merchant
(Stardust for gold) and roost upgrades, then the Dragon Spire, then monetization.
UI polish after the core loop is playable.

**Luck scaling (decided):** luck boosts rarer tiers harder via `Config/Luck.TierScaling` (0.4):
Mythic 0.5% at x1 → 7.4% at the x10 cap.

**World (built in Studio, lives in the place file, not Git):** `Workspace.StarterMeadow` has terrain meadow,
the Star Altar (Model tagged `StarAltar`, `AreaId = "StarterMeadow"`, PrimaryPart `Core`), placeholder trees/rocks,
and the SpawnLocation. Any new altar just needs the tag + `AreaId` attribute; the Bind prompt is added by code.
`StarterMeadow.Roosts` has 8 plots (Models tagged `RoostPlot`, each with a `Perches` folder of 8 perch Models with
an `Index` attribute and pivot on the top surface facing the plot center, plus a `Sign` part). Keep server max
players ≤ 8, or add plots.
`Workspace.VolcanoPeak` (at z ≈ -900, past the meadow hills): basalt plateau, volcano, lava, red Star Altar
(`AreaId = "VolcanoPeak"`), `AreaSpawn`, and a portal back. The meadow has `Portal_VolcanoPeak` near the spawn and
its own `AreaSpawn`. New areas: build far away, add a `StarAltar` + `AreaSpawn` with the AreaId, and a portal.
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

## Game systems (summary of the design doc)

### Constellation binding
- Day/night cycle. Each night a constellation appears and sets the theme (e.g., element).
- Players bind at a Star Altar. **Each player gets a separate server-side roll**; nobody competes for dragons.
- One bind per player per constellation night.
- Rare constellations trigger a server-wide announcement and sky change.
- The constellation in the sky when a dragon evolves decides its evolution branch.
- Star Atlas tracks every constellation a player has bound to.

### Dragons
- Rarities: Common, Rare, Epic, Legendary, Mythic (possible Secret tier later).
- Launch elements: Fire, Ice, Storm, Shadow.
- **No training.** Dragons level up by spending gold. Costs rise per level and are higher for rarer dragons.
- Evolution by level: Hatchling (1), Drake (10), Dragon (25), Elder (50). Higher stages come with raised caps.

### Luck
Stacked as multipliers with a **total cap**. Show the current luck multiplier in the UI before binding.
- Stardust offerings at the altar before binding.
- Moon phases (full moon boost) and rare sky events (server-wide boost).
- Group binding: more players binding together = better odds for everyone.
- Area luck: higher areas' Star Altars give better odds.

### Roost / AFK income
- Dragons in the roost earn gold over time, including offline.
- Base gold/sec by rarity (placeholder): Common 1, Rare 5, Epic 20, Legendary 100, Mythic 500.
- Level and evolution stage multiply the base rate.
- Roost upgrades add slots and income multipliers.

### Economy (gold sinks)
- Leveling dragons (main sink).
- Stardust from the Star Merchant: price rises per purchase each day, resets at dawn.
- Roost upgrades.
- Costs scale roughly 2–3x per step.

### Rebirth + areas
- Rebirth resets **gold only**. Dragons, levels, and evolved forms are kept.
- Each rebirth raises the level cap and counts toward area unlocks. Areas stay unlocked permanently.

| Area | Rebirths needed | Bind luck | Level cap |
| --- | --- | --- | --- |
| Starter Meadow | 0 | 1x | 50 |
| Volcano Peak | 1 | 1.25x | 60 |
| Frozen Cliffs | 3 | 1.5x | 70 |
| Storm Canyon | 5 | 2x | 80 |
| Sky Isles | 10 | 3x | 100 |

### Dragon Spire (tower)
- Climb floor by floor; each floor is a fight against an enemy dragon; every 10th floor is a boss.
- Free players start at floor 1 each climb. Elevator (paid) starts from highest cleared floor.
- Rewards: gold per floor, Stardust from bosses, luck potions at floors 25/50/100, first-clear bonuses.
- Floors far below the dragon's power resolve instantly; already-cleared floors give reduced rewards.
- **No cosmetic rewards.** Enemies reuse existing dragon models.

### Monetization
| Feature | Type | Robux |
| --- | --- | --- |
| Tower Elevator Pass | Game pass | 300 |
| Single Elevator Skip | Developer product | 25–35 |
| 2x AFK Income | Game pass | 150–250 |
| Auto-bind | Game pass | 100–200 |

- Handle developer products with `MarketplaceService.ProcessReceipt`; grant only after data is saved,
  and record receipt IDs to prevent double-granting.
- Paid features are convenience only; nothing paid should affect PvP directly.

### Ranked PvP (post-launch, do not build yet)
- Rank tiers: Hatchling, Drake, Wyvern, Dragon, Elder, Celestial.
- Monthly seasons, matchmaking by rank and team power, top-100 lobby leaderboard.

## Open questions (ask before assuming)

- Rebirth cost: using 10M gold, x5 per rebirth ("expensive", to lengthen play) unless told otherwise.
- Evolution branch Spire battle perk: define when the Spire is built.

## Decisions made

- Title: **Bind A Dragon**.
- Spire/PvP combat: **auto-battle**, **one dragon** (the player's best).
- Rebirth should be **expensive** to lengthen play.
- Evolution branches (option B): each evolution under a night constellation gives +10% income (+20% if the
  constellation's element matches the dragon's) and tints the dragon's accent in that element. Evolving during
  the day gives a plain "Day" branch with no bonus. Numbers in `Config/Evolution`.
- `E:\Roblox\Bind A Dragon.pdf` is the team's copy of the design doc (exported from the Claude Doc linked above).
  **Only revise the doc/PDF when the user asks.** Until then, track changes in "Pending design doc updates" below.

## Pending design doc updates (apply when the user asks to revise the doc)

- Title is Bind A Dragon; combat is auto-battle with the player's best dragon (answers 3 open questions).
- Luck: 5 sources (Stardust offerings 3/night, 8-phase moon, rare constellation boost, group at altar, area), x10 cap,
  scales harder for rarer tiers (TierScaling).
- Evolution branches = option B (element income bonus + accent color; daytime = plain branch).
- Roost: one plot per player (8 per server), 3 base slots, auto-fill with best dragons, offline income capped 8h.
- Leveling cost formula (per-rarity base x 1.2^level); rebirth cost 10M x5 per rebirth.
- Day/night: 8 min day + 4 min night, same night and constellation on every server.
- Rebirth: ★ badge above the character; areas are reached by portals (locked ones refuse), not walked to.

## Working agreements for Claude Code

- Read the relevant config and service before editing a system.
- Keep changes scoped to the task; don't refactor unrelated systems.
- Put any new tunable number in Config, with a comment explaining it.
- When using Studio MCP to edit the place, describe the changes before making large ones.
- After finishing a system, update the **Current status** table above.
