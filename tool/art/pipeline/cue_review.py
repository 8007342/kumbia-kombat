#!/usr/bin/env python3
"""A review sheet: each pose's skeleton (with its cue line) beside its candidates, on one grey.

Usage: cue_review.py <run> OUT.png --family F [--only clip,pose] [--dir raw|registered] [--root ROOT]
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

ap = argparse.ArgumentParser()
ap.add_argument("run")
ap.add_argument("out")
ap.add_argument("--family", required=True)
ap.add_argument("--only", default="")
ap.add_argument("--dir", default="raw")
ap.add_argument("--root", default="")
ap.add_argument("--cols", type=int, default=3, help="candidates per row, after the skeleton")
a = ap.parse_args()
root = Path(a.root) if a.root else Path.home() / ".cache/tillandsias-project/kumbia-art" / a.run
rig = {p["id"]: p for p in json.loads(Path(f"art_runs/inputs/{a.family}/rig.json").read_text())["poses"]}
want = set(filter(None, a.only.split(",")))
poses = [d for d in sorted((root / a.dir).iterdir()) if d.is_dir() and (not want or d.name in want or d.name.split(".")[0] in want)]
W, H = 230, 288
sheet = Image.new("RGB", (W * (a.cols + 1), (H + 14) * len(poses)), (150, 150, 155))
d = ImageDraw.Draw(sheet)
for row, pd in enumerate(poses):
    y = (H + 14) * row
    d.text((3, y + 1), pd.name, fill=(0, 0, 0))
    if pd.name in rig:
        im = Image.open(f"art_runs/inputs/{a.family}/{pd.name}.pose.png").convert("RGB")
        c = rig[pd.name].get("cue")
        if c:
            ImageDraw.Draw(im).line([tuple(c[0]), tuple(c[1])], fill=(255, 255, 255), width=6)
        sheet.paste(im.resize((W, H)), (0, y + 14))
    for i, f in enumerate(sorted(pd.glob("*.png"))[: a.cols]):
        im = Image.open(f).convert("RGBA").resize((W, H), Image.NEAREST)
        sheet.paste(im, (W * (i + 1), y + 14), im)
sheet.save(a.out)
print(len(poses), "poses")
