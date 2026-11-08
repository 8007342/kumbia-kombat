#!/usr/bin/env python3
"""Fireworks over a room's sky, as room layers: each burst is a `pulse` prop whose frame 0 is empty (the plate as
painted) and whose last frame is the full bloom, so the game's pulse plays it from nothing to a bloom on the beat
and back, at a size set by the crowd's swing and the tier (kind `light`: it grows with every tier). Drawn as pixels
by code, no GPU, on the plate's 2-pixel grid, and clipped to the painted sky so palms, strings and the city stay in
front of every burst.

Spec: tool/art/rooms/fireworks/<room>.json
  {"plate": "<plate png>", "atlas": "<room>/<room>-fireworks.png", "cell": 2, "frames": 6,
   "sky": {"maxY": .34, "rule": {...}}, "bursts": [{"id", "at": [x, y] plate px, "r": px, "colours": "gold",
   "spokes": 18, "periodBeats": 8, "phaseBeats": 0, "instance": 1, "seed": 1}]}
Writes the atlas to assets/art/<atlas>, the level's `layers.props` entries to art_runs/rooms/<room>/fireworks-level.json,
and a review sheet (every frame over the plate, and a bloom-everything still) to the art cache.

Usage: fireworks.py <room> [--sheet]
"""
from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"
GUTTER = 2  # RoomLayerProp.gutter

# core, main, dim, ember: no pure white (style guide 2), and nothing from the audience's reserved pinks and plums.
RAMPS = {
    "gold": [(255, 240, 196), (255, 204, 84), (214, 128, 34), (120, 60, 24)],
    "turquoise": [(222, 252, 246), (70, 216, 206), (24, 132, 140), (14, 70, 84)],
    "red": [(255, 226, 196), (242, 78, 58), (168, 36, 40), (90, 22, 32)],
    "green": [(234, 252, 214), (120, 220, 96), (44, 132, 58), (22, 72, 40)],
    "white": [(250, 246, 232), (214, 222, 240), (140, 156, 196), (70, 80, 120)],
}


def sky_mask(plate: np.ndarray, rule: dict, max_y: int, cell: int) -> np.ndarray:
    """Painted sky: dark, blue over red, above max_y. Eroded by one cell so no burst touches a frond's edge."""
    r, g, b = (plate[..., i].astype(int) for i in range(3))
    lum = .3 * r + .59 * g + .11 * b
    m = (b > r + rule.get("blueOverRed", 12)) & (b >= g) & (lum < rule.get("maxLuma", 95))
    m[max_y:] = False
    # cell-wise: a cell is sky only if every pixel in it and its 4 neighbours is
    h, w = m.shape
    cm = m[: h // cell * cell, : w // cell * cell].reshape(h // cell, cell, w // cell, cell).all(axis=(1, 3))
    e = cm.copy()
    e[1:] &= cm[:-1]; e[:-1] &= cm[1:]; e[:, 1:] &= cm[:, :-1]; e[:, :-1] &= cm[:, 1:]
    out = np.zeros_like(m)
    out[: h // cell * cell, : w // cell * cell] = np.repeat(np.repeat(e, cell, 0), cell, 1)
    return out


def burst_frame(k: int, frames: int, b: dict, cell: int, size: tuple[int, int]) -> Image.Image:
    """Frame k of a burst on a canvas of `size` with the burst centre at b['_c'] (canvas px)."""
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    if k == 0:
        return im
    d = ImageDraw.Draw(im)
    core, main, dim, ember = RAMPS[b.get("colours", "gold")]
    cx, cy = b["_c"]
    R = b["r"]
    rnd = random.Random(b.get("seed", 1) * 100 + k)

    def dot(x, y, col, n=1):
        x0 = int(x // cell * cell); y0 = int(y // cell * cell)
        if 0 <= x0 < size[0] and 0 <= y0 < size[1]:
            d.rectangle([x0, y0, x0 + cell * n - 1, y0 + cell * n - 1], fill=(*col, 255))

    if k == 1:
        # the rocket: a short rising streak with a bright head, and the first flash at the centre
        for i in range(7):
            dot(cx + (i % 2) * .5, cy + R * .55 - i * R * .07, [ember, dim, dim, main, main, core, core][i])
        dot(cx - cell, cy - cell, core, 2)
        return im
    u = (k - 1) / (frames - 2)              # 0 at the first ring .. 1 at full bloom
    r = R * (.28 + .72 * u ** .75)
    droop = R * .16 * u * u                 # sparks fall a little as the bloom opens
    n = b.get("spokes", 18)
    for s in range(n):
        a = 2 * math.pi * (s + .5 * (s % 2) * (b.get("seed", 1) % 2)) / n + b.get("twist", 0)
        rr = r * (.88 + .12 * ((s * 7) % 3) / 2)
        length = .3 + .25 * u                # the streak behind each spark lengthens as it flies
        steps = 9
        for t in range(steps):
            f = 1 - length * t / (steps - 1)
            x = cx + math.cos(a) * rr * f
            y = cy + math.sin(a) * rr * f + droop * f * f
            q = t / (steps - 1)
            col = (core if u < 1 else main) if q < .15 else main if q < .45 else dim if q < .8 else ember
            dot(x, y, col)
        # the spark's head, two cells, at the streak's tip
        hx = cx + math.cos(a) * rr; hy = cy + math.sin(a) * rr + droop
        dot(hx - cell / 2, hy - cell / 2, core if u < 1 else main, 2)
    if u >= .5:
        # a second, inner ring of glitter
        for s in range(n // 2):
            a = 2 * math.pi * (s + .25) / (n // 2)
            dot(cx + math.cos(a) * r * .45, cy + math.sin(a) * r * .45 + droop * .3, dim if u >= 1 else main)
    if u >= .75:
        for _ in range(int(10 * u)):        # loose twinkles round the bloom
            a = rnd.random() * 2 * math.pi; q = r * (.6 + .5 * rnd.random())
            dot(cx + math.cos(a) * q, cy + math.sin(a) * q + droop, core if rnd.random() < .4 else dim)
    if u < .5:
        dot(cx - cell / 2, cy - cell / 2, core, 2)
    return im


def build(room: str, sheet: bool) -> dict:
    spec = json.loads((ROOT / "tool/art/rooms/fireworks" / f"{room}.json").read_text())
    plate_im = Image.open(ROOT / spec["plate"]).convert("RGB")
    plate = np.asarray(plate_im)
    H, W = plate.shape[:2]
    cell, frames = spec.get("cell", 2), spec.get("frames", 6)
    mask = sky_mask(plate, spec.get("sky", {}).get("rule", {}), int(spec["sky"]["maxY"] * H), cell)
    props, strips = [], []
    for b in spec["bursts"]:
        pad = int(b["r"] * 1.35) + 2 * cell
        left = max(0, (int(b["at"][0]) - pad) // cell * cell)
        top = max(0, (int(b["at"][1]) - pad) // cell * cell)
        right = min(W, int(b["at"][0]) + pad); bottom = min(int(spec["sky"]["maxY"] * H), int(b["at"][1]) + pad)
        w, h = right - left, bottom - top
        b["_c"] = (b["at"][0] - left, b["at"][1] - top)
        clip = Image.fromarray((mask[top:bottom, left:right] * 255).astype(np.uint8), "L")
        row = []
        for k in range(frames):
            f = burst_frame(k, frames, b, cell, (w, h))
            a = np.asarray(f).copy(); a[..., 3] = np.minimum(a[..., 3], np.asarray(clip))
            row.append(Image.fromarray(a, "RGBA"))
        strips.append((b, left, top, w, h, row))
    aw = max(len(r[5]) * (r[3] + GUTTER) for r in strips)
    ah = sum(r[4] + GUTTER for r in strips)
    atlas = Image.new("RGBA", (aw, ah), (0, 0, 0, 0))
    y = 0
    for b, left, top, w, h, row in strips:
        for k, f in enumerate(row):
            atlas.paste(f, (k * (w + GUTTER), y))
        props.append({"id": b["id"], "atlas": spec["atlas"], "atlasY": y, "left": left, "top": top, "width": w, "height": h,
                      "frames": frames, "motion": "pulse", "periodBeats": b.get("periodBeats", 8),
                      "phaseBeats": b.get("phaseBeats", 0), "instance": b.get("instance", 1), "kind": b.get("kind", "light")})
        y += h + GUTTER
        # the loader's rules (room_layers.dart): out of the tap band and the quiet box behind the opponent
        x0, x1, y0, y1 = left / W, (left + w) / W, top / H, (top + h) / H
        assert y1 <= .65, f"{b['id']} reaches the tap band"
        assert not (x1 > .35 and x0 < .65 and y1 > .3 and y0 < .6), f"{b['id']} reaches the quiet box ({x0:.2f}-{x1:.2f}, {y0:.2f}-{y1:.2f})"
    out = ROOT / "assets/art" / spec["atlas"]
    out.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(out, optimize=True)
    frag = {"plateWidth": W, "plateHeight": H, "props": props}
    (ROOT / "art_runs/rooms" / room).mkdir(parents=True, exist_ok=True)
    (ROOT / "art_runs/rooms" / room / "fireworks-level.json").write_text(json.dumps(frag, indent=1) + "\n")
    if sheet:
        cdir = CACHE / f"fireworks-{room}"; cdir.mkdir(parents=True, exist_ok=True)
        for k in range(frames):
            im = plate_im.convert("RGBA")
            for b, left, top, w, h, row in strips:
                im.alpha_composite(row[k], (left, top))
            im.crop((0, 0, W, int(spec["sky"]["maxY"] * H) + 40)).save(cdir / f"frame-{k}.png")
        Image.fromarray((mask * 255).astype(np.uint8)).save(cdir / "sky-mask.png")
        print("sheet", cdir)
    return frag


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("room"); ap.add_argument("--sheet", action="store_true")
    a = ap.parse_args()
    frag = build(a.room, a.sheet)
    print(json.dumps({"props": [(p["id"], p["left"], p["top"], p["width"], p["height"]) for p in frag["props"]]}))
