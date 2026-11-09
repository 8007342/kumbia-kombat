#!/usr/bin/env python3
"""How far a stretched tier's attacks sit from its mid, to the millisecond.

  uv run --no-project --with numpy --with scipy --with soundfile python -I \
      tool/music/layer/lag.py MID STRETCHED RATIO

The stretched file's time is divided by RATIO (output over input duration) to
land on mid's clock, then onset envelopes at 1 kHz are cross-correlated over the
middle of the take. Prints the lag in ms: positive means the stretched tier is late.
"""
import sys
import numpy as np
import soundfile as sf
from scipy.signal import stft

PAD = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0  # seconds before the loop, the same in both

def env(path, ratio):
    x, sr = sf.read(path, always_2d=True)
    m = x.mean(axis=1)
    hop = sr // 1000
    _, _, z = stft(m, fs=sr, nperseg=1024, noverlap=1024 - hop)
    s = np.abs(z)
    flux = np.maximum(np.diff(np.log1p(100 * s), axis=1), 0).sum(axis=0)
    t = PAD + (np.arange(len(flux)) / 1000.0 - PAD) / ratio  # on mid's clock, in seconds
    grid = np.arange(0, t[-1], 0.001)
    return np.interp(grid, t, flux)

a = env(sys.argv[1], 1.0)
b = env(sys.argv[2], float(sys.argv[3]))
n = min(len(a), len(b))
lo, hi = int(n * 0.15), int(n * 0.85)
reach = 40
scores = [np.dot(a[lo:hi], b[lo + k:hi + k]) for k in range(-reach, reach + 1)]
print(f"{(int(np.argmax(scores)) - reach)}")
