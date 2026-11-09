#!/usr/bin/env python3
"""Measures for layered tiers: stereo image, clipping, brightness, bass, density, level.

  uv run --no-project --with numpy --with soundfile python -I tool/music/layer/measure.py FILE...

Gates (fail): overall stereo correlation under +0.2, more than 10 % of half-second
windows anti-correlated, more than 4 clipped runs (3+ samples at |x| >= 0.999),
or any dropout
(a 10 ms window 30 dB under its second).
These numbers measure the signal. They can't say whether it sounds good.
"""
import json, subprocess, sys
import numpy as np
import soundfile as sf

CORR_MIN, NEG_MAX, CLIP_MAX = 0.2, 0.10, 4

def lufs(path):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    val = lambda key: float(out.split(key)[-1].split()[0])
    return val(" I: "), val("Peak:")

def clip_runs(x, thr=0.999, run=3):
    hot = np.abs(x) >= thr
    n = 0
    for ch in range(x.shape[1]):
        h = hot[:, ch].astype(np.int8)
        d = np.diff(np.concatenate([[0], h, [0]]))
        starts, ends = np.where(d == 1)[0], np.where(d == -1)[0]
        n += int(np.sum(ends - starts >= run))
    return n

def clicks(x, sr):
    """Informational only, not a gate: it counts thousands on clean takes, so compare
    a tier against its own base, and leave real click finding to audio.detect_glitches.
    Sample steps far above what the neighbourhood does: a step in the second
    difference over 12x the local (50 ms) median of the same, on either channel."""
    n = 0
    k = int(sr * 0.05) | 1
    for ch in range(x.shape[1]):
        d = np.abs(np.diff(x[:, ch], 2))
        # Local level from block medians, which is cheap on a whole take.
        blocks = d[: len(d) // k * k].reshape(-1, k)
        med = np.repeat(np.median(blocks, axis=1), k)
        hot = d[: len(med)] > 12 * med + 0.02
        n += int(np.sum(np.diff(hot.astype(np.int8)) == 1))
    return n


def dropouts(x, sr):
    """10 ms windows over 30 dB under the second around them, after the first second."""
    m = np.abs(x).mean(axis=1)
    w = sr // 100
    rms = np.sqrt(np.convolve(m[: len(m) // w * w].reshape(-1, w).mean(axis=1) ** 2, np.ones(1), "same"))
    ctx = np.convolve(rms, np.ones(100) / 100, "same")
    low = (rms < ctx * db_(-30)) & (ctx > db_(-40))
    low[:100] = low[-100:] = False
    return int(np.sum(np.diff(low.astype(np.int8)) == 1))


def db_(v):
    return 10 ** (v / 20)


def measure(path):
    x, sr = sf.read(path, always_2d=True, dtype="float64")
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    l, r = x[:, 0], x[:, 1]
    corr = float(np.sum(l * r) / (np.sqrt(np.sum(l * l) * np.sum(r * r)) + 1e-12))
    w = sr // 2
    neg = tot = 0
    for i in range(0, len(l) - w, w):
        a, b = l[i:i + w], r[i:i + w]
        e = np.sqrt(np.sum(a * a) * np.sum(b * b))
        if e < 1e-6:
            continue
        tot += 1
        neg += np.sum(a * b) / e < 0
    m = (l + r) / 2
    n = 4096
    frames = np.lib.stride_tricks.sliding_window_view(m, n)[::n // 2]
    spec = np.abs(np.fft.rfft(frames * np.hanning(n), axis=1)) ** 2
    f = np.fft.rfftfreq(n, 1 / sr)
    p = spec.sum(axis=0)
    centroid = float(np.sum(f * p) / np.sum(p))
    bass_db = float(10 * np.log10(p[f < 150].sum() / p.sum()))
    flux = np.maximum(np.diff(np.sqrt(spec), axis=0), 0).sum(axis=1)
    flux = flux - np.convolve(flux, np.ones(9) / 9, mode="same")
    onsets_per_s = float(np.sum((flux[1:-1] > flux[:-2]) & (flux[1:-1] > flux[2:]) & (flux[1:-1] > flux.std())) / (len(m) / sr))
    side = float(10 * np.log10(np.sum((l - r) ** 2) / (np.sum((l + r) ** 2) + 1e-12)))
    il, peak = lufs(path)
    res = dict(file=path, seconds=round(len(l) / sr, 2), corr=round(corr, 3), negWindows=round(neg / max(tot, 1), 3),
               clipRuns=clip_runs(x), clicks=clicks(x, sr), dropouts=dropouts(x, sr), centroidHz=round(centroid), bassDb=round(bass_db, 1), sideDb=round(side, 1),
               onsetsPerS=round(onsets_per_s, 2), lufs=il, peakDb=peak)
    fails = []
    if corr < CORR_MIN: fails.append(f"stereo correlation {corr:+.2f} < {CORR_MIN:+.2f}")
    if res["negWindows"] > NEG_MAX: fails.append(f"{res['negWindows']:.0%} windows anti-correlated")
    if res["clipRuns"] > CLIP_MAX: fails.append(f"{res['clipRuns']} clipped runs")
    if res["dropouts"] > 0: fails.append(f"{res['dropouts']} dropouts")
    res["fails"] = fails
    return res

if __name__ == "__main__":
    bad = 0
    for p in sys.argv[1:]:
        r = measure(p)
        bad += bool(r["fails"])
        print(json.dumps(r))
    sys.exit(1 if bad else 0)
