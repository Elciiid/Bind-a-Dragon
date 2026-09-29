"""Render stills / preview frames of a rigged dragon .blend (Workbench, textured).

    blender -b <rig.blend> --python tools/dragon_rig/preview.py -- <out_prefix> [--views side,front,top,persp]
        [--action Dragon_Idle] [--frames 1,30,60 | --all [--step 2]] [--bones] [--size 900]

Writes <out_prefix>_<action>_<view>_f<frame>.png (action "rest" when none is given). --all renders every --step-th
frame of the action (for GIFs: tools/dragon_rig/make_gifs.py). --bones draws the skeleton as colored sticks
(left = green, right = red, center = yellow). --air drops the ground for flying actions. The camera frames the dragon's rest bounds with room for spread wings.
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out = argv[0]
opts = {"air": False, "views": "side,front,persp", "action": None, "frames": None, "all": False, "step": 1, "bones": False,
        "size": 900}
i = 1
while i < len(argv):
    k = argv[i]
    if k in ("--views", "--action", "--frames"):
        opts[k[2:]] = argv[i + 1]; i += 2
    elif k in ("--step", "--size"):
        opts[k[2:]] = int(argv[i + 1]); i += 2
    elif k in ("--all", "--bones", "--air"):
        opts[k[2:]] = True; i += 1
    else:
        raise SystemExit(f"unknown option {k}")

scene = bpy.context.scene
rig = bpy.data.objects["DragonRig"]
body = bpy.data.objects["Body"]
scene.render.fps = 30

try:
    scene.render.engine = "BLENDER_WORKBENCH"
except TypeError as e:
    print(e)
shading = scene.display.shading
shading.color_type = "TEXTURE"
shading.light = "STUDIO"
shading.show_backface_culling = False
scene.display.render_aa = "8"
scene.render.resolution_x = opts["size"]
scene.render.resolution_y = int(opts["size"] * 0.75)
world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
scene.world = world
world.color = (0.16, 0.14, 0.26)
scene.render.film_transparent = False

# ground grid line: a thin plane so height reads
if "PreviewGround" not in bpy.data.objects:
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, -0.02))
    g = bpy.context.active_object
    g.name = "PreviewGround"
    mat = bpy.data.materials.new("PreviewGround")
    mat.diffuse_color = (0.32, 0.36, 0.3, 1)
    g.data.materials.append(mat)
    g.color = (0.32, 0.36, 0.3, 1)

sticks = []
if opts["bones"]:
    shading.show_xray = True  # see the sticks through the body
    shading.xray_alpha = 0.55
    for b in rig.data.bones:
        if not b.use_deform:
            continue
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.12, radius2=0.03, depth=1.0)
        c = bpy.context.active_object
        c.name = "Stick_" + b.name
        mat = bpy.data.materials.new("Stick_" + b.name)
        col = (0.2, 0.95, 0.3, 1) if ("_L" in b.name or "FL" in b.name or "BL" in b.name) else \
            (0.95, 0.25, 0.25, 1) if ("_R" in b.name or "FR" in b.name or "BR" in b.name) else (1.0, 0.85, 0.2, 1)
        mat.diffuse_color = col
        c.data.materials.append(mat)
        c.show_in_front = True
        sticks.append((c, b.name))


def place_sticks():
    for c, name in sticks:
        pb = rig.pose.bones[name]
        m = rig.matrix_world @ pb.matrix
        head = m.translation
        direction = m.col[1].to_3d()
        length = pb.bone.length
        rot = Vector((0, 0, 1)).rotation_difference(direction.normalized()).to_matrix().to_4x4()
        c.matrix_world = Matrix.Translation(head + direction.normalized() * length * 0.5) @ rot @ \
            Matrix.Diagonal((1, 1, length, 1))


# --air: flying actions float above the ground
bpy.data.objects["PreviewGround"].location.z = -4.0 if opts["air"] else -0.02

# rest bounds -> camera framing
pts = [body.matrix_world @ v.co for v in body.data.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
center = (lo + hi) / 2
span = max(hi - lo) * 1.35

cam = bpy.data.objects.get("PreviewCam")
if cam is None:
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = span
views = {
    "side": Vector((1, 0, 0.08)),     # from the dragon's left
    "front": Vector((0, -1, 0.08)),
    "top": Vector((0, 0.001, 1)),
    "persp": Vector((0.8, -0.9, 0.55)),
    "back": Vector((-0.5, 1, 0.45)),
    "under": Vector((1, -0.25, -0.35)),  # low side view (legs in flight)
}

if opts["action"]:
    act = bpy.data.actions[opts["action"]]
    rig.animation_data_create()
    rig.animation_data.action = act
    if rig.animation_data.action_slot is None and act.slots:  # an action from another file: pick its slot
        rig.animation_data.action_slot = act.slots[0]
    start, end = int(act.frame_range[0]), int(act.frame_range[1])
    name = opts["action"]
else:
    start = end = 1
    name = "rest"
if opts["all"]:
    frames = list(range(start, end + 1, opts["step"]))
elif opts["frames"]:
    frames = [int(f) for f in opts["frames"].split(",")]
else:
    frames = [start]

os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
for view in opts["views"].split(","):
    d = views[view].normalized()
    bpy.data.objects["PreviewGround"].hide_render = view == "under"
    cam.location = center + d * 60
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y" if view != "top" else "Y").to_euler()
    for f in frames:
        scene.frame_set(f)
        place_sticks()
        scene.render.filepath = os.path.abspath(f"{out}_{name}_{view}_f{f:03d}.png")
        bpy.ops.render.render(write_still=True)
print("rendered", len(frames) * len(opts["views"].split(",")), "images")
