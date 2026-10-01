"""Top-down schematic mockups of Valley sanctuary layouts (world X east, Z south; north = up).
Run: python tools/valley_layout/mockup.py  -> docs/img/valley_layout_adjusted_*.png
Numbers mirror tools/valley_terrain/ValleyTerrain.luau (V.Sanct, V.River, edge table)."""
import math, os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "img")
S = 2.0  # px per stud
X0, X1, Z0, Z1 = -420, 420, -330, 350
W, H = int((X1 - X0) * S), int((Z1 - Z0) * S)


def P(x, z):
    return ((x - X0) * S, (z - Z0) * S)


try:
    FONT = ImageFont.truetype("arialbd.ttf", 22)
    FS = ImageFont.truetype("arial.ttf", 17)
except Exception:
    FONT = FS = ImageFont.load_default()

CUR = {"W1": (-208, -184), "W2": (-174, -30), "W3": (-158, 150),
       "E1": (208, -184), "E2": (174, -30), "E3": (158, 150)}
COL = {"1": (255, 120, 60), "2": (255, 215, 70), "3": (255, 110, 220)}
R_RIM, R_FLAT = 75, 80


def horseshoe(R, a1, gap):
    step = 2 * math.degrees(math.asin((150 + gap) / 2 / R))
    out = {}
    for i in range(3):
        a = math.radians(a1 + i * step)
        x, z = R * math.sin(a), -R * math.cos(a)
        out["W%d" % (i + 1)] = (-x, z)
        out["E%d" % (i + 1)] = (x, z)
    return out, step


EDGE = [(0, 300), (30, 300), (45, 286), (60, 272), (90, 274), (95, 276), (99, 304), (110, 304), (114, 272), (130, 262), (140, 238), (150, 208), (165, 188), (180, 184)]


def table_edge(a):
    a = abs(a)
    for (p, q) in zip(EDGE, EDGE[1:]):
        if a <= q[0]:
            return p[1] + (q[1] - p[1]) * (a - p[0]) / (q[0] - p[0])
    return EDGE[-1][1]


def bulge(th, plots):
    t = math.radians(th)
    dx, dz = math.sin(t), -math.cos(t)
    best = 0
    for (x, z) in plots.values():
        b = x * dx + z * dz
        disc = b * b - (x * x + z * z - (R_FLAT + 16) ** 2)
        if b > 0 and disc > 0:
            best = max(best, b + math.sqrt(disc))
    return best


def outline(plots):
    pts = []
    for d in range(-180, 181, 2):
        r = max(table_edge(d), bulge(d, plots))
        t = math.radians(d)
        pts.append(P(r * math.sin(t), -r * math.cos(t)))
    return pts


RIVER_CUR = [(-304, 61), (-281, 60), (-264, 67), (-246, 66), (-228, 61), (-205, 58), (-186, 57), (-168, 58), (-148, 58), (-128, 57), (-100, 60), (-72, 53), (-36, 63), (0, 63), (36, 59), (72, 59), (100, 60), (132, 57), (172, 58), (205, 58), (243, 67), (270, 61), (294, 62)]
PORTALS = [(-94, -129), (-36, -156), (36, -156), (94, -129)]


def draw(plots, title, subtitle, show_cur, river_new=None):
    img = Image.new("RGB", (W, H), (214, 224, 196))
    d = ImageDraw.Draw(img, "RGBA")
    o = outline(plots)
    d.polygon(o, fill=(150, 196, 120, 255))
    if show_cur:
        oc = outline(CUR)
        d.line(oc + oc[:1], fill=(90, 90, 90, 255), width=2)
    for pts in ([(0, 205), (0, 84)], [(0, -54), (0, -124)]):
        d.line([P(*p) for p in pts], fill=(236, 222, 190, 255), width=int(10 * S))
    cx, cz = P(0, 0)
    for r, c in ((57, (236, 222, 190)), (48, (200, 196, 190)), (42, (168, 170, 190))):
        d.ellipse([cx - r * S, cz - r * S, cx + r * S, cz + r * S], fill=c + (255,))
    d.ellipse([cx - 5, cz - 5, cx + 5, cz + 5], fill=(220, 40, 40, 255))
    ring = [P(180 * math.sin(math.radians(a)), -180 * math.cos(math.radians(a))) for a in range(-44, 45, 2)]
    ring += [P(133 * math.sin(math.radians(a)), -133 * math.cos(math.radians(a))) for a in range(44, -45, -2)]
    d.polygon(ring, fill=(205, 195, 178, 255))
    sx, sz = P(0, -252)
    d.ellipse([sx - 42 * S, sz - 42 * S, sx + 42 * S, sz + 42 * S], fill=(190, 185, 200, 255))
    d.text((sx - 28, sz - 10), "Spire", font=FS, fill=(40, 40, 60))
    for (x, z) in PORTALS:
        px, pz = P(x, z)
        d.rectangle([px - 10, pz - 10, px + 10, pz + 10], fill=(110, 70, 200, 255))
    for (x, z, n) in ((-56, 116, "merchant"), (58, 114, "forge"), (-50, 144, "shrine"), (0, 112, "obelisk")):
        px, pz = P(x, z)
        d.rectangle([px - 14, pz - 14, px + 14, pz + 14], fill=(170, 130, 90, 255))
        d.text((px - 22, pz + 14), n, font=FS, fill=(60, 40, 20))
    for (x, z) in ((-50, 84), (50, 84)):
        px, pz = P(x, z)
        d.ellipse([px - 20, pz - 14, px + 20, pz + 14], fill=(90, 170, 230, 255))
    ex, ez = P(0, 150)
    d.rectangle([ex - 30, ez - 8, ex + 30, ez + 8], fill=(120, 120, 130, 255))
    d.text((ex + 36, ez - 10), "entrance gate + spawn", font=FS, fill=(40, 40, 40))
    rv = river_new if river_new else RIVER_CUR
    d.line([P(*p) for p in rv], fill=(60, 150, 230, 255), width=int(10 * S), joint="curve")
    if show_cur:
        for n, (x, z) in CUR.items():
            px, pz = P(x, z)
            d.ellipse([px - 75 * S, pz - 75 * S, px + 75 * S, pz + 75 * S], outline=(60, 60, 60, 255), width=3)
            d.text((px - 14, pz - 40), n + " now", font=FS, fill=(60, 60, 60))
    for n, (x, z) in plots.items():
        px, pz = P(x, z)
        c = COL[n[1]]
        d.ellipse([px - R_FLAT * S, pz - R_FLAT * S, px + R_FLAT * S, pz + R_FLAT * S], fill=c + (110,), outline=(30, 30, 30, 255), width=2)
        d.ellipse([px - R_RIM * S, pz - R_RIM * S, px + R_RIM * S, pz + R_RIM * S], outline=(30, 30, 30, 255), width=2)
        ln = math.hypot(x, z)
        ax, az = -x / ln, -z / ln
        gx, gz = x + ax * 75, z + az * 75
        gp = P(gx, gz)
        nx, nz = -az, ax
        d.line([gp[0] - nx * 13 * S, gp[1] - nz * 13 * S, gp[0] + nx * 13 * S, gp[1] + nz * 13 * S], fill=(255, 255, 255, 255), width=7)
        d.line([P(0, 0), gp], fill=(255, 255, 255, 170), width=2)
        d.text((px - 14, pz - 12), n, font=FONT, fill=(20, 20, 20, 255))
        d.text((px - 36, pz + 12), "gate %d" % round(ln - 75), font=FS, fill=(20, 20, 20, 255))
    zz = P(0, -129)[1]
    d.line([0, zz, W, zz], fill=(220, 20, 20, 255), width=2)
    d.text((10, zz - 22), "portal row: z -129 (outer portals)", font=FS, fill=(200, 0, 0))
    d.rectangle([0, 0, W, 64], fill=(255, 255, 255, 230))
    d.text((12, 6), title, font=FONT, fill=(0, 0, 0))
    d.text((12, 34), subtitle, font=FS, fill=(40, 40, 40))
    d.text((12, H - 26), "north = up; filled disc = flat r80, line = rim r75; white bar = gate; grey = today's plots and valley edge", font=FS, fill=(0, 0, 0))
    return img


def report(name, plots):
    print(name)
    for n, (x, z) in plots.items():
        if n[0] == "W":
            print("  %s (%.0f, %.0f) gate %.0f back edge z %.0f front edge z %.0f" % (n, x, z, math.hypot(x, z) - 75, z - 80, z + 80))
    w = [plots["W1"], plots["W2"], plots["W3"]]
    for a, b in zip(w, w[1:]):
        print("  gap rim-rim %.0f  flat-flat %.0f" % (math.hypot(a[0] - b[0], a[1] - b[1]) - 150, math.hypot(a[0] - b[0], a[1] - b[1]) - 160))
    print("  S pair gap rim-rim %.0f" % (2 * abs(plots["W3"][0]) - 150))


if __name__ == "__main__":
    R = 256
    a79, st = horseshoe(R, 79, 24)
    a60, st60 = horseshoe(R, 60, 24)
    report("A-79 (recommended) step %.1f" % st, a79)
    report("A-60 (your example)", a60)
    river = [(-352, 52), (-310, 46), (-270, 40), (-238, 37), (-210, 40), (-185, 46), (-160, 53), (-130, 58), (-112, 61), (-100, 60), (-72, 53), (-36, 63), (0, 63), (36, 59), (72, 59), (100, 60), (112, 61), (130, 58), (160, 53), (185, 46), (210, 40), (238, 37), (270, 40), (310, 46), (352, 52)]
    draw(a79, "Option A-79: even horseshoe, nothing behind the portal row",
         "R 256, bearings 79 / 118.7 / 158.4, rim gap 24, gate distance 181 for all six; the river runs between W1 and W2", True, river).save(os.path.join(OUT, "valley_layout_adjusted_A79.png"))
    draw(a60, "Option A-60 (your example bearings), for comparison",
         "W1 back edge z -208: behind the portals; the river would cut W2", True, None).save(os.path.join(OUT, "valley_layout_adjusted_A60.png"))
