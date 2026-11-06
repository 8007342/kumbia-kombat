#!/usr/bin/env python3
"""Add a candidate atlas's frames to a live atlas: stacks the images and shifts rects.

Keeps a character in one atlas, so its frames share one reference frame and scale.
Writes a new image beside the old one and updates the manifest entry.

Usage:
  append_candidate_frames.py MANIFEST ATLAS CANDIDATE.json NEW_IMAGE.png --only id id ...
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("manifest", type=Path)
    ap.add_argument("atlas")
    ap.add_argument("candidate", type=Path)
    ap.add_argument("image", type=Path)
    ap.add_argument("--only", nargs="*", help="frame ids to take; default all")
    a = ap.parse_args()
    manifest = json.loads(a.manifest.read_text())
    entry = manifest["atlases"][a.atlas]
    cand = json.loads(a.candidate.read_text())
    live = Image.open(a.manifest.parent / entry["image"]).convert("RGBA")
    extra = Image.open(a.candidate.with_suffix("").with_suffix(".png")).convert("RGBA")
    width = max(live.width, extra.width)
    sheet = Image.new("RGBA", (width, live.height + extra.height))
    sheet.paste(live, (0, 0))
    sheet.paste(extra, (0, live.height))
    sheet.save(a.image, optimize=True)
    wanted = set(a.only) if a.only else set(cand["frames"])
    for frame_id in sorted(wanted):
        if frame_id in entry["frames"]:
            raise SystemExit(f"{a.atlas} already has frame {frame_id}")
        frame = dict(cand["frames"][frame_id])
        x, y, w, h = frame["rect"]
        frame["rect"] = [x, y + live.height, w, h]
        entry["frames"][frame_id] = frame
    entry["image"] = a.image.name
    entry["imageWidth"] = sheet.width
    entry["imageHeight"] = sheet.height
    a.manifest.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n")
    print(f"{a.atlas}: +{len(wanted)} frames -> {a.image} {sheet.size}")


if __name__ == "__main__":
    main()
