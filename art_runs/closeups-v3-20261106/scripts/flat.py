#!/usr/bin/env python3
"""Lay a folder's PNGs in a row on a dark ground, in the named order, to look at. usage: flat.py out.png zoom dir prefix name [name...]"""
import sys
from PIL import Image
out, zoom, folder, prefix, names = sys.argv[1], float(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5:]
ims = [Image.open(f"{folder}/{prefix}{n}.png").convert("RGBA") for n in names]; ims = [i.resize((round(i.width * zoom), round(i.height * zoom)), Image.NEAREST) for i in ims]
cols = min(4, len(ims)); rows = (len(ims) + cols - 1) // cols; w = max(i.width for i in ims); h = max(i.height for i in ims)
S = Image.new("RGBA", (cols * (w + 8) + 8, rows * (h + 8) + 8), (46, 40, 52, 255))
for n, i in enumerate(ims): S.alpha_composite(i, (8 + n % cols * (w + 8), 8 + n // cols * (h + 8)))
S.save(out)
