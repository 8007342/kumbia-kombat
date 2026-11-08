#!/usr/bin/env python3
"""Don Charolas' half of the banquet close-up, drawn by Qwen from a bust crop of his accepted front sheet.
Each drawing is one edit of the same crop (image 1 and image 2 both), with its words as the prompt node's override,
through the lane's studio like run_jobs.py. Words are below, so provenance's empty `prompt` is answered here.
Usage: bust_jobs.py stage | run [name,...]"""
import json, sys, time, pathlib
from PIL import Image
ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tool/art/pipeline"))
import run_jobs as R

STAGE = pathlib.Path("/work/tmp/imagegen/kumbia/charolas-bust-20261108/in")
CROP = STAGE / "bust.png"
SEED = 996000
BASE = ("Image 1 is a close-up of this man. Draw the same man again in the same close-up framing: a bust from the top of his "
        "head down to his belly, the bottom edge of the picture cutting across his belly, his whole head inside the frame "
        "with margin above. Keep exactly the same man: a short, round head waiter of about fifty with a big round head, round "
        "rosy cheeks, shiny black hair slicked flat with a parting down the middle, a tiny neat black moustache, warm tan skin, "
        "a short white waiter's jacket with brass buttons, a white shirt collar and a black bow tie, same crisp pixel art style, "
        "cel shading and thick dark ink outline. He is turned a little toward the right of the picture, where someone stands "
        "outside the picture. He has exactly two arms and two hands, each hand complete with fingers. ")
CAN = "a tiny cylindrical motor-oil can with a short spout, a dark green can with a gold label band, with one small lit birthday candle standing on top of it"
WORDS = {
    "present": "He holds a round silver tray out toward the right of the picture at chest height on the hand on the right side of the picture, and on the tray sits a tall domed silver cloche, closed. His other hand rests on the cloche's knob. A proud grin, eyes toward the right of the picture.",
    "lift": "He holds a round silver tray out toward the right of the picture at chest height on the hand on the right side of the picture. With his other hand he lifts the domed silver cloche up off the tray by its knob, and on the tray, just revealed, stands " + CAN + ". Eyebrows raised, a delighted grin.",
    "offer": "He holds the round silver tray out toward the right edge of the picture at chest height on the hand on the right side of the picture, and on it stands " + CAN + ". His other hand holds the domed silver cloche raised high beside his head like a trophy. A big beaming grin, eyes toward the right of the picture.",
    "empty": "He holds the round silver tray out toward the right of the picture at chest height on the hand on the right side of the picture, and the tray is empty. His other hand holds the domed silver cloche raised high beside his head. His eyes are squeezed into happy arcs with a warm, won-over smile.",
}
SEEDS = {"present": 996000, "lift": 996010, "offer": 996020, "empty": 996030}
TAIL = " Plain light grey background, no text."


def stage():
    """The accepted front sheet's top, on the light grey the edit model expects, 768 wide."""
    im = Image.open(ROOT / "tool/art/references/charolas/front.png").convert("RGBA")
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
