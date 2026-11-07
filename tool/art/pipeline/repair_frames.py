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
from scipy import ndimage as ndi

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_jobs import GRAPH, LORA, Lane  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"
STAGE = Path("/work/tmp/imagegen/kumbia")
REPAIRS = "repairs.json"
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
    jobs = json.loads((ROOT / "art_runs" / run / REPAIRS).read_text())
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
    if keep.mean() < .4:  # A repair of most of the frame: the rest of the figure still lines it up.
        keep[:] = True
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
    jobs = json.loads((ROOT / "art_runs" / run / REPAIRS).read_text())
    rows = []
    atlases: dict[str, Image.Image] = {}
    cursors: dict[str, tuple[int, int, int]] = {}
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
        if spec.get("append"):
            # A new pose wider than its old rect: a fresh strip at the bottom of the atlas, with its own rect and anchor.
            W, H = CANVAS
            ax0 = a["frames"][spec["frame"]]["anchor"][0]
            x0 = (W - source.width * SCALE) // 2 + dx * SCALE // 2
            y0 = H - source.height * SCALE - 48 + dy * SCALE // 2
            arr = np.asarray(raw.convert("RGBA")).astype(np.uint8)
            xs = np.arange(x0 % SCALE + SCALE // 2, W, SCALE)
            ys = np.arange(y0 % SCALE + SCALE // 2, H, SCALE)
            whole = arr[np.ix_(ys, xs)].copy()
            whole[..., 3] = np.where(whole[..., 3] >= 128, 255, 0)
            labels, count = ndi.label(whole[..., 3] > 0)
            if count > 1:  # Qwen copies a stray piece of a neighbour along with the frame.
                sizes = ndi.sum(whole[..., 3] > 0, labels, range(1, count + 1))
                whole[labels != 1 + int(np.argmax(sizes))] = 0
            whole[whole[..., 3] == 0] = 0
            pic = Image.fromarray(whole, "RGBA")
            l, t, r, b = pic.getbbox()
            ox, oy = (x0 - x0 % SCALE) // SCALE, (y0 - y0 % SCALE) // SCALE
            for cx, cy, cw, ch in spec.get("clear", []):
                pw, ph = r - l, b - t
                whole[t + int(cy * ph):t + int(ch * ph), l + int(cx * pw):l + int(cw * pw)] = 0
            pic = Image.fromarray(whole, "RGBA")
            l, t, r, b = pic.getbbox()
            # Qwen draws a little larger. Back to this frame's own height, so nobody grows between drawings.
            fit = source.height / (b - t)
            cut = pic.crop((l, t, r, b)).resize((round((r - l) * fit), source.height), Image.NEAREST)
            shift = (ax0 + ox - l) * fit
            pic, l, t, r, b = cut, 0, 0, cut.width, cut.height
            px, strip, shelf = cursors.get(str(path), (2, atlas.height + 2, 0))
            if px + (r - l) + 2 > atlas.width:
                px, strip, shelf = 2, strip + shelf + 2, 0
            shelf = max(shelf, b - t)
            grown = Image.new("RGBA", (atlas.width, max(atlas.height, strip + shelf)), (0, 0, 0, 0))
            grown.paste(atlas, (0, 0))
            grown.paste(pic.crop((l, t, r, b)), (px, strip))
            atlases[str(path)] = atlas = grown
            cursors[str(path)] = (px + (r - l) + 2, strip, shelf)
            doc = json.loads((folder / "manifest.json").read_text())
            entry = doc["atlases"][spec["atlas"]]
            entry["frames"][target]["rect"] = [px, strip, r - l, b - t]
            # Every guest frame's anchor sits on its feet, at the bottom of its rect.
            entry["frames"][target]["anchor"] = [round(shift, 1), b - t]
            entry["imageHeight"] = grown.height
            (folder / "manifest.json").write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n")
            rows.append((name, before, pic.crop((l, t, r, b))))
            print(f"{name}: {spec['atlas']}/{target} appended at y {strip}")
            continue
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
    ap.add_argument("--file", default="repairs.json")
    a = ap.parse_args()
    global REPAIRS
    REPAIRS = a.file
    if a.cmd == "compose":
        compose(a.run, a.sheet)
    else:
        draw(a.run, set(filter(None, a.only.split(","))))


if __name__ == "__main__":
    main()
