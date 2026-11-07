#!/usr/bin/env python3
"""Don Terciopelo's half of the rose handoff, drawn by Qwen from a bust crop of his accepted front sheet.
Each drawing is one edit of the same crop (image 1 and image 2 both), with its words as the prompt node's override,
through the lane's studio like run_jobs.py. Words are below, so provenance's empty `prompt` is answered here.
Usage: bust_jobs.py stage | run [name,...]"""
import json, sys, time, pathlib
from PIL import Image
ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tool/art/pipeline"))
import run_jobs as R

STAGE = pathlib.Path("/work/tmp/imagegen/kumbia/terciopelo-bust-20261107/in")
CROP = STAGE / "bust.png"
SEED = 991500
BASE = ("Image 1 is a close-up of this man. Draw the same man again in the same close-up framing: a bust from the top of his "
        "head down to his belly, the bottom edge of the picture cutting across his belly, his whole head inside the frame "
        "with margin above. Keep exactly the same man: a tall slim elderly gentleman of about seventy, long narrow face, "
        "swept-back silver hair, a thin grey pencil moustache, light olive-tan skin, crisp white dinner jacket with shawl "
        "lapels, white dress shirt, burgundy velvet bow tie, same crisp pixel art style, cel shading and thick dark ink "
        "outline. He is turned a little toward the right of the picture, where someone stands outside the picture. "
        "He has exactly two arms and two hands, each hand complete with fingers. ")
WORDS = {
    "rest": "Both arms hang relaxed at his sides, the hands below the frame. The single red rose is in the lapel on the right side of the picture. His mouth is closed in a poised, faintly amused smile, and his eyes look toward the right of the picture.",
    "pluck": "His hand on the left side of the picture is raised across his chest to the lapel on the right side of the picture, its fingers pinching the stem of the red rose and drawing it out of the lapel. His other arm hangs below the frame. His head tilts down toward the rose with a fond smile.",
    "offer": "His hand on the left side of the picture holds the single red rose by its stem, the arm extended across in front of his chest toward the right of the picture, offering it. The lapel is bare, with no rose. His other arm hangs below the frame. His head is inclined in a slight gallant bow, with a warm smile, eyes toward the right of the picture.",
    # offer2: the first offer held the rose low at the waist, nowhere near the other actor, so the words name the far hand and the edge.
    "offer2": "His hand on the right side of the picture holds the single red rose by its stem, the arm reaching out to the right of the picture at chest height so the rose is held out near the right edge of the picture, offering it to someone there. The lapel is bare, with no rose. His other arm hangs below the frame. His head is inclined toward the rose in a slight gallant bow, with a warm closed-mouth smile.",
    "empty": "The lapel is bare, with no rose. His hand on the left side of the picture is open in front of his chest with the palm up, just after giving something away, and his other arm hangs below the frame. A warm, won-over smile, eyes toward the right of the picture.",
}
# offer2 was first run with 991530, the same seed as empty, by a bug in an earlier version of this script.
SEEDS = {"rest": 991500, "pluck": 991510, "offer": 991520, "empty": 991530, "offer2": 991540}
TAIL = " Plain light grey background, no text."


def stage():
    """The accepted front sheet's top, on the light grey the edit model expects, 768 wide."""
    im = Image.open(ROOT / "tool/art/references/terciopelo/front.png").convert("RGBA")
    a = im.getbbox()
    # The sheet's hair touches its top edge, so the crop gets a margin of grey above it.
    cx = (a[0] + a[2]) // 2; w, h, pad = 420, 462, 44
    crop = im.crop((cx - w // 2, a[1], cx + w // 2, a[1] + h - pad))
    bg = Image.new("RGBA", (w, h), (226, 226, 226, 255)); bg.alpha_composite(crop, (0, pad))
    STAGE.mkdir(parents=True, exist_ok=True)
    bg.convert("RGB").resize((768, 768 * h // w), Image.NEAREST).save(CROP)
    box = (cx - w // 2, a[1], w, h)
    print("staged", CROP, box)


def run(names):
    lane = R.Lane()
    for i, name in enumerate(names):
        args = {"workflow": R.GRAPH, "tier": "I1", "count": 2,
                "inputs": {"sheet_front": str(CROP), "pose_proxy": str(CROP)},
                "overrides": {"seed": SEEDS[name], "$node:30.lora_name": R.LORA, "$node:10.prompt": BASE + WORDS[name] + TAIL}}
        t = time.time(); res = lane.call("studio.run_workflow", args)
        print(name, "error" if res.get("isError") else "ok", f"{time.time() - t:.0f}s", json.dumps(res)[:300], flush=True)


if __name__ == "__main__":
    if sys.argv[1] == "stage":
        stage()
    else:
        run(sys.argv[2].split(",") if len(sys.argv) > 2 else list(WORDS))
