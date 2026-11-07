#!/usr/bin/env python3
"""Gather one family's frames from several runs into one folder, later runs winning per pose, ready to register.

Usage: merge_runs.py OUT_RUN RUN [RUN ...]
Writes ~/.cache/tillandsias-project/kumbia-art/OUT_RUN/raw/<pose>/ as hard links, leaving the source runs alone.
"""
import os
import sys
from pathlib import Path

CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"
out = CACHE / sys.argv[1] / "raw"
out.mkdir(parents=True, exist_ok=True)
for run in sys.argv[2:]:
    for pose in sorted(p for p in (CACHE / run / "raw").iterdir() if p.is_dir()):
        dst = out / pose.name
        if dst.is_symlink():
            dst.unlink()
        dst.mkdir(exist_ok=True)
        for old in dst.iterdir():
            old.unlink()
        for f in pose.iterdir():
            os.link(f, dst / f.name)
print(len(list(out.iterdir())), "poses")
