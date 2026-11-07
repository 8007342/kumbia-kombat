#!/usr/bin/env python3
"""Mācron's held frames large and at game size (75 px tall), each with a red dot on the fixed hand spot. Usage: held_sheet.py <folder> <out.png>."""
import json, pathlib, sys
from PIL import Image, ImageDraw
D = pathlib.Path(sys.argv[1]); M = json.load(open(D / "held.json")); O, H = M["origin"], M["hold"]; names = list(M["frames"])
S = Image.new("RGB", (len(names) * 200, 360), (74, 120, 78)); d = ImageDraw.Draw(S)
for i, n in enumerate(names):
    im = Image.open(D / f"{n}.png").convert("RGBA"); big = im.resize((im.width // 2, im.height // 2), Image.LANCZOS); S.paste(big, (i * 200, 14), big); d.text((i * 200 + 2, 1), n, fill="white")
    d.ellipse([i * 200 + (O[0] + H[0]) // 2 - 2, 14 + (O[1] + H[1]) // 2 - 2, i * 200 + (O[0] + H[0]) // 2 + 2, 14 + (O[1] + H[1]) // 2 + 2], fill=(255, 40, 40))
    k = 75 / 296; sm = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS); S.paste(sm, (i * 200 + 40, 260), sm)
S.save(sys.argv[2]); print(S.size)
