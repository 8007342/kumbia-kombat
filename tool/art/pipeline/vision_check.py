#!/usr/bin/env python3
"""First-pass curation of a run's candidates with the local vision model, so eyes go to a shortlist.

It asks one plain question per candidate, with the character's own checklist, and writes
art_runs/<run>/vision.json. Advisory: see plan/levels/indoor-band-2026-11-07.md for what it missed.

Usage: vision_check.py <character> --run <run> [--only pose,pose]
"""
from __future__ import annotations

import argparse
import base64
import json
import re
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"
URL = "http://inference:11434/api/generate"
MODEL = "qwen2.5vl:7b"
ASK = ("This is one pixel-art character picture. Answer only with JSON, with these keys: "
       '"arms" (how many arms you can see, a number), "hands" (how many hands), "faces_right" (true if the person faces '
       'toward the right side of the picture), "text" (true if there is any lettering), "faults" (a short list of anything '
       "wrong, such as an extra limb, a broken or doubled object, or a cut-off part). Also: ")


def ask(path: Path, question: str) -> dict:
    data = {"model": MODEL, "stream": False, "format": "json", "prompt": ASK + question,
            "images": [base64.b64encode(path.read_bytes()).decode()]}
    req = urllib.request.Request(URL, json.dumps(data).encode())
    text = json.load(urllib.request.urlopen(req, timeout=300))["response"]
    try:
        return json.loads(text)
    except ValueError:
        m = re.search(r"\{.*\}", text, re.S)
        return json.loads(m.group(0)) if m else {"raw": text}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("character")
    ap.add_argument("--run", required=True)
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    c = json.loads((ROOT / "tool/art/characters" / f"{a.character}.json").read_text())
    question = c.get("drawing", {}).get("visionChecklist", "")
    only = set(filter(None, a.only.split(",")))
    out = ROOT / "art_runs" / a.run / "vision.json"
    doc = json.loads(out.read_text()) if out.exists() else {}
    t = time.time()
    n = 0
    for pose in sorted((CACHE / a.run / "raw").iterdir()):
        if only and pose.name not in only:
            continue
        for png in sorted(pose.glob("*.png")):
            key = f"{pose.name}/{png.stem}"
            if key in doc:
                continue
            doc[key] = ask(png, question)
            n += 1
            print(key, json.dumps(doc[key])[:200], flush=True)
    out.write_text(json.dumps(doc, indent=1) + "\n")
    print(f"vision: {n} images in {time.time() - t:.0f}s")


if __name__ == "__main__":
    main()
