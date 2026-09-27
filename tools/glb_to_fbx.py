"""GLB -> Roblox-ready FBX for rigged dragon models (Meshy / UniRig exports).

Run with Blender in background mode:
    D:/jonas/Blender/blender.exe -b --python tools/glb_to_fbx.py -- <input.glb> <output.fbx> [--stage Elder]
        [--tris 10000] [--max-tris 20000] [--texture 1024] [--no-flip]

What it does:
  1. imports the GLB, deletes helper meshes (meshes not skinned to the armature, e.g. Meshy's "Icosphere");
  2. merges tiny tip bones (shorter than 2% of the body length, UniRig adds them at every chain end) into their parents;
  3. decimates each skinned mesh to ~--tris triangles (never above --max-tris; UVs and weights are kept);
  4. limits every vertex to its 4 strongest bone weights (Roblox's max) and normalizes them;
  5. keeps only the base-color texture, downscaled to --texture px, embedded in the FBX;
  6. turns the model 180 degrees so its head faces Blender +Y (= Roblox's forward, -Z / LookVector, after the FBX axis
     change); glTF models face +Z, i.e. Blender -Y after import. --no-flip keeps the imported facing;
  7. scales it so the body length (along the facing axis) is the stage length in studs, feet on the ground (Z = 0),
     centered on the origin;
  8. exports FBX: mesh + armature, Apply Scalings = FBX All, no leaf bones, no animation, textures embedded.
Prints a report (bones, weights per body part, triangles before/after, texture size).
"""

import sys

import bpy
import mathutils

STAGE_LENGTH = {"Hatchling": 6.0, "Drake": 8.5, "Dragon": 11.0, "Elder": 15.0}  # studs, nose to tail tip
MAX_INFLUENCES = 4  # Roblox skinning limit
TIP_BONE_FRACTION = 0.02  # tip bones shorter than this share of the body length are merged into their parent


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 2:
        raise SystemExit("usage: blender -b --python glb_to_fbx.py -- <input.glb> <output.fbx> [--stage Elder] ...")
    opts = {"input": argv[0], "output": argv[1], "stage": "Elder", "tris": 10000, "max_tris": 20000,
            "texture": 1024, "flip": None}
    i = 2
    while i < len(argv):
        key = argv[i]
        if key == "--stage":
            opts["stage"] = argv[i + 1]; i += 2
        elif key == "--tris":
            opts["tris"] = int(argv[i + 1]); i += 2
        elif key == "--max-tris":
            opts["max_tris"] = int(argv[i + 1]); i += 2
        elif key == "--texture":
            opts["texture"] = int(argv[i + 1]); i += 2
        elif key == "--flip":
            opts["flip"] = True; i += 1
        elif key == "--no-flip":
            opts["flip"] = False; i += 1
        else:
            raise SystemExit(f"unknown option {key}")
    if opts["stage"] not in STAGE_LENGTH:
        raise SystemExit(f"--stage must be one of {', '.join(STAGE_LENGTH)}")
    opts["max_tris"] = min(opts["max_tris"], 20000)
    opts["tris"] = min(opts["tris"], opts["max_tris"])
    return opts


def triangles(mesh_obj):
    return sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons)


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def main():
    opts = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=opts["input"])

    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if len(arms) != 1:
        raise SystemExit(f"expected one armature, found {len(arms)}")
    arm = arms[0]
    skinned = [o for o in bpy.data.objects if o.type == "MESH"
               and (o.parent == arm or any(m.type == "ARMATURE" and m.object == arm for m in o.modifiers))]
    helpers = [o for o in bpy.data.objects if o.type == "MESH" and o not in skinned]
    report = {"helpers removed": [o.name for o in helpers]}
    for o in helpers:
        bpy.data.objects.remove(o, do_unlink=True)
    if not skinned:
        raise SystemExit("no skinned mesh found")

    # apply the import transforms so bone and mesh data are in world space
    for o in [arm, *skinned]:
        select_only(o)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    tris_before = sum(triangles(o) for o in skinned)
    bones_before = len(arm.data.bones)

    # facing: glTF models face +Z, which Blender's glTF importer turns into -Y. Roblox's forward (-Z) comes from
    # Blender +Y through the FBX axis change, so turn 180 degrees. --no-flip keeps the imported facing, --flip forces
    # the turn (for models that don't follow the glTF convention).
    angle = 3.14159265 if opts["flip"] is not False else 0.0
    long_axis = 1  # body length runs along Y (front to back)
    report["turned (degrees)"] = 180 if angle else 0

    # body length before scaling, for the tip-bone threshold
    def mesh_bounds():
        pts = [o.matrix_world @ v.co for o in skinned for v in o.data.vertices]
        lo = mathutils.Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = mathutils.Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        return lo, hi
    lo, hi = mesh_bounds()
    body_len = (hi - lo)[long_axis]

    # merge tiny tip bones into their parents (weights move to the parent)
    select_only(arm)
    bpy.ops.object.mode_set(mode="EDIT")
    ebones = arm.data.edit_bones
    merged = []
    changed = True
    while changed:
        changed = False
        for eb in list(ebones):
            if not eb.children and eb.parent and eb.length < body_len * TIP_BONE_FRACTION:
                merged.append((eb.name, eb.parent.name))
                ebones.remove(eb)
                changed = True
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in skinned:
        for child, parent in merged:
            g = o.vertex_groups.get(child)
            if g is None:
                continue
            pg = o.vertex_groups.get(parent) or o.vertex_groups.new(name=parent)
            for v in o.data.vertices:
                for vg in v.groups:
                    if vg.group == g.index and vg.weight > 0:
                        pg.add([v.index], vg.weight, "ADD")
            o.vertex_groups.remove(g)
    report["tip bones merged"] = len(merged)

    # decimate, then limit + normalize weights
    per_mesh = []
    for o in skinned:
        before = triangles(o)
        target = min(opts["tris"], opts["max_tris"]) * before / max(tris_before, 1)
        if before > target:
            select_only(o)
            mod = o.modifiers.new("Decimate", "DECIMATE")
            mod.decimate_type = "COLLAPSE"
            mod.ratio = target / before
            mod.use_collapse_triangulate = True
            bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
            bpy.ops.object.modifier_apply(modifier=mod.name)
        select_only(o)
        bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
        bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=0.001)
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=MAX_INFLUENCES)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        max_inf = max((sum(1 for g in v.groups if g.weight > 0) for v in o.data.vertices), default=0)
        per_mesh.append((o.name, before, triangles(o), max_inf))
    report["meshes (name, tris before, after, max influences)"] = per_mesh

    # textures: keep base color only, downscaled
    textures = []
    keep = set()
    for o in skinned:
        for mat in o.data.materials:
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
        size = img.size[:]
        if max(size) > opts["texture"]:
            img.scale(opts["texture"], opts["texture"])
        img.pack()
        textures.append((img.name, size, img.size[:]))
    report["textures (name, before, after)"] = textures

    # turn, scale to the stage length, feet on the ground, centered
    rot = mathutils.Matrix.Rotation(-angle, 4, "Z")
    for o in [arm, *skinned]:
        if o.parent is None:
            o.matrix_world = rot @ o.matrix_world
    bpy.context.view_layer.update()
    for o in [arm, *skinned]:
        select_only(o)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo, hi = mesh_bounds()
    length = hi.y - lo.y
    s = STAGE_LENGTH[opts["stage"]] / length
    offset = mathutils.Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    for o in [arm, *skinned]:
        if o.parent is None:
            o.matrix_world = mathutils.Matrix.Scale(s, 4) @ mathutils.Matrix.Translation(offset) @ o.matrix_world
    bpy.context.view_layer.update()
    for o in [arm, *skinned]:
        select_only(o)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo, hi = mesh_bounds()
    report["size (studs, x/y/z = width/length/height)"] = tuple(round(v, 2) for v in (hi - lo))

    # bone report: which chains have weighted bones
    weighted = set()
    for o in skinned:
        counts = {g.index: 0 for g in o.vertex_groups}
        for v in o.data.vertices:
            for g in v.groups:
                if g.weight > 0.01:
                    counts[g.group] += 1
        weighted |= {o.vertex_groups[i].name for i, n in counts.items() if n > 0}
    bones = arm.data.bones
    report["bones before/after"] = (bones_before, len(bones))
    report["bones with skin weights"] = f"{len([b for b in bones if b.name in weighted])} of {len(bones)}"
    root = bones[0]
    while root.parent:
        root = root.parent
    chains = []
    for b in bones:
        if b.parent and len(b.parent.children) > 1 or b.parent is None:
            # a chain starts where a branch starts
            chain = [b]
            while len(chain[-1].children) == 1:
                chain.append(chain[-1].children[0])
            if len(chain) >= 2:
                head, tip = chain[0].head_local, chain[-1].tail_local
                w = sum(1 for c in chain if c.name in weighted)
                chains.append((f"{chain[0].name}..{chain[-1].name}", len(chain), w,
                               tuple(round(v, 1) for v in head), tuple(round(v, 1) for v in tip)))
    report["chains (first..last, bones, weighted, start xyz, tip xyz)"] = chains

    select_only(arm)
    for o in skinned:
        o.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=opts["output"],
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        apply_scale_options="FBX_SCALE_ALL",
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="COPY",
        embed_textures=True,
        mesh_smooth_type="FACE",
        use_armature_deform_only=True,
    )
    print("\n=== glb_to_fbx report ===")
    print("input:", opts["input"])
    print("output:", opts["output"])
    print("stage:", opts["stage"], STAGE_LENGTH[opts["stage"]], "studs")
    print("triangles before:", tris_before)
    for k, v in report.items():
        if isinstance(v, list) and v and isinstance(v[0], tuple):
            print(f"{k}:")
            for row in v:
                print("   ", row)
        else:
            print(f"{k}: {v}")


main()
