#!/usr/bin/env python3
"""Colour-only variants of a packed, palette-locked atlas: swap one ramp's exact colours for another's.

Las Tréboles (galeria) dance one frame set as a line of five; this gives the four beside Siobhán their own hair
with no GPU. Every pixel of the named ramp is replaced by the colour at the same rank in the new ramp, so shading
and outlines stay identical and nothing else moves. The atlas's JSON sidecar (if any) is copied with the new name.

Usage: ramp_variants.py ATLAS.png PALETTE.json RAMP NAME=#c1,#c2,#c3,#c4 [NAME=...]
Writes ATLAS-NAME.png beside the atlas (e.g. siobhan-v1-raven.png)."""
import json, sys
from pathlib import Path
import numpy as np
from PIL import Image


def hexrgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def main():
    atlas, palette, ramp, *specs = sys.argv[1:]
    old = [hexrgb(c) for c in json.loads(Path(palette).read_text())["$provenance"]["ramps"][ramp]]
    im = np.asarray(Image.open(atlas).convert("RGBA")).copy()
    for spec in specs:
        name, cols = spec.split("=")
        new = [hexrgb(c) for c in cols.split(",")]
        assert len(new) == len(old), f"{name}: {len(new)} colours for a ramp of {len(old)}"
        out = im.copy()
        n = 0
        for o, c in zip(old, new):
            hit = (im[..., 0] == o[0]) & (im[..., 1] == o[1]) & (im[..., 2] == o[2]) & (im[..., 3] > 0)
            out[hit, :3] = c; n += int(hit.sum())
        dst = Path(atlas).with_name(Path(atlas).stem + f"-{name}.png")
        Image.fromarray(out).save(dst, optimize=True)
        print(dst, n, "pixels recoloured")


if __name__ == "__main__":
    main()
