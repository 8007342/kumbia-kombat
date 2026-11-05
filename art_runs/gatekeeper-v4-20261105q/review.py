#!/usr/bin/env python3
"""Contact sheet for eye review: per pose, skeleton, v3 final, then each registered candidate labelled with seed and build.
Usage: review.py out.png cellh pose [pose ...] [--seeds a,b,c,d]"""
import json, sys
from pathlib import Path
from PIL import Image, ImageDraw
sys.path.insert(0, str(Path(__file__).parent))
from measure_build import measure
RUN = "gatekeeper-v4-20261105q"
REG = Path.home() / ".cache/tillandsias-project/kumbia-art" / RUN / "registered"
STAGE = Path("/work/tmp/imagegen/kumbia") / RUN / "in"
OLD = Path("art_runs/gatekeeper-v3-20261105q/final")
args = sys.argv[1:]
seeds = None
if "--seeds" in args:
    i = args.index("--seeds"); seeds = args[i + 1].split(","); del args[i:i + 2]
out, ch, poses = args[0], int(args[1]), args[2:]
cw = int(ch * 0.8)
def cell(path, native=False):
    im = Image.open(path).convert("RGBA")
    k = ch / im.height
    im = im.resize((int(im.width * k), ch), Image.NEAREST if native else Image.LANCZOS)
    bg = Image.new("RGBA", im.size, (150, 150, 155, 255)); bg.alpha_composite(im)
    return bg.convert("RGB")
rows = []
for pose in poses:
    cs = sorted((REG / pose).glob("*.png"))
    if seeds:
        cs = [c for c in cs if c.stem in seeds]
    rows.append((pose, cs))
cols = 2 + max(len(c) for _, c in rows)
sheet = Image.new("RGB", (cols * cw + (cols - 1) * 4, len(rows) * (ch + 4)), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for r, (pose, cs) in enumerate(rows):
    y = r * (ch + 4)
    sk = STAGE / f"{pose}.skeleton.png"
    items = [(sk, pose)] + [(OLD / f"{pose}.png", "v3")]
    for c in cs:
        items.append((c, c.stem[-2:]))
    for n, (p, label) in enumerate(items):
        x = n * (cw + 4)
        if p.exists():
            sheet.paste(cell(p, native=label == "v3"), (x, y))
            if n:
                h, cen, tor = measure(p)
                label = f"{label} {cen:.2f}/{tor:.2f}"
        d.rectangle((x, y, x + 8 + 7 * len(label), y + 12), fill=(0, 0, 0))
        d.text((x + 3, y + 1), label, fill=(255, 255, 0))
sheet.save(out)
