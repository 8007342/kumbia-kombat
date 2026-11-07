#!/usr/bin/env python3
"""The pure Python build at a chosen worker count, into a scratch root, for baselines.

  uv run --no-project --with numpy python -I tool/music/mixrs/compare/run_python_build.py WORKERS OUT [LEVEL...]
"""
import importlib.util
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("mix", HERE.parents[1] / "mix" / "mix.py")
mix = importlib.util.module_from_spec(spec)
sys.modules["mix"] = mix
spec.loader.exec_module(mix)

if __name__ == "__main__":
    workers, out = int(sys.argv[1]), pathlib.Path(sys.argv[2]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    cfg = mix.load_config()
    mix.build(cfg, set(sys.argv[3:]) or None, out, workers=workers, report_path=out / "report.json")
