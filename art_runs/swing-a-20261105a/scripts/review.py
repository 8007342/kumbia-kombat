#!/usr/bin/env python3
"""Eye-review sheet: per pose, the skeleton then each candidate, labelled by seed.
Usage: review.py <run> <out.png> <cell height> <pose> [pose ...]"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw
run, out, ch, poses = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4:]
RAW = Path.home() / ".cache/tillandsias-project/kumbia-art" / run / "raw"
LANE = Path("/work/tmp/imagegen/kumbia") / run / "in"
cw = int(ch * 0.8)
rows = [(p, sorted((RAW / p).glob("*.png"))) for p in poses]
cols = 1 + max((len(c) for _, c in rows), default=0)
sheet = Image.new("RGB", (cols * cw, len(rows) * ch), (20, 20, 20))
d = ImageDraw.Draw(sheet)
def cell(path):
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, (150, 150, 155, 255))
    bg.alpha_composite(im)
    return bg.convert("RGB").resize((cw, ch), Image.LANCZOS)
for r, (pose, cs) in enumerate(rows):
    y = r * ch
    sk = LANE / f"{pose}.skeleton.png"
    if sk.exists():
        sheet.paste(cell(sk), (0, y))
    d.text((3, y + 2), pose, fill=(255, 255, 0))
    for c, p in enumerate(cs):
        sheet.paste(cell(p), ((c + 1) * cw, y))
        d.text(((c + 1) * cw + 3, y + 2), p.stem[-2:], fill=(255, 255, 0))
sheet.save(out)
