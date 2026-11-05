#!/usr/bin/env python3
"""Build check: how wide the figure is for its height, on any frame with alpha or a flat background.

height: top to bottom of the largest piece (hat to shoes).
central: width of the connected run through the body's middle, median over the band 35-60% down the
figure (chest to belly, arms that touch the body included).
torso: as central but shirt-coloured pixels only, so arms held out or akimbo can't inflate it.
Usage: measure_build.py a.png b.png ...   prints name height central/h torso/h
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SHIRT = np.array([0x63, 0x1a, 0x57])


def mask_of(im):
    a = np.array(im.convert("RGBA"))
    if (a[..., 3] < 128).any():
        fig = a[..., 3] >= 128
    else:
        rgb = a[..., :3].astype(int)
        bg = np.median(np.concatenate([rgb[:24, :24], rgb[:24, -24:]]).reshape(-1, 3), axis=0)
        fig = np.abs(rgb - bg).max(axis=-1) > 18
    lab, n = ndi.label(fig)
    fig = lab == 1 + int(np.argmax(ndi.sum(fig, lab, range(1, n + 1))))
    return a[..., :3], fig


def measure(path):
    rgb, fig = mask_of(Image.open(path))
    ys = np.where(fig.any(axis=1))[0]
    y0, y1 = ys[0], ys[-1] + 1
    h = y1 - y0
    shirt = fig & (np.abs(rgb.astype(int) - SHIRT).max(axis=-1) < 48)
    cx = np.median(np.where(shirt)[1]) if shirt.any() else np.median(np.where(fig)[1])
    central, torso = [], []
    for y in range(y0 + int(h * 0.35), y0 + int(h * 0.60)):
        row = fig[y]
        lab, n = ndi.label(row)
        if not n:
            continue
        l = lab[int(cx)]
        if l:
            central.append((lab == l).sum())
        sx = np.where(shirt[y])[0]
        if sx.size > 4:
            torso.append(sx[-1] - sx[0] + 1)
    return h, np.median(central) / h if central else 0, np.median(torso) / h if torso else 0


if __name__ == "__main__":
    for p in sys.argv[1:]:
        h, c, t = measure(p)
        print(f"{p.split('/')[-1]:36s} h={h:4d} central={c:.3f} torso={t:.3f}")
