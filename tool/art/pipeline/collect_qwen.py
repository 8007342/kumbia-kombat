#!/usr/bin/env python3
"""Copy a run's finished studio outputs to the persistent art cache, sorted by pose and seed.

The studio folder is deleted when the forge shuts down, so run this during a wave. Provenance
names each output's pose: by its skeleton's file name, or, for a job with no skeleton (sheet views,
frames posed by words), by its per-pose workflow's file name. A seed that ran twice keeps its newest
job's frame. Safe to repeat.

Usage: collect_qwen.py --run <run>
Writes ~/.cache/tillandsias-project/kumbia-art/<run>/raw/<pose>/<seed>.png with its provenance,
and prints how many frames it holds.
"""
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

STUDIO = Path("/work/tmp/imagegen/studio")


def pose_of(doc: dict, run: str) -> str | None:
    """Which pose of this run a provenance record belongs to, or None if it's another run's."""
    proxy = [i["path"] for i in doc.get("inputs", []) if i["name"] == "pose_proxy"]
    if proxy:
        if f"/kumbia/{run}/" in proxy[0] and proxy[0].endswith(".skeleton.png"):
            return Path(proxy[0]).name.removesuffix(".skeleton.png")
        return None
    path = (doc.get("workflow") or {}).get("path", "")
    if f"art_runs/{run}/workflows/" in path and path.endswith(".api.json"):
        return Path(path).name.removesuffix(".api.json")
    return None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    a = ap.parse_args()
    root = Path.home() / ".cache/tillandsias-project/kumbia-art" / a.run / "raw"
    def job_time(p: Path) -> int:
        return int(p.parent.name.split("-")[1])

    for prov in sorted(STUDIO.glob("st-*/*.provenance.json"), key=job_time):
        doc = json.loads(prov.read_text())
        pose = pose_of(doc, a.run)
        if pose is None:
            continue
        png = prov.with_name(prov.name.removesuffix(".provenance.json"))
        out = root / pose
        out.mkdir(parents=True, exist_ok=True)
        shutil.copy(png, out / f"{doc['seed']}.png")
        shutil.copy(prov, out / f"{doc['seed']}.provenance.json")
    frames = list(root.glob("*/*.png"))
    print(f"{len(frames)} frames, {len({p.parent.name for p in frames})} poses")


if __name__ == "__main__":
    main()
