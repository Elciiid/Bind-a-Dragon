"""Writes each bone's rest frame (armature space: head position + 3x3 rotation, columns = the bone's X, Y, Z axes)
of a rig .blend to JSON, to compare with the imported Roblox bones. Read-only.

    blender -b <rig.blend> --python tools/dragon_rig/dump_rest.py -- <out.json>
"""

import json
import sys

import bpy

out = sys.argv[sys.argv.index("--") + 1]
rig = bpy.data.objects["DragonRig"]
data = {}
for b in rig.data.bones:
    m = b.matrix_local
    data[b.name] = {"head": [round(c, 4) for c in b.head_local],
                    "rot": [[round(m[r][c], 5) for c in range(3)] for r in range(3)]}
with open(out, "w") as f:
    json.dump(data, f, indent=1)
print("rest written", len(data))
