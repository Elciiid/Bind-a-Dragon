"""Stylized tileable terrain textures (pure Python, no dependencies).
Usage: python gen.py [name ...]   (writes <name>.png next to this file)
"""
import math, random, struct, sys, zlib, os, time

N = 512
OUT = os.path.dirname(os.path.abspath(__file__))


def write_png(path, pixels):
    raw = bytearray()
    for y in range(N):
        raw.append(0)
        row = pixels[y * N:(y + 1) * N]
        for r, g, b in row:
            raw += bytes((r, g, b))
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


class ValueNoise:
    """Tileable value noise; period in cells must divide N."""
    def __init__(self, cells, seed):
        rnd = random.Random(seed)
        self.c = cells
        self.v = [[rnd.random() for _ in range(cells)] for _ in range(cells)]

    def at(self, x, y):
        c = self.c
        fx = x / N * c
        fy = y / N * c
        x0 = int(fx) % c
        y0 = int(fy) % c
        tx = fx - int(fx)
        ty = fy - int(fy)
        tx = tx * tx * (3 - 2 * tx)
        ty = ty * ty * (3 - 2 * ty)
        x1 = (x0 + 1) % c
        y1 = (y0 + 1) % c
        v = self.v
        a = v[y0][x0] + (v[y0][x1] - v[y0][x0]) * tx
        b = v[y1][x0] + (v[y1][x1] - v[y1][x0]) * tx
        return a + (b - a) * ty


def fbm(layers, x, y):
    total, amp, norm = 0.0, 1.0, 0.0
    for n in layers:
        total += n.at(x, y) * amp
        norm += amp
        amp *= 0.5
    return total / norm


class Voronoi:
    """Tileable cellular noise: returns (cell id, f1, f2) in pixels."""
    def __init__(self, cells, seed, jitter=0.9):
        rnd = random.Random(seed)
        self.c = cells
        self.size = N / cells
        self.p = [[((i + 0.5 + (rnd.random() - 0.5) * jitter) * self.size,
                    (j + 0.5 + (rnd.random() - 0.5) * jitter) * self.size,
                    rnd.random()) for i in range(cells)] for j in range(cells)]

    def at(self, x, y):
        c, s = self.c, self.size
        cx, cy = int(x / s), int(y / s)
        f1 = f2 = 1e9
        cid = 0.0
        for dj in (-1, 0, 1):
            for di in (-1, 0, 1):
                i, j = cx + di, cy + dj
                px, py, r = self.p[j % c][i % c]
                px += (i - (i % c)) * s
                py += (j - (j % c)) * s
                d = math.hypot(x - px, y - py)
                if d < f1:
                    f2 = f1
                    f1 = d
                    cid = r
                elif d < f2:
                    f2 = d
        return cid, f1, f2


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return (lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t))


def clamp8(c):
    return tuple(max(0, min(255, int(round(v)))) for v in c)


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def speckle_map(count, seed, rmin, rmax):
    """Tileable dots: dict pixel -> strength."""
    rnd = random.Random(seed)
    m = {}
    for _ in range(count):
        cx, cy = rnd.random() * N, rnd.random() * N
        r = rnd.uniform(rmin, rmax)
        for dy in range(-int(r) - 1, int(r) + 2):
            for dx in range(-int(r) - 1, int(r) + 2):
                d = math.hypot(dx, dy)
                if d <= r:
                    k = ((int(cy) + dy) % N) * N + (int(cx) + dx) % N
                    m[k] = max(m.get(k, 0.0), 1 - (d / r) ** 2)
    return m


def strokes_map(count, seed, length, width, angle_spread=0.6):
    """Short soft brush strokes (blade-like), tileable."""
    rnd = random.Random(seed)
    m = {}
    for _ in range(count):
        cx, cy = rnd.random() * N, rnd.random() * N
        ang = -math.pi / 2 + rnd.uniform(-angle_spread, angle_spread)
        L = rnd.uniform(length * 0.6, length)
        steps = int(L)
        for s in range(steps):
            t = s / max(1, steps - 1)
            w = width * (1 - t) + 0.5
            px = cx + math.cos(ang) * s
            py = cy + math.sin(ang) * s
            for dy in range(-int(w) - 1, int(w) + 2):
                for dx in range(-int(w) - 1, int(w) + 2):
                    d = math.hypot(dx, dy)
                    if d <= w:
                        k = ((int(py) + dy) % N) * N + (int(px) + dx) % N
                        m[k] = max(m.get(k, 0.0), (1 - d / w) * (0.6 + 0.4 * (1 - t)))
    return m


def normal_facets(seed, cells, tilt_deg=22):
    vor = Voronoi(cells, seed)
    rnd = random.Random(seed + 99)
    tilts = {}
    px = []
    for y in range(N):
        for x in range(N):
            cid, f1, f2 = vor.at(x, y)
            t = tilts.get(cid)
            if t is None:
                a = rnd.uniform(0, 2 * math.pi)
                m = math.radians(rnd.uniform(tilt_deg * 0.3, tilt_deg))
                t = (math.cos(a) * math.sin(m), math.sin(a) * math.sin(m), math.cos(m))
                tilts[cid] = t
            e = f2 - f1
            nx, ny, nz = t
            if e < 2.0:  # soften the crease
                k = e / 2.0
                nx, ny = nx * k, ny * k
                nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
            px.append(clamp8(((nx + 1) * 127.5, (ny + 1) * 127.5, (nz + 1) * 127.5)))
    return px



def tex_dotted_grass(base, light, dark, dots, seed, count=900, rmin=1.0, rmax=2.2, clover=False):
    layers = [ValueNoise(4, seed), ValueNoise(8, seed + 1), ValueNoise(16, seed + 2), ValueNoise(32, seed + 3)]
    strokes = strokes_map(500, seed + 4, 12, 1.4)
    rnd = random.Random(seed + 9)
    dotmaps = []
    for i, col in enumerate(dots):
        dotmaps.append((speckle_map(count // len(dots), seed + 20 + i, rmin, rmax), col))
    leaves = {}
    if clover:
        for _ in range(420):
            cx, cy = rnd.random() * N, rnd.random() * N
            r = rnd.uniform(2.0, 3.2)
            for k in range(3):
                a = k * 2 * math.pi / 3 + rnd.random()
                ox, oy = cx + math.cos(a) * r, cy + math.sin(a) * r
                for dy in range(-4, 5):
                    for dx in range(-4, 5):
                        d = math.hypot(dx, dy)
                        if d <= r * 0.9:
                            leaves[((int(oy) + dy) % N) * N + (int(ox) + dx) % N] = 1 - d / (r * 0.9)
    px = []
    for y in range(N):
        for x in range(N):
            n = fbm(layers, x, y)
            c = mix(dark, base, (n - 0.25) * 2.2)
            c = mix(c, light, (n - 0.65) * 3.0)
            k = y * N + x
            s = strokes.get(k)
            if s:
                c = mix(c, light, s * 0.4)
            l = leaves.get(k)
            if l:
                c = mix(c, light, 0.35 + 0.45 * l)
            for m, col in dotmaps:
                d = m.get(k)
                if d:
                    c = mix(c, col, min(1, d * 1.6))
            px.append(clamp8(c))
    return px

# ---------------------------------------------------------------- textures

def tex_grass_like(base, light, dark, stroke, seed):
    layers = [ValueNoise(4, seed), ValueNoise(8, seed + 1), ValueNoise(16, seed + 2), ValueNoise(32, seed + 3)]
    strokes = strokes_map(900, seed + 4, 14, 1.6)
    specks = speckle_map(160, seed + 5, 1.2, 2.4)
    px = []
    for y in range(N):
        for x in range(N):
            n = fbm(layers, x, y)
            c = mix(dark, base, (n - 0.25) * 2.2)
            c = mix(c, light, (n - 0.62) * 3.0)
            k = y * N + x
            s = strokes.get(k)
            if s:
                c = mix(c, stroke, s * 0.55)
            p = specks.get(k)
            if p:
                c = mix(c, light, p * 0.5)
            px.append(clamp8(c))
    return px


def tex_facets(base, light, shadow, edge, seed, cells=8, edge_w=2.5, crack=None, crack_w=1.6, crack_share=0.35, specks=None):
    vor = Voronoi(cells, seed)
    layers = [ValueNoise(4, seed + 1), ValueNoise(16, seed + 2)]
    spk = speckle_map(specks[0], seed + 7, specks[1], specks[2]) if specks else {}
    px = []
    for y in range(N):
        for x in range(N):
            cid, f1, f2 = vor.at(x, y)
            n = fbm(layers, x, y)
            # flat shade per facet with a soft gradient inside, like painted planes
            shade = cid * 0.5 + n * 0.5
            c = mix(shadow, base, 0.35 + shade * 1.1)
            c = mix(c, light, (shade - 0.62) * 2.2)
            e = f2 - f1
            if crack and cid < crack_share and e < crack_w * 2.2:
                c = mix(c, crack, 1 - e / (crack_w * 2.2))
            elif e < edge_w:
                c = mix(c, edge, (1 - e / edge_w) * 0.8)
            p = spk.get(y * N + x)
            if p:
                c = mix(c, specks[3], p)
            px.append(clamp8(c))
    return px


def tex_soft(base, light, dark, seed, specks=None, speck_color=None, pebbles=None):
    layers = [ValueNoise(4, seed), ValueNoise(8, seed + 1), ValueNoise(16, seed + 2), ValueNoise(64, seed + 3)]
    spk = speckle_map(specks[0], seed + 4, specks[1], specks[2]) if specks else {}
    peb = speckle_map(pebbles[0], seed + 5, pebbles[1], pebbles[2]) if pebbles else {}
    px = []
    for y in range(N):
        for x in range(N):
            n = fbm(layers, x, y)
            c = mix(dark, base, (n - 0.2) * 2.0)
            c = mix(c, light, (n - 0.62) * 3.0)
            k = y * N + x
            p = peb.get(k)
            if p:
                rim = 1 - abs(p - 0.25) * 4 if p < 0.5 else 0
                c = mix(c, pebbles[3], min(1, p * 2.5))
                if p < 0.25:
                    c = mix(c, dark, 0.5 * (1 - p * 4))
            s = spk.get(k)
            if s:
                c = mix(c, speck_color, s)
            px.append(clamp8(c))
    return px


def tex_strata(colors, seed, band=22):
    layers = [ValueNoise(4, seed), ValueNoise(16, seed + 1)]
    wob = ValueNoise(8, seed + 2)
    vor = Voronoi(6, seed + 3)
    px = []
    for y in range(N):
        for x in range(N):
            w = (wob.at(x, y) - 0.5) * 30
            idx = int((y + w) / band) % len(colors)
            nxt = colors[(idx + 1) % len(colors)]
            c = colors[idx]
            n = fbm(layers, x, y)
            c = mix(c, nxt, max(0.0, (n - 0.6) * 1.5))
            cid, f1, f2 = vor.at(x, y)
            if f2 - f1 < 1.8:
                c = mix(c, (c[0] * 0.7, c[1] * 0.7, c[2] * 0.75), 0.6)
            frac = ((y + w) / band) % 1.0
            if frac < 0.08:
                c = mix(c, (c[0] * 0.78, c[1] * 0.78, c[2] * 0.8), 0.8)
            px.append(clamp8(c))
    return px



# ---------------------------------------------------------------- Valley ground restyle (2026-09-28)
# Painterly grass: near-white with soft, low-noise value washes and warm light patches; its green comes from the
# terrain Grass (and Mud = forest/slope grass) color, so the grass blades match the ground.

def tex_paint_grass(seed, wash=0.10, warm=0.08, strokes=0, stroke_len=16, stroke_w=2.2, stroke_k=0.10, flecks=0,
                    fleck_r=(1.2, 2.0), base=(236, 240, 232), fleck_color=(255, 255, 250), buds=0, bud_color=(255, 232, 120), bud_r=(1.6, 2.6)):
    big = [ValueNoise(2, seed), ValueNoise(4, seed + 1), ValueNoise(8, seed + 2)]
    warmth = [ValueNoise(2, seed + 5), ValueNoise(4, seed + 6)]
    sm = strokes_map(strokes, seed + 7, stroke_len, stroke_w, angle_spread=0.9) if strokes else {}
    fl = speckle_map(flecks, seed + 8, fleck_r[0], fleck_r[1]) if flecks else {}
    bd = speckle_map(buds, seed + 9, bud_r[0], bud_r[1]) if buds else {}  # little warm flower buds
    px = []
    for y in range(N):
        for x in range(N):
            n = fbm(big, x, y)  # soft value wash
            v = 1 - wash + wash * 2 * max(0.0, min(1.0, (n - 0.2) / 0.6))
            w = max(0.0, (fbm(warmth, x, y) - 0.5) * 2)  # warm, light patches
            c = (base[0] * v + 30 * w * warm * 10, base[1] * v + 18 * w * warm * 10, base[2] * v - 20 * w * warm * 10)
            k = y * N + x
            st = sm.get(k)
            if st:
                c = mix(c, (255, 255, 236), st * stroke_k * 4)
            f = fl.get(k)
            if f:
                c = mix(c, fleck_color, min(1, f * 1.4))
            b = bd.get(k)
            if b:
                c = mix(c, bud_color, min(1, b * 1.6))
            px.append(clamp8(c))
    return px


def slab_field(cells, seed, jitter=0.85):
    """Per pixel: (cell id, edge distance in px) for irregular slabs, tileable."""
    vor = Voronoi(cells, seed, jitter)
    out = []
    for y in range(N):
        for x in range(N):
            cid, f1, f2 = vor.at(x, y)
            out.append((cid, (f2 - f1) / 2))
    return out


def tex_flagstone(field, slab_colors, grout, seed, grout_w=3.0, bevel=9.0, moss=None, moss_share=0.0):
    wash = [ValueNoise(4, seed), ValueNoise(8, seed + 1), ValueNoise(16, seed + 2)]
    mossn = ValueNoise(8, seed + 3)
    px = []
    for i, (cid, e) in enumerate(field):
        x, y = i % N, i // N
        col = slab_colors[int(cid * 997) % len(slab_colors)]
        tint = (cid * 7.31) % 1.0  # per-slab value shift
        col = tuple(v * (0.94 + 0.10 * tint) for v in col)
        n = fbm(wash, x, y)
        c = tuple(v * (0.93 + 0.12 * n) for v in col)
        if e < bevel:  # soft rounded edge: darker toward the grout
            t = e / bevel
            c = mix(tuple(v * 0.80 for v in c), c, t * t * (3 - 2 * t))
        if e < grout_w:
            g = grout
            if moss and mossn.at(x, y) > 1 - moss_share:
                g = moss
            c = mix(g, c, max(0.0, (e - grout_w * 0.5) / (grout_w * 0.5)))
        px.append(clamp8(c))
    return px


def normal_slabs(field, bevel=9.0, strength=2.2):
    h = [min(1.0, e / bevel) for _, e in field]
    h = [t * t * (3 - 2 * t) for t in h]
    px = []
    for y in range(N):
        for x in range(N):
            dx = (h[y * N + (x + 1) % N] - h[y * N + (x - 1) % N]) * strength
            dy = (h[((y + 1) % N) * N + x] - h[((y - 1) % N) * N + x]) * strength
            nx, ny, nz = -dx, dy, 1.0
            l = math.sqrt(nx * nx + ny * ny + nz * nz)
            px.append(clamp8(((nx / l + 1) * 127.5, (ny / l + 1) * 127.5, (nz / l + 1) * 127.5)))
    return px


_SLABS = {}


def slabs(cells, seed):
    key = (cells, seed)
    if key not in _SLABS:
        _SLABS[key] = slab_field(cells, seed)
    return _SLABS[key]


TEXTURES = {
    # Valley ground restyle options (2026-09-28): grass A soft wash, B painted strokes, C sunny meadow with flecks;
    # roads A cream, B honey sandstone with mossy joints, C pale cream/limestone mix (5 x 5 rounded slabs per tile).
    # In use: A (MaterialService Valley_GrassA on Grass + Valley_ForestA on Mud, 48 studs/tile; Valley_RoadA on
    # Brick with valley_road_a_n, 20 studs/tile). Colors come from the terrain material colors (see CLAUDE.md).
    "valley_grass_a": lambda: tex_paint_grass(301, wash=0.07, warm=0.06),
    "valley_grass_b": lambda: tex_paint_grass(311, wash=0.10, warm=0.07, strokes=700, stroke_len=18, stroke_w=2.4, stroke_k=0.05),
    "valley_grass_c": lambda: tex_paint_grass(321, wash=0.08, warm=0.10, flecks=60),
    # D (2026-10-02, kids restyle): clover dots + a few warm buds on a slightly deeper base, for the sunny lawn look
    "valley_grass_d": lambda: tex_paint_grass(331, wash=0.07, warm=0.08, flecks=120, fleck_r=(3.5, 6.0), base=(214, 222, 204), fleck_color=(255, 252, 238), buds=34, bud_r=(5.0, 8.0)),
    # Rock (Simplify 2026-10-04): a calm, near-white painted wash with warm patches and no normal map, so the mountain facets read
    # soft (Roblox's own Rock texture is high contrast); MaterialService Valley_RockA on Rock, 40 studs/tile, color from the
    # terrain Rock color (warm grey-lilac).
    "valley_rock_a": lambda: tex_paint_grass(361, wash=0.06, warm=0.05, base=(238, 234, 232)),
    "valley_road_a": lambda: tex_flagstone(slabs(5, 331), [hexc("EADCBE"), hexc("E2D0AE"), hexc("EFE4CC"), hexc("DCC8A4")], hexc("A88E6A"), 331),
    "valley_road_b": lambda: tex_flagstone(slabs(5, 341), [hexc("E4C99A"), hexc("D8B884"), hexc("ECD4A8"), hexc("CFAE7C")], hexc("8E7452"), 341, moss=hexc("7D8E5E"), moss_share=0.35),
    "valley_road_c": lambda: tex_flagstone(slabs(5, 351), [hexc("F1EADA"), hexc("E6DCC6"), hexc("DCD8CE"), hexc("EDE2C8")], hexc("B4A48A"), 351, grout_w=2.4),
    # Starter Meadow
    # grass is near white: its hue comes from the terrain Grass color, so the ground matches the grass blades
    "grass": lambda: tex_grass_like(hexc("E6EDDD"), hexc("FFFFF4"), hexc("BFCBB2"), hexc("FAFFE6"), 11),
    "ground": lambda: tex_soft(hexc("CFA872"), hexc("E0C08E"), hexc("A9844F"), 21, pebbles=(70, 2.0, 4.2, hexc("E8D7B0"))),
    "rock": lambda: tex_facets(hexc("A39C94"), hexc("C2BBB0"), hexc("8A8D9C"), hexc("7A7479"), 31, cells=10, edge_w=1.5),
    "mud": lambda: tex_soft(hexc("7E6246"), hexc("977A5A"), hexc("5E4632"), 41, pebbles=(40, 1.5, 3.0, hexc("9C8466"))),
    "sand": lambda: tex_soft(hexc("E8D8A0"), hexc("F4E8BE"), hexc("CDBB84"), 51, specks=(120, 0.8, 1.6), speck_color=hexc("C9B37A")),
    "cobble": lambda: tex_facets(hexc("CBC2B2"), hexc("E0D8CA"), hexc("A89E8E"), hexc("7F766A"), 181, cells=9, edge_w=2.6),
    "clover": lambda: tex_dotted_grass(hexc("4E8C34"), hexc("78B84E"), hexc("3A7428"), [hexc("F4F7EE")], 191, count=160, rmin=0.9, rmax=1.6, clover=True),
    "flowermeadow": lambda: tex_dotted_grass(hexc("66AA42"), hexc("8CC85A"), hexc("4E9234"), [hexc("F7A8C8"), hexc("FFE27A"), hexc("FFFFFF"), hexc("C9A2F0")], 201, count=420, rmin=2.6, rmax=4.6),
    # Volcano Peak
    "basalt": lambda: tex_facets(hexc("4C403E"), hexc("62524E"), hexc("352C2C"), hexc("2A2222"), 61, cells=9, crack=hexc("E0642A"), crack_w=1.3, crack_share=0.22),
    "asphalt": lambda: tex_facets(hexc("40363A"), hexc("54474A"), hexc("2C2427"), hexc("221B1D"), 71, cells=6),
    "lava": lambda: tex_facets(hexc("5A2C22"), hexc("6E3A2A"), hexc("3E1E18"), hexc("FF8A2A"), 81, cells=7, edge_w=5.5, crack=hexc("FFB347"), crack_w=3.5, crack_share=0.5),
    # Frozen Cliffs
    "snow": lambda: tex_soft(hexc("F3F8FD"), hexc("FFFFFF"), hexc("D5E3F2"), 91, specks=(90, 0.7, 1.4), speck_color=hexc("FFFFFF")),
    "glacier": lambda: tex_facets(hexc("A6DDF3"), hexc("D8F3FF"), hexc("7FC0E0"), hexc("E8FAFF"), 101, cells=5, edge_w=1.4),
    "limestone": lambda: tex_facets(hexc("C5D2E4"), hexc("E2EAF4"), hexc("9DAEC6"), hexc("8494AE"), 111, cells=7),
    "ice": lambda: tex_soft(hexc("BDE8FF"), hexc("E6F7FF"), hexc("8FCDEE"), 121),
    # Storm Canyon
    "slate": lambda: tex_facets(hexc("61637C"), hexc("777A94"), hexc("4A4C62"), hexc("3C3E52"), 131, cells=8),
    "canyon": lambda: tex_strata([hexc("7E7A94"), hexc("6A6682"), hexc("8E8AA4"), hexc("73708C")], 141),
    # Eclipse Isles
    "violetmoss": lambda: tex_grass_like(hexc("7C5BA8"), hexc("A688D4"), hexc("5A3F86"), hexc("9677C6"), 151),
    "voidstone": lambda: tex_facets(hexc("42325E"), hexc("56437A"), hexc("2E2244"), hexc("241A36"), 161, cells=7, specks=(70, 0.8, 1.6, hexc("CDBDF2"))),
    "templestone": lambda: tex_facets(hexc("9A8EB6"), hexc("B6ACCE"), hexc("7C7098"), hexc("675C84"), 171, cells=5, edge_w=2.0),
}

# normal maps (name -> (seed, cells)) matching the facet color maps above
NORMALS = {
    "rock": (31, 10), "cobble": (181, 9), "basalt": (61, 9), "asphalt": (71, 6), "lava": (81, 7), "glacier": (101, 5),
    "limestone": (111, 7), "slate": (131, 8), "voidstone": (161, 7), "templestone": (171, 5),
}
# rounded-slab normal maps (name -> (cells, seed)) matching the flagstone color maps
SLAB_NORMALS = {"valley_road_a": (5, 331), "valley_road_b": (5, 341), "valley_road_c": (5, 351)}

if __name__ == "__main__":
    names = sys.argv[1:] or list(TEXTURES)
    for name in names:
        t = time.time()
        write_png(os.path.join(OUT, name + ".png"), TEXTURES[name]())
        if name in NORMALS:
            seed, cells = NORMALS[name]
            write_png(os.path.join(OUT, name + "_n.png"), normal_facets(seed, cells))
        if name in SLAB_NORMALS:
            cells, seed = SLAB_NORMALS[name]
            write_png(os.path.join(OUT, name + "_n.png"), normal_slabs(slabs(cells, seed)))
        print(name, round(time.time() - t, 1), "s")
