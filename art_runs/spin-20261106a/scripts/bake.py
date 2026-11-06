#!/usr/bin/env python3
"""Bake this run's per-pose workflows: Qwen edit with the prompt baked in (2001-stpr), same matte as the frame route.
Poses are in poses.json as {pose: {images: {input_name: file}, words, seed}}; prefix gk., bt. or mc. picks the character.
Appends to jobs.<name>.json so each round stays on record. Usage: bake.py <jobs-name> pose [pose ...]. Run from the repo root."""
import json, sys, pathlib
HERE = pathlib.Path("art_runs/spin-20261106a"); LANE = "/work/tmp/imagegen/kumbia/spin-20261106a/in/"
P = json.load(open(HERE / "poses.json"))
TEMPLATE = {
 "gk": "Draw the man from image 1 {d} {keep}Keep exactly the same man: short, stocky, heavyset build, broad body, big round belly straining his shirt and overhanging his waistband, thick arms and legs, thick neck, wide round head, panama hat with teal band, black hair, purple short-sleeved guayabera, cream pleated trousers, teal shoes and thick dark ink outline, same crisp pixel art style with cel shading. He has exactly two arms and two hands. Whole man visible with margin on all sides, hat, both shoes and both hands inside the frame. Plain light grey background, no text.",
 "bt": "Draw the woman from image 1 {d} {keep}Keep exactly the same woman: slim adult build, curly dark hair tied up in a rounded puff, gold hoop earrings, ivory shirt with rolled sleeves, deep teal waistcoat, plum apron tied at the waist, dark plum trousers, amber shoes and thick dark ink outline, same crisp pixel art style with cel shading. Both her hands are open and empty. She has exactly two arms and two hands. Whole woman visible with margin on all sides, hair puff, both shoes and both hands inside the frame. Plain light grey background, no text.",
 "mc": "Draw the small robot from image 1 {d} {keep}Keep exactly the same small robot seen from behind: big rounded ivory head seen from the back with one vertical seam and a round teal ear disc on each side, one small cyan antenna ball on a thin stem, round ivory body, teal ball joints, short ivory limbs with dark teal mitten hands, thick dark outline, same flat colours and same pixel art style. Exactly two arms and two legs. The whole robot visible with margin on all sides, antenna ball and both feet inside the frame. Plain light grey background, no text.",
}
base = json.load(open("tool/art/workflows/qwen-frame.api.json"))
jobs_path = HERE / f"jobs.{sys.argv[1]}.json"; jobs = json.load(open(jobs_path)) if jobs_path.exists() else []
for pose in sys.argv[2:]:
    j = P[pose]; wf = json.loads(json.dumps(base))
    for k in ("1", "2"): wf.pop(k)
    for enc in ("10", "11"):
        wf[enc]["inputs"] = {k: v for k, v in wf[enc]["inputs"].items() if not k.startswith("image")}
    for i, n in enumerate(j["images"]):
        nid = str(60 + i); wf[nid] = {"_meta": {"title": f"${n}"}, "class_type": "LoadImage", "inputs": {"image": f"${n}"}}
        for enc in ("10", "11"): wf[enc]["inputs"][f"image{i + 1}"] = [nid, 0]
    wf["10"]["inputs"]["prompt"] = TEMPLATE[pose[:2]].format(d=j["words"], keep=j.get("keep", ""))
    wf["14"]["inputs"]["filename_prefix"] = f"kk/spin-{pose}"
    p = HERE / "workflows" / f"{pose}.api.json"; json.dump(wf, open(p, "w"), indent=1)
    args = {"workflow": str(p), "tier": "I1", "count": j.get("count", 4), "inputs": {n: LANE + f for n, f in j["images"].items()}, "overrides": {"seed": j["seed"]}}
    jobs.append({"pose": pose, "args": args}); print(json.dumps(args))
json.dump(jobs, open(jobs_path, "w"), indent=1)
