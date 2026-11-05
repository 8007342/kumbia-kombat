#!/usr/bin/env python3
"""Research-only locked palette and family specs for studio.finish_pixels on close-up actors. Not game families."""
import json, pathlib
import numpy as np
from PIL import Image
R = pathlib.Path.home() / ".cache/tillandsias-project/kumbia-art/closeups-20261105/raw"
OUT = pathlib.Path("art_runs/closeups-20261105")
def rows(p, alpha=True):
    a = np.asarray(Image.open(p).convert("RGBA")); return a[a[..., 3] > 128][:, :3] if alpha else a[..., :3].reshape(-1, 3)
g = rows("tool/art/references/gatekeeper/front-stocky.png", False); g = g[~((g.min(1) > 190) & (np.ptp(g, axis=1) < 12))]
src = [g, rows(R / "mc-impact/990001.png"), rows(R / "gulp-tilt2/990903.png"), rows(R / "gulp-low3/991402.png"), rows(R / "gk-impact/990000.png")]
rng = np.random.default_rng(1); keep = [k[rng.choice(len(k), min(len(k), 60000), replace=False)] for k in src]
all_ = np.concatenate(keep); side = int(len(all_) ** .5)
q = Image.fromarray(all_[:side * side].reshape(side, side, 3).astype("uint8")).quantize(47, method=Image.MEDIANCUT); p = q.getpalette()[:141]
cols = sorted({tuple(p[i:i + 3]) for i in range(0, len(p), 3)}, key=lambda c: .299 * c[0] + .587 * c[1] + .114 * c[2])
hx = ["#1A1018"] + ["#%02X%02X%02X" % c for c in cols if "#%02X%02X%02X" % c != "#1A1018"]
(OUT / "palette-actors.json").write_text(json.dumps({"schema": "tillandsias.palette/v1", "name": "closeup-actors", "colours": hx, "transparent": None, "$provenance": {"tool": str(OUT / "scripts/mkpalette.py"), "note": "research only"}}, indent=1))
base = json.load(open("art_runs/gatekeeper-v4-20261105q/family.json"))
for name, w, h in [("gk", 410, 307), ("mc", 240, 240), ("hand", 320, 320), ("glass", 205, 256)]:
    f = json.loads(json.dumps(base)); f["family"] = "closeup-" + name; f["description"] = "Research only: close-up finish, not a game family."
    f["frame"]["native"] = {"width": w, "height": h, "pixelScale": 2}; f["frame"]["generationCanvas"] = {"width": w, "height": h}
    f["palette"] = {"locked": "art_runs/closeups-20261105/palette-actors.json"}
    (OUT / f"family-{name}.json").write_text(json.dumps(f, indent=1))
print(len(hx), hx[:14])
