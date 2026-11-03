#!/usr/bin/env python3
"""Suggest one candidate per pose, favouring a consistent character identity.

Reads art_runs/<run>/raw/scores.json (from prep_finish.py) and, for each
candidate, measures the median colour inside each rig region (the pose's
regionMask, eroded so edges don't count) against the family's
regionProxyColours, as perceptual distance (OKLab, scaled to 0-100). Hat colour
weighs most: it drifts most between seeds and flickers worst in a loop. The
matte signals break ties and veto border touches and heavy floor debris.

Fails closed: run gatekeeper-v3-20261103a silently scored every candidate 0.0
because the region map was inverted, so its picks came from speck counts alone.
Selection now aborts when scores are missing or carry no information.

Writes the identity distances back into scores.json and the pick into
art_runs/<run>/selection.suggested.json. Review the sheets before copying the
suggestion to selection.json.

Usage: python3 tool/art/pipeline/suggest.py tool/art/families/<family>.json --run <run>
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

WEIGHTS = {"hat": 2.0, "cloth": 1.0, "trousers": 0.7, "shoes": 0.5, "skin": 0.5}


def hexrgb(h: str) -> np.ndarray:
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float)


def oklab(rgb: np.ndarray) -> np.ndarray:
    """sRGB 0-255 to OKLab, L scaled 0-100 (Ottosson 2020)."""
    c = np.asarray(rgb, float) / 255.0
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    l = np.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = np.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = np.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return 100 * np.stack([0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                           1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                           0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s], axis=-1)


def region_masks(mask_rgb: np.ndarray, regions: dict[str, str]) -> dict[str, np.ndarray]:
    """{'#RRGGBB': region name} and the pose's flat region render -> {name: eroded mask}."""
    out = {}
    for colour, name in regions.items():
        if name not in WEIGHTS:
            continue
        m = Image.fromarray((np.all(mask_rgb == hexrgb(colour), axis=2) * 255).astype(np.uint8))
        out[name] = np.asarray(m.filter(ImageFilter.MinFilter(9))) > 0  # ignore outlines and edge drift
    return out


def score_candidate(rgb: np.ndarray, masks: dict[str, np.ndarray], target: dict[str, np.ndarray]) -> tuple[dict, float | None]:
    """Per-region distance from target colour, and their weighted mean (None if nothing was measurable)."""
    ident = {}
    for name, m in masks.items():
        px = rgb[m]
        if len(px) < 30 or name not in target:
            continue
        ident[name] = round(float(np.linalg.norm(oklab(np.median(px, axis=0)) - oklab(target[name]))), 1)
    if not ident:
        return ident, None
    return ident, round(sum(WEIGHTS[n] * d for n, d in ident.items()) / sum(WEIGHTS[n] for n in ident), 1)


def require_informative(scores: dict) -> None:
    """Abort rather than select when identity was not actually measured."""
    vals = [c.get("identityScore") for pose in scores.values() for c in pose.values()]
    if not vals or any(v is None for v in vals):
        missing = sum(v is None for v in vals)
        raise SystemExit(f"selection refused: {missing}/{len(vals)} candidates have no identity score")
    if len(set(vals)) <= 1 and len(vals) > 1:
        raise SystemExit(f"selection refused: all {len(vals)} identity scores equal {vals[0]}; scoring measured nothing")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("spec")
    ap.add_argument("--run", required=True)
    a = ap.parse_args()
    spec = json.loads(Path(a.spec).read_text())
    run = Path("art_runs") / a.run
    scores = json.loads((run / "raw" / "scores.json").read_text())
    index = json.loads((run / "raw" / "index.json").read_text())
    target = {k: hexrgb(v) for k, v in spec["regionProxyColours"].items()}
    masks = {p["id"]: p["regionMask"] for p in spec["poses"]}
    for pose, cands in index.items():
        rm = Image.open(masks[pose]).convert("RGB")
        regions = region_masks(np.asarray(rm), spec["regions"])
        for c in cands:
            im = Image.open(c["rgb"]).convert("RGB")
            if im.size != rm.size:
                im = im.resize(rm.size, Image.NEAREST)
            ident, total = score_candidate(np.asarray(im, float), regions, target)
            s = scores[pose][str(c["k"])]
            s["identity"], s["identityScore"] = ident, total
    require_informative({p: {k: scores[p][k] for k in scores[p]} for p in index})
    sel = {}
    for pose in index:
        def rank(k: str):
            s = scores[pose][k]
            return (s["border"], s["specks"] > 2000, s["identityScore"] + 20 * (s["debris"] > 0.9) + s["specks"] / 100)
        sel[pose] = int(min(scores[pose], key=rank))
    (run / "raw" / "scores.json").write_text(json.dumps(scores, indent=1) + "\n")
    (run / "selection.suggested.json").write_text(json.dumps(sel, indent=1) + "\n")
    print(f"suggested {len(sel)} poses -> {run / 'selection.suggested.json'}")


if __name__ == "__main__":
    main()
