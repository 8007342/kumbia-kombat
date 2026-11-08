#!/usr/bin/env python3
"""Tía Purpurina's close-up drawings, from the Qwen busts (purpurina_bust.py), like salon_bust.py.

Each drawing is scaled by hair-top-to-earring and placed by her gold hoop earring, so her head holds its place
between the cuts while she leans in for the kiss; then snapped to her sprite palette on a 2-pixel grid, on a
380x440 transparent canvas whose bottom edge cuts her waist. Also writes the foreground rail: a strip of the
terrace's balustrade, so her cut-off waist has something in front of it (style guide 8.1, rule 5).

Usage: purpurina_bust_finish.py REST KISS [out dir]. Writes terraza-tp-{rest,kiss}.png and terraza-rail.png, and
prints each drawing's lips pixel (the kiss's contact point)."""
import json, pathlib, sys
import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[3]
SIZE = (380, 440); CELL = 2
D = 120.0          # hair top to earring, in canvas px
EAR_X = 0.52       # the earring's place across the canvas: she leans in toward the right edge


def load(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.int32)


def palette():
    cols = json.loads((ROOT / "tool/art/palettes/purpurina.json").read_text())["colours"]
    cols = [c if isinstance(c, str) else c.get("hex", c.get("colour")) for c in cols]
    return np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in cols])


def anchors(raw):
    """Hair top, and the earring: the gold in the head's band that sits beside the face, not the dress below."""
    a = raw[..., 3] > 128
    r, g, b = raw[..., 0], raw[..., 1], raw[..., 2]
    ys = np.where(a.any(1))[0]; top, bottom = ys.min(), ys.max()
    head = np.zeros_like(a); head[top + int((bottom - top) * .15): top + int((bottom - top) * .42)] = True
    gold = a & head & (r > 170) & (g > 120) & (b < 90) & (r - b > 110)
    gy, gx = np.where(gold)
    return top, float(np.median(gy)), float(np.median(gx))


def lips(raw):
    a = raw[..., 3] > 128
    r, g, b = raw[..., 0], raw[..., 1], raw[..., 2]
    red = a & (r > 170) & (g < 60) & (b < 80)
    ys, xs = np.where(red)
    i = xs.argmax() if len(xs) else 0
    return (float(xs[i]), float(ys[i])) if len(xs) else None


def grid(canvas, pal):
    rows, cols = SIZE[1] // CELL, SIZE[0] // CELL
    idx = ((canvas[..., None, :3] - pal[None, None]) ** 2).sum(-1).argmin(-1)
    idx[canvas[..., 3] <= 128] = -1
    out = np.zeros((rows, cols, 4), np.uint8)
    for y in range(rows):
        for x in range(cols):
            v, c = np.unique(idx[y * CELL:(y + 1) * CELL, x * CELL:(x + 1) * CELL].ravel(), return_counts=True)
            m = v[c.argmax()]
            if m >= 0:
                out[y, x] = (*pal[m], 255)
    return Image.fromarray(out, "RGBA").resize(SIZE, Image.NEAREST)


def rail(out):
    plate = Image.open(ROOT / "art_runs/rooms/terraza/picks/plate-996100-graded.png").convert("RGBA")
    strip = plate.crop((40, 505, 390, 582))       # the balustrade left of the stair head, rail and balusters
    strip = strip.resize((strip.width * 2, strip.height * 2), Image.NEAREST)
    strip.save(out / "terraza-rail.png", optimize=True)
    return strip.size


def main():
    names = ["rest", "kiss"]
    raws = [load(p) for p in sys.argv[1:3]]
    out = pathlib.Path(sys.argv[3] if len(sys.argv) > 3 else ROOT / "assets/art/closeups")
    pal = palette()
    for name, raw in zip(names, raws):
        top, ey, ex = anchors(raw)
        k = D / (ey - top)
        im = Image.fromarray(raw.astype(np.uint8), "RGBA")
        im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
        canvas = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        at = (round(SIZE[0] * EAR_X - ex * k), round(D * 0.25 - top * k))
        canvas.alpha_composite(im, at)
        a = np.asarray(canvas).astype(np.int32)
        a[..., 3] = np.where(a[..., 3] > 128, 255, 0)
        g = grid(a, pal); g.save(out / f"terraza-tp-{name}.png", optimize=True)
        lp = lips(np.asarray(g).astype(np.int32))
        print(name, "scale", round(k, 3), "lips", lp)
    print("rail", rail(out))


if __name__ == "__main__":
    main()
