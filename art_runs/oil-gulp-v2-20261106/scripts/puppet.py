#!/usr/bin/env python3
"""Oil gulp frames as a puppet: head, torso and arm cut from one Qwen drawing, the glass and oil drawn by code.
Qwen clung to its key frame's glass, so tilt and oil level barely changed between moments, and redrawing the robot would flicker.
Here only the pose changes, and the oil's volume falls exactly. All output shares one pixel grid. usage: puppet.py reach.png outdir"""
import math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageChops, ImageFilter
SRC, OUT = sys.argv[1], sys.argv[2].rstrip("/") + "/"
S, GRID, FINAL = 1664, 208, 416
INK = (6, 12, 28, 255); GLASS = (226, 240, 244, 255); SHINE = (255, 255, 255, 255); OIL = (20, 9, 8, 255); OIL2 = (58, 26, 14, 255); AMBER = (232, 134, 30, 255)
HEAD_PIVOT = (665, 880); ARM_PIVOT = (975, 1045); ARM_LEN = 405; NECK = (600, 880, 730, 960)
src = Image.open(SRC).convert("RGBA")
src.putalpha(src.split()[3].point(lambda v: 255 if v >= 128 else 0))

def snap(im):
    """One output pixel per grid cell: the cell's majority colour, so rotated edges stay clean instead of fuzzy."""
    a = np.asarray(im, dtype=np.uint32); n = S // GRID; h = (a[..., 0] << 24 | a[..., 1] << 16 | a[..., 2] << 8 | a[..., 3]) * (a[..., 3] >= 128)
    out = np.zeros((GRID, GRID, 4), dtype=np.uint8)
    for y in range(GRID):
        for x in range(GRID):
            v, c = np.unique(h[y * n:(y + 1) * n, x * n:(x + 1) * n], return_counts=True); w = int(v[c.argmax()])
            out[y, x] = (w >> 24 & 255, w >> 16 & 255, w >> 8 & 255, w & 255)
    return Image.fromarray(out, "RGBA")

def tidy(im):
    """Clear lone outline pixels and fill notches, so an edge has no ragged teeth."""
    a = np.array(im); solid = a[..., 3] > 0
    for _ in range(2):
        n = np.zeros(solid.shape, dtype=int)
        n[1:] += solid[:-1]; n[:-1] += solid[1:]; n[:, 1:] += solid[:, :-1]; n[:, :-1] += solid[:, 1:]
        ys, xs = np.where(~solid & (n >= 3))
        for y, x in zip(ys, xs):
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if 0 <= y + dy < a.shape[0] and 0 <= x + dx < a.shape[1] and solid[y + dy, x + dx]: a[y, x] = a[y + dy, x + dx]; break
        a[solid & (n <= 1)] = 0; solid = a[..., 3] > 0
    return Image.fromarray(a, "RGBA")

def mask(box):
    m = Image.new("L", (S, S), 0); ImageDraw.Draw(m).rectangle(box, fill=255); return m

def cut(m):
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0)); out.paste(src, (0, 0), m); return out

head = cut(mask([0, 0, S, 878])); arm = cut(mask([946, 930, 1310, 1185]))
_m = Image.new("L", (S, S), 0); ImageDraw.Draw(_m).ellipse([1276, 935, 1490, 1150], fill=255); mitt = cut(_m); body = cut(ImageChops.subtract(mask([0, 878, S, S]), mask([945, 930, S, 1185])))

def flare(im, grow):
    """Thicken the cyan eye arcs on the face screen."""
    if not grow: return im
    box = (440, 460, 900, 600); part = im.crop(box); cy = Image.new("L", part.size, 0); px = part.load(); q = cy.load()
    for y in range(part.height):
        for x in range(part.width):
            r, g, b, a = px[x, y]
            if a and g > 180 and b > 180 and r < 120: q[x, y] = 255
    big = cy.filter(ImageFilter.MaxFilter(grow)); fill = Image.new("RGBA", part.size, (40, 255, 255, 255)); part.paste(fill, (0, 0), big); im = im.copy(); im.paste(part, box[:2]); return im

def smear(im, spots):
    d = ImageDraw.Draw(im)
    for x, y, r in spots: d.ellipse([x - r, y - r, x + r, y + r], fill=OIL)
    return im

def glass_points(rim, tilt, length, width):
    a = math.radians(tilt); ax, ay = math.sin(a), math.cos(a); nx, ny = ay, -ax
    base = (rim[0] + ax * length, rim[1] + ay * length)
    return [(rim[0] - nx * width / 2, rim[1] - ny * width / 2), (rim[0] + nx * width / 2, rim[1] + ny * width / 2),
            (base[0] + nx * width * .42, base[1] + ny * width * .42), (base[0] - nx * width * .42, base[1] - ny * width * .42)], (ax, ay), (nx, ny), base

def poly_mask(points, size=GRID):
    k = size / S; m = Image.new("L", (size, size), 0); ImageDraw.Draw(m).polygon([(x * k, y * k) for x, y in points], fill=255); return m

def level_for(points, fraction):
    """The y whose level oil fills this fraction of the inside. Binary search on the pixels, so the volume falls exactly."""
    m = poly_mask(points, 832); total = sum(1 for v in m.tobytes() if v)
    lo, hi = 0, 832
    for _ in range(14):
        mid = (lo + hi) / 2; c = m.copy(); ImageDraw.Draw(c).rectangle([0, 0, 832, mid], fill=0)
        n = sum(1 for v in c.tobytes() if v)
        if n / total > fraction: lo = mid
        else: hi = mid
    return hi * 2

def draw_glass(frame, rim, tilt, fraction, length=400, width=300):
    """Directly on the output grid: outline, clear glass, level oil with an amber edge, a thick base, one highlight."""
    pts, axis, normal, base = glass_points(rim, tilt, length, width); k = GRID / S
    mx, my = sum(p[0] for p in pts) / 4, sum(p[1] for p in pts) / 4; inner = [(p[0] * .86 + mx * .14, p[1] * .86 + my * .14) for p in pts]
    d = ImageDraw.Draw(frame); d.polygon([(x * k, y * k) for x, y in pts], fill=INK); d.polygon([(x * k, y * k) for x, y in inner], fill=GLASS)
    y = level_for(inner, fraction)
    oil = poly_mask(inner); ImageDraw.Draw(oil).rectangle([0, 0, GRID, y * k], fill=0)
    frame.paste(Image.new("RGBA", (GRID, GRID), OIL), (0, 0), oil)
    edge = poly_mask(inner); ImageDraw.Draw(edge).rectangle([0, 0, GRID, y * k], fill=0); ImageDraw.Draw(edge).rectangle([0, y * k + 2, GRID, GRID], fill=0)
    frame.paste(Image.new("RGBA", (GRID, GRID), AMBER), (0, 0), edge)
    sh = [(rim[0] + normal[0] * width * .3 + axis[0] * length * t, rim[1] + normal[1] * width * .3 + axis[1] * length * t) for t in (.14, .52)]
    d.line([(x * k, yy * k) for x, yy in sh], fill=SHINE, width=2)
    return pts, axis, normal, base

def arm_to(hand):
    """Rotate and stretch the arm about the shoulder so the mitten lands on hand. The stretch stays small."""
    dx, dy = hand[0] - ARM_PIVOT[0], hand[1] - ARM_PIVOT[1]; L = math.hypot(dx, dy); ang = math.degrees(math.atan2(-dy, dx)); stretch = L / ARM_LEN
    st = arm.transform((S, S), Image.AFFINE, (1 / stretch, 0, ARM_PIVOT[0] * (1 - 1 / stretch), 0, 1, 0), Image.NEAREST)
    mi = mitt.transform((S, S), Image.AFFINE, (1, 0, -(ARM_PIVOT[0] + ARM_LEN) * (stretch - 1), 0, 1, 0), Image.NEAREST)
    return st.rotate(ang, center=ARM_PIVOT, resample=Image.NEAREST), mi.rotate(ang, center=ARM_PIVOT, resample=Image.NEAREST), stretch

def render(name, head_angle, rim=None, tilt=0, fraction=0, grow=0, spots=(), hand=None):
    H = smear(flare(head, grow), spots).rotate(head_angle, center=HEAD_PIVOT, resample=Image.NEAREST)
    big = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(big); d.rectangle(NECK, fill=(5, 70, 85, 255)); big.alpha_composite(body); big.alpha_composite(H)
    frame = snap(big)
    if rim:
        length = 460; width = 330
        pts, axis, normal, base = glass_points(rim, tilt, length, width)
        # The mitten cups the glass at whichever spot on its base or lower half the unstretched arm reaches best.
        spots_on = [(base[0] - axis[0] * length_back + side * normal[0] * across, base[1] - axis[1] * length_back + side * normal[1] * across)
                    for length_back in (-60, -20, 40, 100, 160, 230, 300, 360) for side in ((1,) if normal[1] > 0 else (-1,)) for across in (0, 80, 140, 180)]
        grip = hand or min(spots_on, key=lambda q: abs(math.hypot(q[0] - ARM_PIVOT[0], q[1] - ARM_PIVOT[1]) - ARM_LEN))
    else:
        grip = hand or (ARM_PIVOT[0] + ARM_LEN, ARM_PIVOT[1])
    A, M, stretch = arm_to(grip); frame.alpha_composite(snap(A))
    if rim: draw_glass(frame, rim, tilt, fraction, length, width)
    frame.alpha_composite(snap(M))
    tidy(frame).resize((FINAL, FINAL), Image.NEAREST).save(OUT + name + ".png", optimize=True); print(name, "arm stretch %.2f" % stretch)

SP1 = [(880, 800, 14)]; SP2 = SP1 + [(925, 775, 10)]; SP3 = SP2 + [(860, 835, 9)]
render("reach", 0)
render("gulp1", 3, (925, 690), 52, .92)
render("gulp2", 7, (925, 680), 70, .70, spots=SP1)
render("gulp3", 11, (920, 670), 86, .45, spots=SP2)
render("gulp4", 15, (915, 660), 102, .22, grow=9, spots=SP2)
render("gulp5", 19, (905, 650), 118, .06, grow=13, spots=SP3)
render("relief", -3, (1230, 860), 7, .03, grow=21, spots=SP3)
