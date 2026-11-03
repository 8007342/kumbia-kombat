#!/usr/bin/env python3
"""Pack finished native-grid frames into an atlas and a candidate manifest.

Input: art_runs/<run>/final/<pose-id>.png — one RGBA frame per pose, already
through studio.finish_pixels (native grid, locked palette, binary alpha).
Output (kumbiaManifest target of the family spec):
  <target.out>                          atlas PNG (shelf packed, gutters)
  <target.out stem>.candidate.json      manifest atlas block, status "candidate"

The live assets/art/ensemble/manifest.json is never touched here: the spec's
requireHumanAcceptance gate promotes a candidate with promote.py after review.

Frame ids follow target.frameId ("{clip}_{drawing}"); anchors are relative to
the trimmed rect: x = the rig's support-foot pivot, y = the ground line, both
mapped through the generation->native scale.

Usage:
  python3 tool/art/pipeline/pack_atlas.py tool/art/families/gatekeeper-v3.json --run <run>
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("spec")
    ap.add_argument("--run", required=True)
    ap.add_argument("--max-width", type=int, default=1024)
    a = ap.parse_args()

    spec = json.loads(Path(a.spec).read_text())
    target = next(t for t in spec["targets"] if t["type"] == "kumbiaManifest")
    room = target["room"]
    native = spec["frame"]["native"]
    native = native[room] if native.get("perRoom") else native
    scale = native["pixelScale"]
    gutter = target.get("packing", {}).get("gutterPx", 2)
    run_dir = Path("art_runs") / a.run
    rig = json.loads((Path(spec["rigInputs"]) / "rig.json").read_text())
    rig_by_id = {p["id"]: p for p in rig["poses"]}
    clips = {c["id"]: c for c in spec["clips"]}
    selections = {}
    sel_p = run_dir / "selection.json"
    if sel_p.exists():
        selections = json.loads(sel_p.read_text())

    frames, tiles = {}, []
    for pose in spec["poses"]:
        f = run_dir / "final" / f"{pose['id']}.png"
        if not f.exists():
            continue
        im = Image.open(f).convert("RGBA")
        bbox = im.getbbox()
        if not bbox:
            raise SystemExit(f"empty frame {f}")
        tiles.append((pose, im.crop(bbox), bbox, f))

    # shelf pack, tallest first
    tiles.sort(key=lambda t: -t[1].height)
    x = y = shelf_h = 0
    W = a.max_width
    placed = []
    for pose, im, bbox, f in tiles:
        if x + im.width + gutter > W:
            x, y, shelf_h = 0, y + shelf_h + gutter, 0
        placed.append((pose, im, bbox, f, x + gutter, y + gutter))
        x += im.width + gutter
        shelf_h = max(shelf_h, im.height)
    H = y + shelf_h + 2 * gutter
    atlas = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # Scale: the reference pose keeps the in-game height of the live atlas's
    # reference frame (fixed-per-family), so v3 drops in at the same size.
    live = json.loads(Path(target["manifest"]).read_text())["atlases"].get(target["atlas"], {})
    ref_live = live.get("frames", {}).get(live.get("referenceFrame", ""), {})
    world_h = ref_live["rect"][3] / ref_live["pixelsPerUnit"] if ref_live else 38.75
    ref_id = spec["frame"]["scale"]["referencePose"]
    ref_tile = next((t for t in tiles if t[0]["id"] == ref_id), tiles[0])
    ppu = round(ref_tile[1].height / world_h, 4)

    for pose, im, bbox, f, px, py in placed:
        atlas.paste(im, (px, py))
        rp = rig_by_id.get(pose["id"], {})
        ax = rp.get("pivotX", 0) / scale - bbox[0]
        ay = rp.get("groundY", 0) / scale - bbox[1]
        clip = clips.get(pose["clip"], {})
        drawing = pose["id"].split(".", 1)[1]
        fid = target["frameId"].format(clip=pose["clip"], drawing=drawing)
        frames[fid] = {
            "rect": [px, py, im.width, im.height],
            "anchor": [round(ax, 1), round(ay, 1)],
            "pixelsPerUnit": ppu,
            "facing": "front",
            "loop": clip.get("loop", False),
            "durationBeats": clip.get("durationBeats"),
            "events": [e for e in clip.get("events", []) if e.get("drawing") == drawing],
            "supportFoot": pose.get("supportFoot"),
            "status": "candidate",
            "provenance": {
                "run": a.run,
                "pose": pose["id"],
                "sha256": hashlib.sha256(f.read_bytes()).hexdigest(),
                "selected": selections.get(pose["id"]),
                "animationPrinciples": pose.get("animationPrinciples", []),
            },
        }

    out = Path(target["out"])
    out.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(out, optimize=False)
    cand = out.with_suffix(".candidate.json")
    cand.write_text(json.dumps({
        "atlas": target["atlas"],
        "image": out.name,
        "imageWidth": W,
        "imageHeight": H,
        "referenceFrame": target["frameId"].format(clip="groove", drawing="down_l"),
        "family": a.spec,
        "animationReferences": spec.get("animationReferences"),
        "frames": dict(sorted(frames.items())),
    }, indent=1, ensure_ascii=False) + "\n")
    print(f"packed {len(frames)} frames -> {out} ({W}x{H}), {cand}")


if __name__ == "__main__":
    main()
