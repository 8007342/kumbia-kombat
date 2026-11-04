#!/usr/bin/env python3
"""Swap a candidate atlas into a built site's manifest, for local review only.

Rewrites build/web/assets/assets/art/ensemble/manifest.json. The committed
assets/art/ensemble/manifest.json is never touched: promoting a candidate into
it needs the owner's acceptance.

Usage:
  python3 tool/art/pipeline/preview_candidate.py assets/art/ensemble/gatekeeper-v3.candidate.json
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

BUILT = Path("build/web/assets/assets/art/ensemble")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("candidate", nargs="+", type=Path)
    a = ap.parse_args()
    # Always start from the committed manifest, so reruns never stack overrides.
    manifest = json.loads(Path("assets/art/ensemble/manifest.json").read_text())
    for path in a.candidate:
        cand = json.loads(path.read_text())
        atlas = cand["atlas"]
        if atlas not in manifest["atlases"]:
            raise SystemExit(f"{path}: the manifest has no atlas {atlas}")
        if not (BUILT / cand["image"]).is_file():
            raise SystemExit(f"{BUILT / cand['image']} is missing: build the site first")
        manifest["atlases"][atlas] = {
            k: v for k, v in cand.items() if k not in ("atlas", "family", "animationReferences")
        }
        print(f"preview: {atlas} -> {cand['image']} ({len(cand['frames'])} frames)")
    (BUILT / "manifest.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
