#!/usr/bin/env python3
"""Local review sheets for a run: one sheet per clip, rows = poses, columns =
candidates (matted, over a mid-tone so both dark outline and cream read), with
the rig pose in the first column and the suggested pick outlined.

Writes art_runs/<run>/review/<clip>.png. CPU only; studio.contact_sheet stays
the canonical, provenance-linked sheet.

Usage: python3 tool/art/pipeline/review_sheets.py --run <run> [--cell 200]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

BG = (92, 120, 96, 255)
PICK = (255, 214, 0, 255)


def fit(im: Image.Image, cell: int) -> Image.Image:
    w, h = im.size
    s = cell / max(w, h)
    return im.resize((max(1, int(w * s)), max(1, int(h * s))), Image.LANCZOS)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    ap.add_argument("--cell", type=int, default=200)
    ap.add_argument("--selection", default="selection.suggested.json")
    a = ap.parse_args()
    run = Path("art_runs") / a.run
    scores = json.loads((run / "raw" / "scores.json").read_text())
    jobs = json.loads((run / "jobs.json").read_text())
    sel_p = run / a.selection
    sel = json.loads(sel_p.read_text()) if sel_p.exists() else {}
    clips: dict[str, list[str]] = {}
    for j in jobs:
        clips.setdefault(j["pose"].split(".")[0], []).append(j["pose"])
    out = run / "review"
    out.mkdir(exist_ok=True)
    c = a.cell
    for clip, poses in clips.items():
        ncol = 1 + max(len(scores[p]) for p in poses)
        sheet = Image.new("RGBA", (ncol * c + 140, len(poses) * c), BG)
        d = ImageDraw.Draw(sheet)
        for r, pose in enumerate(poses):
            d.text((4, r * c + 4), pose.split(".", 1)[1], fill=(255, 255, 255, 255))
            rig = Image.open(next(j for j in jobs if j["pose"] == pose)["args"]["init_image"]).convert("RGBA")
            t = fit(rig, c - 8)
            sheet.alpha_composite(t, (140 + 4, r * c + 4))
            for k, s in sorted(scores[pose].items(), key=lambda kv: int(kv[0])):
                t = fit(Image.open(s["rgba"]).convert("RGBA"), c - 8)
                x, y = 140 + (1 + int(k)) * c, r * c
                sheet.alpha_composite(t, (x + 4, y + 4))
                d.text((x + 4, y + c - 14), f"{k} d{s['debris']:.2f} s{s['specks']}", fill=(255, 255, 255, 255))
                if sel.get(pose) == int(k):
                    d.rectangle([x + 1, y + 1, x + c - 2, y + c - 2], outline=PICK, width=3)
        sheet.convert("RGB").save(out / f"{clip}.png", optimize=True)
        print(out / f"{clip}.png")


if __name__ == "__main__":
    main()
