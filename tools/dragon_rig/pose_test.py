"""Renders static wing-pose variants on a rig (art check only). Angles are degrees in the template conventions
(animate.py: per wing segment flap + = tip up, sweep + = tip back, twist + = leading edge up; the right wing mirrored).

    blender -b <rig.blend> --python tools/dragon_rig/pose_test.py -- <variants.json> <out_prefix> [--views persp,side,front,top]

variants.json: {"Name": {"Upper": [flap, sweep, twist], "Fore": [...], "Hand": [...], "Tip": [...]}, ...}
Writes <out_prefix>_<Name>_<view>.png.
"""

import json
import os
import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
variants = json.load(open(argv[0]))
prefix = os.path.abspath(argv[1])  # absolute: Blender resolves a relative render path against the drive root
views = argv[argv.index("--views") + 1].split(",") if "--views" in argv else ["persp", "side", "front", "top"]

scene = bpy.context.scene
rig = bpy.data.objects["DragonRig"]
body = bpy.data.objects["Body"]
if rig.animation_data:
    rig.animation_data.action = None
scene.render.engine = "BLENDER_WORKBENCH"
shading = scene.display.shading
shading.color_type = "TEXTURE"
shading.light = "STUDIO"
scene.render.resolution_x, scene.render.resolution_y = 520, 390
world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
scene.world = world
world.color = (0.16, 0.14, 0.26)
bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, -0.02))
cam_data = bpy.data.cameras.new("PoseCam")
cam = bpy.data.objects.new("PoseCam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
for pb in rig.pose.bones:
    pb.rotation_mode = "XYZ"

pts = [body.matrix_world @ v.co for v in body.data.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
center = (lo + hi) / 2
size = max(hi.y - lo.y, hi.z - lo.z, 1.0)
VIEW = {  # direction from the dragon to the camera (the dragon faces -Y, its left is +X)
    "persp": Vector((-0.9, -1.1, 0.75)), "side": Vector((-1, 0, 0.08)), "front": Vector((0, -1, 0.1)),
    "top": Vector((0, 0.001, 1)), "back": Vector((0.7, 1.0, 0.6)),
}

for name, segs in variants.items():
    for pb in rig.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    for side, s in (("L", 1), ("R", -1)):
        for seg, (flap, sweep, twist) in segs.items():
            pb = rig.pose.bones.get(f"Wing_{side}_{seg}")
            if pb:
                pb.rotation_euler = (math.radians(flap), math.radians(twist * s), math.radians(sweep * s))
    bpy.context.view_layer.update()
    for view in views:
        d = VIEW[view].normalized()
        cam.location = center + d * size * 1.9
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        cam_data.lens = 50
        scene.render.filepath = f"{prefix}_{name}_{view}.png"
        bpy.ops.render.render(write_still=True)
print("poses rendered", len(variants))
