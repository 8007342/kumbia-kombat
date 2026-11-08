#!/usr/bin/env python3
"""Finish the picked frames of a merged run locally and pack the atlas, for a family that isn't on `game` yet.

picks: {pose: seed} in art_runs/<run>/picks.json. Each pick goes from <cache>/<run>/registered/<pose>/<seed>.png through
finish_local (native grid, nearest palette colour, binary alpha) into art_runs/<run>/final/<pose>.png.
`derive` in picks.json makes a small second drawing from a first: {pose: {from: pose, compress: true}} takes one row out at
the waist, so the upper body settles a pixel. Then pack_atlas.py writes the atlas and its .candidate.json.

Usage: finish_run_picks.py <character> --run <run>
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


def shoe_rule(c: dict, rows: int | None):
    """Dark trouser shadow can snap to the dark end of a vivid shoe ramp. Above the shoes, those pixels go to the trousers' ramp."""
    if not rows:
        return lambda im, src: im
    import colour as C  # noqa: E402

    ramps = C.build_ramps(c, D.load_style(c["style"]))
    hexes = lambda r: np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in r["shades"]])
    shoes, trousers = hexes(ramps["shoes"]), hexes(ramps["trousers"])

    def apply(im: Image.Image, src: Path) -> Image.Image:
        a = np.asarray(im.convert("RGBA")).copy()
        raw = np.asarray(Image.open(src).convert("RGB")).astype(int)
        scale = raw.shape[0] // a.shape[0]
        ys = np.where(a[..., 3].max(axis=1) > 0)[0]
        limit = int(ys.max()) - rows
        on_shoe = (a[..., 3] > 0) & (a[..., :3][..., None, :] == shoes).all(-1).any(-1)
        for y, x in zip(*np.where(on_shoe)):
            r, g, b = raw[y * scale + scale // 2, x * scale + scale // 2]
            if y < limit or r < 1.6 * max(g, b, 1):  # the drawing's own colour there wasn't shoe-red
                a[y, x, :3] = trousers[((trousers - a[y, x, :3].astype(int)) ** 2).sum(1).argmin()]
        return Image.fromarray(a, "RGBA")

    return apply


def drop_floor_shadow(im: Image.Image) -> Image.Image:
    """The model sometimes paints a soft grey floor shadow under the shoes, and the matte keeps it. Style: no floor
    shadow in frames. Clear grey, mid-value pixels in the bottom tenth of the figure that the shoes don't cover."""
    a = np.asarray(im.convert("RGBA")).copy()
    ys = np.where(a[..., 3].max(axis=1) > 0)[0]
    if not len(ys):
        return im
    top, bot = int(ys.min()), int(ys.max())
    band = slice(bot - max(4, (bot - top) // 10), bot + 1)
    rgb = a[band, :, :3].astype(int)
    grey = (rgb.max(-1) - rgb.min(-1) < 26) & (rgb.max(-1) > 90) & (rgb.max(-1) < 215) & (a[band, :, 3] > 0)
    sub = a[band]; sub[grey] = 0; a[band] = sub
    return Image.fromarray(a, "RGBA")


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
    shoes_only = shoe_rule(c, doc.get("shoesBelow"))
    for pose, seed in doc["picks"].items():
        src = CACHE / a.run / "registered" / pose / f"{seed}.png"
        im = shoes_only(finish(src, palette, c["targets"][0].get("pixelScale", 3)), src)
        (drop_floor_shadow(im) if doc.get("dropFloorShadow") else im).save(final / f"{pose}.png")
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
