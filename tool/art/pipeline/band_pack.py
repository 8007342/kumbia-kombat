#!/usr/bin/env python3
"""Settle a packed band atlas's candidate, after art.py has packed it.

The packer's anchors follow each pose's pinned foot, which jumps between the band's two-footed and tapping poses, though
frames are locked to one floor spot. Its pixelsPerUnit divides by the reference frame's height, which is the instrument's
for the bass. Here every frame gets the same anchor point, under the player's feet, and pixelsPerUnit from the player's
standing height, so 38.75 world units is one standing adult, like every other atlas. `playerHeightPx` is written out
for code that scales from a level's explicit height.

Usage: band_pack.py band-bass --floor 292 --top 80
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
WORLD_HEIGHT = 38.75


def settle_rects(doc: dict) -> None:
    """The loader refuses an anchor outside a frame's rect. With a near foot lifted, a frame's lowest pixel is the far
    foot, which sits higher in the picture, so the anchor falls below the crop. Grow the rect down over empty atlas."""
    alpha = np.asarray(Image.open(ROOT / "assets/art/ensemble" / doc["image"]).convert("RGBA"))[..., 3]
    for fid, f in doc["frames"].items():
        x, y, w, h = f["rect"]
        need = int(np.ceil(f["anchor"][1])) + 1
        if need > h:
            if alpha[y + h:y + need, x:x + w].any() or y + need > alpha.shape[0]:
                raise SystemExit(f"{fid}: no empty atlas under its rect for the anchor")
            f["rect"][3] = need
        if not (0 <= f["anchor"][0] <= f["rect"][2]):
            raise SystemExit(f"{fid}: anchor x {f['anchor'][0]} is outside its rect")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("atlas")
    ap.add_argument("--floor", type=int, required=True, help="native row just under the player's shoes")
    ap.add_argument("--top", type=int, required=True, help="native row of the top of the player's head, standing")
    a = ap.parse_args()
    cand = ROOT / "assets/art/ensemble" / f"{a.atlas}-v1.candidate.json"
    doc = json.loads(cand.read_text())
    rig = json.loads((ROOT / "art_runs/inputs" / f"{a.atlas}-v1" / "rig.json").read_text())
    poses = {p["id"]: p for p in rig["poses"]}
    ref = poses["relaxed.a"]
    height = a.floor - a.top
    for fid, f in doc["frames"].items():
        p = poses[f["provenance"]["pose"]]
        # anchor = rig point - frame's left/top in native px, so the frame's left/top come back out.
        left = p["pivotX"] / 3 - f["anchor"][0]
        top = p["groundY"] / 3 - f["anchor"][1]
        f["anchor"] = [round(ref["pivotX"] / 3 - left, 1), round(a.floor - top, 1)]
        f["pixelsPerUnit"] = round(height / WORLD_HEIGHT, 4)
    settle_rects(doc)
    doc["playerHeightPx"] = height
    cand.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n")
    print(a.atlas, "player height", height, "ppu", round(height / WORLD_HEIGHT, 4), {k: v["anchor"] for k, v in doc["frames"].items()})


if __name__ == "__main__":
    main()
