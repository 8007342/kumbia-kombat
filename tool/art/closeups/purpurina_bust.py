#!/usr/bin/env python3
"""Tía Purpurina's half of the terrace's kiss close-up, drawn by Qwen from a bust crop of her accepted front sheet,
the salon's route (art_runs/salon-closeups-20261107/scripts/bust_jobs.py). Each drawing is one edit of the same crop
(image 1 and image 2 both), its words as the prompt node's override, so provenance's empty `prompt` is answered here.
She is on the picture's left and leans in to the right, where Mācron's head is, as the lawn's kisser does.

Usage: purpurina_bust.py stage | run [name,...] | collect
Collect copies each output to ~/.cache/tillandsias-project/kumbia-art/purpurina-bust-20261108/<name>-<seed>.png."""
import json, shutil, sys, time, pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tool/art/pipeline"))
import run_jobs as R  # noqa: E402

RUN = "purpurina-bust-20261108"
STAGE = pathlib.Path(f"/work/tmp/imagegen/kumbia/{RUN}/in")
CROP = STAGE / "bust.png"
OUT = pathlib.Path.home() / ".cache/tillandsias-project/kumbia-art" / RUN
BASE = ("Image 1 is a close-up of this woman. Draw the same woman again in a close-up: a bust from the top of her big "
        "curly hair down to her waist, the bottom edge of the picture cutting across her waist, her whole head inside the "
        "frame with margin above. Keep exactly the same woman: a joyful, curvy older lady of about seventy with warm brown "
        "skin, a round cheerful face with laugh lines, a big voluminous mass of copper-red curls, big gold hoop earrings, "
        "bright red lipstick, a sequinned gold cocktail dress with short sleeves and a modest rounded neckline, a fluffy "
        "turquoise feather boa round her shoulders, same crisp pixel art style, cel shading and thick dark ink outline. "
        "She is seen in profile facing the right of the picture, where someone stands just outside the picture. ")
WORDS = {
    "rest": "She leans a little toward the right of the picture with a huge delighted open-mouthed smile, eyes twinkling and looking to the right of the picture, her hand on the right side of the picture raised to her chest.",
    "kiss": "She leans far forward toward the right edge of the picture, her lips pursed into a big puckered kiss reaching the right edge of the picture, her eyes closed, her cheeks round, her hand on the right side of the picture raised to her chest.",
}
SEEDS = {"rest": 996600, "kiss": 996610}
TAIL = " Plain light grey background, no text."


def stage():
    im = Image.open(ROOT / "tool/art/references/purpurina/front.png").convert("RGBA")
    a = im.getbbox()
    cx = (a[0] + a[2]) // 2; w, h, pad = 440, 470, 40
    crop = im.crop((cx - w // 2, a[1], cx + w // 2, a[1] + h - pad))
    bg = Image.new("RGBA", (w, h), (226, 226, 226, 255)); bg.alpha_composite(crop, (0, pad))
    STAGE.mkdir(parents=True, exist_ok=True)
    bg.convert("RGB").resize((768, 768 * h // w), Image.NEAREST).save(CROP)
    print("staged", CROP)


def run(names):
    lane = R.Lane()
    for name in names:
        args = {"workflow": R.GRAPH, "tier": "I1", "count": 2,
                "inputs": {"sheet_front": str(CROP), "pose_proxy": str(CROP)},
                "overrides": {"seed": SEEDS[name], "$node:30.lora_name": R.LORA, "$node:10.prompt": BASE + WORDS[name] + TAIL}}
        t = time.time(); res = lane.call("studio.run_workflow", args)
        print(name, "error" if res.get("isError") else "ok", f"{time.time() - t:.0f}s", flush=True)
    collect()


def collect():
    OUT.mkdir(parents=True, exist_ok=True)
    by_seed = {s + k: n for n, s in SEEDS.items() for k in range(4)}
    for prov in pathlib.Path("/work/tmp/imagegen/studio").glob("st-*/*.provenance.json"):
        try:
            pd = json.loads(prov.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        txt = json.dumps(pd)
        if "sheet_front" not in txt or RUN not in txt:
            continue
        seed = pd.get("seed")
        if seed in by_seed:
            png = prov.with_name(prov.name.removesuffix(".provenance.json"))
            shutil.copy(png, OUT / f"{by_seed[seed]}-{seed}.png"); shutil.copy(prov, OUT / f"{by_seed[seed]}-{seed}.provenance.json")
    print(sorted(p.name for p in OUT.glob("*.png")))


if __name__ == "__main__":
    {"stage": lambda: stage(), "collect": lambda: collect()}.get(sys.argv[1], lambda: run(sys.argv[2].split(",") if len(sys.argv) > 2 else list(WORDS)))()
