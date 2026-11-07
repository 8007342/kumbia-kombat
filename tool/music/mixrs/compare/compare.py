#!/usr/bin/env python3
"""Rust build against Python build: reports, manifest, verify rows and decoded audio.

  uv run --no-project --with numpy python -I tool/music/mixrs/compare/compare.py PY_ROOT RS_ROOT

Each root comes from run_python_build.py with DUMP_RAW=1, one with MIX_ENGINE=python, one with
mixrs. Exits 1 past a tolerance. Decisions (integers, strings, booleans) must be equal. Numbers
get the tolerances below; ebur128 prints one decimal, so its readings can differ by a step.

Audio is compared before encoding, as the residual under the signal, in dB, because ffmpeg's
AAC encoder is chaotic: flip the last bit of some samples and its output moves by about -20 dB
(aac_sensitivity measures that here). So AAC-derived numbers aren't held to tolerances, only
their decisions, and a tier whose first decoded AAC peak fell either side of the -0.3 dB limit
masters at a different ceiling on the two sides. Such a tier is listed, and its own numbers
and whatever is built from it are reported rather than failed, with its raw residual shown.
"""
import json
import pathlib
import subprocess
import sys

import numpy as np

# By last key name. Everything else takes DEFAULT.
DEFAULT = 0.011
TOLERANCE = {
    "lufs": 0.11, "lra": 0.11, "truePeakDb": 0.11, "decodedPeakDb": 0.11, "makeupDb": 0.11, "ceilingDb": 0.11,
    "gainDb": 0.11, "beatRmsDb": 0.11, "wrapResidualDb": 3.0, "burstDb": 1.0, "stepRatio": 0.2,
    "wrapJumpDb": 0.05, "otherBarsP90JumpDb": 0.05, "driftEndsMs": 2.1, "driftWorstMs": 2.1,
    "shareOfLoopStepsAbovePct": 0.5, "pulseBpm": 0.005, "measuredBpm": 0.002, "bpmAfterWarp": 0.002,
    "errorPct": 0.002, "lagMedianMs": 2.0, "lagWorstMs": 2.0, "envelopeCorr": 0.02,
    "wanderMs": 0.1, "loopMaxStep": 0.02, "step": 0.02, "stepStraightThrough": 0.02, "maxReductionDb": 0.11, "limitedShare": 0.001, "tagScore": 0.002, "harmonyMatch": 0.002,
}
RAW_LIMIT_DB = -80.0


def walk(a, b, path, rows, wrong):
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            if k not in a or k not in b:
                wrong.append(f"{path}/{k}: only on one side")
            else:
                walk(a[k], b[k], f"{path}/{k}", rows, wrong)
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            wrong.append(f"{path}: {len(a)} items against {len(b)}")
        for i, (x, y) in enumerate(zip(a, b)):
            walk(x, y, f"{path}[{i}]", rows, wrong)
    elif isinstance(a, float) or isinstance(b, float):
        if isinstance(a, bool) or isinstance(b, bool) or a is None or b is None:
            wrong.append(f"{path}: {a!r} against {b!r}")
            return
        key = path.split("/")[-1].split("[")[0]
        limit = TOLERANCE.get(key, DEFAULT)
        gap = abs(a - b)
        rows[key] = max(rows.get(key, (0.0, limit)), (gap, limit))
        if gap > limit:
            wrong.append(f"{path}: {a} against {b}, past {limit}")
    elif a != b:
        wrong.append(f"{path}: {a!r} against {b!r}")


def raw_residual(a, b):
    return float(10 * np.log10(max(np.mean((a - b) ** 2), 1e-20) / max(np.mean(a ** 2), 1e-20)))


def aac_sensitivity(raw_file):
    """Encode the same audio twice, then with last-bit noise, and compare the decodings."""
    audio = np.fromfile(raw_file, dtype=np.float32)
    def through(x):
        run = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-f", "f32le", "-ar", "48000", "-ac", "2", "-i", "-",
                              "-c:a", "aac", "-b:a", "128k", "-fflags", "+bitexact", "-flags", "+bitexact",
                              "-f", "adts", "-"], input=x.tobytes(), check=True, stdout=subprocess.PIPE)
        out = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-f", "aac", "-i", "-", "-ac", "2", "-ar", "48000", "-f", "f32le", "-"],
                             input=run.stdout, check=True, stdout=subprocess.PIPE).stdout
        return np.frombuffer(out, dtype=np.float32)
    rng = np.random.default_rng(1)
    toward = np.where(rng.random(len(audio)) < 0.5, np.float32(np.inf), np.float32(-np.inf)).astype(np.float32)
    nudged = np.nextafter(audio, toward)
    plain = through(audio)
    return raw_residual(plain, through(audio)), raw_residual(plain, through(nudged))


def decode(path):
    raw = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", str(path), "-ac", "2", "-ar", "48000", "-f", "f32le", "-"],
                         check=True, stdout=subprocess.PIPE).stdout
    return np.frombuffer(raw, dtype=np.float32)


def main():
    py, rs = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    wrong, rows, notes = [], {}, []
    moved = set()
    reports = [json.loads((r / "report.json").read_text()) for r in (py, rs)]
    for lid, level in reports[0].items():
        for name, tier in level["tiers"].items():
            if tier["ceilingDb"] != reports[1][lid]["tiers"][name]["ceilingDb"]:
                moved.add((lid, name))
                notes.append(f"{lid}/{name}: ceiling {tier['ceilingDb']} against {reports[1][lid]['tiers'][name]['ceilingDb']}, "
                             "the AAC peak test falling differently")

    def excused(line):
        if "/aac/" in line or "decodedPeakDb" in line:
            return True
        return any(f"/{lid}/" in line and (f"/{name}/" in line or name in line.split(":")[0].split("/")) for lid, name in moved)

    for name in ("report.json", "verify.json", "assets/music/rendered/manifest.json"):
        if (py / name).exists() and (rs / name).exists():
            found = []
            walk(json.loads((py / name).read_text()), json.loads((rs / name).read_text()), name, rows, found)
            for line in found:
                (notes if excused(line) else wrong).append(line)
        else:
            print(f"not compared, missing on a side: {name}")
    print(f"{'measure':28}{'worst gap':>12}{'allowed':>10}")
    for key, (gap, limit) in sorted(rows.items(), key=lambda kv: -kv[1][0] / kv[1][1])[:24]:
        print(f"{key:28}{gap:>12.4f}{limit:>10.3f}")
    results = []
    for path in sorted((py / "raw").glob("*.f32")):
        other = rs / "raw" / path.name
        a, b = np.fromfile(path, dtype=np.float32), np.fromfile(other, dtype=np.float32)
        if len(a) != len(b):
            wrong.append(f"{path.name}: {len(a)} samples against {len(b)}")
            continue
        db = raw_residual(a, b)
        results.append((db, path.name))
        tier = path.name.split("__")
        touched = any(t[0] == tier[0] for t in moved)
        if db > RAW_LIMIT_DB:
            (notes if touched else wrong).append(f"raw {path.name}: residual {db:.1f} dB")
    if results:
        values = sorted(r[0] for r in results)
        print(f"{len(results)} raw assets before encoding: residual median {values[len(values) // 2]:.1f} dB, "
              f"worst {values[-1]:.1f} dB ({max(results)[1]})")
        for db, name in sorted(results)[-8:]:
            print(f"  {db:7.1f} dB  {name}")
    opus = []
    for rel in sorted(p.relative_to(py) for p in (py / "assets/music/rendered").rglob("*.ogg")):
        a, b = decode(py / rel), decode(rs / rel)
        if len(a) == len(b):
            opus.append(raw_residual(a, b))
    if opus:
        opus.sort()
        print(f"{len(opus)} decoded Opus files: residual median {opus[len(opus) // 2]:.1f} dB, worst {opus[-1]:.1f} dB")
    if results:
        same, nudged = aac_sensitivity(py / "raw" / results[0][1])
        print(f"AAC on {results[0][1]}: encoded twice {same:.1f} dB, with last-bit noise {nudged:.1f} dB")
    print(f"{len(notes)} reported, not failed:")
    for line in notes[:40]:
        print("  " + line)
    print(f"{len(wrong)} past tolerance")
    for line in wrong[:60]:
        print("  " + line)
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
