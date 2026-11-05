#!/usr/bin/env python3
"""Candidate-only atlas for the Macron pilot, in the run's folder. Not the art.py route: `drawn` characters have no
family spec or locked palette yet, so there is no studio.finish_pixels pass. Nearest-neighbour 3x down (register.pixelScale),
binary alpha, no palette lock. Same frame fields as assets/art/party/manifest.json. Also: walk GIF, head metrics.
Picks are my eye's, not the owner's."""
import json, pathlib, sys
import numpy as np
from PIL import Image
RUN = "macron-v1-20261105a"
R = pathlib.Path.home() / ".cache/tillandsias-project/kumbia-art" / RUN
OUT = pathlib.Path("art_runs") / RUN / "candidate"; OUT.mkdir(exist_ok=True)
PICKS = {"fist_bump.ready": 980002, "fist_bump.contact": 980000, "fist_bump.settle": 980002,
         "gulp.lift": 980000, "gulp.sip": 980003, "gulp.after": 980000,
         "rear34_walk.step_r": 980001, "rear34_walk.pass_r": 980001, "rear34_walk.step_l": 980001, "rear34_walk.pass_l": 980003,
         "high_five.ready": 980002, "high_five.contact": 980000, "high_five.after": 980001}
PPU = json.load(open(R / "registered/registration.json")).get("pixelsPerUnit", 6.4865)
cells, CW, CH = {}, 256, 320
for pose, seed in PICKS.items():
    im = Image.open(R / "registered" / pose / f"{seed}.png").convert("RGBA")
    im = im.resize((im.width // 3, im.height // 3), Image.NEAREST)
    a = np.array(im); a[..., 3] = (a[..., 3] > 128) * 255; cells[pose] = Image.fromarray(a)
print("registered frame", im.size)
cols = 5; rows = (len(cells) + cols - 1) // cols
W = max(c.width for c in cells.values()); H = max(c.height for c in cells.values())
atlas = Image.new("RGBA", (cols * W, rows * H), (0, 0, 0, 0)); frames = {}
for i, (pose, c) in enumerate(cells.items()):
    x, y = (i % cols) * W, (i // cols) * H; bb = c.getbbox()
    atlas.paste(c, (x, y))
    a = np.asarray(c)[..., 3] > 0; ys, xs = np.where(a); floor = ys.max()
    fx = int(np.median(np.where(a[max(0, floor - 4):floor + 1].any(0))[0]))
    frames[pose] = {"rect": [x + bb[0], y + bb[1], bb[2] - bb[0], bb[3] - bb[1]], "anchor": [int(fx - bb[0]), int(floor - bb[1])],
                    "pixelsPerUnit": PPU, "seed": PICKS[pose]}
atlas.save(OUT / "macron-clips-candidate.png", optimize=True)
json.dump({"status": "candidate for review, not accepted, not promoted; no palette lock; picks by agent's eye", "run": RUN, "frames": frames},
          open(OUT / "macron-clips-candidate.json", "w"), indent=1)
print("atlas", atlas.size)
# Walk GIF: 2 beats a cycle at 104 BPM
seq = ["rear34_walk.step_r", "rear34_walk.pass_r", "rear34_walk.step_l", "rear34_walk.pass_l"]
fr = []
for p in seq:
    bg = Image.new("RGBA", (W, H), (70, 75, 90, 255)); bg.alpha_composite(cells[p]); fr.append(bg.convert("P", palette=Image.ADAPTIVE, colors=64))
fr[0].save("art_runs/closeups-20261105/sheets/macron-walk-picks.gif", save_all=True, append_images=fr[1:], duration=int(60000 / 104 * 2 / 4), loop=0)
# Head metrics: widest-rows box in the top 60%: width over total height, and fill of its corners (1 = perfectly boxy)
def head(im):
    a = np.asarray(im.convert("RGBA"))[..., 3] > 128; ys, xs = np.where(a); a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    H = a.shape[0]; w = a.sum(1); top = int(H * .6); m = w[:top].max(); rows = np.where(w[:top] > .7 * m)[0]
    r0, r1 = rows.min(), rows.max(); cols = np.where(a[r0:r1 + 1].any(0))[0]; c0, c1 = cols.min(), cols.max()
    hh, hw = r1 - r0 + 1, c1 - c0 + 1; k = max(2, int(.18 * min(hh, hw))); box = a[r0:r1 + 1, c0:c1 + 1]
    corners = np.concatenate([box[:k, :k].ravel(), box[:k, -k:].ravel(), box[-k:, :k].ravel(), box[-k:, -k:].ravel()])
    return round(hw / H, 3), round(hw / hh, 3), round(float(corners.mean()), 3)
src = Image.open(R / "raw/sheet.front/980001.png")
print("pose head_w/height head_w/h corner_fill")
ref = Image.open("assets/art/party/macron-dance-v1.png").crop((41, 337, 41 + 223, 337 + 296)); print("front_idle", head(ref))
for d in sorted((R / "raw").iterdir()):
    v = [head(Image.open(p)) for p in sorted(d.glob("*.png"))]
    print(d.name, *np.round(np.mean(v, 0), 3))
