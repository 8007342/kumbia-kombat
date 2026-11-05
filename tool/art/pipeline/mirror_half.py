#!/usr/bin/env python3
"""Mirror the picture-left half of a registered frame onto its right half.

Qwen copies the sheet's hanging arms when a skeleton asks for two forearms across the chest, but
draws one fine (art_runs/gatekeeper-v3-20261105q/). A symmetric pose such as a clap can be built
from one arm: the hand that reaches the centre line meets its own reflection.

Usage: mirror_half.py <src.png> <dst.png> [--axis 384]
The axis is in pixels of the registered canvas, normally the rig's neck x for the pose.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path)
    ap.add_argument("dst", type=Path)
    ap.add_argument("--axis", type=int, default=384)
    a = ap.parse_args()

    im = np.array(Image.open(a.src).convert("RGBA"))
    out = np.zeros_like(im)
    out[:, : a.axis] = im[:, : a.axis]
    width = min(a.axis, im.shape[1] - a.axis)
    out[:, a.axis : a.axis + width] = im[:, a.axis - width : a.axis][:, ::-1]
    a.dst.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out).save(a.dst)


if __name__ == "__main__":
    main()
