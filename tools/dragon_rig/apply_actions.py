"""Copy the Dragon_* actions from a library .blend onto another re-rigged dragon, unchanged.

    blender -b <target_rig.blend> --python tools/dragon_rig/apply_actions.py -- <library.blend> [--save <out.blend>]

The library is any .blend the animations were baked into (e.g. assets/Dragons/blend/DragonAnimations.blend, written by
animate.py --library). Nothing is re-baked or retargeted: the actions only name template bones, so they play as-is on
every rig made by rerig.py. Prints any action channel whose bone the target rig lacks (there should be none).
"""

import os
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
library = os.path.abspath(argv[0])
save = os.path.abspath(argv[argv.index("--save") + 1]) if "--save" in argv else None

rig = bpy.data.objects["DragonRig"]
for pb in rig.pose.bones:
    pb.rotation_mode = "XYZ"  # the actions key Euler XYZ rotations (template convention)
for old in [a for a in bpy.data.actions if a.name.startswith("Dragon_")]:  # replace an earlier copy
    bpy.data.actions.remove(old)
with bpy.data.libraries.load(library, link=False) as (src, dst):
    dst.actions = [a for a in src.actions if a.startswith("Dragon_")]
missing = set()
for act in dst.actions:
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    for layer in act.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    if fc.data_path.startswith('pose.bones["'):
                        bone = fc.data_path.split('"')[1]
                        if bone not in rig.pose.bones:
                            missing.add(bone)
print("applied", [a.name for a in dst.actions])
print("channels for bones this rig lacks:", sorted(missing) or "none")
rig.animation_data.action = dst.actions[0]
if rig.animation_data.action_slot is None and dst.actions[0].slots:
    rig.animation_data.action_slot = dst.actions[0].slots[0]
if save:
    bpy.ops.wm.save_as_mainfile(filepath=save)
