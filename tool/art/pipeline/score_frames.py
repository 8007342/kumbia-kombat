#!/usr/bin/env python3
"""Score registered sheet-driven frames against the rig's joints, and pick one per pose.

Qwen keeps the character but can wander from the pose, so each candidate is measured where the
rig says the body should be: a wrist needs skin nearby, an ankle a shoe, a knee whatever covers it,
and an elbow any part of the figure. Colours come from the character definition: a knee looks for
its `trousers` garment unless `drawing.score.knee` names others, such as a dress, so a dancer in a
skirt scores on the skirt. Joints alone can't see a hand in the wrong place, so silhouettes are
compared too: `extra` is figure outside the rig's silhouette (an arm behind the head), `missing` is
rig silhouette the figure doesn't reach (a lost hand), each as a percentage of the rig's area, with
a tolerance because Qwen's body is not the rig's (`drawing.score.silhouetteTolerance`; a swinging
skirt needs more). Score: mean joint distance plus the worst joint, plus extra and missing. Lower is
better.

A scorer that fails quietly picks at random (LESSONS_LEARNED A2), so this aborts without writing
anything if a pose has no candidates, a part's colour is found in no candidate, or every score ties.

Usage:
  score_frames.py --run <run> --family gatekeeper-v3 [--dir registered] [--flag 45] [--partial]
Reads <dir>/<pose>[/<k>].png, where <dir> is absolute or under art_runs/<run>. Writes
art_runs/<run>/scores.json and selection.json. --partial allows a run of only some poses. Scores
rank candidates: they can't see a missing hand or an extra arm, so look at every clip before
accepting a selection.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, str(Path(__file__).resolve().parent))
import colour as C  # noqa: E402
import compile_family as CF  # noqa: E402
import definitions as D  # noqa: E402

# OpenPose COCO-18 indices in rig.json
JOINTS = {"r_wri": 4, "l_wri": 7, "r_elb": 3, "l_elb": 6, "r_kne": 9, "l_kne": 12, "r_ank": 10, "l_ank": 13}
TOLERANCE = 18  # canvas pixels
LOST = 999.0  # the part's colour appears nowhere in this candidate


class ScoreFailure(SystemExit):
    """The scores can't be trusted, so nothing is written."""


def near(rgb: np.ndarray, colours: list[np.ndarray], tol: int) -> np.ndarray:
    out = np.zeros(rgb.shape[:2], bool)
    for colour in colours:
        out |= np.abs(rgb.astype(int) - colour).max(axis=-1) < tol
    return out


def part_colours(c: dict, style: dict) -> dict:
    """What each joint looks for, from the definition: {"kne": [rgb...], "ank": [rgb...], "tolerance": px}."""
    ramps = C.build_ramps(c, style)
    base = CF._base_index(style)
    score = c.get("drawing", {}).get("score", {})

    def colours(field: str, region: str) -> list[np.ndarray]:
        ids = score.get(field) or [g["id"] for g in c["garments"] if g["region"] == region and "colour" in g]
        if not ids:
            raise ScoreFailure(f"refused:{c['id']}:drawing.score.{field}: no {region} garment, so name what covers this joint")
        unknown = [i for i in ids if i not in ramps]
        if unknown:
            raise ScoreFailure(f"refused:{c['id']}:drawing.score.{field}: unknown part {unknown}")
        return [np.array(C.hex_to_rgb(ramps[i]["shades"][base])) for i in ids]

    return {"kne": colours("knee", "trousers"), "ank": colours("ankle", "shoes"),
            "tolerance": score.get("silhouetteTolerance", TOLERANCE)}


def distance_to(mask: np.ndarray):
    """Distance to the nearest True pixel; None if there isn't one, which the score then shows."""
    return ndi.distance_transform_edt(~mask) if mask.any() else None


def skin_mask(rgb: np.ndarray) -> np.ndarray:
    """Hue test: skin shades vary from lit to shadow far more than their hue does."""
    r, g, b = [rgb[..., i].astype(int) for i in range(3)]
    return (r > 90) & (r - g > 35) & (g - b > 15)


def measure(path: Path, pose: dict, rig_mask: np.ndarray, parts: dict) -> dict:
    a = np.array(Image.open(path).convert("RGBA"))
    rgb, fig = a[..., :3], a[..., 3] > 128
    h, w = fig.shape
    ys, xs = np.where(fig)
    if not xs.size:
        raise ScoreFailure(f"empty frame {path}")
    head = np.array(pose["openpose"][0][:2])
    yy, xx = np.ogrid[:h, :w]
    near_head = (xx - head[0]) ** 2 + (yy - head[1]) ** 2 < (pose["headWidthPx"] * 0.75) ** 2
    skin = skin_mask(rgb) & fig
    fields = {
        "wri": distance_to(skin & ~near_head),
        "kne": distance_to(near(rgb, parts["kne"], 60) & fig),
        "ank": distance_to(near(rgb, parts["ank"], 60) & fig),
        "elb": distance_to(fig),
    }
    errors = {}
    lost = []
    for name, i in JOINTS.items():
        x, y, visible = pose["openpose"][i]
        if not visible:
            continue
        field = fields[name[2:]]
        x, y = min(max(int(x), 0), w - 1), min(max(int(y), 0), h - 1)
        if field is None:
            lost.append(name)
        errors[name] = round(float(field[y, x]), 1) if field is not None else LOST
    if not errors:
        raise ScoreFailure(f"no visible joints to score at {path}")
    values = list(errors.values())
    area = rig_mask.sum()
    tol = parts["tolerance"]
    extra = 100 * (fig & ~(ndi.binary_dilation(rig_mask, iterations=tol) if tol else rig_mask)).sum() / area
    missing = 100 * (rig_mask & ~(ndi.binary_dilation(fig, iterations=tol) if tol else fig)).sum() / area
    return {
        "score": round(float(np.mean(values) + max(values) + extra + missing), 1),
        "extra": round(float(extra), 1),
        "missing": round(float(missing), 1),
        "worst": max(errors, key=errors.get),
        "errors": errors,
        "lost": lost,
        "touchesFrame": bool(xs.min() == 0 or ys.min() == 0 or xs.max() == w - 1 or ys.max() == h - 1),
    }


def check_scores(scores: dict, wanted: list[str], partial: bool = False) -> None:
    """Abort rather than let bad scores pick frames (LESSONS_LEARNED A2)."""
    if not scores:
        raise ScoreFailure("no candidates scored: wrong --dir, or nothing registered yet")
    absent = [p for p in wanted if p not in scores]
    if absent and not partial:
        raise ScoreFailure(f"{len(absent)} poses have no candidates: {', '.join(absent[:8])}. Use --partial if this run covers only some poses")
    cands = [v for pose in scores.values() for v in pose.values()]
    if any(not np.isfinite(v["score"]) for v in cands):
        raise ScoreFailure("a score is not a number")
    for name in sorted({k[2:] for v in cands for k in v["errors"]}):
        joints = [e for v in cands for k, e in v["errors"].items() if k[2:] == name]
        if name != "elb" and joints and all(e == LOST for e in joints):
            raise ScoreFailure(f"{name}: its colour appears in no candidate, so every {name} is scored blind. Check the definition's colours or drawing.score")
    # A tie needs several candidates to mean anything; one per pose legitimately has no rival.
    if len(cands) > len(scores) and len({v["score"] for v in cands}) == 1:
        raise ScoreFailure(f"every candidate scored {cands[0]['score']}: the scorer isn't telling them apart")


def score_run(poses: dict, root: Path, rig_dir: Path, parts: dict, flag: float = 45.0) -> tuple[dict, dict, list[str]]:
    scores, selection, flagged = {}, {}, []
    for pid, pose in poses.items():
        paths = sorted((root / pid).glob("*.png")) if (root / pid).is_dir() else [root / f"{pid}.png"]
        paths = [p for p in paths if p.exists()]
        if not paths:
            continue
        regions = np.array(Image.open(rig_dir / f"{pid}.regions.png").convert("RGBA"))
        rig_mask = regions[..., 3] > 0
        if rig_mask.all():
            rig_mask = regions[..., :3].max(axis=-1) > 8
        cands = {p.stem if p.parent.name == pid else "0": measure(p, pose, rig_mask, parts) for p in paths}
        scores[pid] = cands
        usable = {k: v for k, v in cands.items() if not v["touchesFrame"]} or cands
        best = min(usable, key=lambda k: usable[k]["score"])
        selection[pid] = {"k": best, "score": usable[best]["score"]}
        if usable[best]["score"] > flag:
            flagged.append(pid)
    return scores, selection, flagged


def character_of(family: str) -> dict:
    for path in sorted((D.ART / "characters").glob("*.json")):
        c = json.loads(path.read_text())
        if c.get("family") == family:
            return D.load_character(c["id"])
    raise ScoreFailure(f"no character in tool/art/characters has family {family!r}: pass --character")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    ap.add_argument("--family", required=True)
    ap.add_argument("--character", help="id or .json path, if the family doesn't name it")
    ap.add_argument("--dir", default="registered")
    ap.add_argument("--flag", type=float, default=45.0, help="best score above this needs a look")
    ap.add_argument("--partial", action="store_true", help="the run covers only some poses")
    a = ap.parse_args()
    run = Path("art_runs") / a.run
    rig_dir = Path("art_runs/inputs") / a.family
    c = D.load_character(a.character) if a.character else character_of(a.family)
    if "motion" in c.get("drawing", {}):
        raise ScoreFailure(f"{c['id']} is posed by words, with no rig to score against: pick from a contact sheet, and run character_check.py")
    parts = part_colours(c, D.load_style(c["style"]))
    poses = {p["id"]: p for p in json.loads((rig_dir / "rig.json").read_text())["poses"]}
    root = run / a.dir if not Path(a.dir).is_absolute() else Path(a.dir)
    scores, selection, flagged = score_run(poses, root, rig_dir, parts, a.flag)
    check_scores(scores, list(poses), a.partial)
    (run / "scores.json").write_text(json.dumps(scores, indent=1) + "\n")
    (run / "selection.json").write_text(json.dumps(selection, indent=1) + "\n")
    print(json.dumps({"poses": len(selection), "flagged": flagged}))


if __name__ == "__main__":
    main()
