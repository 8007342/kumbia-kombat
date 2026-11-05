#!/usr/bin/env python3
"""Review grid: rows of images on mid grey with a label per row and per cell. usage: grid.py out.png cellh ref.png|- label:a.png,b.png ..."""
import sys
from PIL import Image, ImageDraw
out, ch, ref = sys.argv[1], int(sys.argv[2]), sys.argv[3]
rows = [a.split(":", 1) for a in sys.argv[4:]]
def cell(p):
    im = Image.open(p).convert("RGBA"); k = ch / im.height
    im = im.resize((max(1, int(im.width * k)), ch), Image.LANCZOS if k < 1 else Image.NEAREST)
    bg = Image.new("RGBA", im.size, (150, 150, 155, 255)); bg.alpha_composite(im); return bg.convert("RGB")
data = [(lab, [(p.split("/")[-1], cell(p)) for p in ps.split(",")]) for lab, ps in rows]
refim = cell(ref) if ref != "-" else None
W = max(sum(c.width + 6 for _, c in cs) for _, cs in data) + (refim.width + 12 if refim else 0)
S = Image.new("RGB", (W, (ch + 18) * len(data)), (20, 20, 20)); d = ImageDraw.Draw(S)
for r, (lab, cs) in enumerate(data):
    y = r * (ch + 18); x = 0
    d.text((2, y + 3), lab, fill=(255, 220, 120))
    if refim: S.paste(refim, (0, y + 18)); x = refim.width + 12
    for name, c in cs:
        S.paste(c, (x, y + 18)); d.text((x + 3, y + 21), name[:14], fill=(0, 0, 0)); x += c.width + 6
S.save(out, optimize=True); print(out, S.size)
