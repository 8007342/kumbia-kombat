#!/usr/bin/env python3
"""Rough density measures for ladder takes (plan/music-themes-2026-11-06.md).

A filter for the owner's ears, not a verdict: nothing here says a take sounds sparse or full,
only that it has fewer or more of what these numbers count.

  uv run --no-project --with numpy python -I tool/music/ladder_measures.py --self-test
  uv run --no-project --with numpy python -I tool/music/ladder_measures.py --bpm 144 --json out.json take.flac

Each take is measured over the window a listener hears (--start, --seconds) and whole:
  onsets_per_beat   onsets per asked beat. Use this one across tempos: onsets per second rise
                    with tempo alone, so a faster take with the same pattern scores higher.
  onsets_per_sec    the same count against the clock.
  spread_hz         power-weighted spread of the spectrum around its centre, averaged over time.
  centroid_hz       the centre of that spectrum.
  rms_db            mean level before normalising. Takes aren't level matched, so it is weak evidence.
  rms_range_db      95th minus 10th percentile of 100 ms level. A sparse take may show more range
                    than a full one, so its direction isn't "bigger is fuller".

Onsets and spreads are measured after matching RMS, so a louder take doesn't get more onsets.
"""
import argparse
import json
import pathlib
import subprocess
import sys

import numpy as np

RATE = 22050
HOP = 256
WINDOW = 1024
ENV_RATE = RATE / HOP
MIN_ONSET_GAP_S = 0.05
THRESHOLD_STD = 1.0
TARGET_RMS = 0.1


def decode(path):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"],
        check=True, stdout=subprocess.PIPE,
    ).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0


def spectra(samples):
    count = (len(samples) - WINDOW) // HOP
    if count < 2:
        raise ValueError("take is too short to measure")
    window = np.hanning(WINDOW)
    frames = np.stack([samples[i * HOP:i * HOP + WINDOW] * window for i in range(count)])
    return np.abs(np.fft.rfft(frames, axis=1))


def count_onsets(magnitude):
    """Peaks in half-wave rectified log spectral flux, above a threshold that follows the take."""
    logged = np.log1p(100.0 * magnitude)
    flux = np.maximum(np.diff(logged, axis=0), 0.0).sum(axis=1)
    size = int(ENV_RATE)
    trend = np.convolve(flux, np.ones(size) / size, mode="same")
    env = np.maximum(flux - trend, 0.0)
    threshold = env.mean() + THRESHOLD_STD * env.std()
    gap = max(1, int(MIN_ONSET_GAP_S * ENV_RATE))
    onsets, last = 0, -gap
    for i in range(1, len(env) - 1):
        if env[i] > threshold and env[i] >= env[i - 1] and env[i] >= env[i + 1] and i - last >= gap:
            onsets += 1
            last = i
    return onsets


def measure_part(samples, bpm):
    seconds = len(samples) / RATE
    rms = float(np.sqrt(np.mean(samples ** 2)))
    if rms <= 0:
        raise ValueError("take is silent")
    magnitude = spectra(samples * (TARGET_RMS / rms))
    power = magnitude ** 2
    freqs = np.fft.rfftfreq(WINDOW, 1 / RATE)
    total = power.sum(axis=1) + 1e-12
    centroid = (power * freqs).sum(axis=1) / total
    spread = np.sqrt((power * (freqs[None, :] - centroid[:, None]) ** 2).sum(axis=1) / total)
    onsets = count_onsets(magnitude)
    block = int(0.1 * RATE)
    blocks = samples[:len(samples) // block * block].reshape(-1, block)
    levels = 20 * np.log10(np.sqrt(np.mean(blocks ** 2, axis=1)) + 1e-9)
    return {
        "onsets_per_beat": round(onsets / (seconds * bpm / 60.0), 3),
        "onsets_per_sec": round(onsets / seconds, 2),
        "spread_hz": round(float(spread.mean()), 0),
        "centroid_hz": round(float(centroid.mean()), 0),
        "rms_db": round(20 * float(np.log10(rms)), 1),
        "rms_range_db": round(float(np.percentile(levels, 95) - np.percentile(levels, 10)), 1),
    }


def measure(samples, bpm, start, seconds):
    a = int(start * RATE)
    return {
        "bpm_asked": bpm,
        "heard": measure_part(samples[a:a + int(seconds * RATE)], bpm),
        "whole": measure_part(samples, bpm),
    }


def self_test():
    """Known orderings: if these fail, the numbers mean nothing."""
    rng = np.random.default_rng(5)
    seconds = 40

    def clicks(bpm, per_beat):
        out = rng.normal(0, 0.002, seconds * RATE)
        tick = np.exp(-np.arange(400) / 60.0) * np.sin(2 * np.pi * 2500 * np.arange(400) / RATE)
        period = 60.0 / bpm / per_beat
        for k in range(int(seconds / period)):
            at = int(k * period * RATE)
            if at + 400 < len(out):
                out[at:at + 400] += 0.6 * tick
        return out

    sparse = measure_part(clicks(120, 0.5), 120)
    busy = measure_part(clicks(120, 2), 120)
    louder = measure_part(clicks(120, 0.5) * 3, 120)
    same_at_faster = measure_part(clicks(160, 0.5), 160)
    time = np.arange(seconds * RATE) / RATE
    tone = measure_part(0.1 * np.sin(2 * np.pi * 440 * time), 120)
    noise = measure_part(rng.normal(0, 0.1, seconds * RATE), 120)
    steady = measure_part(0.1 * np.sin(2 * np.pi * 440 * time) + rng.normal(0, 0.01, seconds * RATE), 120)
    gated = measure_part((0.1 * np.sin(2 * np.pi * 440 * time)) * (np.sin(2 * np.pi * 0.5 * time) > 0) + rng.normal(0, 0.001, seconds * RATE), 120)
    cases = [
        ("more notes count higher", busy["onsets_per_beat"] > 2 * sparse["onsets_per_beat"]),
        ("level doesn't change the count", louder["onsets_per_beat"] == sparse["onsets_per_beat"]),
        ("per beat holds across tempo", abs(same_at_faster["onsets_per_beat"] - sparse["onsets_per_beat"]) < 0.1),
        ("per second rises with tempo", same_at_faster["onsets_per_sec"] > 1.2 * sparse["onsets_per_sec"]),
        ("noise spreads wider than a tone", noise["spread_hz"] > 5 * tone["spread_hz"]),
        ("gating widens the level range", gated["rms_range_db"] > steady["rms_range_db"] + 10),
    ]
    for name, ok in cases:
        print(f"{'ok  ' if ok else 'FAIL'} {name}")
    failed = not all(ok for _, ok in cases)
    print("self-test " + ("failed" if failed else "passed"))
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("takes", nargs="*", type=pathlib.Path)
    parser.add_argument("--bpm", type=float, help="the tempo asked for")
    parser.add_argument("--start", type=float, default=15.0)
    parser.add_argument("--seconds", type=float, default=40.0)
    parser.add_argument("--json", type=pathlib.Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if not args.takes or not args.bpm:
        parser.error("give --bpm and at least one take, or --self-test")
    results = {}
    for take in args.takes:
        results[take.name] = measure(decode(take), args.bpm, args.start, args.seconds)
        got = results[take.name]["heard"]
        print(f"{take.name}: {got['onsets_per_beat']} onsets/beat, {got['onsets_per_sec']}/s, "
              f"spread {got['spread_hz']:.0f} Hz, centroid {got['centroid_hz']:.0f} Hz, "
              f"{got['rms_db']} dB, range {got['rms_range_db']} dB")
    if args.json:
        args.json.write_text(json.dumps(results, indent=1) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
