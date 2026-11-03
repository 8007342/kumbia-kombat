#!/usr/bin/env python3
"""Extract a locked tillandsias.palette/v1 file from approved character art.

Usage:
  python3 tool/art/palettes/extract_palette.py \
      --source assets/art/ensemble/gatekeeper-v2.png \
      --name gatekeeper --colours 31 --outline '#1A1018' \
      --out tool/art/palettes/gatekeeper.json

Only opaque pixels (alpha >= 128) are sampled. Colours come from Pillow's
median-cut quantiser (deterministic for the same input), sorted dark to light
by luma so the index order is stable; the family outline is forced in at
index 0. Reordering a published palette is a version change (contract D12).
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


def luma(rgb: tuple[int, int, int]) -> float:
    r, g, b = rgb
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True, action="append",
                    help="approved art PNG (repeatable)")
    ap.add_argument("--name", required=True)
    ap.add_argument("--colours", type=int, default=31)
    ap.add_argument("--merge", type=int, default=20,
                    help="merge colours closer than this RGB distance (weighted to the more common)")
    ap.add_argument("--outline", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    pixels: list[tuple[int, int, int]] = []
    hashes = {}
    for src in a.source:
        data = Path(src).read_bytes()
        hashes[src] = hashlib.sha256(data).hexdigest()
        im = Image.open(src).convert("RGBA")
        pixels += [p[:3] for p in im.get_flattened_data() if p[3] >= 128]
    if not pixels:
        raise SystemExit("no opaque pixels")

    strip = Image.new("RGB", (len(pixels), 1))
    strip.putdata(pixels)
    k = a.colours * 3
    q = strip.quantize(colors=k, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q.getpalette()[: k * 3]
    counts = sorted(q.getcolors(maxcolors=1 << 16), reverse=True)  # most common first
    cols: list[tuple[int, int, int]] = []
    for _, i in counts:
        c = tuple(pal[i * 3: i * 3 + 3])
        if all(sum((x - y) ** 2 for x, y in zip(c, d)) ** 0.5 >= a.merge for d in cols):
            cols.append(c)
        if len(cols) == a.colours:
            break

    outline = a.outline.upper()
    hexes = [f"#{r:02X}{g:02X}{b:02X}" for r, g, b in sorted(cols, key=luma)]
    hexes = [outline] + [h for h in hexes if h != outline]

    doc = {
        "schema": "tillandsias.palette/v1",
        "name": a.name,
        "colours": hexes,
        "transparent": None,
        "$provenance": {
            "tool": "tool/art/palettes/extract_palette.py",
            "sources": hashes,
            "method": f"median-cut {a.colours * 3}, merge<{a.merge}, top {a.colours} by count, alpha>=128, luma order, outline at 0",
        },
    }
    Path(a.out).write_text(json.dumps(doc, indent=1) + "\n")
    print(f"wrote {a.out}: {len(hexes)} colours")


if __name__ == "__main__":
    main()
