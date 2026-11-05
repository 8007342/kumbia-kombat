#!/usr/bin/env python3
"""CPU: can a fist bump be registered from separately drawn characters? Floor line shared, Macron at 0.35 adult."""
import sys
import numpy as np
from PIL import Image
C = "/home/forge/.cache/tillandsias-project/kumbia-art/level3-probes-20261105/"
def load(p):
    im = Image.open(C + p).convert("RGBA"); a = np.asarray(im)[..., 3] > 128; ys, xs = np.where(a)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
gk = load("gk-kneel2-970181.png"); mc = load("mac-fist-970121.png")
ADULT = 620                        # px on this sheet
KNEEL_FRACTION = .72               # inferred: kneeling figure with hat, in adults
gk = gk.resize((int(gk.width * ADULT * KNEEL_FRACTION / gk.height), int(ADULT * KNEEL_FRACTION)), Image.LANCZOS)
mh = int(ADULT * .35); mc = mc.resize((int(mc.width * mh / mc.height), mh), Image.LANCZOS)
def edge(im, side):
    a = np.asarray(im)[..., 3] > 128; xs = np.where(a.any(0))[0]; x = xs.min() if side == "L" else xs.max()
    ys = np.where(a[:, x + (4 if side == "L" else -4)])[0]; return x, int(ys.mean())
gx, gy = edge(gk, "L"); mx, my = edge(mc, "R")
floor = 700; W = 900
S = Image.new("RGBA", (W, floor + 30), (150, 150, 155, 255))
gkx = 430; S.alpha_composite(gk, (gkx, floor - gk.height))
fist_g_y = floor - gk.height + gy; fist_m_y = floor - mc.height + my
print("Gatekeeper fist height above floor, adults", round((floor - fist_g_y) / ADULT, 3), "Macron fist", round((floor - fist_m_y) / ADULT, 3), "difference px on a 620px adult", fist_m_y - fist_g_y)
# left: same floor, touching in x only
mcx = gkx + gx - mx; S.alpha_composite(mc, (mcx, floor - mc.height))
S.convert("RGB").save(sys.argv[1])
