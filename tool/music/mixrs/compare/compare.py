#!/usr/bin/env python3
"""Rust build against Python build: reports, manifest, verify rows and decoded audio.

  uv run --no-project --with numpy python -I tool/music/mixrs/compare/compare.py PY_ROOT RS_ROOT

Each root comes from run_python_build.py, one with MIX_ENGINE=python, one with mixrs. Exits 1
past a tolerance. Decisions (integers, strings, booleans) must be equal. Numbers get the
tolerances below; ebur128 prints one decimal, so its readings can differ by a step. Audio is
compared after decoding, as the residual under the signal, in dB.
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
    "maxReductionDb": 0.11, "limitedShare": 0.001, "tagScore": 0.002, "harmonyMatch": 0.002,
}
# Identical audio can still hold different lossy decisions once a sample's last bit moves.
AUDIO_LIMIT_DB = -40.0


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


def decode(path):
    raw = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", str(path), "-ac", "2", "-ar", "48000", "-f", "f32le", "-"],
                         check=True, stdout=subprocess.PIPE).stdout
    return np.frombuffer(raw, dtype=np.float32)


def main():
    py, rs = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    wrong, rows = [], {}
    for name in ("report.json", "verify.json", "assets/music/rendered/manifest.json"):
        if (py / name).exists() and (rs / name).exists():
            walk(json.loads((py / name).read_text()), json.loads((rs / name).read_text()), name, rows, wrong)
        else:
            print(f"not compared, missing on a side: {name}")
    print(f"{'measure':28}{'worst gap':>12}{'allowed':>10}")
    for key, (gap, limit) in sorted(rows.items(), key=lambda kv: -kv[1][0] / kv[1][1]):
        print(f"{key:28}{gap:>12.4f}{limit:>10.3f}")
    files = sorted(p.relative_to(py) for p in (py / "assets/music/rendered").rglob("*") if p.suffix in (".ogg", ".m4a"))
    results = []
    for rel in files:
        if not (rs / rel).exists():
            wrong.append(f"{rel}: no Rust file")
            continue
        a, b = decode(py / rel), decode(rs / rel)
        if len(a) != len(b):
            wrong.append(f"{rel}: {len(a)} samples against {len(b)}")
            continue
        db = 10 * np.log10(max(np.mean((a - b) ** 2), 1e-20) / max(np.mean(a ** 2), 1e-20))
        results.append((float(db), str(rel)))
        if db > AUDIO_LIMIT_DB:
            wrong.append(f"{rel}: residual {db:.1f} dB, past {AUDIO_LIMIT_DB}")
    if results:
        values = sorted(r[0] for r in results)
        print(f"{len(results)} decoded files: residual median {values[len(values) // 2]:.1f} dB, worst {values[-1]:.1f} dB "
              f"({max(results)[1]})")
    print(f"{len(wrong)} past tolerance")
    for line in wrong[:60]:
        print("  " + line)
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
