#!/usr/bin/env python3
"""Put sheet-driven frames back on the rig: same height, same floor line, same torso position.

Qwen draws from a skeleton, so its figure's scale and position wander per frame. Left alone that
reads as jitter. Each frame is scaled so its figure height matches the rig's silhouette in that
pose, which keeps the rig's bounce, then moved so the feet share the rig's floor line and the torso
sits over the rig's torso.

Usage: register_frames.py --run <run> --family gatekeeper-v3 [--shirt 5f1f5f] [--root DIR]
Reads <root>/raw/<pose>.png or <root>/raw/<pose>/<k>.png, and writes the same layout under
<root>/registered/. <root> defaults to art_runs/<run>. A frame with an alpha channel uses it as the
matte, binarised at 128 and reduced to the largest piece; an opaque one is keyed off its background.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi


def figure_mask(rgb: np.ndarray) -> np.ndarray:
    """Everything that differs from the flat background sampled at the frame's corners."""
    h, w, _ = rgb.shape
    corners = np.concatenate([rgb[:24, :24], rgb[:24, -24:]]).reshape(-1, 3)
    bg = np.median(corners, axis=0)
    far = np.abs(rgb.astype(int) - bg).max(axis=-1) > 18
    labels, n = ndi.label(ndi.binary_closing(far, iterations=2))
    if not n:
        raise SystemExit("no figure found")
    sizes = ndi.sum(far, labels, range(1, n + 1))
    figure = labels == 1 + int(np.argmax(sizes))
    # Fill holes the figure encloses, except background showing through, such as the gap inside
    # an arm on the hip: those must stay transparent.
    holes, m = ndi.label(ndi.binary_fill_holes(figure) & ~figure)
    for i in range(1, m + 1):
        region = holes == i
        if np.abs(np.median(rgb[region], axis=0) - bg).max() > 18:
            figure |= region
    return figure


def matte_mask(alpha: np.ndarray) -> np.ndarray:
    """Binary matte without stray fragments, keeping background gaps as the matte drew them."""
    solid = alpha >= 128
    labels, n = ndi.label(solid)
    if not n:
        raise SystemExit("empty matte")
    return labels == 1 + int(np.argmax(ndi.sum(solid, labels, range(1, n + 1))))


def bbox(mask: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.where(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def torso_x(rgb: np.ndarray, mask: np.ndarray, shirt: np.ndarray) -> float:
    """Median x of shirt-coloured pixels: arms and hat can't pull it the way a bbox centre can."""
    near = np.abs(rgb.astype(int) - shirt).max(axis=-1) < 48
    xs = np.where(mask & near)[1]
    return float(np.median(xs)) if xs.size else float(np.median(np.where(mask)[1]))


def register(src: Path, dst: Path, rig: Path, pose: str, shirt: np.ndarray, torso: np.ndarray) -> dict:
    source = Image.open(src)
    im = source.convert("RGB")
    rgb = np.array(im)
    mask = matte_mask(np.array(source.convert("RGBA"))[..., 3]) if source.mode == "RGBA" else figure_mask(rgb)
    x0, y0, x1, y1 = bbox(mask)

    regions = np.array(Image.open(rig / f"{pose}.regions.png").convert("RGBA"))
    rmask = regions[..., 3] > 0
    if rmask.all():
        rmask = regions[..., :3].max(axis=-1) > 8
    _, ry0, _, ry1 = bbox(rmask)
    rtorso = np.where(np.all(regions[..., :3] == torso, axis=-1))[1]
    rx = float(np.median(rtorso)) if rtorso.size else im.width / 2

    s = (ry1 - ry0) / (y1 - y0)
    tx = torso_x(rgb, mask, shirt)
    w, h = im.size
    rgba = im.convert("RGBA")
    rgba.putalpha(Image.fromarray((mask * 255).astype(np.uint8)))
    big = rgba.resize((round(w * s), round(h * s)), Image.LANCZOS)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # Slide a wide pose back inside the frame sideways; a pose wider than the frame still crops,
    # and touchesFrame below reports it.
    px = round(rx - tx * s)
    left, right = px + round(x0 * s), px + round(x1 * s)
    if right - left < w:
        px += max(0, 1 - left) - max(0, right - (w - 1))
    canvas.paste(big, (px, round(ry1 - y1 * s)))
    dst.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dst)
    ox0, oy0, ox1, oy1 = bbox(np.array(canvas)[..., 3] > 128)
    return {"scale": round(s, 3), "touchesFrame": ox0 == 0 or oy0 == 0 or ox1 == w or oy1 == h}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    ap.add_argument("--family", required=True)
    ap.add_argument("--shirt", default="5f1f5f")
    ap.add_argument("--rig-torso", default="0000ff", help="the torso's colour in the rig's regions image")
    ap.add_argument("--root", default="", help="folder holding raw/, if not art_runs/<run>")
    a = ap.parse_args()

    root = Path(a.root) if a.root else Path("art_runs") / a.run
    rig = Path("art_runs/inputs") / a.family
    out = root / "registered"
    shirt = np.array([int(a.shirt[i : i + 2], 16) for i in (0, 2, 4)])
    torso = np.array([int(a.rig_torso[i : i + 2], 16) for i in (0, 2, 4)])
    report = {}
    for src in sorted((root / "raw").rglob("*.png")):
        rel = src.relative_to(root / "raw")
        pose = rel.stem if rel.parent == Path(".") else rel.parent.name
        report[str(rel.with_suffix(""))] = register(src, out / rel, rig, pose, shirt, torso)
    out.mkdir(exist_ok=True)
    (out / "registration.json").write_text(json.dumps(report, indent=1) + "\n")
    print(f"{len(report)} registered, {sum(v['touchesFrame'] for v in report.values())} touch the frame")


if __name__ == "__main__":
    main()
