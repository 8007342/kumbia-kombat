#!/usr/bin/env python3
"""Prototype: swing the medallion on a finished frame, so a beat can move the gold.

Chains are drawn at rest, and Qwen won't hold a chain of moments, so swing has to be a puppet. Cutting every
strand by colour failed: thin strands break up at native size, their dark shades quantise to skin and shoes,
and the base keeps ghost strands (see plan/levels/blinblin-sprites-2026-11-07.md). The medallion is the one
piece that cuts cleanly, being one solid blob, so this moves only it. A code-drawn strand joins it back to where
it hung, which is what the eye follows.

Usage: chain_layer.py FRAME.png POSE --raw REGISTERED.png --family <family> --palette P --out DIR [--shifts -5,0,5]
Writes <pose>.base.png, <pose>.medallion.png, <pose>.swing<shift>.png and <pose>.chains.json (native px).
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


def medallion(gold: np.ndarray, pose: dict, scale: int) -> np.ndarray:
    """The solid blob lowest on the chest: opening removes strands, and a wrist's watch is passed over."""
    op = pose["openpose"]
    solid = ndi.binary_opening(gold, structure=EIGHT, iterations=2)
    labels, n = ndi.label(solid)
    if not n:
        raise SystemExit("no solid gold on this frame")
    best, score = 0, -1.0
    mid_x = (op[1][0] + (op[8][0] + op[11][0]) / 2) / 2 / scale
    for i, (cy, cx) in enumerate(ndi.center_of_mass(solid, labels, range(1, n + 1))):
        by_wrist = any(op[j][2] and np.hypot(cx - op[j][0] / scale, cy - op[j][1] / scale) < 9 for j in (4, 7))
        size = float((labels == i + 1).sum())
        s = size * (0.1 if by_wrist else 1) / (1 + abs(cx - mid_x) / 10) + cy / 100
        if s > score:
            best, score = i + 1, s
    return ndi.binary_dilation(labels == best, structure=EIGHT, iterations=2) & gold


def compose(base: np.ndarray, frame: np.ndarray, cut: np.ndarray, top: tuple[int, int], shift: int, strand: list, ink: list) -> np.ndarray:
    out = base.copy()
    ys, xs = np.where(cut)
    out[ys, np.clip(xs + shift, 0, frame.shape[1] - 1)] = frame[ys, xs]
    # Strand: from where it hung to the top of the moved medallion, one pixel wide, with ink on its outer side.
    x0, y0 = top
    rows = max(1, 6)
    for k in range(rows):
        y = y0 - rows + k
        x = x0 + round(shift * ((k + 1) / rows) ** 2)
        side = 1 if shift > 0 else -1
        out[y, x] = strand
        if shift:
            out[y, x + side] = ink
    return out


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
    palette = json.loads(Path(a.palette).read_text())
    frame = np.asarray(Image.open(a.frame).convert("RGBA")).copy()
    pose = {p["id"]: p for p in json.loads(Path(f"art_runs/inputs/{a.family}/rig.json").read_text())["poses"]}[a.pose]
    alpha = frame[..., 3] > 0
    gold = gold_mask(np.asarray(Image.open(a.raw).convert("RGBA")), a.scale) & alpha
    medal = medallion(gold, pose, a.scale)
    # Everything in a disc around the blob is cleared, since its highlights and rim don't all read as gold by hue.
    # Only the medallion's own pixels travel: gold, ink and the bright rim, never the shirt behind it.
    ink = np.array([int(palette["colours"][0][i:i + 2], 16) for i in (1, 3, 5)] + [255], np.uint8)
    my, mx = ndi.center_of_mass(medal)
    r = max(np.ptp(np.where(medal)[0]), np.ptp(np.where(medal)[1])) / 2 + 3
    yy, xx = np.ogrid[:frame.shape[0], :frame.shape[1]]
    disc = (xx - mx) ** 2 + (yy - my) ** 2 <= r * r
    rgb = frame[..., :3].astype(int)
    dark = (rgb.sum(-1) < 90) & alpha
    warm = (rgb[..., 0] > 120) & (rgb[..., 2] < 0.6 * rgb[..., 1])
    hole = disc & alpha
    cut = hole & (medal | dark | warm)
    source = alpha & ~gold & ~dark & ~warm & ~ndi.binary_dilation(hole, structure=EIGHT)
    idx = ndi.distance_transform_edt(~source, return_distances=False, return_indices=True)
    base = frame.copy()
    base[hole] = frame[idx[0][hole], idx[1][hole]]
    ys, xs = np.where(medal)
    top = (int(np.median(xs[ys == ys.min()])), int(ys.min()))
    shade = frame[medal][..., :3]
    strand = np.append(np.median(shade, axis=0).astype(np.uint8), 255)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    Image.fromarray(base).save(out / f"{a.pose}.base.png")
    only = np.zeros_like(frame)
    only[cut] = frame[cut]
    Image.fromarray(only).save(out / f"{a.pose}.medallion.png")
    for sh in (int(x) for x in a.shifts.split(",")):
        Image.fromarray(compose(base, frame, cut, top, sh, strand, ink)).save(out / f"{a.pose}.swing{sh:+d}.png")
    (out / f"{a.pose}.chains.json").write_text(json.dumps({"top": top, "pixels": int(cut.sum())}, indent=1) + "\n")
    print(a.pose, "medallion pixels", int(cut.sum()), "top", top)


if __name__ == "__main__":
    main()
