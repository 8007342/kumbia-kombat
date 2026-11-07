#!/usr/bin/env python3
"""Layout guides for the oil gulp redraw: Macron from the waist up, so the arm and head have a body, and a chain of moments for
sub-second transitions. Flat shapes only, because enlarged sprite pixels teach Qwen enlarged pixels. Qwen takes a reference's
composition over its words, so pose, glass tilt and level oil are fixed here. usage: guides.py outdir"""
import math, sys
from PIL import Image, ImageDraw, ImageFilter
OUT = sys.argv[1].rstrip("/") + "/"
S = 1664
GREY = (222, 222, 222, 255); INK = (10, 14, 26, 255); IVORY = (250, 230, 190, 255); TEAL = (10, 85, 100, 255); CYAN = (20, 225, 245, 255); SCREEN = (5, 50, 62, 255)
SHOULDER_R = (850, 1010); SHOULDER_L = (235, 1010); CX = 540

def capsule(d, a, b, r, fill):
    d.line([a, b], fill=INK, width=2 * r + 24); d.line([a, b], fill=fill, width=2 * r)
    for p in (a, b):
        d.ellipse([p[0] - r - 12, p[1] - r - 12, p[0] + r + 12, p[1] + r + 12], fill=INK); d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=fill)

def ball(d, c, r, fill):
    d.ellipse([c[0] - r - 12, c[1] - r - 12, c[0] + r + 12, c[1] + r + 12], fill=INK); d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=fill)
    d.ellipse([c[0] - r * .55, c[1] - r * .7, c[0] - r * .05, c[1] - r * .4], fill=(70, 190, 200, 255))

def arm(d, shoulder, hand):
    dx, dy = hand[0] - shoulder[0], hand[1] - shoulder[1]; L = math.hypot(dx, dy); ux, uy = dx / L, dy / L
    ball(d, shoulder, 78, TEAL)
    wrist = (hand[0] - ux * 92, hand[1] - uy * 92); start = (shoulder[0] + ux * 60, shoulder[1] + uy * 60)
    capsule(d, start, wrist, 80, IVORY)
    for t in (150, 215):
        p = (wrist[0] - ux * t, wrist[1] - uy * t); nx, ny = -uy * 84, ux * 84
        d.line([(p[0] - nx, p[1] - ny), (p[0] + nx, p[1] + ny)], fill=CYAN, width=34)
    ball(d, hand, 96, TEAL)

def head(angle, glow, thick):
    H = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(H); cx, k = CX, .72
    def R(x0, y0, x1, y1): return [cx + x0 * k, 40 + y0 * k, cx + x1 * k, 40 + y1 * k]
    d.line([(cx, 40 + 330 * k), (cx, 40 + 150 * k)], fill=INK, width=66); d.line([(cx, 40 + 330 * k), (cx, 40 + 150 * k)], fill=TEAL, width=36)
    d.ellipse(R(-95, 20, 95, 210), fill=INK); d.ellipse(R(-78, 37, 78, 193), fill=CYAN)
    for ex in (-610, 500):
        d.rounded_rectangle(R(ex, 500, ex + 110, 880), 36, fill=INK); d.rounded_rectangle(R(ex + 14, 514, ex + 96, 866), 28, fill=TEAL)
    d.rounded_rectangle(R(-565, 240, 565, 1120), 280, fill=INK); d.rounded_rectangle(R(-545, 260, 545, 1100), 270, fill=IVORY)
    d.rounded_rectangle(R(-395, 470, 395, 930), 122, fill=INK); d.rounded_rectangle(R(-375, 490, 375, 910), 112, fill=SCREEN)
    for ex in (-180, 180):
        d.arc(R(ex - 105, 600, ex + 105, 810), 195, 345, fill=glow, width=thick)
    return H.rotate(angle, center=(CX, 860), resample=Image.BICUBIC)

def body(d):
    d.rounded_rectangle([CX - 72, 800, CX + 72, 930], 30, fill=INK); d.rectangle([CX - 56, 800, CX + 56, 930], fill=TEAL)
    d.rounded_rectangle([CX - 300, 900, CX + 300, 1800], 200, fill=INK); d.rounded_rectangle([CX - 284, 916, CX + 284, 1800], 186, fill=IVORY)
    ball(d, (CX, 1210), 92, CYAN)

def glass(im, rim, tilt, level, length=440, width=320):
    """Rim centre, axis tilted from straight up by tilt degrees to the right. Oil stays level: inside the glass, below y=level."""
    d = ImageDraw.Draw(im); a = math.radians(tilt); ax, ay = math.sin(a), math.cos(a); nx, ny = ay, -ax
    base = (rim[0] + ax * length, rim[1] + ay * length)
    poly = [(rim[0] - nx * width / 2, rim[1] - ny * width / 2), (rim[0] + nx * width / 2, rim[1] + ny * width / 2),
            (base[0] + nx * width * .44, base[1] + ny * width * .44), (base[0] - nx * width * .44, base[1] - ny * width * .44)]
    d.polygon(poly, fill=(236, 244, 246, 255), outline=INK, width=18)
    mx, my = sum(p[0] for p in poly) / 4, sum(p[1] for p in poly) / 4
    mask = Image.new("L", (S, S), 0); md = ImageDraw.Draw(mask); md.polygon([(q[0] * .9 + mx * .1, q[1] * .9 + my * .1) for q in poly], fill=255); md.rectangle([0, 0, S, level], fill=0)
    oil = Image.new("RGBA", (S, S), (18, 8, 6, 255)); ImageDraw.Draw(oil).line([(0, level + 6), (S, level + 6)], fill=(230, 130, 30, 255), width=14)
    im.paste(oil, (0, 0), mask); return base

def scene(name, head_angle, rim, tilt, level, hand, smear=(), glow=CYAN, thick=34, spark=None):
    im = Image.new("RGBA", (S, S), GREY); d = ImageDraw.Draw(im)
    arm(d, SHOULDER_L, (118, 1370)); body(d); im.alpha_composite(head(head_angle, glow, thick))
    for cx, cy, r in smear: d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(22, 10, 8, 255))
    if rim: glass(im, rim, tilt, level)
    arm(ImageDraw.Draw(im), SHOULDER_R, hand)
    im.filter(ImageFilter.GaussianBlur(2)).convert("RGB").save(OUT + f"guide_{name}.png")

SMEAR = [(770, 770, 20), (800, 800, 13)]
scene("reach", 0, None, 0, 0, (1230, 1000))
scene("gulp1", 4, (790, 745), 58, 730, (1190, 1000))
scene("gulp2", 8, (790, 735), 78, 775, (1225, 880), SMEAR[:1])
scene("gulp3", 12, (790, 725), 96, 745, (1215, 750), SMEAR)
scene("gulp4", 17, (790, 715), 116, 815, (1170, 610), SMEAR + [(760, 825, 9)], thick=44)
scene("relief", -4, (1250, 1010), 12, 1405, (1290, 1300), SMEAR, thick=56)
