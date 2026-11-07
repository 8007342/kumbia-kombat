#!/usr/bin/env python3
"""Finish a run's picks into final/, baking the two things a frame can carry without a renderer.

  medallion swing  each drawing's medallion trails the body: its sideways offset comes from how far the neck moved
                   since the previous drawing in the rig, so a dance carries the swing with no new code in the game.
                   A rear view has no medallion and is left alone, as is any frame where none is found.
  nod              crossed.nod_down and crossed.nod_up are crossed.hold with the head moved, so nothing but the head
                   moves and nothing flickers. Qwen redrew the whole figure each time and barely bowed the head.

Usage: finish_picks.py --run <run> --character <id> --picks art_runs/<run>/picks.json --root DIR
picks: {pose: seed suffix, or "run:suffix" for a frame from another run under the same art cache}.
Writes art_runs/<run>/final/<pose>.png, selection.json and swing.json.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import chain_layer as CL  # noqa: E402
import definitions as D  # noqa: E402
import finish_local as FL  # noqa: E402

SEED_PREFIX = "9870"
CARRIES_MEDALLION = lambda clip, name: not clip.startswith("back_") and clip != "crossed" and f"{clip}.{name}" not in ("reveal.glance", "reveal.rear_3q", "reveal.profile")  # noqa: E731
GAIN = 0.5   # native pixels of swing per native pixel the neck moved
LIMIT = 4
NOD = {"crossed.nod_down": 5, "crossed.nod_up": 1}


def swing_offsets(c: dict, rig: dict, scale: int) -> dict[str, int]:
    motion = D.load_motion(c["motion"]["set"])
    loops = {m["id"]: m.get("loop", False) for m in motion["clips"]}
    by_clip: dict[str, list[dict]] = {}
    for p in rig["poses"]:
        by_clip.setdefault(p["id"].split(".")[0], []).append(p)
    out = {}
    for clip, poses in by_clip.items():
        for i, p in enumerate(poses):
            if i == 0 and not loops.get(clip):
                out[p["id"]] = 0
                continue
            moved = (p["openpose"][1][0] - poses[i - 1]["openpose"][1][0]) / scale
            out[p["id"]] = int(np.clip(round(-moved * GAIN), -LIMIT, LIMIT))
    return out


def nod_frame(hold: np.ndarray, pose: dict, scale: int, down: int) -> np.ndarray:
    """The head and neck slide down over the collar: every pixel above the chin line moves, and the top empties."""
    op = pose["openpose"]
    cut = int(op[1][1] / scale) - 3
    out = hold.copy()
    head = hold[:cut]
    keep = head[..., 3] > 0
    out[:cut] = 0
    region = out[down:cut + down]
    region[keep] = head[keep]
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    ap.add_argument("--character", required=True)
    ap.add_argument("--picks", required=True)
    ap.add_argument("--root", required=True)
    ap.add_argument("--scale", type=int, default=3)
    a = ap.parse_args()
    c = D.load_character(a.character)
    picks = json.loads(Path(a.picks).read_text())
    run_dir = Path("art_runs") / a.run
    (run_dir / "final").mkdir(parents=True, exist_ok=True)
    palette = FL.palette_of(f"tool/art/palettes/{c['id']}.json")
    rig = json.loads(Path(f"art_runs/inputs/{c['family']}/rig.json").read_text())
    poses = {p["id"]: p for p in rig["poses"]}
    offsets = swing_offsets(c, rig, a.scale)
    scores = json.loads((run_dir / "scores.json").read_text()) if (run_dir / "scores.json").exists() else {}
    selection, report = {}, {}
    root = Path(a.root)
    for pid, pick in picks.items():
        other, _, suffix = pick.rpartition(":")
        base = root.parent / other if other else root
        src = base / "registered" / pid / f"{SEED_PREFIX}{suffix}.png"
        frame = np.asarray(FL.finish(src, palette, a.scale)).copy()
        clip, name = pid.split(".", 1)
        moved = 0
        note = ""
        if pid not in NOD and CARRIES_MEDALLION(clip, name) and offsets.get(pid):
            try:
                frame, moved = CL.swung(frame, np.asarray(Image.open(src).convert("RGBA")), poses[pid], offsets[pid], a.scale)
            except CL.NoMedallion as e:
                note = str(e)
        Image.fromarray(frame, "RGBA").save(run_dir / "final" / f"{pid}.png", optimize=False)
        selection[pid] = {"k": f"{SEED_PREFIX}{suffix}", "run": other or a.run, "score": scores.get(pid, {}).get(f"{SEED_PREFIX}{suffix}", {}).get("score")}
        report[pid] = {"swing": moved, **({"note": note} if note else {})}
    hold_path = run_dir / "final" / "crossed.hold.png"
    hold = np.asarray(Image.open(hold_path)) if hold_path.exists() else None
    for pid, down in NOD.items():
        if hold is None or pid not in picks:
            continue
        Image.fromarray(nod_frame(hold, poses["crossed.hold"], a.scale, down), "RGBA").save(run_dir / "final" / f"{pid}.png", optimize=False)
        report[pid] = {"derivedFrom": "crossed.hold", "headDown": down}
    (run_dir / "selection.json").write_text(json.dumps(selection, indent=1) + "\n")
    (run_dir / "swing.json").write_text(json.dumps(report, indent=1) + "\n")
    print(len(selection), "finished;", sum(1 for v in report.values() if v.get("swing")), "swung;", [k for k, v in report.items() if v.get("note")])


if __name__ == "__main__":
    main()
