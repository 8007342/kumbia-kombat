#!/usr/bin/env python3
"""Bake one probe workflow: Qwen edit, 2 or 3 images, no matte, prompt baked (2001-stpr)."""
import json, sys
name, w, h, steps, cfg = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), float(sys.argv[5])
images = sys.argv[6].split(",")      # input names, in image1.. order
prompt = open(sys.argv[7]).read().strip()
matte = len(sys.argv) > 8 and sys.argv[8] == "matte"
wf = json.load(open("../../tool/art/workflows/qwen-frame.api.json"))
for k in ("1", "2"):
    wf.pop(k)
for i, n in enumerate(images):
    nid = f"{60 + i}"
    wf[nid] = {"_meta": {"title": f"${n}"}, "class_type": "LoadImage", "inputs": {"image": f"${n}"}}
    for enc in ("10", "11"):
        wf[enc]["inputs"][f"image{i + 1}"] = [nid, 0]
for enc in ("10", "11"):
    wf[enc]["inputs"] = {k: v for k, v in wf[enc]["inputs"].items() if not k.startswith("image") or int(k[5:]) <= len(images)}
wf["10"]["inputs"]["prompt"] = prompt
wf["8"]["inputs"].update(width=w, height=h)
wf["12"]["inputs"].update(steps=steps, cfg=cfg)
if steps > 8:
    del wf["30"]; wf["5"]["inputs"]["model"] = ["4", 0]
if not matte:
    for k in ("40", "41"):
        wf.pop(k)
    wf["14"]["inputs"]["images"] = ["13", 0]
wf["14"]["inputs"]["filename_prefix"] = f"kk/l3probe-{name}"
json.dump(wf, open(f"workflows/{name}.api.json", "w"), indent=1)
