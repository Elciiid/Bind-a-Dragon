# Bind A Dragon: World & UI Remaster Plan (Stage 1)

Written 2026-09-27. Document only: nothing in the place or repo was changed for this plan.
Approve, change or strike any item; nothing below gets built until you say so.
Decisions I need from you are collected in section 11.

---

## 0. Where we start (measured in Studio today)

| Area | What's there | Parts / lights / particles |
|---|---|---|
| Starter Meadow (origin) | Builder altar, Spire, merchant, shrine, forge, 4 builder portal arches; part-built pens (8), trees (50), rocks, flowers, lanterns; terrain hills + painted paths | 1,358 parts (586 scenery, 672 pens) / 29 lights / 0 emitters (particles are code-made) |
| Volcano Peak (z = -900) | Terrain plateau, volcano, lava; part-built red altar; builder return arch | 24 parts / 5 / 1 |
| Frozen Cliffs (x = +900) | Placeholder shell: flat platform, cloned part altar, sign, return arch | 26 / 5 / 1 |
| Storm Canyon (x = -900) | Placeholder shell | 26 / 5 / 1 |
| Eclipse Isles (z = +900) | Placeholder shell (sits *behind* the spawn, while its portal is NW) | 26 / 5 / 1 |

Already built and worth keeping: per-area day/night looks, constellation sky, lanterns, drift particles, music +
ambience, altar glow, binding ceremony, themed prompts, portal warp, roost FX, station boards, feedback palette,
Settings (Low effects), the UITheme kit and 22 icons.

**Main gaps:** four of five areas are empty; the hub is part-built filler (trees, pens, rocks) that reads flat;
nothing guides a new player; there's no loading screen or intro; the HUD has no single "what do I do now" action.

Found during the scan: `Workspace.Realistic Tree` (-152, 28, 61) and `Workspace.Tree` (-156, 21, 6), loose at the
Workspace root, west side of the meadow. They look like a teammate testing tree models. I left them in place. At the
backup step (Stage 2) I'll move them to `ServerStorage.TeamItems_ToSort` unless you say they are meant to stay.

---

## 1. What top Roblox games do that we should copy

Concrete habits, and what each means for us.

| Game | What they do well | Takeaway for Bind A Dragon |
|---|---|---|
| Pet Simulator 99 | Zones are a clear line of numbered areas; each gate shows its price/requirement on a big sign you can read from far away; every zone has one dominant color and material; the next goal is always visible | Each portal shows the destination art, name and "Rebirth X" big enough to read from the altar. One dominant color per area, used everywhere in that area (terrain, lights, UI accents) |
| Sol's RNG | The roll is the show: short build-up, rarity-scaled cutscene, server-wide announcement for rare results; biome/weather events repaint the whole sky and HUD; one huge primary button | Our ceremony is the equivalent; keep scaling it by rarity. Make **nightfall itself an event** (sky, music, HUD color change, "Night has fallen: bind now" banner). One primary action button on the HUD |
| Grow a Garden | Tiny map: plots, shops and the sell spot all visible from spawn; shops lined up in a row with big roof signs; almost no walking. New players understand the loop in under a minute | The meadow must fit in one camera view from spawn: altar, pens, stations, Spire, portals. Short walks (< 10 s spawn to altar). Big roof signs on stations |
| Adopt Me | A hub of landmark buildings with distinct silhouettes; a task list teaches the game step by step with arrows; soft, saturated, friendly palette; good at night too | Every station gets a unique silhouette + roof sign; an onboarding task tracker with a beam/arrow to the next target |
| Anime Defenders (and similar lobby games) | A lobby where each activity has a big themed gate/booth; flashy summon banners; strong rarity colors in all UI | Portals and the Spire door are "gates" with their own framing and lights. Rarity colors stay consistent from the ceremony to the Dragons panel |

Patterns shared by all of them:
- **Readability over detail.** Big simple shapes, strong silhouettes, 3–4 colors per zone, clean paths. Small
  props are clustered, not sprinkled everywhere.
- **Landmarks.** Every zone has one thing you can see from anywhere in it (and ideally from the hub).
- **Lighting sells mood more than parts.** Color correction, fog color and sky change per zone; everything else can
  be simple.
- **VFX on anything that matters.** Rewards, rare results and "you can act here" spots glow, pulse or sparkle;
  scenery doesn't.
- **UI hierarchy.** One primary action (big, bottom center or bottom right), currencies top/left, menus as a
  compact icon grid, notifications stacked in one place. Windows are big, with large text and few buttons.
- **Phones first.** Most players are on phones: thumb-sized buttons, nothing important in the corners the joystick
  and jump button use, low part counts, few moving lights.
- **Onboarding in under a minute.** An arrow or beam to the first target, a task list, instant first reward.

---

## 2. World structure: separate areas or one connected world?

| | A. Separate areas + portals (today) | B. One connected world (regions joined by paths/bridges, rebirth gates) |
|---|---|---|
| Feel | Fast travel, no dead walking; each area can be a complete "set". The world can feel disconnected | Great sense of place; you *see* where you're going. But 700–900 studs of path is boring after the first walk, so it needs portals/fast travel anyway |
| Streaming / performance | Excellent: only one area is near you; each area can spend the full budget | Harder: neighbours stream in at the edges; views across regions show more at once; long sight lines cost on phones |
| Code changes | None (portals, AreaService, nearest-AreaSpawn area detection all work) | Area detection needs region volumes; rebirth gates need a new server-checked barrier; Auto-bind/area lookups change; spawn points per region |
| Work | Each area built independently; the builder can replace one without touching others | Areas must be designed together (joins, transitions, sight lines); much more terrain |
| Risk | Low | Medium–high (a lot of rework, streaming bugs, performance) |

**Recommendation: A, with two changes that give most of B's feel:**
1. **Horizon landmarks.** From the meadow you see each area's landmark (volcano plume, ice spire, storm tower with
   lightning, eclipse ring) on the horizon *behind its portal*. They are cheap client-side stand-ins (a few
   low-poly meshes, no collision, not streamed), hidden with Low effects.
2. **Put each area behind its own portal.** Move the placeholder areas so each lies in its portal's direction:
   Volcano stays north (portal NE), Frozen east, Storm west, and **Eclipse Isles moves from south to north-west**
   (about (-650, 0, -650)). Code doesn't care where areas are (portals and spawns are tagged), so this is only a
   Studio move of placeholder shells.

---

## 2b. Art direction: "The Starlit Highlands" (approved 2026-09-27, updated with the Valley master prompt)

**Reference image:** `assets/concepts/valley_day.webp` in the repo (the Starter Meadow as "the Valley", seen from above
the entrance). Match it as closely as Roblox allows.

**Core idea:** the game's magic comes from the stars. By day every area is a bright, lush, vivid fantasy place; at
night the star magic comes alive: tonight's constellation, the altar beam, glowing runes, glowing flora. The
day-to-night change is the signature of the game and every area has its own night spectacle.

**Story in the world:** an ancient order of dragon-binders left ruins everywhere: old stone with **gold star inlays**
and **glowing runes**, overgrown with moss and flowers. The altar, the Spire and the portals are their relics. Every
area has a few of these ruins (a broken arch, a rune stone, a fallen column, a star-inlaid step) so the world feels
connected.

**Style rules**
1. **Vibrant magical fantasy: natural shapes, vivid colors.** Bright, colorful and fun for kids, with natural,
   realistic shapes and materials like the reference image: realistic trees, rocks, stone and wood (Roblox's realistic
   materials, PBR Creator Store nature, part-built stone and timber), saturated and bright. Never pastel or toy-like,
   never dull or gloomy. Colors: emerald grass, sky blue, warm weathered stone; magic in gold and star-blue.
2. **Magic is an accent.** Glow and sparkle belong to the altar, portals, runes, crystals and rewards; calm nature
   everywhere else. By day the star inlays read as gold and the runes are carved; at night they glow.
3. **One landmark per area**, visible from anywhere in it.
4. **Clean and readable.** Dense nature only at the edges and on slopes and cliffs; open, readable paths in the
   middle. Nature frames the play spaces and never covers them.
5. **Night is the show.** Each area has its own night spectacle, bright and magical, never murky.

**Magic palette (all areas):** gold and star-blue, matching the navy/gold UI. Area accents add to it (lava orange,
aurora green/violet, electric blue, eclipse violet).

**Lighting:** by day sunny, crisp and saturated (little fog, soft shadows, gentle bloom and sun rays, blue sky with
3D Clouds); at night the show: tonight's constellation, the altar beam, gold runes, glowing blue/violet flowers and
mushrooms, fireflies; bright and magical, never murky.

**Asset rules:** no cartoon AI props (puffball trees, pink blossom trees, round bushes, cartoon flowers, mushrooms,
fences, cartoon shelters). They are removed as each area is rolled out. Free Creator Store models are allowed if they
contain no scripts (any script found is deleted and reported). Anything built as a stand-in for a future custom
model is named `Placeholder_<Name>`. Use: realistic Creator Store nature (script-free, checked:
Letaij's PBR firs/pines, the old oak, m00nyx26's mossy rocks, ferns, white wildflowers), AI props only where they
pass as realistic (iron lanterns, rune stones, crystals, glow mushrooms, moonflowers, wildflower patches), and
part-built stone/timber with realistic materials (Cobblestone, Slate, Wood, WoodPlanks, RoofShingles).

**Per area**

| Area | By day | Night spectacle | Colors |
|---|---|---|---|
| Starter Meadow | Sunny highland valley ringed by mountains: emerald grass, wildflowers (purple, yellow, white, a little pink), clear streams, the waterfall, tall firs and big old oaks | Tonight's constellation, the altar beam, gold runes, softly glowing blue/violet flowers and mushrooms, fireflies | Emerald, sky blue, warm stone; magic gold + star-blue |
| Volcano Peak | Obsidian and red rock, glowing orange lava rivers, heat shimmer; dramatic, not grim | Lava glow and rising embers | Obsidian, red rock, lava orange; gold runes |
| Frozen Cliffs | Sparkling white snow, turquoise ice, a frozen waterfall, crisp sky | A big green/violet aurora over glowing ice crystals | White, turquoise, crisp blue; aurora green/violet |
| Storm Canyon | Towering red-and-purple canyon, floating rocks, electric-blue crystals | Purple storm sky with lightning lighting the canyon | Red rock, purple, electric blue |
| Eclipse Isles | Floating islands in a violet sky, silver ruins, a golden eclipse ring | Near-black starry sky, silver moonlight, glowing violet ruins | Violet, silver, eclipse gold |

---

## 3. Area identity

Common rules for every area:
- Arrival point (`AreaSpawn`) faces the altar; the altar is visible from the spawn.
- Altar → return portal → landmark read in one view.
- One landmark visible from everywhere in the area. One dominant color + one accent color.
- Area size about 350 × 350 studs of playable ground (the meadow about 400 × 400), with a painted backdrop beyond
  (terrain ridges, sky) so there is no visible edge.
- Day and night preset per area (already in `Config/Atmosphere`; values tuned per area in Stage 3).
- Only the Meadow has pens and stations. Other areas: altar, arrival, return portal, landmark, a small "camp"
  (lanterns, a sign, benches) and decoration. Later: an area quest board or area-specific event spot.

### 3.1 Starter Meadow (hub)

- **Theme:** a sunny highland valley ringed by mountains around the dragon-binders' star altar: emerald grass,
  wildflowers, clear streams, the waterfall, tall firs and big old oaks; stone-walled pens, flagstone roads.
- **Palette:** emerald, sky blue, warm stone; magic gold + star-blue.
- **Landmark:** the Dragon Spire on its hill (north) with a light at its top that pulses at night. Secondary: the
  altar beam at night.
- **Lighting:** day = sunny late morning, crisp and bright; night = bright starry sky, the constellation, the altar
  beam, gold runes, softly glowing blue/violet flowers and mushrooms, fireflies.
- **Ambient VFX / sound:** a few golden light motes (day), fireflies (night), a shimmer around the altar; birds
  (day), crickets and wind chimes (night). Meadow music.

Layout: **"the Valley"** (master prompt, 2026-09-27), following the reference image. Sketch, positions, sanctuary
design and code changes: `E:\Roblox\Bind A Dragon - Valley Layout Proposal.md`. In short, from south to north: the
entrance gate at the valley mouth (spawn), the market square (merchant tent, star obelisk, forge, shrine) between
two ponds, the river from the western waterfall with two stone arch bridges, the Star Altar on its stepped plaza in
the center, six big Dragon Sanctuaries on terraces (3 west, 3 east), the portal terrace with the four gates in unlock
order and grand stairs up to the Dragon Spire on its hill; mountains, 3D clouds and the four area landmarks in the sky
behind their gates.

**Reads at a glance from spawn:** through the entrance gate you see the market and obelisk, the bridges, the altar
dead ahead, the sanctuaries left and right, the four glowing gates on the terrace, the Spire at the top, and each
area's landmark in the sky behind its gate. A new player's route is spawn → market → altar → own sanctuary → Spire →
portal.

### 3.2 Volcano Peak (Rebirth 1, Fire)

- **Theme:** obsidian and red rock on the flank of an active volcano; glowing orange lava rivers, heat shimmer;
  dramatic, not grim. Binder ruins with gold runes.
- **Palette:** obsidian, red rock, lava orange; night = lava glow and rising embers.
- **Landmark:** the volcano cone with a lava fall and a smoke plume (particles + a beam of glow at its lip).
- **Lighting:** day = bright and warm with light heat haze; night = lava glow and rising embers (bright, not murky).
- **VFX / sound:** embers rising, heat shimmer near lava (Low effects: off), occasional distant eruption rumble
  with a camera micro-shake; lava bubbling 3D sounds.

```
                 ▲ Volcano cone (lava fall)
              lava river ~~~~
         ■ obsidian arch       ~~~~
               ( FIRE ALTAR )  on a basalt dais
          basalt steps      lava pools
                ● AreaSpawn
        ◆ Portal back (camp: lanterns, sign)
```

### 3.3 Frozen Cliffs (Rebirth 3, Ice)

- **Theme:** sparkling white snow, turquoise ice, a frozen waterfall, crisp sky; glowing ice crystals.
- **Palette:** white, turquoise, crisp blue; accent: aurora green/violet.
- **Landmark:** a giant ice crystal spire on a cliff with a frozen waterfall; the aurora overhead at night.
- **Lighting:** day = bright, crisp, high exposure; night = a big green/violet aurora over glowing ice crystals.
- **VFX / sound:** falling snow, drifting mist on the lake, sparkles on ice; wind, creaking ice.

```
             ▲ Ice spire on cliff + frozen waterfall
         cliff wall ─────────────
          frozen lake (walkable)
              ( ICE ALTAR ) on an ice platform
        snow drifts     crystal clusters
                ● AreaSpawn
          ◆ Portal back (camp)
```

### 3.4 Storm Canyon (Rebirth 5, Storm)

- **Theme:** a towering red-and-purple canyon; floating rocks, electric-blue crystals, lightning rods.
- **Palette:** red rock, purple, electric blue; accent: white lightning.
- **Landmark:** a tall stone lightning tower on a mesa, struck by lightning every few seconds (flash + beam).
- **Lighting:** day = bright with dramatic clouds; night = purple storm sky with lightning lighting the canyon.
- **VFX / sound:** rain streaks (Low effects: lighter), lightning flashes, floating rocks bobbing; thunder, wind.

```
          ▲ Lightning tower (mesa)
      canyon wall        canyon wall
          |  floating rocks  |
          |  ( STORM ALTAR ) |  on a rock bridge
          |   rope bridge    |
                ● AreaSpawn
          ◆ Portal back (camp)
```

### 3.5 Eclipse Isles (Rebirth 10, Shadow)

- **Theme:** floating islands in a violet sky; silver ruins of the binders; a golden eclipse ring.
- **Palette:** violet, silver, eclipse gold.
- **Landmark:** a huge eclipse ring (dark sun with a golden corona) in the sky above a ruined temple island.
- **Lighting:** day = bright violet sky; night = near-black starry sky, silver moonlight, glowing violet ruins.
- **VFX / sound:** drifting shadow wisps, floating rock bits, star dust falling; low drones, distant chimes.

```
            ◯ Eclipse ring (sky)
          ▲ ruined temple island
        bridge ═══
            ( SHADOW ALTAR ) main island
        ═══ bridge        small islands (decor)
                ● AreaSpawn
          ◆ Portal back (camp)
```

Safety: every floating island edge gets an invisible fall catch that returns players to the `AreaSpawn`
(a tagged kill-plane handled by a small new server script, see section 6).

---

## 4. Onboarding: a new player's first 5 minutes

Problem: binding only works at night (4 min day + 3 min night). A player who joins at the start of the day can't
bind for up to 4 minutes, and nothing tells them what to do.

Proposed flow:

| Time | What happens | How it's shown |
|---|---|---|
| 0:00 | Loading screen, then a skippable 6-second camera fly-over: Spire → portals → altar → spawn, with the logo | New `IntroController`, only on first join (setting to replay) |
| 0:10 | "Your first dragon": the starter dragon is already in your pen. Beam + arrow to your pen | Onboarding tracker (top center) step 1; ground arrow + beam on the pen |
| 0:30 | "Collect gold": gold pops appear; step completes when gold > 0 | Tracker step 2 |
| 0:50 | "Level up your dragon": pulse on the Dragons tile, arrow in the panel to Level Up | Tracker step 3, highlight ring on the UI |
| 1:30 | **First bind (Falling Star)**: new players get one bind at any time of day, at the altar; plays the full ceremony | Tracker step 4, beam to the altar. Needs a server change (below) |
| 2:30 | "Place your new dragon in the roost" | Tracker step 5 |
| 3:00 | "Visit the stations": merchant, shrine, forge each get a short tip when you walk up | Tracker step 6 (optional steps, each ticks off) |
| 4:00 | "Night falls soon: come back to the altar" | Tracker step 7 + the dusk warning |
| Later | First Spire climb (tracker), first rebirth (progress bar toward Rebirth 1 on the tracker), first portal (beam to the Volcano portal after Rebirth 1) | Tracker switches to "goals" mode after the first night |

Code this needs (propose now, build in Stage 4):
- `data.Onboarding` (step index + done flags) with a data migration (version 3). Server-owned: steps complete from
  real events (bind, level-up, place in roost, climb, rebirth, portal) that services already see.
- **Falling Star bind:** `BindingService` allows one daytime bind while `data.FirstBindDone` is false; normal odds
  (base luck, meadow roster). This is a design change and needs your OK (section 11).
- `OnboardingController` (tracker UI, beams/arrows using `Beam` + attachments, UI highlight rings), config in
  `Config/Onboarding` (steps, texts, targets by tag).

---

## 5. UI remaster

### 5.1 Audit (today)

| Screen | Now | Problem |
|---|---|---|
| HUD menu grid (Shop, Quests, Index, Boosts, Dragons, Rebirth, Settings) | 2-column icon grid, left middle | Good base. No priority: Rebirth looks like the others; Settings tile is a letter |
| Currency pills | Gold + Stardust, bottom left (PC) / top left (phone) | Fine; income rate shown. Runes/Stones only in panels |
| Sky / clock HUD | Top center: "Day · Night falls in 1:59" | Clear. Night could be more of an event |
| Luck pill + boost timers | Top right (phone) | OK; timers are small |
| Toasts / notifications / announcements | Stacked | Some overlap with the Spire card on phones |
| Prompts | Themed (PromptController) | Good |
| Dragons panel | Card grid, level up, place in roost | Busy; no sort/filter; no "level up all" feedback on phones |
| Index / Star Atlas | Grid + atlas | Fine; could use progress rings |
| Quests | List with rewards | No "claim"/done state animation; streak hidden |
| Shop | Pass cards with icons | Needs featured item, better prices layout |
| Boosts | Potion list, arm luck | OK |
| Rebirth | Button + confirm panel | Doesn't show *progress* to the next rebirth anywhere |
| Luck panel (altar) | Luck breakdown | Good information, dense |
| Merchant / Shrine / Forge panels | Station panels | OK; odds scroll |
| Spire card + fight panel | Timer bar | No visible fight (known open question) |
| Settings | New | Fine |
| Missing | — | Loading screen, intro fly-over, onboarding tracker, rebirth progress, "bind now" action, pen claim feedback |

### 5.2 New hierarchy

1. **Primary action button** (bottom right on phones, bottom center on PC): context-aware.
   Night + near altar = **BIND** (glowing); night + away = **Go to altar** (beam); day = **Night in 1:23** (shows
   countdown, taps open the luck panel); at the Spire = **Climb**. One place for the most important thing.
2. **Top center:** sky/clock bar, with the onboarding/goal tracker under it (collapsible).
3. **Top left / bottom left:** currencies (unchanged), plus a rebirth progress bar under Gold ("Rebirth 12: 63%").
4. **Left:** the menu grid, with badges (quests ready, potions, new Index entries). Rebirth tile glows when
   affordable.
5. **Right:** luck pill + boost timers (unchanged).
6. **Toasts:** one stack, right side under the timers; big announcements top center under the clock.

### 5.3 Style

Keep the UITheme kit (fonts, colors, rarity/element colors, sounds, icons). Add:
- The artist's panel frame (dragon scales), title ornament and panel texture into the existing `UITheme.Art` slots.
- Window headers with the menu icon next to the title.
- Hover/press animation on every button (springs, see section 6), opening windows scale in.
- Rarity-colored card borders + glow for Epic+.
- Empty states with a hint ("No dragons in your roost yet: tap Place in roost").

New screens: loading screen (logo, tips from `Config/Text`, progress), intro fly-over, onboarding tracker,
rebirth progress, primary action button, a "Night has fallen" banner, and the Spire fight view (later; open
question).

---

## 6. Third-party modules (for approval)

| Module | Source | License | What it does for us | Why it's safe |
|---|---|---|---|---|
| Signal | Sleitnick/RbxUtil `modules/signal` | MIT | Typed events between controllers (area changed, onboarding step) instead of our ad-hoc listener tables | Pure Luau, no dependencies, no HttpService/require(id)/loadstring; widely used |
| Trove | Sleitnick/RbxUtil `modules/trove` | MIT | Cleans up connections/instances when a window, area or effect goes away (fewer leaks as UI grows) | Same as above |
| Spring | Sleitnick/RbxUtil `modules/spring` | MIT | Springy UI motion (buttons, windows, tracker) and smooth camera moves for the intro | Same as above; math only |

Copied into `src/ReplicatedStorage/Packages/<Name>` with the LICENSE file (like ProfileStore), pinned to a commit.
I'll read each file in full before adding it.

Considered and **not** recommended:
- **TopbarPlus** (MPL-2.0 + a credit requirement in the game description): we have our own HUD; not needed.
- **ZonePlus** (MIT, last updated 2024): only needed for a connected world; with portals, our nearest-spawn area
  detection is enough.
- No Creator Store scripts. Creator Store models/meshes only (scripts inside are deleted and reported).

Small new code of our own (not third-party): `IntroController`, `OnboardingController`, `LoadingScreen`
(in `ReplicatedFirst`, which needs a `default.project.json` mapping and a `rojo serve` restart), a
`FallCatchService` for floating islands, `HorizonController` for the horizon landmarks. All config-driven.

---

## 7. Performance budget (per area, phone first)

| Item | Meadow (hub) | Other areas | Notes |
|---|---|---|---|
| BaseParts in the area | ≤ 2,500 | ≤ 1,800 | Today the meadow has 1,358, mostly part-built trees/pens. Mesh props replace groups of parts |
| Unique meshes | ≤ 60 | ≤ 40 | Reuse the same mesh many times (instanced) |
| Triangles in view | ≤ 250k | ≤ 200k | Builder meshes: ≤ 20k tris each, props ≤ 2k |
| Texture sets (SurfaceAppearance) | ≤ 25 | ≤ 15 | 1024² max; 512² for props |
| Active lights (PointLight/SpotLight) | ≤ 8 near the player (already capped by `WorldLifeController`), no shadows | ≤ 8 | Glow via Neon + bloom instead of lights |
| Active particle emitters | ≤ 20, ≤ 400 particles on screen | ≤ 20 | Low effects: about a third |
| Beams / trails | ≤ 20 | ≤ 20 | |
| Streaming | Target radius 384–512, min 128 | same | Atomic on tagged models (unchanged). Horizon landmarks are client stand-ins, not streamed |
| Water terrain | Small ponds only | Frozen lake uses ice, not water | |

Check: MicroProfiler + Studio's device emulator (low-end phone) at the spawn and at the altar in each area; target
a steady 60 fps on a mid phone and 30 fps on low-end with Low effects on.

---

## 8. Studio AI generation (where it helps)

- Blockout and filler props: rocks, crystal clusters, stumps, bushes, lava rocks, ice shards, ruins pieces
  (mesh generation; each checked for triangle count and scaled).
- Terrain material variants (volcanic rock, packed snow, storm slate, void stone) and textures for signs.
- Landmark stand-ins until the builder's art arrives (ice spire, lightning tower, temple).
Everything generated is marked in its name (`AI_...`) so the builder can swap it later.

---

## 9. What still needs human art (for the builder)

Priority order:
1. **Dragon models** (0 of 80 done): at least one model per species (20) that scales by stage, then per-stage
   models; plus idle/walk/fly animations (rigged, ≤ 10k tris each).
2. **Element altars** for Volcano, Frozen, Storm, Eclipse (today: part-built copies). Must keep a `Core` part and
   a spot for the Glow anchors.
3. **Area landmarks:** ice crystal spire, lightning tower, eclipse temple + ring, volcano lip dressing.
4. **Pen kit:** fence, gate, nest, sign board (one set, reused 8 times).
5. **Station roof signs:** Merchant, Rune Shrine, Dragonstone Forge (and the Spire door sign).
6. **UI art:** panel frame (scales), title ornament, panel texture, Settings icon, Tower Elevator + Elevator Skip
   shop icons, onboarding arrow, area name logos (5), game logo.
7. **Loading screen key art, game icon and thumbnails.**
8. **Spire interior/arena** (for the fight view, later).
9. Sound: music for Frozen, Storm, Eclipse (the designer can pick free tracks).

**Ownership:** most 3D art is uploaded from zenoss_00's and xdize06's personal accounts. Before launch, move the
game and all assets to a group (or re-upload from the owner) and test in a published server. Otherwise some art
may not load for players.

---

## 10. Build order and effort

Effort in working sessions like today's (one session ≈ one wow-pass phase).

| Stage | Work | Effort | Gate |
|---|---|---|---|
| 2 Blockout | Backup (in place, you download a copy); move Eclipse shell to NW; terrain shapes, paths, landmark placement and stand-ins for the 4 areas; meadow path/prop cluster plan marked with simple parts; horizon landmarks | 2 sessions | One overview screenshot per area |
| 3a Starter Meadow detail | Mesh props, pen kit (placeholder until art), station signs, portal framing, terrain paint, lighting tune, VFX, sound | 3 sessions | Play check, overview + spawn screenshot |
| 3b Volcano Peak | Terrain, lava, landmark, camp, lighting, VFX, sound | 2 | same |
| 3c Frozen Cliffs | same | 2 | same |
| 3d Storm Canyon | same, lightning system | 2 | same |
| 3e Eclipse Isles | islands, fall catch, eclipse ring | 2 | same |
| 4 UI remaster | Packages; loading screen, intro, onboarding (with data v3 + Falling Star bind), primary action button, rebirth progress, window polish screen by screen; phone + PC checks | 5–6 | Per screen group |

Total: about 18–20 sessions.

---

## 11. Decisions I need from you

1. **World structure:** separate areas + portals, plus horizon landmarks (recommended), or a connected world?
2. **Move Eclipse Isles** placeholder from south to north-west, behind its portal? (Recommended.)
3. **Falling Star bind:** a new player's first bind works any time of day? (Recommended; otherwise the first bind
   can take up to 4 minutes.)
4. **Third-party:** approve Signal, Trove, Spring (RbxUtil, MIT)?
5. **Primary action button** on the HUD (Bind / Go to altar / Night in / Climb)? (Recommended.)
6. **Loose trees** `Workspace.Realistic Tree` and `Workspace.Tree`: move to `TeamItems_ToSort` at the Stage 2
   backup, or are they the builder's work in progress to keep?
