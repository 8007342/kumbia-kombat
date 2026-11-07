#!/usr/bin/env python3
"""Ask Qwen for one change to a finished atlas frame, keeping everything else.

The frame, scaled up 3x with nearest neighbour, goes in as both reference images with words naming one change. The
candidates land in the art cache. compose (below) pastes back only the named box, so a repair can't drift the rest of the
frame. Jobs and paste boxes are data: art_runs/<run>/repairs.json, {name: {atlas, frame, ask, seed, count, box}}.

Usage: repair_frames.py draw --run R [--only name,name]
       repair_frames.py compose --run R [--sheet PNG]   (applies each repair with a `pick` to the atlases; a repair's
       `box` is [x0,y0,x1,y1] in fractions of its frame, default the whole frame; `target` names another frame to fill)
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import time
from pathlib import Path

import numpy as np
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
        for attempt in range(3):
            try:
                res = lane.call("studio.run_workflow", args)
                text = json.dumps(res)
                if not res.get("isError"):
                    break
                print("retry", name, text[:200], flush=True)
            except (RuntimeError, ConnectionError, OSError) as e:
                print("retry", name, str(e)[:200], flush=True)
                lane = Lane()
            time.sleep(20)
        else:
            print("FAILED", name, flush=True)
            continue
        out.mkdir(parents=True, exist_ok=True)
        for i, png in enumerate(sorted(set(re.findall(r"/work/tmp/imagegen/studio/[^\"\\]+?\.png", text)))):
            shutil.copy(png, out / f"{spec['seed'] + i}.png")
        print(f"ok {name} {time.time() - t:.0f}s", flush=True)
    print("DRAW DONE", flush=True)


def aligned(raw: Image.Image, im: Image.Image, box: tuple[int, int, int, int]) -> tuple[np.ndarray, int, int]:
    """The candidate at frame scale, moved by the offset that best matches the frame outside the repaired box."""
    # The staging placed the frame bottom centre, so start there and search a little.
    W, H = CANVAS
    x0 = (W - im.width * SCALE) // 2
    y0 = H - im.height * SCALE - 48
    a = np.asarray(raw.convert("RGBA")).astype(np.int32)
    src = np.asarray(im).astype(np.int32)
    keep = np.ones(src.shape[:2], bool)
    keep[box[1]:box[3], box[0]:box[2]] = False
    best = None
    for dy in range(-12, 13, 1):
        for dx in range(-12, 13, 1):
            ys = (np.arange(im.height) * SCALE + y0 + SCALE // 2 + dy * SCALE // 2).clip(0, H - 1)
            xs = (np.arange(im.width) * SCALE + x0 + SCALE // 2 + dx * SCALE // 2).clip(0, W - 1)
            s = a[np.ix_(ys, xs)]
            on = keep & (src[..., 3] > 128) & (s[..., 3] > 128)
            score = np.abs(src[..., :3] - s[..., :3]).sum(-1)[on].mean() if on.any() else 1e9
            if best is None or score < best[0]:
                best = (score, s, dx, dy)
    return best[1], best[2], best[3]


def compose(run: str, sheet: str | None) -> None:
    jobs = json.loads((ROOT / "art_runs" / run / "repairs.json").read_text())
    rows = []
    atlases: dict[str, Image.Image] = {}
    for name, spec in jobs.items():
        if "pick" not in spec:
            continue
        target = spec.get("target", spec["frame"])
        before, a = frame_of(spec["atlas"], target)
        source, _ = frame_of(spec["atlas"], spec["frame"])
        folder = ROOT / "assets/art" / MANIFESTS.get(spec["atlas"], "ensemble")
        path = folder / a["image"]
        atlas = atlases.setdefault(str(path), Image.open(path).convert("RGBA"))
        x, y, w, h = a["frames"][target]["rect"]
        f = spec.get("box", [0, 0, 1, 1])
        box = (int(f[0] * w), int(f[1] * h), int(f[2] * w), int(f[3] * h))
        raw = Image.open(CACHE / run / "raw" / name / f"{spec['pick']}.png")
        new, dx, dy = aligned(raw, source, box)
        cut = new[box[1]:box[3], box[0]:box[2]].copy()
        cut[..., 3] = np.where(cut[..., 3] >= 128, 255, 0)
        cut[cut[..., 3] == 0] = 0
        atlas.paste(Image.fromarray(cut.astype(np.uint8), "RGBA"), (x + box[0], y + box[1]))
        rows.append((name, before, atlas.crop((x, y, x + w, y + h)).copy()))
        print(f"{name}: {spec['atlas']}/{target} box {box} offset {dx},{dy}")
    for p, im in atlases.items():
        im.save(p, optimize=True)
    if sheet and rows:
        w = max(b.width for _, b, _ in rows) * 2 + 12
        h = max(b.height for _, b, _ in rows) + 4
        cols = 4
        out = Image.new("RGB", (w * cols, h * ((len(rows) + cols - 1) // cols)), (120, 120, 130))
        for i, (_, b, c) in enumerate(rows):
            ox, oy = (i % cols) * w, (i // cols) * h
            out.paste(b, (ox + 2, oy + 2), b)
            out.paste(c, (ox + 4 + b.width, oy + 2), c)
        out.save(sheet)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["draw", "compose"])
    ap.add_argument("--run", required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--sheet")
    a = ap.parse_args()
    if a.cmd == "compose":
        compose(a.run, a.sheet)
    else:
        draw(a.run, set(filter(None, a.only.split(","))))


if __name__ == "__main__":
    main()
