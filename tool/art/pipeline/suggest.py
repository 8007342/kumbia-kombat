#!/usr/bin/env python3
"""Suggest one candidate per pose, favouring a consistent character identity.

Reads art_runs/<run>/raw/scores.json (from prep_finish.py) and, for each
candidate, measures the median colour inside each rig region (the pose's
regionMask, eroded so edges don't count) against the family's
regionProxyColours. Hat colour weighs most: it drifts most between seeds and
flickers worst in a loop. The matte signals break ties and veto border touches
and heavy floor debris.

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


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("spec")
    ap.add_argument("--run", required=True)
    a = ap.parse_args()
    spec = json.loads(Path(a.spec).read_text())
    run = Path("art_runs") / a.run
    scores = json.loads((run / "raw" / "scores.json").read_text())
    index = json.loads((run / "raw" / "index.json").read_text())
    region_of = {v: k for k, v in spec["regions"].items()}  # mask colour -> region name
    target = {k: hexrgb(v) for k, v in spec["regionProxyColours"].items()}
    masks = {p["id"]: p["regionMask"] for p in spec["poses"]}
    sel = {}
    for pose, cands in index.items():
        rm = Image.open(masks[pose]).convert("RGB")
        regions = {}
        for col, name in region_of.items():
            if name not in WEIGHTS:
                continue
            m = Image.fromarray((np.all(np.asarray(rm) == hexrgb(col), axis=2) * 255).astype(np.uint8))
            m = m.filter(ImageFilter.MinFilter(9))  # erode: ignore outlines and drift at edges
            regions[name] = m
        for c in cands:
            im = Image.open(c["rgb"]).convert("RGB")
            if im.size != rm.size:
                im = im.resize(rm.size, Image.NEAREST)
            arr = np.asarray(im, float)
            ident = {}
            for name, m in regions.items():
                sel_px = arr[np.asarray(m) > 0]
                if len(sel_px) < 30:
                    continue
                ident[name] = round(float(np.linalg.norm(np.median(sel_px, axis=0) - target[name])), 1)
            s = scores[pose][str(c["k"])]
            s["identity"] = ident
            s["identityScore"] = round(sum(WEIGHTS[n] * d for n, d in ident.items()) / max(1e-9, sum(WEIGHTS[n] for n in ident)), 1)
        def rank(k: str):
            s = scores[pose][k]
            return (s["border"], s["specks"] > 2000, s["identityScore"] + 20 * (s["debris"] > 0.9) + s["specks"] / 100)
        sel[pose] = int(min(scores[pose], key=rank))
    (run / "raw" / "scores.json").write_text(json.dumps(scores, indent=1) + "\n")
    (run / "selection.suggested.json").write_text(json.dumps(sel, indent=1) + "\n")
    print(f"suggested {len(sel)} poses -> {run / 'selection.suggested.json'}")


if __name__ == "__main__":
    main()
