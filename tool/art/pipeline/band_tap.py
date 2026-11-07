#!/usr/bin/env python3
"""Lift a musician's foot on a finished frame: the tap of motion set band-loop.

Qwen moves hands and keeps an instrument when told to, but a small heel lift is below what it reliably draws, and
it adds motion lines when told about tapping. So the tap is a puppet on the finished frame, as chain_layer.py
is for the gold: the arms stay those of the drawing it comes from, which is what keeps the loop continuous. The whole foot
rises, with the heel a little higher, since at this angle most feet point at the viewer and a pure pivot on the toe barely shows.

Usage: band_tap.py IN.png OUT.png --box X0,Y0,X1,Y1 [--lift 8] [--heel left|right]   (native pixels, box inclusive)
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def lift_foot(a: np.ndarray, box: tuple[int, int, int, int], lift: int, heel: str = "left") -> np.ndarray:
    """A copy of the RGBA array with the box's opaque pixels moved up: `lift` at the heel, 70% of it at the toe."""
    x0, y0, x1, y1 = box
    out = a.copy()
    foot = a[y0:y1 + 1, x0:x1 + 1].copy()
    out[y0:y1 + 1, x0:x1 + 1] = 0
    w = x1 - x0
    for col in range(w + 1):
        t = col / max(1, w)
        up = round(lift * (0.7 + 0.3 * (1 - t if heel == "left" else t)))
        for row in range(foot.shape[0]):
            if foot[row, col, 3]:
                out[y0 + row - up, x0 + col] = foot[row, col]
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("output")
    ap.add_argument("--box", required=True)
    ap.add_argument("--lift", type=int, default=8)
    ap.add_argument("--heel", default="left", choices=["left", "right"])
    a = ap.parse_args()
    box = tuple(int(v) for v in a.box.split(","))
    arr = np.asarray(Image.open(a.input).convert("RGBA"))
    Path(a.output).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(lift_foot(arr, box, a.lift, a.heel), "RGBA").save(a.output)


if __name__ == "__main__":
    main()
