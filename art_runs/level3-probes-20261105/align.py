#!/usr/bin/env python3
"""How far did a generated room drift from the greybox? For known floor lines (path edges and paving
joints, projected from floor.json), find the strongest image edge perpendicular to the line within
+-search px, per sample. Reports the median and 90th percentile offset in 1024-wide px, per zone."""
import json, sys
import numpy as np
from PIL import Image
calib = json.load(open(sys.argv[1])); Hm = np.array(calib["floorHomography_st_to_px"]); W0, H0 = calib["image"]
PW = calib["pathWidthAdults"]; END = calib["pathEndS"]
def px(s, t):
    q = Hm @ np.array([s, t, 1.0]); return q[:2] / q[2]
LINES = {"path-left": [(s, -PW/2) for s in np.linspace(-1.2, END, 90)],
         "path-right": [(s, PW/2) for s in np.linspace(-1.2, END, 90)],
         "joint-1": [(s, -PW/6) for s in np.linspace(-1.2, END, 90)],
         "joint-2": [(s, PW/6) for s in np.linspace(-1.2, END, 90)],
         "cross": [(sj, t) for sj in np.arange(0, END, 1.5) for t in np.linspace(-PW/2, PW/2, 16)]}
SEARCH = 40
for path in sys.argv[2:]:
    im = Image.open(path).convert("L"); sc = W0 / im.width
    g = np.asarray(im.resize((W0, H0), Image.BICUBIC), float)
    gx = np.abs(np.gradient(g, axis=1)); gy = np.abs(np.gradient(g, axis=0)); G = np.hypot(gx, gy)
    row = [path.split("/")[-1][:24].ljust(24)]
    allv = []
    for name, pts in LINES.items():
        offs = []
        P = [px(*p) for p in pts]
        for i in range(1, len(P) - 1):
            a, b = P[i - 1], P[i + 1]
            v = b - a; L = np.hypot(*v)
            if L < 1e-6: continue
            nrm = np.array([-v[1], v[0]]) / L
            c = P[i]
            if not (20 < c[0] < W0 - 20 and 20 < c[1] < H0 - 20): continue
            vals = []
            for o in range(-SEARCH, SEARCH + 1):
                q = c + o * nrm; x, y = int(q[0]), int(q[1])
                vals.append(G[y, x] if 0 <= x < W0 and 0 <= y < H0 else 0)
            vals = np.array(vals)
            if vals.max() > 6:
                offs.append(int(np.argmax(vals)) - SEARCH)
        if offs:
            offs = np.abs(offs); allv += list(offs)
            row.append(f"{name}:{np.median(offs):.0f}/{np.percentile(offs, 90):.0f}")
    row.append(f"ALL med {np.median(allv):.1f} p90 {np.percentile(allv, 90):.1f} n={len(allv)}")
    print(" ".join(row))
