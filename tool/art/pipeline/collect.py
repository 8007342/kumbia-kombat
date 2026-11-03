#!/usr/bin/env python3
"""Copy studio outputs off the lane volume into art_runs/<run>/raw/.

The agent saves each studio.run_workflow result verbatim as
art_runs/<run>/results/<pose-id>.json. This walks every result, finds the
output PNGs (and the provenance JSON beside each), and copies them to
art_runs/<run>/raw/<pose-id>/<k>.<rgb|rgba>.png with their provenance, so the
run survives forge teardown. It also writes art_runs/<run>/raw/index.json
(pose -> candidates) for contact sheets and review.

Usage: python3 tool/art/pipeline/collect.py --run <run>
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path

PNG = re.compile(r"/work/tmp/imagegen/[^\s\"']+?\.png")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    a = ap.parse_args()
    run = Path("art_runs") / a.run
    index: dict[str, list[dict]] = {}
    for res in sorted((run / "results").glob("*.json")):
        pose = res.stem
        text = res.read_text()
        pngs = sorted(set(PNG.findall(text)))
        dst_dir = run / "raw" / pose
        dst_dir.mkdir(parents=True, exist_ok=True)
        rgb = [p for p in pngs if "frame_rgba" not in Path(p).name]
        rgba = [p for p in pngs if "frame_rgba" in Path(p).name]
        cands = []
        for k, src in enumerate(rgb):
            entry = {"k": k}
            for kind, lst in (("rgb", rgb), ("rgba", rgba)):
                if k < len(lst):
                    s = Path(lst[k])
                    d = dst_dir / f"{k}.{kind}.png"
                    shutil.copyfile(s, d)
                    entry[kind] = str(d)
                    for prov in (s.with_suffix(".json"), s.with_suffix(".provenance.json"),
                                 s.parent / (s.name + ".provenance.json")):
                        if prov.exists():
                            shutil.copyfile(prov, dst_dir / f"{k}.{kind}.provenance.json")
                            break
            cands.append(entry)
        index[pose] = cands
    (run / "raw" / "index.json").write_text(json.dumps(index, indent=1) + "\n")
    print(f"collected {sum(len(v) for v in index.values())} candidates for {len(index)} poses")


if __name__ == "__main__":
    main()
