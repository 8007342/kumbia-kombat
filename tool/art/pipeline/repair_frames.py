#!/usr/bin/env python3
"""Ask Qwen for one change to a finished atlas frame, keeping everything else.

The frame, scaled up 3x with nearest neighbour, goes in as both reference images with words naming one change. The
candidates land in the art cache. compose (below) pastes back only the named box, so a repair can't drift the rest of the
frame. Jobs and paste boxes are data: art_runs/<run>/repairs.json, {name: {atlas, frame, ask, seed, count, box}}.

Usage: repair_frames.py draw --run R [--only name,name]
       repair_frames.py compose --run R --out DIR   (one before/after per repair with a pick)
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import time
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_jobs import GRAPH, LORA, Lane  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"
STAGE = Path("/work/tmp/imagegen/kumbia")
GREY = (226, 226, 226, 255)
SCALE = 3
CANVAS = (768, 960)
MANIFESTS = {"hero": "party"}
WORDS = ("Image 1 is a finished pixel art game sprite of one person on a plain grey background; image 2 is the same picture. "
         "Redraw exactly the same person at exactly the same size and position, with the same pose, face, hair, clothes, colours, "
         "thick dark ink outline and crisp pixel art style. Change only this: {ask} Everything else stays exactly as it is. "
         "A grown adult, fully clothed. Exactly two arms and two hands. Plain light grey background.")


def frame_of(atlas: str, frame: str, base: Path = ROOT) -> tuple[Image.Image, dict]:
    folder = base / "assets/art" / MANIFESTS.get(atlas, "ensemble")
    a = json.loads((folder / "manifest.json").read_text())["atlases"][atlas]
    im = Image.open(folder / a["image"]).convert("RGBA")
    x, y, w, h = a["frames"][frame]["rect"]
    return im.crop((x, y, x + w, y + h)), a


def staged(run: str, name: str, spec: dict) -> Path:
    im, _ = frame_of(spec["atlas"], spec["frame"])
    big = im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST)
    bg = Image.new("RGBA", CANVAS, GREY)
    bg.alpha_composite(big, ((CANVAS[0] - big.width) // 2, CANVAS[1] - big.height - 48))
    path = STAGE / run / "in" / f"{name}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    bg.convert("RGB").save(path)
    return path


def draw(run: str, only: set[str]) -> None:
    jobs = json.loads((ROOT / "art_runs" / run / "repairs.json").read_text())
    lane = Lane()
    for name, spec in jobs.items():
        if only and name not in only:
            continue
        out = CACHE / run / "raw" / name
        want = spec.get("count", 2)
        if out.is_dir() and len(list(out.glob("*.png"))) >= want:
            continue
        src = staged(run, name, spec)
        t = time.time()
        args = {"workflow": GRAPH, "tier": "I1", "count": want, "inputs": {"sheet_front": str(src), "pose_proxy": str(src)},
                "overrides": {"seed": spec["seed"], "$node:30.lora_name": LORA, "$node:10.prompt": WORDS.format(ask=spec["ask"])}}
        res = lane.call("studio.run_workflow", args)
        text = json.dumps(res)
        if res.get("isError"):
            print("FAILED", name, text[:300], flush=True)
            continue
        out.mkdir(parents=True, exist_ok=True)
        for i, png in enumerate(sorted(set(re.findall(r"/work/tmp/imagegen/studio/[^\"\\]+?\.png", text)))):
            shutil.copy(png, out / f"{spec['seed'] + i}.png")
        print(f"ok {name} {time.time() - t:.0f}s", flush=True)
    print("DRAW DONE", flush=True)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["draw"])
    ap.add_argument("--run", required=True)
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    draw(a.run, set(filter(None, a.only.split(","))))


if __name__ == "__main__":
    main()
