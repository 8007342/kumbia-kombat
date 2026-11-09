#!/usr/bin/env python3
"""Vertical layering: every tier of a room from one recording, getting denser.

  uv run --no-project --with numpy --with scipy --with soundfile python -I \
      tool/music/layer/layer.py LEVEL [--out DIR]

Reads tool/music/layer/tiers.json. For one level:

1. The base is one performance (the approved mid take). Its parts are split with
   soft masks on one STFT: percussive and harmonic (median-filter HPSS), the
   harmonic split again into bass (under `bassHz`) and upper, and the upper into
   centre (L+R) and sides (L-R). The masks come from the mono magnitude, so the
   same mask applies to both channels and the stereo image is kept.
2. With every gain at 1 the parts sum back to the base exactly (checked: the
   residual is printed), so mid can be the recording itself.
3. Each tier is a gain per part. A tier may also add parts of an `add` take: a
   second render of the same performance on the same clock (one ACE pass from the
   base, never a chain). Its added sides are narrowed by `addWidth` so the image
   can't collapse the way chained passes did.
4. Tiers are written at the base's own tempo. Tempo steps are done after, with
   rubberband (audio.transform time_stretch), not here.

Nothing here says the result sounds good. It only keeps one recording.
"""
import argparse, json, os, pathlib, sys
import numpy as np
import soundfile as sf
from scipy.ndimage import median_filter
from scipy.signal import stft, istft

HERE = pathlib.Path(__file__).resolve().parent
N, HOP = 4096, 1024
PARTS = ("perc", "bass", "center", "side")


def spectra(x, sr):
    _, _, z = stft(x.T, fs=sr, nperseg=N, noverlap=N - HOP, boundary="even", padded=True)
    return z.astype(np.complex64)  # (2, freq, frames)


def back(z, sr, length):
    _, y = istft(z, fs=sr, nperseg=N, noverlap=N - HOP, boundary=True)
    return y.T[:length].astype(np.float64)


def novel(add, base, sr, cfg):
    """What the add take has that the base doesn't: its energy above the base's,
    cell by cell (smoothed over a few frames and bins), with the add's own phase.
    New instruments sit where the base is quiet; doubled hits cancel out of it."""
    za, zb = spectra(add, sr), spectra(base, sr)
    ea = median_filter((np.abs(za) ** 2).mean(axis=0), size=(3, 5), mode="nearest")
    eb = median_filter((np.abs(zb) ** 2).mean(axis=0), size=(3, 5), mode="nearest")
    over = cfg.get("novelOverDb", 3.0)
    m = np.clip(1 - db(over * 2) * eb / (ea + 1e-12), 0, 1)
    return back(za * np.sqrt(m)[None].astype(np.float32), sr, len(add))


def split(x, sr, cfg):
    """The base's parts, as a dict of stereo arrays that sum back to x."""
    z = spectra(x, sr)
    mag = np.abs(z).mean(axis=0)
    h = median_filter(mag, size=(1, cfg.get("harmFrames", 17)), mode="nearest")
    p = median_filter(mag, size=(cfg.get("percBins", 17), 1), mode="nearest")
    mh = h * h / (h * h + p * p + 1e-12)
    f = np.fft.rfftfreq(N, 1 / sr)[:, None]
    bass_hz = cfg.get("bassHz", 160)
    low = np.clip((bass_hz * 1.25 - f) / (bass_hz * 0.5), 0, 1)  # a soft crossover
    harm = z * mh
    parts = {"perc": z * (1 - mh), "bass": harm * low}
    upper = harm * (1 - low)
    c = (upper[0] + upper[1]) / 2
    s = (upper[0] - upper[1]) / 2
    parts["center"] = np.stack([c, c])
    parts["side"] = np.stack([s, -s])
    return {k: back(v, sr, len(x)) for k, v in parts.items()}


def tilt(y, sr, db_per_oct, above):
    """A gentle shelf as a spectral tilt above `above` Hz, on the whole part."""
    if not db_per_oct:
        return y
    z = spectra(y, sr)
    f = np.fft.rfftfreq(N, 1 / sr)
    g = np.where(f > above, 10 ** (db_per_oct * np.log2(np.maximum(f, above) / above) / 20), 1.0)
    return back(z * g[None, :, None].astype(np.float32), sr, len(y))


def db(v):
    return 10 ** (v / 20)


def load(path, length=None):
    x, sr = sf.read(os.path.expanduser(path), always_2d=True, dtype="float64")
    if length is not None:
        x = np.pad(x, ((0, max(0, length - len(x))), (0, 0)))[:length]
    return x, sr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("level")
    ap.add_argument("--out")
    a = ap.parse_args()
    spec = json.loads((HERE / "tiers.json").read_text())
    root = spec["mastersDir"]
    lv = spec["levels"][a.level]
    out = pathlib.Path(os.path.expanduser(a.out or f"{root}/{spec['outDir']}/{a.level}"))
    out.mkdir(parents=True, exist_ok=True)

    base, sr = load(f"{root}/{lv['base']}")
    parts = split(base, sr, lv)
    resid = base - sum(parts.values())
    print(f"{a.level}: parts sum back to the base, residual "
          f"{20 * np.log10(np.abs(resid).max() / np.abs(base).max() + 1e-12):.1f} dB")
    add = None
    if lv.get("add"):
        ax, asr = load(f"{root}/{lv['add']}", len(base))
        assert asr == sr, "the add take must share the base's rate"
        if lv.get("addNovel"):
            ax = novel(ax, base, sr, lv)
            sf.write(out / "add-novel.flac", ax, sr, subtype="PCM_24")
        add = split(ax, sr, lv)

    report = {"level": a.level, "base": lv["base"], "add": lv.get("add"), "tiers": {}}
    for name, t in lv["tiers"].items():
        y = np.zeros_like(base)
        for part in PARTS:
            g = db(t.get(part, 0.0))
            piece = parts[part] * g
            if part in ("center", "side") and t.get("tiltDb"):
                piece = tilt(piece, sr, t["tiltDb"], t.get("tiltHz", 1200))
            y += piece
        for part, gdb in t.get("add", {}).items():
            piece = add[part] * db(gdb)
            if part == "side":
                piece = piece * lv.get("addWidth", 0.5)
            y += piece
        # Never rescaled: the mixer sets loudness, and its beat and bar-one analysis
        # is level-sensitive (a trimmed mid moved terraza's bar one by a beat). Float
        # WAV holds peaks over full scale; rubberband and ffmpeg both read it.
        peak = np.abs(y).max()
        path = out / f"{name}.wav"
        sf.write(path, y.astype(np.float32), sr, subtype="FLOAT")
        report["tiers"][name] = {"file": str(path), "gains": t, "peakDb": round(20 * np.log10(peak), 2)}
        print(f"  {name}: {path}")
    (out / "layer.json").write_text(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
