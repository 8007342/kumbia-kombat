#!/usr/bin/env python3
"""Lay real-renderer stills side by side at game size, labelled. Usage: montage.py out.png in.png [in.png ...]. Crops off the empty tap band, since art stops above it."""
import pathlib, sys
from PIL import Image, ImageDraw
names = sys.argv[2:]; W, H = 390, 600
S = Image.new("RGB", (len(names) * (W + 8), H + 16), (30, 30, 30)); d = ImageDraw.Draw(S)
for i, n in enumerate(names):
    S.paste(Image.open(n).convert("RGB").crop((0, 0, W, H)), (i * (W + 8), 16)); d.text((i * (W + 8) + 2, 2), pathlib.Path(n).stem, fill="white")
S.save(sys.argv[1]); print(S.size)
