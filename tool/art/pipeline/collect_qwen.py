#!/usr/bin/env python3
"""Copy a run's finished studio outputs to the persistent art cache, sorted by pose and seed.

The studio folder is deleted when the forge shuts down, so run this during a wave. Provenance
names each output's pose. A seed that ran twice keeps its newest job's frame. Safe to repeat.

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


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    a = ap.parse_args()
    root = Path.home() / ".cache/tillandsias-project/kumbia-art" / a.run / "raw"
    def job_time(p: Path) -> int:
        return int(p.parent.name.split("-")[1])

    for prov in sorted(STUDIO.glob("st-*/*.provenance.json"), key=job_time):
        doc = json.loads(prov.read_text())
        proxy = [i["path"] for i in doc["inputs"] if i["name"] == "pose_proxy"]
        if not proxy or f"/kumbia/{a.run}/" not in proxy[0]:
            continue
        if not proxy[0].endswith(".skeleton.png"):
            continue
        pose = Path(proxy[0]).name.removesuffix(".skeleton.png")
        png = prov.with_name(prov.name.removesuffix(".provenance.json"))
        out = root / pose
        out.mkdir(parents=True, exist_ok=True)
        shutil.copy(png, out / f"{doc['seed']}.png")
        shutil.copy(prov, out / f"{doc['seed']}.provenance.json")
    frames = list(root.glob("*/*.png"))
    print(f"{len(frames)} frames, {len({p.parent.name for p in frames})} poses")


if __name__ == "__main__":
    main()
