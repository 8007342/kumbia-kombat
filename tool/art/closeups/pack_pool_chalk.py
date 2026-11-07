#!/usr/bin/env python3
"""The billiards close-up's Mācron: the lawn's drawings, plus the blue chalk dot on the antenna's ball.

No GPU. Only the dot's pixels differ from the duet-macron-* drawing each frame starts from, so nothing flickers when
frames swap. A dot from a cube of chalk, in a blue well apart from the antenna's cyan, with a dark ring so it reads
small. The contact point is the dot's centre, in image pixels: pool-chalk-art.json.

Usage: pack_pool_chalk.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

DIR = Path("assets/art/closeups")
CENTRE = (200, 22)   # the crown of the antenna ball
RADIUS = 9
BLUE, SHADE, INK = (58, 96, 224), (34, 62, 170), (10, 26, 46)
GRID = 3


def dot(a: np.ndarray) -> None:
    cx, cy = CENTRE
    for y in range(cy - RADIUS - GRID, cy + RADIUS + GRID + 1, GRID):
        for x in range(cx - RADIUS - GRID, cx + RADIUS + GRID + 1, GRID):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            colour = None
            if d <= RADIUS - 1:
                colour = SHADE if (x - cx) + (y - cy) > RADIUS * 0.7 else BLUE
            elif d <= RADIUS + GRID - 1:
                colour = INK
            if colour:
                a[y:y + GRID, x:x + GRID, :3] = colour
                a[y:y + GRID, x:x + GRID, 3] = 255


for name in ("round", "wide", "squash", "arc", "arc-blush"):
    a = np.array(Image.open(DIR / f"duet-macron-{name}.png").convert("RGBA"))
    dot(a)
    Image.fromarray(a).save(DIR / f"pool-macron-{name}.png")
(DIR / "pool-chalk-art.json").write_text(json.dumps({"macronContact": list(CENTRE), "note": "Image pixels on pool-macron-*.png, where the chalk dot sits on the antenna."}, indent=1) + "\n")
print("wrote 5 frames, contact", CENTRE)
