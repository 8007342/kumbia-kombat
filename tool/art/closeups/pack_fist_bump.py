#!/usr/bin/env python3
"""Pack the fist bump close-up from research raws into assets/art/closeups.

Each raw is painted on a loose grid of about 8 pixels per art pixel, so it is reduced to that
grid with nearest sampling and cropped to its alpha. The anchor is the knuckle point that meets
the other fist, in art pixels, and is written to fist-bump.json for the shot player.
"""
import json, os, sys
import numpy as np
from PIL import Image

RAW = os.path.expanduser("~/.cache/tillandsias-project/kumbia-art/closeups-20261105/raw/")
OUT = "assets/art/closeups/"
BLOCK = 8
PIECES = {
    "gk-approach": "gk-approach2/990500",
    "gk-impact": "gk-impact/990000",
    "mc-approach": "mc-approach2/990700",
    "mc-impact": "mc-impact/990001",
}
PLATE = "plate-garden2/990101"


def reduce(path, extend=0):
    im = Image.open(path).convert("RGBA")
    im = im.resize((im.width // BLOCK, im.height // BLOCK), Image.NEAREST)
    a = np.array(im)
    a[a[:, :, 3] < 128] = 0
    a[a[:, :, 3] >= 128, 3] = 255
    if extend:
        # Continue a forearm that leaves through the bottom edge: repeat its last
        # row, sliding left, so the arm runs off the screen instead of ending.
        h, w = a.shape[:2]
        out = np.zeros((h + extend, w, 4), a.dtype)
        out[:h] = a
        last = a[h - 2]
        for k in range(extend):
            out[h + k] = np.roll(last, -(k + 2), axis=0)
            out[h + k, w - (k + 2):] = 0
        a = out
    return Image.fromarray(a)


def main():
    meta = {"pieces": {}}
    for name, raw in PIECES.items():
        im = reduce(RAW + raw + ".png", extend=48 if name.startswith("mc") else 0)
        a = np.array(im)[:, :, 3] > 0
        ys, xs = np.where(a)
        # The contact point: the fist's leading edge at the mean height of its leading column band.
        gk = name.startswith("gk")
        edge = xs.min() if gk else xs.max()
        band = ys[np.abs(xs - edge) < 4]
        meta["pieces"][name] = {
            "file": f"{name}.png",
            "size": [im.width, im.height],
            "contact": [int(edge), int(band.mean())],
        }
        im.save(OUT + name + ".png", optimize=True)
    plate = Image.open(RAW + PLATE + ".png").convert("RGB")
    plate = plate.resize((plate.width // 4, plate.height // 4), Image.NEAREST)
    plate.save(OUT + "garden-plate.png", optimize=True)
    meta["plate"] = {"file": "garden-plate.png", "size": list(plate.size)}
    json.dump(meta, open(OUT + "fist-bump-art.json", "w"), indent=1)
    print(json.dumps(meta))


main()
