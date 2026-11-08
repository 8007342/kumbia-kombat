#!/usr/bin/env python3
"""Don Terciopelo's half of the rose handoff: four Qwen busts to the close-up canvas, like nod-bb-*.

Each drawing is aligned to the rest drawing by its head and shoulders, then cut by the rest drawing's box, snapped to
his sprite palette and a 2-pixel grid on a 400x440 transparent canvas whose bottom edge cuts his belly. Qwen redrew the
whole bust each time, so the jacket's folds differ a little between drawings; the head and shoulders line up.
Usage: salon_bust.py REST PLUCK OFFER EMPTY [out dir]. Writes salon-dt-{rest,pluck,offer,empty}.png."""
import json, pathlib, sys
import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[3]
SIZE = (400, 440); CELL = 2


def load(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.int32)


def palette():
    cols = json.loads((ROOT / "tool/art/palettes/terciopelo.json").read_text())["colours"]
    return np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in cols])


def align(rest, other, rows):
    """The shift of `other` that best lays its head and shoulders (rows) over the rest drawing's."""
    a = rest[rows, :, 3] > 128
    best, at = None, (0, 0)
    for dy in range(-40, 41, 2):
        for dx in range(-40, 41, 2):
            b = np.roll(np.roll(other[..., 3] > 128, dy, 0), dx, 1)[rows]
            e = (a ^ b).sum()
            if best is None or e < best:
                best, at = e, (dy, dx)
    return at


def grid(raw, pal, box):
    y0, y1, x0b, x1b = box
    crop = raw[y0:y1, x0b:x1b]
    rows, cols = SIZE[1] // CELL, SIZE[0] // CELL
    k = crop.shape[0] / rows
    w = min(cols, int(crop.shape[1] / k))
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


def anchors(raw):
    """Hair top and the bow tie's centre: the bow tie is the one burgundy thing on him, and it sits under the chin in
    every drawing, so it fixes both scale (top of hair to bow tie) and place."""
    a = raw[..., 3] > 128
    r, g, b = raw[..., 0], raw[..., 1], raw[..., 2]
    tie = a & (r > 55) & (r < 140) & (g < 45) & (b > 15) & (b < 75)
    ys, xs = np.where(tie)
    ty, tx = np.median(ys), np.median(xs)
    col = a[:, int(tx) - 40:int(tx) + 40]
    top = np.where(col.any(1))[0].min()
    return top, ty, tx


def main():
    names = ["rest", "pluck", "offer", "empty"]
    raws = [load(p) for p in sys.argv[1:5]]
    out = pathlib.Path(sys.argv[5] if len(sys.argv) > 5 else ROOT / "assets/art/closeups")
    pal = palette()
    # The common frame, in units of d (hair top to bow tie): margin above the hair, the bottom edge across the belly.
    D = 150.0                         # d on the shared canvas, in raw-scale px
    H = int(D * 2.45); W = int(H * SIZE[0] / SIZE[1])
    for name, raw in zip(names, raws):
        top, ty, tx = anchors(raw)
        k = D / (ty - top)
        im = Image.fromarray(raw.astype(np.uint8), "RGBA")
        im = im.resize((round(im.width * k), round(im.height * k)), Image.NEAREST)
        canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # Bow tie at 40% of the width (he stands left of centre, facing the right), hair top 0.18 d below the edge.
        canvas.alpha_composite(im, (round(W * 0.40 - tx * k), round(D * 0.18 - top * k)))
        grid(np.asarray(canvas).astype(np.int32), pal, (0, H, 0, W)).save(out / f"salon-dt-{name}.png", optimize=True)
        print(name, "scale", round(k, 3))


if __name__ == "__main__":
    main()
