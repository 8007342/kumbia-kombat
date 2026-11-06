#!/usr/bin/env python3
"""Copy a studio job's outputs into the run's cache (seed-named), and write a review sheet on mid grey. usage: keep.py name job [job...]"""
import sys, glob, json, os, shutil
from PIL import Image, ImageDraw
BASE = os.path.expanduser("~/.cache/tillandsias-project/kumbia-art/oil-gulp-20261106/raw/")
name = sys.argv[1]; os.makedirs(BASE + name, exist_ok=True); items = []
for job in sys.argv[2:]:
    for p in sorted(glob.glob(f"/work/tmp/imagegen/studio/{job}/*.png")):
        seed = json.load(open(p + ".provenance.json")).get("seed")
        if seed is None: seed = os.path.basename(p)[:4]
        out = f"{BASE}{name}/{seed}.png"; shutil.copy(p, out); shutil.copy(p + ".provenance.json", out + ".provenance.json"); items.append((seed, out))
cell = 480
sheet = Image.new("RGB", (cell * min(4, len(items)), cell * ((len(items) + 3) // 4)), (110, 110, 118))
for i, (seed, out) in enumerate(items):
    im = Image.open(out).convert("RGBA"); im = im.resize((cell, cell * im.height // im.width), Image.NEAREST)
    x, y = (i % 4) * cell, (i // 4) * cell; sheet.paste(im, (x, y), im); ImageDraw.Draw(sheet).text((x + 4, y + 4), str(seed), fill=(255, 255, 0))
sheet.save(os.path.dirname(BASE[:-1]) + f"/sheet-{name}.png"); print(os.path.dirname(BASE[:-1]) + f"/sheet-{name}.png", len(items))
