# CLAUDE.md — Bind A Dragon (Roblox)

This file gives Claude Code the context for this project. Read it before making changes.
Keep it updated: when a system is finished or a design decision changes, edit the relevant section.

**Hakai gameplay polish economy (2026-10-02, feature branch):** level prices grow x1.08 per level with a server-saved
retained-income anchor and exact bulk/Auto-Upgrade sums; `Rebirth.LateGrowth = 2.31`. Paired 1,000-seed cohorts/profile
produce raw Dedicated R30 median **7.961 days** (3.5 scheduled active h/day + capped 50% offline); paid AFK **16.00 days**.
Latest-band roost-only grind median **12.12 minutes**, with a 15-minute quote floor. Finite first-clear Spire gold can
shorten individual bands and is already included in progression cohorts. Full evidence, assumptions and limitations:
[`tools/sim/Hakai_Polish_Results.md`](tools/sim/Hakai_Polish_Results.md). These simulations do not certify Studio flows.

## Project summary

A cooperative Roblox dragon-collecting idle game built by a 3-person team.
Players bind to constellations in the night sky to hatch dragons, level them with gold,
earn AFK income in a roost, rebirth to unlock new areas, and climb a tower (the Dragon Spire).
Ranked PvP comes after launch.

Full design doc (source of truth for game design):
https://claude.ai/code/artifact/a97e00fd-8305-4a44-b04a-663db52ab491

Plan docs in Git (copies of the originals in `E:\Roblox\`; edit the copy in `docs/` from now on):
`docs/World_UI_Remaster_Plan.md`, `docs/Valley_Layout_Proposal.md`, `docs/Economy_Rebalance_Proposal_v5.md`.
`AGENTS.md` points other coding agents (e.g. Codex) here.

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
| World leaderboards (2026-10-03 feature branch) | Implemented: tagged SurfaceGui boards for Rebirths, credited lifetime gold, and rarest base pair odds; budgeted monotonic OrderedDataStore writes, cached top ten/viewer ranks, Studio-suffixed stores and Rebirths leaderstats. Static checks pass; user-operated Hakai Test verification pending. Spire earnings are omitted because SpireService is protected; historical earnings cannot be recovered. See `docs/Leaderboards_Implementation.md`. |
| Area audio / dragon sounds (2026-10-03 feature branch) | Implemented: five area day/night palettes, crossfades, rarity fanfares, remote-driven Spire music, unique timed feedback and capped nearby 3D dragon cues. Config checks pass; 15 new public APM/PSE listings verified for provenance only. Actual load permissions, listening, loop seams and Studio flows remain user-test pending; `AudioController.GetLoadReport()` exposes runtime diagnostics. All IDs and checklist: `docs/Audio_Manifest.md`. |
| First-time onboarding (2026-10-03 feature branch) | Implemented: server-owned skippable progress, once-only daytime Rare-or-better conditional bind with accurately labeled odds, falling-star prelude, local star trails, Inventory pointer and separate free-upgrade action, next-night and contextual hints. Four appended saved fields use Reconcile without a data-version bump. Five pools and 500,000 seeded rolls pass portable checks; Hakai Test flows remain unverified. Protected HUD/Inventory prevent exact Home/internal Upgrade pointers; documented fallbacks in `docs/Onboarding_Implementation.md`, proposal in `docs/Onboarding_Proposal.md`. |
| Day/night + constellation cycle | Done: `Shared/Cycle` (global clock, same night on every server; `GetNightBlend` for visuals), `DayNightService`, `DayNightController` (clock + the day/night card at the top: sun/moon icon, phase + time left, tonight's luck line, progress bar, pop on phase change; wording in `Config/Text.SkyHud`, sizes `UITheme.Sizes.SkyCard`/`PhoneSkyCard`; design by Kyle) |
| Atmosphere (meadow wow pass, phase 1) | Done (NightGlow parts with a SurfaceAppearance glow through its emissive: `GlowStrength` attribute): per-area Day/Night looks in `Config/Atmosphere` (`AtmosphereController`: ambient, haze, bloom, color correction, sun rays, far blur, 3D clouds (`Terrain.Clouds`, per-area cover/density/color); blends at dusk/dawn and on area change; night tint by element), tonight's constellation drawn in the sky + shooting stars (`SkyController`, drawings in `Config/Constellations` Stars/Lines; drawn 2,000 studs out following the camera like a skybox, as depth-tested pixel-sized BillboardGuis, so the Spire, buildings and mountains hide it and the haze doesn't fade it), lanterns (tag `Lantern`, Atomic) lit at dusk with flicker, max 8 lights (`WorldLifeController`), drifting particles per area (petals/fireflies, embers, snow...), music + ambience crossfade and 3D world sounds (`AudioController`, `Config/Audio`). `EffectsQuality` = Low effects (setting or low graphics quality). Lighting uses `Lighting.LightingStyle = Realistic` (set in Studio; replaces the old Future technology) |
| Altar glow + binding ceremony (wow pass, phase 2) | Done: `AltarGlowController` (every `StarAltar`: beam from the main crystal, glow sprites on `Glow/GlowAnchor` parts (Rank 1 = main crystal; only `MaxLights` cast light), rising sparkles, pulsing Highlight up close; element color, brighter when favored; `Config/AltarGlow`). `CeremonyController` (`Config/Ceremony`): after the server's BindResult, camera eases in, tonight's sky stars streak into the altar, rarity/mutation burst + flash, the dragon rises with its name; Legendary/Mythic/Primordial = big; skippable; no ceremony for Auto-bind or idle players; Quick binds remain supported |
| In-world UI (wow pass, phase 3) | Done (`Config/WorldUI`): `PromptController` draws every ProximityPrompt in the UI theme (Style = Custom; key badge, icon, hold ring, tap/click to use). Portal warp in `PortalController` (whoosh, FOV kick, color flash). `RoostFXController`: owner banners with avatar (replace the server sign locally), "+gold" pops from your roost dragons, level-up/evolve bursts. `StationFXController`: rune/stone count boards, shrine glow and forge flare while you own runes/stones, merchant price board, Spire door record board (`UI/WorldBoard`). Note: Studio screenshots don't show `AlwaysOnTop` billboards (prompts); they do show in play |
| Game feel (wow pass, phase 4) | Done: `FeedbackController` + `Config/Feedback`: one sound palette (level-up, buy, arm, climb start, floor clear, Index entry, reward, rebirth) with a small camera shake and screen flash, driven by data changes and SpireUpdate; shake/flash off with Low effects. A palette sound replaces the toast chime when both fire together (`Style.MarkFeedbackSound`); UI sounds follow the SoundVolume setting |
| Settings (wow pass, phase 5) | Done: Settings window (`SettingsController`, menu tile) with Music / Sound sliders (5% steps) and Low effects / Quick binds toggles; applied at once as LocalPlayer attributes (`MusicVolume`, `SoundVolume`, `LowEffects`, `QuickBinds`), saved to `data.Settings` via the `SaveSettings` remote (`SettingsService`: type-checked, clamped, rate-limited) after a short debounce. Defaults in `Config/Data.DefaultSettings`; data version 2 (migration fills missing settings) |
| World remaster (plan: `docs/World_UI_Remaster_Plan.md`) | In progress (overnight run, log: `E:\Roblox\Bind A Dragon - Remaster Progress Log.md`). Stage 2 blockout done: areas moved ≥ 1,200 studs apart (see World), terrain shapes for all 5 areas, horizon landmarks (`HorizonController`, `Config/Horizon`), portal streaming in `AreaService`. AI prop kits in `ServerStorage.PropKits` (`AI_<Area>_<Prop>`, pivot at the bottom, `Triangles` attribute) and stylized terrain materials done. Stage 3: Starter Meadow detailed (e1) and rebuilt as a hub (e1b: raised plaza + ring road, 6 big pens, portals in the north half with themed gateways, flagstone roads, market row, groves, ground variety; `AmbientFXController` lowers world particles with Low effects). Art direction "The Starlit Highlands" (plan section 2b): `SunColor` per look (`AtmosphereController`), `NightGlow` tag (parts glow Neon at night, `WorldLifeController`). Now: the Starter Meadow rebuilt as "the Valley" from the concept image (checkpoints A–E done: terrain, hub layout with spawn zones, nature/ruins/landmarks/lighting, perches for flying dragons). Proposed: painted skybox for weak phones Volcano Peak after the Valley |
| Binding (RNG, rarity, mutations) | Done: direct server roll over every eligible `SpeciesId × MutationId` outcome (`Shared/BindingOdds`); species weights/stats in `Config/Dragons`; Normal/Hoardscale/Warcrest/Aetherwing/Primordial in `Config/Mutations`; area/element filtering precedes normalization; luck applies once to each pair; Auto-bind remains base luck. Earned Echo Sigils permit extra manual binds (cap 6; one from all dailies and one from five non-fast Spire wins per UTC day) |
| Luck system | Done: `Shared/Luck` (same math on server + client), `Config/Luck`; Stardust offerings (F at altar), moon phases, constellation luck, group luck, area luck, capped. Panel in `LuckController` |
| Dragons: leveling + evolution | Done: `DragonService` (LevelUpDragon remote, bulk-capable), costs and the level cap (50 + 5 per rebirth) in `Config/Leveling`, evolution branches in `dragon.Evolutions` give income bonus + accent color. Level up in the Dragons panel (`InventoryController`) or via the E prompt on own roost dragons (`DragonPromptController`); one evolution toast per level-up |
| Roost + AFK income | Done: `RoostService` (payouts, offline capped, auto-fill slots, plot visuals), `Shared/DragonStats`, `Config/Roost`, `Config/Evolution`. Roost is a Dragon Sanctuary where dragons roam (`RoostAnimationController`); new dragons appear in their stage's zone (nesting ground / meadow, `Shared/RoostZones`, `Config/Evolution` `Zone`) and walkers stay in it; fliers cruise at their own height (stage `FlyHeightRange`, Elders 44-68 (Dragons 20-32), spread by dragon id) with swoops now and then, steer/climb apart when crowded (`Config/Roost.Separation`) and take turns (`Config/Roost.Turns`: at most `MaxAirborne` (4) of a pen in the air; after a flight they land on a free perch or lie down on a free spot in the meadow zone, rest, then take off when the sky has room); real art with a bone map in `Config/DragonRigs` moves its bones (`Controllers/DragonRig`: flap bursts with glides, hover beats at take off/landing, sweep/elbow fold, dive sweep, banking, body pitch with the climb, roars in the air; perched/lying: folded wings, breathing, weight shift, head looking around and idle actions (Stretch, Roar, Yawn, Shake, Preen, TailFlick) picked by weight (`DragonRigs.Actions`); lying down = legs folded, head low, tail curled; full detail near the camera, wings+tail+head farther, none beyond; shorter with Low effects). Bone maps: Solflare, Aurorynth, Borealis, Duskling, Infernus (Elder; per-rig wing tuning `WingLevel`/`WingFold`/`WingFoldBack`/`RestWingFold` for models whose rest pose has raised wings); "Place in roost" / "Take out" on each Dragons panel card (`ReturnFromRoost` remote; a dragon taken out stays out of the auto-fill until placed again: `data.RoostUnplacedDragonIds`, server-only) |
| Gold sinks (Stardust shop, roost upgrades) | Done: `EconomyService` (Star Merchant prompt on `StarMerchant` tag, price resets at dawn; BuyRoostUpgrade Slots/Income), `Config/Economy`, `MerchantController`; roost upgrades are bought at stands in front of the roost (`RoostUpgradeController`: the owner's prompts). The stands are shrines in the altar's style that show everyone the owner's progress (`UpgradeStandController`, `Config/WorldUI.UpgradeStands`, wording `Config/Text.UpgradeStands`; levels from the plot attributes `RoostSlots` / `RoostIncomeLevel`, set by `RoostService`): a floating star egg circled by crystals + 8 gems (one per slot), a gold hoard bowl with a floating star coin + 5 jade gems (5 income levels each), a board with the level, glow/sparkles when near, a sparkle burst on each upgrade, gold glow when maxed. **Sanctuary tiers:** the whole sanctuary grows grander with the owner's upgrades (`SanctuaryTierController`, `Config/WorldUI.SanctuaryTiers`): points = extra slots + income levels / 5, a tier per 2 points: 1 Gilded (gold rim trim, gate banners), 2 Runed (glowing rune circle in the meadow, fire braziers), 3 Crystal (crystals at the rock pillars, drifting motes), 4 Ascendant (glowing pillar runes, an aurora at night), 5 Legendary (a starlight beam into the sky, golden dragon statues on the gate); tiers add up, a starburst + sound at the gate on each new tier (toast for the owner). The art is built per sanctuary by `ValleyBuild.BuildSanctuaryTiers` into `ReplicatedStorage.Assets.SanctuaryTiers.<PlotName>.TierN` (world position) and cloned in locally only for the tiers reached |
| Rebirth + area unlocks | Done: `RebirthService` (RequestRebirth, cost in `Config/Rebirth`, ★ badge), `AreaService` (portals tagged `AreaPortal` → `AreaSpawn`, server-checked), `RebirthController` button + confirm panel. Volcano Peak built; Frozen Cliffs, Storm Canyon and Eclipse Isles are placeholder shells (see World) |
| Traits + grades | Done: `Config/Traits` (11 traits, 7 grades), rolls in `DragonService` (RollTrait/RollGrade, must be at the station), `RollStationController` panel at the Rune Shrine ("Inscribe a Rune") / Dragonstone Forge ("Temper"); wording in `Config/Text`, no dice/gacha words in player-facing text. Dragons have Power (`DragonStats.GetPower`). Wyrm Runes/Dragonstones come from the Spire, quests, streak and Index |
| Economy rebalance (big numbers, open-ended rebirths) | Done (Phases 1–6). Phase 1: new configs, multiplicative levels/traits/grades, rebirth curve + weekly cap (`DragonStats.GetRebirthCost`, `IsAtRebirthCap`, gold clamps at the cap), ×1.59 rebirth income bonus, level cap 50 + 5/rebirth, idle >20 min = offline rate from the 8 h/day allowance (`RoostService`), starter dragon (`Config/Data.StarterDragon`), dusk warning. Phases 2–6 in the rows below |
| Boosts / potions + Boosts panel | Done: `Config/Boosts` (7 potions), `BoostService` (UseBoost remote, timers tick only in game, 60 min max stored, Premium +10%, `GetMultiplier`/`GrantPotion`), gold boosts in `RoostService` (in game only), Runebright roll luck in `DragonService` (`Luck.GetTierWeights`), luck charges armed via Boosts panel or the altar luck panel and used up by the next bind (`Luck.GetArmedPotionLuck`, up to `PotionCap`). `BoostController` panel + HUD timers, count badge + pulse on the Boosts button, one-time potion hint. Potions come from the Spire, quests, streak and Index |
| Dragon Index + mutations | Done: species-only progression/rewards plus optional per-species mutation badges (`MutationIndex`); mutations never inflate completion income. Dormant Starborn code is removed; data v3 defensively maps any prototype Starborn record to Primordial. `IndexController` retains the species grid and Star Atlas |
| Daily/weekly quests + login streak | Done (streak: Gilded, 30 Stardust, Rune+Stone, 2 Gilded, Hoard, 2 Runes+2 Stones, Moonfire): `Config/Quests` (pools, per-slot rewards, streak rewards), `QuestService` (3 daily / 2 weekly picked per UTC day / Monday week, auto-granted on completion, `Progress(player, kind, amount)` from Binding/Dragon/Roost services; Gold targets = minutes of roost income), login streak on first join per UTC day. `Shared/Rewards` (Describe/Apply) shared with the Index. `QuestController` panel |
| Dragon Spire (tower) | Done (Kyle's Hakai polish, merged 2026-10-02; checkpoint 4 of the 2026-10-02 update replaces it with difficulties): `Config/Spire` (100 stages, `FightSeconds` 12 each, ~20 min for a full run, drop tables), `SpireService` (prompt on `DragonSpire` tag or SpireAction Start/Stop/AutoRepeat; server-run: every run fights stages 1-100 in order, no fast-forward, no skipping; must stay within `EntranceRange`; a loss, death, Stop or leaving range ends the run; **Auto-Repeat** (default OFF, validated boolean toggle) restarts at stage 1 only after stage 100; first clear of a stage = 30 s of income + guaranteed drops; every boss victory gives 1 Wyrm Rune + 1 Dragonstone, so a first full run gives 30 + 30 and a repeat run 10 + 10 (before boosts); Wyrmblood power, Conqueror's Brew rewards), `data.SpireRecord`, `SpireController` battle HUD (opens at the tower; see UI). The Elevator is retired (see Monetization). Placeholder tower only; no interior/arena yet |
| Game passes + developer products | Done: `Config/Products` (IDs are 0 = not created yet; paste real IDs), `MonetizationService` (pass cache + `Pass_<Key>` player attributes, `WaitForPasses`, `ProcessReceipt` grants, records PurchaseId, confirms only after ProfileStore saved it). Tower Elevator / Elevator Skip are retired: the Spire no longer skips stages, purchases/skip controls are disabled and old entitlements/counts (`data.ElevatorSkips`) are kept but never consumed (product IDs must stay 0 until a replacement exists); 2x AFK Income doubles offline + idle income only; Auto-bind binds at base luck with `AutoBindSecondsLeft` of night left. `ShopController`. Studio: server-side Player attribute `TestPass_<Key>` grants a pass |
| Sanctuary looks (Valley rework, checkpoint 4 of 4) | In progress (checkpoint 4 built, perf measurement + look-change polish still open): `Shared/SanctuaryLooks` (points = extra slots + income levels/5 -> look: WildHollow 0, CrystalGarden 4, CelestialSanctum 8; `Config/WorldUI.SanctuaryLooks`, wording `Text.Moments.Look`), `RoostService` sets the plot attribute `SanctuaryLook` (Studio: Player attribute `TestSanctuaryLook` forces one), `SanctuaryLookController` clones `ReplicatedStorage.Assets.SanctuaryLooks.<Look>.<PlotName>` (a Folder of piece Models, pivot at the base) in within 320 studs, drops it beyond 380, grows the pieces from the gate outward on a look change with a burst and a "New look!" pop-up (a look with no kit yet shows the default look). Kits are built by the Studio module `ServerStorage.RemasterTools.SanctuaryLooks` (reference copy `tools/valley_build/SanctuaryLooks.luau`; `BuildWildHollow()`, `Preview(plot)`, `Stats`). **Wild Hollow built** (gate of log posts, mossy wall, AI nest tree 48 tall as the centerpiece with a glowing hollow facing the gate, AI mossy spires on the Elder pads and log stumps on the Dragon pads, stepping-stone path, spring pond, nests, flowers; about 40k AI-mesh faces + ~150 parts per sanctuary, AI meshes in `ServerStorage.PropKits.SanctuaryLooks`). **Crystal Garden built** (module `SanctuaryLooksCrystal`, reference `tools/valley_build/SanctuaryLooksCrystal.luau`: marble-and-gold wall with crystal posts, columns gate with rune glyphs and no statues, AI giant crystal `CG_Crystal` on a marble plaza, AI marble pillars `CG_Pillar` + AI `CG_CrystalCluster` on the perches, crystal-lined pool with a sparkle fountain, star-blossom trees from the Fantasy kit; about 40k AI-mesh faces + 6 store trees (1.2k each) + ~300 parts). Each look is its own module and shares helpers through `SanctuaryLooks.H`. Tier art that clashes with a look is removed from the local tier clones (`WorldUI.SanctuaryLooks.HideTierArt`: Crystal Garden hides `PillarCrystals` and `GoldenGuardian`; `SanctuaryTierController`). Night glow of the tiers, gate runes, stands and crystals is softer (`ValleyBuild.TierColors.TrimGlow`, Rune). Upgrade stands are 2.4x (`ValleyBuild.StandScale`, `WorldUI.UpgradeStands` BoardHeight 23). **Celestial Sanctum built** (module `SanctuaryLooksCelestial`, reference `tools/valley_build/SanctuaryLooksCelestial.luau`, concept `assets/concepts/sanctuary_celestial.png`; same slots; code-built: gold-trimmed marble wall with crystal posts and glass niches, columns + gold-arch gate, flat constellation floor inlay (gold lines `NightGlow`), three spinning gold armillary rings (parts spun by `SanctuaryLookController` via model attributes `SpinAxis`/`SpinSpeed` within `SpinDistance` 220), gold rings holding the perches, pool, a starlight beam; Studio `generate_mesh`: `CE_NestDome` (star-crystal nest dome), `CE_FloatRock` (floating perch rocks, solid, stretched onto each pad), `CE_DragonStatue` (golden dragon statues at the gate, texture stripped to Metal gold); kit props: star-blossom trees, small firs, nests, crystal clusters; no Blender pieces in game; ~37k AI-mesh faces + ~720 parts + store trees per sanctuary). **Elder detail by distance** (`Config/DragonRigs`: `LodEnabled` **false**, `LodPart` `BodyLOD`, `LodDistance` 120, `HideDistance` 260, `LowEffectsMaxVisible` 4; `RoostAnimationController`): dragons beyond 260 studs are hidden and with Low effects a sanctuary draws only its 4 nearest; the custom LOD swap (a 4k-triangle `BodyLOD` mesh) is coded but OFF because the generated meshes had holes, so Elders always draw the full `Body` (RenderFidelity Automatic). The five imported LOD meshes are parked in `ServerStorage.LodParked` (not in the Elder models). Measured in Studio Play, 6 Celestial kits + 48 Elders, main-pass triangles / batches: PC (quality 10) 875k / 846 (kits ~215k, dragons ~130k); phone-like (quality 1, Low effects) 495k / 281 (kits ~200k, dragons ~50k); with the LOD swap on they were 803k and 473k. Studio's own fps counter stays at ~27 whatever the load, so it can't rank scenarios. If a custom LOD is ever needed: merge by distance before decimating, keep boundaries, recompute normals, check flipped faces, ~1.5k triangles, put it in the same FBX as Body and review stills first. |
| Dragon Hotbar + carried companion (2026-10-02 update, checkpoint 2) | Done: `data.Hotbar` (10 dragon ids, "" = empty, data version 4 with a migration; `Config/Hotbar`, wording `Text.Hotbar`). `HotbarController`: 10 slots bottom-center (keys 1-9, 0 or tap; Roblox's Backpack bar is off), each a card tinted in the dragon's rarity color with its picture (`UI/DragonPicture`), a mutation-colored glow for mutated dragons, a gold outline on the carried one, key number, tooltip; empty slots show a hint toast; hidden while the Spire HUD is open; phones show 5 slots at 46 px (>= 44) with a small page arrow for slots 6-10 (`PhoneSlotsPerPage`), PC shows all 10. Inventory Dragons cards have an "Add to hotbar" / "Remove from bar" button (first empty slot; `SetHotbarSlot`). `HotbarService` (server): `SetHotbarSlot(slot, dragonId)` and `CarryDragon(slot)` (same slot again = put away; one carried at a time), type-checked, rate limited (`SetCooldown` 0.1 s, `CarryCooldown` 0.4 s), the dragon must be the player's own, a dragon sits in one slot at most, a carried dragon removed from the bar is put away, the stage is re-checked every 2 s; the carried dragon is published as Player attributes `CarryDragonId/CarrySpecies/CarryMutation/CarryStage/CarryChampion` so every client can draw it. `CompanionController`: every client draws every player's carried dragon beside them (client-only clone of the art, scaled to `CompanionSpan`, follows with a lerp + bob + bank, bones animated by `DragonRig` when the species has a bone map, mutation/champion aura = Sparkles named `MutationAura`, not drawn beyond `RenderDistance` or with Low effects; checkpoint 5 redoes the auras). Hotbar dragons are protected from selling (checkpoint 3). Dev ops `Hotbar` and `Carry`. |
| Star Merchant dialog + selling (2026-10-02 update, checkpoint 3) | Built, **selling numbers wait for approval** (`docs/Merchant_Selling_Proposal.md`, sim-checked: no pacing change). `MerchantController`: a speech bubble ("Welcome, binder!") over every `StarMerchant` when you're within 28 studs, the E prompt opens a dialog [Buy Stardust] [Sell Dragons] [Sell Items] [Bye] (closes when you walk away or the tag goes), pages: Buy (Kyle's live price), Sell Dragons (tick rows, "Select all Commons", gold + Runes/Stones shown, confirm; Epic+/mutated get a second "Are you sure?" naming them), Sell Items (potions, Wyrm Runes, Dragonstones: Sell 1 / Sell all). `SellService` (server): `SellDragons(ids, confirmedRisky)` atomic, refuses dragons in the roost, on the hotbar, carried, locked (`dragon.Locked`, `SetDragonLocked`, Lock chip on Inventory cards) or the champion, risky sales need `confirmedRisky`, must be near a merchant (`EconomyService:NearMerchant`), 0.5 s rate limit, gold clamped at the rebirth-cap bank; `SellItems(kind, id, count)` pays seconds of roost income per item (armed luck charge kept; Stardust not sold). Prices: `Config/Economy.Selling`, `DragonStats.GetSellValue/GetSellProtection/IsRiskySale` (shared by client and server). The NPC model (`assets/NPC/Star_Merchant.glb` -> `assets/NPC/fbx/Star_Merchant.fbx` via `tools/glb_to_fbx.py --length 5`: cute standing baby dragon in a starry cape, 11.5k -> ~10k triangles, 76 bones, 6 studs tall) still has to be imported in Studio and placed beside the market (tag `StarMerchant`, an `InteractionAnchor` part; EconomyService adds the prompt); until then no merchant is tagged in the place. |
| Travel | Done (UI renewal checkpoint 1, 2026-09-28; based on Kyle's Hakai branch): three HUD icons at the very top-center (in the middle of Roblox's top bar, `ScreenInsets.None`), Portals | Home | Market (`TravelController`, `Config/Travel`, looks `UITheme.Travel`, wording `Config/Text.Travel`); `TravelService` checks the id, cooldown and that the player is alive, streams the spot in, then teleports onto the matching part in `StarterMeadow.TravelPoints` (Home = the player's own sanctuary forecourt, the Altar before they have one; Portals = the front of the portal terrace; Market = the valley mouth spawn); works from every area; the client swings the camera to face the spot |
| Weekly Spire leaderboard | Proposed (weekly update) |
| Weekly event constellation (event-only dragon, single model) | Proposed (weekly update) |
| Ascension (second prestige) | Proposed (design only, post-launch) |
| UI | **HUD layout (2026-10-02, supersedes any older text below about the sky pill, bottom navigation or portrait):** landscape only; travel row top-center (Portals | Home | Market (+ Altars)); the 4 menu icons on the left, a bit above the vertical center (`Sizes.MenuRaise`) (Inventory, Quests, Shop, Rebirth) with a `Sizes.LeftMargin` (64, phone 36) margin; currency pills stacked bottom-left; **phones use exactly the same arrangement, just smaller** (the Bind Luck panel is the PC panel at 0.5 scale, from the top on phones so it clears the timers); **bottom-right timer stack** (`HudLayout.GetTimerStack`, `Sizes.RightMargin` 64 / phone 36, above the jump button on phones): the day/night timer row (`UI/TimerRow`: sun/moon icon + bold italic white text with a dark outline, no background, "Night in 1m 42s", gold at dusk) with a small caption under it ("Tonight: The Veiled Eye · favors Eclipse Isles", `DayNightController`, `Text.SkyHud`), then the potion timers as a horizontal row (icon with the time under each, `BoostController`); bottom-center is the Dragon Hotbar; on phones the timer stack sits above Roblox's real jump button (`HudLayout.jumpReserve`: TouchGui JumpButton position, else `Sizes.PhoneJumpReserve`). The sky pill and `UI/SkyPill` are gone. Every gui uses `ScreenInsets.CoreUISafeInsets` (travel row and top-bar buttons None); `HudLayout.GetUsableRect()` is the safe rect in screen pixels (the probe's own AbsolutePosition is inset-local, so the top-left `GuiService:GetGuiInset()` is added). Windows start under the travel row (`HudLayout.TopReserved`). Odds: pop-up lines are whole numbers (`OddsText.OneIn`), exact decimals only in the tap-for-details breakdown (`OddsText.OneInExact`). **UI renewal done** (master prompt 2026-09-28, checkpoints: 1 HUD, 2 windows, 3 world UI). **UI renewal part 2 done** (2026-09-29/30, style sheet approved; checkpoints: 1 top bar + notifications, 2 Inventory + windows, 3 Spire HUD + world UI). **Checkpoint 3:** the Spire card is a compact battle HUD at the bottom center (`SpireController`, sizes `UITheme.Sizes.Spire*`, motion `UITheme.Motion.Spire*`, words `Text.Spire`): a big floor badge on its top edge ("Floor 40", gold BOSS tag on boss floors) with the record small under it, your dragon's portrait vs the enemy's (`UI/DragonPicture`, VS in the middle) each with a health bar that drains over the fight (the server already decided the winner; the attacker lunges, the defender flinches, off with Low effects), no text log: each cleared floor pops a "Floor 39 cleared!" chip (first clears sparkle) and the drops fly as icons into the Inventory button (`HudLayout.GetMenuButton`; never the toast queue); Stop = small rose button, Hide (–) minimizes to a small floor badge (tap = open again); between climbs: your best dragon + Climb / Elevator. `SpireUpdate` now also sends `SpeciesId`/`Level`/`EnemyId` (Fight) and `Reward`/`Gold` (Won). Phones: the same HUD at `PhoneSpireScale`, bottom center between the thumbstick and jump. One thing at a time at stations: a station's board hides while its own prompt shows, and your own ★ badge hides while any prompt shows or near a Spire/merchant board (`StationFXController`, `WorldUI.Stations.HideBoardWithPrompt`/`BadgeHideRange`). Boards: "Best floor N" / "5 Stardust" + price. World panels get the faint sparkle pattern. Long toasts shrink their text to fit (never clip); tooltips hide when their target hides. **Checkpoint 2:** Dragons tab (`InventoryController`): cards tinted + glowing in the rarity color with a picture (`UI/DragonPicture`), rarity icon + level, name, "Rarity · Element", income big, ONE Upgrade button with the cost (tap = +1, hold = keeps buying 1 → 5 → 25 levels per request, `UITheme.Motion.Upgrade*`, above DragonService's 0.1 s limit), a small In roost / Resting switch; power/trait/grade in the tooltip; header "Equip best" = new `EquipBest` remote (`RoostService.onEquipBest`: no arguments, 1 s rate limit, ranks by gold/sec, fills up to the slot count, clears the equipped dragons' "taken out" marks, toast `Text.Dragons.Equipped`). Potions tab: big cards (picture, count badge, one line, status, one button; Arm = jade). Collection: header card (income bonus big, found count, milestone bar; rules in the tooltip), bigger rarity-tinted cells, Star Atlas chips. Quests: bigger streak days (today gold, claimed jade), title-font quests with bigger rewards/bars. Shop: 2x2 big cards (short line `Text.Shop.Short`, full description in the tooltip). Luck panel: one row per factor (x1 dimmed). Rune Shrine / Forge rows show the dragon's picture; button "Inscribe · 1" with the rune/stone icon. Settings rows in the title font. Currency pills violet with a gold border; red badges brighter and pop on change; progress bars gold-rimmed and glossy. Phone cards drawn at `Sizes.PhoneCardScale`. Windows use the full height below the top bar (up to their MaxSize). Part 2 kit: panels are indigo -> violet (`Colors.PanelV2*`) with a faint sparkle pattern (`Art.PanelPattern`) and a soft outer glow (`Style.Glow`, `Art.Glow` 9-sliced); the banner's dark ribbon ends are gone (gold end gems + glow); chunky 3D buttons (`UI/Button`: face on a darker bottom edge, bounce/squish, Luckiest Guy label; jade = go/buy, gold = upgrade, rose = stop/close, blue = neutral, grey = disabled); cards tinted + glowing in their accent (`Style.CardLook`), tabs `Style.TabLook`; windows fade + pop in. Art sources `tools/ui_art/gen.py` -> `assets/ui/` (sparkles, glow, rays, stand-in sun/moon). **Top bar:** travel buttons get equal slots (`Sizes.TravelSlot`, labels never clip); the sky pill (`UI/SkyPill`, `DayNightController`) sits under them with a gap (`HudLayout.SkyPillTop`): big sun/moon, "Night in 3:31" big, at night a small constellation + favored-area line, a thin progress bar, glows/pulses in the dusk-warning seconds (wording `Text.SkyHud` Big*/Small*). Windows (`HudLayout.layoutPopups`) and toasts start below `HudLayout.TopReserved()` (top bar + pill), so they never cover them; the travel row and pill stay visible on phones. **Notifications** (`NotificationController`): one toast queue (at most `UITheme.Toasts.MaxVisible` = 2 on screen, the same text merges into "x3" and restarts, announcements/rewards/errors jump the queue); toasts are pills with a big icon (`UI/Toast`). Big moments show a centered reward pop-up (`UI/RewardPopup`: turning rays, banner, big picture (`UI/DragonPicture`: the dragon's model in a ViewportFrame, or its rarity icon), name, tag chip, "Awesome!", sparkle burst; one at a time, queued; closes by itself after 8 s; the dim leaves the top bar clear): new dragon (bind, starter), evolution, rebirth, sanctuary tier, rare constellation. The server sends them as `Notify(player, text, "moment", payload)` / `Announcement(text, payload)` with `payload.Moment` (DragonService, RebirthService, DayNightService); the client also calls `NotificationController:Moment` (BindingController, SanctuaryTierController). Wording `Text.Moments`. Low effects: fewer sparkles, no turning rays. HUD now: big standalone icons with a drop shadow and a Luckiest Guy label (`UI/HudIcon`: hover bounce + glow, press squish, tap sparkles, red badge, pulse, "ready" = gold glow + hop + sparkle ring + READY! tag, calm = progress ring of dots). Left column (`HudLayout`, `UITheme.Menu`): Inventory, Quests, Shop, Rebirth (READY! when affordable, else % to the next rebirth). **Inventory** = one window with tabs (`InventoryWindow`, `UITheme.InventoryTabs`): Dragons (`InventoryController`), Potions (`BoostController`), Items (`ItemsController`: Wyrm Runes, Dragonstones, Stardust; wording `Config/Text.Items`), Collection (`IndexController`: Index + Star Atlas); tab badges add up on the Inventory icon. Settings = a gear right after Roblox's own top-bar buttons (`HudLayout.AddTopbarButton`, lined up with `GuiService.TopbarInset`; Roblox's own settings image). Top-center: the travel row and under it the slim day/night pill (`DayNightController`, `Text.SkyHud` Pill*). Bottom-right: active potions as their own icons with the time under each (tap = Potions tab; phones: above the jump button, max `PhoneMaxTimers` then "+N"). Currency pills restyled (big icon over a translucent bar, title-font value): bottom-left on PC, one row under the top bar on phones. HUD sizes/motion in `UITheme.Sizes` (HudIcon..., Travel..., SkyPill, PotionTimer) and `UITheme.Motion` (Icon..., Ready..., ProgressDots). Painted icons for Inventory (satchel), Home (cottage), Portals, Market (tent), Items and Collection (star atlas) in `UITheme.Icons` (sheet `assets/new_icons.png`, cut to `assets/icons/`). **Windows (checkpoint 2):** one frame for every window and station panel (`Style.PanelLook`): navy glass (`Colors.Glass*`, `GlassTransparency`) with a soft light across the top, a gold border shaded light to dark (`Style.GoldBorder`) with a thin gold line inside, a gold diamond with a jewel on each corner plus gold beads (`Style.Ornament`), a small ornament mid-bottom, sparkles. `UI/Window`: a jewel title banner (`UI/Banner`: amethyst ribbon, gold border, ribbon ends, a slowly wobbling gold star on top, the painted icon popping out on the left, title in Luckiest Guy) hangs on the top edge; a big round ruby close button on the top-right corner (the X turns on hover); pop-in plus a sparkle burst out of the banner (`Style.SparkleBurst`). Sizes in `UITheme.Sizes` (Border, CornerOrnament, Banner, BannerStar, CloseButton, WindowPadding...), motion in `UITheme.Motion` (OpenSparkles, BannerStarSpin, CloseHoverTurn). Cards (`Style.CardLook`) are a lighter glass with a soft gold outline; buttons have a glossy top; Inventory tabs are navy glass, the open one amethyst with a gold border; toasts are navy glass with a gold border (under the day/night pill on PC). The Luck panel and the Spire card carry the same banner ("Bind Luck" with the luck total big under it; "Dragon Spire"). The Rebirth window is a big ★ heading, a cost card (gold icon, bar toward the cost), reward chips (income, level cap, new area) and big Rebirth! / Not yet buttons (wording `Config/Text.Rebirth`). The Rune Shrine / Dragonstone Forge window has two columns: dragons (rarity icon, level, current trait/grade) and the rune/stone count, the chosen dragon, a big button and a grid of chances colored by tier (`Text.RuneShrine/DragonstoneForge` Owned/Chances). Settings uses sliding switches. The binding ceremony shows the dragon's name on a rarity-colored banner with a Rarity · Element tag and sparkles (lower middle of the screen). Phones: windows are 94% x 88% of the screen, and while one is open the menu, currencies, travel row and day/night pill hide (`HudLayout.HideWithPopups`). **World UI (checkpoint 3):** the window look made small (`Style.WorldPanel`, `UITheme.WorldPanel`: navy glass, gold border, gold diamonds on the ends, optional little star on top; `Style.Outline` = title-font text with a dark outline). Prompts (`PromptController`): a round amethyst key badge with a gold ring that fills gold while held, the action in the title font, a bounce on appear and sparkles when used. Boards (`UI/WorldBoard`: stand levels, rune/stone counts, merchant price, Spire record) have the star on top and the icon popping out; the upgrade stand's board hides while its own buy prompt shows (`UpgradeStandController`, so it never covers the E prompt), and the two stand boards sit 6 studs out from the gate's center line (`WorldUI.UpgradeStands.BoardSideOffset`). Owner banners (`RoostFXController`), portal names (above the arch art) and the portal lock use the same panel; "+gold" pops, dragon nameplates and the ★ rebirth badge use the title font with an outline (`RoostService`, `RebirthService`). Themed UI kit. Look (Kyle's jewel-tone restyle, 2026-09-27): jade/rose/stargold/dusk-blue buttons with an antique-gold outline that lights up on hover, menu tiles on one twilight surface with a thin colored stripe, warm-white text; toasts draw above windows. World text: `UITheme.WorldLabels` (every BillboardGui: 40-stud MaxDistance, 80 for the ★ rebirth badge, not AlwaysOnTop, sizes); empty roost signs are hidden. Designer-editable wording in `Config/Text` (station words, results, tips; `Text.Format` fills `{placeholders}`). `Config/UITheme` holds every color (incl. per rarity/element), font (Luckiest Guy titles, Builder Sans body), size, motion timing, sound ID, icon ID and art slot; empty icon = styled fallback tile, empty sound = silent, empty art slot = procedural look. Kit in `Controllers/UI` (Style, Icon, Button, IconButton, Window, ProgressBar, Toast, Tooltip, CurrencyPill, RarityTag, RewardRow); every panel uses it. `HudLayout`: menu tiles, currency pills, popups (Windows register themselves), `OnLayoutChanged`; one window at a time (`ClaimFocus`/`ReleaseFocus`: every Window, and station panels via `TrackPanel`, close whatever else is open; clicking a menu tile again closes its window). Phones show at most `UITheme.PhoneMaxTimers` boost timers, then a "+N" chip that opens Boosts. The Dragons panel keeps its cards and only writes changed values. PC = icon grid left-middle + currency bottom-left; phone (short side ≤ 500 px) = same grid smaller in 3 columns (`PhoneMenuColumns`, clear of the thumbstick), currency top-left, luck pill + boost timers top-right, Spire card top-center; thumbstick/jump corners stay clear. Landscape only. ScreenGuis use Sibling ZIndex. Studio test: LocalPlayer attribute `ForceLayout` = "Phone"/"PC"; `ReplicatedStorage.DevTools.PhoneMock` (Studio only, not in Git) renders the UI in a phone frame. Shop cards use the pass icons (`UITheme.ShopIcons`). Waiting on art: panel frame (dragon scales), title ornament, panel texture |
| Ranked PvP | Post-launch |

**Next up: approved build order** (full numbers in `docs/Economy_Rebalance_Proposal_v5.md`,
plus the changes approved after it, listed under Decisions made). Work phase by phase: after each phase, playtest in
Studio, fix, commit, and send the user a short summary before starting the next.
1. Economy core rebalance (configs, DragonStats, weekly rebirth cap, idle rule, starter dragon, dusk warning).
2. Boosts and potions (`Config/Boosts`, `BoostService`, `BoostController`, UseBoost remote; luck potions are
   charges the player arms for the next bind).
3. Dragon Index + mutations (`Config/Index`, `Config/Mutations`, `IndexService`, `IndexController`, direct pair roll in `BindingService`).
4. Quests + login streak (`Config/Quests`, `QuestService`, `QuestController`).
5. Dragon Spire (`Config/Spire`, `SpireService`, `SpireController`).
6. Monetization (Tower Elevator Pass, Single Elevator Skip, 2x AFK Income, Auto-bind; `ProcessReceipt` with receipt IDs).
Later weekly updates: Spire leaderboard, event constellations, then Ascension (design only).
UI polish after the core loop is playable. **UI polish list (in order):**
1. ~~Phone layout of the left button column~~ Done: `HudLayout` (phone grid, popups above the HUD, luck pill, Spire
   card, scaled Rebirth confirm, scrolling station odds). Menu buttons still use text labels until the artist's icons.
2. ~~Full UI styling pass~~ Done: `Config/UITheme` + the `Controllers/UI` kit (all panels migrated). Remaining: the artist's panel frame / title ornament / texture art (`UITheme.Art`). Shop pass icons done.
3. Spire battle visuals (see Open questions): the HUD now shows portraits + health bars; a 3D dragon-vs-dragon fight is still open.

**Luck scaling (decided):** luck boosts rarer tiers harder via `Config/Luck.TierScaling` (0.3):
Mythic 0.5% at x1 → 4.2% at the x10 cap → 7.1% at the x20 hard cap with a potion.

**World (built in Studio, lives in the place file, not Git):** `Workspace.StarterMeadow` is being rebuilt as **"the
Valley"** (remaster master prompt, reference image `assets/concepts/valley_day.webp`, plan
`docs/Valley_Layout_Proposal.md`). Checkpoints A-E are done (terrain, hub layout, nature/ruins/
dressing/landmarks/lighting, perches); a painted skybox for weak phones is proposed (plan file, section 9). North = -Z, the altar at the origin. Built by the Studio
modules in `ServerStorage.RemasterTools` (reference copies in `tools/valley_terrain/` and `tools/valley_build/`):
`ValleyTerrain` (terrain), `ValleyBuild` (hub), `ValleyDetail` (nature, ruins, dressing; deterministic seeds) and
`ValleyLandmarks` (horizon models); each `Build*` function rebuilds only its own folder. Stand-ins for future custom art
are named `Placeholder_<Name>`. **Ideas for the builder's replacements** (from Kyle's reference remodel, Hakai branch;
build them as models, not part-by-part, within the part budget): a lodge-style `Placeholder_Shelter` in each sanctuary
(timber posts, slate roof, a crest in the owner's element color); a royal-blue canopy with gold seams and stars over
the Star Merchant; a stone chimney with glowing embers and a little smoke on the Dragonstone Forge. Grouped as:
- `Plaza`: the Star Altar model `StarAltar` (tag `StarAltar`, `AreaId = "StarterMeadow"`; art = the builder's `Mesh`
  (2026-09-30: round stepped platform, two gold horn arcs, a floating crystal; imported at 80 studs wide, scaled x0.58 to
  the old footprint, PreciseConvexDecomposition), `Glow` anchors (Rank 1 = the floating crystal, 2-5 = rim crystals),
  PrimaryPart `Core` = invisible part on the platform top, 12 studs south of the center so the Bind prompt (range 20)
  reaches the front steps; every area altar is the same setup with its element's mesh) on its round stepped stone `Floor` (radius 42), the
  `AltarShimmer` and the `CrystalRing` (8 star-blue crystal clusters on gold sockets on the lower floor step, between
  the roads, `NightGlow`; `ValleyBuild.BuildCrystalRing`). `Dressing`: an outer step (radius 48), 4 lanterns (flanking the north and south approaches), 4 `Placeholder_StarBanner` poles; flagstone base
  (terrain, radius 57). Any new altar just needs the tag + `AreaId` attribute; the Bind prompt is added by code.
- `Pens`: **6 plots** = the Dragon Sanctuaries (Valley rework 2026-10-01, plan `docs/Valley_Rework_Proposal.md`, checkpoint 1
  done: terrain, positions, dragon sizes; the kit system and the three looks follow). 150 studs across (rim r 75, terrace
  r 77, flat to r 80). **Layout A-N (2026-10-02, replaces the 10-01 positions):** one even horseshoe, centers 256 from the
  altar at bearings 50 / 90 / 130: W1 (-196, -165) T 12, W2 (-256, 0) T 8, W3 (-196, 165) T 8, E1-E3 mirrored (T = terrace
  height, multiples of 4 because terrain voxels are 4 studs); every gate faces the altar at the same distance (181), 25 studs
  between neighbours, flat usable area 18,676 studs^2 for all six (measured with a top-down raycast). Each is a Model
  tagged `RoostPlot` (PrimaryPart `Base`, Atomic) with attributes `RoamCenter` (terrace floor center), `RoamRadius` 64
  and `CenterHeight` 48. The layout every look shares lives in `ValleyTerrain` `V.Slots` (local coordinates: x = right
  for a player entering, y = toward the gate; `V.ToWorld(s, x, y)`): gate at y 75 (pillars +-13, lintel top 28), forecourt
  to y 97, upgrade stands at (+-14, 88), NestZone (-36, 30) r 19, MeadowZone (14, 16) r 28, CenterZone (0, -34) r 24
  (the hero piece, max 48 tall; fliers steer around it below `CenterHeight`), WaterZone (-34, -22) r 17, five Elder perch
  pads (19 across, tops 26/32/38/32/26), three Dragon perch pads (14 across, tops 12/16/20), two basking rocks. The
  terrain is a neutral terrace (no pillars, no back cliff: `ValleyTerrain.Height`; the valley edge bulges out behind each
  terrace, `edgeAt`); `ValleyBuild.BuildSanctuary` builds the invisible slots (Zones, Perches with attribute `Size`
  2 = Elder pads / 1 = Dragon pads, stand anchors, Sign); the art is a **look kit** (see the status row "Sanctuary looks"),
  and `ValleyBuild.PlainArt = true` brings back the plain `Placeholder_*` stand-ins. Perches get their positions from `V.Slots`; tiers
  (`BuildSanctuaryTiers`) use the same slots. The four rock pillars, back cliffs and old stand positions are gone.
  Roads: W1/E1 bend around the portal terrace corner, W2/E2 run straight from the plaza ring, W3/E3 go plaza ->
  side bridge -> forecourt; the market ponds moved in to (+-50, 84) (A 25) and the river's decorative bows near
  x = +-140..190 were straightened (z 58) so W2/E2 clear it. **Keep server max players <= 6**, or add plots (code finds
  plots by tag). Dragons roam client-side (`RoostAnimationController`): Hatchlings hop, Drakes walk, Dragons/Elders
  fly; sizes (`Config/Evolution.Length`, nose to tail tip, RoostService scales any model to it): 10 / 15 / 21 / 28
  studs, MoveSpeed 6 / 8 / 12 / 15, Dragon FlyHeightRange 20-32, Elder 44-68. Nothing grows inside a sanctuary
  (`ValleyDetail.D.ClearZones.Sanctuaries` r 108); the trees, flowers and ruins that stood there (51 trees, 76 flowers...)
  were removed surgically. **Don't re-run `ValleyDetail.BuildNature`**: its random stream depends on the terrain, which
  changed. Backup: `ServerStorage.Backups.StarterMeadow_2026-10-01_BeforeSanctuaryRework`.
- `Spire`: the builder's `DragonSpire` (tag `DragonSpire`, PrimaryPart `Entrance` = invisible part in front of the
  door, facing the altar; `EntranceRange` is measured from it) on its hill at (0, -252) (flat top y 28, radius 42,
  steeper slope since layout A-N: foot r ~70), the portal terrace wraps its south foot; entrance at (0, 32, -220), a paved
  court in front, `SpireStairs` (z -176 .. -213) up from the terrace's front bay.
- `Buildings` (market square at (0, 112), south of the river, all facing the square's center): the `StarMerchant` tent
  (-56, 116) (tag `StarMerchant`, PrimaryPart `Counter`), `DragonstoneForge` (58, 114) and `RuneShrine` (-50, 144) (tags
  `DragonstoneForge` / `RuneShrine`, PrimaryPart `PromptPoint` = invisible part at the front at standing height;
  station prompts have a 12-stud range), each on a stone platform (top y 2.4) in `Market`, with the
  `Placeholder_StarObelisk` (star-blue crystal on a stepped base, signpost arms) in the center.
- `Entrance`: `Placeholder_EntranceGate` (two stone towers with navy star banners, lanterns) at the valley mouth (z 150).
- `Bridges`: `Placeholder_GrandBridge` on the main road over the river (z 48-80, lands on the plaza step), and
  `Placeholder_SideBridge_W` / `_E` at (-100 / 100, 60) on the W3/E3 roads, square to the river; gold stars, lanterns.
- `Portals`: **layout A-N:** on the portal terrace behind the sanctuaries, wrapping the Spire's south foot (`V.Terrace.Poly` in
  `ValleyTerrain`: a flat polygon, top y 12, front bay at (0, -176), back edge z -300; `PortalTerrace`: retaining wall along its
  front/sides, `GrandStairs` at the end of the north road (z -155 .. -176), `SpireStairs`, a themed ground disc under each gate;
  paved promenade `V.Walkway`), in unlock order west to east, each facing the altar: `Portal_VolcanoPeak` (-145, -280),
  `Portal_FrozenCliffs` (-90, -256), `Portal_StormCanyon` (90, -256), `Portal_EclipseIsles` (145, -280) (Surface positions; every
  sanctuary's back edge, z -245 for W1/E1, is south of the row). AreaSpawn (-22, 13.5, -193), TravelPoint `Portals` (22, -193).
  The horizon landmarks stand behind the gates at bearings -35 / -18 / 18 / 35 (`Config/Horizon`, ridge dips `SADDLES`). Each is the builder's arch `Art` (2026-09-30: one
  themed mesh per destination (Volcano / Ice / Storm / Eclipse), anchored, collidable, PreciseConvexDecomposition) plus a
  `Surface` part filling the opening (16.5 x 28, 20.5 studs above the arch's base) (PrimaryPart, tag `AreaPortal`, `AreaId` = destination,
  CanCollide off): touching it teleports (`AreaService`, server-checked). The return portals (`Portal_StarterMeadow` in
  each area) use that area's own arch (the same themed mesh). The previous altars/arches and the builder's imports are in
  `ServerStorage.Backups.AltarsPortals_2026-09-30_BeforeSwap` (tags stripped). `PortalController` draws the Surface per client: destination color, light,
  swirl and particles when unlocked; dim gray with a lock + "Rebirth X" (close up) when locked (`Config/Portals`).
- `Water`: the `Waterfall` on the western cliff (layout A-N: lip about (-344, 61, 124), pool (-322, 118); the ancient tree moved with it): streak Beams facing the camera on `BeamAnchor`
  (tagged `DistanceFade`: they fade out 380-500 studs from the camera, `Config/Atmosphere` BeamFade*, AmbientFXController; the east cascade too),
  foam/spray emitters tagged `AmbientFX`, a `SoundSource` tagged `Waterfall` for `Config/Audio`. The river (terrain
  water, level -1) runs from its pool east through the gap between W2 and W3 (a stone-walled stream ~9 wide, z 82 at
  x -226), past the plaza's south side (z ≈ 63) under the side bridges (x +-100) and the grand bridge, with two ponds
  flanking the market, and leaves through the E2/E3 gap into a lower pool (332, 121) (the east cascade). Edit terrain near
  water with `ReadVoxelChannels`/`WriteVoxelChannels` (plain `ReadVoxels`/`WriteVoxels` drops water in shoreline
  cells), and keep water voxels free of ground (beds below the water's voxel layer), or the water doesn't render.
- Terrain: written by `ServerStorage.RemasterTools.ValleyTerrain` (reference copy `tools/valley_terrain/`): valley
  floor, sanctuary terraces (rock pillars, back cliffs), the portal terrace + Spire hill, jagged mountains all around
  (green foothills, rocky peaks, saddles behind the gates so the landmarks show), the winding river, the south gorge.
  Mountains: grass up to the tree line, rock higher up, snowcaps above `SnowLine` (terrain `Sand` colored white:
  `Snow` carries the Frozen area's stylized override). Flagstone roads and squares = terrain `Brick` with the painterly cream `Valley_RoadA` MaterialVariant override (`ValleyTerrain.V.RoadMaterial`; not Cobblestone, because overrides restyle parts too and ~360 Valley parts use Cobblestone, while no part uses Brick) (roads from the plaza to each sanctuary, the main road, the
  terrace walkway, the spawn plaza, the Spire court). Solid terrain surfaces end up ~2 studs above the voxel fill
  height, so the script writes solids 2 lower (`SurfaceLift`); keep that in mind for any other terrain script.
- `SpawnLocation` at the valley mouth (0, 1.3, 160) facing north (new players); `AreaSpawn` (arrivals from other
  areas) on the portal terrace (0, 13.5, -150) facing the altar.
- `Tiles`: real Granite stone tiles in warm cream shades (to match the cream roads) flush on the flagstone (`ValleyBuild.BuildTiles`, 132 parts): a two-row ring around
  the plaza's outer step (gap at the grand bridge, none over the river bank) and a two-row ring around the market
  obelisk, with gold inlays (`NightGlow`) at the compass points.
- `TravelPoints`: invisible markers the Travel menu lands on (`ValleyBuild.BuildTravelPoints`): `Altar` (plaza, facing
  the altar), `Market` (south of the obelisk, facing north), `Spire` (court, facing the door) and one per sanctuary
  named after its plot (forecourt, facing the gate). If a pen moves, rebuild them.
- `Bounds`: 60 invisible walls 30 studs up the foothills all around the valley (from the terrain's edge table).
- `Nature`: magical, painterly fantasy trees (kit `ServerStorage.PropKits.Fantasy`, approved 2026-09-28; placed by
  `ValleyDetail.BuildNature`): 217 forest trees (`Trees`) = teal firs `Fantasy_TealFir` / `_TealFir_B` on the ridges and
  high slopes, emerald broadleaves `Fantasy_EmeraldTree_A` / `_B` on the valley floor, both mixed on the foothills
  (canopies tinted via SurfaceAppearance.Color, `ValleyDetail.FantasyTint`); 9 magical trees (`MagicTrees`)
  where they matter: lantern willows (glowing orbs) by the low pool, a star-blossom and/or crystal tree (aqua crystals)
  at the kept ruin sites, crystal trees framing the altar approaches; 3 big broadleaf `Specimens` at the valley edges;
  the giant `Fantasy_AncientTree` (`Landmark`, ~115 studs, faint glow + fireflies) on the cliff top beside the
  waterfall. Magical trees glow at night (`NightGlow`; canopies with a SurfaceAppearance glow through its emissive,
  `GlowStrength`). Never on roads or play spaces, thinner in the saddles behind the gates; trees inside the bounds have
  an invisible `TrunkCollider`, foliage doesn't collide. Kit sources: emerald/teal/star-blossom/ancient = Creator
  Store "Yasu's Stylized Tree Pack" (92016775395411; a hidden script was removed; the rest of the pack is kept in
  `Fantasy.Store_YasuStylizedTreePack`), crystal tree + lantern willow = AI-generated (owned by the game's creator).
  The realistic Store firs/pines/oak were deleted from PropKits and ValleyHold (2026-09-28). Also ferns, 14 big
  wildflower patches toward the valley edges (lupines, buttercups, daisies, white wildflowers; `D.FlowerPatches`), night
  flora (moonflowers and glow mushrooms tagged `NightGlow`) by the river and forest edge, 18 boulders on the lower
  slopes only (`D.MaxBoulders`). **Tidy-up (2026-09-28):** `D.ClearZones` keep a ring of open grass around the plaza
  (radius 82) and the field in front of the portal terrace free of nature (magical trees excepted); trees the user
  removed by hand are in `D.RemovedByHand` (BuildNature still generates them so every other tree keeps its spot, since
  all trees share one random stream, then removes them; add to that list when removing trees by hand). Backup of the
  folders before the tidy-up: `ServerStorage.Backups.StarterMeadow_2026-09-28_BeforeTidy`.
- `Ruins`: binder ruins (columns with gold bands, broken arches, fallen columns, rune stones, star-inlaid steps; gold
  parts tagged `NightGlow`) at 5 sites (waterfall, low pool, west meadow, Spire hill west/east; `D.RuinSites`, the
  removed terrace/east meadow/market sites stay listed with keep = false) and a rune stone in each sanctuary's flight
  zone (the broken arches there were removed: they read as extra gates).
- `Dressing`: crystals at each portal gate in its area's color (glass by day, `NightGlow` at night), the obelisk's
  signpost words (SurfaceGuis), market crates and barrels (the only crates/barrels in the Valley), lily pads, one pair of road lanterns where the
  north road leaves the plaza (other lanterns stand only at junctions: plaza, bridge ends, entrance, grand stairs,
  sanctuary gates; 26 in all), the east cascade (beam + foam
  tagged `AmbientFX`).
- `ServerStorage.ValleyHold`: what's left of the old layout: realistic Creator Store trees/rocks/ferns/flowers,
  Enchanted AI props and old part-built pieces (curbs, plaza ring, platforms, stairs). The 509 cartoon AI props were
  deleted on 2026-09-27 (copies remain in the backup below). Backup of the meadow before the Valley:
  `ServerStorage.Backups.StarterMeadow_2026-09-27_BeforeValley` (tags stripped; terrain, lighting, materials, horizon
  models).
- Dev: `DevService` (Studio only) creates `ServerStorage.DevTools.GiveDragons` (BindableFunction, server-only):
  `GiveDragons:Invoke(player, { "Solflare", ... }, level, placeInRoost)` adds test dragons to a player's data;
  `SetRoostSlots:Invoke(player, n)` sets their roost to n slots.
- Dev (Studio only): the MCP's `execute_luau` threads can no longer invoke our BindableFunctions, fire our remotes or `require` our modules
  (Capabilities restriction), so `DevService` also listens to the Workspace string attribute `DevCommand` (JSON, answers in `DevResult`): ops
  `Items`, `Dragons`, `Slots`, `UseBoost`, `Level`, `Hotbar`, `Carry`, `SellDragons`, `SellItems`, `Lock`, `SimStart`/`SimResult` (cohort sim on the server, `tools/sim/README.md`), `SpireAction`, `FireClient` (e.g. a fake `BindResult`), `Config` (change a Config value in the
  running server, e.g. Spire `FightSeconds` to speed a loop test), `Get`, `Teleport`, `Set` (header of `DevService.luau`). Real input:
  `user_keyboard_input` (hold E at the altar), `user_mouse_input` (use `instance_path` for GUI buttons; `UI/Button` strips spaces from its instance name, e.g. `...Menu.Frame.SellDragons`; coordinate clicks are unreliable).
- Hakai handoff notes from Kyle: `docs/Hakai_Handoff.md` (ignore its branch/merge rules; use the open place and the isolated test profile).
- Dev: `Controllers/Dev/DragonRigDemo.client.luau` animates any Model tagged `DragonRigDemo` (walk -> take off -> fly
  -> land by moving bones). No such model is in the place now (all dragon art was cleared on 2026-09-26).
The building meshes use the default CollisionFidelity (a script can't change it; set `PreciseConvexDecomposition`
by hand in Properties if a building blocks players). Real Elder art (2026-09-28, Meshy + `tools/glb_to_fbx.py`): `Assets.Dragons.<Id>.Elder` for Solflare, Aurorynth,
Borealis, Duskling and Infernus: one skinned MeshPart `Body` (PrimaryPart; bones animated when the species has a bone
map in `Config/DragonRigs`), pivot
at the bottom center facing the head, each scaled evenly (in the place) to fit 12 studs tall x 17 long. Every other species/stage
still uses `ReplicatedStorage.Assets.Dragons.Placeholder` (keep it). Note: Studio's importer puts a rotated
`PivotOffset` on the imported MeshPart; reset it (upright part, bottom-center offset) before moving the model.
**Other areas (remaster blockout 2026-09-27; areas are ≥ 1,200 studs apart so they never stream/see each other):**
`Workspace.VolcanoPeak` (center (0, 0, -1600)), `Workspace.FrozenCliffs` (1600, 0, 0), `Workspace.StormCanyon`
(-1600, 0, 0) and `Workspace.EclipseIsles` (-1150, 140, -1150, floating islands, north-west behind its portal). Each
folder holds the Star Altar (`AreaId`), `AreaSpawn`, `Portal_StarterMeadow` and a `Blockout` folder; terrain shapes the
area (Frozen: snow bowl, frozen lake, north cliff; Storm: canyon + north mesa + floating rocks; Eclipse: main island,
bridge to the temple island). Their Meadow portals are in `StarterMeadow.Portals`. `AreaService` streams the
destination in (`RequestStreamAroundAsync`) before teleporting. Terrain materials are split per area (Meadow: Grass,
Rock, Ground, Mud, Sand, Water; Volcano: Basalt, CrackedLava, Asphalt; Frozen: Snow, Glacier, Ice, Limestone; Storm:
Salt, Sandstone; Eclipse: LeafyGrass, Concrete, Pavement) so each area can have its own terrain look.
**Stylized terrain:** `MaterialService` holds 19 `BAD_*` MaterialVariants; these are set as base-material overrides
(other areas, until they are remastered): Basalt, Asphalt, CrackedLava = lava, Snow, Glacier, Limestone, Ice, Salt =
storm floor, Sandstone = canyon walls, LeafyGrass = violet moss, Concrete = void stone, Pavement = temple stone. The
Meadow (painterly ground restyle 2026-09-28, option A, matching the concept art): Grass = `Valley_GrassA` (soft,
low-noise near-white wash with warm light patches, 48 studs/tile; its green comes from the terrain color (88, 112, 60),
which the grass blades also use, so they match; the lighting boosts saturation, so keep it soft); Mud = the deeper
teal-green forest/slope grass `Valley_ForestA` (same texture, color (46, 92, 72), no blades), painted on steep ground,
high ground and around forest trees by `ValleyTerrain.PaintForest()`; Brick = the roads, `Valley_RoadA` (warm cream
flagstone, big rounded painted slabs + normal map, 20 studs/tile, color (226, 214, 196)); Roblox's own Ground, Rock and
Water; Ground (128, 106, 78), Rock (112, 110, 112), Cobblestone (168, 160, 146), Sand (236, 241, 248) = the snowcaps.
Parts using Grass (nests, hay, lily pads, plot base discs) take the painted texture in their own color. Sources:
`tools/terrain_textures/gen.py` (`valley_*`; the A PNGs are kept next to it). `MaterialService.Use2022Materials` is on (set by hand 2026-09-27; scripts can't read or
change it). Textures are hand-made
tileable PNGs (`tools/terrain_textures/gen.py`, uploaded as images); faceted materials have per-facet normal maps.
Overrides also restyle **parts** with those materials, so part-built art should avoid them (Slate is deliberately not
overridden: 126 part-built stands use it). Terrain material color multiplies the variant: Grass's texture is near white
and its green comes from `Terrain:SetMaterialColor(Grass)` so the ground matches the grass blades; the others are white.
**Landmarks:** `HorizonController` + `Config/Horizon` clone models from `ReplicatedStorage.Assets.Horizon` on the
client (no collision, never streamed): in the Meadow, each area's landmark 650-720 studs out behind its gate, seen
through the dips in the ridge (`ValleyVolcano`: AI-generated cone, rock + glowing lava, smoke plume; `IceSpire`;
`StormTower` with lightning and a storm cloud; `ValleyIsland`: realistic boulders, fantasy firs, silver ruins and the eclipse
sun spinning above), plus `MeadowRanges` (distant mountain ranges ~830 out, all around); in each area, its own sky
landmark (Eclipse sun, ice crystals, storm tower with lightning, volcano plume). Far objects vanish when Studio's
graphics quality is low (the render distance shrinks); set a high quality level for overview screenshots.
The builder replaces each with the real area (keep the altar tag + `AreaId`, the `AreaSpawn`, and the portals).
Eclipse Isles should be themed to match the Shadow dragons.
StreamingEnabled is on: tagged models use `ModelStreamingMode = Atomic`, and client code that sets up prompts on
streamed models must retry until the parts arrive.
`Workspace.VolcanoPeak` (at z ≈ -1600): basalt plateau, a big volcano cone (crater + lava fall), lava, red Star Altar
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
- **Art pipeline (dragon models):** Meshy GLBs go in `assets/Dragons/` (not in Git: `*.glb` / `*.fbx` are ignored),
  then `D:/jonas/Blender/blender.exe -b --python tools/glb_to_fbx.py -- <in.glb> <out.fbx> --stage Elder` makes a
  Roblox-ready FBX in `assets/Dragons/fbx/`: helper meshes removed, tiny UniRig tip bones merged into their parents,
  ~10k triangles (max 20k per mesh), max 4 bone weights per vertex, base-color texture only at 1024 px (embedded),
  head facing Roblox forward (-Z after Studio's importer; `--flip` turns 180 degrees if a source faces the other way), scaled to the stage length
  (Hatchling 6, Drake 8.5, Dragon 11, Elder 15 studs), feet at the origin; FBX mesh + armature, Apply Scalings = FBX
  All, no leaf bones. It prints a report (bones per chain, weights, triangles, texture). Import the FBX with Studio's
  3D Importer, then the model goes to `ReplicatedStorage/Assets/Dragons/<SpeciesId>/<StageId>` with a PrimaryPart and
  a bottom-center pivot facing -Z, no scripts.
- **Dragon rig + animation set (Blender, 2026-09-30, not in the game yet):** `tools/dragon_rig/` (README there). One
  standard skeleton (`template.py`: Root, Spine1-3, Neck1-3, Head, Jaw, Tail1-6, Wing_L/R_Upper/Fore/Hand/Tip,
  Leg_FL/FR/BL/BR_Upper/Lower/Foot; wings standardized to a spread rest pose, the tail straightened onto the center
  line) and one set of 21 generic actions (core: Idle/TakeOff/FlyLoop/Glide/Land/Roar/Reveal; roost: Sleep, HappyHop,
  Sneeze, Stretch, Preen, Shake, TailFlick, BarrelRoll; moments/battle: Evolve, LevelUp, Attack, Hit, Victory, Defeat;
  lengths + FX markers in `animations.json`) that play on every re-rigged dragon. Straight tails make models longer
  (Solflare 19 studs, Infernus 27 nose to tail tip; bodies keep their size). `rerig.py` re-rigs a Meshy GLB automatically (~2 s: UniRig skeleton as landmarks, automatic weights), then
  `apply_actions.py` copies the actions from `assets/Dragons/blend/DragonAnimations.blend`. Done: Solflare + Infernus
  Elder (`assets/Dragons/blend/`, rigged FBX in `assets/Dragons/fbx/rigged/`, per-action FBX in `assets/Dragons/fbx/anim/`,
  previews in `assets/Dragons/previews/`; blends and previews are not in Git). The game still uses the UniRig bone maps
  in `Config/DragonRigs` until this set is imported to Roblox.
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
- Mutations: direct species-pair roll; Hoardscale favors income, Warcrest power, Aetherwing balance, Primordial prestige. Mutation collection never blocks Index completion.

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
- Dragons in the roost earn gold over time. Base gold/sec and Spire power are species-specific in `Config/Dragons`.
- Multiplied by level, evolution stage, branches, trait, grade, mutation, the roost income upgrade, the rebirth bonus
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
- Auto-battle with the player's most powerful dragon, one enemy per stage, every 10th stage a boss (`Config/Spire`).
- Every run fights stages 1-100 in order, 12 s each (~20 min); no fast-forward, no elevator. The player must stay at the
  Spire; a loss, death, Stop or leaving ends the run. Auto-Repeat (off by default) restarts at stage 1 after stage 100.
- Rewards: first clears pay gold (30 s of roost income) plus guaranteed drops (potions, Wyrm Runes, Dragonstones, Stardust
  from bosses); every boss victory, repeats included, gives 1 Wyrm Rune + 1 Dragonstone; re-clears roll small potion chances.
  A first full run = 30 runes + 30 stones, a repeat full run = 10 + 10 (a 2x reward boost doubles them).
- **No cosmetic rewards.** Enemies reuse existing dragon models.

### Boosts, quests, Index
- Potions and luck charges (`Config/Boosts`), daily/weekly quests + login streak (`Config/Quests`), Dragon Index
  bonuses and milestone rewards (`Config/Index`). The status table above says how each works.

### Monetization
Game passes and developer products in `Config/Products` (IDs are 0 until created in the Creator Dashboard).

| Feature | Type | What it does |
| --- | --- | --- |
| Tower Elevator Pass | Game pass | **Retired** (Spire has no skipping; entitlements kept, never used) |
| Single Elevator Skip | Developer product | **Retired** |
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
- Spire battle visuals: the HUD shows both dragons' portraits with draining health bars (UI renewal part 2). A 3D
  dragon-vs-dragon fight in the world (reusing dragon models) is still open.
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
- **Mutation/economy rebalance approved** (`docs/Mutation_Economy_Implementation.md`). Pacing targets: Dedicated (3–4 h/day + offline)
  reaches the R30 launch cap in 9–12 days; Casual clearly slower; AFK-only and
  paying AFK (Auto-bind + 2x AFK) slower than Dedicated; the rebirth cost curve always rises; short dips from potion bursts are fine as long as the weekly-update and week-1 targets hold; a weekly
  update's +3 rebirths lasts a veteran 5–8 days. Current sensitivity targets are Dedicated 10.3 d, Casual 27.4 d,
  AFK-only 70.9 d, paying AFK 30.5 d; final cohort validation is required in Hakai test.
- Paid passes must not beat active play: idling in game counts as offline after 20 min without input
  (`IdleAfterSeconds`); Auto-bind binds every night while in game at base luck, no offerings or potions.
- Luck potions are charges the player arms for the next bind (toggle in the Boosts panel or at the altar),
  not auto-consumed.
- Event dragons use ONE model for all stages (`Assets/Dragons/<SpeciesId>`), 1 model per weekly update.

## Mutation economy, retune proposal, sim (2026-10-02)

- Kyle's branch `codex/mutation-economy` is merged: mutations (`Config/Mutations`: Normal 90 / Hoardscale 4 / Warcrest 4 /
  Aetherwing 1.5 / Primordial 0.5) replace Starborn (data v3 migrates Starborn dragons to Primordial), one roll over
  species x mutation (`Shared/BindingOdds`), species-specific gold/power/bind weight in `Config/Dragons`, Echo Sigils
  (extra binds, `Config/Binding`), server bind distance/alive check, Spire gold clamp, strongest gold potion only
  (`Config/Boosts.GoldPotionCap`), mutation Index with 1-in-N odds. Luck exponents are in `Config/Luck.RarityExponent`
  (binding) and `TierScaling` (trait/grade rolls only). `docs/Mutation_Economy_Implementation.md` is its spec.
- **Retune applied (2026-10-02, `docs/Economy_Retune_Proposal.md`, tuned with the sim):** `Rebirth` EarlyGrowth 5.0, LateGrowth
  2.55, WeeklyJump 4.8, WeeklyGrowthStep 0.72 (cap 30, +3 per weekly update); Mythic ~30x Common gold/s (Common 700-900, Rare
  1.5-2k, Epic 3.5-4.6k, Legendary 8.5-12k, Mythic 20-30k); best trait x15 / best grade x15; `Spire.EnemyGrowth` 1.15; offline
  rule unchanged (50%). Sim (calibrated real days): Dedicated 8.1 median (fastest 10% 5.9), Casual 22, AFK-only 33, paid AFK
  11, weekly +3 about 5-6 days, Spire week-1 floor ~98. Re-run `tools/sim` after any economy change.
- **Rebirth Milestone Ladder (wave 1 built):** `Config/RebirthMilestones` (Titles, Milestones with Perks, AutoUpgrade, Ascended,
  Champion, AltarTravel), wording `Text.Milestones`, helpers `Shared/RebirthMilestones`, server `MilestoneService` (celebrates
  each milestone once in `data.MilestonesSeen` with a reward pop-up, champion grant, `Ascended` player attribute, Auto-Upgrade
  toggle `SetAutoUpgrade` + a 1 s loop using `DragonService:BuyLevels`), track + Auto-Upgrade switch in the Rebirth window
  (`RebirthController`), rank title above the badge (`RebirthService`): R12 Auto-Upgrade (spends gold above 50% of the next
  rebirth cost), R18 +1 Echo Sigil cap and Altar Travel (Travel row "Altars", `TravelToAltar`), R20 Ascended altars (x1.25 bind
  luck as a normal source in `Luck.Compute`, gold altar glow for everyone in `AltarGlowController`), R30 champion dragon (Solflare
  art in gold with sparkles, x1.25 income/power, not an Index discovery) and the gold "Rebirth Champion" title. Wave 2 (weekly
  updates, not built): R15 Star Throne, R25 Astral Throne look (`docs/Rebirth_Milestones_Proposal.md`).
- **Odds display:** bind pop-up = excitement banner ("LEGENDARY LUCK!"), "Only 1 in N binds!", rarity/element/mutation chips,
  tap the card for the breakdown (`Shared/OddsText`, `Config/Odds`, `Text.Odds`); the server sends N (`BindResult` BaseOneIn,
  EffectiveOneIn, SpeciesOneIn, MutationOneIn via `BindingOdds.Breakdown`); Index/dragon tooltips say "Chance: 1 in N"
  (`BindingOdds.GetHomeOneIn`).
- Studio test profile: set the ServerStorage attribute `TestProfileKey` (Edit mode) to play on a fresh profile (`Player_<id>_<key>`).
  The "no access to asset 114302219876492" Studio warning is the test avatar's own `Animate.mood` animation, not ours.
- `tools/sim/CohortSim.luau` (+ README): cohort simulation (Dedicated / Casual / AFK-only / paid AFK, weekly
  updates, Spire floor) against the live Config; runs in Studio. Calibrated: sim-days x 0.476 = real days of the
  approved v5 sim. Re-run it after any economy Config change.
- Studio dev tools (`ServerStorage.DevTools`, DevService): `GiveDragons` (optional 5th arg = mutation id), `GiveItems`
  (sigils, gold, rebirths, potions, runes, stones, Stardust), `SimulateBinding`, `SetRoostSlots`. Note: `execute_luau`
  in Play has its own module cache, so read player data from the Client with `Remotes.GetPlayerData:InvokeServer()`.

## Valley layout A-N + grass (built 2026-10-02, `docs/Valley_Layout_And_Grass_Proposal.md`, screenshots `docs/img/an_step*`)

- Step 1: terrain + positions (see Pens/Portals/Water above). Step 2: portals, terrace, stairs, travel points, waterfall,
  landmarks. Step 3: `ValleyDetail.BuildRuins()` + `BuildLife()` (own folder `StarterMeadow.Life`: Forest 140 extra trees on the
  new valley edges, Magic star-blossom/crystal trees at the gates, ruins and avenue, Flowers, Lanterns = the avenue on the north
  road); the four kept ruins stand in the wedges beside the W1/E1 and W2/E2 roads and flanking the avenue; the old terrace
  area is the open lantern-avenue meadow (`D.ClearZones.NorthField`). `ValleyTerrain` now writes 4 height samples per voxel
  (round terrace rims) and `PaintForest` also reads `Life.Forest`. Don't re-run `BuildNature`.
- Kits and tiers are in world position: `ReplicatedStorage.Assets.SanctuaryLooks.<Look>.<PlotName>` and `SanctuaryTiers.<PlotName>`
  were moved rigidly with their plots (a plot move = `PivotTo` for the plot, its kits and tiers, then `ValleyBuild.BuildSanctuaries()`).
- Backup: `ServerStorage.Backups.StarterMeadow_2026-10-02_BeforeAN` (folders, kits, old modules; terrain can't be copied: re-run the
  old `ValleyTerrain` from `RemasterToolsCopy`).
- Grass Option 1 applied: terrain Grass color (122, 152, 58), `Valley_GrassA` override, Mud (teal slopes) unchanged,
  `Valley_GrassD` deleted; `Terrain.GrassLength` 0.4 is set by hand (not scriptable).
- Measured (Studio, tree triangles from the kit `Triangles` attributes, whole world): trees 308 / ~441k (before 172 / ~250k);
  StarterMeadow parts 2,017 (891 mesh) vs 1,651 (546 mesh). To trim: lower `D.MaxLifeTrees` (140) and rebuild `Life`.
- The east cascade's beam attachments used to be placed in world space before parenting (beam never visible); fixed.

## Pending design doc updates (apply when the user asks to revise the doc)

Doc and PDF last revised 2026-09-25. Changes since then (economy rebalance, approved):
- **Luck:** rare-tier scaling 0.4 → 0.3. Cap x10 without potions, **x20 hard cap** with one luck potion charge
  (Starlight ×1.5, Moonfire ×2), armed by the player for the next bind.
- **Offline income:** 100% → **50%** of online, still capped at 8 h/day; idling in game >20 min counts as offline.
  The 2x AFK Income pass doubles it.
- **Rebirth cost:** first 50M, ×5.0 per rebirth to R10, ×2.55 to the R30 launch cap; weekly updates add 3 rebirths (a ×4.8
  first step, then two cheaper ones). At the cap, banked gold stops at one rebirth's cost.
- **Rebirth reward:** new permanent income bonus **×1.59 per rebirth** (multiplying), plus +5 level cap per rebirth.
- **Level cap:** per-area caps (50/60/70/80/100) → **50 + 5 per rebirth**. Areas keep luck bonus + unlocks.
- **Levels:** income ×1.06 and power ×1.05 per level; each level costs 0.20–0.40% of the next rebirth cost by tier.
- **Base income/power:** species-specific values in `Config/Dragons` (Mythic ~30x Common gold/s), not broad rarity.
- **Traits and grades:** maximum x15 each (x225 combined; Config/Traits).
- **Roost upgrades:** slots unchanged; income +4% × 25 levels (2x maximum).
- **Star Merchant:** bundle price = 0.06% of the next rebirth cost, ×1.5 per buy, resets at dawn.
- **Day/night:** 8+4 min → **4 min day + 3 min night** (~8.6 binds/hour), "Night falls in 30s" warning,
  moon stays 8 phases (full moon every ~56 min). Mutation odds are in `Config/Mutations`.
- **Starter dragon:** free Common Hatchling on first join (placeholder Cinderwing).
- **New systems:** timed Spire boosts (×2 / ×5 gold potions, luck charges, Wyrmblood, Conqueror's Brew,
  Runebright; stacking extends up to 60 min; timers pause offline; Premium +10% duration) with a Boosts panel;
  Dragon Index (+0.5%/species, ×1.10 per complete element, ×1.20 all 20, milestone items); four mutation variants;
  daily/weekly quests + login streak; weekly Spire leaderboard; weekly event
  constellation; Ascension (design only).
- **Spire (superseded by Kyle's polish: 100 stages, ×1.15 per floor; see the Spire section):** enemy power 10 × 1.215^floor (bosses ×1.5), 150 floors at launch + 10 per weekly update, first-clear
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
