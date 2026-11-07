#!/usr/bin/env python3
"""Per-step wall time and peak RSS of the Python build, one worker, in one process.

  OPENBLAS_NUM_THREADS=1 MIX_ENGINE=python uv run --no-project --with numpy python -I \
      tool/music/mixrs/compare/profile_python.py LEVEL OUT_DIR [CONFIG]

MIX_PY names another mix.py to profile; WHOLE_TAKE_HPSS=1 separates whole takes, as the
build that stalled the forge did.

Wraps mix.py's own functions. Peak is VmHWM, reset through /proc/self/clear_refs at each
call. "excl_s" leaves out time in wrapped functions called from inside. ffmpeg's own RSS
isn't counted: it's a separate process, and its peak appears at the end as children_peak.
"""
import collections
import importlib.util
import json
import os
import pathlib
import resource
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
MIX = os.environ.get("MIX_PY") or HERE.parents[1] / "mix" / "mix.py"
spec = importlib.util.spec_from_file_location("mix", MIX)
mix = importlib.util.module_from_spec(spec)
sys.modules["mix"] = mix
spec.loader.exec_module(mix)

NAMES = """decode loudness encode codec_peak onset_envelope fit_tempo _attack_curve _track_offsets
_smooth_curve phase_wander_ms grid_error_ms grid_bias_seconds beat_times wsola shelf_eq beat_features
find_bar_one measure_key choose_loop limit master_loop hpss prepare_tier write_asset decode_offset
render_transition render_success render_bridge cut_table bar_features outgoing_at _hpss_block""".split()


def hwm():
    for line in open("/proc/self/status"):
        if line.startswith("VmHWM"):
            return int(line.split()[1]) / 1024
    return 0.0


def rss():
    for line in open("/proc/self/status"):
        if line.startswith("VmRSS"):
            return int(line.split()[1]) / 1024
    return 0.0


def reset():
    with open("/proc/self/clear_refs", "w") as f:
        f.write("5")


stats = collections.defaultdict(lambda: {"calls": 0, "s": 0.0, "excl_s": 0.0, "peak_mb": 0.0, "added_mb": 0.0})
stack = []


def wrap(name, fn):
    def inner(*a, **k):
        if stack:
            stack[-1]["peak"] = max(stack[-1]["peak"], hwm())
        reset()
        frame = {"peak": 0.0, "child": 0.0, "at": rss()}
        stack.append(frame)
        t = time.perf_counter()
        try:
            return fn(*a, **k)
        finally:
            dt = time.perf_counter() - t
            stack.pop()
            peak = max(frame["peak"], hwm())
            row = stats[name]
            row["calls"] += 1
            row["s"] += dt
            row["excl_s"] += dt - frame["child"]
            row["peak_mb"] = max(row["peak_mb"], peak)
            row["added_mb"] = max(row["added_mb"], peak - frame["at"])
            if stack:
                stack[-1]["child"] += dt
                stack[-1]["peak"] = max(stack[-1]["peak"], peak)
    return inner


class Serial:
    """Stands in for the process pool: one worker, here, so everything is measured."""
    def __init__(self, **_):
        pass
    def __enter__(self):
        return self
    def __exit__(self, *_):
        return False
    def map(self, fn, jobs):
        return [fn(j) for j in jobs]


def main():
    level, out = sys.argv[1], pathlib.Path(sys.argv[2]).resolve()
    for name in NAMES:
        if hasattr(mix, name):
            setattr(mix, name, wrap(name, getattr(mix, name)))
    mix.futures.ProcessPoolExecutor = Serial
    if os.environ.get("WHOLE_TAKE_HPSS"):
        mix.HPSS_CHUNK_SECONDS = 100000
    if hasattr(mix, "limit_process"):
        mix.limit_process = lambda: None
    cfg = mix.load_config(sys.argv[3] if len(sys.argv) > 3 else None)
    out.mkdir(parents=True, exist_ok=True)
    start = time.perf_counter()
    mix.build(cfg, {level}, out, report_path=out / "report.json")
    wall = time.perf_counter() - start
    self_peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024
    kids = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss / 1024
    rows = sorted(stats.items(), key=lambda kv: -kv[1]["excl_s"])
    print(f"{'step':22}{'calls':>6}{'total s':>9}{'excl s':>9}{'peak MB':>9}{'added MB':>9}")
    for name, r in rows:
        print(f"{name:22}{r['calls']:>6}{r['s']:>9.1f}{r['excl_s']:>9.1f}{r['peak_mb']:>9.0f}{r['added_mb']:>9.0f}")
    print(f"wall {wall:.1f} s, self peak {self_peak:.0f} MB, largest child {kids:.0f} MB")
    (out / "profile.json").write_text(json.dumps({"level": level, "wall_s": wall, "self_peak_mb": self_peak,
                                                  "children_peak_mb": kids, "steps": stats}, indent=1))


if __name__ == "__main__":
    main()
