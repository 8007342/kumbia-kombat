#!/usr/bin/env python3
"""CPU layout guides for Macron's gulp and reach: head from the hero atlas, arm and glass from flat shapes. Qwen takes a reference's
composition over its words, so position, tilt, level oil and the arm's exit are fixed here. Softened so Qwen doesn't copy big pixels."""
import json, math
from PIL import Image, ImageDraw, ImageFilter
R = "/work/tmp/imagegen/kumbia/oil-gulp/in/"
GREY = (222, 222, 222, 255); INK = (10, 14, 26, 255); IVORY = (250, 230, 190, 255); TEAL = (10, 85, 100, 255); CYAN = (20, 225, 245, 255)
frames = json.load(open("assets/art/party/manifest.json"))["atlases"]["hero"]["frames"]
atlas = Image.open("assets/art/party/macron-dance-v1.png").convert("RGBA")
x, y, w, h = frames["front_idle"]["rect"]; fr = atlas.crop((x, y, x + w, y + h)); fr.putalpha(fr.split()[3].point(lambda v: 255 if v >= 128 else 0))
head = fr.crop((0, 0, w, 160)); head = head.crop(head.getbbox())  # antenna to chin
S = 1664

def capsule(d, a, b, r, fill):
    d.line([a, b], fill=INK, width=2 * r + 28); d.line([a, b], fill=fill, width=2 * r)
    for p in (a, b):
        d.ellipse([p[0] - r - 14, p[1] - r - 14, p[0] + r + 14, p[1] + r + 14], fill=INK); d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=fill)

def ball(d, c, r, fill, shine=(70, 190, 200, 255)):
    d.ellipse([c[0] - r - 14, c[1] - r - 14, c[0] + r + 14, c[1] + r + 14], fill=INK); d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=fill)
    d.ellipse([c[0] - r * .55, c[1] - r * .7, c[0] - r * .05, c[1] - r * .4], fill=shine)

def arm(d, wrist, hand, corner, mr):
    """corner -> wrist forearm with two bands near the wrist, then the mitten."""
    capsule(d, corner, wrist, 118, IVORY)
    dx, dy = wrist[0] - corner[0], wrist[1] - corner[1]; L = math.hypot(dx, dy); ux, uy = dx / L, dy / L
    for t in (250, 370):
        p = (wrist[0] - ux * t, wrist[1] - uy * t); nx, ny = -uy * 124, ux * 124
        d.line([(p[0] - nx, p[1] - ny), (p[0] + nx, p[1] + ny)], fill=CYAN, width=52)
    ball(d, wrist, 74, TEAL); ball(d, hand, mr, TEAL)

def glass(d, rim, tilt, length, width, level):
    """Tumbler from rim centre along its axis; opening points tilt degrees left of up. Oil stays level: everything below y=level."""
    a = math.radians(tilt); ax, ay = math.sin(a), math.cos(a); nx, ny = ay, -ax
    base = (rim[0] + ax * length, rim[1] + ay * length)
    poly = [(rim[0] - nx * width / 2, rim[1] - ny * width / 2), (rim[0] + nx * width / 2, rim[1] + ny * width / 2),
            (base[0] + nx * width * .44, base[1] + ny * width * .44), (base[0] - nx * width * .44, base[1] - ny * width * .44)]
    d.polygon(poly, fill=(236, 244, 246, 255), outline=INK, width=20)
    # oil: clip the inner glass to below the level line
    inner = [(rim[0] * .93 + base[0] * .07 + q[0] - (rim[0] if i < 2 else base[0]) * 0, 0) for i, q in enumerate(poly)]
    mask = Image.new("L", (S, S), 0); md = ImageDraw.Draw(mask)
    shrink = [(q[0] * .9 + sum(p[0] for p in poly) / 4 * .1, q[1] * .9 + sum(p[1] for p in poly) / 4 * .1) for q in poly]
    md.polygon(shrink, fill=255); md.rectangle([0, 0, S, level], fill=0)
    oil = Image.new("RGBA", (S, S), (18, 8, 6, 255)); ImageDraw.Draw(oil).line([(0, level + 6), (S, level + 6)], fill=(230, 130, 30, 255), width=16)
    return oil, mask

def vector_head(angle, glow=(30, 235, 250, 255)):
    """Flat head from the atlas's proportions. No atlas pixels: an enlarged sprite teaches Qwen enlarged pixels (24 raw against 13)."""
    H = Image.new("RGBA", (1500, 1300), (0, 0, 0, 0)); d = ImageDraw.Draw(H); cx = 700
    d.line([(cx, 330), (cx, 150)], fill=INK, width=90); d.line([(cx, 330), (cx, 150)], fill=TEAL, width=50)
    d.ellipse([cx - 95, 20, cx + 95, 210], fill=INK); d.ellipse([cx - 78, 37, cx + 78, 193], fill=CYAN)
    for ex in (cx - 610, cx + 500):
        d.rounded_rectangle([ex, 500, ex + 110, 880], 50, fill=INK); d.rounded_rectangle([ex + 14, 514, ex + 96, 866], 40, fill=TEAL)
    d.rounded_rectangle([cx - 565, 240, cx + 565, 1120], 390, fill=INK); d.rounded_rectangle([cx - 545, 260, cx + 545, 1100], 375, fill=IVORY)
    d.rounded_rectangle([cx - 395, 470, cx + 395, 930], 170, fill=INK); d.rounded_rectangle([cx - 375, 490, cx + 375, 910], 155, fill=(5, 50, 62, 255))
    for ex in (cx - 180, cx + 180):
        d.arc([ex - 105, 600, ex + 105, 810], 195, 345, fill=glow, width=46)
    return H.rotate(angle, expand=False, resample=Image.BICUBIC)

def gulp(name, head_angle, rim, tilt, level, smear):
    im = Image.new("RGBA", (S, S), GREY); d = ImageDraw.Draw(im)
    im.alpha_composite(vector_head(head_angle), (0, 0))
    for (cx, cy, r) in smear: d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(22, 10, 8, 255))
    oil, mask = glass(d, rim, tilt, 620, 440, level); im.paste(oil, (0, 0), mask)
    arm(d, (1000, 1440), (1210, 1350), (-160, 1800), 170)
    im.filter(ImageFilter.GaussianBlur(2)).convert("RGB").save(R + f"guide_{name}.png")

gulp("gulp", 10, (1010, 860), 52, 985, [(800, 1000, 30), (850, 1020, 22), (750, 1005, 18)])
gulp("low", 14, (1010, 830), 64, 1150, [(800, 980, 30), (850, 1005, 22), (750, 985, 18), (830, 1060, 14)])
im = Image.new("RGBA", (1344, 1152), GREY); d = ImageDraw.Draw(im)
arm(d, (830, 620), (1040, 520), (-160, 1000), 180)
im.filter(ImageFilter.GaussianBlur(3)).convert("RGB").save(R + "guide_reach.png")
d2 = Image.new("RGBA", (w + 80, h + 60), GREY); d2.alpha_composite(fr, (40, 30)); d2.convert("RGB").resize(((w + 80) * 2, (h + 60) * 2), Image.NEAREST).save(R + "mac_front2.png")
