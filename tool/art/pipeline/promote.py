#!/usr/bin/env python3
"""Promote an accepted candidate atlas into the committed ensemble manifest.

Run this only after the owner has accepted the candidate in a test play. It
takes the candidate's atlas block as preview_candidate.py does, and writes
assets/art/ensemble/manifest.json. Remove the candidate's line from
tool/local_preview_candidates.txt afterwards.

Usage:
  python3 tool/art/pipeline/promote.py assets/art/ensemble/gatekeeper-v3.candidate.json
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ENSEMBLE = Path("assets/art/ensemble")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("candidate", nargs="+", type=Path)
    ap.add_argument("--new", action="store_true", help="also add an atlas the manifest doesn't have yet")
    a = ap.parse_args()
    path = ENSEMBLE / "manifest.json"
    manifest = json.loads(path.read_text())
    for cand_path in a.candidate:
        cand = json.loads(cand_path.read_text())
        atlas = cand["atlas"]
        if atlas not in manifest["atlases"] and not a.new:
            raise SystemExit(f"{cand_path}: the manifest has no atlas {atlas}")
        if not (ENSEMBLE / cand["image"]).is_file():
            raise SystemExit(f"{ENSEMBLE / cand['image']} is missing")
        manifest["atlases"][atlas] = {
            k: v for k, v in cand.items() if k not in ("atlas", "family", "animationReferences")
        }
        print(f"promoted: {atlas} -> {cand['image']} ({len(cand['frames'])} frames)")
    path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
