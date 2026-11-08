#!/usr/bin/env python3
"""The terrace close-up's plate: a crop of the painted terrace (the graded pick, palms and all) in the lawn duet
plate's proportions (470x700), with the fireworks' full blooms drawn in, since the kiss happens under them.
No GPU. Usage: terraza_plate_closeup.py"""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
BOX = (181, 30, 651, 730)   # plate px: the stair head, festoons, the city and a little floor


def main():
    plate = Image.open(ROOT / "art_runs/rooms/terraza/picks/plate-996100-graded.png").convert("RGBA")
    frag = json.loads((ROOT / "art_runs/rooms/terraza/fireworks-level.json").read_text())
    atlas = Image.open(ROOT / "assets/art/terraza/terraza-fireworks.png").convert("RGBA")
    for p in frag["props"]:
        last = p["frames"] - 1
        x = last * (p["width"] + 2)
        plate.alpha_composite(atlas.crop((x, p["atlasY"], x + p["width"], p["atlasY"] + p["height"])), (p["left"], p["top"]))
    out = ROOT / "assets/art/closeups/terraza-plate.png"
    plate.crop(BOX).convert("RGB").save(out, optimize=True)
    print(out, BOX)


if __name__ == "__main__":
    main()
