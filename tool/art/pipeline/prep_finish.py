#!/usr/bin/env python3
"""Matte every collected candidate and score it, ready for review and finish.

For art_runs/<run>/raw/<pose>/<k>.rgb.png this writes, on the lane volume
(/work/tmp/imagegen/kumbia/<run>/finish/), <pose>.<k>.rgba.png (frame with the
keyed matte as alpha, the input studio.finish_pixels takes with alpha source
"engine"), and art_runs/<run>/raw/scores.json with cheap matte-quality
signals that help review, never replace it:

  fg        foreground fraction of the canvas
  border    the character touches the canvas edge (frame.margin.failOnBorderTouch)
  debris    width of the foreground's bottom 2% band relative to its widest row
            (a floor shadow or ground strip left in the matte reads as ~1)
  specks    foreground pixels dropped as separate specks

With --suggest it writes art_runs/<run>/selection.suggested.json: per pose the
candidate with no border touch and the least debris/specks. Copy it to
selection.json only after looking at the contact sheets.

Usage: python3 tool/art/pipeline/prep_finish.py --run <run> [--suggest]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from matte import background, key  # noqa: E402

LANE = Path("/work/tmp/imagegen/kumbia")


def score(rgb: Image.Image, m: np.ndarray, raw_fg: int) -> dict:
    h, w = m.shape
    ys, xs = np.nonzero(m)
    if len(ys) == 0:
        return {"fg": 0.0, "border": True, "debris": 1.0, "specks": 0}
    top, bot = ys.min(), ys.max()
    band = m[max(top, bot - max(2, (bot - top) // 50)): bot + 1]
    band_w = np.nonzero(band.any(axis=0))[0]
    widest = max((np.ptp(np.nonzero(r)[0]) + 1) for r in m[top:bot + 1] if r.any())
    return {
        "fg": round(float(m.mean()), 4),
        "border": bool(top == 0 or xs.min() == 0 or bot == h - 1 or xs.max() == w - 1),
        "debris": round(float((np.ptp(band_w) + 1) / widest), 3) if len(band_w) else 0.0,
        "specks": int(raw_fg - m.sum()),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    ap.add_argument("--suggest", action="store_true")
    a = ap.parse_args()
    run = Path("art_runs") / a.run
    index = json.loads((run / "raw" / "index.json").read_text())
    out_dir = LANE / a.run / "finish"
    out_dir.mkdir(parents=True, exist_ok=True)
    scores: dict[str, dict[str, dict]] = {}
    for pose, cands in sorted(index.items()):
        for c in cands:
            src = Path(c["rgb"])
            im = Image.open(src).convert("RGBA")
            m = key(im)
            # raw foreground (before keeping the largest component), for specks
            raw_fg = int((~background(np.asarray(im.convert("RGB"), dtype=np.int32))).sum())
            im.putalpha(Image.fromarray((m * 255).astype(np.uint8), "L"))
            dst = out_dir / f"{pose}.{c['k']}.rgba.png"
            im.save(dst)
            scores.setdefault(pose, {})[str(c["k"])] = score(im, m, raw_fg) | {"rgba": str(dst)}
    (run / "raw" / "scores.json").write_text(json.dumps(scores, indent=1) + "\n")
    print(f"matted {sum(len(v) for v in scores.values())} candidates -> {out_dir}")
    if a.suggest:
        sel = {p: int(min(s, key=lambda k: (s[k]["border"], s[k]["debris"] > 0.8, s[k]["specks"], s[k]["debris"])))
               for p, s in scores.items()}
        (run / "selection.suggested.json").write_text(json.dumps(sel, indent=1) + "\n")
        print(f"suggested selection for {len(sel)} poses -> {run / 'selection.suggested.json'}")


if __name__ == "__main__":
    main()
