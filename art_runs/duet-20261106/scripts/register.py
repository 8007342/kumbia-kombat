#!/usr/bin/env python3
"""Put each skirt pick on its atlas's scale and ground line, on the 768x960 generation canvas, 3x native, ready for studio.finish_pixels.
No rig exists for these poses, so scale = standing height from picks.json and the horizontal centre is the bodice's median, as in the spin run. Run from the worktree root."""
import json, pathlib, sys
import numpy as np
from PIL import Image
sys.path.insert(0, "tool/art/pipeline")
from register_frames import matte_mask, bbox, torso_x
RAW = pathlib.Path.home() / ".cache/tillandsias-project/kumbia-art/duet-20261106/raw"
OUT = pathlib.Path("/work/tmp/imagegen/kumbia/duet-20261106/selected"); OUT.mkdir(parents=True, exist_ok=True)
picks = json.load(open("art_runs/duet-20261106/picks.json"))["skirt"]
for char, c in picks.items():
    shirt = np.array([int(c["shirt"][i:i + 2], 16) for i in (0, 2, 4)])
    for name, p in c["poses"].items():
        src = Image.open(RAW / p["raw"] / f"{p['seed']}.png").convert("RGBA"); a = np.array(src); rgb = a[..., :3]
        mask = matte_mask(a[..., 3]); x0, y0, x1, y1 = bbox(mask)
        s = c["height"] * 3 / (y1 - y0); tx = torso_x(rgb, mask, shirt)
        rgba = src.copy(); rgba.putalpha(Image.fromarray((mask * 255).astype(np.uint8)))
        big = rgba.resize((round(768 * s), round(960 * s)), Image.LANCZOS)
        canvas = Image.new("RGBA", (768, 960), (0, 0, 0, 0))
        canvas.paste(big, (round(384 - tx * s), round(c["floor"] * 3 - y1 * s))); canvas.save(OUT / f"{char}.{name}.png")
        b = bbox(np.array(canvas)[..., 3] > 128); print(char, name, "scale", round(s, 3), "touches", b[0] <= 0 or b[1] <= 0 or b[2] >= 768 or b[3] >= 960, b)
