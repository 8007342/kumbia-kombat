#!/usr/bin/env python3
"""Finish the picked frames of a merged run locally and pack the atlas, for a family that isn't on `game` yet.

picks: {pose: seed} in art_runs/<run>/picks.json. Each pick goes from <cache>/<run>/registered/<pose>/<seed>.png through
finish_local (native grid, nearest palette colour, binary alpha) into art_runs/<run>/final/<pose>.png.
`derive` in picks.json makes a small second drawing from a first: {pose: {from: pose, compress: true}} takes one row out at
the waist, so the upper body settles a pixel. Then pack_atlas.py writes the atlas and its .candidate.json.

Usage: finish_picks.py <character> --run <run>
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, str(Path(__file__).resolve().parent))
import definitions as D  # noqa: E402
from finish_local import finish, palette_of  # noqa: E402

CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"


def compress(im: Image.Image) -> Image.Image:
    a = np.asarray(im.convert("RGBA")).copy()
    ys = np.where(a[..., 3].max(axis=1) > 0)[0]
    waist = int(ys.min() + (ys.max() - ys.min()) * 0.45)
    out = np.zeros_like(a)
    out[1:waist + 1] = a[:waist]
    out[waist + 1:] = a[waist + 1:]
    return Image.fromarray(out, "RGBA")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("character")
    ap.add_argument("--run", required=True)
    a = ap.parse_args()
    c = D.load_character(a.character)
    run_dir = Path("art_runs") / a.run
    doc = json.loads((run_dir / "picks.json").read_text())
    palette = palette_of(f"tool/art/palettes/{c['id']}.json")
    final = run_dir / "final"
    final.mkdir(parents=True, exist_ok=True)
    selection = {}
    for pose, seed in doc["picks"].items():
        src = CACHE / a.run / "registered" / pose / f"{seed}.png"
        finish(src, palette, c["targets"][0].get("pixelScale", 3)).save(final / f"{pose}.png")
        selection[pose] = {"k": seed, "accepted": True}
    for pose, how in doc.get("derive", {}).items():
        compress(Image.open(final / f"{how['from']}.png")).save(final / f"{pose}.png")
        selection[pose] = {"k": f"derived from {how['from']}", "accepted": True}
    for pose, source in doc.get("alias", {}).items():
        Image.open(final / f"{source}.png").save(final / f"{pose}.png")
        selection[pose] = {"k": f"same drawing as {source}", "accepted": True}
    for pose in doc.get("trimCue", []):
        # The game reads standing height from the reference drawing's rect, so a cue above the head would shrink them.
        im = np.asarray(Image.open(final / f"{pose}.png").convert("RGBA")).copy()
        body = ndi.binary_opening(im[..., 3] > 0, structure=np.ones((8, 8)))
        im[:int(np.where(body.any(axis=1))[0].min())] = 0
        Image.fromarray(im, "RGBA").save(final / f"{pose}.png")
    (run_dir / "selection.json").write_text(json.dumps(selection, indent=1) + "\n")
    subprocess.run([sys.executable, "tool/art/pipeline/pack_atlas.py", f"tool/art/families/{c['family']}.json", "--run", a.run], check=True)


if __name__ == "__main__":
    main()
