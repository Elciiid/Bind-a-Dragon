# Bind a Dragon — Kyle reference remodel

Private target: **Bind a Dragon TEST Kyle**, place ID **85007700009982**.
Git repository: `C:/Users/Kyle/Documents/GitHub/Bind-a-Dragon`.
Existing feature branch: **Hakai**. No commits, pushes, merges, or edits to main.

## Authoring

The three files in `tools/` are Studio Command Bar world-authoring commands.
They are not runtime Scripts and must never be inserted as Script instances or
synced into the shared place. Each refuses any other place ID and refuses Play mode.

Run order, from the original test map:

1. `build-reference-hub.luau`
2. `finish-reference-hub.luau`
3. `review-reference-hub.luau`

The first two refuse duplicate execution. The review command is repeatable.
The map is organized under `Workspace.StarterMeadow.ReferenceRemodel`.

## Changes

- Six dragon lodges with slate roofs, elemental crests, straw nests, and colored
  resident dragons cloned from the existing placeholder art.
- Forest perimeter, flower gardens, shrubs, ferns, boulders, and limestone paths.
- Royal blue merchant pavilion, workshop canopy and chimney, banners and lanterns.
- Existing overlapping backdrop meshes moved to the skyline; ice and storm art
  reused from the existing Horizon library; floating island and eclipse corona.
- Existing river, bridges, plaza, shops, portals, six roost plots and spire retained.
- Daylight, atmosphere, water colors and an elevated editor overview.

The original 28 tagged gameplay objects were checked for retained tags, attributes,
and PrimaryParts after the main build. New lanterns use the existing Lantern tag.
No gameplay scripts or configs were changed. This is a stylized Roblox adaptation,
not a pixel-identical rendering of the reference illustration.

## Recovery and limits

Original test-place backup:
`C:/Users/Kyle/Documents/ChatGPT/Bind a Dragon Remodel/TEST-Kyle-before-remodel.rbxl`.

Studio reported API Services disabled during the user's Play session. DataStore
save testing remains unavailable until that setting is enabled in the TEST copy.
Existing day/night and atmosphere controllers can override editor lighting in Play.
The resident display dragons are static scenery. Player-owned dragons continue to
use the existing roost animation system.
