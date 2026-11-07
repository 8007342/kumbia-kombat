#!/usr/bin/env python3
"""Prototype: swing the medallion on a finished frame, so a beat can move the gold.

Chains are drawn at rest, and Qwen won't hold a chain of moments, so swing has to be a puppet. Cutting every
strand by colour failed: thin strands break up at native size, their dark shades quantise to skin and shoes,
and the base keeps ghost strands (see plan/levels/blinblin-sprites-2026-11-07.md). The medallion is the one
piece that cuts cleanly, being one solid blob, so this moves only it, by whole pixels, so colours stay on the palette.

Usage: chain_layer.py FRAME.png POSE --raw REGISTERED.png --family <family> --palette P --out DIR [--shifts -5,0,5]
Writes <pose>.swing<shift>.png. finish_picks.py uses swung() to bake a swing into a run.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

EIGHT = np.ones((3, 3))


def gold_mask(raw: np.ndarray, scale: int) -> np.ndarray:
    """Gold by hue before quantising, when its dark shades still look like gold."""
    h, w = raw.shape[0] // scale, raw.shape[1] // scale
    s = raw[np.ix_(np.arange(h) * scale + scale // 2, np.arange(w) * scale + scale // 2)].astype(int)
    r, g, b = s[..., 0], s[..., 1], s[..., 2]
    return (s[..., 3] > 128) & (r > 110) & (g >= 0.62 * r) & (b < 0.5 * g) & (r >= g)


class NoMedallion(ValueError):
    pass


def medallion(gold: np.ndarray, pose: dict, scale: int) -> np.ndarray:
    """The solid round blob low on the chest: opening removes strands, and a wrist's watch is passed over."""
    op = pose["openpose"]
    solid = ndi.binary_opening(gold, structure=EIGHT, iterations=2)
    labels, n = ndi.label(solid)
    if not n:
        raise NoMedallion("no solid gold")
    best, score = 0, -1.0
    neck_y = op[1][1] / scale
    for i, (cy, cx) in enumerate(ndi.center_of_mass(solid, labels, range(1, n + 1))):
        by_wrist = any(op[j][2] and np.hypot(cx - op[j][0] / scale, cy - op[j][1] / scale) < 9 for j in (4, 7))
        size = float((labels == i + 1).sum())
        if by_wrist or cy < neck_y + 8:
            continue
        s = size + cy / 100
        if s > score:
            best, score = i + 1, s
    if not best:
        raise NoMedallion("only gold near a wrist or the neck")
    ys, xs = np.where(labels == best)
    w, h = np.ptp(xs) + 1, np.ptp(ys) + 1
    if not (6 <= w <= 24 and 6 <= h <= 24 and 0.6 <= w / h <= 1.6):
        raise NoMedallion(f"blob {w}x{h} isn't medallion shaped")
    return ndi.binary_dilation(labels == best, structure=EIGHT, iterations=2) & gold


def swung(frame: np.ndarray, raw: np.ndarray, pose: dict, shift: int, scale: int = 3) -> tuple[np.ndarray, int]:
    """The frame with its medallion moved sideways by whole pixels, and the disc it left painted from around it."""
    alpha = frame[..., 3] > 0
    gold = gold_mask(raw, scale) & alpha
    medal = medallion(gold, pose, scale)
    my, mx = ndi.center_of_mass(medal)
    ys, xs = np.where(medal)
    r = max(np.ptp(ys), np.ptp(xs)) / 2 + 3
    yy, xx = np.ogrid[:frame.shape[0], :frame.shape[1]]
    disc = (xx - mx) ** 2 + (yy - my) ** 2 <= r * r
    rgb = frame[..., :3].astype(int)
    dark = (rgb.sum(-1) < 90) & alpha
    warm = (rgb[..., 0] > 120) & (rgb[..., 2] < 0.6 * rgb[..., 1])
    hole = disc & alpha
    cut = hole & (medal | dark | warm)
    source = alpha & ~gold & ~dark & ~warm & ~ndi.binary_dilation(hole, structure=EIGHT)
    if not source.any():
        raise NoMedallion("nothing to paint the hole from")
    idx = ndi.distance_transform_edt(~source, return_distances=False, return_indices=True)
    out = frame.copy()
    out[hole] = frame[idx[0][hole], idx[1][hole]]
    cy, cx = np.where(cut)
    tx = np.clip(cx + shift, 0, frame.shape[1] - 1)
    land = alpha[cy, tx]  # never onto the background: a swing mustn't change the silhouette
    out[cy[land], tx[land]] = frame[cy[land], cx[land]]
    return out, shift


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("frame")
    ap.add_argument("pose")
    ap.add_argument("--raw", required=True)
    ap.add_argument("--family", required=True)
    ap.add_argument("--palette", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--scale", type=int, default=3)
    ap.add_argument("--shifts", default="-4,0,4")
    a = ap.parse_args()
    frame = np.asarray(Image.open(a.frame).convert("RGBA")).copy()
    pose = {p["id"]: p for p in json.loads(Path(f"art_runs/inputs/{a.family}/rig.json").read_text())["poses"]}[a.pose]
    raw = np.asarray(Image.open(a.raw).convert("RGBA"))
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    for sh in (int(x) for x in a.shifts.split(",")):
        im, _ = swung(frame, raw, pose, sh, a.scale)
        Image.fromarray(im).save(out / f"{a.pose}.swing{sh:+d}.png")


if __name__ == "__main__":
    main()
