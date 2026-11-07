#!/usr/bin/env python3
"""Music sheets as pipeline inputs: render a guide from a sheet, or read chords from a take.

  uv run --no-project --with numpy python -I tool/music/sheet.py --self-test
  uv run --no-project --with numpy python -I tool/music/sheet.py guide tool/music/sheets/bar.json OUT_DIR
  uv run --no-project --with numpy python -I tool/music/sheet.py ear TAKE.flac BPM [--bar-one BEATS]

`guide` writes one FLAC per layer plus the sum, on an exact grid: the wireframe an
audio-to-audio pass starts from once audio input is available. `ear` writes no audio and
uses no model: chord templates against chroma, one guess per bar. It's a plain estimate,
good enough to write a sheet down and to compare takes, not a transcription.
"""
import json
import pathlib
import subprocess
import sys

import numpy as np

SR = 48000
NOTES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7,
         "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
QUALITIES = {"": (0, 4, 7), "m": (0, 3, 7), "7": (0, 4, 7, 10), "m7": (0, 3, 7, 10), "maj7": (0, 4, 7, 11)}
# A 3-2 son clave, in beats of a two-bar cell.
CLAVE = (0, 1.5, 3, 5, 6)


def parse_chord(name):
    root = name[:2] if name[:2] in NOTES else name[0]
    return NOTES[root], QUALITIES[name[len(root):]]


def chord_lane(sheet):
    """One chord name per bar, in form order."""
    lane = []
    for section in sheet["form"]:
        chords = section["chords"]
        lane += [chords[i % len(chords)] for i in range(section["bars"])]
    return lane


def freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def tone(f, seconds, partials=(1.0, 0.5, 0.25), decay=3.0):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    wave = sum(a * np.sin(2 * np.pi * f * (k + 1) * t) for k, a in enumerate(partials))
    attack = np.minimum(t / 0.004, 1.0)
    release = np.minimum((seconds - t) / 0.01, 1.0)
    return wave * attack * release * np.exp(-decay * t) / sum(partials)


def tick(seconds=0.03, hz=2400.0):
    t = np.arange(int(seconds * SR)) / SR
    return np.sin(2 * np.pi * hz * t) * np.exp(-t / 0.006)


def _add(buffer, at, audio, gain):
    start = int(round(at * SR))
    stop = min(start + len(audio), len(buffer))
    if start < len(buffer):
        buffer[start:stop] += audio[:stop - start] * gain


def render_layers(sheet):
    """Bass, comping and clave on the grid. No lead: melody is what the model must add."""
    beat = 60.0 / sheet["bpm"]
    lane = chord_lane(sheet)
    length = int(round(len(lane) * 4 * beat * SR)) + SR
    layers = {name: np.zeros(length) for name in ("bass", "comp", "clave")}
    for bar, name in enumerate(lane):
        root, quality = parse_chord(name)
        at = bar * 4 * beat
        # A tumbao-like bass: root and fifth, anticipating the next bar's root.
        following = parse_chord(lane[(bar + 1) % len(lane)])[0]
        for pos, pitch in ((0.0, root), (1.5, root + 7), (3.5, following)):
            _add(layers["bass"], at + pos * beat, tone(freq(36 + pitch % 12), 1.2 * beat, (1.0, 0.35), 2.0), 0.8)
        for pos in (0.5, 1.5, 2.5, 3.5):
            for step in quality:
                _add(layers["comp"], at + pos * beat, tone(freq(60 + (root + step) % 12), 0.45 * beat), 0.22)
        for pos in CLAVE:
            if bar % 2 == int(pos // 4):
                _add(layers["clave"], at + (pos % 4) * beat, tick(), 0.5)
    return layers


def write_flac(audio, path):
    pathlib.Path(path).parent.mkdir(parents=True, exist_ok=True)
    stereo = np.stack([audio, audio], axis=1).astype(np.float32)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                    "-map_metadata", "-1", "-c:a", "flac", str(path)], input=stereo.tobytes(), check=True)


def guide(sheet, out_dir):
    layers = render_layers(sheet)
    total = sum(layers.values())
    scale = 0.7 / max(np.abs(total).max(), 1e-9)
    out = pathlib.Path(out_dir)
    for name, audio in layers.items():
        write_flac(audio * scale, out / f"{name}.flac")
    write_flac(total * scale, out / "guide.flac")
    return total * scale


def bar_chroma(mono, rate, bpm, first_beat=0):
    size, step = 8192, 2048
    count = (len(mono) - size) // step
    idx = np.arange(size) + step * np.arange(count)[:, None]
    mag = np.abs(np.fft.rfft(mono[idx] * np.hanning(size), axis=1)) ** 2
    f = np.fft.rfftfreq(size, 1 / rate)
    keep = (f >= 60) & (f <= 2000)
    pc = np.mod(np.round(12 * np.log2(f[keep] / 261.626)).astype(int), 12)
    frames = np.zeros((count, 12))
    np.add.at(frames.T, pc, mag[:, keep].T)
    bar_seconds = 240.0 / bpm
    origin = first_beat * 60.0 / bpm
    bars = int((len(mono) / rate - origin) / bar_seconds)
    centres = (np.arange(count) * step + size / 2) / rate
    out = np.zeros((bars, 12))
    for b in range(bars):
        where = (centres >= origin + b * bar_seconds) & (centres < origin + (b + 1) * bar_seconds)
        out[b] = frames[where].sum(axis=0)
    return out


def ear(mono, rate, bpm, first_beat=0):
    chroma = bar_chroma(mono, rate, bpm, first_beat)
    templates = []
    for name, root in NOTES.items():
        if "#" in name:
            continue
        for label in ("", "m"):
            t = np.zeros(12)
            t[[(root + s) % 12 for s in QUALITIES[label]]] = 1
            templates.append((name + label, t / np.linalg.norm(t)))
    unit = chroma / np.maximum(np.linalg.norm(chroma, axis=1, keepdims=True), 1e-9)
    return [max(templates, key=lambda x: float(row @ x[1]))[0] for row in unit]


def read_mono(path, rate=22050):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(rate), "-f", "f32le", "-"],
                         check=True, stdout=subprocess.PIPE).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def self_test():
    sheet = {"bpm": 100, "form": [{"bars": 4, "chords": ["Cm", "Fm", "G7", "Cm"]}]}
    layers = render_layers(sheet)
    total = sum(layers.values())
    assert len(total) == int(round(4 * 4 * 0.6 * SR)) + SR, "the guide's length follows the bars"
    assert np.abs(total).max() > 0.1, "the guide isn't silent"
    heard = ear(np.interp(np.arange(int(len(total) * 22050 / SR)) * SR / 22050, np.arange(len(total)), total), 22050, 100)[:4]
    assert heard[0] == "Cm" and heard[1] == "Fm" and heard[3] == "Cm", heard
    assert chord_lane({"form": [{"bars": 3, "chords": ["Am", "E7"]}]}) == ["Am", "E7", "Am"]
    print("self-test passes", heard)


def main():
    if sys.argv[1] == "--self-test":
        self_test()
    elif sys.argv[1] == "guide":
        guide(json.loads(pathlib.Path(sys.argv[2]).read_text()), sys.argv[3])
    elif sys.argv[1] == "ear":
        first = float(sys.argv[sys.argv.index("--bar-one") + 1]) if "--bar-one" in sys.argv else 0
        print(" ".join(ear(read_mono(sys.argv[2]), 22050, float(sys.argv[3]), first)))


if __name__ == "__main__":
    main()
