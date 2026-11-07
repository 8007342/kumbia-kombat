#!/usr/bin/env python3
"""Where the model's drawn-in partner sleeve starts, and her hand just before it, in each candidate of a pose: the first column on the picture's right with a run of neutral dark grey. Prints a cut x and a hand spot for picks.json. Usage: find_hand.py <pose> [...]."""
import pathlib, sys
import numpy as np
from PIL import Image
RAW = pathlib.Path.home() / ".cache/tillandsias-project/kumbia-art/pair-20261106/raw"
for pose in sys.argv[1:]:
    for png in sorted((RAW / pose).glob("[0-9]*.png")):
        a = np.array(Image.open(png).convert("RGBA")).astype(int); r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
        grey = (al > 128) & (abs(r - g) < 10) & (abs(g - b) < 10) & (r > 28) & (r < 80)
        cols = grey[:500].sum(axis=0); x = next((i for i in range(450, 768) if cols[i:i + 6].min() >= 8), None)
        if x is None: print(pose, png.stem, "no sleeve"); continue
        skin = (al > 128) & (r > g + 25) & (g > b) & (r > 90)
        band = skin[:500, x - 45:x]; ys = np.nonzero(band.sum(axis=1) > 2)[0]
        print(pose, png.stem, "cut", x - 1, "hand", [x - 30, int(np.median(ys)) if len(ys) else None])
