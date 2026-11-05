#!/usr/bin/env python3
"""Fit the generated image's along-path lines near the authored ones and intersect them: did the vanishing
point and horizon survive? Refit is what a real calibration stage would do on accepted art."""
import json, sys
import numpy as np
from PIL import Image
calib = json.load(open(sys.argv[1])); Hm = np.array(calib["floorHomography_st_to_px"]); W0, H0 = calib["image"]; PW = calib["pathWidthAdults"]; END = calib["pathEndS"]
def px(s, t):
    q = Hm @ np.array([s, t, 1.0]); return q[:2] / q[2]
for path in sys.argv[2:]:
    g = np.asarray(Image.open(path).convert("L").resize((W0, H0), Image.BICUBIC), float)
    G = np.hypot(np.gradient(g, axis=1), np.gradient(g, axis=0))
    lines = []
    for t in (-PW/2, -PW/6, PW/6, PW/2):
        P = [px(s, t) for s in np.linspace(0.3, END - .5, 80)]; pts = []
        for i in range(1, len(P) - 1):
            v = P[i + 1] - P[i - 1]; nrm = np.array([-v[1], v[0]]) / np.hypot(*v); c = P[i]
            if not (5 < c[0] < W0 - 5 and 5 < c[1] < H0 - 5): continue
            best, bo = 0, None
            for o in range(-30, 31):
                q = c + o * nrm; x, y = int(q[0]), int(q[1])
                if 0 <= x < W0 and 0 <= y < H0 and G[y, x] > best: best, bo = G[y, x], q
            if best > 6: pts.append(bo)
        pts = np.array(pts)
        if len(pts) < 12: continue
        best = None
        rng = np.random.default_rng(0)
        for _ in range(400):      # RANSAC
            a, b = pts[rng.choice(len(pts), 2, replace=False)]
            d = b - a
            if np.hypot(*d) < 40: continue
            n = np.array([-d[1], d[0]]) / np.hypot(*d); e = np.abs((pts - a) @ n); inl = e < 3
            if best is None or inl.sum() > best[0]: best = (inl.sum(), a, n, inl)
        if best: lines.append((t, best[0], len(pts), best[1], best[2]))
    A = np.array([l[4] for l in lines]); b = np.array([l[4] @ l[3] for l in lines])
    vp = np.linalg.lstsq(A, b, rcond=None)[0] if len(lines) >= 2 else [np.nan, np.nan]
    print(path.split("/")[-1][:26].ljust(26), "VP", np.round(vp, 0), "authored", calib["vanishingX"] * W0, calib["horizonY"] * H0, "inliers", [(round(l[0], 2), int(l[1]), l[2]) for l in lines])
