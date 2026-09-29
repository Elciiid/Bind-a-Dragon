# Dragon rig + animation set

One standard skeleton and one animation set for every dragon. Roblox plays an animation on any model with the same
bone names, so no dragon is animated by hand. Blender 5.2 in background mode (`D:/jonas/Blender/blender.exe -b ...`).

| File | What it does |
| --- | --- |
| `template.py` | The standard skeleton: bone names, parents, axis conventions, the canonical spread-wing rest pose. `-- <out.blend>` writes a reference armature. |
| `rerig.py` | Meshy GLB -> rigged `.blend` (+ optional FBX): the tail straightened onto the center line first (with the model's own skin; scale taken from the model as generated, so bodies keep their size and only the tail gets longer), export rules of `tools/glb_to_fbx.py`, landmarks from the model's UniRig skeleton, template bones fitted on them, automatic weights (max 4), wings swung into the canonical pose and baked as the rest pose. Writes `<name>_rig.json` (landmarks, report). |
| `animate.py` | Bakes the `Dragon_*` actions onto a rig (`--save`), writes the actions-only library (`--library`), one FBX per action (`--fbx-dir`) and `animations.json` (lengths, loops, FX markers). |
| `apply_actions.py` | Copies the actions from the library onto another rig, unchanged. |
| `preview.py` | Workbench stills / frames of a rig or an action (`--bones` draws the skeleton). |
| `make_gifs.py` | Side-by-side preview GIFs from `preview.py --all` frames (normal Python + Pillow). |
| `animations.json` | Action lengths, loop flags and FX marker times (seconds) for the game. |

New dragon:

```
blender -b --python tools/dragon_rig/rerig.py -- assets/Dragons/<Id>_<Stage>.glb assets/Dragons/blend/<Id>_<Stage>.blend --stage <Stage> --fbx assets/Dragons/fbx/rigged/<Id>_<Stage>.fbx
blender -b assets/Dragons/blend/<Id>_<Stage>.blend --python tools/dragon_rig/apply_actions.py -- assets/Dragons/blend/DragonAnimations.blend --save assets/Dragons/blend/<Id>_<Stage>.blend
```

Changing an animation: edit `animate.py`, rebake on Solflare with `--save ... --library assets/Dragons/blend/DragonAnimations.blend`,
then `apply_actions.py` on the other rigs. `.blend` files and previews stay out of Git (`assets/Dragons/blend/`,
`assets/Dragons/previews/`).

Actions (30 fps, in place; lengths and markers in `animations.json`):
- core: `Dragon_Idle` (4 s loop), `Dragon_TakeOff` (1.5 s), `Dragon_FlyLoop` (1.2 s loop), `Dragon_Glide` (3 s loop),
  `Dragon_Land` (1.5 s), `Dragon_Roar` (2 s), `Dragon_Reveal` (3 s, bind ceremony);
- roost / personality: `Dragon_Sleep` (5 s loop), `Dragon_HappyHop` (2 s), `Dragon_Sneeze` (1.5 s), `Dragon_Stretch`
  (3 s), `Dragon_Preen` (3 s), `Dragon_Shake` (1.5 s), `Dragon_TailFlick` (1 s), `Dragon_BarrelRoll` (2 s, in the air,
  ends on the FlyLoop's first frame);
- moments / battle: `Dragon_Evolve` (3 s), `Dragon_LevelUp` (1.5 s), `Dragon_Attack` (1 s), `Dragon_Hit` (0.6 s),
  `Dragon_Victory` (2 s), `Dragon_Defeat` (2 s, ends slumped).
Markers: `FX_Flap`, `FX_TakeOff`, `FX_Land`, `FX_Roar`, `FX_Burst`, `FX_Sneeze`, `FX_LevelUp`, `FX_Attack`, `FX_Hit`.
