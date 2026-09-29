# Bind A Dragon: "the Valley" (Starter Meadow), master plan, checkpoint A

Written 2026-09-27 from the master prompt; approved at checkpoint A with the grand bridge on the main road. It replaces every earlier layout proposal in this file (the Portal Ring,
the 54-stud roosts, the first sanctuary draft). Reference image: `E:\Roblox\Bind a Dragon\assets\concepts\valley_day.webp`.
Style: "The Starlit Highlands" (plan section 2b, updated today). Nothing has been built yet.

## 1. Top-down sketch (north = up, schematic; exact positions in section 2)

```
N                   ~ ~ ~   far mountain ranges + 3D clouds   ~ ~ ~
      VOLCANO+smoke        ICE SPIRE               STORM TOWER    ISLAND + GOLD RING
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^   [ DRAGON SPIRE ]   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
^^^^ forest on the slopes ^^^^        on its hill       ^^^ forest on the slopes ^^^^^
^^^                                       ||                                       ^^^
^^^  +----------+             (FROZEN)    ||     (STORM)             +----------+  ^^^
^^^  |    W1    |    (VOLCANO) == PORTAL TERRACE +12 ==  (ECLIPSE)   |    E1    |  ^^^
^^^  |    +10   |> gate                arrivals                gate <|    +10   |  ^^^
^^^  |          |                         ||  grand stairs           |          |  ^^^
^^^  +----------+                         ||                         +----------+  ^^^
^^^                                  .----++----.                                  ^^^
^^^                                /              \                                ^^^
^^^ +----------+                  |   STAR ALTAR   |                  +----------+ ^^^
^^^ |    W2    |                  |  stepped plaza |                  |    E2    | ^^^
^^^ |    +8    |> gate ---------  |       +5       |  --------- gate <|    +8    | ^^^
^^^ |          |                   \              /                   |          | ^^^
^^^ +----------+                     '----++----'                     +----------+ ^^^
WATERFALL v                               ||                                       ^^^
^^^~~~~~~~~~~~~~~~~ [BRIDGE] ~~~~~~~~~~ [GRAND] ~~~~~~~~~ [BRIDGE] ~~~~~~~~ cascade >^
^^^  +----------+       ~~ West Pond ~~   ||    ~~ East Pond ~~      +----------+  ^^^
^^^  |    W3    |> gate                   ||                   gate <|    E3    |  ^^^
^^^  |    +6    |       MERCHANT [#]  <> obelisk     [#] FORGE       |    +6    |  ^^^
^^^  |          |        SHRINE [#]  MARKET SQUARE                   |          |  ^^^
^^^  +----------+                         ||                         +----------+  ^^^
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ [*] ENTRANCE GATE [*] ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                        o SPAWN
```

Legend: W1–W3 / E1–E3 = Dragon Sanctuaries (terrace height), `> gate` = sanctuary gate facing the altar,
(VOLCANO) etc. = portal gates, [#] = station, <> = star obelisk, ~ = water, ^ = mountain slopes and forest.

## 2. Positions

Studs, (x, z) with north = -z; the altar stays where it is (0, 0). Heights are above the valley floor (y ≈ 0).

| Place | Position | Size / height | Notes |
|---|---|---|---|
| Spawn (`SpawnLocation`) | (0, 160) | – | Valley mouth, just inside the entrance gate; new players start here |
| Entrance gate | (0, 150) | two stone towers ~16 tall, road 20 wide | Binder ruin: towers with blue star banners, gold stars, lanterns; forested cliffs on both sides (`Placeholder_EntranceGate`) |
| Market square | center (0, 112), radius 26 | flagstone | Star obelisk in the center (`Placeholder_StarObelisk`: glowing blue crystal on a 3-step base, signpost arms to "Altar", "Sanctuaries", "Portals", "Spire") |
| Star Merchant (tent) | (-56, 116), faces east | builder's model | On a low stone platform at the square's west side |
| Dragonstone Forge | (58, 114), faces west | builder's model | East side of the square |
| Rune Shrine | (-50, 144), faces north-east | builder's model | South-west corner of the square, by the gate |
| Waterfall | western cliff (-310, 58) | ~45 studs high | Pool at (-285, 60); keeps the current waterfall effects (beams, foam, sound) |
| River | centerline z ≈ 52–63, from the pool east through the gap between W2 and W3 | 14 wide (16 at the main road) | Runs past the plaza's south foot; the grand bridge carries the main road over it; leaves east through the gap between E2 and E3 as a small cascade into the forest |
| West Pond / East Pond | (-65, 84) / (65, 84) | ~74 × 32 each | South of the river, behind the merchant tent and the forge; lily pads, reeds, stones |
| Grand stone arch bridge | (0, 63), on the main road | ~20 wide, spans the 16-stud river | The valley's second landmark: gold star inlays, lanterns; lands at the plaza's south steps |
| Side stone arch bridges | (-100, 60) / (100, 60) | ~14 wide | Carry the roads to W3 and E3 over the river (gold star keystones, lanterns) |
| Star Altar plaza | (0, 0), radius 50 | 3 stepped rings, top +4.4 (the altar's floor today) | Stepped all around; 8 lanterns, 4 star banners (`Placeholder_StarBanner`), star mosaic floor |
| Sanctuary W1 / E1 | (-187, -117) / (187, -117) | 96 across, terrace +10 | Bearing 58° from north; gate at (∓146, -91) |
| Sanctuary W2 / E2 | (-220, 0) / (220, 0) | 96 across, terrace +8 | Gate at (∓172, 0) |
| Sanctuary W3 / E3 | (-187, 117) / (187, 117) | 96 across, terrace +6 | Gate at (∓146, 91); reached over the arch bridges |
| Portal terrace | crescent around the altar, radius 140–180, bearings ±44° | +12, stone retaining wall | Grand stairs in the middle; each gate stands on its area's ground (basalt, snow, slate, violet moss) with its crystals and glows in its color |
| Portal gates | Volcano (-94, -129), Frozen (-36, -156), Storm (36, -156), Eclipse (94, -129) | builder's arches, full size | Radius 160 at bearings -36°, -13°, 13°, 36°, facing the altar; unlock order left to right |
| Meadow `AreaSpawn` | (0, -150) on the terrace, faces south | +12 | Returning players arrive between the Frozen and Storm gates, looking at the altar |
| Dragon Spire | (0, -250), entrance at (0, -222) | hilltop +28 | Grand stairs continue from the terrace up the hill |
| Valley floor | x ±270, z -200 to +160 | – | Slopes and cliffs rise behind the sanctuaries to ridges 60–140 studs high at radius 300–420; invisible `Bounds` walls follow the valley edge |
| Area landmarks (sky) | Volcano (-418, -498), Ice spire (-168, -628), Storm tower (168, -628), Floating island (418, -498) | ~250–330 tall; island at y ~200 under the gold eclipse ring | Bearings -40°, -15°, 15°, 40° from the altar, so each one sits behind its gate as seen from the spawn and the plaza (fanned out a little wider, like the image) |
| Mountain ranges | all around, radius 550–900 | – | Client-side backdrop models (`HorizonController`), no collision, never streamed |

**Walk times (16 studs/s, straight roads):** spawn → altar ≈ 10.5 s; altar → any sanctuary gate ≈ 11 s (all six gates
are on one circle, radius 172); altar → portal gates ≈ 11–13 s; altar → Spire entrance ≈ 14 s.

## 3. Where it differs from the image (and why)

1. **The sanctuaries are much bigger than the image's pens** (96 studs across, 8 dragons including 15-stud Elders), so
   the valley is about 560 studs wide, and W3/E3 sit beside the market instead of above the bridges.
2. **The river reaches the ponds through the gap between W2 and W3**, not below W3 (there is no room below W3 without
   pushing the market and spawn back, which would make spawn → altar ~13 s).
3. **The two side arch bridges are on the roads to W3 and E3, about 100 studs out** (in the image they sit next to the
   main road); the main road crosses the river on the grand stone arch bridge (approved at checkpoint A).
4. **The portal gates stand on a gentle crescent** facing the altar, not a straight row, so every gate faces the
   altar and the terrace clears the northern sanctuaries.
5. **The Spire is further from the altar** (~14 s instead of ~9 s today), on its hill at the top as in the image.

## 4. Dragon Sanctuary (all six the same, turned so the gate faces the altar)

- **Floor:** a flat 96-stud disc (the `Base` part, grass, PrimaryPart) on a terrace with a low weathered stone
  retaining wall. `RoamCenter` = the Base top center, `RoamRadius` 40.
- **Front (altar side):** the grand binder gate: two stone pillars ~20 tall with gold star inlays and runes (glow at
  night), a lintel with a gold star and the owner `Sign` under it. Outside it, a small forecourt with the two upgrade
  stands (`UpgradeSlots` / `UpgradeIncome`) flanking wide steps down to the road, and two iron lanterns.
- **Nesting ground (front left):** three big straw nests, hay bales and a warm timber shelter (open front, shingle
  roof) against the wall. Marked by `NestZone`.
- **Drake meadow (center):** open grass with a few rocks, and a small stone-rimmed pond or water trough on the front
  right. Marked by `MeadowZone`.
- **Flight zone (back half):** 3–4 rock pillars 18–30 studs tall with flat mossy tops (future perches), cliff ledges
  on the slope behind, a broken binder arch and a rune stone. Everything tall stands 41+ studs from the center, so
  fliers (FlyHeight 8 / 16, roaming up to 34 studs out) never clip it; the sky above stays open.
- **Budget:** about 75–90 parts each, 2 lanterns (only the nearest 8 lanterns in the valley cast light).
- The six plots stay the same `RoostPlot` models (tag, Atomic streaming, `Base`, `Sign`, stands, attributes); I
  move and rebuild them.

## 5. Proposed code change: spawn zones (small; I'd build it at checkpoint C)

Today the server drops a new roost dragon at a random spot within 0.7 × RoamRadius, and walkers roam the whole
circle. With a shelter, pond and pillars inside, dragons could appear in a rock or walk through the pond.

- **Place data:** each plot gets a `Zones` folder with two invisible flat disc parts, `NestZone` and `MeadowZone`
  (no collision, no queries). Their size is the zone.
- **`Config/Evolution`:** each stage gets `Zone`: Hatchling = "Nest", Drake / Dragon / Elder = "Meadow".
- **`RoostService`:** places a new dragon at a random open spot inside its stage's zone, kept half the model's width
  from the zone edge. If a plot has no zones, it falls back to today's behavior.
- **`RoostAnimationController`:** Hatchlings and Drakes pick roam targets inside their zone; fliers take off from
  there and fly over the whole RoamRadius as today.
- About 40 lines in total. The server stays authoritative, and nothing changes in player data.

## 6. Other code and data changes

| What | Change | Type |
|---|---|---|
| Portals | The 4 portal models move to the terrace at full size; `Surface` keeps its tag and `AreaId`, server checks unchanged | Place data |
| Meadow `AreaSpawn` / `SpawnLocation` | Terrace (0, -150) / entrance (0, 160) | Place data |
| Stations, Spire | Moved with their PrimaryParts (`Counter`, `PromptPoint`, `Entrance`) | Place data |
| Altar | Stays; the plaza is rebuilt around it | Place data |
| Sanctuaries | Same 6 `RoostPlot` models, moved and rebuilt; `RoamCenter` recalculated, `RoamRadius` 40 | Place data |
| Spawn zones | Section 5 | Code + config |
| 3D clouds | `Terrain.Clouds` is one object for the whole place, so each area's Day/Night look in `Config/Atmosphere` gets cloud Cover / Density / Color, blended by `AtmosphereController` (other areas can have their own sky). About 15 lines | Code + config |
| Landmarks + mountain ranges | New positions and entries in `Config/Horizon`; new `Placeholder_` models in `ReplicatedStorage.Assets.Horizon` (volcano cone with smoke, ice spire, storm tower, floating island + gold ring, mountain ranges). Replaces the "mushroom" volcano and the Eclipse blob | Config + place data |
| Bounds | Invisible walls follow the new valley edge | Place data |
| Perches (checkpoint E) | As proposed earlier: a `Perches` folder per sanctuary on the pillar tops and ledges; fliers sometimes land and rest (`RoostAnimationController`, `PerchChance` / `PerchSeconds` in config) | Code + config, later |
| Style-test code | The uncommitted `SunColor` + `NightGlow` changes get committed with checkpoint B | Code |
| CLAUDE.md | World section rewritten for the Valley | Docs |

Player data: no change. Max players stays 6.

## 7. Phone budget plan

- **Parts:** the meadow has 1,453 parts today. Terrain does all the landforms (costs no parts). Estimate after the
  rebuild: sanctuaries ~500, plaza + terrace + gate grounds ~300, market + entrance + bridges ~200, ruins and lanterns
  ~250, nature ~600 → about 1,850–2,300 (budget 2,500).
- **Triangles in view (≤ 250k):** realistic trees are the main cost, so ≤ ~150 trees around the valley, mostly on
  the slopes, with automatic LOD; distant ranges are a few low-poly backdrop meshes. Measured at C and D.
- **Lights:** lanterns tagged `Lantern` (only the nearest 8 cast light, 4 on Low effects).
- **Emitters (≤ 20 near the player):** waterfall 4, altar 2, gates 1–2 each, obelisk 1, drift 2; all world emitters
  tagged `AmbientFX` so Low effects scales them.

## 8. Build steps and checkpoints

| Checkpoint | Work | What you get |
|---|---|---|
| B | In-place backup (tags stripped) + download reminder; clear the old meadow layout (e1b pens' contents, ring, roads, cartoon props); terrain: valley floor, cliffs, waterfall, river + ponds, sanctuary terraces, plaza rise, portal terrace, Spire hill, mountain ridges | One overview screenshot from the concept image's angle; commit (style-test code) |
| C | Entrance gate, market square + obelisk, stations moved, bridges, plaza, portal terrace with the 4 gates, Spire moved, AreaSpawn/SpawnLocation, 6 sanctuaries placed with zones; spawn-zone code | Overview + spawn screenshots; commit |
| D | Nature (forest on slopes, oaks, wildflowers), ruins, dressing, backdrop ranges, landmarks, 3D clouds, lighting day + night, Low effects check, Play check | Overview day + night from the concept angle + spawn shot; commit |
| E | Perches for flying dragons, final report | Commit |

Kept: the builder's models, the realistic store trees and rocks (moved to the slopes), iron lanterns, rune stones,
the waterfall effects. Removed from the meadow: every cartoon AI prop (the kits stay in `ServerStorage.PropKits`).
Unknown items go to `ServerStorage.TeamItems_ToSort`.

## 9. Proposal (not built): painted skybox for weak phones

**Problem.** On low graphics quality Roblox shortens the draw distance, and far terrain streams out on phones, so the
3D landmarks (650-720 studs out) and the distant ranges (~830) may not be drawn at all. In Studio at Automatic quality
even the far half of the valley disappeared from the overview camera.

**Idea.** A custom `Sky` per area whose six faces have the distant mountain ranges painted into the horizon band.
A skybox is drawn at infinite distance on every device, so the valley is always ringed by mountains. The 3D landmarks,
ridges and ranges stay for devices that can draw them and simply sit in front of the painted ones.

- **Two variants per area:** the normal sky has only the painted ranges (no double landmarks on strong devices). A
  "Low" sky also has faint painted silhouettes of the four landmarks behind their gates. `AtmosphereController` uses
  it when `EffectsQuality` is Low, which already turns on at low graphics levels.
- **Day and night:** the day sky is a blue gradient to a pale haze, with blue-gray ranges and snowcaps. The night sky
  is dark navy with stars and the same ranges in moonlight. A skybox can't blend, so the swap happens in the middle of
  dusk and dawn, hidden by the haze fade. `SkyController` still draws tonight's constellation on top.
- **Making the images:** a small generator in `tools/` (like the terrain texture generator) renders each face from
  one cylindrical silhouette (height by compass bearing), so the six faces are seamless by construction. It keeps the
  gaps behind the four gates where the landmarks stand. Images are uploaded like the terrain textures. The artist can
  later paint over the generated faces.
- **Size:** faces at 1024 px, about 4 MB of texture memory per sky (8 MB with day + night loaded); the Low sky could
  use 512 px faces.
- **Code:** `Config/Atmosphere` gets per-area `Sky` image ids (Day/Night, plus LowDay/LowNight).
  `AtmosphereController` swaps `Lighting.Sky` faces on area change and at dusk/dawn. No server change.
- **Effort:** about one session for the Meadow (generator, upload, controller, config); later areas reuse the
  generator with their own silhouettes and colors.
- **Risks:** the painted horizon has to sit low enough that the real ridges (5-15 degrees up from the valley) cover
  its base. The haze tints the sky's horizon, which helps depth but can wash out the ranges if Haze is raised.
