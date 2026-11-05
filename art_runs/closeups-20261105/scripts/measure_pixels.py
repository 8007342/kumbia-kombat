#!/usr/bin/env python3
"""Measure the painted cell of world art in device pixels on a 390x844 @3x phone, from the assets and the same formulas as
party_layout.dart: 180 logical world width, cover mapping, floor projection from levels/*.json. Cell = period of the horizontal
and vertical edge comb (FFT of summed |d|), with median colour run length as a cross-check."""
import json, sys
import numpy as np
from PIL import Image
LW, LH = 390, 844; DPR = 3
def cell(path, rect=None):
    im = Image.open(path).convert("RGBA")
    if rect: im = im.crop(rect)
    a = np.asarray(im, float); mask = a[..., 3] > 128; g = a[..., :3].mean(2)
    out = []
    for ax in (1, 0):
        d = np.abs(np.diff(g, axis=ax)); m = mask[:, 1:] & mask[:, :-1] if ax == 1 else mask[1:, :] & mask[:-1, :]
        s = (d * m).sum(0 if ax == 1 else 1); s = s - s.mean()
        if len(s) < 16: out.append(None); continue
        F = np.abs(np.fft.rfft(s * np.hanning(len(s)))); f = np.fft.rfftfreq(len(s))
        v = (f > 1 / 14) & (f <= .5); out.append(round(float(1 / f[v][np.argmax(F[v])]), 2))
    # run length of near-equal colours along rows
    A = a[..., :3]; same = (np.abs(np.diff(A, axis=1)).max(2) <= 4) & mask[:, 1:] & mask[:, :-1]; runs = []
    for r in same[:: max(1, same.shape[0] // 200)]:
        c = 0
        for v in r:
            if v: c += 1
            elif c: runs.append(c + 1); c = 0
    return out, (round(float(np.mean(runs)), 2) if runs else None)
def plate_scale(sw, sh, overscan=0.0):
    ppu = LW / 180; lh = LH / ppu
    return max((180 + 2 * overscan) / sw, (lh + 2 * overscan) / sh), ppu
if __name__ == "__main__":
    for lv, f in [("garden", "assets/art/garden/garden-mansion.png"), ("bar", "assets/art/bar/bar-interior.png")]:
        im = Image.open(f); s, ppu = plate_scale(*im.size); devperpx = s * ppu * DPR
        comb, run = cell(f)
        print(lv, "plate", im.size, "device px per source px", round(devperpx, 3), "comb(x,y)", comb, "run", run,
              "=> device px per painted cell (comb)", [round(c * devperpx, 2) if c else None for c in comb], "(run)", round(run * devperpx, 2))
    for f in sys.argv[1:]:
        print(f, Image.open(f).size, cell(f))
