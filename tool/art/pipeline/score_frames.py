#!/usr/bin/env python3
"""Score registered sheet-driven frames against the rig's joints, and pick one per pose.

Qwen keeps the character but can wander from the pose, so each candidate is measured where the
rig says the body should be: a wrist needs skin nearby, an ankle a shoe, a knee trousers, and an
elbow any part of the figure. Joints alone can't see a hand in the wrong place, so silhouettes are
compared too: `extra` is figure outside the rig's silhouette (an arm behind the head), `missing` is
rig silhouette the figure doesn't reach (a lost hand), each as a percentage of the rig's area, with
a tolerance because Qwen's body is not the rig's. Score: mean joint distance plus the worst joint,
plus extra and missing. Lower is better.

Usage:
  score_frames.py --run <run> --family gatekeeper-v3 [--dir registered] [--flag 45]
Reads <dir>/<pose>[/<k>].png, where <dir> is absolute or under art_runs/<run>. Writes
art_runs/<run>/scores.json and selection.json. Scores rank candidates: they can't see a missing
hand or an extra arm, so look at every clip before accepting a selection.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

# OpenPose COCO-18 indices in rig.json
JOINTS = {"r_wri": 4, "l_wri": 7, "r_elb": 3, "l_elb": 6, "r_kne": 9, "l_kne": 12, "r_ank": 10, "l_ank": 13}
TOLERANCE = 18  # canvas pixels


def near(rgb: np.ndarray, colour: np.ndarray, tol: int) -> np.ndarray:
    return np.abs(rgb.astype(int) - colour).max(axis=-1) < tol


def skin_mask(rgb: np.ndarray) -> np.ndarray:
    """Hue test: skin shades vary from lit to shadow far more than their hue does."""
    r, g, b = [rgb[..., i].astype(int) for i in range(3)]
    return (r > 90) & (r - g > 35) & (g - b > 15)


def measure(path: Path, pose: dict, rig_mask: np.ndarray, trousers: np.ndarray, shoes: np.ndarray) -> dict:
    a = np.array(Image.open(path).convert("RGBA"))
    rgb, fig = a[..., :3], a[..., 3] > 128
    h, w = fig.shape
    ys, xs = np.where(fig)
    head = np.array(pose["openpose"][0][:2])
    yy, xx = np.ogrid[:h, :w]
    near_head = (xx - head[0]) ** 2 + (yy - head[1]) ** 2 < (pose["headWidthPx"] * 0.75) ** 2
    skin = skin_mask(rgb) & fig
    fields = {
        "wri": ndi.distance_transform_edt(~(skin & ~near_head)) if (skin & ~near_head).any() else None,
        "kne": ndi.distance_transform_edt(~(near(rgb, trousers, 60) & fig)),
        "ank": ndi.distance_transform_edt(~(near(rgb, shoes, 60) & fig)),
        "elb": ndi.distance_transform_edt(~fig),
    }
    errors = {}
    for name, i in JOINTS.items():
        x, y, visible = pose["openpose"][i]
        if not visible:
            continue
        field = fields[name[2:]]
        x, y = min(max(int(x), 0), w - 1), min(max(int(y), 0), h - 1)
        errors[name] = round(float(field[y, x]), 1) if field is not None else 999.0
    values = list(errors.values())
    area = rig_mask.sum()
    extra = 100 * (fig & ~ndi.binary_dilation(rig_mask, iterations=TOLERANCE)).sum() / area
    missing = 100 * (rig_mask & ~ndi.binary_dilation(fig, iterations=TOLERANCE)).sum() / area
    return {
        "score": round(float(np.mean(values) + max(values) + extra + missing), 1),
        "extra": round(float(extra), 1),
        "missing": round(float(missing), 1),
        "worst": max(errors, key=errors.get),
        "errors": errors,
        "touchesFrame": bool(xs.min() == 0 or ys.min() == 0 or xs.max() == w - 1 or ys.max() == h - 1),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    ap.add_argument("--family", required=True)
    ap.add_argument("--dir", default="registered")
    ap.add_argument("--flag", type=float, default=45.0, help="best score above this needs a look")
    a = ap.parse_args()
    run = Path("art_runs") / a.run
    rig_dir = Path("art_runs/inputs") / a.family
    # Each joint looks for the part that should be at it, in the family's own colours.
    proxy = json.loads(Path(f"tool/art/families/{a.family}.json").read_text())["regionProxyColours"]
    trousers, shoes = (np.array([int(proxy[k][i : i + 2], 16) for i in (1, 3, 5)]) for k in ("trousers", "shoes"))
    poses = {p["id"]: p for p in json.loads((rig_dir / "rig.json").read_text())["poses"]}
    root = run / a.dir if not Path(a.dir).is_absolute() else Path(a.dir)
    scores, selection, flagged = {}, {}, []
    for pid, pose in poses.items():
        paths = sorted((root / pid).glob("*.png")) if (root / pid).is_dir() else [root / f"{pid}.png"]
        regions = np.array(Image.open(rig_dir / f"{pid}.regions.png").convert("RGBA"))
        rig_mask = regions[..., 3] > 0
        if rig_mask.all():
            rig_mask = regions[..., :3].max(axis=-1) > 8
        cands = {p.stem if p.parent.name == pid else "0": measure(p, pose, rig_mask, trousers, shoes) for p in paths if p.exists()}
        if not cands:
            continue
        scores[pid] = cands
        usable = {k: v for k, v in cands.items() if not v["touchesFrame"]} or cands
        best = min(usable, key=lambda k: usable[k]["score"])
        selection[pid] = {"k": best, "score": usable[best]["score"]}
        if usable[best]["score"] > a.flag:
            flagged.append(pid)
    (run / "scores.json").write_text(json.dumps(scores, indent=1) + "\n")
    (run / "selection.json").write_text(json.dumps(selection, indent=1) + "\n")
    print(json.dumps({"poses": len(selection), "flagged": flagged}))


if __name__ == "__main__":
    main()
