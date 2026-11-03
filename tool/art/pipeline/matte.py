#!/usr/bin/env python3
"""Key a binary matte from a generated frame's plain background.

Stopgap while BiRefNet is missing from the studio (2026-11-03). The prompts ask
for a "plain light grey background". Background = components of background-coloured or neutral-light-grey pixels
that touch the border or are large (the gap between the legs); small enclosed
patches stay, so light-cream clothing and highlights are kept. Then only the
largest character component is kept, which drops specks.
Writes an 8-bit L PNG: 255 = character, 0 = background; --rgba also writes the
frame with the matte as its alpha, which studio.finish_pixels takes with its
default alpha source "engine".

Usage: python3 tool/art/pipeline/matte.py IN.png OUT.matte.png [--rgba OUT.rgba.png] [--tol 34]
"""
from __future__ import annotations

import argparse
from collections import deque

import numpy as np
from PIL import Image


def _components(mask: np.ndarray):
    """Yield (pixels_y, pixels_x) per 4-connected component of mask."""
    h, w = mask.shape
    lab = np.zeros((h, w), bool)
    q: deque[tuple[int, int]] = deque()
    for y0, x0 in zip(*np.nonzero(mask)):
        if lab[y0, x0]:
            continue
        lab[y0, x0] = True
        q.append((y0, x0))
        ys, xs = [], []
        while q:
            y, x = q.popleft()
            ys.append(y)
            xs.append(x)
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = True
                    q.append((ny, nx))
        yield np.array(ys), np.array(xs)


def key(img: Image.Image, tol: float, hole: int, grey_chroma: int, grey_min: int) -> np.ndarray:
    a = np.asarray(img.convert("RGB"), dtype=np.int32)
    h, w, _ = a.shape
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    chroma = a.max(axis=2) - a.min(axis=2)
    # background colour, or a neutral light grey (the floor shadow the model adds)
    near = (np.sqrt(((a - bg) ** 2).sum(axis=2)) <= tol) | ((chroma <= grey_chroma) & (a.min(axis=2) >= grey_min))
    is_bg = np.zeros((h, w), bool)
    for ys, xs in _components(near):
        touches = ys.min() == 0 or xs.min() == 0 or ys.max() == h - 1 or xs.max() == w - 1
        if touches or len(ys) >= hole:  # border-connected, or a large enclosed gap (between legs)
            is_bg[ys, xs] = True
    fg = ~is_bg
    best = max(_components(fg), key=lambda c: len(c[0]), default=None)
    out = np.zeros((h, w), bool)
    if best is not None:
        out[best] = True
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("inp")
    ap.add_argument("out")
    ap.add_argument("--tol", type=float, default=34.0, help="RGB distance to the border median")
    ap.add_argument("--hole", type=int, default=250, help="enclosed background regions at least this many px are cut")
    ap.add_argument("--grey-chroma", type=int, default=14, help="max(rgb)-min(rgb) of the neutral floor-shadow greys")
    ap.add_argument("--grey-min", type=int, default=150, help="darkest channel of those greys")
    ap.add_argument("--rgba", help="also write IN with the matte as alpha")
    a = ap.parse_args()
    m = key(Image.open(a.inp), a.tol, a.hole, a.grey_chroma, a.grey_min)
    matte = Image.fromarray((m * 255).astype(np.uint8), "L")
    matte.save(a.out)
    if a.rgba:
        im = Image.open(a.inp).convert("RGBA")
        im.putalpha(matte)
        im.save(a.rgba)
    print(f"{a.out}: {m.mean():.1%} foreground")


if __name__ == "__main__":
    main()
