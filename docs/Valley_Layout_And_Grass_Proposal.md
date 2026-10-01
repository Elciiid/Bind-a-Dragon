# Valley layout fix + kids' grass: proposal (not built)

Images in `docs/img/`: `valley_layout_current|A|B|C.jpg` (straight top-down; colored discs = 150-stud sanctuaries with a white gate bar; red = altar), `grass_{base,opt1,opt2}_{ground,aerial,night}.jpg`.

## 1. Layout

Measured today (top-down raycast of the flat terrace inside each 80-stud disc, area in studs^2):

| Plot | Center | Gate dist. from altar | Flat usable area | Notes |
| --- | --- | --- | --- | --- |
| W1 / E1 | (+-208, -184) | 203 | **18,290** (91% of the disc) | the outer 10 studs (r 70-80) are cut: 62% flat at r 70-80, 0% beyond; the portal terrace / hills behind it |
| W2 / E2 | (+-174, -30) | 102 | **20,050** (99%) | full disc |
| W3 / E3 | (+-158, 150) | 143 | **18,230** (90%) | valley edge cuts the outside |

So W1/E1 and W3/E3 are ~9% smaller than W2/E2 (flat 100% only to r 60-70, then the rim steps off). Gate distances 102 / 143 / 203 are very uneven; W1/E1 gaps to W2/E2 are 7 studs.

| | A: even horseshoe | B: two straight columns | C: keep, shrink W1/E1 |
| --- | --- | --- | --- |
| Positions | R 256 from the altar, bearings +-60/100/140 from north (W1 (-222,-128), W2 (-252,44), W3 (-164,196)) | x = +-215, z = -175 / 0 / 175 | as now, W1/E1 radius ~60 (120 across) |
| Gate distance from altar | **181 for all six** (gates face the altar) | 202 / 140 / 202 | 203 / 102 / 143 |
| Gap between neighbours | 25 | 25 | 7 (W1-W2), 24 (W2-W3) |
| Valley wide enough? | Needs ~+-330 at z 0..50: the valley is +-300 at z 0 and +-315..335 at z 50 -> **widen the edge ~35 studs on both flanks near z 0..100** and cut into the foothills; W1 sits (-222,-128): inside at z -150 (valley +-260) | needs +-290 at z+-175: valley is +-235 at z -200 and +-255 at z 150 -> widen **~60 studs at both ends** | fits today |
| Terrain under the plots now | W2 spot is the foothill: flat 43-46% (needs terraforming), W1/W3 70-94% | W2/W3 57-64% flat, hills/low ground | fine |
| Moves | plots, their roads (re-route plaza->gate roads as straight spokes), river bows (river is at z ~60: W3/E3 at (-164,196) is south of it, W2 at z 44 straddles it -> river/bridges/ponds shift), market ponds, side bridges, TravelPoints, trees/ruins in the clear zones, bounds, valley edge terrain | all roads, river crossing at every column, bounds, edge | W1/E1 terrace only (Studio rebuild of 2 plots), TravelPoints |
| Portal terrace / Spire | stay; W1/E1 end up beside the portals at about the terrace's west/east tips (-222,-128) vs terrace x -95..95 | stay, W1/E1 move out to x +-215 (beside, 120 studs clear of the portals) | W1/E1 stay behind |
| Risk / cost | **highest**: 6 plots rebuilt (terrain, terrace, kits are local so they move with the plot), roads, river, edge sculpt, bounds | high (similar) | **lowest**, half a day |

Recommendation: **Option A in a "A2" variant (R 240-256, bearings +-50/90/130 north-open)**, because it is the only one with equal gate distances and plots on one arc; it also puts W1/E1 beside the portals as asked. It is the biggest rebuild, so build it in steps (new terrain terraces first, then roads/river, then kits re-attached), with a backup (`ServerStorage.Backups`). If cost matters more than evenness, take **C+**: shrink W1/E1 and also trim W3/E3 to the same usable area (~18,200), leaving the layout as is.
Same usable area for all six in A or B: the plan is a flat 77-stud-radius terrace (about 18,600 studs^2) for every plot, i.e. the current W1/E1/W3/E3 size, and W2/E2 is trimmed to match; measured again after the build.

## 2. Life between sanctuaries
After the layout is approved: lantern paths along the spokes, small binder ruins, crystal / star-blossom trees and flower patches in the new grass gaps (`ValleyDetail`, deterministic seeds, keeping the plaza and portal-terrace clear zones). Nothing built yet.

## 3. Grass for kids: options (both tested in Studio, not applied)
`Terrain.GrassLength` (and `Decoration`) **cannot be set from scripts or the MCP** (not exposed to the tool's thread). Set it by hand: select `Workspace > Terrain` in the Explorer, Properties > Appearance > **GrassLength = 0.4** (default 0.7). I could therefore not show the shorter blades in the screenshots; everything else below is in the images (Studio Edit view; Play shows denser blades but the same colors).

- **Option 1 (color only):** `Terrain:SetMaterialColor(Grass, (122,152,58))` (was (88,112,60)): sunny yellow-green blades and ground, same Valley_GrassA texture. Slopes / forest (Mud = Valley_ForestA, teal) stay deeper. Night (`grass_opt1_night`): still reads green and a bit brighter than now.
- **Option 2 (color + clover dots):** option 1 colour (128,158,58) with the new texture `Valley_GrassD` (made by `tools/terrain_textures/gen.py valley_grass_d`: pale clover dots + a few warm buds on a slightly deeper base; asset rbxassetid://74192556784093; the MaterialVariant `Valley_GrassD` already exists in MaterialService). At ground level the dots are tiny (48-stud tiles); from the air they give the fields a faint speckle.
- Blades and ground match (both come from the terrain Grass colour). Applying either: set the colour (and for option 2 `MaterialService:SetBaseMaterialOverride(Grass, "Valley_GrassD")`) in Edit mode; the Valley build modules set the colour in `ValleyTerrain` (`V.GrassColor`), update it there too.
Pick 1 or 2 (or tweak the colour) and I apply it.
