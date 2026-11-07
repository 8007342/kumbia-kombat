#!/usr/bin/env python3
"""First-pass curation with the local vision model: count heads and hands per candidate.

A first pass only. It asks qwen2.5vl about one candidate at a time on a flat grey background, and records the
answers beside the scores, so a person reads a shortlist instead of every frame. How far to trust it is measured
in plan/levels/blinblin-sprites-2026-11-07.md. Safe to restart: finished candidates are kept.

Usage: vision_curate.py --run <run> --dir <registered dir> [--only pose,clip] [--ledger AGENT] [--poses-file F]
Writes art_runs/<run>/vision.json: {pose: {seed: {"heads": n, "hands": n, "ok": bool, "seconds": s}}}.
"""
from __future__ import annotations

import argparse
import base64
import io
import json
import re
import time
import urllib.request as u
from pathlib import Path

from PIL import Image

URL = "http://inference:11434/api/generate"
MODEL = "qwen2.5vl:7b"
QUESTIONS = {"heads": "How many separate human heads are drawn in this image? Reply with only a number.",
             "hands": "How many separate human hands are drawn in this image? Reply with only a number."}


def ask(path: Path) -> dict:
    """Counts on one cropped figure, the form measured as reliable (plan/compute-ledger-2026-11-07.md). A clean count isn't a pass."""
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, (150, 150, 155, 255))
    bg.alpha_composite(im)
    buf = io.BytesIO()
    bg.crop(im.getbbox()).convert("RGB").save(buf, "PNG")
    t = time.time()
    doc = {}
    for key, q in QUESTIONS.items():
        body = json.dumps({"model": MODEL, "stream": False, "prompt": q, "images": [base64.b64encode(buf.getvalue()).decode()],
                           "options": {"temperature": 0}}).encode()
        text = json.load(u.urlopen(u.Request(URL, body), timeout=600))["response"]
        m = re.search(r"\d+", text)
        doc[key] = int(m.group(0)) if m else None
    doc["ok"] = doc["heads"] == 1 and doc["hands"] in (1, 2)
    doc["seconds"] = round(time.time() - t, 1)
    return doc


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    ap.add_argument("--dir", required=True)
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    root = Path(a.dir)
    out = Path("art_runs") / a.run / "vision.json"
    results = json.loads(out.read_text()) if out.exists() else {}
    want = set(filter(None, a.only.split(",")))
    for pose_dir in sorted(p for p in root.iterdir() if p.is_dir()):
        pose = pose_dir.name
        if want and pose not in want and pose.split(".")[0] not in want:
            continue
        for f in sorted(pose_dir.glob("*.png")):
            if f.stem in results.get(pose, {}):
                continue
            results.setdefault(pose, {})[f.stem] = ask(f)
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(json.dumps(results, indent=1) + "\n")
    flagged = sum(not v["ok"] for p in results.values() for v in p.values())
    total = sum(len(p) for p in results.values())
    print(f"{total} candidates asked, {flagged} flagged, {sum(v['seconds'] for p in results.values() for v in p.values()):.0f}s")


if __name__ == "__main__":
    main()
