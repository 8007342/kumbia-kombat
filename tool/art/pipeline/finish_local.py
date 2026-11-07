#!/usr/bin/env python3
"""The pixel finish without the host, for a family that isn't in the main checkout yet.

studio.finish_pixels only reads family specs inside the main checkout, so a palette edited on a worktree
branch can't reach it until merged. This does the same steps: alpha binarised at 128, centre-sampled to the
native grid, each opaque pixel to the nearest palette colour. check_against() compares it with host output.

Usage: finish_local.py IN.png OUT.png --palette tool/art/palettes/<id>.json [--scale 3]
       finish_local.py --check HOST_OUT.png IN.png --palette P
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


def palette_of(path: str | Path) -> np.ndarray:
    colours = json.loads(Path(path).read_text())["colours"]
    return np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in colours], np.int64)


def finish(src: str | Path, palette: np.ndarray, scale: int = 3) -> Image.Image:
    a = np.asarray(Image.open(src).convert("RGBA")).astype(np.int64)
    h, w = a.shape[0] // scale, a.shape[1] // scale
    ys = np.arange(h) * scale + scale // 2
    xs = np.arange(w) * scale + scale // 2
    s = a[np.ix_(ys, xs)]
    d = ((s[:, :, None, :3] - palette[None, None]) ** 2).sum(-1)
    rgb = palette[d.argmin(-1)]
    alpha = np.where(s[..., 3] >= 128, 255, 0)
    out = np.dstack([np.where(alpha[..., None] > 0, rgb, 0), alpha]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("output", nargs="?")
    ap.add_argument("--palette", required=True)
    ap.add_argument("--scale", type=int, default=3)
    ap.add_argument("--check")
    a = ap.parse_args()
    im = finish(a.input, palette_of(a.palette), a.scale)
    if a.check:
        host = np.asarray(Image.open(a.check).convert("RGBA")).astype(int)
        mine = np.asarray(im).astype(int)
        print("shape", host.shape, mine.shape, "alpha differs", int(((host[..., 3] > 0) != (mine[..., 3] > 0)).sum()),
              "colour differs", int((np.any(host[..., :3] != mine[..., :3], axis=-1) & (host[..., 3] > 0)).sum()), "of", int((host[..., 3] > 0).sum()))
        return
    Path(a.output).parent.mkdir(parents=True, exist_ok=True)
    im.save(a.output, optimize=False)


if __name__ == "__main__":
    main()
