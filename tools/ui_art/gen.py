"""UI art for the UI renewal part 2 (run: python tools/ui_art/gen.py). Writes PNGs to assets/ui/.

- ui_sparkles.png  tileable faint star-sparkle pattern for panels (white on transparent; tinted/faded in Roblox)
- ui_glow.png      soft glow for 9-slicing around panels and cards (white; SliceCenter = Rect(60, 60, 68, 68); the solid body starts 44 px in)
- ui_rays.png      light rays behind reward pop-ups (white, fading out; rotated in Roblox)
- icon_sun.png / icon_moon.png  sky pill icons (painted-ish, dark outline like the other icons)
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui")
os.makedirs(OUT, exist_ok=True)


def sparkle(draw, cx, cy, r, alpha):
    """Four-point star (thin diamond arms) plus a small bright core."""
    w = max(1.0, r * 0.22)
    pts = [(cx, cy - r), (cx + w, cy - w), (cx + r, cy), (cx + w, cy + w), (cx, cy + r), (cx - w, cy + w), (cx - r, cy), (cx - w, cy - w)]
    one = draw.mode == "L"  # masks take a single value
    draw.polygon(pts, fill=alpha if one else (255, 255, 255, alpha))
    core = min(255, alpha + 40)
    draw.ellipse((cx - w, cy - w, cx + w, cy + w), fill=core if one else (255, 255, 255, core))


def gen_sparkles():
    size = 256
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    rng = random.Random(7)
    items = [(rng.uniform(0, size), rng.uniform(0, size), rng.uniform(3, 9), rng.randint(110, 230)) for _ in range(11)]
    dots = [(rng.uniform(0, size), rng.uniform(0, size), rng.uniform(0.8, 1.8), rng.randint(90, 200)) for _ in range(26)]
    for dx in (-size, 0, size):  # draw wrapped copies so the tile repeats seamlessly
        for dy in (-size, 0, size):
            for x, y, r, a in items:
                sparkle(draw, x + dx, y + dy, r, a)
            for x, y, r, a in dots:
                draw.ellipse((x + dx - r, y + dy - r, x + dx + r, y + dy + r), fill=(255, 255, 255, a))
    img.save(os.path.join(OUT, "ui_sparkles.png"))


def gen_glow():
    """Solid rounded body 44 px in from the edges; outside it the alpha falls off smoothly over those 44 px."""
    size, body, radius = 128, 44, 10
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    lo, hi = body + radius, size - body - radius  # centers of the body's corner arcs
    for y in range(size):
        for x in range(size):
            dx = max(lo - x, 0, x - hi)
            dy = max(lo - y, 0, y - hi)
            d = math.hypot(dx, dy) - radius  # distance outside the rounded body (<0 inside)
            t = 1.0 if d <= 0 else max(0.0, 1 - d / body)
            px[x, y] = (255, 255, 255, int(255 * t ** 0.9))
    img.save(os.path.join(OUT, "ui_glow.png"))


def gen_rays():
    size = 512
    c = size / 2
    rays = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(rays)
    count = 16
    for i in range(count):
        a = i / count * math.tau
        half = math.tau / count * 0.36
        draw.polygon([(c, c), (c + math.cos(a - half) * c * 1.5, c + math.sin(a - half) * c * 1.5),
                      (c + math.cos(a + half) * c * 1.5, c + math.sin(a + half) * c * 1.5)], fill=255)
    rays = rays.filter(ImageFilter.GaussianBlur(3))
    # fade out toward the edge
    fade = Image.new("L", (size, size), 0)
    fd = ImageDraw.Draw(fade)
    for r in range(int(c), 0, -2):
        v = int(255 * (1 - r / c) ** 0.7)
        fd.ellipse((c - r, c - r, c + r, c + r), fill=v)
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))  # alpha = rays x fade
    px_r, px_f = rays.load(), fade.load()
    a_img = Image.new("L", (size, size))
    pa = a_img.load()
    for y in range(size):
        for x in range(size):
            pa[x, y] = px_r[x, y] * px_f[x, y] // 255
    out.putalpha(a_img)
    out.save(os.path.join(OUT, "ui_rays.png"))


def radial(size, center, radius, inner, outer):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - center[0], y - center[1]) / radius
            t = min(1.0, d)
            px[x, y] = tuple(int(inner[i] + (outer[i] - inner[i]) * t) for i in range(3)) + (255,)
    return img


def outlined(shape_mask, fill_img, outline=(40, 22, 60), width=6):
    """Fill inside the mask with fill_img, with a dark outline around it and a soft drop shadow."""
    size = shape_mask.size[0]
    grown = shape_mask.filter(ImageFilter.MaxFilter(width * 2 + 1))
    shadow = grown.filter(ImageFilter.GaussianBlur(6))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sh = Image.new("RGBA", (size, size), (10, 6, 30, 0))
    sh.putalpha(Image.eval(shadow, lambda v: v * 110 // 255))
    out.alpha_composite(sh, (0, 6))
    ol = Image.new("RGBA", (size, size), outline + (0,))
    ol.putalpha(grown)
    out.alpha_composite(ol)
    body = fill_img.copy()
    body.putalpha(shape_mask)
    out.alpha_composite(body)
    return out


def highlight(img, mask, box):
    hl = Image.new("L", img.size, 0)
    ImageDraw.Draw(hl).ellipse(box, fill=150)
    hl = hl.filter(ImageFilter.GaussianBlur(10))
    hl = Image.composite(hl, Image.new("L", img.size, 0), mask)
    white = Image.new("RGBA", img.size, (255, 255, 255, 0))
    white.putalpha(hl)
    img.alpha_composite(white)


def gen_sun():
    size = 256
    c = size / 2
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    for i in range(12):  # rays
        a = i / 12 * math.tau
        long = 104 if i % 2 == 0 else 88
        half = 0.2
        d.polygon([(c + math.cos(a - half) * 52, c + math.sin(a - half) * 52),
                   (c + math.cos(a) * long, c + math.sin(a) * long),
                   (c + math.cos(a + half) * 52, c + math.sin(a + half) * 52)], fill=255)
    d.ellipse((c - 62, c - 62, c + 62, c + 62), fill=255)
    fill = radial(size, (c - 20, c - 24), 110, (255, 246, 170), (246, 146, 32))
    img = outlined(mask, fill)
    core = Image.new("L", (size, size), 0)
    ImageDraw.Draw(core).ellipse((c - 58, c - 58, c + 58, c + 58), fill=255)
    highlight(img, core, (c - 44, c - 50, c + 6, c - 12))
    img.save(os.path.join(OUT, "icon_sun.png"))


def gen_moon():
    size = 256
    c = size / 2
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse((c - 84, c - 84, c + 84, c + 84), fill=255)
    d.ellipse((c - 44, c - 110, c + 110, c + 44), fill=0)  # bite -> crescent
    star = Image.new("L", (size, size), 0)
    sparkle(ImageDraw.Draw(star), c + 50, c + 26, 30, 255)
    shape = Image.composite(Image.new("L", (size, size), 255), mask, star)
    fill = radial(size, (c - 40, c + 10), 130, (255, 250, 214), (150, 170, 255))
    img = outlined(shape, fill)
    highlight(img, mask, (c - 72, c - 40, c - 30, c + 30))
    img.save(os.path.join(OUT, "icon_moon.png"))


if __name__ == "__main__":
    gen_sparkles()
    gen_glow()
    gen_rays()
    gen_sun()
    gen_moon()
    print("written to", os.path.abspath(OUT))
