#!/usr/bin/env python3
"""Rough stand-ins for what the owner praised: lively, identifiable, characterful.

  uv run --no-project --with numpy python -I tool/music/character_measures.py BPM take.flac...

Nobody here can hear. These count things that might go with a lead line and a hook: how much
pitched motion sits above the accompaniment, whether the top line repeats bar patterns, how
much the arrangement moves. They were picked after seeing a handful of blind results, so
they can shortlist takes but can't say a take is good.
"""
import json
import pathlib
import subprocess
import sys

import numpy as np

RATE = 22050
SIZE, HOP = 4096, 512


def read(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
                         check=True, stdout=subprocess.PIPE).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def measure(path, bpm):
    mono = read(path)
    count = (len(mono) - SIZE) // HOP
    idx = np.arange(SIZE) + HOP * np.arange(count)[:, None]
    mag = np.abs(np.fft.rfft(mono[idx] * np.hanning(SIZE), axis=1))
    freq = np.fft.rfftfreq(SIZE, 1 / RATE)
    lead = (freq >= 400) & (freq <= 2500)
    power = mag[:, lead] ** 2
    # The strongest pitch in the lead register, per frame, and how far above its surroundings.
    peak = power.argmax(axis=1)
    top = power.max(axis=1)
    mean = np.maximum(power.mean(axis=1), 1e-12)
    salience = top / mean
    midi = 69 + 12 * np.log2(np.maximum(freq[lead][peak], 1.0) / 440.0)
    voiced = salience > np.percentile(salience, 40)
    beat_frames = 60.0 / bpm * RATE / HOP
    step = max(int(beat_frames / 4), 1)
    line = midi[::step]
    ok = voiced[::step]
    moves = np.abs(np.diff(line))
    # Pitch changes of one to twelve semitones between sixteenths: melody, not noise.
    melodic = float(np.mean((moves >= 0.8) & (moves <= 12) & ok[1:] & ok[:-1]))
    range_st = float(np.percentile(line[ok], 95) - np.percentile(line[ok], 5)) if ok.any() else 0.0

    # Does the top line come back? Pitch-class pattern against itself 2, 4 and 8 bars on.
    bar = int(round(beat_frames * 4 / step))
    pc = np.mod(np.round(line), 12).astype(int)
    onehot = np.zeros((len(pc), 12))
    onehot[np.arange(len(pc)), pc] = ok.astype(float)
    def repeat(lag_bars):
        lag = lag_bars * bar
        if len(onehot) <= lag:
            return 0.0
        return float(np.sum(onehot[lag:] * onehot[:-lag]) / max(np.sum(ok[lag:] & ok[:-lag]), 1))
    hook = max(repeat(2), repeat(4), repeat(8))

    # Arrangement movement: how much the spectrum's shape changes across 4-bar blocks.
    edges = np.geomspace(60, 8000, 13)
    bands = np.stack([np.log1p((mag[:, (freq >= a) & (freq < b)] ** 2).sum(axis=1)) for a, b in zip(edges[:-1], edges[1:])], axis=1)
    block = int(round(beat_frames * 16))
    means = np.stack([bands[i:i + block].mean(axis=0) for i in range(0, len(bands) - block, block)]) if len(bands) > block else bands[:1]
    movement = float(np.mean(np.abs(np.diff(means, axis=0)))) if len(means) > 1 else 0.0
    return {"melodicMotion": round(melodic, 3), "leadRangeSemitones": round(range_st, 1), "hookRepeat": round(hook, 3),
            "leadSalience": round(float(np.median(salience)), 1), "arrangementMovement": round(movement, 3)}


if __name__ == "__main__":
    bpm = float(sys.argv[1])
    out = {pathlib.Path(p).name: measure(p, bpm) for p in sys.argv[2:]}
    print(json.dumps(out, indent=1))
