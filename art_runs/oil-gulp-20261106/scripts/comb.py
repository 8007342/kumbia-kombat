#!/usr/bin/env python3
"""Painted cell of a raw, in raw px: strongest period of the edge comb between 4 and 40 px, same idea as closeups' measure_pixels.py with a wider range."""
import sys, numpy as np
from PIL import Image
def comb(path):
    a = np.asarray(Image.open(path).convert("RGBA"), float); m = a[..., 3] > 128; g = a[..., :3].mean(2); out = []
    for ax in (1, 0):
        d = np.abs(np.diff(g, axis=ax)); k = m[:, 1:] & m[:, :-1] if ax == 1 else m[1:, :] & m[:-1, :]
        s = (d * k).sum(0 if ax == 1 else 1); s = s - s.mean(); F = np.abs(np.fft.rfft(s * np.hanning(len(s)), n=8192)); f = np.fft.rfftfreq(8192)
        v = (f >= 1 / 40) & (f <= 1 / 4); out.append(round(float(1 / f[v][np.argmax(F[v])]), 1))
    return out
for p in sys.argv[1:]: print(p.split("kumbia-art/")[-1], comb(p))
