#!/usr/bin/env python3
"""Plan sheet-driven frames: Qwen draws the character from the model sheet in a rig pose.

The rig supplies only an OpenPose skeleton, never its mannequin: a colour proxy or a clay
figure gets copied, shapes included (art_runs/qwen-trials-20261105/). The skeleton is scaled
down so the larger figure Qwen draws still fits the frame. register_frames.py puts each frame
back on the rig's size and position afterwards.

Usage: plan_qwen_frames.py <character> --run <run> [--only clip,pose.id] [--seed N] [--scale 0.8]
Writes art_runs/<run>/jobs.json, staging inputs under /work/tmp/imagegen/kumbia/<run>/in/.

Each pose gets its own workflow, art_runs/<run>/workflows/<pose>.api.json, with its prompt baked in:
studio.run_workflow's prompt override doesn't reach TextEncodeQwenImageEditPlus, though provenance
records it as if it did (seen in ComfyUI's /history on 2026-11-05). Passing none keeps provenance true.

art_runs/inputs/<family>/skeleton_overrides.json moves joints for this drawing only, as
{pose: {keypoint index: [x, y]}} in canvas pixels. Qwen follows the skeleton over the prompt, and
the rig's wrists stop short where its big hands would meet, so a clap reads as arms hanging down.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "rig"))
from openpose_draw import draw_openpose  # noqa: E402

WORKFLOW = "tool/art/workflows/qwen-frame.api.json"
STAGE = Path("/work/tmp/imagegen/kumbia")
PROMPT_NODE = "10"

PROMPT = (
    "Image 2 is a coloured stick-figure pose skeleton. Draw the {noun} from image 1 standing in that "
    "exact pose, at the same size and position in the frame as the skeleton, with empty background "
    "around {obj}: {poss} whole figure fits inside the frame, {fits} fully visible with margin on "
    "every side. {description}. {props}Sides are {poss} own: {sub} faces the viewer, so {poss} left "
    "is on the right of the picture. {Sub} keeps {poss} {look}, exactly as in image 1. Same pixel "
    "art style with crisp pixel clusters and cel shading. {Sub} has exactly two arms and two hands, "
    "each hand complete with fingers. {extra}Do not draw the skeleton. Plain light grey background, "
    "full body."
)
CAST = {
    "gatekeeper": {
        "noun": "man",
        "fits": "hat, both shoes and both hands",
        "look": (
            "short, stocky, broad body, big belly, face, thin pencil mustache, black hair, panama hat "
            "with teal band, purple short-sleeved guayabera with collar, pockets and teal embroidered "
            "panels, cream pleated trousers, teal shoes and thick dark ink outline"
        ),
        "extra": "Clean-shaven apart from the mustache, no beard, no goatee. ",
    },
    "bartender": {
        "noun": "woman",
        "fits": "hair puff, both shoes and both hands",
        "look": (
            "slim adult build, face, warm smile, curly dark hair tied up in a rounded puff, gold hoop "
            "earrings, ivory shirt with rolled sleeves, deep teal waistcoat with gold buttons, plum "
            "apron tied at the waist, dark plum trousers, amber shoes and thick dark ink outline"
        ),
        "extra": (
            "Her shirt stays buttoned up to the closed collar and her waistcoat stays buttoned high, "
            "fully covering her chest. "
        ),
    },
}


def props_text(character: dict, clip: str, sub: str, poss: str) -> str:
    """A sentence for each prop this clip carries."""
    return "".join(
        f"{sub.capitalize()} holds a {prop['text']} in {poss} {prop['hand']} hand. "
        for prop in character.get("props", [])
        if clip in prop.get("clips", [])
    )


def scaled(src: Path, dst: Path, scale: float) -> None:
    """Scale about the frame's bottom centre, leaving 5% below the feet."""
    im = Image.open(src).convert("RGB")
    w, h = im.size
    small = im.resize((int(w * scale), int(h * scale)), Image.BILINEAR)
    out = Image.new("RGB", (w, h), (0, 0, 0))
    out.paste(small, ((w - small.width) // 2, h - small.height - int(h * 0.05)))
    out.save(dst)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("character")
    ap.add_argument("--run", required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--seed", type=int, default=930000)
    ap.add_argument("--scale", type=float, default=0.8)
    ap.add_argument("--family", default="")
    ap.add_argument("--count", type=int, default=4, help="candidates per pose: seed, seed+1, ...")
    a = ap.parse_args()

    family = a.family or {"gatekeeper": "gatekeeper-v3", "bartender": "bartender-v1"}[a.character]
    rig = Path("art_runs/inputs") / family
    poses = json.loads((rig / "poses.intent.json").read_text())["poses"]
    want = [x for x in a.only.split(",") if x]
    ids = [p for p in poses if not want or p in want or p.split(".")[0] in want]

    overrides_file = rig / "skeleton_overrides.json"
    overrides = json.loads(overrides_file.read_text()) if overrides_file.exists() else {}
    rig_poses = {r["id"]: r for r in json.loads((rig / "rig.json").read_text())["poses"]}

    character = json.loads(Path(f"tool/art/characters/{a.character}.json").read_text())
    sub, obj, poss = character["pronouns"]
    cast = CAST[a.character]
    base = json.loads(Path(WORKFLOW).read_text())
    out = Path("art_runs") / a.run
    workflows = out / "workflows"
    workflows.mkdir(parents=True, exist_ok=True)

    lane = STAGE / a.run / "in"
    lane.mkdir(parents=True, exist_ok=True)
    sheet = lane / "sheet_front.png"
    shutil.copy(f"tool/art/references/{a.character}/front.png", sheet)

    jobs = []
    for pid in ids:
        skel = lane / f"{pid}.skeleton.png"
        source = rig / f"{pid}.pose.png"
        if pid in overrides:
            pts = [list(pt) for pt in rig_poses[pid]["openpose"]]
            for joint, xy in overrides[pid].items():
                pts[int(joint)][:2] = xy
                pts[int(joint)][2] = 1
            source = lane / f"{pid}.adjusted.png"
            with Image.open(rig / f"{pid}.pose.png") as im:
                draw_openpose(source, pts, [bool(pt[2]) for pt in pts], im.size)
        scaled(source, skel, a.scale)
        workflow = json.loads(json.dumps(base))
        workflow[PROMPT_NODE]["inputs"]["prompt"] = PROMPT.format(
            noun=cast["noun"], fits=cast["fits"], look=cast["look"], extra=cast["extra"],
            sub=sub, Sub=sub.capitalize(), obj=obj, poss=poss,
            description=poses[pid]["description"],
            props=props_text(character, poses[pid]["clip"], sub, poss),
        )
        path = workflows / f"{pid}.api.json"
        path.write_text(json.dumps(workflow, indent=1) + "\n")
        jobs.append({
            "pose": pid,
            "args": {
                "workflow": str(path),
                "tier": "I1",
                "count": a.count,
                "inputs": {"sheet_front": str(sheet), "pose_proxy": str(skel)},
                "overrides": {"seed": a.seed},
            },
        })
    (out / "jobs.json").write_text(json.dumps(jobs, indent=1) + "\n")
    print(f"{len(jobs)} jobs in {out / 'jobs.json'}")


if __name__ == "__main__":
    main()
