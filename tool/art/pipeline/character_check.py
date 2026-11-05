#!/usr/bin/env python3
"""Compare a character's finished frames to its sheet and source art: same build, and all there?

The Gatekeeper's skinny wave was caught only by eye (LESSONS_LEARNED A8), and pose scores can't see it
because they reward matching the rig. This measures build as central width over height: the median
width of the connected run through the body's middle, chest to belly (the definition used on the
Gatekeeper v4 pilot, art_runs/gatekeeper-v4-20261105q/measure_build.py). An arm with a gap beside the
body doesn't count, and an arm touching it does, so a relaxed sheet reads somewhat wider than a dance
pose: it compares across sizes and backgrounds, and only roughly across poses.

Frames are compared with the sheet and, when drawing.buildReference names the art the owner has in
mind, both are compared with that. Measured: Gatekeeper v3 frames 0.294 against sheet 0.396 and
original 0.346; Bartender frames 0.221 against sheet 0.216 and original 0.215.

Thresholds are advisory, calibrated on two characters: a verdict is a prompt to look, and the exit
status stays 0 unless --strict.

Usage: character_check.py <character|file.json> --run <run> [--dir final]
Reads art_runs/<run>/<dir>/<pose>.png, or <pose>/<k>.png. Uses the sheet's front view, and the clips
the character's motion defines. Reserved clips are reported as reserved, not missing.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import definitions as D  # noqa: E402
import plan_qwen_frames as Q  # noqa: E402
from register_frames import figure_mask, matte_mask  # noqa: E402

BAND = (0.35, 0.60)  # of the figure's height from its top: chest to belly on an adult, before the legs part
ADVISORY = 0.15  # relative difference worth a look: the Bartender's frames sit at +2% of her sheet, Gatekeeper v3's at -26%


def mask_of(path: Path, rect: list[int] | None = None) -> np.ndarray:
    src = Image.open(path)
    if rect:
        x, y, w, h = rect
        src = src.crop((x, y, x + w, y + h))
    rgba = np.array(src.convert("RGBA"))
    if rgba[..., 3].min() < 128:
        return matte_mask(rgba[..., 3])
    return figure_mask(rgba[..., :3])


def run_through(row: np.ndarray, x: int) -> int:
    """The unbroken stretch of figure holding x, or the longest in the row if x falls in a gap."""
    edges = np.diff(np.concatenate(([0], row.astype(np.int8), [0])))
    starts, ends = np.where(edges == 1)[0], np.where(edges == -1)[0]
    if not starts.size:
        return 0
    for start, end in zip(starts, ends):
        if start <= x < end:
            return int(end - start)
    return int((ends - starts).max())


def build_ratio(mask: np.ndarray) -> float:
    """Central width over height."""
    ys = np.where(mask.any(axis=1))[0]
    if not ys.size:
        raise ValueError("empty figure")
    top, bottom = int(ys.min()), int(ys.max()) + 1
    height = bottom - top
    rows = mask[top + int(height * BAND[0]) : top + int(height * BAND[1])]
    middle = int(np.median(np.where(rows)[1]))
    return round(float(np.median([run_through(r, middle) for r in rows])) / height, 3)


def frame_paths(root: Path, pid: str) -> list[Path]:
    if (root / pid).is_dir():
        return sorted((root / pid).glob("*.png"))
    single = root / f"{pid}.png"
    return [single] if single.exists() else []


def check(c: dict, root: Path) -> dict:
    table = Q.pose_table(c)
    sheet_path = D.ROOT / Q.drawing_of(c)["sheet"]["views"]["front"]["image"]
    sheet = build_ratio(mask_of(sheet_path)) if sheet_path.exists() else None
    per_clip: dict[str, list[float]] = {}
    missing: dict[str, list[str]] = {}
    for pid, pose in table.items():
        paths = frame_paths(root, pid)
        if not paths:
            missing.setdefault(pose["clip"], []).append(pid)
            continue
        per_clip.setdefault(pose["clip"], []).extend(build_ratio(mask_of(p)) for p in paths)
    ratios = [r for clip in per_clip.values() for r in clip]
    median = round(float(np.median(ratios)), 3) if ratios else None
    advisories = []
    reference_spec = Q.drawing_of(c).get("buildReference")
    reference = None
    if reference_spec:
        reference = build_ratio(mask_of(D.ROOT / reference_spec["image"], reference_spec.get("rect")))

    def compare(name: str, value: float | None, against: str, base: float | None) -> float | None:
        if value is None or base is None:
            return None
        rel = round((value - base) / base, 3)
        if abs(rel) > ADVISORY:
            word = "narrower" if rel < 0 else "wider"
            advisories.append(f"build: {name} is {abs(rel):.0%} {word} than the {against} ({value} against {base}). Look at them side by side")
        return rel

    relative = compare("the frames' median", median, "sheet", sheet)
    to_reference = {"sheet": compare("the sheet", sheet, "build reference", reference),
                    "frames": compare("the frames' median", median, "build reference", reference)}
    if sheet is None:
        advisories.append(f"sheet: {sheet_path.relative_to(D.ROOT)} is missing, so build can't be compared")
    if missing:
        advisories.append(f"clips: {sum(map(len, missing.values()))} of {len(table)} poses have no frame, in {', '.join(sorted(missing))}")
    return {"character": c["id"], "frames": str(root), "build": {"sheet": sheet, "frames": median, "relative": relative,
                                                                "reference": reference, "relativeToReference": to_reference,
                                                                "byClip": {k: round(float(np.median(v)), 3) for k, v in per_clip.items()}},
            "missing": missing, "reservedClips": Q.reserved_clips(c), "advisories": advisories, "ok": not advisories}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("character")
    ap.add_argument("--run", required=True)
    ap.add_argument("--dir", default="final")
    ap.add_argument("--strict", action="store_true", help="exit 1 on any advisory")
    a = ap.parse_args()
    try:
        c = D.load_character(a.character)
    except D.DefinitionError as e:
        sys.exit(f"refused:{a.character}:{e}")
    root = Path(a.dir) if Path(a.dir).is_absolute() else D.ROOT / "art_runs" / a.run / a.dir
    report = check(c, root)
    print(json.dumps(report, indent=1, ensure_ascii=False))
    if a.strict and report["advisories"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
