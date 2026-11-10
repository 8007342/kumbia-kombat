#!/usr/bin/env python3
"""Offline mixing: approved takes in, game-ready loops, joins and exit material out.

  uv run --no-project --with numpy python -I tool/music/mix/mix.py --self-test
  uv run --no-project --with numpy python -I tool/music/mix/mix.py build [--level garden]
  uv run --no-project --with numpy python -I tool/music/mix/mix.py verify
  uv run --no-project --with numpy python -I tool/music/mix/mix.py listen DIR

Everything comes from levels.json beside this file. Numbers here measure timing,
level and sample continuity. They can't say whether a join sounds good.

For each tier: find the beat, warp it onto the exact grid with WSOLA (pitch kept),
find bar one, pick the best-looping bars, wrap the seam, set loudness, limit, encode.
Each file holds its loop between pads of wrapped audio, so codec edges stay outside
the loop points. Stdlib, numpy and ffmpeg only; one file, so `python -I` can run it.
"""
import argparse
import atexit
import concurrent.futures as futures
import json
import os
import pathlib
import re
import resource
import shutil
import subprocess
import sys
import tempfile

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
SR = 48000
RATE = 22050
HOP = 256
WINDOW = 1024
ENV_RATE = RATE / HOP
MAX_DECODED_PEAK_DB = -0.3
# The forge has 12 GB, shared with other agents, and a stall there freezes everyone. A build
# at 12 workers took 11 GB and held the forge for 20 minutes on 2026-11-07. So one worker by
# default, two at most, a limit per process that fails instead of stalling, and no start
# while the machine is already busy.
DEFAULT_WORKERS = 1
MAX_WORKERS = 2
PROCESS_LIMIT_BYTES = 4 * 1024 ** 3
BUSY_BYTES = 6 * 10 ** 9
HPSS_CHUNK_SECONDS = 10
TONICS = {"C": 0, "C#": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "Ab": 8, "A": 9, "Bb": 10, "B": 11}
MAJOR = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
MINOR = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])


# ---------------------------------------------------------------- audio in and out

def decode(path, rate=SR, channels=2):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-map_metadata", "-1", "-ac", str(channels),
         "-ar", str(rate), "-f", "f32le", "-"], check=True, stdout=subprocess.PIPE).stdout
    data = np.frombuffer(raw, dtype=np.float32).astype(np.float64)
    return data.reshape(-1, channels) if channels > 1 else data


def _pipe(audio):
    return np.clip(audio, -4, 4).astype(np.float32).tobytes()


def loudness(audio):
    """Integrated LUFS, LRA and true peak from ffmpeg's ebur128."""
    run = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
         "-af", "ebur128=peak=true", "-f", "null", "-"],
        input=_pipe(audio), stderr=subprocess.PIPE, stdout=subprocess.DEVNULL, check=True)
    tail = run.stderr.decode(errors="replace").split("Summary:")[-1]
    grab = lambda key: float(re.search(key + r":\s+(-?[\d.]+|-?inf)", tail).group(1))
    return {"lufs": grab("I"), "lra": grab("LRA"), "truePeakDb": grab("Peak")}


def codec_peak(audio, cfg):
    """The higher true peak of the two formats, once encoded and decoded."""
    with tempfile.TemporaryDirectory() as tmp:
        files = encode(audio, pathlib.Path(tmp) / "probe", cfg)
        return max(loudness(decode(p))["truePeakDb"] for p in files.values())


def encode(audio, base, cfg):
    """Both formats, without the master's metadata, repeatably."""
    base.parent.mkdir(parents=True, exist_ok=True)
    common = ["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
              "-map_metadata", "-1", "-fflags", "+bitexact", "-flags", "+bitexact"]
    opus, aac = base.with_suffix(".ogg"), base.with_suffix(".m4a")
    # Written beside the target and renamed, so a killed build can't leave half a file.
    part_opus, part_aac = base.with_name(base.name + ".part.ogg"), base.with_name(base.name + ".part.m4a")
    subprocess.run(common + ["-c:a", "libopus", "-b:a", f"{cfg['encode']['opusKbps']}k", "-vbr", "on",
                             "-application", "audio", str(part_opus)], input=_pipe(audio), check=True)
    subprocess.run(common + ["-c:a", "aac", "-b:a", f"{cfg['encode']['aacKbps']}k",
                             "-movflags", "+faststart", str(part_aac)], input=_pipe(audio), check=True)
    os.replace(part_opus, opus)
    os.replace(part_aac, aac)
    return {"opus": opus, "aac": aac}


# ---------------------------------------------------------------- beat measurement

def onset_envelope(mono):
    count = (len(mono) - WINDOW) // HOP
    if count < 2:
        raise ValueError("take is too short to measure")
    window = np.hanning(WINDOW)
    env = np.zeros(count)
    previous = None
    # In batches: a whole take's frames at once cost hundreds of MB for one sum per frame.
    for at in range(0, count, 1024):
        idx = np.arange(WINDOW) + HOP * np.arange(at, min(at + 1024, count))[:, None]
        spec = np.log1p(100.0 * np.abs(np.fft.rfft(mono[idx] * window, axis=1)))
        if previous is not None:
            spec = np.vstack([previous, spec])
        flux = np.maximum(spec[1:] - spec[:-1], 0.0).sum(axis=1)
        env[at + idx.shape[0] - len(flux):at + idx.shape[0]] = flux
        previous = spec[-1:]
    size = int(ENV_RATE)
    trend = np.convolve(env, np.ones(size) / size, mode="same")
    return np.maximum(env - trend, 0.0)


def env_times(count):
    return (np.arange(count) - 0.5) * HOP / RATE + WINDOW / 2 / RATE


def fit_tempo(env, target, span_pct=3.0):
    t = env_times(len(env))
    grid = target * (1 + np.linspace(-span_pct, span_pct, 601) / 100)
    power = np.array([abs(np.exp(-2j * np.pi * g / 60 * t) @ env) for g in grid])
    i = int(np.argmax(power))
    bpm = grid[i]
    if 0 < i < len(grid) - 1:
        a, b, c = power[i - 1:i + 2]
        bpm += 0.5 * (a - c) / (a - 2 * b + c) * (grid[1] - grid[0])
    return float(bpm)


def _attack_curve(mono):
    """A fine, uncompressed energy rise: it places the grid on the attacks, without
    the lead a log spectrum gets from a window's edge reaching a hit early."""
    size, step = 128, 32
    energy = np.sqrt(np.convolve(mono ** 2, np.ones(size) / size, mode="same")[::step])
    rise = np.maximum(np.diff(energy, prepend=energy[0]), 0.0)
    return rise, step / RATE


def _track_offsets(env, t, line, period):
    """The likeliest path of beat offsets around a straight line: Viterbi over local
    comb scores, so a noisy phrase can't slip the phase the way unwrapping can."""
    smooth = np.convolve(env, np.hanning(7) / 3.0, mode="same")
    offsets = np.arange(-0.15, 0.1501, 0.003)
    score = np.stack([np.interp(line + o, t, smooth, left=0, right=0) for o in offsets], axis=1)
    kernel = np.hanning(11)[1:-1]
    score = np.apply_along_axis(lambda c: np.convolve(c, kernel, "same"), 0, score)
    score /= max(score.mean(), 1e-9)
    total = score[0].copy()
    back = np.zeros(score.shape, dtype=int)
    reach = 3
    steps = np.arange(-reach, reach + 1)
    cost = 0.15 * steps ** 2 * (0.003 / 0.003)
    for n in range(1, len(score)):
        options = np.stack([np.roll(total, s) - c for s, c in zip(steps, cost)], axis=0)
        # np.roll wraps round the ends; a path can't leave the search range that way.
        for i, s_ in enumerate(steps):
            if s_ > 0:
                options[i, :s_] = -np.inf
            elif s_ < 0:
                options[i, s_:] = -np.inf
        pick = np.argmax(options, axis=0)
        total = options[pick, np.arange(len(total))] + score[n]
        back[n] = np.arange(len(total)) - steps[pick]
    j = int(np.argmax(total))
    path = np.zeros(len(score), dtype=int)
    for n in range(len(score) - 1, -1, -1):
        path[n] = j
        j = int(np.clip(back[n, j], 0, len(offsets) - 1))
    weight = score[np.arange(len(score)), path]
    return offsets[path], weight


def _smooth_curve(values, weight, period, max_slope=0.0075):
    """A weighted second-difference smoother, stiffened until the warp it asks for
    stays within max_slope of the take's own tempo."""
    n = len(values)
    w = np.maximum(weight, 1e-3)
    d2 = np.zeros((n - 2, n))
    for i in range(n - 2):
        d2[i, i:i + 3] = (1, -2, 1)
    penalty = d2.T @ d2
    stiffness = 50.0
    for _ in range(12):
        curve = np.linalg.solve(np.diag(w) + stiffness * penalty, w * values)
        if np.max(np.abs(np.diff(curve))) / period <= max_slope:
            return curve
        stiffness *= 4
    return curve


def phase_wander_ms(env, bpm, window_beats=16):
    """Phase wander by per-window fundamental phase around a straight line. Separate
    from the tracker, so it can check what the tracker did."""
    size = int(window_beats * 60.0 / bpm * ENV_RATE)
    t = env_times(len(env))
    freq = bpm / 60.0
    phases, centres = [], []
    for start in range(0, len(env) - size + 1, size // 2):
        phases.append(np.angle(np.sum(env[start:start + size] * np.exp(-2j * np.pi * freq * t[start:start + size]))))
        centres.append(t[start:start + size].mean())
    if len(phases) < 3:
        return 0.0
    unwrapped = np.unwrap(phases)
    fit = np.polyval(np.polyfit(centres, unwrapped, 1), centres)
    return float(np.sqrt(np.mean((unwrapped - fit) ** 2)) / (2 * np.pi * freq) * 1000)


def grid_error_ms(mono, beats):
    """How far real attacks sit from given beat times. For each beat, the strongest rise
    within 50 ms; then the median of each 16-beat block, so a block's value is the
    beat's position, not one stray hit. Returns the typical and the worst block."""
    curve, step = _attack_curve(mono)
    reach = int(0.05 / step)
    found = []
    for beat in beats:
        at = int(beat / step)
        low, high = max(at - reach, 0), min(at + reach + 1, len(curve))
        if high > low:
            found.append((low + int(np.argmax(curve[low:high]))) * step - beat)
    found = np.array(found)
    blocks = [np.median(found[i:i + 16]) for i in range(0, max(len(found) - 15, 1), 8)]
    return round(float(np.median(np.abs(found)) * 1000), 2), round(float(np.max(np.abs(blocks)) * 1000), 2)


def grid_bias_seconds(mono, beats):
    """The median offset from these beats to the attacks nearest them."""
    curve, step = _attack_curve(mono)
    reach = int(0.05 / step)
    found = []
    for beat in beats:
        at = int(beat / step)
        low, high = max(at - reach, 0), min(at + reach + 1, len(curve))
        if high > low:
            found.append((low + int(np.argmax(curve[low:high]))) * step - beat)
    return float(np.median(found))


def beat_times(mono, target):
    """Measured beats: a straight fit, then the slow wander around it."""
    env = onset_envelope(mono)
    bpm = fit_tempo(env, target)
    period = 60.0 / bpm
    t = env_times(len(env))
    duration = len(mono) / RATE
    start = float(np.angle(np.sum(env * np.exp(-2j * np.pi * t / period))) / (2 * np.pi) * period) % period
    line = start + np.arange(int(duration / period) + 2) * period
    offset, weight = _track_offsets(env, t, line, period)
    smooth = _smooth_curve(offset, weight, period)

    # Place the whole curve on the attacks: one constant, searched over a beat.
    rise_curve, step = _attack_curve(mono)
    def comb(shift):
        where = ((line + smooth + shift) / step).astype(int)
        where = where[(where >= 0) & (where < len(rise_curve))]
        return float(np.mean(rise_curve[where]))
    shifts = np.arange(-0.5, 0.5, 0.001) * period
    beats = line + smooth + shifts[int(np.argmax([comb(x) for x in shifts]))]
    beats = beats[(beats >= 0) & (beats + period <= duration)]
    return beats, bpm, phase_wander_ms(env, bpm)


def wsola(audio, in_at, out_len, frame=1920, drift=192):
    """Waveform-similarity overlap-add. in_at maps output sample positions to input
    positions. The natural continuation is kept while it stays within `drift` of the
    map (4 ms, or half as much again during an attack, so hits aren't spliced), then one
    splice inside +-drift brings it back past the map, so the slow creep that follows
    stays centred. Stereo shares each decision, which keeps the image."""
    hop = frame // 2
    edge = frame + 2 * drift + hop
    padded = np.vstack([np.zeros((edge, 2)), audio, np.zeros((edge, 2))])
    mono = padded.mean(axis=1)
    window = 0.5 - 0.5 * np.cos(2 * np.pi * np.arange(frame) / frame)
    out = np.zeros((out_len + 2 * frame, 2))
    energy = np.concatenate([[0.0], np.cumsum(mono ** 2)])
    size = 2 * drift + frame
    nfft = 1 << int(np.ceil(np.log2(size + frame)))
    splices = 0
    prev = None
    last = len(mono) - size - 1
    offsets = np.arange(2 * drift + 1)
    for o in range(0, out_len + hop, hop):
        want = int(np.clip(int(round(float(in_at(o)))) + edge, drift, last))
        chosen = want
        if prev is not None:
            natural = min(prev + hop, last)
            mid = natural + hop
            attack = energy[natural + frame] - energy[mid] > 2.0 * (energy[mid] - energy[max(natural - hop, 0)])
            if abs(natural - want) <= (drift * 3 // 2 if attack else drift):
                chosen = natural
            else:
                low = want - drift
                ref = mono[natural:natural + frame]
                seg = mono[low:low + size]
                xc = np.fft.irfft(np.fft.rfft(seg, nfft) * np.conj(np.fft.rfft(ref, nfft)), nfft)[:2 * drift + 1]
                seg_energy = energy[low + frame:low + frame + 2 * drift + 1] - energy[low:low + 2 * drift + 1]
                ncc = xc / np.sqrt(np.maximum(seg_energy * np.sum(ref ** 2), 1e-12))
                # Only the far side of the map: the near edge always correlates best, and
                # choosing it would splice again on the next frame.
                far = offsets > drift if want > natural else offsets < drift
                chosen = low + int(offsets[far][np.argmax(ncc[far])])
                splices += 1
        out[o:o + frame] += padded[chosen:chosen + frame] * window[:, None]
        prev = chosen
    return out[:out_len], splices


def stretch_linear(audio, out_len):
    ratio = len(audio) / max(out_len, 1)
    return wsola(audio, lambda o: o * ratio, out_len)[0]


# ---------------------------------------------------------------- what the grid holds

def beat_features(mono, beat_seconds, beats):
    """Per beat: low-band attack, chroma and coarse band energy, on an exact grid."""
    size, step = 4096, 512
    count = (len(mono) - size) // step
    window = np.hanning(size)
    freq = np.fft.rfftfreq(size, 1 / RATE)
    tone = (freq >= 80) & (freq <= 2000)
    pc = np.mod(np.round(12 * np.log2(freq[tone] / 261.626)).astype(int), 12)
    edges = np.geomspace(60, 10000, 13)
    chroma_frames, bands, low = np.zeros((count, 12)), np.zeros((count, 12)), np.zeros(count)
    # In batches, each frame reduced to these 25 numbers: whole spectrograms took a gigabyte.
    for at in range(0, count, 256):
        rows = np.arange(at, min(at + 256, count))
        idx = np.arange(size) + step * rows[:, None]
        mag = np.abs(np.fft.rfft(mono[idx] * window, axis=1))
        part = np.zeros((len(rows), 12))
        np.add.at(part.T, pc, (mag[:, tone] ** 2).T)
        chroma_frames[rows] = part
        bands[rows] = np.stack([np.log1p((mag[:, (freq >= a) & (freq < b)] ** 2).sum(axis=1))
                                for a, b in zip(edges[:-1], edges[1:])], axis=1)
        low[rows] = np.sqrt((mag[:, freq < 180] ** 2).sum(axis=1))
    low_rise = np.maximum(np.diff(low, prepend=low[0]), 0.0)
    frame_at = (np.arange(beats + 1) * beat_seconds * RATE - size / 2) / step
    frame_at = np.clip(frame_at.astype(int), 0, count)
    chroma, band, attack = np.zeros((beats, 12)), np.zeros((beats, 12)), np.zeros(beats)
    for b in range(beats):
        a, z = frame_at[b], max(frame_at[b + 1], frame_at[b] + 1)
        chroma[b] = chroma_frames[a:z].sum(axis=0)
        band[b] = bands[a:z].mean(axis=0) if z <= count and a < count else 0
        near = low_rise[max(a - 2, 0):a + 4]
        attack[b] = near.max() if len(near) else 0
    return chroma, band, attack


def _unit(v, axis=-1):
    return v / np.maximum(np.linalg.norm(v, axis=axis, keepdims=True), 1e-9)


def find_bar_one(chroma, attack, beats_per_bar=4):
    """Which beat is bar one: bass attacks and chord changes, voted over 8-bar blocks.
    Confidence is the share of blocks that agree with the whole take's answer, scaled
    down when the winner barely beats the runner-up."""
    n = len(attack)
    unit = _unit(chroma)
    change = np.zeros(n)
    for b in range(2, n - 2):
        change[b] = 1 - float(_unit(unit[b - 2:b].sum(axis=0)) @ _unit(unit[b:b + 2].sum(axis=0)))
    def score(lo, hi):
        result = np.zeros(beats_per_bar)
        for p in range(beats_per_bar):
            pick = [b for b in range(lo, hi) if b % beats_per_bar == p]
            result[p] = 1.0 * np.mean(attack[pick]) / max(np.mean(attack[lo:hi]), 1e-9) \
                + 2.0 * np.mean(change[pick]) / max(np.mean(change[lo:hi]), 1e-9)
        return result
    whole = score(0, n)
    best = int(np.argmax(whole))
    size = 8 * beats_per_bar
    blocks = [int(np.argmax(score(lo, lo + size))) for lo in range(0, max(n - size, 1), size // 2)]
    agree = float(np.mean([b == best for b in blocks])) if blocks else 0.0
    ordered = np.sort(whole)
    margin = float((ordered[-1] - ordered[-2]) / ordered[-1])
    # Both must hold: blocks agreeing, and the winner standing clear of the runner-up.
    return best, round(agree * min(margin / 0.15, 1.0), 2), round(margin, 3)


def measure_key(chroma):
    total = chroma.sum(axis=0)
    best = (-2.0, 0, "")
    names = list(TONICS)
    for i, name in enumerate(names):
        for mode, profile in (("major", MAJOR), ("minor", MINOR)):
            r = float(np.corrcoef(total, np.roll(profile, TONICS[name]))[0, 1])
            if r > best[0]:
                best = (r, i, f"{name} {mode}")
    return best[2], round(best[0], 3)


def tonic_template(key):
    name, mode = key.split()
    t = np.zeros(12)
    root = TONICS[name]
    for step, weight in ((0, 1.0), (3 if mode == "minor" else 4, 0.8), (7, 0.8)):
        t[(root + step) % 12] = weight
    return _unit(t)


def choose_loop(bar_chroma, bar_band, bar_rms, loop_bars):
    """The start bar whose continuation past the loop's end most resembles its head."""
    total = len(bar_rms)
    if total < loop_bars + 1:
        raise ValueError(f"take has {total} bars, needs {loop_bars + 1}")
    floor = np.median(bar_rms) * 0.5
    chroma, band = _unit(bar_chroma), _unit(bar_band - bar_band.mean(axis=0))
    rows = []
    for start in range(0, total - loop_bars):
        end = start + loop_bars
        pairs = [(start, end)] + ([(start + 1, end + 1)] if end + 1 < total else []) \
            + ([(start - 1, end - 1)] if start > 0 else [])
        harmony = np.mean([chroma[a] @ chroma[b] for a, b in pairs])
        texture = np.mean([band[a] @ band[b] for a, b in pairs])
        level = 1 - min(abs(np.log2(max(bar_rms[start], 1e-6) / max(bar_rms[end], 1e-6))), 1)
        quiet = float(np.mean(bar_rms[start:end] < floor))
        rows.append((float(harmony + 0.5 * texture + 0.5 * level - 2.0 * quiet), start,
                     float(harmony), float(texture), quiet))
    best = max(rows)
    return {"startBar": best[1], "score": round(best[0], 3), "harmony": round(best[2], 3),
            "texture": round(best[3], 3), "quietShare": round(best[4], 3),
            "candidates": len(rows)}


# ---------------------------------------------------------------- level and limiting

def shelf_eq(audio, bands):
    if not bands:
        return audio
    spec = np.fft.rfft(audio, axis=0)
    freq = np.maximum(np.fft.rfftfreq(len(audio), 1 / SR), 1.0)
    db = np.zeros(len(freq))
    for band in bands:
        rise = 1 / (1 + np.exp(-4 * np.log2(freq / band["freq"])))
        db += band["gain"] * (rise if band["type"] == "highshelf" else 1 - rise)
    return np.fft.irfft(spec * (10 ** (db / 20))[:, None], len(audio), axis=0)


def sliding_min(values, half, circular):
    """van Herk's running minimum over 2*half+1 samples, centred."""
    size = 2 * half + 1
    n = len(values)
    data = np.concatenate([values[-half:], values, values[:half]]) if circular \
        else np.concatenate([np.ones(half), values, np.ones(half)])
    extra = (-len(data)) % size
    full = np.concatenate([data, np.ones(extra)]).reshape(-1, size)
    forward = np.minimum.accumulate(full, axis=1).ravel()
    backward = np.minimum.accumulate(full[:, ::-1], axis=1)[:, ::-1].ravel()
    result = np.minimum(backward[:len(data) - size + 1], forward[size - 1:len(data)])
    return result[:n]


def limit(audio, ceiling_db, circular=False, half_ms=8.0):
    """A look-ahead peak limiter. Holding the needed gain over the same span the Hann
    smoother reads means the smoothed gain never exceeds what any sample needs."""
    ceiling = 10 ** (ceiling_db / 20)
    peak = np.max(np.abs(audio), axis=1)
    if peak.max() <= ceiling:
        return audio, {"maxReductionDb": 0.0, "limitedShare": 0.0}
    half = int(SR * half_ms / 1000)
    need = np.minimum(1.0, ceiling / np.maximum(peak, 1e-12))
    held = sliding_min(need, half, circular)
    kernel = np.hanning(2 * half + 3)[1:-1]
    kernel /= kernel.sum()
    padded = np.concatenate([held[-half:], held, held[:half]]) if circular \
        else np.concatenate([np.ones(half), held, np.ones(half)])
    gain = np.convolve(padded, kernel, mode="valid")[:len(held)]
    gain = np.minimum(gain, held)
    return audio * gain[:, None], {
        "maxReductionDb": round(float(-20 * np.log10(gain.min())), 2),
        "limitedShare": round(float(np.mean(gain < 0.999)), 4)}


def master_loop(loop, target, ceiling_db):
    """Gain to the target, measured through the limiter; a few rounds settle it."""
    gain_db = target - loudness(np.vstack([loop, loop]))["lufs"]
    for _ in range(5):
        out, stats = limit(loop * 10 ** (gain_db / 20), ceiling_db, circular=True)
        measured = loudness(np.vstack([out, out]))
        if abs(measured["lufs"] - target) <= 0.05:
            break
        gain_db += target - measured["lufs"]
    return out, gain_db, stats, measured


# ---------------------------------------------------------------- separation for joins

def hpss(audio, nfft=2048, hop=512, width=17):
    """Harmonic and percussive parts by median masks, a block at a time, as the median
    filters of a whole take want gigabytes. Blocks crossfade, and the percussive part is
    the remainder, so the two parts still sum back to the input."""
    block = HPSS_CHUNK_SECONDS * SR
    if len(audio) <= block * 3 // 2:
        return _hpss_block(audio, nfft, hop, width)
    overlap = SR
    harmonic = np.zeros_like(audio)
    weight = np.zeros(len(audio))
    ramp = (np.arange(overlap) + 0.5) / overlap
    for start in range(0, len(audio), block - overlap):
        stop = min(start + block, len(audio))
        part = _hpss_block(audio[start:stop], nfft, hop, width)[0]
        shape = np.ones(stop - start)
        if start > 0:
            shape[:overlap] = ramp
        if stop < len(audio):
            shape[-overlap:] = ramp[::-1]
        harmonic[start:stop] += part * shape[:, None]
        weight[start:stop] += shape
        if stop == len(audio):
            break
    harmonic /= np.maximum(weight, 1e-9)[:, None]
    return harmonic, audio - harmonic


def _hpss_block(audio, nfft, hop, width):
    window = np.hanning(nfft + 1)[:-1]
    pad = np.vstack([np.zeros((nfft, 2)), audio, np.zeros((nfft, 2))])
    count = (len(pad) - nfft) // hop + 1
    idx = np.arange(nfft) + hop * np.arange(count)[:, None]
    specs = np.fft.rfft(pad[idx] * window[None, :, None], axis=1)
    mag = np.abs(specs).sum(axis=2)
    half = width // 2
    view = np.lib.stride_tricks.sliding_window_view
    along_time = np.median(view(np.pad(mag, ((half, half), (0, 0)), mode="edge"), width, axis=0), axis=-1)
    along_freq = np.median(view(np.pad(mag, ((0, 0), (half, half)), mode="edge"), width, axis=1), axis=-1)
    mask = along_time ** 2 / np.maximum(along_time ** 2 + along_freq ** 2, 1e-12)
    def invert(spec):
        frames = np.fft.irfft(spec, nfft, axis=1) * window[None, :, None]
        out = np.zeros_like(pad)
        norm = np.zeros(len(pad))
        for i in range(count):
            out[i * hop:i * hop + nfft] += frames[i]
            norm[i * hop:i * hop + nfft] += window ** 2
        return (out / np.maximum(norm, 1e-6)[:, None])[nfft:nfft + len(audio)]
    harmonic = invert(specs * mask[:, :, None])
    return harmonic, audio - harmonic


def rise(n, beat_len, start, end):
    """A raised-cosine ramp from 0 to 1 between two beats; n counts from asset start."""
    x = np.clip((np.arange(n) / beat_len - start) / max(end - start, 1e-9), 0, 1)
    return (0.5 - 0.5 * np.cos(np.pi * x))[:, None]


def circ(loop, start, count):
    return loop[np.mod(np.arange(start, start + count), len(loop))]


# ---------------------------------------------------------------- the Rust engine

# tool/music/mixrs does the prepare, render and verify measuring without holding spectrograms.
# The Python below stays as the reference it's compared against (mixrs/compare/compare.py),
# and as the fallback when cargo isn't there. MIX_ENGINE=python chooses it.
_mixrs_path = False
_work = None


def find_mixrs():
    """The built binary, or None for the Python engine. Cargo does nothing if it's current."""
    global _mixrs_path
    if _mixrs_path is not False:
        return _mixrs_path
    _mixrs_path = None
    if os.environ.get("MIX_ENGINE") == "python":
        return None
    if os.environ.get("MIXRS"):
        _mixrs_path = os.environ["MIXRS"]
        return _mixrs_path
    if shutil.which("cargo"):
        target = pathlib.Path(os.environ.get("CARGO_TARGET_DIR") or "~/.cache/tillandsias-project/cargo/target").expanduser()
        env = {**os.environ, "CARGO_TARGET_DIR": str(target)}
        built = subprocess.run(["cargo", "build", "--release", "--quiet", "-j", "4", "--manifest-path",
                                str(HERE.parent / "mixrs" / "Cargo.toml")], env=env)
        if built.returncode == 0:
            _mixrs_path = str(target / "release" / "mixrs")
            return _mixrs_path
    print("mixrs isn't available: using the Python engine, one worker", file=sys.stderr, flush=True)
    return None


def _rs(*args):
    done = subprocess.run([find_mixrs(), *map(str, args)], check=True, stdout=subprocess.PIPE)
    return json.loads(done.stdout)


def _work_dir():
    """Tiers wait on the cache disk, not in memory. /home/forge/src is a small tmpfs."""
    global _work
    if _work is None:
        base = pathlib.Path("~/.cache/tillandsias-project/mixrs-work").expanduser()
        base.mkdir(parents=True, exist_ok=True)
        _work = pathlib.Path(tempfile.mkdtemp(dir=base))
        atexit.register(_clear_work)
    return _work


def _clear_work():
    global _work
    if _work is not None:
        shutil.rmtree(_work, ignore_errors=True)
        _work = None


def _rs_cfg(cfg):
    cfg = {k: v for k, v in cfg.items() if k != "levels"}
    cfg["mastersDir"] = str(pathlib.Path(cfg["mastersDir"]).expanduser())
    return cfg


def _rs_job(cfg):
    path = _work_dir() / "cfg.json"
    if not path.exists():
        path.write_text(json.dumps({"cfg": _rs_cfg(cfg)}))
    return path


def _rs_raw(path):
    return np.memmap(path, dtype=np.float32, mode="r").reshape(-1, 2)


def _rs_prepare(cfg, level, tier, follow):
    out = _work_dir() / level["id"] / tier["name"]
    out.mkdir(parents=True, exist_ok=True)
    job = out / "job.json"
    job.write_text(json.dumps({"cfg": _rs_cfg(cfg), "level": {k: v for k, v in level.items() if k != "tiers"},
                               "tier": tier, "follow": follow}))
    try:
        data = _rs("prepare", "--job", job, "--out", out)
    except subprocess.CalledProcessError as failed:
        raise ValueError(f"{level['id']}/{tier['name']}: mixrs prepare failed ({failed.returncode})") from failed
    data["dir"] = str(out)
    data["loop"] = _rs_raw(out / "loop.f32")
    for key in ("barChroma", "allBarChroma", "barRms"):
        data[key] = np.array(data[key])
    return data


def _rs_render(command, cfg, *args):
    out = _work_dir() / f"segment-{next(tempfile._get_candidate_names())}.f32"
    info = _rs(command, *args, "--job", _rs_job(cfg), "--out", out)
    info.pop("samples", None)
    return _rs_raw(out), info


def _rs_write_asset(audio, base, cfg):
    work = _work_dir()
    if isinstance(audio, np.memmap) and audio.filename and audio.size * 4 == os.path.getsize(audio.filename):
        raw = pathlib.Path(audio.filename)
    else:
        raw = work / f"asset-{next(tempfile._get_candidate_names())}.f32"
        np.asarray(audio, dtype=np.float32).tofile(raw)
    got = _rs("write-asset", "--audio", raw, "--base", base, "--job", _rs_job(cfg), "--scratch", work / "scratch")
    raw.unlink(missing_ok=True)
    return {"opus": pathlib.Path(got["opus"]), "aac": pathlib.Path(got["aac"])}, got["offsets"]


# ---------------------------------------------------------------- one tier

def beat_samples(bpm):
    return 60.0 * SR / bpm


def prepare_tier(args):
    """Master to grid to chosen loop, mastered. Runs in a worker process. With `follow`,
    the take is another layer of one performance: it takes the parent's beat map, bar one
    and loop, so the layers stay sample-aligned."""
    cfg, level, tier, *rest = args
    follow = rest[0] if rest else None
    if find_mixrs():
        return _rs_prepare(cfg, level, tier, follow)
    path = pathlib.Path(cfg["mastersDir"]).expanduser() / tier["source"]
    audio = decode(path)
    for extra in tier.get("layer") or []:
        # Another take of the same performance, sample-aligned: its percussion can sit
        # under a re-sampled layer, which keeps the parent's attacks.
        other = decode(pathlib.Path(cfg["mastersDir"]).expanduser() / extra["source"])[:len(audio)]
        harmonic, percussive = hpss(other)
        part = percussive if extra.get("part") == "percussive" else harmonic
        audio[:len(part)] += part * 10 ** (extra.get("db", 0) / 20)
    mono = decode(path, RATE, 1)
    target = float(tier["bpm"])
    beats, measured, wander = beat_times(mono, target)
    error_pct = (measured - target) / target * 100
    report = {"source": tier["source"], "targetBpm": target, "measuredBpm": round(measured, 3),
              "errorPct": round(error_pct, 3), "wanderMs": round(wander, 2)}
    timing = path.with_suffix(".timing.json")
    if timing.exists():
        report["timingFileBpm"] = json.loads(timing.read_text())[path.name]["measured_bpm"]
    report["corrected"] = abs(error_pct) <= cfg["maxCorrectionPct"]
    if follow:
        report["followsGridOf"] = follow["name"]
        # A tier pre-stretched with rubberband from the followed take: its beats sit
        # at the followed beats times the stretch (output over input duration).
        scale = tier.get("followScale", 1.0)
        beats, measured = np.asarray(follow["beats"]) * scale, follow["measured"] / scale
        report["followScale"] = scale
    elif not report["corrected"]:
        raise ValueError(f"{level['id']}/{tier['name']}: {error_pct:+.2f}% is past the "
                         f"{cfg['maxCorrectionPct']}% allowed, not corrected")

    beat_len = beat_samples(target)
    out_len = int(round(len(beats) * beat_len))
    out_beats = np.arange(len(beats)) * beat_len
    in_beats = beats * SR
    rates = np.diff(in_beats) / beat_len
    report["maxLocalStretchPct"] = round(float(np.max(np.abs(rates - 1)) * 100), 2)
    # Past the last measured beat the warp keeps the last beat's rate, for the tail.
    slope = rates[-1]
    def in_at(o):
        if o <= out_beats[-1]:
            return np.interp(o, out_beats, in_beats)
        return in_beats[-1] + (o - out_beats[-1]) * slope
    grid, splices = wsola(audio, in_at, out_len)
    report["splices"] = splices
    grid = shelf_eq(grid, tier.get("eq") or [])

    grid_mono = grid.mean(axis=1)
    if SR != RATE:
        grid_mono = np.interp(np.arange(int(len(grid) * RATE / SR)) * SR / RATE, np.arange(len(grid)), grid_mono)
    env = onset_envelope(grid_mono)
    after = fit_tempo(env, target, 1.0)
    report["bpmAfterWarp"] = round(after, 3)
    report["wanderAfterMs"] = round(phase_wander_ms(env, target), 2)
    # The same test on the raw take's straight line and on the warped grid.
    straight = beats[0] + np.arange(len(beats)) * 60.0 / measured
    report["gridErrorBeforeMs"] = dict(zip(("typical", "worstBlock"), grid_error_ms(mono, straight)))
    report["gridErrorAfterMs"] = dict(zip(("typical", "worstBlock"),
                                          grid_error_ms(grid_mono, np.arange(len(beats)) * beat_len / SR)))

    beat_seconds = beat_len / SR
    chroma, band, attack = beat_features(grid_mono, beat_seconds, len(beats))
    first, confidence, margin = find_bar_one(chroma, attack)
    if follow:
        first, confidence, margin = follow["first"], follow["confidence"], follow["margin"]
    report.update(bar1Beat=first, bar1Seconds=round(float(beats[first]), 3),
                  bar1Confidence=confidence, bar1Margin=margin)
    key, key_r = measure_key(chroma)
    report.update(measuredKey=key, keyCorrelation=key_r, askedKey=level["key"])

    total_bars = (len(beats) - first) // 4 - 1
    bar_chroma = np.stack([chroma[first + 4 * b:first + 4 * b + 4].sum(axis=0) for b in range(total_bars)])
    bar_band = np.stack([band[first + 4 * b:first + 4 * b + 4].mean(axis=0) for b in range(total_bars)])
    bar_len = 4 * beat_len
    # One constant for the take: the grid's beats sit on the median attack.
    bias = follow["bias"] if follow else grid_bias_seconds(grid_mono, np.arange(len(beats)) * beat_seconds)
    report["beatBiasMs"] = round(bias * 1000, 2)
    report["gridErrorAfterMs"] = dict(zip(("typical", "worstBlock"), grid_error_ms(
        grid_mono, np.arange(len(beats)) * beat_seconds + bias)))
    origin = first * beat_len + bias * SR
    if origin < 0:  # A bar one before the audio starts: take the next one.
        origin += 4 * beat_len
    def bar_at(b):
        return int(round(origin + b * bar_len))
    bar_rms = np.array([np.sqrt(np.mean(grid[bar_at(b):bar_at(b + 1)] ** 2)) for b in range(total_bars)])
    bars = int(tier["loopBars"])
    choice = follow["loop"] if follow else choose_loop(bar_chroma, bar_band, bar_rms, bars)
    report["loop"] = choice
    report["totalBars"] = total_bars

    start = bar_at(choice["startBar"])
    length = int(round(bars * bar_len))
    fade = int(round(cfg["seamFadeBeats"] * beat_len))
    fade = min(fade, len(grid) - (start + length))
    loop = grid[start:start + length].copy()
    follow = grid[start + length:start + length + fade]
    head = loop[:fade]
    corr = float(np.sum(follow * head) / max(np.sqrt(np.sum(follow ** 2) * np.sum(head ** 2)), 1e-12))
    x = (np.arange(fade) + 0.5) / fade
    fade_in = np.sin(0.5 * np.pi * x) if abs(corr) < 0.5 else x
    fade_out = np.cos(0.5 * np.pi * x) if abs(corr) < 0.5 else 1 - x
    loop[:fade] = follow * fade_out[:, None] + head * fade_in[:, None]
    report["seamFadeSamples"] = fade
    report["seamCorrelation"] = round(corr, 3)
    loop_bpm = target
    if tier.get("frameSamples"):
        if tier["frameSamples"] != len(loop):
            report["frameStretchPct"] = round((tier["frameSamples"] / len(loop) - 1) * 100, 4)
            loop = resample_circular(loop, tier["frameSamples"])
        loop_bpm = bars * 4 * 60.0 * SR / tier["frameSamples"]

    # The codecs overshoot what they're given, AAC by up to 3 dB here, so the ceiling
    # that counts is measured on the decoded files; lower it until they clear.
    ceiling = cfg["ceilingDb"]
    pad = int(round(cfg["padSeconds"] * SR))
    for _ in range(5):
        mastered, gain_db, stats, measured_level = master_loop(loop, tier["targetLufs"], ceiling)
        worst = codec_peak(np.vstack([mastered[-pad:], mastered, mastered[:pad]]), cfg)
        if worst <= MAX_DECODED_PEAK_DB:
            break
        ceiling -= worst - MAX_DECODED_PEAK_DB + 0.2
    report.update(makeupDb=round(gain_db, 2), limiter=stats, ceilingDb=round(ceiling, 2),
                  decodedPeakDb=worst, **{k: measured_level[k] for k in measured_level})

    loop_chroma = bar_chroma[choice["startBar"]:choice["startBar"] + bars]
    return {"level": level["id"], "name": tier["name"], "bpm": target, "loopBpm": loop_bpm, "bars": bars, "loop": mastered,
            "barChroma": loop_chroma, "gainDb": gain_db, "grid": (grid * 10 ** (gain_db / 20)).astype(np.float32),
            "firstBarSample": first * beat_len, "barLen": bar_len, "beatLen": beat_len,
            "allBarChroma": bar_chroma, "barRms": bar_rms, "report": report,
            "follow": {"name": tier["name"], "beats": beats, "measured": measured, "first": first,
                       "confidence": confidence, "margin": margin, "bias": bias, "loop": choice}}


# ---------------------------------------------------------------- joins and exits

def head_mismatch_db(decoded, pad, n, k=480):
    """How far the two codings of a loop's head disagree, in dB under the signal: the
    decoded file holds loop[0] at pad (after the pre-pad) and at pad + n (after the loop),
    and the game jumps from just before the second to the first at every wrap."""
    first, second = decoded[pad:pad + k], decoded[pad + n:pad + n + k]
    level = lambda v: 20 * np.log10(np.sqrt(np.mean(v ** 2)) + 1e-12)
    return level(first - second) - level(second)


def write_take(loop, base, cfg, root):
    """Encode a take as loop[-pad:] + loop + loop[:pad]. The two codings of loop[0] agree
    only once the Opus encoder has settled, and where it settles changes with the pad
    (salon's low: -33 dB at 12000, -102 dB at 13440; garden's low the other way round,
    2026-11-10), so each of `padChoicesSamples` is tried in turn and the one whose codings
    agree best is kept. Returns the written entry, the offsets, the pad and the choice."""
    choices = cfg.get("padChoicesSamples") or [int(round(cfg["padSeconds"] * SR))]
    tried, best = {}, None
    for pad in choices:
        written, offsets = write_asset(np.vstack([loop[-pad:], loop, loop[:pad]]), base, cfg, root)
        # The offset can be negative (billiards' low decodes a sample early), so it moves
        # where the heads are read rather than slicing the decoded file.
        decoded = decode(root / written["files"]["opus"])
        tried[pad] = round(float(head_mismatch_db(decoded, pad + offsets.get("opus", 0), len(loop))), 1)
        if not np.isfinite(tried[pad]):
            raise ValueError(f"{base}: the head mismatch at pad {pad} isn't a number")
        if best is None or tried[pad] < tried[best[0]]:
            best = (pad, written, offsets)
        if tried[pad] < -90:
            break
    pad, written, offsets = best
    if pad != list(tried)[-1]:
        written, offsets = write_asset(np.vstack([loop[-pad:], loop, loop[:pad]]), base, cfg, root)
    return written, offsets, pad, {"samples": pad, "headMismatchDb": tried[pad], "tried": tried}


def write_asset(audio, base, cfg, root):
    """Encode, lowering any peak the codecs push too high, then measure where ffmpeg's
    decoder puts the content. The manifest carries an offset only where one exists."""
    if find_mixrs():
        files, offsets = _rs_write_asset(audio, base, cfg)
        entry = {"files": {k: str(v.relative_to(root)) for k, v in files.items()}}
        if any(offsets.values()):
            entry["decodeOffsetSamples"] = {k: v for k, v in offsets.items() if v}
        return entry, offsets
    ceiling = cfg["ceilingDb"]
    for _ in range(5):
        worst = codec_peak(audio, cfg)
        if worst <= MAX_DECODED_PEAK_DB:
            break
        ceiling -= worst - MAX_DECODED_PEAK_DB + 0.2
        audio, _stats = limit(audio, ceiling)
    files = encode(audio, base, cfg)
    entry = {"files": {k: str(v.relative_to(root)) for k, v in files.items()}}
    offsets = {k: decode_offset(audio, decode(v)) for k, v in files.items()}
    if any(offsets.values()):
        entry["decodeOffsetSamples"] = {k: v for k, v in offsets.items() if v}
    return entry, offsets


def segment_bpm_len(bpm, beats):
    return int(round(beats * beat_samples(bpm)))


def outgoing_at(source, bpm_out, beats_out, pad):
    """The source's last loop bar and what follows it, stretched to the new tempo.
    Output sample 0 is the file's first pad sample; the bar starts at pad."""
    bar = int(round(source["barLen"]))
    in_pad = int(round(pad * source["bpm"] / bpm_out)) + 1
    extra = int(round(source["beatLen"] * (beats_out - 4 + 1)))
    raw = circ(source["loop"], len(source["loop"]) - bar - in_pad, in_pad + bar + extra)
    ratio = bpm_out / source["bpm"]
    return stretch_linear(raw, int(round(len(raw) / ratio)))


def best_entry(source_chroma, dest, phase=(2, 0)):
    """The destination bar whose lead-in best matches the given chroma: every even bar, or
    bars offset, offset + step, ... when the next level asks for a phase (`bridgeEntry`)."""
    step, offset = phase
    chroma = _unit(dest["barChroma"])
    count = len(chroma)
    scores = [(float(chroma[(k - 1) % count] @ _unit(source_chroma)), -k) for k in range(offset % count, count, max(1, step))]
    score, k = max(scores)
    return -k, round(score, 3)


def render_transition(source, dest, cfg, pad):
    if source.get("dir"):
        return _rs_render("transition", cfg, "--a", source["dir"], "--b", dest["dir"])
    beats = cfg["transition"]["beats"]
    width = cfg["transition"]["crossfadeBeats"]
    fill = 10 ** (cfg["transition"]["fillDb"] / 20)
    bpm = dest["bpm"]
    beat_len = beat_samples(bpm)
    length = segment_bpm_len(bpm, beats)
    total = pad + length + pad
    entry, match = best_entry(source["barChroma"][-1], dest)
    entry_at = int(round(entry * dest["barLen"]))
    incoming = circ(dest["loop"], entry_at - length - pad, total)
    outgoing = outgoing_at(source, bpm, beats, pad)
    if len(outgoing) < total:
        outgoing = np.vstack([outgoing, np.zeros((total - len(outgoing), 2))])
    outgoing = outgoing[:total]
    out_h, out_p = hpss(outgoing)
    in_h, in_p = hpss(incoming)
    # Beats count from the asset's beat 0, which sits after the pad.
    n = total
    mid = beats / 2
    lo, hi = mid - width / 2, mid + width / 2
    shift = pad / beat_len
    ramp = lambda a, b: rise(n, beat_len, a + shift, b + shift)
    keep_h = 1 - ramp(lo, mid)
    keep_p = 1 - ramp(mid - width / 4, mid + width / 4)
    enter_p = ramp(lo, mid)
    enter_h = ramp(mid - width / 4, hi)
    # The fill: the incoming percussion runs a little hot until the barline settles it.
    bump = 1 + (fill - 1) * (ramp(lo, mid) - ramp(mid, hi))
    mix = out_h * keep_h + out_p * keep_p + in_h * enter_h + in_p * enter_p * bump
    done = int(round((hi + 0.25) * beat_len)) + pad
    mix[done:] = incoming[done:]
    mix, stats = limit(mix, cfg["ceilingDb"])
    return mix, {"entryBar": entry, "harmonyMatch": match, "limiter": stats, "beats": beats, "bpm": bpm}


def choose_tag(tier, key, bars):
    """The run of bars ending nearest the tonic, loud enough, with a strong third bar
    in a four-bar finale."""
    chroma = _unit(tier["allBarChroma"])
    tonic = tonic_template(key)
    rms = tier["barRms"]
    level = np.median(rms)
    best, start = -9.0, 0
    for b in range(0, len(rms) - bars):
        score = float(chroma[b + bars - 1] @ tonic) + 0.5 * min(rms[b:b + bars].min() / level, 1)
        if bars >= 4:
            score += 0.5 * min(rms[b + 2] / level, 1.2)
        if score > best:
            best, start = score, b
    return start, round(best, 3)


def render_success(tier, key, bars, final, cfg, pad):
    if tier.get("dir"):
        args = ["--tier", tier["dir"], "--key", key, "--bars", bars] + (["--final"] if final else [])
        return _rs_render("success", cfg, *args)
    start_bar, score = choose_tag(tier, key, bars)
    beat_len = tier["beatLen"]
    length = segment_bpm_len(tier["bpm"], bars * 4)
    at = int(round(tier["firstBarSample"] + start_bar * tier["barLen"]))
    total = pad + length + pad
    begin = at - pad
    audio = tier["grid"][max(begin, 0):begin + total].copy()
    if begin < 0:
        audio = np.vstack([np.zeros((-begin, 2)), audio])
    if len(audio) < total:
        audio = np.vstack([audio, np.zeros((total - len(audio), 2))])
    harmonic, percussive = hpss(audio)
    shift = pad / beat_len
    beats = bars * 4
    n = total
    if final:
        # The last level has nothing after it: everything settles to silence by the end.
        settle = 1 - rise(n, beat_len, beats - 4 + shift, beats + shift)
        mix = (harmonic + percussive) * settle
    else:
        # The percussion thins in the last beat, and the harmony carries into the bridge.
        thin = 1 - 0.5 * rise(n, beat_len, beats - 1 + shift, beats + shift)
        mix = harmonic + percussive * thin
    mix, stats = limit(mix, cfg["ceilingDb"])
    return mix, {"sourceBar": start_bar, "tagScore": score, "limiter": stats,
                 "bars": bars, "beats": beats, "bpm": tier["bpm"]}


def render_bridge(source, dest, cfg, pad, phase=(2, 0)):
    """Two bars at the next level's tempo: its percussion from the downbeat, the
    outgoing harmony dissolving, its harmony arriving into the loop."""
    if source.get("dir"):
        return _rs_render("bridge", cfg, "--a", source["dir"], "--b", dest["dir"],
                          "--entry-step", phase[0], "--entry-offset", phase[1])
    beats = 8
    bpm = dest["bpm"]
    beat_len = beat_samples(bpm)
    length = segment_bpm_len(bpm, beats)
    total = pad + length + pad
    entry, match = best_entry(source["barChroma"][-1], dest, phase)
    incoming = circ(dest["loop"], int(round(entry * dest["barLen"])) - length - pad, total)
    outgoing = outgoing_at(source, bpm, beats, pad)
    if len(outgoing) < total:
        outgoing = np.vstack([outgoing, np.zeros((total - len(outgoing), 2))])
    out_h, _ = hpss(outgoing[:total])
    in_h, in_p = hpss(incoming)
    shift = pad / beat_len
    ramp = lambda a, b: rise(total, beat_len, a + shift, b + shift)
    # The percussion runs hot while it's alone, and settles as the harmony arrives.
    boost = 10 ** (cfg["bridge"]["percussionBoostDb"] / 20)
    hot = boost + (1 - boost) * ramp(2, 5)
    mix = out_h * (1 - ramp(0, 3)) + in_p * ramp(-0.25, 0) * hot + in_h * ramp(1, 5)
    done = int(round(5.25 * beat_len)) + pad
    mix[done:] = incoming[done:]
    mix, stats = limit(mix, cfg["ceilingDb"])
    return mix, {"entryBar": entry, "harmonyMatch": match, "limiter": stats, "bars": 2, "beats": beats, "bpm": bpm}


def match_bridge(mix, target_lufs, cfg, pad):
    """A bridge plays at the loudness of the take it lands in. Its mix fades one
    room's harmony against the next room's percussion, so it comes out quieter
    (garden's was 2.4 LU under the lawn). Gain within `bridge.maxMatchDb`, then
    the limiter again. Measured without the pads."""
    most = cfg["bridge"].get("maxMatchDb", 0)
    if not most:
        return mix, 0.0
    level = loudness(mix[pad:len(mix) - pad])["lufs"]
    gain = float(np.clip(target_lufs - level, -most, most))
    if abs(gain) < 0.25:
        return mix, 0.0
    mix, _ = limit(mix * 10 ** (gain / 20), cfg["ceilingDb"])
    return mix, round(gain, 2)


def bar_features(tier):
    """What the cut table compares: per loop bar, chroma, bands at each end, and level."""
    loop = tier["loop"].mean(axis=1)
    mono = np.interp(np.arange(int(len(loop) * RATE / SR)) * SR / RATE, np.arange(len(loop)), loop)
    beat_seconds = tier["beatLen"] / SR
    wrapped = np.concatenate([mono, mono[:8192]])
    chroma, band, _ = beat_features(wrapped, beat_seconds, tier["bars"] * 4)
    size = int(beat_seconds * RATE)
    rms = np.array([np.sqrt(np.mean(np.take(mono, np.arange(int(b * beat_seconds * RATE), int(b * beat_seconds * RATE) + size), mode="wrap") ** 2))
                    for b in range(tier["bars"] * 4)])
    return {"chroma": _unit(chroma.reshape(tier["bars"], 4, 12).sum(axis=1)), "band": band.reshape(tier["bars"], 4, 12),
            "rmsDb": 20 * np.log10(np.maximum(rms, 1e-6)), "bars": tier["bars"]}


def cut_score(out, b, into, e):
    """Out plays to its bar b, then into plays from its bar e. Harmony across the seam,
    and against the bar into would have followed, then spectrum and level."""
    before = (b - 1) % out["bars"]
    harmony = float(out["chroma"][before] @ into["chroma"][e % into["bars"]])
    follows = float(out["chroma"][before] @ into["chroma"][(e - 1) % into["bars"]])
    timbre = float(np.mean(np.abs(out["band"][before, -1] - into["band"][e % into["bars"], 0])))
    level = abs(float(out["rmsDb"][b * 4 - 1] - into["rmsDb"][e * 4 % len(into["rmsDb"])]))
    return harmony + 0.25 * follows - 0.15 * timbre - 0.03 * level, harmony, timbre, level


def cut_table(source, dest, step=2):
    """For each exit bar, the even bar to enter. Entries keep the exit's place in a
    four-bar phrase when bar one is trusted on both sides; otherwise any even bar."""
    out, into = bar_features(source), bar_features(dest)
    entries, seams = [], []
    for b in range(0, out["bars"], step):
        rows = [(cut_score(out, b, into, e), e) for e in range(0, into["bars"], step)]
        best = max(rows, key=lambda row: row[0][0])
        entries.append(best[1])
        seams.append(best[0][1:])
    h, t, l = zip(*seams)
    return entries, {"harmonyMedian": round(float(np.median(h)), 3), "harmonyWorst": round(float(np.min(h)), 3),
                     "timbreMedian": round(float(np.median(t)), 2), "levelMedianDb": round(float(np.median(l)), 2),
                     "levelWorstDb": round(float(np.max(l)), 2)}


def transition_pairs(order):
    """What the game's tier map can reach: each step both ways, and the reset."""
    a, b, c = order
    return [(a, b), (b, c), (c, b), (b, a), (c, a)]


def tier_map(order):
    return [order[0], order[0], order[1], order[1], order[2]]


# ---------------------------------------------------------------- the build

def load_config(path=None):
    cfg = json.loads((pathlib.Path(path) if path else HERE / "levels.json").read_text())
    check_config(cfg)
    frame_loops(cfg)
    return cfg


def frame_loops(cfg):
    """With `loopFrameSamples`, give each tier a loop length that is a whole number of that
    many samples. The .ogg is loop[-pad:] + loop + loop[:pad], so the codec codes loop[0]
    twice; the codings agree only when the loop starts both times on a frame boundary, and
    the game jumps from one to the other at every wrap. 960 is the Opus frame. The tier is
    still warped at its asked tempo, so a layer keeps its parent's exact ratio; only the
    finished loop is resampled, as one period, to `frameSamples` (`resample_circular`),
    which moves its tempo to `frameBpm` (by 0.013 % at most on these loops at 960)."""
    frame = cfg.get("loopFrameSamples")
    if not frame:
        return
    for level in cfg["levels"]:
        for tier in level["tiers"]:
            beats = tier["loopBars"] * 4
            n = max(1, round(beats * beat_samples(tier["bpm"]) / frame)) * frame
            tier["frameSamples"] = n
            tier["frameBpm"] = beats * 60.0 * SR / n


def resample_circular(loop, n):
    """The loop resampled to n samples as one period (mixrs' resample_circular)."""
    spec = np.fft.rfft(loop, axis=0)
    keep = min(len(loop), n) // 2 + 1
    cut = np.zeros((n // 2 + 1, loop.shape[1]), dtype=complex)
    cut[:keep] = spec[:keep]
    if min(len(loop), n) % 2 == 0:
        cut[keep - 1] = (2.0 if n < len(loop) else 0.5) * cut[keep - 1].real
    return np.fft.irfft(cut, n, axis=0) * (n / len(loop))


def check_config(cfg):
    ids = [l["id"] for l in cfg["levels"]]
    for level in cfg["levels"]:
        if level.get("next") and level["next"] not in ids:
            raise ValueError(f"{level['id']}: unknown next level {level['next']}")
        targets = [t["targetLufs"] for t in level["tiers"]]
        if targets != sorted(targets) or len(set(targets)) != len(targets):
            raise ValueError(f"{level['id']}: loudness must rise in play order, got {targets}")
        if len(level["tiers"]) != 3:
            raise ValueError(f"{level['id']}: the tier map expects three tiers")


def tier_gain(level, name):
    """The owner's per-tier trim, from the game's mixer JSON. Default none."""
    for tier in level["tiers"]:
        if tier["name"] == name:
            return tier.get("gainDb", 0)
    return 0


def good_exit_bars(tier):
    chroma = _unit(tier["barChroma"])
    last = chroma[-1]
    sims = [(float(chroma[b] @ last), b) for b in range(0, len(chroma), 2)]
    return sorted(b for s, b in sims if s >= 0.85)


def build(cfg, only=None, root=REPO, workers=None, report_path=None):
    levels = {l["id"]: l for l in cfg["levels"]}
    wanted = [l for l in cfg["levels"] if not only or l["id"] in only]
    workers = max(1, min(workers or DEFAULT_WORKERS, MAX_WORKERS))
    busy = memory_in_use()
    if busy is not None and busy > BUSY_BYTES:
        raise SystemExit(f"{busy / 1e9:.1f} GB in use, over the {BUSY_BYTES / 1e9:.0f} GB limit: not starting")

    out_dir = root / cfg["outDir"]
    manifest_path = out_dir / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else \
        {"schemaVersion": 1, "mix": {"masterDb": 0, "musicDb": 0, "accentsDb": 0, "rewardsDb": 0}, "levels": {}}
    report_path = report_path or HERE / "report.json"
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    pad = int(round(cfg["padSeconds"] * SR))

    # A level at a time, releasing its audio before the next, and the manifest saved after
    # each: a build that dies keeps the levels it finished, each whole.
    for level in wanted:
        ready = prepare_level(cfg, level, levels, workers)
        lid = level["id"]
        order = [t["name"] for t in level["tiers"]]
        directory = out_dir / lid
        entry = {"key": level["key"], "tierTakes": tier_map(order), "takes": {}, "transitions": []}
        level_report = {"tiers": {}, "transitions": []}
        for name in order:
            tier = ready[(lid, name)]
            loop = tier["loop"]
            written, offsets, take_pad, choice = write_take(loop, directory / name, cfg, root)
            rep = tier["report"]
            rep["decodeOffsetSamples"] = offsets
            rep["pad"] = choice
            entry["takes"][name] = {
                "bpm": tier.get("loopBpm", tier["bpm"]), "bars": tier["bars"], "beatsPerBar": 4,
                "loopStartSeconds": take_pad / SR, "loopEndSeconds": (take_pad + len(loop)) / SR,
                "loopSamples": len(loop), "sampleRate": SR, "gainDb": tier_gain(level, name), **written,
                "lufs": rep["lufs"], "bar1Confidence": rep["bar1Confidence"],
                "goodExitBars": good_exit_bars(tier)}
            level_report["tiers"][name] = rep
        if level.get("gridTier"):
            entry["layerFadeBeats"] = level.get("layerFadeBeats", 2)
            entry["gridTier"] = level["gridTier"]
        if level.get("joinStyle") == "cuts":
            entry["cuts"] = []
            level_report["cuts"] = []
            for a, b in transition_pairs(order):
                entries, numbers = cut_table(ready[(lid, a)], ready[(lid, b)])
                entry["cuts"].append({"from": a, "to": b, "exitStep": 2, "entryBars": entries,
                                      "fadeInBeats": level.get("cutFadeInBeats", 0),
                                      "fadeOutBeats": level.get("cutFadeOutBeats", 1)})
                level_report["cuts"].append({"from": a, "to": b, **numbers})
        wanted_pairs = [] if level.get("gridTier") or level.get("joinStyle") == "cuts" else transition_pairs(order)
        for a, b in wanted_pairs:
            mix, info = render_transition(ready[(lid, a)], ready[(lid, b)], cfg, pad)
            written, offsets = write_asset(mix, directory / f"trans-{a}-{b}", cfg, root)
            info["decodeOffsetSamples"] = offsets
            entry["transitions"].append({
                "from": a, "to": b, "bpm": info["bpm"], "bars": info["beats"] // 4, "beatsPerBar": 4, "beats": info["beats"],
                "gainDb": 0, "entryBar": info["entryBar"], "crossfadeSeconds": 0.01,
                "startSeconds": pad / SR, "endSeconds": (len(mix) - pad) / SR, **written})
            level_report["transitions"].append({"from": a, "to": b, **info})
        last = ready[(lid, order[-1])]
        final = bool(level.get("successFinal"))
        # A tag may land on another chord than the loop's key, such as the relative major.
        tag_key = level.get("successKey", level["key"])
        mix, info = render_success(last, tag_key, level["successBars"], final, cfg, pad)
        written, info["decodeOffsetSamples"] = write_asset(mix, directory / "success", cfg, root)
        entry["success"] = {"bpm": info["bpm"], "bars": info["bars"], "beatsPerBar": 4, "gainDb": 0,
                            "startSeconds": pad / SR, "endSeconds": (len(mix) - pad) / SR,
                            "final": final, **written}
        if "successKey" in level:
            entry["success"]["key"] = tag_key
        level_report["success"] = info
        if level.get("successShortBars"):
            mix, info = render_success(last, tag_key, level["successShortBars"], False, cfg, pad)
            written, info["decodeOffsetSamples"] = write_asset(mix, directory / "success-short", cfg, root)
            entry["successShort"] = {"bpm": info["bpm"], "bars": info["bars"], "beatsPerBar": 4, "gainDb": 0,
                                     "startSeconds": pad / SR, "endSeconds": (len(mix) - pad) / SR,
                                     **written}
            level_report["successShort"] = info
        if level.get("next"):
            nxt = levels[level["next"]]
            first = nxt["tiers"][0]["name"]
            # The next level can ask for its entry bar's phase, so its chart's calls start on the
            # take's phrase: entryBar + introBeats / 4 on the phrase's first bar.
            phase = tuple(nxt.get("bridgeEntry", {}).get(k, d) for k, d in (("step", 2), ("offset", 0)))
            mix, info = render_bridge(last, ready[(nxt["id"], first)], cfg, pad, phase)
            mix, info["matchGainDb"] = match_bridge(mix, nxt["tiers"][0]["targetLufs"], cfg, pad)
            written, info["decodeOffsetSamples"] = write_asset(mix, directory / "bridge", cfg, root)
            entry["bridge"] = {"to": nxt["id"], "toTake": first, "entryBar": info["entryBar"],
                               "bpm": info["bpm"], "bars": info["bars"], "beatsPerBar": 4, "gainDb": 0,
                               "startSeconds": pad / SR, "endSeconds": (len(mix) - pad) / SR, **written}
            level_report["bridge"] = info
        manifest["levels"][lid] = entry
        report[lid] = level_report
        del ready
        _clear_work()
        if cfg.get("mix"):
            manifest["mix"] = cfg["mix"]
        out_dir.mkdir(parents=True, exist_ok=True)
        _write_atomic(manifest_path, json.dumps(manifest, indent=1, ensure_ascii=False) + "\n")
        _write_atomic(report_path, json.dumps(report, indent=1, ensure_ascii=False) + "\n")
        print(f"built {lid}, peak {peak_mb()} MB in a worker", flush=True)
    return manifest, report


def _write_atomic(path, text):
    part = path.with_name(path.name + ".part")
    part.write_text(text)
    os.replace(part, path)


def memory_in_use(current=pathlib.Path("/sys/fs/cgroup/memory.current"),
                  stat=pathlib.Path("/sys/fs/cgroup/memory.stat")):
    """What the forge can't get back: anon + shmem from memory.stat. memory.current also
    counts the page cache, which reading and writing takes fills and the kernel reclaims;
    it refused a build at 6.4 GB with 0.3 GB anon. memory.current only without a stat."""
    try:
        fields = dict(line.split() for line in stat.read_text().splitlines() if line.count(" ") == 1)
        if "anon" in fields:
            return int(fields["anon"]) + int(fields.get("shmem", 0))
    except (OSError, ValueError):
        pass
    try:
        return int(current.read_text())
    except (OSError, ValueError):
        return None


def peak_mb():
    return resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss // 1024


def limit_process():
    """Run out of memory here, as an error, before the whole forge stalls."""
    resource.setrlimit(resource.RLIMIT_AS, (PROCESS_LIMIT_BYTES, PROCESS_LIMIT_BYTES))


def prepare_level(cfg, level, levels, workers):
    """The level's tiers, and the first tier of the level it leads to. A layered level's
    parent goes first, as the others take its beat map."""
    def jobs_for(lv, tiers):
        parent = lv.get("gridTier")
        if not parent:
            return [(cfg, lv, t) for t in tiers], []
        needed = list(tiers)
        if parent not in [t["name"] for t in needed]:
            needed += [t for t in lv["tiers"] if t["name"] == parent]
        return [(cfg, lv, t) for t in needed if t["name"] == parent], \
            [(cfg, lv, t) for t in needed if t["name"] != parent]
    first, rest = jobs_for(level, level["tiers"])
    if level.get("next"):
        nxt = levels[level["next"]]
        more_first, more_rest = jobs_for(nxt, [nxt["tiers"][0]])
        first += more_first
        rest += more_rest
    ready = {}
    # With mixrs a worker only waits on its subprocess, so threads will do.
    if find_mixrs():
        _work_dir()  # made here, before two threads can both make it
    pool_of = (lambda: futures.ThreadPoolExecutor(max_workers=workers)) if find_mixrs() else \
        (lambda: futures.ProcessPoolExecutor(max_workers=workers, initializer=limit_process, max_tasks_per_child=1))
    with pool_of() as pool:
        for done in pool.map(prepare_tier, first):
            ready[(done["level"], done["name"])] = done
        followers = [j + (ready[(j[1]["id"], j[1]["gridTier"])]["follow"],) for j in rest]
        for done in pool.map(prepare_tier, followers):
            ready[(done["level"], done["name"])] = done
    return ready


# ---------------------------------------------------------------- verification

def bar_level_jumps(loop, bars):
    """The level change across each bar line, one beat either side, wrap included,
    in the order bar 0 (the wrap), bar 1 and so on."""
    size = int(len(loop) / bars / 4)
    out = []
    for b in range(bars):
        at = int(round(b * len(loop) / bars))
        before = np.mean(circ(loop, at - size, size) ** 2)
        after = np.mean(circ(loop, at, size) ** 2)
        out.append(10 * np.log10(max(after, 1e-12) / max(before, 1e-12)))
    return np.array(out)


def pattern_drift(mono, bpm):
    """Beat lock, tested against the take's own pattern: fold the attacks onto one bar
    at the asked tempo, then find how far each two-bar stretch sits from that fold.
    A wrong tempo shows as first and last stretches disagreeing. Returns the spread
    between the ends and the worst stretch, in ms."""
    env = np.convolve(onset_envelope(mono), np.hanning(5) / 2, "same")
    t = env_times(len(env))
    bar = 240.0 / bpm
    res = 256
    cells = ((t % bar) / bar * res).astype(int)
    pattern = np.bincount(cells, env, minlength=res) / np.maximum(np.bincount(cells, minlength=res), 1)
    pattern = pattern - pattern.mean()
    lags = np.arange(-0.15, 0.1501, 0.002)
    found = []
    for start in np.arange(0, max(t[-1] - 2 * bar, bar), bar):
        where = (t >= start) & (t < start + 2 * bar)
        scores = [np.sum(env[where] * np.interp(((t[where] - lag) % bar) / bar * res, np.arange(res), pattern,
                                                period=res)) for lag in lags]
        found.append(lags[int(np.argmax(scores))] * 1000)
    found = np.array(found)
    edge = min(8, max(len(found) // 3, 1))
    return (round(float(np.median(found[-edge:]) - np.median(found[:edge])), 1),
            round(float(np.max(np.abs(found - np.median(found)))), 1))


def _top_end(audio):
    """RMS of the second difference, which weights the top of the spectrum, where a
    click lives."""
    return float(np.sqrt(np.mean(np.diff(audio, n=2, axis=0) ** 2)))


def seam_numbers(audio, start, end, bars):
    """A wrap joins two copies of the head that the codec encoded separately, so a step
    there may be the music or the join. The file holds both answers: playing on past
    the loop's end reaches the same music with no join. So the test is looped against
    straight through. burstDb is the top-end energy over 2 ms around the wrap, looped
    over straight: a click raises it. The step is also placed among the loop's own."""
    n = 2400
    joined = np.vstack([audio[end - n:end], audio[start:start + n]])
    steps = np.abs(np.diff(joined, axis=0)).max(axis=1)
    typical = float(np.percentile(np.delete(steps, n - 1), 99.9))
    jumps = np.abs(bar_level_jumps(audio[start:end], bars))
    step = float(np.abs(audio[start] - audio[end - 1]).max())
    loop_steps = np.abs(np.diff(audio[start:end], axis=0)).max(axis=1)
    w = 48
    looped = _top_end(np.vstack([audio[end - w:end], audio[start:start + w]]))
    straight = _top_end(audio[end - w:end + w])
    return {"stepRatio": round(float(steps[n - 1]) / max(typical, 1e-9), 2),
            "wrapJumpDb": round(float(jumps[0]), 2),
            "otherBarsP90JumpDb": round(float(np.percentile(jumps[1:], 90)), 2),
            "step": round(step, 4),
            "stepStraightThrough": round(float(np.abs(audio[end] - audio[end - 1]).max()), 4),
            "headMismatch": round(float(np.abs(audio[start] - audio[end]).max()), 4),
            "loopMaxStep": round(float(loop_steps.max()), 4),
            "shareOfLoopStepsAbovePct": round(float(np.mean(loop_steps > step) * 100), 3),
            "burstDb": round(20 * np.log10(max(looped, 1e-9) / max(straight, 1e-9)), 2)}


def decode_offset(reference, decoded, span=1 << 15, reach=4096):
    """Where the decoded file's content sits against what was encoded, in samples."""
    at = min(len(reference) // 2, len(decoded) // 2)
    ref = reference[at:at + span].mean(axis=1)
    dec = decoded[max(at - reach, 0):at + span + reach].mean(axis=1)
    size = 1 << int(np.ceil(np.log2(len(ref) + len(dec))))
    xc = np.fft.irfft(np.fft.rfft(dec, size) * np.conj(np.fft.rfft(ref, size)), size)
    return int(np.argmax(xc[:len(dec) - len(ref) + 1])) - min(reach, at)


def verify(cfg, root=REPO):
    """Measures the encoded files, not the intent. Returns findings and failures."""
    out_dir = root / cfg["outDir"]
    manifest = json.loads((out_dir / "manifest.json").read_text())
    failures, results = [], {}
    ceiling_tp = 0.0
    for lid, entry in manifest["levels"].items():
        level = {"takes": {}, "segments": {}, "megabytes": {}}
        for fmt in ("opus", "aac"):
            paths = [t["files"][fmt] for t in entry["takes"].values()] \
                + [t["files"][fmt] for t in entry["transitions"]] \
                + [entry[k]["files"][fmt] for k in ("success", "successShort", "bridge") if k in entry]
            mb = sum((root / p).stat().st_size for p in paths) / 1e6
            level["megabytes"][fmt] = round(mb, 2)
            if mb > cfg["budgetMbPerFormat"]:
                failures.append(f"{lid} {fmt}: {mb:.2f} MB over budget")
        targets = {t["name"]: t["targetLufs"] for l in cfg["levels"] if l["id"] == lid for t in l["tiers"]}
        previous = None
        for name in dict.fromkeys(entry["tierTakes"]):
            take = entry["takes"][name]
            row = {}
            for fmt in ("opus", "aac"):
                start = int(round(take["loopStartSeconds"] * SR))
                end = int(round(take["loopEndSeconds"] * SR))
                if find_mixrs():
                    row[fmt] = _rs("verify-take", "--file", root / take["files"][fmt], "--bpm", take["bpm"],
                                   "--bars", take["bars"], "--start", start, "--end", end)
                    level_now = row[fmt]
                    ends = row[fmt]["driftEndsMs"]
                else:
                    audio = decode(root / take["files"][fmt])
                    loop = audio[start:end]
                    level_now = loudness(np.vstack([loop, loop]))
                    mono = decode_mono_from(loop)
                    env = onset_envelope(mono)
                    ends, worst_block = pattern_drift(mono, take["bpm"])
                    seconds = len(loop) / SR
                    expected = take["bars"] * 4 * 60 / take["bpm"]
                    row[fmt] = {
                        "lufs": level_now["lufs"], "truePeakDb": level_now["truePeakDb"],
                        "driftEndsMs": ends, "driftWorstMs": worst_block,
                        "pulseBpm": round(fit_tempo(env, take["bpm"], 1.0), 3),
                        "wanderMs": round(phase_wander_ms(env, take["bpm"]), 2),
                        "seam": seam_numbers(audio, start, end, take["bars"]),
                        "wrapResidualDb": wrap_residual(audio, start, end),
                        "decodedSamples": len(audio), "lengthErrorMs": round((seconds - expected) * 1000, 3)}
                # Half a step: the codecs move level a little, and the 1 LU steps must survive.
                if abs(level_now["lufs"] - targets[name]) > 0.5:
                    failures.append(f"{lid}/{name} {fmt}: {level_now['lufs']} LUFS, asked {targets[name]}")
                if level_now["truePeakDb"] > ceiling_tp:
                    failures.append(f"{lid}/{name} {fmt}: true peak {level_now['truePeakDb']} dB")
                # A starting value: 3 dB is well clear of the 1.0 dB the real takes reach.
                if row[fmt]["seam"]["burstDb"] > 3:
                    failures.append(f"{lid}/{name} {fmt}: wrap adds top end, {row[fmt]['seam']['burstDb']} dB")
                # 15 ms across a whole loop is 0.03% at 24 bars and 100 BPM.
                if abs(ends) > 15:
                    failures.append(f"{lid}/{name} {fmt}: beat drifts {ends} ms across the loop")
                if abs(row[fmt]["lengthErrorMs"]) > 0.02:
                    failures.append(f"{lid}/{name} {fmt}: loop length off by {row[fmt]['lengthErrorMs']} ms")
            for fmt in ("opus", "aac"):
                if previous is not None and not previous[fmt] < row[fmt]["lufs"]:
                    failures.append(f"{lid}/{name} {fmt}: loudness doesn't rise in play order")
            previous = {fmt: row[fmt]["lufs"] for fmt in ("opus", "aac")}
            level["takes"][name] = row
        if entry.get("gridTier"):
            level["layers"] = verify_layers(entry, root, failures, lid)
        segments = [(f"{t['from']}>{t['to']}", t) for t in entry["transitions"]] \
            + [(k, entry[k]) for k in ("success", "successShort", "bridge") if k in entry]
        for name, seg in segments:
            row = {}
            for fmt in ("opus", "aac"):
                a, z = int(round(seg["startSeconds"] * SR)), int(round(seg["endSeconds"] * SR))
                if find_mixrs():
                    row[fmt] = _rs("verify-segment", "--file", root / seg["files"][fmt], "--bpm", seg["bpm"],
                                   "--start", a, "--end", z)
                else:
                    audio = decode(root / seg["files"][fmt])
                    body = audio[a:z]
                    row[fmt] = {"truePeakDb": loudness(np.vstack([audio, audio]))["truePeakDb"],
                                "seconds": round(len(body) / SR, 4),
                                "beatRmsDb": beat_rms(body, seg["bpm"])}
                beats = seg["bars"] * 4
                if abs(row[fmt]["seconds"] - beats * 60 / seg["bpm"]) > 0.001:
                    failures.append(f"{lid}/{name} {fmt}: length differs from its beats")
                if row[fmt]["truePeakDb"] > ceiling_tp:
                    failures.append(f"{lid}/{name} {fmt}: true peak {row[fmt]['truePeakDb']} dB")
            level["segments"][name] = row
        results[lid] = level
    return results, failures


def verify_layers(entry, root, failures, lid):
    """Layers must hold the same bars on the same samples. Lag per 8 bars, by attacks."""
    takes = entry["takes"]
    parent = takes[entry["gridTier"]]
    def env(take):
        audio = decode(root / take["files"]["opus"])
        a = int(round(take["loopStartSeconds"] * SR))
        return np.convolve(onset_envelope(decode_mono_from(audio[a:a + take["loopSamples"]])), np.hanning(5) / 2, "same")
    reference = env(parent)
    out = {}
    reach = int(0.08 * ENV_RATE)
    # Eight bars, or half a loop shorter than that, so a short loop still gets a window.
    size = min(int(8 * 240.0 / parent["bpm"] * ENV_RATE), (len(reference) - 2 * reach) // 2)
    for name, take in takes.items():
        if take["bars"] != parent["bars"]:
            failures.append(f"{lid}/{name}: layer doesn't share the parent's bars")
        if name == entry["gridTier"]:
            continue
        lags, corr = layer_lags(reference, env(take), take["loopSamples"] / parent["loopSamples"], size, reach)
        out[name] = {"lagMedianMs": round(float(np.median(lags)), 1), "lagWorstMs": round(float(np.max(np.abs(lags))), 1),
                     "envelopeCorr": round(float(np.median(corr)), 2)}
        if abs(out[name]["lagMedianMs"]) > 5:
            failures.append(f"{lid}/{name}: layer sits {out[name]['lagMedianMs']} ms off its parent")
    return out


def on_parent_clock(other, length, ratio):
    """A layer's onset envelope on its parent's frames, as a layer may run at its own tempo.
    By the loops' real length ratio, at each frame's centre: the frame counts are floored,
    so stretching one count onto the other is off by up to a frame by the loop's end."""
    centre = WINDOW / 2 / HOP
    return np.interp((np.arange(length) + centre) * ratio - centre, np.arange(len(other)), other)


def layer_lags(reference, other, ratio, size, reach):
    """Per window of `size` envelope frames, how far the layer sits from its parent in ms,
    and how well they correlate there. `ratio` is the layer's loop length over the parent's."""
    other = on_parent_clock(other, len(reference), ratio)
    lags, corr = [], []
    for start in range(reach, min(len(reference), len(other)) - size - reach, size):
        a = reference[start:start + size] - reference[start:start + size].mean()
        scores = []
        for lag in range(-reach, reach + 1):
            b = other[start + lag:start + lag + size]
            b = b - b.mean()
            scores.append(float(a @ b / max(np.linalg.norm(a) * np.linalg.norm(b), 1e-9)))
        # The peak between frames (a parabola through it and its neighbours): the
        # limit below is under one envelope frame, so whole frames can't test it.
        k = int(np.argmax(scores))
        frac = 0.0
        if 0 < k < len(scores) - 1:
            y0, y1, y2 = scores[k - 1], scores[k], scores[k + 1]
            bend = y0 - 2 * y1 + y2
            frac = 0.5 * (y0 - y2) / bend if bend < 0 else 0.0
        lags.append((k + frac - reach) / ENV_RATE * 1000)
        corr.append(max(scores))
    return lags, corr


def decode_mono_from(stereo):
    mono = stereo.mean(axis=1)
    return np.interp(np.arange(int(len(mono) * RATE / SR)) * SR / RATE, np.arange(len(mono)), mono)


def wrap_residual(audio, start, end):
    """Pad after the loop's end against the loop's head: both hold the same audio, so
    this is how far the codec moved them apart, in dB under the signal."""
    n = int(round(0.1 * SR))
    a, b = audio[start:start + n], audio[end:end + n]
    return round(float(10 * np.log10(max(np.mean((a - b) ** 2), 1e-14) / max(np.mean(a ** 2), 1e-14))), 1)


def beat_rms(body, bpm):
    size = beat_samples(bpm)
    out = []
    for i in range(int(round(len(body) / size))):
        part = body[int(i * size):int((i + 1) * size)]
        out.append(round(float(10 * np.log10(max(np.mean(part ** 2), 1e-12))), 1))
    return out


# ---------------------------------------------------------------- the listening check

def _clip(path):
    return decode(path)


def _join(parts, fade=int(0.02 * SR)):
    """Butt segments the way the runtime does: a 20 ms fade over each join."""
    out = parts[0]
    for part in parts[1:]:
        x = np.linspace(0, 1, fade)[:, None]
        out = np.vstack([out[:-fade], out[-fade:] * (1 - x) + part[:fade] * x, part[fade:]])
    return out


def _bars(take, audio, first_bar, count):
    start = int(round(take["loopStartSeconds"] * SR))
    length = int(take["loopSamples"])
    bar = length / take["bars"]
    loop = audio[start:start + length]
    return circ(loop, int(round(first_bar * bar)), int(round(count * bar)))


def _segment(seg, audio):
    a, z = int(round(seg["startSeconds"] * SR)), int(round(seg["endSeconds"] * SR))
    return audio[a:z + int(0.02 * SR)]


def _save(audio, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                    "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(path)],
                   input=_pipe(audio), check=True)


def plain_crossfade(a_tail, b_head, beat_len):
    fade = int(round(beat_len))
    x = np.linspace(0, 1, fade)[:, None]
    return np.vstack([a_tail[:-fade], a_tail[-fade:] * (1 - x) + b_head[:fade] * x, b_head[fade:]])


def listen(cfg, target, root=REPO):
    """Joins as the runtime would play them, cut from the encoded Opus files."""
    target = pathlib.Path(target)
    manifest = json.loads((root / cfg["outDir"] / "manifest.json").read_text())
    rows = []
    for lid, entry in manifest["levels"].items():
        takes = {n: _clip(root / t["files"]["opus"]) for n, t in entry["takes"].items()}
        order = list(dict.fromkeys(entry["tierTakes"]))
        section = {"level": lid, "key": entry["key"], "order": [f"{n} {entry['takes'][n]['bpm']:g}" for n in order], "clips": []}
        def add(name, label, audio):
            _save(audio, target / lid / f"{name}.m4a")
            section["clips"].append({"file": f"{lid}/{name}.m4a", "label": label, "seconds": round(len(audio) / SR, 1)})
        for n in order:
            take = entry["takes"][n]
            add(f"seam-{n}", f"Loop wrap, {n}, Opus file: last 4 bars into first 4 bars",
                _bars(take, takes[n], take["bars"] - 4, 8))
            add(f"seam-{n}-aac", f"The same wrap, {n}, from the AAC file",
                _bars(take, _clip(root / take["files"]["aac"]), take["bars"] - 4, 8))
        for t in entry["transitions"]:
            a, b = entry["takes"][t["from"]], entry["takes"][t["to"]]
            seg = _segment(t, _clip(root / t["files"]["opus"]))
            good = [g for g in a.get("goodExitBars", []) if g >= 4]
            boundary = good[-1] if good else a["bars"] - 2
            parts = [_bars(a, takes[t["from"]], boundary - 4, 4), seg, _bars(b, takes[t["to"]], t["entryBar"], 4)]
            direction = "up" if order.index(t["to"]) > order.index(t["from"]) else "down"
            add(f"join-{t['from']}-{t['to']}", f"{t['from']} into {t['to']} ({direction}), leaving at a good bar ({boundary}): 4 bars, the transition, 4 bars", _join(parts))
            if direction == "up":
                other = max(a["bars"] // 2 // 2 * 2, 4)
                add(f"join-{t['from']}-{t['to']}-any", f"The same, leaving at an arbitrary bar ({other}), which the game can also do",
                    _join([_bars(a, takes[t["from"]], other - 4, 4), seg, _bars(b, takes[t["to"]], t["entryBar"], 4)]))
                beat = 60.0 * SR / b["bpm"]
                add(f"plain-{t['from']}-{t['to']}", "For comparison: no transition, only a one-beat crossfade at the boundary",
                    plain_crossfade(_bars(a, takes[t["from"]], boundary - 4, 4), _bars(b, takes[t["to"]], t["entryBar"], 4), beat))
        last = order[-1]
        lastt = entry["takes"][last]
        success = _segment(entry["success"], _clip(root / entry["success"]["files"]["opus"]))
        if entry.get("bridge") and entry["bridge"]["to"] in manifest["levels"]:
            bridge = entry["bridge"]
            nxt = manifest["levels"][bridge["to"]]["takes"][bridge["toTake"]]
            next_audio = _clip(root / nxt["files"]["opus"])
            add("exit", f"Winning: {last} 4 bars, success tag, bridge, then {bridge['to']} {bridge['toTake']} 4 bars",
                _join([_bars(lastt, takes[last], lastt["bars"] - 4, 4), success,
                       _segment(bridge, _clip(root / bridge["files"]["opus"])),
                       _bars(nxt, next_audio, bridge["entryBar"], 4)]))
        else:
            add("exit", f"Winning: {last} 4 bars, then the success tag to its end",
                _join([_bars(lastt, takes[last], lastt["bars"] - 4, 4), success]))
        rows.append(section)
    (target / "clips.json").write_text(json.dumps(rows, indent=1))
    body = []
    for section in rows:
        body.append(f"<h2>{section['level']}</h2><p>{section['key']}. Play order: {', '.join(section['order'])}.</p>")
        for clip in section["clips"]:
            body.append(f"<div class=c><p>{clip['label']} <small>({clip['seconds']} s)</small></p>"
                        f"<audio controls preload=none src='{clip['file']}'></audio></div>")
    (target / "index.html").write_text(
        "<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'>"
        "<title>Mix joins</title><style>body{font:16px system-ui;max-width:44rem;margin:auto;padding:1rem 16px;"
        "background:#fff;color:#111}audio{width:100%}.c{margin:0 0 1rem}small{color:#666}"
        "@media (prefers-color-scheme:dark){body{background:#111;color:#eee}small{color:#999}}</style>"
        "<h1>Tier joins, for ears</h1><p>What to listen for: a click or thump at any join, tempo stumbling, "
        "harmony clashing in the crossfade, and whether the transition beats the plain crossfade. "
        "Cut from the encoded files (Opus, unless a clip says AAC), then re-encoded at 192 kb/s AAC for "
        "this page, so it isn't a test of quality at 128 kb/s. The wrap clips hold the files' real joins, "
        "with that extra encode on top.</p>" + "".join(body))
    return target


# ---------------------------------------------------------------- self-test

def _synth(path, bpm, seconds, pickup_beats, root_shift, tempo_error=0.0, seed=1):
    """A little band with a known grid: kick on 1 and 3, snare on 2 and 4, a chord
    change at each bar line, and pickup beats of hats before bar one."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    audio = np.zeros(n)
    t = np.arange(n) / SR
    beat = 60.0 / (bpm * (1 + tempo_error))
    start = 0.4
    roots = [0, 5, 7, 3]
    count = int((seconds - start) / beat)
    for i in range(count):
        at = start + i * beat
        k = int(at * SR)
        bar_beat = i - pickup_beats
        size = int(0.25 * SR)
        tail = np.arange(min(size, n - k)) / SR
        if bar_beat >= 0:
            if bar_beat % 2 == 0:
                gain = 1.0 if bar_beat % 4 == 0 else 0.55
                audio[k:k + len(tail)] += gain * 0.8 * np.sin(2 * np.pi * 70 * tail) * np.exp(-tail * 18)
            else:
                noise = rng.standard_normal(len(tail))
                audio[k:k + len(tail)] += 0.25 * noise * np.exp(-tail * 30)
        hat = np.arange(min(int(0.03 * SR), n - k)) / SR
        audio[k:k + len(hat)] += 0.06 * rng.standard_normal(len(hat)) * np.exp(-hat * 120)
        if bar_beat >= 0 and bar_beat % 4 == 0:
            root = roots[(bar_beat // 4) % 4] + root_shift
            hold = np.arange(min(int(4 * beat * SR), n - k)) / SR
            for step in (0, 3, 7):
                audio[k:k + len(hold)] += 0.07 * np.sin(2 * np.pi * 220 * 2 ** ((root + step) / 12) * hold)
    stereo = np.stack([audio, audio * 0.9], axis=1)
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                    "-c:a", "flac", str(path)], input=_pipe(stereo), check=True)
    return start + pickup_beats * beat


def self_test():
    # The memory guard counts what can't be reclaimed: anon + shmem, not the page cache.
    # A cache-heavy cgroup (2026-11-10: 6.4 GB current, 5.9 GB of it file cache) must not refuse.
    with tempfile.TemporaryDirectory() as tmp:
        cur, stat = pathlib.Path(tmp, "memory.current"), pathlib.Path(tmp, "memory.stat")
        cur.write_text("6373761024\n")
        stat.write_text("anon 317825024\nfile 5870370816\nkernel 120000000\nshmem 910852096\n")
        assert memory_in_use(cur, stat) == 317825024 + 910852096, memory_in_use(cur, stat)
        stat.write_text("file 5870370816\n")  # no anon line: fall back to memory.current
        assert memory_in_use(cur, stat) == 6373761024
        assert memory_in_use(pathlib.Path(tmp, "none"), pathlib.Path(tmp, "none")) is None

    # Loop lengths a whole number of codec frames: Opus codes loop[0] twice in the padded
    # file, and the two codings agree only on a frame boundary (2026-11-10, work/2617-fral).
    framed = {"loopFrameSamples": 15360, "levels": [{"id": "x", "tiers": [
        {"name": "low", "bpm": 103, "loopBars": 24}, {"name": "mid", "bpm": 106, "loopBars": 24}]}]}
    frame_loops(framed)
    assert [t["frameSamples"] for t in framed["levels"][0]["tiers"]] == [2688000, 2611200]
    assert [t["frameBpm"] for t in framed["levels"][0]["tiers"]] == [24 * 4 * 60 * SR / 2688000, 24 * 4 * 60 * SR / 2611200]
    # The warp still runs at the asked tempo, so layers keep their parent's exact ratio.
    assert [t["bpm"] for t in framed["levels"][0]["tiers"]] == [103, 106]
    unframed = {"levels": [{"id": "x", "tiers": [{"name": "low", "bpm": 103, "loopBars": 24}]}]}
    frame_loops(unframed)
    assert "frameSamples" not in unframed["levels"][0]["tiers"][0]
    # The resample treats the loop as one period: whole cycles stay whole, the level stays.
    cycles = np.sin(2 * np.pi * 400 * np.arange(48000) / 48000)[:, None] * [0.5, -0.5]
    for n in (48000 - 37, 48000 + 37, 48000):
        want = np.sin(2 * np.pi * 400 * np.arange(n) / n)[:, None] * [0.5, -0.5]
        assert np.abs(resample_circular(cycles, n) - want).max() < 1e-6, n

    # A layer is checked on its parent's clock by its real length, not by its envelope's
    # frame count: the counts are floored, which alone read comedor's low as 6 ms late
    # (2026-11-10). The same onsets at the two loop lengths must sit together.
    def onsets(samples, period_s):
        count = (int(samples * RATE / SR) - WINDOW) // HOP
        t = (np.arange(count) * HOP + WINDOW / 2) / RATE / (samples / 2880000)
        return np.exp(-0.5 * (((t + 0.1) % period_s - 0.1) / 0.004) ** 2) + 0.3 * np.exp(-0.5 * (((t + 0.37) % 0.469 - 0.1) / 0.004) ** 2)
    parent_env, layer_env = onsets(2880000, 0.46875), onsets(2973120, 0.46875)
    lags, _ = layer_lags(parent_env, layer_env, 2973120 / 2880000, int(8 * 240.0 / 128 * ENV_RATE), int(0.08 * ENV_RATE))
    assert max(abs(v) for v in lags) < 1.0, lags

    # The head's two codings: equal heads read far below the signal, a head 20 dB off reads -20.
    body = np.random.default_rng(9).normal(0, 0.1, (5000, 2))
    padded = np.vstack([body[-300:], body, body[:600]])
    assert head_mismatch_db(padded, 300, 5000) < -200
    padded[300 + 5000:300 + 5000 + 480] += 0.1 * padded[300:300 + 480]
    assert abs(head_mismatch_db(padded, 300, 5000) - 20 * np.log10(0.1 / 1.1)) < 0.01

    # Blocks of separation still sum back, and sit close to separating the whole.
    long_mix = np.random.default_rng(6).normal(0, 0.2, (SR * 24, 2))
    long_h, long_p = hpss(long_mix)
    assert np.allclose(long_h + long_p, long_mix, atol=1e-9)

    # Stretching keeps pitch, length and the map.
    t = np.arange(SR * 4) / SR
    tone = np.stack([np.sin(2 * np.pi * 440 * t)] * 2, axis=1) * 0.5
    out = stretch_linear(tone, int(len(tone) / 1.02))
    assert len(out) == int(len(tone) / 1.02)
    body = out[SR // 2:-SR // 2, 0]
    spec = np.abs(np.fft.rfft(body * np.hanning(len(body))))
    peak = np.argmax(spec) * SR / len(body)
    assert abs(peak - 440) < 1.0, f"pitch moved to {peak}"
    rms = np.sqrt(np.mean(body ** 2))
    assert abs(rms - 0.5 / np.sqrt(2)) < 0.03, f"level moved to {rms}"

    # The running minimum matches a slow one, both ways round.
    values = np.random.default_rng(3).uniform(0.2, 1.0, 400)
    for circular in (False, True):
        fast = sliding_min(values, 5, circular)
        data = np.concatenate([values[-5:], values, values[:5]]) if circular \
            else np.concatenate([np.ones(5), values, np.ones(5)])
        slow = np.array([data[i:i + 11].min() for i in range(len(values))])
        assert np.allclose(fast, slow), f"sliding_min, circular={circular}"

    # The limiter holds its ceiling and leaves quiet audio alone.
    loud = np.random.default_rng(4).normal(0, 0.4, (SR * 2, 2))
    limited, stats = limit(loud, -1.5, circular=True)
    assert np.max(np.abs(limited)) <= 10 ** (-1.5 / 20) + 1e-9, "limiter let a peak through"
    assert stats["maxReductionDb"] > 0
    quiet, stats = limit(loud * 0.01, -1.5)
    assert stats["maxReductionDb"] == 0 and np.array_equal(quiet, loud * 0.01)

    # Separation sums back to its input.
    harm, perc = hpss(loud[:SR // 2])
    assert np.allclose(harm + perc, loud[:SR // 2], atol=1e-9)

    # The key finder names a plain A minor, from a progression's pitch classes.
    pcs = np.zeros((16, 12))
    for i, chord in enumerate([(9, 0, 4), (2, 5, 9), (4, 7, 11), (9, 0, 4)] * 4):
        pcs[i, list(chord)] = 1.0
    assert measure_key(pcs)[0] == "A minor", measure_key(pcs)

    # The drift test sees a tempo off by 0.15%, and passes one that's on.
    beat_at = lambda bpm_true: np.arange(0, 60, 60.0 / bpm_true)
    def clicks(bpm_true):
        mono = np.zeros(RATE * 60)
        noise = np.random.default_rng(5).standard_normal(200)
        for i, at in enumerate(beat_at(bpm_true)):
            k = int(at * RATE)
            mono[k:k + 200] += noise[:len(mono[k:k + 200])] * (1.0 if i % 4 == 0 else 0.5) * np.exp(-np.arange(len(mono[k:k + 200])) / 40)
        return mono
    assert abs(pattern_drift(clicks(100.0), 100.0)[0]) <= 4, pattern_drift(clicks(100.0), 100.0)
    assert abs(pattern_drift(clicks(100.15), 100.0)[0]) >= 30, pattern_drift(clicks(100.15), 100.0)

    # The seam test passes a clean wrap and catches a join the codec left mismatched.
    tone_len = SR * 2
    seam_t = np.arange(tone_len + 4800) / SR
    wrapped = np.stack([0.3 * np.sin(2 * np.pi * 110 * seam_t)] * 2, axis=1)
    period = SR * 2  # 110 Hz fits a whole number of cycles in two seconds.
    assert abs(seam_numbers(wrapped, 2400, 2400 + period, 2)["burstDb"]) < 0.5
    broken = wrapped.copy()
    broken[2400:2400 + 48] += 0.1
    caught = seam_numbers(broken, 2400, 2400 + period, 2)
    assert caught["burstDb"] > 3 and caught["headMismatch"] > 0.05, caught

    # A config whose loudness doesn't rise in play order is refused.
    real = load_config()
    bad = json.loads(json.dumps(real))
    bad["levels"][0]["tiers"][0]["targetLufs"] = -10
    try:
        check_config(bad)
        raise AssertionError("falling loudness was accepted")
    except ValueError:
        pass
    # The owner's rulings stay in the committed config.
    by_id = {l["id"]: l for l in real["levels"]}
    asked = lambda lid: [t["bpm"] for t in by_id[lid]["tiers"]]
    # 2026-11-09: the lawn is layered from its 136 take, rising about 3 % in play order (owner).
    assert [t["name"] for t in by_id["pool-garden"]["tiers"]] == ["low", "mid", "high"]
    assert asked("pool-garden") == [128, 132, 136]
    assert asked("garden") == [95, 98, 101]
    # 2026-11-09: the owner chose a lift of about 3 % per tier for the layered rebuild.
    assert asked("bar") == [103, 106, 109]
    assert asked("cool-crowd") == [120, 124, 128]
    # 2026-11-10: every loop is a whole number of Opus frames (owner, option B); the nudge stays tiny.
    assert real["loopFrameSamples"] == 960
    for level in real["levels"]:
        for t in level["tiers"]:
            assert t["frameSamples"] % 960 == 0, (level["id"], t["name"])
            assert abs(t["frameBpm"] / t["bpm"] - 1) < 0.0005, (level["id"], t["name"], t["frameBpm"])
    assert transition_pairs(["a", "b", "c"]) == [("a", "b"), ("b", "c"), ("c", "b"), ("b", "a"), ("c", "a")]
    assert tier_map(["a", "b", "c"]) == ["a", "a", "b", "b", "c"]

    # The whole road on synthetic takes with a known grid: off tempo and with pickups.
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        truth = {}
        cases = [("low", 100, 1, 0.008), ("mid", 106, 2, -0.005), ("high", 112, 3, 0.012)]
        for name, bpm, pickup, err in cases:
            truth[name] = (pickup, _synth(root / "m" / f"{name}.flac", bpm, 60, pickup, 0, err))
        cfg = dict(real)
        cfg.update(mastersDir=str(root / "m"), outDir="out")
        cfg["levels"] = [{"id": "test", "key": "A minor", "next": None, "successBars": 2, "successFinal": True,
                          "tiers": [{"name": n, "source": f"{n}.flac", "bpm": b, "loopBars": 8,
                                     "targetLufs": -16 + i, "eq": []} for i, (n, b, _, _) in enumerate(cases)]}]
        manifest, report = build(cfg, None, root, workers=3, report_path=root / "report.json")
        for name, _, pickup, _ in cases:
            rep = report["test"]["tiers"][name]
            assert rep["bar1Beat"] % 4 == pickup % 4, f"{name}: bar one at beat {rep['bar1Beat']}, truth {pickup}"
            assert abs(rep["bar1Seconds"] - truth[name][1]) < 0.012, \
                f"{name}: bar one at {rep['bar1Seconds']}, truth {truth[name][1]}"
            assert rep["gridErrorAfterMs"]["worstBlock"] < 5, f"{name}: grid {rep['gridErrorAfterMs']}"
        results, failures = verify(cfg, root)
        # This sparse take has so little at its seams that the codecs' mismatch between
        # the two copies of the head stands out (12 dB on AAC). It's a real effect, which
        # dense takes mask, and verify stays strict on the real assets. Only this may pass.
        failures = [f for f in failures if "wrap adds top end" not in f]
        assert not failures, failures
        for name in ("low", "mid", "high"):
            row = results["test"]["takes"][name]["opus"]
            assert row["seam"]["stepRatio"] < 2.0, f"{name}: seam {row['seam']}"
        take = manifest["levels"]["test"]["takes"]["low"]
        assert abs(take["loopEndSeconds"] - take["loopStartSeconds"] - 8 * 4 * 60 / 100) < 1 / SR
        assert len(manifest["levels"]["test"]["transitions"]) == 5

        # One performance on one grid: the layers share bars and stay on their parent's
        # beats at their own tempos, with no written transition.
        layered = json.loads(json.dumps(cfg))
        layered["levels"] = [{"id": "layers", "key": "A minor", "next": None, "successBars": 2, "successFinal": True,
                              "gridTier": "mid", "layerFadeBeats": 1,
                              "tiers": [{"name": "low", "source": "mid.flac", "bpm": 102, "loopBars": 8, "targetLufs": -17, "eq": []},
                                        {"name": "mid", "source": "mid.flac", "bpm": 106, "loopBars": 8, "targetLufs": -16, "eq": []},
                                        {"name": "high", "source": "mid.flac", "bpm": 110, "loopBars": 8, "targetLufs": -15, "eq": [],
                                         "layer": [{"source": "mid.flac", "part": "percussive", "db": -6}]}]}]
        (root / "out" / "manifest.json").unlink()
        manifest, _ = build(layered, None, root, workers=3, report_path=root / "report2.json")
        entry = manifest["levels"]["layers"]
        assert entry["layerFadeBeats"] == 1 and entry["transitions"] == []
        assert {t["bars"] for t in entry["takes"].values()} == {8}
        results, failures = verify(layered, root)
        failures = [f for f in failures if "wrap adds top end" not in f]
        assert not failures, failures
        assert all(abs(r["lagMedianMs"]) <= 12 for r in results["layers"]["layers"].values()), results["layers"]["layers"]

        # Cuts: an entry for every second exit bar, each a real bar of the destination.
        cuts = json.loads(json.dumps(cfg))
        cuts["levels"][0]["joinStyle"] = "cuts"
        (root / "out" / "manifest.json").unlink()
        manifest, _ = build(cuts, None, root, workers=3, report_path=root / "report3.json")
        entry = manifest["levels"]["test"]
        assert entry["transitions"] == [] and len(entry["cuts"]) == 5
        for cut in entry["cuts"]:
            assert len(cut["entryBars"]) == 4 and all(0 <= e < 8 and e % 2 == 0 for e in cut["entryBars"]), cut
    print("self-test passed")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--config")
    parser.add_argument("--root", help="build and verify here instead of the repository, for trying a config")
    parser.add_argument("command", nargs="?", choices=["build", "verify", "listen"])
    parser.add_argument("target", nargs="?", help="listen: the directory to fill")
    parser.add_argument("--level", action="append", help="build: only this level, and repeatable")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if not args.command:
        parser.error("name a command, or --self-test")
    limit_process()
    cfg = load_config(args.config)
    root = pathlib.Path(args.root).resolve() if args.root else REPO
    log_dir = root if args.root else HERE
    if args.command == "build":
        build(cfg, set(args.level) if args.level else None, root, report_path=log_dir / "report.json")
    elif args.command == "verify":
        results, failures = verify(cfg, root)
        (log_dir / "verify.json").write_text(json.dumps(results, indent=1) + "\n")
        for failure in failures:
            print("FAIL", failure)
        print(f"{len(failures)} failures")
        return 1 if failures else 0
    else:
        if not args.target:
            parser.error("listen needs a directory")
        print(listen(cfg, args.target))
    return 0


if __name__ == "__main__":
    sys.exit(main())
