#!/usr/bin/env python3
"""Put each pick on its atlas's scale and ground line, on the 768x960 generation canvas, 3x native, ready for studio.finish_pixels.
No rig exists for these poses, so scale = standing height from the live atlas's median, or a per-pose height with a manual head top where a raised
arm would otherwise shrink the figure. Horizontal: shirt-coloured pixels' median at canvas centre. Run from the repo root."""
import json, pathlib, sys
import numpy as np
from PIL import Image
sys.path.insert(0, "tool/art/pipeline")
from register_frames import matte_mask, bbox, torso_x
RUN = "spin-20261106a"; RAW = pathlib.Path.home() / ".cache/tillandsias-project/kumbia-art" / RUN / "raw"
OUT = pathlib.Path("/work/tmp/imagegen/kumbia") / RUN / "selected"; OUT.mkdir(parents=True, exist_ok=True)
picks = json.load(open(f"art_runs/{RUN}/picks.json")); report = {}
for char in ("gatekeeper", "bartender"):
    c = picks[char]; shirt = np.array([int(c["shirt"][i:i + 2], 16) for i in (0, 2, 4)])
    for name, p in c["poses"].items():
        src = Image.open(RAW / p["raw"] / f"{p['seed']}.png").convert("RGBA"); a = np.array(src); rgb = a[..., :3]
        mask = matte_mask(a[..., 3]); x0, y0, x1, y1 = bbox(mask)
        top = p.get("headTop", y0); T = p.get("height", c["height"]) * 3
        s = T / (y1 - top); tx = torso_x(rgb, mask, shirt)
        rgba = src.copy(); rgba.putalpha(Image.fromarray((mask * 255).astype(np.uint8)))
        big = rgba.resize((round(768 * s), round(960 * s)), Image.LANCZOS)
        canvas = Image.new("RGBA", (768, 960), (0, 0, 0, 0))
        px, py = round(384 - tx * s), round(c["floor"] * 3 - y1 * s)
        canvas.paste(big, (px, py)); canvas.save(OUT / f"{char}.{name}.png")
        o = bbox(np.array(canvas)[..., 3] > 128)
        report[f"{char}.{name}"] = {"scale": round(s, 3), "maskTop": y0, "touches": o[0] <= 0 or o[1] <= 0 or o[2] >= 768 or o[3] >= 960, "bbox": o}
for k, v in report.items(): print(k, v)
