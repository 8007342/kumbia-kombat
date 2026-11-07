#!/usr/bin/env python3
"""BlinBlin's half of the matched nod, from two Qwen drawings: the arms-crossed bust, and the same bust with his
head bowed and eyes closed. Qwen redrew the whole body in the second, a little moved, so only its head is kept:
it is aligned to the first drawing by the body, and pasted onto the first drawing's body. Nothing below the
collar changes between drawings. `up` is the rest drawing with the head a little lowered, the way back up.

Both drawings go to the sprite's palette and a 2-pixel grid, like the other close-ups, on a 400x440 canvas whose
bottom edge cuts his belly. Usage: nod_blinblin.py REST.png DOWN.png [out dir]. Writes nod-bb-{rest,down,up}.png.
"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[3]
SIZE = (400, 440)
CELL = 2
SPLIT = (260, 330)   # raw rows: above the first the head drawing wins outright; between, only near the middle
BAND = 80            # raw px either side of the face's middle, in the blended rows


def load(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.int32)


def align(rest, down):
    """The shift of `down` that best lays its body (below the collar) over the rest drawing's."""
    a, b = rest[400:, :, 3] > 128, down[:, :, 3] > 128
    best, at = None, (0, 0)
    for dy in range(-16, 17, 2):
        for dx in range(-16, 17, 2):
            sb = np.roll(np.roll(b, dy, 0), dx, 1)[400:]
            e = (a ^ sb).sum()
            if best is None or e < best:
                best, at = e, (dy, dx)
    return at


def palette():
    cols = json.loads((ROOT / "tool/art/palettes/blinblin.json").read_text())["colours"]
    return np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in cols])


def grid(raw, pal, box):
    """Bust to canvas: fit the rest drawing's height, palette by nearest colour, then one colour per cell by majority.
    Every drawing uses the rest drawing's box, or a head that rises would rescale the whole bust."""
    y0, y1, x0b, x1b = box
    crop = raw[y0:y1, x0b:x1b]
    rows, cols = SIZE[1] // CELL, SIZE[0] // CELL
    k = crop.shape[0] / rows
    w = int(crop.shape[1] / k)
    out = np.zeros((rows, cols, 4), np.uint8)
    x0 = (cols - w) // 2
    idx = ((crop[..., None, :3] - pal[None, None]) ** 2).sum(-1).argmin(-1)
    idx[crop[..., 3] <= 128] = -1
    for y in range(rows):
        for x in range(w):
            block = idx[int(y * k):max(int((y + 1) * k), int(y * k) + 1), int(x * k):max(int((x + 1) * k), int(x * k) + 1)].ravel()
            v, c = np.unique(block, return_counts=True)
            m = v[c.argmax()]
            if m >= 0:
                out[y, x0 + x] = (*pal[m], 255)
    return Image.fromarray(out, "RGBA").resize(SIZE, Image.NEAREST)


def main():
    rest, down = load(sys.argv[1]), load(sys.argv[2])
    out = pathlib.Path(sys.argv[3] if len(sys.argv) > 3 else ROOT / "assets/art/closeups")
    dy, dx = align(rest, down)
    down = np.roll(np.roll(down, dy, 0), dx, 1)
    ys, xs = np.where(rest[:SPLIT[0], :, 3] > 128)
    mid = int(np.median(xs))
    nod = rest.copy()
    nod[:SPLIT[0]] = down[:SPLIT[0]]
    band = slice(max(0, mid - BAND), mid + BAND)
    nod[SPLIT[0]:SPLIT[1], band] = np.where(down[SPLIT[0]:SPLIT[1], band, 3:4] > 128, down[SPLIT[0]:SPLIT[1], band], rest[SPLIT[0]:SPLIT[1], band])
    up = rest.copy()
    lift = 8
    head = rest[:SPLIT[0]]
    up[:SPLIT[0] + lift] = np.concatenate([np.zeros_like(rest[:lift]), up[lift:SPLIT[0] + lift]])
    up[lift:SPLIT[0] + lift] = np.where(head[..., 3:4] > 128, head, up[lift:SPLIT[0] + lift])
    pal = palette()
    ys, xs = np.where(rest[..., 3] > 128)
    box = (max(0, ys.min() - 12), ys.max() + 1, xs.min(), xs.max() + 1)
    for name, im in (("rest", rest), ("down", nod), ("up", up)):
        grid(im, pal, box).save(out / f"nod-bb-{name}.png", optimize=True)
    print("aligned by", (dy, dx), "->", out)


if __name__ == "__main__":
    main()
