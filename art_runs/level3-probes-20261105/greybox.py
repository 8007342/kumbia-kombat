#!/usr/bin/env python3
"""Throwaway probe: author a shift-lens greybox for the angled pool lawn, plus its floor calibration.

Coordinates: s runs along the path, t to the path's right, z up, unit = one standing adult. The camera
has no roll and vertical lines stay vertical, so standing height at a floor point depends only on its
image y: height = (y - horizon) / eye_height. Writes guide, id map, calibration and a review overlay.
"""
import json, math, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

W, H = 1024, 1536
OUT = Path(sys.argv[1])
HORIZON = 0.20 * H
EYE = 3.0            # adults above the floor
F = 900.0
VP_U = 1000.0        # where the path vanishes on the horizon
START_U = 250.0      # where the path's centre meets the bottom edge
PATH_W = 2.4
PATH_END = 11.0

a = math.atan((VP_U - W / 2) / F)
d = np.array([math.sin(a), math.cos(a)])
n = np.array([math.cos(a), -math.sin(a)])
y0 = F * EYE / (H - HORIZON)
p0 = np.array([(START_U - W / 2) * y0 / F, y0])

def proj(s, t, z=0.0):
    x, y = p0 + s * d + t * n
    return (W / 2 + F * x / y, HORIZON + F * (EYE - z) / y)

def homography():
    src = [(0, -1), (0, 1), (8, -1), (8, 1)]
    A, b = [], []
    for (s, t) in src:
        u, v = proj(s, t)
        A.append([s, t, 1, 0, 0, 0, -u * s, -u * t]); b.append(u)
        A.append([0, 0, 0, s, t, 1, -v * s, -v * t]); b.append(v)
    h = np.linalg.solve(np.array(A, float), np.array(b, float))
    return np.append(h, 1).reshape(3, 3)

COL = dict(sky=(20, 28, 70), trees=(14, 60, 50), lawn=(70, 140, 60), path=(165, 150, 130), joint=(95, 85, 75),
           hedge=(20, 90, 60), wall=(235, 220, 185), roof=(170, 80, 50), glass=(120, 170, 190),
           inner=(90, 75, 70), water=(30, 200, 220), deck=(215, 205, 180), table=(250, 250, 250),
           parasol=(245, 170, 90), gate=(235, 220, 185), pot=(190, 90, 50))
IDS = {k: i + 1 for i, k in enumerate(COL)}
col = Image.new("RGB", (W, H), COL["sky"])
idm = Image.new("L", (W, H), IDS["sky"])
dc, di = ImageDraw.Draw(col), ImageDraw.Draw(idm)

NEAR = 0.5

def depth(q):
    return float((p0 + q[0] * d + q[1] * n)[1])

def clip(world):
    """Clip a world polygon to the camera's near plane, so geometry behind it can't fold over."""
    out = []
    for i, a_ in enumerate(world):
        b_ = world[(i + 1) % len(world)]
        da, db = depth(a_) - NEAR, depth(b_) - NEAR
        if da >= 0:
            out.append(a_)
        if (da >= 0) != (db >= 0):
            k = da / (da - db)
            out.append(tuple(a_[j] + k * (b_[j] - a_[j]) for j in range(3)))
    return out

def poly(pts, name, fill=None):
    pts = [tuple(p) for p in pts]
    dc.polygon(pts, fill=fill or COL[name]); di.polygon(pts, fill=IDS[name])

def wpoly(world, name, fill=None):
    w = clip([tuple(q) + (0.0,) * (3 - len(q)) for q in world])
    if len(w) >= 3:
        poly([proj(*q) for q in w], name, fill)

def ground(s0, s1, t0, t1, name):
    wpoly([(s0, t0), (s0, t1), (s1, t1), (s1, t0)], name)

def box(s0, s1, t0, t1, z, name, top=None, zb=0.0):
    """Painter order: only the two faces towards the camera, then the top."""
    faces = [((s0, t0), (s0, t1)), ((s0, t0), (s1, t0)), ((s1, t1), (s1, t0)), ((s1, t1), (s0, t1))]
    for (a0, a1) in faces[:2]:
        wpoly([(*a0, zb), (*a1, zb), (*a1, z), (*a0, z)], name)
    wpoly([(s0, t0, z), (s0, t1, z), (s1, t1, z), (s1, t0, z)], top or name)

def table(s, t, parasol=True):
    u, v = proj(s, t)
    scale = (v - HORIZON) / EYE
    r = 0.22 * scale
    top = proj(s, t, 0.42)[1]
    dc.rectangle([u - r * .12, top, u + r * .12, v], fill=COL["table"]); di.rectangle([u - r * .12, top, u + r * .12, v], fill=IDS["table"])
    dc.ellipse([u - r, top - r * .35, u + r, top + r * .35], fill=COL["table"]); di.ellipse([u - r, top - r * .35, u + r, top + r * .35], fill=IDS["table"])
    if parasol:
        pz = proj(s, t, 1.05)[1]
        dc.rectangle([u - r * .07, pz, u + r * .07, top], fill=COL["table"]); di.rectangle([u - r * .07, pz, u + r * .07, top], fill=IDS["table"])
        poly([(u - r * 2.0, pz + r * .55), (u + r * 2.0, pz + r * .55), (u, pz - r * .8)], "parasol")

# far background
dc.rectangle([0, 0, W, HORIZON + 4], fill=COL["sky"]); di.rectangle([0, 0, W, HORIZON + 4], fill=IDS["sky"])
tree = [(0, 180), (90, 150), (210, 175), (330, 140), (470, 170), (620, 135), (760, 165), (900, 130), (W, 160), (W, HORIZON + 8), (0, HORIZON + 8)]
poly(tree, "trees")
# lawn: everything below the horizon
dc.rectangle([0, HORIZON + 6, W, H], fill=COL["lawn"]); di.rectangle([0, HORIZON + 6, W, H], fill=IDS["lawn"])

# covered pool house, top left: an open arcade facing the lawn and camera (its s0 side)
PS0, PS1, PT0, PT1 = 9.0, 17.0, -13.5, -5.0
WALL = 2.6
# back wall and far side first
wpoly([(PS1, PT0), (PS1, PT1), (PS1, PT1, WALL), (PS1, PT0, WALL)], "inner")
wpoly([(PS0, PT1), (PS1, PT1), (PS1, PT1, WALL), (PS0, PT1, WALL)], "glass")
wpoly([(PS0, PT0), (PS1, PT0), (PS1, PT0, WALL), (PS0, PT0, WALL)], "inner")
ground(PS0, PS1, PT0, PT1, "deck")
ground(PS0 + 0.5, PS1 - 1.0, PT0 + 0.8, PT1 - 0.8, "water")
for c in np.linspace(PT0, PT1, 5):          # front columns
    poly([proj(PS0, c - .18), proj(PS0, c + .18), proj(PS0, c + .18, WALL), proj(PS0, c - .18, WALL)], "wall")
for c in np.linspace(PS0, PS1, 5):          # path-side columns
    poly([proj(c, PT1 - .18), proj(c, PT1 + .18), proj(c, PT1 + .18, WALL), proj(c, PT1 - .18, WALL)], "wall")
wpoly([(PS0, PT0, WALL), (PS0, PT1, WALL), (PS0, PT1, WALL + .35), (PS0, PT0, WALL + .35)], "wall")
wpoly([(PS0, PT1, WALL), (PS1, PT1, WALL), (PS1, PT1, WALL + .35), (PS0, PT1, WALL + .35)], "wall")
mid_s, mid_t = (PS0 + PS1) / 2, (PT0 + PT1) / 2
wpoly([(PS0, PT0, WALL + .35), (PS0, PT1, WALL + .35), (mid_s, mid_t, WALL + 1.6)], "roof")
wpoly([(PS0, PT1, WALL + .35), (PS1, PT1, WALL + .35), (mid_s, mid_t, WALL + 1.6)], "roof", fill=(140, 65, 42))

# far tables, then path, near tables
for s, t in [(7.0, -3.2), (5.2, -6.5), (4.4, -9.6)]:
    table(s, t)
ground(-3, PATH_END, -PATH_W / 2, PATH_W / 2, "path")
for sj in np.arange(0, PATH_END, 1.5):
    a0, a1 = proj(sj, -PATH_W / 2), proj(sj, PATH_W / 2)
    dc.line([a0, a1], fill=COL["joint"], width=3); di.line([a0, a1], fill=IDS["joint"], width=3)
for tj in (-PATH_W / 2, -PATH_W / 6, PATH_W / 6, PATH_W / 2):
    a0, a1 = proj(-1.2, tj), proj(PATH_END, tj)
    dc.line([a0, a1], fill=COL["joint"], width=3); di.line([a0, a1], fill=IDS["joint"], width=3)
# hedge along the path's right, gate at its far end
box(-3, PATH_END, PATH_W / 2 + .25, PATH_W / 2 + 1.0, 0.8, "hedge")
g0, g1 = -PATH_W / 2 - .45, PATH_W / 2 + .45
box(PATH_END, PATH_END + .4, g0 - .35, g0, 2.1, "gate")
box(PATH_END, PATH_END + .4, g1, g1 + .35, 2.1, "gate")
wpoly([(PATH_END, g0, 2.1), (PATH_END, g1, 2.1), (PATH_END, g1, 2.5), (PATH_END, g0, 2.5)], "gate")
for s, t in [(2.6, -3.1), (2.6, -6.2), (5.0, -3.0), (0.6, -2.4)]:
    table(s, t)

OUT.mkdir(parents=True, exist_ok=True)
col.save(OUT / "greybox-1024.png")
idm.save(OUT / "greybox-ids-1024.png")
small = col.resize((832, 1248), Image.LANCZOS); small.save(OUT / "greybox.png")
Hm = homography()
calib = {
    "image": [W, H], "horizonY": HORIZON / H, "vanishingX": VP_U / W, "eyeHeightAdults": EYE, "focalPx": F,
    "pathWidthAdults": PATH_W, "pathEndS": PATH_END,
    "standingHeightPerFootY": H / H / EYE,
    "floorHomography_st_to_px": Hm.tolist(), "ids": IDS,
    "note": "Adult height at foot y, as a fraction of image height: (y - horizonY) / eyeHeightAdults",
}
(OUT / "floor.json").write_text(json.dumps(calib, indent=1))
# check the homography against the projector, and the runtime formula against vertical projection
err = 0.0
for s in np.linspace(-1, 10, 12):
    for t in np.linspace(-6, 2, 9):
        u, v = proj(s, t); q = Hm @ np.array([s, t, 1]); err = max(err, abs(q[0] / q[2] - u), abs(q[1] / q[2] - v))
        if v > HORIZON + 20:
            h1 = v - proj(s, t, 1.0)[1]; h2 = (v - HORIZON) / EYE; err = max(err, abs(h1 - h2))
print("max homography/height error px", round(err, 6))
# review overlay: phone crop, sample adults
ov = col.copy(); dv = ImageDraw.Draw(ov)
vis = (180 / (844 / 390 * 180)) / (W / H) ; x0 = W * (1 - vis) / 2
dv.rectangle([x0, 0, W - x0, H - 1], outline=(255, 0, 255), width=4)
dv.line([0, HORIZON, W, HORIZON], fill=(255, 255, 0), width=2)
for s in [0, 2, 4, 6, 8]:
    u, v = proj(s, 0); h = (v - HORIZON) / EYE
    dv.rectangle([u - h * .17, v - h, u + h * .17, v], outline=(255, 255, 255), width=3)
    dv.rectangle([u + h * .3 - h * .07, v - .35 * h, u + h * .3 + h * .07, v], outline=(0, 255, 255), width=3)
ov.save(OUT / "greybox-overlay.png")
print("phone 390x844 visible width fraction", round(vis, 3), "x range", round(x0), round(W - x0))
