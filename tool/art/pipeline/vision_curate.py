#!/usr/bin/env python3
"""First-pass curation with the local vision model: flag candidates with anatomy or costume errors.

A first pass only. It asks qwen2.5vl about one candidate at a time on a flat grey background, and records the
answers beside the scores, so a person reads a shortlist instead of every frame. How far to trust it is measured
in plan/levels/blinblin-sprites-2026-11-07.md. Safe to restart: finished candidates are kept.

Usage: vision_curate.py --run <run> --dir <registered dir> [--only pose,clip] [--ledger AGENT] [--poses-file F]
Writes art_runs/<run>/vision.json: {pose: {seed: {"arms": n, "hands": n, "ok": bool, "note": str, "seconds": s}}}.
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
FRONT = ("This is a pixel art sprite of a man in a long purple coat with gold chains. Check the drawing carefully. "
         "Count the arms you can see and the hands you can see. Answer only with JSON: "
         '{"arms": <number>, "hands": <number>, "extra_limb": <true or false>, "broken": <true or false>, "note": "<up to 8 words>"}. '
         '"broken" means a deformed body, melted hand, cut-off head or feet, or stray shapes.')
BACK = FRONT.replace("gold chains", "a thin gold neck chain, seen from behind")


def ask(path: Path, prompt: str) -> dict:
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, (150, 150, 155, 255))
    bg.alpha_composite(im)
    box = im.getbbox()
    buf = io.BytesIO()
    bg.crop(box).convert("RGB").save(buf, "PNG")
    t = time.time()
    body = json.dumps({"model": MODEL, "stream": False, "prompt": prompt, "images": [base64.b64encode(buf.getvalue()).decode()],
                       "format": "json", "options": {"temperature": 0}}).encode()
    text = json.load(u.urlopen(u.Request(URL, body), timeout=600))["response"]
    try:
        doc = json.loads(text)
    except ValueError:
        m = re.search(r"\{.*\}", text, re.S)
        doc = json.loads(m.group(0)) if m else {"note": text[:60], "unparsed": True}
    arms, hands = doc.get("arms"), doc.get("hands")
    doc["ok"] = not (doc.get("extra_limb") or doc.get("broken") or doc.get("unparsed")) and arms in (2, None) and hands in (2, None)
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
            prompt = BACK if pose.startswith(("back_", "reveal.glance", "reveal.rear")) else FRONT
            results.setdefault(pose, {})[f.stem] = ask(f, prompt)
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(json.dumps(results, indent=1) + "\n")
    flagged = sum(not v["ok"] for p in results.values() for v in p.values())
    total = sum(len(p) for p in results.values())
    print(f"{total} candidates asked, {flagged} flagged, {sum(v['seconds'] for p in results.values() for v in p.values()):.0f}s")


if __name__ == "__main__":
    main()
