"""Re-rig a Meshy dragon (GLB with a UniRig skeleton) onto the standard dragon skeleton (template.py).

Run with Blender in background mode:
    blender -b --python tools/dragon_rig/rerig.py -- <input.glb> <output.blend> [--stage Elder] [--fbx <out.fbx>]
        [--tris 10000] [--texture 1024] [--flip] [--landmarks <overrides.json>] [--no-canonical]

Steps:
  1. import the GLB, delete helper meshes, apply transforms;
  2. same export rules as tools/glb_to_fbx.py: decimate to ~--tris triangles, keep only the base-color texture at
     --texture px, facing -Y (--flip turns 180 degrees), scaled to the stage length in studs, feet at Z = 0, centered;
  3. find landmarks from the model's own UniRig skeleton (it is already fitted to the mesh; only its topology and
     joint positions are used): the pelvis hub (spine, tail, back legs) and the chest hub (neck, wings, front legs);
     the snout and jaw come from the mesh itself. A --landmarks JSON can override any chain by hand
     ({"wing_L": [[x, y, z], ...], ...} in output studs);
  4. builds the template bones along those chains (joints placed on the source joints with the biggest bends, so the
     elbow / wrist / knee land on real joints), bone axes per template.py;
  5. binds with automatic weights, fixes any vertex the heat solver missed (nearest bone), max 4 weights, normalized;
  6. swings each wing into the canonical spread pose (template.CANONICAL_WING) and bakes it as the rest pose, so the
     same animations look the same on every dragon (--no-canonical skips this);
  7. saves the .blend (armature "DragonRig", mesh "Body") and optionally a rigged FBX (no animation), and writes
     <output>.json with the landmarks and a report.
Missing parts (e.g. a wyvern has no front legs) still get their bones, marked non-deform, so every rig has every
bone name; they don't export (the FBX keeps deform bones only).
"""

import json
import math
import os
import sys
import time

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import template as T  # noqa: E402

TIP_FRACTION = 0.02  # source segments shorter than this share of the body length are merged away


# ---------------------------------------------------------------------------------------------------------------
# CLI

def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 2:
        raise SystemExit(__doc__)
    opts = {"input": argv[0], "output": argv[1], "stage": "Elder", "fbx": None, "tris": 10000, "texture": 1024,
            "flip": False, "landmarks": None, "canonical": True}
    i = 2
    while i < len(argv):
        key = argv[i]
        if key in ("--stage", "--fbx", "--landmarks"):
            opts[key[2:]] = argv[i + 1]; i += 2
        elif key == "--tris":
            opts["tris"] = min(int(argv[i + 1]), 20000); i += 2
        elif key == "--texture":
            opts["texture"] = int(argv[i + 1]); i += 2
        elif key == "--flip":
            opts["flip"] = True; i += 1
        elif key == "--no-canonical":
            opts["canonical"] = False; i += 1
        else:
            raise SystemExit(f"unknown option {key}")
    if opts["stage"] not in T.STAGE_LENGTH:
        raise SystemExit(f"--stage must be one of {', '.join(T.STAGE_LENGTH)}")
    return opts


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


# ---------------------------------------------------------------------------------------------------------------
# Polylines

def length(pts):
    return sum((pts[i + 1] - pts[i]).length for i in range(len(pts) - 1))


def clean(pts, min_seg):
    """Drops points closer than min_seg to the previous kept point; the last point always stays (it replaces a kept
    point that is too close to it)."""
    out = [pts[0]]
    for p in pts[1:-1]:
        if (p - out[-1]).length >= min_seg:
            out.append(p)
    if len(out) > 1 and (pts[-1] - out[-1]).length < min_seg:
        out[-1] = pts[-1]
    else:
        out.append(pts[-1])
    return out


def resample(pts, n):
    """n equal-length segments along the polyline -> n + 1 points."""
    total = length(pts)
    out = [pts[0].copy()]
    target = total / n
    acc = 0.0
    seg = 0
    pos = pts[0].copy()
    for k in range(1, n):
        want = target * k
        while seg < len(pts) - 1:
            seg_len = (pts[seg + 1] - pts[seg]).length
            if acc + seg_len >= want:
                t = (want - acc) / max(seg_len, 1e-9)
                out.append(pts[seg].lerp(pts[seg + 1], t))
                break
            acc += seg_len
            seg += 1
    out.append(pts[-1].copy())
    return out


def bend(pts, i):
    a, b = pts[i] - pts[i - 1], pts[i + 1] - pts[i]
    if a.length < 1e-9 or b.length < 1e-9:
        return 0.0
    return a.angle(b)


def pick_joints(pts, n):
    """n segments whose inner joints sit on the source joints with the biggest bends (anatomical joints); segments
    that would be tiny are avoided; falls back to equal resampling when there are too few joints."""
    if len(pts) - 1 < n:
        return resample(pts, n)
    total = length(pts)
    inner = list(range(1, len(pts) - 1))
    ranked = sorted(inner, key=lambda i: -bend(pts, i))
    chosen = []
    for i in ranked:
        cand = sorted(chosen + [i])
        full = [0] + cand + [len(pts) - 1]
        if all(length(pts[full[k]:full[k + 1] + 1]) > total * 0.08 for k in range(len(full) - 1)):
            chosen = cand
        if len(chosen) == n - 1:
            break
    if len(chosen) < n - 1:
        return resample(pts, n)
    return [pts[0]] + [pts[i] for i in chosen] + [pts[-1]]


# ---------------------------------------------------------------------------------------------------------------
# Source skeleton analysis

class Src:
    def __init__(self, arm):
        self.arm = arm
        self.bones = arm.data.bones
        mw = arm.matrix_world
        self.head = {b.name: mw @ b.head_local for b in self.bones}
        self.tail = {b.name: mw @ b.tail_local for b in self.bones}

    def subtree(self, b):
        out = [b]
        for c in b.children:
            out += self.subtree(c)
        return out

    def points(self, b):
        pts = []
        for x in self.subtree(b):
            pts += [self.head[x.name], self.tail[x.name]]
        return pts

    def path(self, b, score):
        """Follows children from b; at each branch takes the child whose subtree scores highest. Returns bones."""
        out = [b]
        while b.children:
            if len(b.children) == 1:
                b = b.children[0]
            else:
                b = max(b.children, key=lambda c: max(score(p) for p in self.points(c)))
            out.append(b)
        return out

    def polyline(self, bones_):
        return [self.head[b.name] for b in bones_] + [self.tail[bones_[-1].name]]


def find_landmarks(arm, mesh, body_len, height):
    s = Src(arm)
    roots = [b for b in s.bones if b.parent is None]
    if len(roots) != 1:
        raise SystemExit(f"expected one root bone, found {len(roots)}")
    b = roots[0]
    while len(b.children) < 3:
        if not b.children:
            raise SystemExit("no pelvis hub (a bone with 3+ children) found")
        b = b.children[0]
    pelvis = b
    cx_pelvis = s.head[pelvis.name].x
    ground = min(p.z for p in s.points(pelvis))

    def has_hub(c):
        return any(len(x.children) >= 3 for x in s.subtree(c))

    spine_child = max((c for c in pelvis.children if has_hub(c)), key=lambda c: len(s.subtree(c)), default=None)
    if spine_child is None:
        raise SystemExit("no chest hub found under the pelvis")
    chest = spine_child
    spine_bones = [chest]
    while len(chest.children) < 3:
        chest = chest.children[0]
        spine_bones.append(chest)
    lm = {"pelvis": s.head[pelvis.name], "report": {"pelvis_hub": pelvis.name, "chest_hub": chest.name}}
    lm["spine"] = [s.head[pelvis.name]] + [s.head[x.name] for x in spine_bones] + [s.tail[chest.name]]

    # pelvis children: the tail starts on the centerline (it may touch the ground too), the back legs to the sides
    others = [c for c in pelvis.children if c != spine_child]
    tails = [c for c in others if abs(s.head[c.name].x - cx_pelvis) < 0.03 * body_len]
    legs = [c for c in others if c not in tails and min(p.z for p in s.points(c)) < ground + 0.15 * height]
    if not tails:
        raise SystemExit("no tail found")
    tail = max(tails, key=lambda c: max(p.y for p in s.points(c)))
    tail_path = s.path(tail, lambda p: (p - s.head[tail.name]).length)
    lm["tail"] = s.polyline(tail_path)
    lm["report"]["tail"] = [x.name for x in tail_path]
    for c in legs:
        side = "L" if s.head[c.name].x > cx_pelvis else "R"
        path = s.path(c, lambda p: -p.z)
        lm[f"leg_B{side}"] = s.polyline(path)
        lm["report"][f"leg_B{side}"] = [x.name for x in path]

    # chest children: the neck is the centered one with the biggest subtree; per side, wing = the higher reaching one
    cx = s.head[chest.name].x
    centered = [c for c in chest.children if abs(s.head[c.name].x - cx) < 0.03 * body_len]
    neck = max(centered, key=lambda c: len(s.subtree(c)))
    neck_bones = [neck]
    while len(neck_bones[-1].children) == 1:
        neck_bones.append(neck_bones[-1].children[0])
    head_hub = neck_bones[-1]
    lm["head_base"] = s.head[head_hub.name]
    lm["neck"] = [s.tail[chest.name]] + [s.head[x.name] for x in neck_bones]
    lm["report"]["neck"] = [x.name for x in neck_bones]
    # a source jaw: a centered child chain of the head hub pointing forward and down from the head base
    for side_sign, side in ((1, "L"), (-1, "R")):
        cands = [c for c in chest.children if c not in centered and (s.head[c.name].x - cx) * side_sign > 0]
        wing, leg = None, None
        if len(cands) >= 2:
            cands.sort(key=lambda c: -max(p.z for p in s.points(c)))
            wing, leg = cands[0], cands[1]
        elif len(cands) == 1:
            c = cands[0]
            reach = max(abs(p.x - cx) for p in s.points(c))
            if reach > 0.3 * body_len:
                wing = c
            else:
                leg = c
        if wing:
            shoulder = s.head[wing.name]
            path = s.path(wing, lambda p: abs(p.x - cx))
            pts = s.polyline(path)
            far = max(range(len(pts)), key=lambda i: (pts[i] - shoulder).length)
            lm[f"wing_{side}"] = pts[:far + 1]
            lm["report"][f"wing_{side}"] = [x.name for x in path]
        if leg:
            path = s.path(leg, lambda p: -p.z)
            lm[f"leg_F{side}"] = s.polyline(path)
            lm["report"][f"leg_F{side}"] = [x.name for x in path]
    return lm


def head_from_mesh(mesh, head_base, body_len):
    """Snout tip and jaw line from the mesh: vertices in front of the head base, near the centerline."""
    pts = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
    region = [p for p in pts if p.y < head_base.y and abs(p.x - head_base.x) < 0.12 * body_len
              and p.z > head_base.z - 0.12 * body_len and (p - head_base).length < 0.3 * body_len]
    if len(region) < 20:
        tip = head_base + Vector((0, -0.08 * body_len, 0))
        return tip, head_base + Vector((0, -0.02 * body_len, -0.03 * body_len)), tip + Vector((0, 0, -0.03 * body_len))
    snout = min(region, key=lambda p: p.y)
    head_len = head_base.y - snout.y
    front = [p for p in region if p.y < snout.y + 0.35 * head_len]
    mid_z = sum(p.z for p in front) / len(front)
    low_z = min(p.z for p in region if p.y < head_base.y - 0.3 * head_len)
    tip = Vector((head_base.x, snout.y, mid_z))
    hinge = head_base.lerp(tip, 0.3)
    hinge.z = (head_base.z + low_z) * 0.5
    jaw_tip = head_base.lerp(tip, 0.88)
    jaw_tip.z = low_z + 0.25 * (mid_z - low_z)
    return tip, hinge, jaw_tip


# ---------------------------------------------------------------------------------------------------------------
# Fit the template

def fit_points(lm, body_len, head_tip, jaw_hinge, jaw_tip, height):
    """{bone: (head, tail)} for every template bone. Returns (points, missing chains)."""
    min_seg = body_len * TIP_FRACTION
    p = {}
    missing = []
    spine = resample(clean(lm["spine"], min_seg), 3)
    for i in range(3):
        p[f"Spine{i + 1}"] = (spine[i], spine[i + 1])
    root = spine[0]
    p["Root"] = (root, root + Vector((0, 0, 0.06 * body_len)))
    neck = resample(clean(lm["neck"] + [lm["head_base"]], min_seg), 3)
    neck[0] = spine[-1]
    for i in range(3):
        p[f"Neck{i + 1}"] = (neck[i], neck[i + 1])
    p["Head"] = (neck[-1], head_tip)
    p["Jaw"] = (jaw_hinge, jaw_tip)
    tail = resample(clean(lm["tail"], min_seg), 6)
    for i in range(6):
        p[f"Tail{i + 1}"] = (tail[i], tail[i + 1])
    for side in ("L", "R"):
        sx = 1 if side == "L" else -1
        key = f"wing_{side}"
        if key in lm:
            w = pick_joints(clean(lm[key], min_seg), 4)
        else:
            missing.append(key)
            start = spine[-1] + Vector((0.05 * body_len * sx, 0, 0.03 * body_len))
            w = [start + Vector((0.06 * body_len * sx * k, 0, 0)) for k in range(5)]
        for i, seg in enumerate(("Upper", "Fore", "Hand", "Tip")):
            p[f"Wing_{side}_{seg}"] = (w[i], w[i + 1])
    for leg in ("FL", "FR", "BL", "BR"):
        key = f"leg_{leg}"
        sx = 1 if leg[1] == "L" else -1
        if key in lm:
            pts = clean(lm[key], min_seg)
            # the foot starts at the first joint close to the ground; the knee is the biggest bend above it
            foot_i = next((i for i in range(1, len(pts) - 1) if pts[i].z < 0.12 * height), len(pts) - 2)
            upper = pick_joints(pts[:foot_i + 1], 2) if foot_i >= 1 else resample(pts, 3)[:3]
            j = [upper[0], upper[1], pts[foot_i], pts[-1]]
            if (j[3] - j[2]).length < min_seg:
                j = resample(pts, 3)
        else:
            missing.append(key)
            anchor = spine[-1] if leg[0] == "F" else spine[0]
            hip = anchor + Vector((0.07 * body_len * sx, 0, -0.04 * body_len))
            j = [hip + Vector((0, 0, -0.03 * body_len * k)) for k in range(4)]
        for i, seg in enumerate(("Upper", "Lower", "Foot")):
            p[f"Leg_{leg}_{seg}"] = (j[i], j[i + 1])
    return p, missing


# ---------------------------------------------------------------------------------------------------------------
# Weights

def bind(mesh, rig):
    select_only(mesh)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    deform = {b.name for b in rig.data.bones if b.use_deform}
    # vertices the heat solver missed: give them the nearest deform bone
    segs = []
    for b in rig.data.bones:
        if b.use_deform:
            segs.append((b.name, rig.matrix_world @ b.head_local, rig.matrix_world @ b.tail_local))
    fixed = 0
    groups = {g.name: g for g in mesh.vertex_groups}
    for v in mesh.data.vertices:
        total = sum(g.weight for g in v.groups if mesh.vertex_groups[g.group].name in deform)
        if total > 1e-4:
            continue
        co = mesh.matrix_world @ v.co
        best, best_d = None, 1e9
        for name, h, t in segs:
            ab = t - h
            k = max(0.0, min(1.0, (co - h).dot(ab) / max(ab.length_squared, 1e-12)))
            d = (co - (h + ab * k)).length
            if d < best_d:
                best, best_d = name, d
        g = groups.get(best) or mesh.vertex_groups.new(name=best)
        groups[best] = g
        g.add([v.index], 1.0, "REPLACE")
        fixed += 1
    select_only(mesh)
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=0.01)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=T.MAX_INFLUENCES)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    max_inf = max((sum(1 for g in v.groups if g.weight > 0) for v in mesh.data.vertices), default=0)
    return fixed, max_inf


def weighted_bones(mesh):
    counts = {}
    for v in mesh.data.vertices:
        for g in v.groups:
            if g.weight > 0.05:
                n = mesh.vertex_groups[g.group].name
                counts[n] = counts.get(n, 0) + 1
    return counts


# ---------------------------------------------------------------------------------------------------------------
# Canonical wings

def canonical_wings(rig, mesh):
    select_only(rig)
    bpy.ops.object.mode_set(mode="POSE")
    for side, sx in (("L", 1), ("R", -1)):
        for seg in ("Upper", "Fore", "Hand", "Tip"):
            pb = rig.pose.bones[f"Wing_{side}_{seg}"]
            bpy.context.view_layer.update()
            cur = pb.matrix.col[1].to_3d().normalized()
            dx, dy, dz = T.CANONICAL_WING[seg]
            want = Vector((dx * sx, dy, dz)).normalized()
            rot = cur.rotation_difference(want).to_matrix().to_4x4()
            head = pb.matrix.translation.copy()
            m = pb.matrix.copy()
            m.translation = Vector((0, 0, 0))
            new = rot @ m
            new.translation = head
            pb.matrix = new
    bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode="OBJECT")
    # bake the deformation into the mesh, then make the pose the new rest pose
    select_only(mesh)
    mod = next(m for m in mesh.modifiers if m.type == "ARMATURE")
    name = mod.name
    bpy.ops.object.modifier_apply(modifier=name)
    new_mod = mesh.modifiers.new("Armature", "ARMATURE")
    new_mod.object = rig
    select_only(rig)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="EDIT")
    T.set_rolls(rig.data.edit_bones)
    bpy.ops.object.mode_set(mode="OBJECT")


# ---------------------------------------------------------------------------------------------------------------

def main():
    t0 = time.time()
    opts = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=opts["input"])
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if len(arms) != 1:
        raise SystemExit(f"expected one armature, found {len(arms)}")
    src = arms[0]
    skinned = [o for o in bpy.data.objects if o.type == "MESH"
               and (o.parent == src or any(m.type == "ARMATURE" and m.object == src for m in o.modifiers))]
    for o in [o for o in bpy.data.objects if o.type == "MESH" and o not in skinned]:
        bpy.data.objects.remove(o, do_unlink=True)
    if len(skinned) != 1:
        # several skinned parts: join them into one body
        select_only(skinned[0])
        for o in skinned[1:]:
            o.select_set(True)
        bpy.ops.object.join()
    mesh = skinned[0]
    # unparent (keep transform) and drop the old skinning
    select_only(mesh)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for m in list(mesh.modifiers):
        mesh.modifiers.remove(m)
    mesh.vertex_groups.clear()
    for o in (src, mesh):
        select_only(o)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    report = {"input": opts["input"], "stage": opts["stage"]}

    # weld the seams: the glTF import splits vertices at UV/normal seams, which leaves hundreds of loose islands that
    # the automatic-weights (bone heat) solver can't handle. UVs live on the face corners, so they survive.
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    verts_before = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5 * max(mesh.dimensions))
    bm.to_mesh(mesh.data)
    report_weld = (verts_before, len(bm.verts))
    bm.free()

    # decimate
    before = triangles(mesh)
    if before > opts["tris"]:
        mod = mesh.modifiers.new("Decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = opts["tris"] / before
        mod.use_collapse_triangulate = True
        select_only(mesh)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    report["triangles"] = [before, triangles(mesh)]
    report["welded_vertices"] = report_weld

    # base-color texture only, downscaled
    keep = set()
    for mat in mesh.data.materials:
        if not mat or not mat.use_nodes:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
        for name in ("Metallic", "Roughness", "Normal"):
            for link in list(bsdf.inputs[name].links):
                mat.node_tree.links.remove(link)
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.8
        base = bsdf.inputs["Base Color"].links
        if base and base[0].from_node.type == "TEX_IMAGE":
            keep.add(base[0].from_node.image)
    for img in list(bpy.data.images):
        if img not in keep:
            bpy.data.images.remove(img)
            continue
        if max(img.size[:]) > opts["texture"]:
            img.scale(opts["texture"], opts["texture"])
        img.pack()

    # facing, scale to the stage length, feet on the ground, centered (the source skeleton moves with the mesh)
    if opts["flip"]:
        rot = Matrix.Rotation(math.pi, 4, "Z")
        for o in (src, mesh):
            o.matrix_world = rot @ o.matrix_world
    bpy.context.view_layer.update()
    pts = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    s = T.STAGE_LENGTH[opts["stage"]] / (hi.y - lo.y)
    offset = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    for o in (src, mesh):
        o.matrix_world = Matrix.Scale(s, 4) @ Matrix.Translation(offset) @ o.matrix_world
    bpy.context.view_layer.update()
    for o in (src, mesh):
        select_only(o)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    pts = [v.co for v in mesh.data.vertices]
    size = Vector((max(p.x for p in pts) - min(p.x for p in pts), max(p.y for p in pts) - min(p.y for p in pts),
                   max(p.z for p in pts)))
    body_len, height = size.y, size.z
    report["size_studs"] = [round(v, 2) for v in size]

    # landmarks
    lm = find_landmarks(src, mesh, body_len, height)
    if opts["landmarks"]:
        with open(opts["landmarks"]) as f:
            for key, value in json.load(f).items():
                lm[key] = [Vector(v) for v in value] if isinstance(value[0], list) else Vector(value)
                lm["report"][key] = "override"
    head_tip, jaw_hinge, jaw_tip = head_from_mesh(mesh, lm["head_base"], body_len)
    points, missing = fit_points(lm, body_len, head_tip, jaw_hinge, jaw_tip, height)
    report["source_chains"] = lm["report"]
    report["missing_chains"] = missing
    bpy.data.objects.remove(src, do_unlink=True)

    skip = set()
    for chain in missing:
        skip |= set(T.CHAINS[chain])
    rig = T.build_armature(points, "DragonRig", deform_skip=skip)
    mesh.name = "Body"
    mesh.data.name = "Body"

    fixed, max_inf = bind(mesh, rig)
    report["heat_misses_fixed"] = fixed
    report["max_influences"] = max_inf
    counts = weighted_bones(mesh)
    report["deform_bones_without_weights"] = [b.name for b in rig.data.bones if b.use_deform and not counts.get(b.name)]

    if opts["canonical"]:
        canonical_wings(rig, mesh)
    report["seconds"] = round(time.time() - t0, 1)

    # joint positions for the report
    report["bones"] = {b.name: [[round(c, 3) for c in b.head_local], [round(c, 3) for c in b.tail_local]]
                       for b in rig.data.bones}

    os.makedirs(os.path.dirname(os.path.abspath(opts["output"])), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(opts["output"]))
    if opts["fbx"]:
        select_only(rig)
        mesh.select_set(True)
        bpy.ops.export_scene.fbx(filepath=os.path.abspath(opts["fbx"]), use_selection=True,
                                 object_types={"ARMATURE", "MESH"}, apply_scale_options="FBX_SCALE_ALL",
                                 add_leaf_bones=False, bake_anim=False, path_mode="COPY", embed_textures=True,
                                 mesh_smooth_type="FACE", use_armature_deform_only=True)
    with open(os.path.splitext(os.path.abspath(opts["output"]))[0] + "_rig.json", "w") as f:
        json.dump(report, f, indent=1)
    print("\n=== rerig report ===")
    for k, v in report.items():
        if k != "bones":
            print(f"{k}: {v}")


main()
