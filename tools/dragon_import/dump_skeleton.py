"""Prints a source GLB's skeleton (bone tree with head positions) to diagnose re-rig failures. Read-only.

    blender -b --python tools/dragon_import/dump_skeleton.py -- <in.glb>
"""

import sys

import bpy

src = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
mesh = [o for o in bpy.data.objects if o.type == "MESH"]
pts = [m.matrix_world @ v.co for m in mesh for v in m.data.vertices]
print("MESH bounds y", round(min(p.y for p in pts), 3), round(max(p.y for p in pts), 3),
      "z", round(min(p.z for p in pts), 3), round(max(p.z for p in pts), 3),
      "x", round(min(p.x for p in pts), 3), round(max(p.x for p in pts), 3))
mw = arm.matrix_world


def walk(b, depth):
    h, t = mw @ b.head_local, mw @ b.tail_local
    print("BONE", "  " * depth + b.name, f"head({h.x:.2f},{h.y:.2f},{h.z:.2f}) tail({t.x:.2f},{t.y:.2f},{t.z:.2f})", len(b.children))
    for c in b.children:
        walk(c, depth + 1)


for b in arm.data.bones:
    if b.parent is None:
        walk(b, 0)
