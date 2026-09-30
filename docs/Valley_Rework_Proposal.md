# Valley rework proposal: bigger sanctuaries, bigger dragons, three sanctuary looks

Status: PROPOSAL, nothing built. Studs everywhere. Mockups were made in Blender (massing, real posed Elder dragons).

## 1. Layout (top-down: `plan_before_after.png`)

| | Now | Proposed |
| --- | --- | --- |
| Sanctuary size | 96 across (rim r 48) | 150 across (rim r 75, terrace r 77) |
| W1 / E1 | (+-187, -117), gate 172 from altar | (+-194, -186), gate 194 |
| W2 / E2 | (+-220, 0), gate 172 | (+-174, -30), gate 102 |
| W3 / E3 | (+-187, 117), gate 172 | (+-158, 150), gate 143 |
| Average gate distance | 172 | 146 (15% shorter) |

- The only way a 150-stud disc fits is W1/E1 further out and north, past the portal terrace (bearing must stay >= 46
  degrees so the portal field and the landmark sight-lines stay open). Cost: altar to W1/E1 gate is +22 studs; portals
  to W1/E1 is 14 shorter. W2/E2 (-70) and W3/E3 (-29) get much closer to the altar.
- Kept: 6 plots, gates face the altar, market, spawn, portal terrace, Spire, the river (its two decorative bows at
  x = +-140..190 straighten a few studs so W2/E2 clear it), the side bridges at x = +-100.
- W3/E3 sit next to the market ponds: their forecourt road runs along the pond's outer bank to the side bridge. If it
  is too tight I nudge the pond 6 studs inward (ValleyTerrain `V.Ponds`).
- W1/E1 rims cut about 60 studs into the foothills (a natural cliff wall behind the back half, like today).

What changes in the tools:
- `ValleyTerrain`: `V.Sanct` (X, Z, T), `V.FlatR` 52 -> 80, `V.ApronLen` 66 -> 22 (forecourt), `V.PillarDist/Pillars` replaced
  by the kit's perch slots, back cliff radius, `V.Roads` (W1/E1 branch from the terrace walkway end, W2/E2 straight
  from the plaza ring, W3/E3 plaza -> side bridge -> gate), `V.River` (bows).
- `ValleyBuild`: `B.RoamRadius` 40 -> 64, `B.NestZone` {Forward 16, Side -22, Radius 13} -> centre (-36, -30) r 19,
  `B.MeadowZone` -> centre (14, -8) r 30, gate/rim/steps (`BuildSanctuary`), upgrade stands (`BuildUpgradeStands`, 1.6
  scale stays, moved out to the wider forecourt), `BuildTravelPoints`, `BuildSanctuaryTiers`.
- `ValleyDetail`: `D.ClearZones` gets six sanctuary discs (r 100), so BuildNature skips them; the random stream is
  unchanged, so every other tree keeps its spot and `D.RemovedByHand` still works. Trees that go: 41 (1 crystal
  tree at (-94, -41), 3 Specimens, 37 forest trees, listed in the plan image as red X); also 71 flowers, 25 ferns,
  16 night flora, 8 boulders and the ruins `Ruin_MeadowWest` (-100, -31) and the old `Sanctuary_*` ruins (rebuilt by
  the looks). `D.RuinSites` entry for MeadowWest becomes keep = false.
- Backups first: `ServerStorage.Backups.StarterMeadow_2026-10-01_BeforeSanctuaryRework` (Pens, Nature, Ruins,
  Dressing, TravelPoints, terrain read-out).

## 2. Dragon sizes (total length nose to tail tip; `sizes_front.png`)

| Stage | Now (real art / placeholder) | New length | New wingspan (flying) |
| --- | --- | --- | --- |
| Hatchling | 5.9 (placeholder) | **10** | ~14 |
| Drake | 8.2 | **15** | ~21 |
| Dragon | 11.1 | **21** | ~30 |
| Elder | 17 (real art, tail curled) | **28** | ~40 (Solflare 37, Infernus 28) |

- The rig template's `STAGE_LENGTH` becomes 10 / 15 / 21 / 28, measured after the tail is straightened (today it is
  measured on the curled model and Solflare ends up 19, Infernus 27).
- `ModelScale` only scales the placeholder; real art keeps whatever the place has. New `Config/Evolution` field
  `Length` per stage: RoostService scales any model (art or placeholder) so its length equals it. Replaces `ModelScale`.
- `Config/Evolution` (x = new): Hatchling MoveSpeed 4 -> 6, Drake 5 -> 8, Dragon 8 -> 12, Elder 10 -> 15 (about x1.5,
  a little slower than the size ratio so big dragons stay stately). FlyHeight: Dragon 8 -> `FlyHeightRange` 20-32,
  Elder 24-36 -> 44-68 (over the tallest perch, 38, and the centrepiece, 48). PerchSize unchanged (Dragon 1, Elder 2).
- `Config/Roost`: `Separation.Margin` 2 -> 4, `Climb` 10 -> 16, `ClimbRate` 4 -> 6, `Turns.RestSpacing` 3 -> 5,
  `Perch.ApproachHeight` 6 -> 10, `GlideDistance` 14 -> 24, `MaxAirborne` stays 4.
- Perch pads: Elder pad 19 across, Dragon pad 14 across (today 12 / none).
- One small code change: fliers steer around the sanctuary's `CenterZone` disc (r 24) while below the centrepiece's
  height (plot attribute `CenterHeight`), so they don't fly through the tree/crystal/dome.
- Checks to do while building (nothing changed yet): E prompt `PROMPT_RANGE` 10 -> 16 (measured from the dragon's
  centre; Elders in the air can't be reached, as today); nameplate `WorldLabels.MaxDistance` 40 -> 70 for nameplates only
  (the offset already scales with the model); camera zoom near 28-long dragons (dragons stay CanCollide false, so the
  camera passes through; test zoom-in inside a body).

## 3. Sanctuary looks

Shared slots (`slots.png`), local coordinates, centre = terrace centre, +Y toward the gate:
- Gate at y = 75, forecourt 22 long, the two upgrade stands at x = +-15, y = 88.
- Perch slots: Elder E1-E5 at (-58, -18) (-42, -48) (0, -66) (42, -48) (58, -18), pads 19, tops 26/32/38/32/26.
  Dragon D1-D3 at (-62, 12) (62, 14) (30, -30), pads 14, tops 12/16/20.
- NestZone centre (-36, 30) r 19 (three nests, hatchlings). MeadowZone centre (14, 8) r 30 (open landing space,
  drakes, resting dragons). Centrepiece slot centre (0, -34) r 24, max 48 tall. Water slot centre (-34, -22) r 17.
  Two basking rocks at (46, 40) and (-8, 44).
- All slots are the same in every look, so zones, prompts, perches and stands keep working when the look changes.

How a look works: `SanctuaryLook` plot attribute (server, string). The client clones only that look's kit
(`ReplicatedStorage.Assets.SanctuaryLooks.<Look>.<PlotName>`, built by a new `ValleyBuild.BuildSanctuaryLooks`
into world positions, like the tiers). Config: `WorldUI.SanctuaryLooks` = ordered list `{ Id, MinPoints }`, using the
sanctuary points (slots + income levels / 5, max 10) until Essence exists: Wild Hollow 0, Crystal Garden 4, Celestial
Sanctum 8 (placeholders). Studio test switch: server Player attribute `TestSanctuaryLook` = look id.
Look change moment: old look fades and sinks over 1.5 s, the new one grows in piece by piece over 2 s with a
sparkle burst at the gate, `Text.Moments.Look` reward pop-up + sound.

Gold-upgrade tiers (`WorldUI.SanctuaryTiers`, kept) vs looks:
| Tier | Wild Hollow | Crystal Garden | Celestial Sanctum |
| --- | --- | --- | --- |
| 1 Gilded (gold rim trim, gate banners) | as is | as is (white-gold rim, so gold trim hidden) | as is |
| 2 Runed (rune circle, braziers) | as is | as is | rune circle hidden (constellation floor), braziers kept |
| 3 Crystal (crystals at the pillars, motes) | as is | hidden (the look is crystals) | as is (on the islands) |
| 4 Ascendant (pillar runes, aurora at night) | as is | as is | as is |
| 5 Legendary (sky beam, gold statues on the gate) | as is | as is | hidden (the look has both) |

### Piece lists for Meshy (studs, W x D x H; tris = target per mesh; "xN" = cloned N times; names
`Placeholder_<Look>_<Piece>`)

Shared by all looks (each look gets its own art, same sizes): `Gate` 30x5x28 (8k) - `PerchElder` x3 variants, base
22 across, pad 19, 26/32/38 tall (4k each) - `PerchDragon` x2 variants, pad 14, 12/16/20 tall (3k each) - `Nest` 11
across x 2.5 (1.5k, x3) - `BaskRock` 18 across x 3 (1k, x2) - `RimSegment` 15x5x6 (600, x30) - `ForecourtTile` 8x8x0.5 (200).

**Wild Hollow** (budget 45k tris / 200 parts):
- Centrepiece `NestTree`: trunk + roots 34x34x30 with a hollow 8 wide x 10 tall (12k), canopy 34 across x 22 (10k) =
  48 tall; `Lantern` 1.5x1.5x2.5 (300, x8 hanging from the canopy).
- `Gate`: wooden posts and lintel with a gold star 5 across (5k).
- `MossyArch` 18x4x20 (4k), `BrokenColumn` 4x4x14 (1k, x3), `RuneStone` 4x2x6 (500, x2).
- `RockLedge` 26x18x10 (6k, x3), `SpringRock` 14x12x14 with a trickle (4k), `PondRim` ring 34 across (2k).
- `HayNest` (the Nest), `MossyPerch`/`MossyPerchSmall` (spires with grass caps), `MossBask` rocks.
- Planting: reuse Valley flowers/ferns; new `MushroomClump` 3x3x3 (500, x6, glowing at night), `FlowerClump` (reuse).
- Night: lantern glow (warm), moss/mushroom `NightGlow`, spring shimmer.

**Crystal Garden** (budget 55k / 240 parts):
- Centrepiece `GiantCrystal` cluster 26x26x46 (9k, emissive star-blue) on `CrystalBasin` 48 across x 3 (6k).
- `RuneGate` 30x5x28 carved, gold inlay (8k).
- `GardenTerrace` x3 tiers, 40 / 28 / 16 across, 3 / 6 / 9 tall, balustrades (8k total).
- `CrystalPool` 34x30x12 with a 3-step waterfall (8k), `CrystalCluster` small x4 sizes 3-9 tall (400-1.5k, x20).
- `WhiteGoldPerch` (3 spires, gold ring, 3 crystal spikes 9 tall around the pad), `WhiteGoldPerchSmall`.
- `StarBlossomTree` (reuse `Fantasy_StarBlossom` 16 across x 20), `StoneLantern` 2x2x6 (400, x8), `WhiteGoldRim` 15x2.5x5.
- Night: crystals emissive pulse, pool glow, blossoms `NightGlow`.

**Celestial Sanctum** (budget 65k / 260 parts):
- Centrepiece `StarDome`: crystal dome 28 across x 20 on a rock base 18 across x 12 (14k), `ConstellationRing` x3 tubes
  32 / 40 / 48 across (2k each, rotated by script), starlight beam = a script beam (no Meshy).
- `GrandGate` 40x6x34 in gold (8k) + `DragonStatue` x2 12x10x16 (6k each).
- `FloatingIslandElder` x5 (22 across x 12 tall with hanging rock underside, pad 19; 5k), `FloatingIslandDragon` x3 (16
  across x 10; 4k), `LightBridge` x4 (parts, 28 long x 4 wide, neon), island waterfalls = beams + particles.
- `ObservatoryRing` 56 across x 1.5 gold (3k), constellation floor = a 1024 texture on a disc 54 across (no tris),
  `MarbleRim` 15x2.5x12 (700, x30), `StarNest` (gold nest with a crystal egg).
- Night: dome, rings and beam glow, island rims lit, constellation stars glow.

### Budgets (phone)
- Per look, kit only: Wild Hollow <= 45k tris / 200 parts, Crystal Garden <= 55k / 240, Celestial <= 65k / 260; <= 24
  unique meshes, <= 6 textures at 1024, <= 6 lights (2 cast), <= 12 emitters.
- Worst case 6 x Celestial = 390k kit tris + 48 Elders x 10k = 480k dragon tris. Too much for a phone if all drawn, so:
  each kit is only cloned while its sanctuary is within 320 studs (typically 2-3 of 6); Elders beyond 120 studs draw a
  4k-tri version (rerig `--tris 4000`) and beyond 260 studs hide; Low effects caps visible dragons per sanctuary at 4.
  Expected on screen at the altar: about 250k tris. Measured in Studio during the build (part/triangle counts per
  look) before the last look ships.

## 4. Checks (from the mockups; re-measured in play after the build)
- 8 Elders (28 long, 40 span): 4 in the air (their own layers 44-68), 5 Elder perches + a 30-radius meadow for the rest;
  worst case 8 resting = 5 on perches + 3 on the meadow (about 1500 of its 2800 studs squared). Fits in every look.
- Landmarks: the altar plaza (radius 57 flagstone + tall crystal), Spire (radius 42 hill, 28 up) and portal terrace stay
  the tallest, widest things on the axis; centrepieces stay under 48 tall and sit 100+ studs off the axis.
- Walking: altar to gate 15% shorter on average (W2/E2 -41%, W3/E3 -17%, W1/E1 +13%).
- Build order (checkpoints, each with screenshots and your OK): 1 terrain + layout + Config sizes with plain
  placeholders, 2 the kit system + Wild Hollow, 3 Crystal Garden, 4 Celestial Sanctum + look-change moment + budget check.
