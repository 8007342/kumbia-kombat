#!/usr/bin/env python3
"""A contact sheet of a rig's skeletons with the cue's line drawn in, for checking poses before any GPU.

Usage: cue_sheet.py RIG_DIR OUT.png [--only clip,pose] [--cols 8]
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

ap = argparse.ArgumentParser()
ap.add_argument("rig")
ap.add_argument("out")
ap.add_argument("--only", default="")
ap.add_argument("--cols", type=int, default=8)
a = ap.parse_args()
rig = json.loads((Path(a.rig) / "rig.json").read_text())
want = set(filter(None, a.only.split(",")))
poses = [p for p in rig["poses"] if not want or p["id"] in want or p["clip"] in want]
W, H = 192, 240
rows = (len(poses) + a.cols - 1) // a.cols
sheet = Image.new("RGB", (W * a.cols, (H + 14) * rows), (30, 30, 30))
d = ImageDraw.Draw(sheet)
for i, p in enumerate(poses):
    im = Image.open(Path(a.rig) / f"{p['id']}.pose.png").convert("RGB")
    if p.get("cue"):
        ImageDraw.Draw(im).line([tuple(p["cue"][0]), tuple(p["cue"][1])], fill=(255, 255, 255), width=8)
    x, y = W * (i % a.cols), (H + 14) * (i // a.cols)
    sheet.paste(im.resize((W, H)), (x, y + 14))
    d.rectangle([x, y + 14, x + W - 1, y + 13 + H], outline=(90, 90, 90))
    bad = [q for q in p.get("problems", [])]
    d.text((x + 2, y + 1), p["id"][:30], fill=(255, 120, 120) if bad else (255, 255, 255))
sheet.save(a.out)
print(len(poses), "poses")
