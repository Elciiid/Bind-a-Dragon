"""The standard dragon skeleton (one template for every species and stage).

Every dragon re-rigged with tools/dragon_rig/rerig.py gets exactly these bones, names, parents and axis conventions, so
one animation set (tools/dragon_rig/animate.py) plays on all of them (Roblox matches animation tracks by bone name).

Axes (Blender, before the FBX export): the dragon faces -Y, up is +Z, its LEFT side is +X (Blender's mirror
convention; "_L" / "FL" / "BL" bones are on +X). 1 unit = 1 stud after rerig.py scales it.

Bone axis conventions (set by rerig.py after fitting, see `roll_reference`):
  * Body bones (Root, Spine, Neck, Head, Jaw, Tail, Legs): local X = world +X, so a rotation about local X is always a
    pitch in the side view with one sign for every dragon: +X = "nose-down" sense (head/neck bones tip down, tail bones
    tip up, legs swing back, Root pitches the whole body nose-down). Local Z rotation = yaw: +Z moves the bone's tip
    toward the dragon's right (-X).
  * Wing bones: local Y points out along the wing, local Z up. +X = tip up (flap up) on BOTH sides. Local Z (sweep)
    and local Y (twist) are mirrored: the animations use +Z on the left = -Z on the right for the same motion
    (Blender's X-mirror rule: mirrored pose = (x, -y, -z)).
  * The rest pose of the wings is standardized ("canonical spread", CANONICAL_WING below): rerig.py swings each fitted
    wing into it and bakes that as the rest pose, so a flap is the same motion on every dragon whatever pose the
    model was generated in.

Run standalone to write a reference armature (a generic 15-stud dragon, no mesh):
    blender -b --python tools/dragon_rig/template.py -- <out.blend>
"""

import math
import sys

# name -> (parent, chain, deform). Order = parents first.
BONES = [
    ("Root", None, "root"),
    ("Spine1", "Root", "spine"), ("Spine2", "Spine1", "spine"), ("Spine3", "Spine2", "spine"),
    ("Neck1", "Spine3", "neck"), ("Neck2", "Neck1", "neck"), ("Neck3", "Neck2", "neck"),
    ("Head", "Neck3", "head"), ("Jaw", "Head", "jaw"),
    ("Tail1", "Root", "tail"), ("Tail2", "Tail1", "tail"), ("Tail3", "Tail2", "tail"),
    ("Tail4", "Tail3", "tail"), ("Tail5", "Tail4", "tail"), ("Tail6", "Tail5", "tail"),
]
for side in ("L", "R"):
    BONES += [
        (f"Wing_{side}_Upper", "Spine3", f"wing_{side}"), (f"Wing_{side}_Fore", f"Wing_{side}_Upper", f"wing_{side}"),
        (f"Wing_{side}_Hand", f"Wing_{side}_Fore", f"wing_{side}"), (f"Wing_{side}_Tip", f"Wing_{side}_Hand", f"wing_{side}"),
    ]
for leg, parent in (("FL", "Spine3"), ("FR", "Spine3"), ("BL", "Root"), ("BR", "Root")):
    BONES += [
        (f"Leg_{leg}_Upper", parent, f"leg_{leg}"), (f"Leg_{leg}_Lower", f"Leg_{leg}_Upper", f"leg_{leg}"),
        (f"Leg_{leg}_Foot", f"Leg_{leg}_Lower", f"leg_{leg}"),
    ]

PARENT = {name: parent for name, parent, _ in BONES}
CHAINS = {}
for name, _, chain in BONES:
    CHAINS.setdefault(chain, []).append(name)

# Chains whose first bone attaches to its parent's tail (connected); the rest float (wings, legs, tail, Root).
CONNECTED_TO_PARENT = {"Spine1": False, "Neck1": True}

# Canonical wing rest directions (left wing; the right wing mirrors X). +Y = backward, +Z = up. A spread wing with a
# little dihedral and the tip swept back. Sized per dragon (bone lengths come from the model).
CANONICAL_WING = {
    "Upper": (1.0, 0.05, 0.28),
    "Fore": (1.0, 0.15, 0.08),
    "Hand": (1.0, 0.35, -0.02),
    "Tip": (1.0, 0.75, -0.08),
}

# Stage body lengths in studs (nose to tail tip), same as tools/glb_to_fbx.py.
STAGE_LENGTH = {"Hatchling": 6.0, "Drake": 8.5, "Dragon": 11.0, "Elder": 15.0}
MAX_INFLUENCES = 4  # Roblox skinning limit


def side_of(name):
    """+1 for left-side bones (+X), -1 for right-side, 0 for the centerline."""
    if name.startswith("Wing_L") or name.startswith("Leg_FL") or name.startswith("Leg_BL"):
        return 1
    if name.startswith("Wing_R") or name.startswith("Leg_FR") or name.startswith("Leg_BR"):
        return -1
    return 0


def is_wing(name):
    return name.startswith("Wing_")


def roll_reference(name, direction):
    """The world vector the bone's local Z axis is aligned to (see the conventions above)."""
    from mathutils import Vector
    d = Vector(direction).normalized()
    if is_wing(name):
        up = Vector((0, 0, 1))
        if abs(d.dot(up)) > 0.9:  # a wing bone pointing straight up/down: use backward
            return Vector((0, 1, 0))
        return up
    x = Vector((1, 0, 0))
    if abs(d.dot(x)) > 0.85:  # e.g. a tail tip curling sideways: fall back to up
        return Vector((0, 0, 1))
    return x.cross(d).normalized()  # local X = world +X  =>  Z = X x Y


def generic_points():
    """Joint positions of a generic 15-stud dragon (used for the standalone reference armature)."""
    p = {}
    p["Root"] = ((0, 1.5, 4.2), (0, 1.5, 5.0))
    spine = [(0, 1.5, 4.2), (0, 0.2, 4.4), (0, -1.1, 4.6), (0, -2.3, 4.8)]
    neck = [spine[-1], (0, -3.1, 5.6), (0, -3.7, 6.4), (0, -4.2, 7.0)]
    tail = [(0, 2.4, 4.0), (0, 3.6, 3.6), (0, 4.8, 3.3), (0, 5.9, 3.1), (0, 6.9, 3.0), (0, 7.8, 2.9), (0, 8.6, 2.9)]
    for i in range(3):
        p[f"Spine{i + 1}"] = (spine[i], spine[i + 1])
        p[f"Neck{i + 1}"] = (neck[i], neck[i + 1])
    p["Head"] = (neck[-1], (0, -5.8, 6.8))
    p["Jaw"] = ((0, -4.6, 6.4), (0, -5.6, 6.1))
    for i in range(6):
        p[f"Tail{i + 1}"] = (tail[i], tail[i + 1])
    for side, sx in (("L", 1), ("R", -1)):
        start = (0.7 * sx, -1.6, 5.3)
        lengths = {"Upper": 2.0, "Fore": 2.4, "Hand": 1.8, "Tip": 1.4}
        cur = start
        for seg in ("Upper", "Fore", "Hand", "Tip"):
            dx, dy, dz = CANONICAL_WING[seg]
            n = math.sqrt(dx * dx + dy * dy + dz * dz)
            end = (cur[0] + sx * dx / n * lengths[seg], cur[1] + dy / n * lengths[seg], cur[2] + dz / n * lengths[seg])
            p[f"Wing_{side}_{seg}"] = (cur, end)
            cur = end
    for leg, (x, y) in (("FL", (1.0, -1.9)), ("FR", (-1.0, -1.9)), ("BL", (1.0, 1.4)), ("BR", (-1.0, 1.4))):
        hip, knee, ankle, toe = (x, y, 4.0), (x * 1.1, y - 0.3, 2.2), (x * 1.1, y + 0.2, 0.6), (x * 1.1, y - 0.6, 0.0)
        p[f"Leg_{leg}_Upper"] = (hip, knee)
        p[f"Leg_{leg}_Lower"] = (knee, ankle)
        p[f"Leg_{leg}_Foot"] = (ankle, toe)
    return p


def build_armature(points, name="DragonRig", deform_skip=()):
    """Creates the armature object from {bone: (head, tail)} in world space. Bones in deform_skip don't deform."""
    import bpy
    from mathutils import Vector
    data = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.view_layer.objects:
        o.select_set(o == obj)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = data.edit_bones
    for bone, parent, _ in BONES:
        b = eb.new(bone)
        head, tail = points[bone]
        b.head, b.tail = Vector(head), Vector(tail)
        b.use_deform = bone not in deform_skip
    for bone, parent, _ in BONES:
        if parent:
            b = eb[bone]
            b.parent = eb[parent]
            connect = CONNECTED_TO_PARENT.get(bone)
            if connect is None:
                connect = PARENT.get(bone) is not None and CHAINS_OF[bone] == CHAINS_OF[parent]
            if connect and (b.head - eb[parent].tail).length < 1e-4:
                b.use_connect = True
    set_rolls(eb)
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in obj.pose.bones:
        pb.rotation_mode = "XYZ"  # every animation keys Euler XYZ rotations
    obj.data.display_type = "STICK"
    obj.show_in_front = True
    return obj


def set_rolls(edit_bones):
    for bone, _, _ in BONES:
        b = edit_bones.get(bone)
        if b is None:
            continue
        b.align_roll(roll_reference(bone, b.tail - b.head))


CHAINS_OF = {name: chain for name, _, chain in BONES}


if __name__ == "__main__":
    import bpy
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not argv:
        raise SystemExit("usage: blender -b --python tools/dragon_rig/template.py -- <out.blend>")
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    build_armature(generic_points(), "DragonTemplate")
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
    print("wrote", argv[0])
