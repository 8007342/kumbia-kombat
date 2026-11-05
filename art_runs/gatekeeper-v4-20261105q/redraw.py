#!/usr/bin/env python3
"""Second-try jobs for poses the review rejected: this wave's skeleton fixes and prompt rewrites.

Gatekeeper-v3's clap overrides move one arm only, because that wave mirrored the half afterwards.
With real prompts the other arm hangs down, so here both arms mirror about the neck. Those overrides
stay as they are. Skeletons go under in/redo/<tag>/, keeping the <pose>.skeleton.png name that
collect_qwen.py reads the pose from. Writes redo-<tag>.jobs.json.
Usage: redraw.py <tag> <seed>   (run from the repo root; the tag's entries are in REDO)
"""
import json, sys
from pathlib import Path
from PIL import Image
sys.path.insert(0, "tool/art/pipeline"); sys.path.insert(0, "tool/art/rig")
from plan_qwen_frames import scaled, STAGE, PROMPT_NODE
from openpose_draw import draw_openpose

RUN = "gatekeeper-v4-20261105q"
WARM = ("Both eyes are open.", "Both eyes are open, eyebrows relaxed and high, with a warm friendly smile.")
def mirrored(r_elbow, r_wrist, gap=0):
    """Right arm as given, left arm its mirror about the neck at x=384. gap pulls touching wrists apart."""
    return {"3": r_elbow, "4": [r_wrist[0] - gap, r_wrist[1]], "6": [768 - r_elbow[0], r_elbow[1]], "7": [768 - r_wrist[0] + gap, r_wrist[1]]}
REDO = {
    "r2": {
        "clap.open": {"joints": mirrored([225, 470], [318, 405])},
        "clap.close": {"joints": mirrored([235, 475], [345, 425])},
        "clap.contact": {"joints": mirrored([240, 495], [384, 445], gap=8), "swap": [WARM]},
        "clap.release": {"joints": mirrored([225, 480], [330, 440])},
        "approval.nod": {"swap": [WARM]},
        "yield_side.pass_r": {"swap": [(
            "left fist on the hip, right arm held out low and wide with the palm open and up",
            "the fist on the right side of the picture rests on the hip, and the arm on the left side of "
            "the picture is held out low and wide with the palm open and up",
        )]},
    },
}

tag, seed = sys.argv[1], int(sys.argv[2])
out = Path("art_runs") / RUN
rig = Path("art_runs/inputs/gatekeeper-v3")
rig_poses = {r["id"]: r for r in json.loads((rig / "rig.json").read_text())["poses"]}
lane = STAGE / RUN / "in"
(lane / "redo" / tag).mkdir(parents=True, exist_ok=True)
jobs = []
for pose, fix in REDO[tag].items():
    wf = json.loads((out / "workflows" / f"{pose}.api.json").read_text())
    prompt = wf[PROMPT_NODE]["inputs"]["prompt"]
    for old, new in fix.get("swap", []):
        assert old in prompt, (pose, old)
        prompt = prompt.replace(old, new)
    wf[PROMPT_NODE]["inputs"]["prompt"] = prompt
    path = out / "workflows" / f"{pose}.{tag}.api.json"
    path.write_text(json.dumps(wf, indent=1) + "\n")
    skel = lane / "redo" / tag / f"{pose}.skeleton.png"
    if "joints" in fix:
        pts = [list(p) for p in rig_poses[pose]["openpose"]]
        for j, xy in fix["joints"].items():
            pts[int(j)][:2] = xy; pts[int(j)][2] = 1
        src = lane / "redo" / tag / f"{pose}.adjusted.png"
        with Image.open(rig / f"{pose}.pose.png") as im:
            draw_openpose(src, pts, [bool(p[2]) for p in pts], im.size)
        scaled(src, skel, 0.8)
    else:
        skel.write_bytes((lane / f"{pose}.skeleton.png").read_bytes())
    jobs.append({"pose": pose, "args": {"workflow": str(path), "tier": "I1", "count": 4,
        "inputs": {"sheet_front": str(lane / "sheet_front.png"), "pose_proxy": str(skel)}, "overrides": {"seed": seed}}})
(out / f"redo-{tag}.jobs.json").write_text(json.dumps(jobs, indent=1) + "\n")
print(len(jobs), "jobs")
