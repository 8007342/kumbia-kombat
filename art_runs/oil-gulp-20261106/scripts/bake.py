#!/usr/bin/env python3
"""Bake oil-gulp workflows: Qwen edit, prompt baked into node 10 (host bug 2001-stpr: overrides don't reach the encoder).
Same route as art_runs/closeups-20261105. Prompts in prompts.json as {name: {w, h, images, matte, prompt}}. usage: bake.py [name ...]"""
import json, sys, pathlib
HERE = pathlib.Path("art_runs/oil-gulp-20261106")
P = json.load(open(HERE / "prompts.json"))
for name, j in P.items():
    if sys.argv[1:] and name not in sys.argv[1:]: continue
    wf = json.load(open("tool/art/workflows/qwen-frame.api.json"))
    for k in ("1", "2"): wf.pop(k)
    for i, n in enumerate(j["images"]):
        nid = f"{60 + i}"; wf[nid] = {"_meta": {"title": f"${n}"}, "class_type": "LoadImage", "inputs": {"image": f"${n}"}}
        for enc in ("10", "11"): wf[enc]["inputs"][f"image{i + 1}"] = [nid, 0]
    for enc in ("10", "11"):
        wf[enc]["inputs"] = {k: v for k, v in wf[enc]["inputs"].items() if not k.startswith("image") or int(k[5:]) <= len(j["images"])}
    wf["10"]["inputs"]["prompt"] = j["prompt"]; wf["8"]["inputs"].update(width=j["w"], height=j["h"])
    if not j.get("matte"):
        for k in ("40", "41"): wf.pop(k)
        wf["14"]["inputs"]["images"] = ["13", 0]
    wf["14"]["inputs"]["filename_prefix"] = f"kk/oil-gulp-{name}"
    json.dump(wf, open(HERE / "workflows" / f"{name}.api.json", "w"), indent=1)
    print(name, j["w"], j["h"], j["images"])
