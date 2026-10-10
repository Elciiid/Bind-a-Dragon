"""Dumps posed bone data of a rig at given action frames (to check the game's clip playback numerically). Read-only.

    blender -b <rig_with_actions.blend> --python tools/dragon_rig/dump_pose.py -- <out.json> Dragon_Idle:0 Dragon_FlyLoop:18

Per frame and bone: rotation_euler (degrees, bone-local XYZ) and the posed head position in armature space; plus the
rest head positions.
"""

import json
import math
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
out = argv[0]
rig = bpy.data.objects["DragonRig"]
result = {"rest": {b.name: list(b.head_local) for b in rig.data.bones}, "poses": {}}
for spec in argv[1:]:
    action, frame = spec.split(":")
    rig.animation_data.action = bpy.data.actions[action]
    bpy.context.scene.frame_set(int(frame))
    bpy.context.view_layer.update()
    result["poses"][spec] = {pb.name: {"euler": [math.degrees(a) for a in pb.rotation_euler], "head": list(pb.head)}
                             for pb in rig.pose.bones}
with open(out, "w") as f:
    json.dump(result, f)
print("pose written")
