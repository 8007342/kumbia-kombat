#!/usr/bin/env python3
"""Bake this run's per-pose workflows from pair/poses.json: the duet run's Qwen edit graph, words only, one per dancer.
Usage: bake.py <jobs-name> pose [pose ...], from the worktree root. Prints each job's args."""
import json, sys, pathlib
HERE = pathlib.Path("art_runs/duet-20261106/pair"); LANE = "/work/tmp/imagegen/kumbia/duet-20261106/in/"
ROOT = pathlib.Path.cwd().relative_to(pathlib.Path("/home/forge/src/kumbia-kombat")); P = json.load(open(HERE / "poses.json"))
A = "tall, long-limbed adult build, narrow face, deep brown skin, short cropped silver-grey natural hair, gold hoop earrings, long-sleeved emerald green wrap dress with a gold belt"
B = "short, round adult build, round face, fair olive skin, round glasses, long straight black ponytail tied with a red ribbon, coral blouse with elbow-length sleeves and a high gathered collar"
FULL = "Draw the woman from image 1 {d} Keep exactly the same woman: {look}, {rest}, and thick dark ink outline, same crisp pixel art style with cel shading. She is a grown woman {age}, fully dressed. She has exactly two arms. Her whole figure is visible with margin on all sides, hair and both shoes inside the frame. Plain light grey background, no text."
WHO = {"a": dict(look=A, rest="full emerald skirt falling below the knee, low gold dance shoes", age="of about fifty"),
       "b": dict(look=B, rest="full cream skirt with a wide coral hem falling below the knee, low red dance shoes", age="in her forties")}
base = json.load(open("tool/art/workflows/qwen-frame.api.json"))
jobs_path = HERE / f"jobs.{sys.argv[1]}.json"; jobs = json.load(open(jobs_path)) if jobs_path.exists() else []
for pose in sys.argv[2:]:
    for who, fields in WHO.items():
        j = P[pose]; wf = json.loads(json.dumps(base))
        for k in ("1", "2"): wf.pop(k)
        for enc in ("10", "11"):
            wf[enc]["inputs"] = {k: v for k, v in wf[enc]["inputs"].items() if not k.startswith("image")}
            wf[enc]["inputs"]["image1"] = ["60", 0]
        wf["60"] = {"_meta": {"title": "$sheet_front"}, "class_type": "LoadImage", "inputs": {"image": "$sheet_front"}}
        name = f"{who}.{pose}"
        wf["10"]["inputs"]["prompt"] = FULL.format(d=j["words"], **fields); wf["14"]["inputs"]["filename_prefix"] = f"kk/pair-{name}"
        p = HERE / "workflows" / f"{name}.api.json"; p.parent.mkdir(exist_ok=True); json.dump(wf, open(p, "w"), indent=1)
        seed = j["seed"] + (500 if who == "b" else 0)
        args = {"workflow": str(ROOT / p), "tier": "I1", "count": j.get("count", 3), "inputs": {"sheet_front": LANE + f"{who}_front.png"},
                "overrides": {"seed": seed, "$node:30.lora_name": "Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"}}
        jobs.append({"pose": name, "args": args}); print(json.dumps(args))
json.dump(jobs, open(jobs_path, "w"), indent=1)
