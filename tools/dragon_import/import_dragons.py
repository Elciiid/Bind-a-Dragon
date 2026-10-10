"""Dragon art import: Meshy GLBs -> standard-skeleton, Roblox-ready FBX files + manifest + checks.

Normal Python (3.10+), drives Blender in background mode. Everything stays on drive E; source files are only read.

    python tools/dragon_import/import_dragons.py scan
    python tools/dragon_import/import_dragons.py run --species Cinderwing --out assets/Dragons/fbx/ready
    python tools/dragon_import/import_dragons.py run --element Fire --out assets/Dragons/fbx/ready/Fire
    python tools/dragon_import/import_dragons.py report

scan    re-reads assets/Dragons (only files ending in .glb count) and rewrites manifest.json; every run starts with a
        scan, so a .glb added later is picked up automatically.
run     per model: tools/dragon_rig/rerig.py (standard skeleton, straight tail, budgets below, exact stage length,
        unique names) -> <out>/<Species>_<Stage>.fbx; if the re-rig fails, tools/glb_to_fbx.py as a FLAGGED fallback
        (the model keeps its Meshy bones and needs its own bone map). Then check_fbx.py measures the FBX and
        preview.py renders stills into assets/Dragons/previews/. Results: results.json + results.md here.
report  rewrites results.md from results.json.

Budgets (per stage; the game scales each model to Config/Evolution Length, read from the Luau file):
  * Triangles: Hatchling 5k, Drake 7k, Dragon 9k, Elder 10k (hard cap 20k, Roblox's per-mesh limit). Hatchlings and
    Drakes are 10-15 studs and mostly seen small (nests, meadow, hotbar pictures), so their silhouette survives 5-7k;
    Dragons/Elders (21-28 studs, flying overhead, the reveal close-up) keep 9-10k like the current Elder imports. Six
    sanctuaries of up to ~8 dragons + companions stay in the range measured with the Elders (~130k dragon triangles
    on screen on PC) because Roblox only draws what is near and in view (and RoostAnimationController hides dragons
    beyond 260 studs).
  * Textures: base color only, embedded. 512 px for Hatchling/Drake (they rarely cover more than ~300 px on screen),
    1024 px for Dragon/Elder (reveal close-up). 512^2 ~ 0.35 MB and 1024^2 ~ 1.4 MB of GPU memory each with mips (BC1/3
    compressed, Roblox's format); 80 models ~ 0.35 * 40 + 1.4 * 40 = 70 MB if every texture were loaded at once.
  * Max 4 bone weights per vertex (Roblox skinning), every model the same 35-bone skeleton (template.py).
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLENDER = "D:/jonas/Blender/blender.exe"  # Blender 5.2 (already installed; all outputs are written to drive E)
SOURCE_DIR = os.path.join(ROOT, "assets", "Dragons")
BLEND_DIR = os.path.join(SOURCE_DIR, "blend")
PREVIEW_DIR = os.path.join(SOURCE_DIR, "previews")
LOG_DIR = os.path.join(SOURCE_DIR, "logs")  # full Blender logs (not in Git)
CHECK_DIR = os.path.join(BLEND_DIR, "_check")  # FBX copies imported by check_fbx.py (Blender unpacks textures there)
HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST = os.path.join(HERE, "manifest.json")
RESULTS = os.path.join(HERE, "results.json")
RESULTS_MD = os.path.join(HERE, "results.md")

STAGES = ["Hatchling", "Drake", "Dragon", "Elder"]
BUDGETS = {  # stage -> (triangles, texture px)
    "Hatchling": (5000, 512),
    "Drake": (7000, 512),
    "Dragon": (9000, 1024),
    "Elder": (10000, 1024),
}
MAX_TRIANGLES = 20000
TRIANGLE_TOLERANCE = 1.05  # Blender's collapse decimation lands within a few percent of the target
LENGTH_TOLERANCE = 0.02  # 2 % of the stage length
NAME_FIXES = {"Elipsar": "Eclipsar"}  # file-name typos -> SpeciesId (manifest only; files are never renamed)
NOT_SPECIES = {"Unicorn": "not a game species (owner): skipped"}


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def load_species():
    """SpeciesId -> {Element, Rarity} from Config/Dragons.luau."""
    text = read(os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Config", "Dragons.luau"))
    out = {}
    for sid, element, rarity in re.findall(r'^\s*(\w+) = \{ Name = "[^"]+", Element = "(\w+)", Rarity = "(\w+)"', text, re.M):
        out[sid] = {"Element": element, "Rarity": rarity}
    return out


def load_lengths():
    """StageId -> Length (studs, nose to tail tip) from Config/Evolution.luau."""
    text = read(os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Config", "Evolution.luau"))
    return {sid: float(length) for sid, length in re.findall(r'Id = "(\w+)".*?Length = ([\d.]+)', text)}


def glb_ok(path):
    try:
        with open(path, "rb") as f:
            return f.read(4) == b"glTF"
    except OSError:
        return False


def scan():
    species = load_species()
    old = {}
    if os.path.exists(MANIFEST):
        for e in json.load(open(MANIFEST)).get("models", []):
            old[(e["species"], e["stage"])] = e
    found, skipped, unknown, other = {}, [], [], []
    for name in sorted(os.listdir(SOURCE_DIR)):
        path = os.path.join(SOURCE_DIR, name)
        if not os.path.isfile(path):
            continue
        if not name.lower().endswith(".glb"):
            other.append(name)  # e.g. extensionless copies: ignored on purpose, never opened
            continue
        stem = name[:-4]
        if "_" not in stem:
            unknown.append({"file": name, "reason": "name is not <Species>_<Stage>"})
            continue
        raw, stage = stem.rsplit("_", 1)
        sid = NAME_FIXES.get(raw, raw)
        if raw in NOT_SPECIES:
            skipped.append({"file": name, "reason": NOT_SPECIES[raw]})
            continue
        if sid not in species or stage not in STAGES:
            unknown.append({"file": name, "reason": "unknown species or stage"})
            continue
        found[(sid, stage)] = {"file": name, "name_fix": f"{raw} -> {sid}" if raw != sid else None,
                               "readable": glb_ok(path), "bytes": os.path.getsize(path),
                               "mtime": int(os.path.getmtime(path))}
    models = []
    for sid, info in species.items():
        for stage in STAGES:
            src = found.get((sid, stage))
            prev = old.get((sid, stage), {})
            entry = {"species": sid, "stage": stage, "element": info["Element"], "rarity": info["Rarity"],
                     "source": src["file"] if src else None}
            if src and src["name_fix"]:
                entry["name_fix"] = src["name_fix"]
            if not src:
                entry["status"] = "missing"
            elif not src["readable"]:
                entry["status"] = "unreadable"
            elif prev.get("source") == src["file"] and prev.get("bytes") == src["bytes"] and prev.get("mtime") == src["mtime"] \
                    and prev.get("status") in ("converted", "fallback", "failed", "placed"):
                for k in ("status", "fbx", "problems", "placed"):
                    if k in prev:
                        entry[k] = prev[k]
            else:
                entry["status"] = "pending"
            if src:
                entry["bytes"], entry["mtime"] = src["bytes"], src["mtime"]
            models.append(entry)
    manifest = {"note": "Built by tools/dragon_import/import_dragons.py scan. Source GLBs are never modified; GLB/FBX are not in Git.",
                "models": models, "skipped": skipped, "unknown": unknown, "ignored_non_glb": other}
    with open(MANIFEST, "w") as f:
        json.dump(manifest, f, indent=1)
    return manifest


def blender(args, log_name):
    os.makedirs(LOG_DIR, exist_ok=True)
    log = os.path.join(LOG_DIR, log_name)
    t0 = time.time()
    with open(log, "w", encoding="utf-8", errors="replace") as f:
        proc = subprocess.run([BLENDER, "-b", *args], cwd=ROOT, stdout=f, stderr=subprocess.STDOUT, timeout=1800)
    return proc.returncode, round(time.time() - t0, 1), log


def check(fbx, name):
    os.makedirs(CHECK_DIR, exist_ok=True)
    copy = os.path.join(CHECK_DIR, os.path.basename(fbx))
    shutil.copyfile(fbx, copy)
    out = os.path.join(CHECK_DIR, f"{name}_check.json")
    code, _, log = blender(["--python", os.path.join(HERE, "check_fbx.py"), "--", copy, out], f"{name}_check.log")
    if code != 0 or not os.path.exists(out):
        return None
    return json.load(open(out))


def judge(c, stage, length, fallback):
    """Problems (empty = within budget) from a check_fbx.py result."""
    tris_budget, tex_budget = BUDGETS[stage]
    p = []
    if c is None:
        return ["FBX could not be re-read"]
    if c["triangles"] > min(tris_budget * TRIANGLE_TOLERANCE, MAX_TRIANGLES):
        p.append(f"triangles {c['triangles']} > budget {tris_budget}")
    sizes = [max(t["size"]) for t in c["textures"]]
    if len(sizes) != 1:
        p.append(f"{len(sizes)} textures (want 1 base color)")
    if sizes and max(sizes) > tex_budget:
        p.append(f"texture {max(sizes)} px > {tex_budget}")
    if c["max_influences"] > 4:
        p.append(f"{c['max_influences']} bone weights on a vertex (max 4)")
    if not fallback:
        if c.get("bones_not_standard"):
            p.append("bones not in the standard skeleton: " + ", ".join(c["bones_not_standard"]))
        if c.get("standard_bones_missing"):
            p.append("standard bones missing: " + ", ".join(c["standard_bones_missing"]))
        if c.get("wrong_parents"):
            p.append("wrong parents: " + "; ".join(c["wrong_parents"]))
        if c.get("faces_minus_y") is False:
            p.append("head is not at the front (-Y)")
    if "size_studs" in c:
        if abs(c["size_studs"][1] - length) > length * LENGTH_TOLERANCE:
            p.append(f"length {c['size_studs'][1]} studs, want {length}")
        if abs(c["lowest_z"]) > 0.05:
            p.append(f"lowest point at {c['lowest_z']} (feet should be at 0)")
    if c.get("meshes") != ["Body"]:
        p.append(f"meshes {c.get('meshes')} (want one 'Body')")
    return p


def convert(entry, out_dir, lengths):
    sid, stage = entry["species"], entry["stage"]
    name = f"{sid}_{stage}"
    tris, tex = BUDGETS[stage]
    length = lengths[stage]
    src = os.path.join(SOURCE_DIR, entry["source"])
    fbx = os.path.join(out_dir, f"{name}.fbx")
    blend = os.path.join(BLEND_DIR, f"{name}.blend")
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(BLEND_DIR, exist_ok=True)
    row = {"name": name, "species": sid, "stage": stage, "element": entry["element"], "source": entry["source"],
           "fbx": os.path.relpath(fbx, ROOT).replace("\\", "/"), "budget_tris": tris, "budget_texture": tex, "length_want": length}
    code, secs, log = blender(["--python", os.path.join(ROOT, "tools", "dragon_rig", "rerig.py"), "--", src, blend,
                               "--stage", stage, "--tris", str(tris), "--texture", str(tex), "--length", str(length),
                               "--name", name, "--flip", "auto", "--fbx", fbx], f"{name}_rerig.log")
    row["seconds"] = secs
    fallback = code != 0 or not os.path.exists(fbx)
    if fallback:
        row["rerig_error"] = tail(log)
        code, secs, log = blender(["--python", os.path.join(ROOT, "tools", "glb_to_fbx.py"), "--", src, fbx,
                                   "--stage", "Elder", "--tris", str(tris), "--texture", str(tex), "--length", str(length)],
                                  f"{name}_fallback.log")
        if code != 0 or not os.path.exists(fbx):
            row["status"] = "failed"
            row["problems"] = ["re-rig failed: " + row["rerig_error"], "fallback glb_to_fbx failed: " + tail(log)]
            return row
    else:
        rig_json = os.path.splitext(blend)[0] + "_rig.json"
        if os.path.exists(rig_json):
            rep = json.load(open(rig_json))
            row["missing_chains"] = rep.get("missing_chains", [])
            row["heat_misses_fixed"] = rep.get("heat_misses_fixed")
            row["tail_straightened"] = rep.get("tail_straightened", {}).get("droop_scale")
            row["deform_bones_without_weights"] = rep.get("deform_bones_without_weights", [])
            row["flipped"] = rep.get("flipped")
            row["tail_note"] = rep.get("source_chains", {}).get("tail_note")
    c = check(fbx, name)
    row["check"] = c
    row["problems"] = judge(c, stage, length, fallback)
    for chain in row.get("missing_chains", []):
        row["problems"].append(f"NOTE: the source has no {chain} bones; that part is skinned to the body and moves with it")
    if row.get("deform_bones_without_weights"):
        row["problems"].append("deform bones with no skin: " + ", ".join(row["deform_bones_without_weights"]))
    if fallback:
        row["problems"].insert(0, "FLAGGED: re-rig failed, converted with tools/glb_to_fbx.py (Meshy bones, needs its own bone map)")
    row["status"] = "fallback" if fallback else "converted"
    if not fallback and os.path.exists(blend):
        os.makedirs(PREVIEW_DIR, exist_ok=True)
        blender([blend, "--python", os.path.join(ROOT, "tools", "dragon_rig", "preview.py"), "--",
                 os.path.join(PREVIEW_DIR, name), "--views", "side,front,persp", "--size", "700"], f"{name}_preview.log")
        row["previews"] = sorted(f for f in os.listdir(PREVIEW_DIR) if f.startswith(name + "_rest_"))
    return row


def tail(log, n=6):
    try:
        lines = [l.rstrip() for l in open(log, encoding="utf-8", errors="replace") if l.strip()]
    except OSError:
        return "no log"
    return " | ".join(lines[-n:])[-600:]


def write_md(results):
    lines = ["# Dragon import results", "",
             "Measured by tools/dragon_import/check_fbx.py on the exported FBX (numbers only, no game test).", "",
             "| Model | Status | Tris (budget) | Texture | Bones | Max weights | Size W x L x H (studs) | Feet | Problems |",
             "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    for name in sorted(results, key=lambda n: (results[n]["element"], results[n]["species"], STAGES.index(results[n]["stage"]))):
        r = results[name]
        c = r.get("check") or {}
        tex = ", ".join(f"{t['size'][0]}" for t in c.get("textures", [])) or "-"
        size = " x ".join(str(v) for v in c.get("size_studs", [])) or "-"
        problems = "; ".join(r.get("problems", [])) or "none"
        lines.append(f"| {name} | {r['status']} | {c.get('triangles', '-')} ({r['budget_tris']}) | {tex} | {c.get('bones', '-')} | "
                     f"{c.get('max_influences', '-')} | {size} (want L {r['length_want']:g}) | {c.get('lowest_z', '-')} | {problems} |")
    with open(RESULTS_MD, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["scan", "run", "report"])
    ap.add_argument("--species", nargs="*")
    ap.add_argument("--element")
    ap.add_argument("--out")
    ap.add_argument("--force", action="store_true", help="convert again even if already converted")
    a = ap.parse_args()
    results = json.load(open(RESULTS)) if os.path.exists(RESULTS) else {}
    if a.command == "report":
        write_md(results)
        return
    manifest = scan()
    m = manifest["models"]
    print(f"scan: {sum(1 for e in m if e['source'])} of {len(m)} stages have a .glb; missing:",
          [f"{e['species']}_{e['stage']}" for e in m if e["status"] == "missing"],
          "unreadable:", [e["source"] for e in m if e["status"] == "unreadable"],
          "skipped:", [s["file"] for s in manifest["skipped"]], "unknown:", manifest["unknown"],
          "ignored (no .glb ending):", manifest["ignored_non_glb"])
    if a.command == "scan":
        return
    if not a.out:
        raise SystemExit("run needs --out")
    out_dir = os.path.join(ROOT, a.out)
    lengths = load_lengths()
    todo = [e for e in m if (not a.species or e["species"] in a.species) and (not a.element or e["element"] == a.element)
            and e["status"] in (("pending", "converted", "fallback", "failed") if a.force else ("pending",))]
    for e in todo:
        print("converting", e["species"], e["stage"], flush=True)
        row = convert(e, out_dir, lengths)
        results[row["name"]] = row
        e["status"], e["fbx"], e["problems"] = row["status"], row["fbx"], row["problems"]
        with open(RESULTS, "w") as f:
            json.dump(results, f, indent=1)
        with open(MANIFEST, "w") as f:
            json.dump(manifest, f, indent=1)
        print("  ->", row["status"], row.get("problems"), flush=True)
    write_md(results)


if __name__ == "__main__":
    main()
