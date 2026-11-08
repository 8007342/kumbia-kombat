#!/usr/bin/env python3
"""The gallery's source plate for layers: the accepted plate 993301 with the far-left portrait repainted at full
length, so its gentleman has shoes to tap (room life at full party). One Qwen edit of a 144x180 box at 3x
(layers-galeria-20261108/portrait-full-993400.png, words in tool/art/rooms/layers/galeria.json), aligned by
inplace.align and pasted inside the gilt frame only. Writes art_runs/rooms/galeria/picks/plate-993301-full.png.
Run from the repo root with the art venv. CPU, seconds."""
from pathlib import Path
import sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, str(Path(__file__).resolve().parent))
from inplace import align

CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"
SRC = Path("art_runs/rooms/galeria/picks/plate-993301.png")
OUT = Path("art_runs/rooms/galeria/picks/plate-993301-full.png")
BOX = (226, 214, 370, 394)
FRAME = [(248, 237), (346, 237), (346, 372), (248, 372)]  # the gilt frame, below the picture light

plate = Image.open(SRC).convert("RGB")
crop = plate.crop(BOX)
poly = [[x - BOX[0], y - BOX[1]] for x, y in FRAME]
small, shift = align(Image.open(CACHE / "layers-galeria-20261108/portrait-full-993400.png"), crop, [poly])
m = Image.new("L", crop.size, 0); ImageDraw.Draw(m).polygon([tuple(p) for p in poly], fill=255)
inside = np.asarray(m) > 0
out = np.asarray(plate).copy()
region = out[BOX[1]:BOX[3], BOX[0]:BOX[2]]
region[inside] = small.astype(np.uint8)[inside]
Image.fromarray(out).save(OUT, optimize=True)
print(OUT, "shift", shift)
