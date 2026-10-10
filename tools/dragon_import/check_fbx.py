"""Measures an exported dragon FBX (numbers only; an art check, not a game test).

    blender -b --python tools/dragon_import/check_fbx.py -- <in.fbx> <out.json>

Imports the FBX into an empty scene and writes: bone names vs the standard skeleton (tools/dragon_rig/template.py),
deform bones without weights, triangles, max bone influences per vertex, textures (name, size), materials, bounds in
studs (x = width, y = nose to tail, z = height), the lowest point (feet at 0), which way the head points (the Head bone
must be at the -Y end, which Roblox's importer turns into the model's forward -Z) and the object names.
"""

import json
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "dragon_rig"))
import template as T  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)

arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
r = {"file": os.path.basename(src), "objects": sorted(o.name for o in bpy.data.objects)}
r["armatures"] = len(arms)
r["meshes"] = [m.name for m in meshes]
standard = [name for name, _, _ in T.BONES]
if arms:
    arm = arms[0]
    names = [b.name for b in arm.data.bones]
    r["bones"] = len(names)
    r["bones_not_standard"] = sorted(set(names) - set(standard))
    r["standard_bones_missing"] = [n for n in standard if n not in names]
    bad_parent = []
    for b in arm.data.bones:
        want = T.PARENT.get(b.name)
        have = b.parent.name if b.parent else None
        if b.name in T.PARENT and want != have and not (want is None and have is None):
            bad_parent.append(f"{b.name}: parent {have}, want {want}")
    r["wrong_parents"] = bad_parent
tris, max_inf, verts = 0, 0, 0
weighted = {}
pts = []
for m in meshes:
    tris += sum(len(p.vertices) - 2 for p in m.data.polygons)
    verts += len(m.data.vertices)
    mw = m.matrix_world
    for v in m.data.vertices:
        pts.append(mw @ v.co)
        n = sum(1 for g in v.groups if g.weight > 0)
        max_inf = max(max_inf, n)
        for g in v.groups:
            if g.weight > 0.05:
                name = m.vertex_groups[g.group].name
                weighted[name] = weighted.get(name, 0) + 1
r["triangles"] = tris
r["vertices"] = verts
r["max_influences"] = max_inf
if arms:
    r["bones_without_weights"] = [b.name for b in arms[0].data.bones if not weighted.get(b.name)]
r["textures"] = [{"name": i.name, "size": list(i.size)} for i in bpy.data.images]
r["materials"] = [m.name for m in bpy.data.materials]
if pts:
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    size = hi - lo
    r["size_studs"] = [round(size.x, 2), round(size.y, 2), round(size.z, 2)]
    r["lowest_z"] = round(lo.z, 3)
    r["center_xy"] = [round((lo.x + hi.x) / 2, 3), round((lo.y + hi.y) / 2, 3)]
if arms and "Head" in arms[0].data.bones and "Tail6" in arms[0].data.bones:
    a = arms[0]
    head = a.matrix_world @ a.data.bones["Head"].tail_local
    tail = a.matrix_world @ a.data.bones["Tail6"].tail_local
    r["head_y"] = round(head.y, 2)
    r["tail_tip_y"] = round(tail.y, 2)
    r["faces_minus_y"] = head.y < tail.y
with open(out, "w") as f:
    json.dump(r, f, indent=1)
print("check written", out)
