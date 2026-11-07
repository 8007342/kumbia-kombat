#!/usr/bin/env python3
"""Plan The Pool Player's close-up drawings: a key from her sheet, then one change at a time from the key.

Qwen holds one change from one reference, and not a chain of moments (plan/cinematics.md), so every later drawing is
drawn from the key or the wink, not from the one before it. image 2 is the same picture as image 1.

Usage: plan_pool_closeup.py <step>   chalk | changes | reach  (each needs the picks of the step before, in picks.json)
"""
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

RUN = "pool-closeup-20261107a"
OUT = Path("art_runs") / RUN
LANE = Path("/work/tmp/imagegen/kumbia") / RUN / "in"
CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art" / RUN
GRAPH = json.loads(Path("tool/art/workflows/qwen-frame.api.json").read_text())
LOOK = ("warm brown skin, fine smile lines, neat silver chin-length bob, small gold stud earrings, crisp ivory blouse with rolled sleeves, "
        "fitted billiard-green waistcoat with brass buttons, the same crisp pixel art with thick dark ink outline")
TAIL = " Plain light grey background, no text. She is a grown woman of about sixty, fully clothed. Exactly two arms and two hands, each hand complete with fingers."
STEPS = {
    "chalk": {"ck.chalk_a": ("sheet", 989700, "Draw the woman from image 1 in a large head-and-chest close-up, her body turned three-quarters toward the right of the picture, looking down at the tip of a billiard cue that she holds upright just in front of her, its pale shaft running off the bottom edge of the picture, its white tip at the height of her chin. Her other hand holds a small blue cube of chalk against the tip. A calm, knowing smile with her lips together, both eyes open. Her shoulder and arm run off the left and bottom edges of the picture. She keeps her " + LOOK + "." + TAIL)},
    "changes": {
        "ck.chalk_b": ("key", 989710, "Draw exactly the same picture of the same woman, the same size and position in the frame. The only change: her raised hand has lifted the small blue cube of chalk up onto the white tip of the cue, covering the tip, pressing it there. Everything else stays the same." + TAIL),
        "ck.wink": ("key", 989720, "Draw exactly the same picture of the same woman, the same size and position in the frame. The only change: her head lifts and she looks to the right of the picture, giving a sly wink, one eye closed in a happy curved line and the other eye open, a playful smile with her lips together. Her hands, the cue and the chalk stay where they are." + TAIL),
    },
    "reach": {
        "ck.reach": ("wink", 989730, "Draw the same woman at the same size and in the same place in the frame, with the same sly wink, now looking to the right of the picture. The only change: her arm is raised so that her hand is at the height of her chin, in front of her, and the billiard cue runs from that hand nearly level, straight toward the right edge of the picture, above the height of her shoulder. The cue runs off the right edge of the picture. Her other hand has gone off the bottom of the picture." + TAIL),
    },
}


def main() -> None:
    step = sys.argv[1]
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "workflows").mkdir(exist_ok=True)
    LANE.mkdir(parents=True, exist_ok=True)
    picks = json.loads((OUT / "picks.json").read_text()) if (OUT / "picks.json").exists() else {}
    sources = {"sheet": Path("tool/art/references/pool-player/front.png")}
    if "ck.chalk_a" in picks:
        sources["key"] = CACHE / "raw/ck.chalk_a" / f"{picks['ck.chalk_a']}.png"
    if "ck.wink" in picks:
        sources["wink"] = CACHE / "raw/ck.wink" / f"{picks['ck.wink']}.png"
    jobs = []
    for pid, (src, seed, words) in STEPS[step].items():
        staged = LANE / f"{src}.png"
        im = Image.open(sources[src]).convert("RGBA")
        flat = Image.new("RGBA", im.size, (226, 226, 226, 255))
        flat.alpha_composite(im)
        flat.convert("RGB").save(staged)
        wf = json.loads(json.dumps(GRAPH))
        wf["10"]["inputs"]["prompt"] = words
        path = OUT / "workflows" / f"{pid}.api.json"
        path.write_text(json.dumps(wf, indent=1) + "\n")
        proxy = LANE / f"{pid}.skeleton.png"  # collect_qwen names a pose from this file
        shutil.copy(staged, proxy)
        jobs.append({"pose": pid, "args": {"workflow": str(path), "tier": "I1", "count": 3, "inputs": {"sheet_front": str(staged), "pose_proxy": str(proxy)}, "overrides": {"seed": seed}}})
    (OUT / f"jobs.{step}.json").write_text(json.dumps(jobs, indent=1) + "\n")
    print(len(jobs), "jobs")


if __name__ == "__main__":
    main()
