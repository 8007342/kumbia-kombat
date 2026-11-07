#!/usr/bin/env python3
"""Measures tier joins as the runtime plays them, across every phrase boundary.

  uv run --no-project --with numpy python -I tool/music/mix/join_lab.py LEVEL [--manifest PATH]

Each seam is scored against the same take's own bar lines, so 'excess' reads as how much
more a join changes than the music already does from bar to bar. These numbers measure
harmony, spectrum and level across a seam. They can't say a join sounds good.
"""
import argparse
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


class Take:
    """A looping file's bars: chroma and bands per bar, level per beat around each line."""

    def __init__(self, path, start_s, bpm, bars):
        mono = mix.decode(path, RATE, 1)
        beat = 60.0 / bpm
        length = int(round(bars * 4 * beat * RATE))
        at = int(round(start_s * RATE))
        loop = mono[at:at + length]
        if len(loop) < length:
            loop = np.concatenate([loop, np.zeros(length - len(loop))])
        self.bars, self.bpm, self.beat = bars, bpm, beat
        looped = np.concatenate([loop, loop[:8192]])
        chroma, band, _ = mix.beat_features(looped, beat, bars * 4)
        self.key = mix.measure_key(chroma)
        self.chroma = mix._unit(chroma.reshape(bars, 4, 12).sum(axis=1))
        self.band = band.reshape(bars, 4, 12)
        self.loop = loop
        self.beat_len = beat * RATE

    def rms_db(self, beat_from, beats=1):
        a = int(beat_from * self.beat_len) % len(self.loop)
        n = int(beats * self.beat_len)
        idx = np.mod(np.arange(a, a + n), len(self.loop))
        return 10 * np.log10(max(np.mean(self.loop[idx] ** 2), 1e-12))


def seam(out, b, into, e):
    """Out plays up to its bar b, then into plays from its bar e."""
    before, after = (b - 1) % out.bars, e % into.bars
    harmony = float(out.chroma[before] @ into.chroma[after])
    near = float(out.chroma[(b - 1) % out.bars] @ into.chroma[(e - 1) % into.bars])
    last_band = out.band[before, -1] - out.band.mean(axis=(0, 1))
    first_band = into.band[after, 0] - into.band.mean(axis=(0, 1))
    # Absolute spectral step in log-energy, so a change of timbre counts as well.
    timbre = float(np.mean(np.abs(out.band[before, -1] - into.band[after, 0])))
    level = abs(out.rms_db(b * 4 - 1) - into.rms_db(e * 4))
    del last_band, first_band
    return harmony, near, timbre, level


def baseline(take):
    rows = [seam(take, b, take, b) for b in range(take.bars)]
    return {"harmony": float(np.median([r[0] for r in rows])),
            "timbre": float(np.median([r[2] for r in rows])),
            "level": float(np.median([r[3] for r in rows]))}


def best_entries(out, into, step=2):
    """For each even bar of out, the even bar of into that joins it best."""
    table = []
    for b in range(0, out.bars, step):
        scored = []
        for e in range(0, into.bars, step):
            h, n, t, l = seam(out, b, into, e)
            scored.append((h + 0.25 * n - 0.15 * t - 0.03 * l, e))
        table.append(max(scored)[1])
    return table


def summarise(rows, base):
    h = np.array([r[0] for r in rows])
    t = np.array([r[2] for r in rows])
    l = np.array([r[3] for r in rows])
    return {"harmony": round(float(np.median(h)), 3), "harmonyWorst": round(float(h.min()), 3),
            "harmonyBelowBaseline": round(float(base["harmony"] - np.median(h)), 3),
            "timbreStep": round(float(np.median(t)), 2), "timbreBaseline": round(base["timbre"], 2),
            "levelJumpDb": round(float(np.median(l)), 2), "levelWorstDb": round(float(l.max()), 2)}


def run(level_id, manifest_path, root):
    manifest = json.loads(pathlib.Path(manifest_path).read_text())
    entry = manifest["levels"][level_id]
    takes = {n: Take(root / t["files"]["opus"], t["loopStartSeconds"], t["bpm"], t["bars"])
             for n, t in entry["takes"].items()}
    result = {"keys": {n: t.key[0] for n, t in takes.items()},
              "bpm": {n: t.bpm for n, t in takes.items()}, "joins": {}}
    base = {n: baseline(t) for n, t in takes.items()}
    for join in entry.get("transitions", []):
        a, z = join["from"], join["to"]
        out, into = takes[a], takes[z]
        rows = {}
        pair_base = {k: (base[a][k] + base[z][k]) / 2 for k in base[a]}
        # As shipped: any even bar, into the clip whose first bar is the loop's last bar.
        if join.get("files"):
            clip = Take(root / join["files"]["opus"], join["startSeconds"], join["bpm"], join["bars"])
            entered = [seam(out, b, clip, 0) for b in range(0, out.bars, 2)]
            rows["clipEntry"] = summarise(entered, base[a])
            rows["clipLanding"] = summarise([seam(clip, 0, into, join["entryBar"])], base[z])
        table = best_entries(out, into)
        rows["bestEntryTable"] = summarise(
            [seam(out, 2 * i, into, e) for i, e in enumerate(table)], pair_base)
        rows["bestEntryTable"]["distinctEntries"] = len(set(table))
        rows["sameBar"] = summarise([seam(out, b, into, b) for b in range(0, min(out.bars, into.bars), 2)], pair_base)
        rows["tempoStepPct"] = round((into.bpm / out.bpm - 1) * 100, 2)
        result["joins"][f"{a}>{z}"] = rows
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("level")
    parser.add_argument("--manifest", default=str(mix.REPO / "assets/music/rendered/manifest.json"))
    parser.add_argument("--root", default=str(mix.REPO))
    args = parser.parse_args()
    print(json.dumps(run(args.level, args.manifest, pathlib.Path(args.root)), indent=1))
