#!/usr/bin/env python3
"""Mācron turning under a held hand, puppeted from his own accepted drawings so he stays exactly on model: each body is an atlas frame with one arm erased, plus the raised arm cut from `arm_sweep`, rotated and stretched a little from its shoulder to one fixed spot.
Every drawing is on one canvas with its anchor on the floor point and HOLD at the same offset from it, so the hand stays still while he turns beneath it. Polygons are in that atlas frame's own pixels, read off a grid. Writes PNGs and held.json to the given folder. Run from the worktree root."""
import json, math, pathlib, sys
import numpy as np
from PIL import Image, ImageDraw
OUT = pathlib.Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
hero = json.load(open("assets/art/party/manifest.json"))["atlases"]["hero"]
ATLAS = Image.open("assets/art/party/" + hero["image"]).convert("RGBA")
HOLD = (-100, -195)  # the held hand from the floor point, in atlas pixels
CANVAS, ORIGIN = (360, 330), (200, 310)  # floor point on the canvas
def frame(name):
    f = hero["frames"][name]; x, y, w, h = f["rect"]
    return ATLAS.crop((x, y, x + w, y + h)), tuple(f["anchor"])
def erase(im, poly):
    mask = Image.new("L", im.size, 255); ImageDraw.Draw(mask).polygon(poly, fill=0)
    out = im.copy(); out.putalpha(Image.composite(out.getchannel("A"), Image.new("L", im.size, 0), mask)); return out
ARM_POLY = [(0, 40), (52, 40), (52, 72), (55, 85), (58, 105), (66, 130), (72, 148), (70, 170), (40, 170), (25, 130), (0, 90)]
ARM_S, ARM_F = (58, 148), (28, 62)  # shoulder ball, and the fist's top, in arm_sweep
def arm_piece():
    im, _ = frame("arm_sweep"); keep = Image.new("L", im.size, 0); ImageDraw.Draw(keep).polygon(ARM_POLY, fill=255)
    out = im.copy(); out.putalpha(Image.composite(out.getchannel("A"), Image.new("L", im.size, 0), keep)); return out
# name, source, flip, polygon erased, shoulder in the source frame. The held arm always reaches toward her and goes behind his head, so nothing covers his face; he turns on the spot beneath it.
T = [
    ("held_front", "arm_sweep", False, ARM_POLY, (58, 148)),
    ("held_front34", "spin_front", False, [(0, 140), (46, 140), (60, 155), (95, 163), (95, 205), (0, 205)], (110, 180)),
    ("held_side", "profile", False, [(0, 148), (60, 148), (60, 200), (0, 200)], (65, 168)),
    ("held_rear34", "spin_rear", False, [(0, 135), (78, 135), (78, 195), (0, 195)], (92, 170)),
    ("held_rear", "rear_finish", False, [(0, 118), (45, 118), (60, 140), (78, 155), (78, 190), (0, 190)], (92, 170)),
    ("held_rear34b", "spin_rear", True, [(190, 150), (215, 150), (225, 140), (256, 135), (256, 195), (190, 195)], (175, 172)),
    ("held_sideb", "profile", True, [(134, 150), (212, 150), (212, 200), (134, 200)], (118, 172)),
    ("held_front34b", "spin_front", True, [(216, 150), (228, 128), (278, 110), (280, 190), (222, 190), (216, 175)], (202, 160)),
]
NUDGE = {"held_front34b": 22, "held_front34": 8}  # keeps the wide tilted head off the hand
def tidy(im):
    """Keep the one connected figure: erasing and rotating leave stray specks."""
    a = np.array(im); solid = a[..., 3] >= 128; seen = np.zeros(solid.shape, bool); best = []
    for start in zip(*np.nonzero(solid)):
        if seen[start]: continue
        stack, blob = [start], []; seen[start] = True
        while stack:
            y, x = stack.pop(); blob.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < solid.shape[0] and 0 <= nx < solid.shape[1] and solid[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True; stack.append((ny, nx))
        if len(blob) > len(best): best = blob
    keep = np.zeros(solid.shape, bool); ys, xs = zip(*best); keep[np.array(ys), np.array(xs)] = True
    a[~keep] = 0; return Image.fromarray(a)
piece = arm_piece(); result = {}
for name, source, flip, poly, shoulder in T:
    body, anchor = frame(source); body = erase(body, poly); w = body.width
    if flip:
        body = body.transpose(Image.FLIP_LEFT_RIGHT); anchor = (w - anchor[0], anchor[1]); shoulder = (w - shoulder[0], shoulder[1])
    ox = NUDGE.get(name, 0)
    bx, by = ORIGIN[0] + ox - anchor[0], ORIGIN[1] - anchor[1]
    S = (bx + shoulder[0], by + shoulder[1]); H = (ORIGIN[0] + HOLD[0], ORIGIN[1] + HOLD[1])
    vx, vy = H[0] - S[0], H[1] - S[1]; v0 = (ARM_F[0] - ARM_S[0], ARM_F[1] - ARM_S[1])
    k = math.hypot(vx, vy) / math.hypot(*v0); turn = math.atan2(vy, vx) - math.atan2(v0[1], v0[0])
    if k > 1.3: print("stretch", name, round(k, 2))
    c, s = math.cos(turn) * k, math.sin(turn) * k
    # Maps canvas back to the arm's own pixels: rotate and stretch about the shoulder.
    det = c * c + s * s; a, b, d, e = c / det, s / det, -s / det, c / det
    arm = piece.transform(CANVAS, Image.AFFINE, (a, b, ARM_S[0] - a * S[0] - b * S[1], d, e, ARM_S[1] - d * S[0] - e * S[1]), Image.BICUBIC)
    A = arm.getchannel("A").point(lambda v: 255 if v >= 128 else 0); arm.putalpha(A)
    out = Image.new("RGBA", CANVAS, (0, 0, 0, 0)); layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0)); layer.paste(body, (bx, by))
    out.alpha_composite(arm); out.alpha_composite(layer); out = tidy(out)
    out.save(OUT / f"{name}.png"); result[name] = {"stretch": round(k, 3), "bodyOffset": ox}; print(name, result[name])
json.dump({"hold": HOLD, "origin": ORIGIN, "frames": result}, open(OUT / "held.json", "w"), indent=1)
