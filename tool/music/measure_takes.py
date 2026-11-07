#!/usr/bin/env python3
"""Timing filter for generated music takes (plan/music-rebuild.md, stage 2).

Measures each take's beat against the tempo asked for and says whether it can be
corrected to the grid. It judges timing only: the owner's ears judge the music.

  uv run --with numpy python -I tool/music/measure_takes.py --self-test
  uv run --with numpy python -I tool/music/measure_takes.py --bpm 98 --json out.json takes/*.flac

A take passes when all of these hold. The limits are starting values, not findings:
  - the strongest pulse near the target is within MAX_ERROR_PCT, the most the pilot
    corrects with ffmpeg;
  - that pulse stands clear of the take's other tempi (MIN_CLARITY);
  - it isn't really half-time. With alternate beats of strength a and b, the pulse at
    target/2 over the pulse at the target is (a-b)/(a+b): 0 for even beats, 1 when every
    other beat is missing. HALF_TIME_RATIO 0.6 means the weak beats are 4 times weaker;
  - the beat holds steady, with phase wander under MAX_WANDER_MS after a straight fit.
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

MAX_ERROR_PCT = 1.5
MIN_CLARITY = 4.0
HALF_TIME_RATIO = 0.6
MAX_WANDER_MS = 35.0
SEARCH_PCT = 8.0
PHASE_WINDOW_BEATS = 16


def decode(path):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE),
         "-f", "s16le", "-"],
        check=True, stdout=subprocess.PIPE,
    ).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0


def onset_envelope(samples):
    """Half-wave rectified log spectral flux, with its slow trend removed."""
    count = (len(samples) - WINDOW) // HOP
    if count < 2:
        raise ValueError("take is too short to measure")
    window = np.hanning(WINDOW)
    env = np.zeros(count)
    previous = None
    for i in range(count):
        frame = samples[i * HOP:i * HOP + WINDOW] * window
        spectrum = np.log1p(100.0 * np.abs(np.fft.rfft(frame)))
        if previous is not None:
            env[i] = np.maximum(spectrum - previous, 0.0).sum()
        previous = spectrum
    trend = np.convolve(env, np.ones(int(ENV_RATE)) / int(ENV_RATE), mode="same")
    return np.maximum(env - trend, 0.0)


def pulse_strength(env, bpm):
    """How much of the envelope repeats at this tempo: a Fourier tempogram over the take."""
    times = np.arange(len(env)) / ENV_RATE
    bpm = np.atleast_1d(bpm)
    return np.array([np.abs(np.sum(env * np.exp(-2j * np.pi * (b / 60.0) * times))) for b in bpm])


def wander_ms(env, bpm):
    """Steadiness: per-window beat phase, a straight line fitted through it, residual in ms."""
    size = int(PHASE_WINDOW_BEATS * 60.0 / bpm * ENV_RATE)
    freq = bpm / 60.0
    phases, centres = [], []
    for start in range(0, len(env) - size + 1, size // 2):
        part = env[start:start + size]
        if part.sum() <= 0:
            continue
        times = (start + np.arange(size)) / ENV_RATE
        phases.append(np.angle(np.sum(part * np.exp(-2j * np.pi * freq * times))))
        centres.append(times.mean())
    if len(phases) < 3:
        return None, bpm
    unwrapped = np.unwrap(phases)
    slope, offset = np.polyfit(centres, unwrapped, 1)
    residual = unwrapped - (slope * np.array(centres) + offset)
    # A beat at freq + df gains phase at 2*pi*df, and the sign follows exp(-2j*pi*f*t).
    refined = (freq - slope / (2 * np.pi)) * 60.0
    return float(np.sqrt(np.mean(residual ** 2)) / (2 * np.pi * freq) * 1000.0), float(refined)


def measure(samples, target):
    env = onset_envelope(samples)
    near = np.arange(target * (1 - SEARCH_PCT / 100), target * (1 + SEARCH_PCT / 100), 0.05)
    strengths = pulse_strength(env, near)
    coarse = float(near[int(np.argmax(strengths))])
    wander, refined = wander_ms(env, coarse)
    if abs(refined - coarse) > 0.5:  # A refinement this far is a fit gone wrong, not precision.
        refined = coarse
    at_target = float(strengths.max())
    background = float(np.median(pulse_strength(env, np.arange(45.0, 240.0, 0.5))))
    clarity = at_target / background if background > 0 else 0.0
    half = float(pulse_strength(env, target / 2)[0]) / at_target if at_target > 0 else 0.0
    error = (refined - target) / target * 100.0
    reasons = []
    if abs(error) > MAX_ERROR_PCT:
        reasons.append(f"tempo off by {error:+.2f}%")
    if clarity < MIN_CLARITY:
        reasons.append(f"no clear pulse ({clarity:.1f})")
    if half > HALF_TIME_RATIO:
        reasons.append(f"half-time ({half:.2f})")
    if wander is None:
        reasons.append("too short to judge steadiness")
    elif wander > MAX_WANDER_MS:
        reasons.append(f"beat wanders {wander:.0f} ms")
    return {
        "target_bpm": target,
        "measured_bpm": round(refined, 2),
        "error_pct": round(error, 2),
        "clarity": round(clarity, 1),
        "half_time_ratio": round(half, 2),
        "wander_ms": None if wander is None else round(wander, 1),
        "seconds": round(len(samples) / RATE, 2),
        "passed": not reasons,
        "reasons": reasons,
    }


def click_track(bpm, seconds, jitter_ms=0.0, every=1, seed=1):
    """A bright tick on each beat, over quiet noise so the spectrum is never empty."""
    rng = np.random.default_rng(seed)
    out = rng.normal(0, 0.002, int(seconds * RATE))
    tick = np.exp(-np.arange(400) / 60.0) * np.sin(2 * np.pi * 2500 * np.arange(400) / RATE)
    period = 60.0 / bpm * every
    for k in range(int(seconds / period)):
        at = int((k * period + rng.normal(0, jitter_ms / 1000.0)) * RATE)
        if 0 <= at < len(out) - len(tick):
            out[at:at + len(tick)] += 0.6 * tick
    return out


def self_test():
    """Known answers: every case must come out as stated, or the filter can't be trusted."""
    cases = [
        ("steady, on target", click_track(98, 60), 98, True, None),
        ("fast, on target", click_track(144, 60), 144, True, None),
        ("0.5% slow, correctable", click_track(97.5, 60), 98, True, None),
        ("4% fast", click_track(102, 60), 98, False, "tempo off"),
        ("half-time", click_track(98, 60, every=2), 98, False, "half-time"),
        ("beat wanders", click_track(98, 60, jitter_ms=120), 98, False, "wanders"),
        ("noise only", np.random.default_rng(3).normal(0, 0.1, 60 * RATE), 98, False, None),
    ]
    failures = 0
    for name, samples, target, expected, reason in cases:
        got = measure(samples, target)
        ok = got["passed"] == expected and (reason is None or any(reason in r for r in got["reasons"]))
        failures += not ok
        print(f"{'ok  ' if ok else 'FAIL'} {name}: {got['measured_bpm']} bpm, "
              f"clarity {got['clarity']}, half {got['half_time_ratio']}, "
              f"wander {got['wander_ms']} ms, {got['reasons'] or 'passed'}")
    print("self-test " + ("failed" if failures else "passed"))
    return 1 if failures else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("takes", nargs="*", type=pathlib.Path)
    parser.add_argument("--bpm", type=float)
    parser.add_argument("--json", type=pathlib.Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if not args.takes or not args.bpm:
        parser.error("give --bpm and at least one take, or --self-test")
    results = {}
    for take in args.takes:
        got = measure(decode(take), args.bpm)
        results[take.name] = got
        print(f"{'PASS' if got['passed'] else 'fail'} {take.name}: {got['measured_bpm']} bpm "
              f"({got['error_pct']:+.2f}%), clarity {got['clarity']}, half {got['half_time_ratio']}, "
              f"wander {got['wander_ms']} ms {'; '.join(got['reasons'])}")
    passed = sum(r["passed"] for r in results.values())
    print(f"{passed} of {len(results)} pass")
    if args.json:
        args.json.write_text(json.dumps(results, indent=1) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
