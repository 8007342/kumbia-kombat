#!/usr/bin/env python3
"""Do takes share one performance? Beat, harmony and density against a reference take.

  uv run --no-project --with numpy python -I tool/music/mix/shared_grid.py REF.flac BPM OTHER.flac...

Measures only timing, harmony and event counts. It can't say a take sounds good.
"""
import importlib.util
import json
import pathlib
import sys

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("mix", HERE / "mix.py")
mix = importlib.util.module_from_spec(spec)
sys.modules["mix"] = mix
spec.loader.exec_module(mix)
RATE = mix.RATE


def features(path, bpm):
    mono = mix.decode(path, RATE, 1)
    env = np.convolve(mix.onset_envelope(mono), np.hanning(5) / 2, "same")
    beat_s = 60.0 / bpm
    chroma, band, _ = mix.beat_features(mono, beat_s, int(len(mono) / RATE / beat_s) - 1)
    return {"mono": mono, "env": env, "chroma": chroma, "band": band, "beat": beat_s}


def lag_ms(env_a, env_b, window, reach):
    """Lag of b against a in each window, by envelope cross-correlation."""
    out, peaks = [], []
    n = min(len(env_a), len(env_b))
    for start in range(reach, n - window - reach, window):
        a = env_a[start:start + window] - env_a[start:start + window].mean()
        best, at = -2.0, 0
        for lag in range(-reach, reach + 1):
            b = env_b[start + lag:start + lag + window]
            b = b - b.mean()
            r = float(a @ b / max(np.linalg.norm(a) * np.linalg.norm(b), 1e-9))
            if r > best:
                best, at = r, lag
        out.append(at * mix.HOP / RATE * 1000)
        peaks.append(best)
    return np.array(out), np.array(peaks)


def density(env, beat_s):
    """Onsets per beat: envelope peaks above the take's own median level."""
    thresh = np.percentile(env, 75)
    peaks = (env[1:-1] > env[:-2]) & (env[1:-1] >= env[2:]) & (env[1:-1] > thresh)
    seconds = len(env) * mix.HOP / RATE
    return float(peaks.sum() / (seconds / beat_s))


def spread(mono):
    size = 4096
    idx = np.arange(size) + (size // 2) * np.arange((len(mono) - size) // (size // 2))[:, None]
    mag = np.abs(np.fft.rfft(mono[idx] * np.hanning(size), axis=1)) ** 2
    freq = np.fft.rfftfreq(size, 1 / RATE)
    total = np.maximum(mag.sum(axis=1), 1e-12)
    centre = (mag * freq).sum(axis=1) / total
    width = np.sqrt((mag * (freq - centre[:, None]) ** 2).sum(axis=1) / total)
    return float(np.median(centre)), float(np.median(width))


def compare(ref_path, bpm, others):
    ref = features(ref_path, bpm)
    rows = {}
    def describe(f):
        centre, width = spread(f["mono"])
        key, r = mix.measure_key(f["chroma"])
        return {"onsetsPerBeat": round(density(f["env"], f["beat"]), 2), "centroidHz": round(centre),
                "spreadHz": round(width), "key": key, "keyR": r,
                "rmsDb": round(10 * np.log10(np.mean(f["mono"] ** 2)), 1)}
    rows["ref"] = describe(ref)
    window = int(8 * ref["beat"] * RATE / mix.HOP)
    reach = int(0.08 * RATE / mix.HOP)
    for path in others:
        other = features(path, bpm)
        lags, peak = lag_ms(ref["env"], other["env"], window, reach)
        n = min(len(ref["chroma"]), len(other["chroma"]))
        a, b = mix._unit(ref["chroma"][:n]), mix._unit(other["chroma"][:n])
        bars = n // 4
        ba = mix._unit(ref["chroma"][:bars * 4].reshape(bars, 4, 12).sum(axis=1))
        bb = mix._unit(other["chroma"][:bars * 4].reshape(bars, 4, 12).sum(axis=1))
        row = describe(other)
        row.update(lagMedianMs=round(float(np.median(lags)), 1), lagP90AbsMs=round(float(np.percentile(np.abs(lags), 90)), 1),
                   envelopeCorr=round(float(np.median(peak)), 2),
                   barChromaMatch=round(float(np.mean((ba * bb).sum(axis=1))), 3),
                   beatChromaMatch=round(float(np.mean((a * b).sum(axis=1))), 3))
        rows[pathlib.Path(path).name] = row
    return rows


if __name__ == "__main__":
    print(json.dumps(compare(sys.argv[1], float(sys.argv[2]), sys.argv[3:]), indent=1))
