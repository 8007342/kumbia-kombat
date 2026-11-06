#!/usr/bin/env python3
"""Bake this run's per-pose workflows: Qwen edit, prompt baked in, same matte as the frame route. Words-only poses, as the spin run: no skeleton.
Prefix picks the template: a./b. a whole dancer on the 768x960 frame canvas, ka./kb. a close-up on 1024 square. Usage: bake.py <jobs-name> pose [pose ...], from the worktree root."""
import json, sys, pathlib
HERE = pathlib.Path("art_runs/duet-20261106"); LANE = "/work/tmp/imagegen/kumbia/duet-20261106/in/"
ROOT = pathlib.Path.cwd().relative_to(pathlib.Path("/home/forge/src/kumbia-kombat")); P = json.load(open(HERE / "poses.json"))
A = "tall, long-limbed adult build, narrow face, deep brown skin, short cropped silver-grey natural hair, gold hoop earrings, long-sleeved emerald green wrap dress with a gold belt"
B = "short, round adult build, round face, fair olive skin, round glasses, long straight black ponytail tied with a red ribbon, coral blouse with elbow-length sleeves and a high gathered collar"
FULL = "Draw the woman from image 1 {d} {keep}Keep exactly the same woman: {look}, {rest}, and thick dark ink outline, same crisp pixel art style with cel shading. She is a grown woman {age}, fully dressed. She has exactly two arms. Her whole figure is visible with margin on all sides, hair and both shoes inside the frame. Plain light grey background, no text."
CLOSE = "Draw the woman from image 1 {d} {keep}Keep exactly the same woman: {look}, thick dark ink outline, same crisp pixel art style with cel shading. She is a grown woman {age}, fully dressed, warm and kindly. Plain light grey background, no text."
TEMPLATE = {
 "a": (FULL, dict(look=A, rest="full emerald skirt falling below the knee, low gold dance shoes", age="of about fifty")),
 "b": (FULL, dict(look=B, rest="full cream skirt with a wide coral hem falling below the knee, low red dance shoes", age="in her forties")),
 "ka": (CLOSE, dict(look=A, age="of about fifty")),
 "kb": (CLOSE, dict(look=B, age="in her forties")),
}
base = json.load(open("tool/art/workflows/qwen-frame.api.json"))
jobs_path = HERE / f"jobs.{sys.argv[1]}.json"; jobs = json.load(open(jobs_path)) if jobs_path.exists() else []
for pose in sys.argv[2:]:
    j = P[pose]; wf = json.loads(json.dumps(base)); prefix = pose.split(".")[0]; tpl, fields = TEMPLATE[prefix]
    for k in ("1", "2"): wf.pop(k)
    for enc in ("10", "11"):
        wf[enc]["inputs"] = {k: v for k, v in wf[enc]["inputs"].items() if not k.startswith("image")}
    for i, n in enumerate(j["images"]):
        nid = str(60 + i); wf[nid] = {"_meta": {"title": f"${n}"}, "class_type": "LoadImage", "inputs": {"image": f"${n}"}}
        for enc in ("10", "11"): wf[enc]["inputs"][f"image{i + 1}"] = [nid, 0]
    wf["10"]["inputs"]["prompt"] = tpl.format(d=j["words"], keep=j.get("keep", ""), **fields)
    wf["14"]["inputs"]["filename_prefix"] = f"kk/duet-{pose}"
    if prefix.startswith("k"): wf["8"]["inputs"].update(width=1024, height=1024)
    p = HERE / "workflows" / f"{pose}.api.json"; json.dump(wf, open(p, "w"), indent=1)
    args = {"workflow": str(ROOT / p), "tier": "I1", "count": j.get("count", 4), "inputs": {n: LANE + f for n, f in j["images"].items()},
            "overrides": {"seed": j["seed"], "$node:30.lora_name": "Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"}}
    jobs.append({"pose": pose, "args": args}); print(json.dumps(args))
json.dump(jobs, open(jobs_path, "w"), indent=1)
