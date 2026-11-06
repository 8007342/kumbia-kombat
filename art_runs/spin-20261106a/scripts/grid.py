#!/usr/bin/env python3
"""A review grid of raw candidates: one row per pose, seeds as columns, optional reference first. usage: grid.py out.png [--ref image[:x,y,w,h]] pose [pose ...]"""
import sys, pathlib
from PIL import Image, ImageDraw
R = pathlib.Path.home() / ".cache/tillandsias-project/kumbia-art/spin-20261106a/raw"
args = sys.argv[1:]; out = args.pop(0); ref = None
if args[0] == "--ref": args.pop(0); ref = args.pop(0)
CW, CH = 300, 375; BG = (150, 150, 155, 255)
rows = [(p, sorted((R / p).glob("*.png"), key=lambda q: int(q.stem))) for p in args]
cols = max(len(r[1]) for r in rows) + (1 if ref else 0)
sheet = Image.new("RGBA", (cols * CW, len(rows) * CH), BG); d = ImageDraw.Draw(sheet)
for y, (pose, fs) in enumerate(rows):
    x0 = 0
    if ref:
        im = Image.open(ref).convert("RGBA"); im.thumbnail((CW, CH)); sheet.alpha_composite(im, (0, y * CH)); x0 = 1
    for x, f in enumerate(fs):
        im = Image.open(f).convert("RGBA").resize((CW, CH), Image.LANCZOS)
        sheet.alpha_composite(im, ((x + x0) * CW, y * CH))
        d.text(((x + x0) * CW + 3, y * CH + 2), f"{pose} {f.stem}", fill=(255, 255, 0))
sheet.convert("RGB").save(out)
