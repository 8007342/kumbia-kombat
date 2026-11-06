#!/usr/bin/env python3
"""Put each pick from pair/picks.json on its atlas's scale and ground line, on the 768x960 generation canvas, 3x native, ready for studio.finish_pixels.
A pick names raw/<pose>/<seed>.png, polygons to erase (the partner or robot the model drew in, which the game draws for itself), the raw spot of her holding hand, and optionally `scale`: a bent or arm-raised figure can't be scaled by its own height, so those take the scale that matched her head to the standing drawing. Writes selected/ and holds.json. Run from the worktree root."""
import json, pathlib, sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, "tool/art/pipeline")
from register_frames import matte_mask, bbox, torso_x
HERE = pathlib.Path("art_runs/duet-20261106/pair"); RAW = pathlib.Path.home() / ".cache/tillandsias-project/kumbia-art/pair-20261106/raw"
OUT = pathlib.Path("/work/tmp/imagegen/kumbia/pair-20261106/selected"); OUT.mkdir(parents=True, exist_ok=True)
picks = json.load(open(HERE / "picks.json")); holds = {}
def largest(mask):
    seen = np.zeros(mask.shape, bool); best = []
    for start in zip(*np.nonzero(mask)):
        if seen[start]: continue
        stack, blob = [start], []; seen[start] = True
        while stack:
            y, x = stack.pop(); blob.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1] and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True; stack.append((ny, nx))
        if len(blob) > len(best): best = blob
    keep = np.zeros(mask.shape, bool); ys, xs = zip(*best); keep[np.array(ys), np.array(xs)] = True
    return keep
for char, c in picks.items():
    shirt = np.array([int(c["shirt"][i:i + 2], 16) for i in (0, 2, 4)])
    for name, p in c["poses"].items():
        src = Image.open(RAW / p["raw"] / f"{p['seed']}.png").convert("RGBA"); a = np.array(src); rgb = a[..., :3]
        mask = matte_mask(a[..., 3])
        for poly in p.get("erase", []):
            m = Image.new("L", src.size, 0); ImageDraw.Draw(m).polygon([tuple(q) for q in poly], fill=255); mask &= np.array(m) == 0
        mask = largest(mask); x0, y0, x1, y1 = bbox(mask)
        s = p.get("scale") or c["height"] * 3 / (y1 - y0); tx = torso_x(rgb, mask, shirt)
        rgba = src.copy(); rgba.putalpha(Image.fromarray((mask * 255).astype(np.uint8)))
        big = rgba.resize((round(768 * s), round(960 * s)), Image.LANCZOS)
        canvas = Image.new("RGBA", (768, 960), (0, 0, 0, 0)); ox, oy = round(384 - tx * s), round(c["floor"] * 3 - y1 * s)
        canvas.paste(big, (ox, oy)); canvas.save(OUT / f"{char}.{name}.png")
        hx, hy = p["hold"]; holds[f"{char}.{name}"] = [(ox + hx * s) / 3, (oy + hy * s) / 3]
        b = bbox(np.array(canvas)[..., 3] > 128); print(char, name, "scale", round(s, 3), "touches", b[0] <= 0 or b[1] <= 0 or b[2] >= 768 or b[3] >= 960, b, "hold native", [round(v, 1) for v in holds[f"{char}.{name}"]])
json.dump(holds, open(HERE / "holds.json", "w"), indent=1)
