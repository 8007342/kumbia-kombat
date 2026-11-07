#!/usr/bin/env python3
"""After the neckline pass: match the blouse's colour across guest0's frames, and pack them back into a 1536 wide atlas.

Qwen wandered a little in the blouse's pink between frames, which would flicker in a clip. Each frame's blouse pixels get
per-channel gains toward standing_idle_b's mean. Only the pixels in the shader's pink range change, so skin and hair don't.
seated_idle_a keeps its old place, since test/outfit_palette_test.dart samples that part of the atlas.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
ENS = ROOT / "assets/art/ensemble"
doc = json.loads((ENS / "manifest.json").read_text())
atlas = doc["atlases"]["guest0"]
src = np.asarray(Image.open(ENS / atlas["image"]).convert("RGBA")).astype(float)
frames = atlas["frames"]


def blouse(c):
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    return (c[..., 3] > 0) & (r > 150) & (b > g * .86) & (r - g > 60) & (g > 20)


crops = {k: src[f["rect"][1]:f["rect"][1] + f["rect"][3], f["rect"][0]:f["rect"][0] + f["rect"][2]].copy() for k, f in frames.items()}
ref = crops["standing_idle_b"]
want = ref[blouse(ref)][:, :3].mean(0)
for k, c in crops.items():
    m = blouse(c)
    gain = want / c[m][:, :3].mean(0)
    print(k, m.sum(), np.round(gain, 2))
    c[..., :3][m] = np.clip(c[..., :3][m] * gain, 0, 255)
out = Image.new("RGBA", (atlas["imageWidth"], 1400), (0, 0, 0, 0))
first = frames["seated_idle_a"]
x0 = 67 + first["rect"][2] + 4
out.paste(Image.fromarray(crops["seated_idle_a"].astype(np.uint8), "RGBA"), (67, 24))
first["rect"] = [67, 24, first["rect"][2], first["rect"][3]]
x, y, shelf = x0, 2, first["rect"][3] + 24
for k, f in frames.items():
    if k == "seated_idle_a":
        continue
    h, w = crops[k].shape[:2]
    if x + w + 2 > atlas["imageWidth"]:
        x, y, shelf = 2, y + shelf + 2, 0
    out.paste(Image.fromarray(crops[k].astype(np.uint8), "RGBA"), (x, y))
    f["rect"] = [x, y, w, h]
    x, shelf = x + w + 2, max(shelf, h)
height = y + shelf + 2
out.crop((0, 0, atlas["imageWidth"], height)).save(ENS / atlas["image"], optimize=True)
atlas["imageHeight"] = height
(ENS / "manifest.json").write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n")
print("atlas", atlas["imageWidth"], height)
