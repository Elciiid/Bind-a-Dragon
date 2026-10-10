"""Read-only survey of every source GLB: which way the mesh faces and how its UniRig skeleton is built.

    blender -b --python tools/dragon_import/survey.py -- <out.json> <glb> [<glb> ...]

Per file: mesh bounds; HEIGHT test = the highest mesh point in the front 30 % (-Y) vs the back 30 % (+Y) of the
length (the head end is the higher one for a standing dragon); the first bone with 3+ children (UniRig's first hub)
and whether it sits in the front or the back half; the number of hubs.
"""

import json
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
out_path, files = argv[0], argv[1:]
rows = []
for path in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        bpy.ops.import_scene.gltf(filepath=path)
    except Exception as e:  # noqa: BLE001
        rows.append({"file": path, "error": str(e)})
        continue
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and arms
              and (o.parent == arms[0] or any(m.type == "ARMATURE" and m.object == arms[0] for m in o.modifiers))]
    pts = [m.matrix_world @ v.co for m in meshes for v in m.data.vertices]
    if not arms or not pts:
        rows.append({"file": path, "error": "no armature or skinned mesh"})
        continue
    ylo, yhi = min(p.y for p in pts), max(p.y for p in pts)
    zlo = min(p.z for p in pts)
    span = yhi - ylo
    front = max((p.z for p in pts if p.y < ylo + 0.3 * span), default=zlo) - zlo
    back = max((p.z for p in pts if p.y > yhi - 0.3 * span), default=zlo) - zlo
    arm = arms[0]
    mw = arm.matrix_world
    hubs = [b for b in arm.data.bones if len(b.children) >= 3]
    first = None
    b = next((x for x in arm.data.bones if x.parent is None), None)
    while b is not None and len(b.children) < 3:
        b = b.children[0] if b.children else None
    first = b
    mid = (ylo + yhi) / 2
    rows.append({
        "file": path.replace("\\", "/").split("/")[-1],
        "length": round(span, 3),
        "front_height": round(front, 3), "back_height": round(back, 3),
        "mesh_faces": "-Y" if front >= back else "+Y",
        "first_hub": first.name if first else None,
        "first_hub_half": (("front" if (mw @ first.head_local).y < mid else "back") if first else None),
        "hubs": len(hubs),
        "bones": len(arm.data.bones),
    })
with open(out_path, "w") as f:
    json.dump(rows, f, indent=1)
print("survey written", len(rows))
