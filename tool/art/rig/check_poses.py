"""Automated pose QA for the Blender stand-in renders (reads rig.json only).

    python3 tool/art/rig/check_poses.py art_runs/inputs/gatekeeper-v3

Fails (exit 1) on:
  crossing   two different limbs (arm/leg segments) cross in the 2D OpenPose
             skeleton (hidden keypoints are skipped)
  head       a wrist closer than 1.2 head-widths to the head centre, except
             the whitelisted brim-touch and palm-to-chest poses
  drift      a weighted ankle moves within a clip (see drift_problems)
  ground     a free ankle below the ground line, or a pinned ankle off it
  shoulders  2D shoulder width changes by more than 25% within a clip
  yaw        body yaw above 35 degrees outside turn clips
  margin     a frame closer to the canvas edge than the family's minClear
  shoes      the shoes region is (nearly) hidden
  static     two consecutive drawings no joint moves >= 16 px (about 10
             degrees on a limb or 5 on the torso at ~110 px sprite height)

Stdlib only, so any Python 3 can run it. Non-human rigs (no OpenPose) skip
the crossing and head checks.
"""

from __future__ import annotations

import argparse
import itertools
import json
import math
import sys
from pathlib import Path

HEAD_CLEAR = 1.2                      # head-widths, wrist to head centre
HEAD_WHITELIST = {"finish_turn.finish_a", "finish_turn.finish_b", "approval.nod"}
TURN_CLIPS = {"turn", "finish_turn", "reveal", "pair_dance", "back_dance", "sidestep", "glance", "model"}  # yaw cap does not apply
# Seen in profile, or a set of different views: legs may overlap and shoulder width and ankles may change.
PROFILE_CLIPS = {"sidestep", "model"}
REAR_CLIPS = {"back_groove", "back_accent"}  # the yaw cap is measured from facing directly away
BAND_CLIPS = {"relaxed", "tap", "swing"}  # motion set band-loop: arms reach across to an instrument, a horn is at the face
CROSSED_ARMS = {"crossed"}  # the arms cross on purpose
HEAD_ONLY = {"crossed"}  # a nod moves little but the head, so the static check does not apply
NO_WIDTH_CHECK = {"turn", "reveal"}            # deliberate 360-degree turn views (no width/drift check)
LOCOMOTION = {"enter_forward", "retreat_backward", "yield_side", "ingress", "egress"}
LOOPS = {"groove", "watch", "back_groove"}
MAX_YAW = 35.0
MAX_WIDTH_CHANGE = 0.25
DRIFT_PX = 3.0
GROUND_PX = 3.0
MIN_MOVE_PX = 16.0
MIN_SHOES_PX = 600
DEFAULT_MARGIN = 0.03

# OpenPose COCO-18 limb segments by limb (indices into the 18 keypoints).
LIMB_SEGMENTS = {
    "r_arm": [(2, 3), (3, 4)], "l_arm": [(5, 6), (6, 7)],
    "r_leg": [(8, 9), (9, 10)], "l_leg": [(11, 12), (12, 13)],
}


def _orient(a, b, c) -> float:
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def segments_cross(p1, p2, q1, q2) -> bool:
    """Proper 2D intersection (touching endpoints do not count)."""
    d1, d2 = _orient(q1, q2, p1), _orient(q1, q2, p2)
    d3, d4 = _orient(p1, p2, q1), _orient(p1, p2, q2)
    return d1 * d2 < 0 and d3 * d4 < 0


def dist(a, b) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def crossing_problems(r: dict) -> list[str]:
    op = r.get("openpose")
    if not op or r.get("clip") in BAND_CLIPS:
        return []
    out = []
    crossed = r.get("clip") in CROSSED_ARMS
    for (la, sa), (lb, sb) in itertools.combinations(LIMB_SEGMENTS.items(), 2):
        for (a1, a2), (b1, b2) in itertools.product(sa, sb):
            if not all(op[i][2] for i in (a1, a2, b1, b2)):
                continue
            if crossed and {la, lb} == {"l_arm", "r_arm"}:
                continue
            if segments_cross(op[a1], op[a2], op[b1], op[b2]):
                out.append(f"crossing: {la} segment {a1}-{a2} crosses {lb} segment {b1}-{b2}")
    return out


def head_problems(r: dict) -> list[str]:
    if not r.get("openpose") or r["id"] in HEAD_WHITELIST or r.get("clip") in BAND_CLIPS:
        return []
    head = r["joints"]["head"]
    limit = HEAD_CLEAR * r["headWidthPx"]
    out = []
    for side in ("l", "r"):
        d = dist(r["joints"][f"{side}_wri"], head)
        if d < limit:
            out.append(f"head: {side} wrist {d:.0f}px from head centre (< {limit:.0f})")
    return out


def foot_problems(r: dict, ankle_y: float) -> list[str]:
    out = []
    for side in ("l", "r"):
        y = r["joints"][f"{side}_ank"][1]
        if y > ankle_y + GROUND_PX:
            out.append(f"ground: {side} ankle {y - ankle_y:.1f}px below the ground line")
    pin = r.get("pin")
    if pin in ("l", "r") and abs(r["joints"][f"{pin}_ank"][1] - ankle_y) > GROUND_PX:
        out.append(f"ground: pinned {pin} ankle off the ground line")
    return out


def weighted(r: dict) -> set[str]:
    return {"left": {"l"}, "right": {"r"}}.get(r["support"], {"l", "r"})


def drift_problems(clip: str, recs: list[dict]) -> list[str]:
    """A weighted ankle must not move between consecutive drawings.

    Pinned feet are checked in every clip. In-place clips also check the
    second weighted foot of a 'both' drawing (no sliding into or out of a
    two-foot stance). Locomotion clips travel by root motion, so there only
    a foot pinned in both drawings must stay put."""
    out = []
    pairs = list(zip(recs, recs[1:]))
    if clip in LOOPS and len(recs) > 2:
        pairs.append((recs[-1], recs[0]))
    if clip in NO_WIDTH_CHECK:   # turn views spin about the midpoint
        return []
    for a, b in pairs:
        if clip in LOCOMOTION:
            feet = {a["pin"]} & {b["pin"]} - {"mid"}
        else:
            feet = weighted(a) & weighted(b)
        for f in sorted(feet):
            pa, pb = a["joints"][f"{f}_ank"], b["joints"][f"{f}_ank"]
            d = dist(pa, pb)
            if d > DRIFT_PX:
                out.append(f"drift: {f} ankle moves {d:.1f}px from {a['id']} to {b['id']}")
    return out


def width_problems(clip: str, recs: list[dict]) -> list[str]:
    if clip in NO_WIDTH_CHECK:
        return []
    w = {r["id"]: dist(r["joints"]["l_sho"], r["joints"]["r_sho"]) for r in recs}
    lo, hi = min(w.values()), max(w.values())
    if hi and (hi - lo) / hi > MAX_WIDTH_CHANGE:
        return [f"shoulders: width {lo:.0f}-{hi:.0f}px ({(hi - lo) / hi:.0%}) in {clip}"]
    return []


def static_problems(clip: str, recs: list[dict]) -> list[str]:
    out = []
    if clip in HEAD_ONLY:
        return out
    for a, b in zip(recs, recs[1:]):
        move = max(dist(a["joints"][k], b["joints"][k]) for k in a["joints"])
        if move < MIN_MOVE_PX:
            out.append(f"static: {a['id']} -> {b['id']} max joint move {move:.1f}px (< {MIN_MOVE_PX:.0f})")
    return out


def margin_problems(r: dict, canvas, frac: float) -> list[str]:
    if not r.get("bbox"):
        return ["margin: empty frame"]
    W, H = canvas
    mx, my = frac * W, frac * H
    x0, y0, x1, y1 = r["bbox"]
    bad = []
    if x0 < mx: bad.append(f"left {x0}")
    if y0 < my: bad.append(f"top {y0}")
    if x1 > W - 1 - mx: bad.append(f"right {W - 1 - x1}")
    if y1 > H - 1 - my: bad.append(f"bottom {H - 1 - y1}")
    return [f"margin: {', '.join(bad)} px clear (< {mx:.0f}/{my:.0f})"] if bad else []


def check(rig: dict, margin: float) -> dict[str, list[str]]:
    canvas = rig["canvas"]
    px_per_m = canvas[1] / rig["orthoScale"]
    by_clip: dict[str, list[dict]] = {}
    problems: dict[str, list[str]] = {}
    for r in rig["poses"]:
        by_clip.setdefault(r.get("clip") or r["id"].split(".")[0], []).append(r)
    ankle_h = None
    for r in rig["poses"]:
        pin = r.get("pin")
        if pin in ("l", "r"):
            ankle_h = r["joints"][f"{pin}_ank"][1]
            break
    for r in rig["poses"]:
        p = problems.setdefault(r["id"], [])
        p += r.get("problems", [])
        if r.get("clip") not in PROFILE_CLIPS:
            p += crossing_problems(r)
        p += head_problems(r)
        if ankle_h is not None:
            p += foot_problems(r, ankle_h)
        yaw = abs(r.get("params", {}).get("yaw", 0))
        if r.get("clip") in REAR_CLIPS:
            yaw = abs(yaw - 180)
        if yaw > MAX_YAW and r.get("clip") not in TURN_CLIPS:
            p.append(f"yaw: {yaw:.0f} degrees outside a turn clip")
        p += margin_problems(r, canvas, margin)
        shoes = r.get("regionPixels", {}).get("shoes")
        if shoes is not None and shoes < MIN_SHOES_PX:
            p.append(f"shoes: only {shoes}px of shoes visible")
    for clip, recs in by_clip.items():
        if clip in PROFILE_CLIPS:
            continue
        clip_p = drift_problems(clip, recs) + width_problems(clip, recs) + static_problems(clip, recs)
        for msg in clip_p:
            problems.setdefault(f"{clip}.*", []).append(msg)
    del px_per_m
    return {k: v for k, v in problems.items() if v}


def family_margin(character: str) -> float:
    fam = Path(__file__).resolve().parents[1] / "families" / f"{character}-v3.json"
    try:
        return float(json.loads(fam.read_text())["frame"]["margin"]["minClear"])
    except (OSError, KeyError, ValueError, TypeError):
        return DEFAULT_MARGIN


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("dir", help="render directory holding rig.json")
    ap.add_argument("--margin", type=float, help="min clear fraction (default: family spec or 0.03)")
    args = ap.parse_args()
    rig = json.loads((Path(args.dir) / "rig.json").read_text())
    margin = args.margin if args.margin is not None else family_margin(rig["character"])
    problems = check(rig, margin)
    n = len(rig["poses"])
    for pid, msgs in sorted(problems.items()):
        for m in msgs:
            print(f"FAIL {pid}: {m}")
    print(f"{rig['character']}: {n} poses checked, {sum(map(len, problems.values()))} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
