#!/usr/bin/env python3
"""Copy studio outputs off the lane volume into art_runs/<run>/raw/.

The agent saves each studio.run_workflow result verbatim as
art_runs/<run>/results/<pose-id>.json. This walks every result, finds the
output PNGs (and the provenance JSON beside each), and copies them to
art_runs/<run>/raw/<pose-id>/<k>.<rgb|rgba>.png with their provenance, so the
run survives forge teardown. It also writes art_runs/<run>/raw/index.json
(pose -> candidates) for contact sheets and review.

Usage: python3 tool/art/pipeline/collect.py --run <run> [--from-disk]

--from-disk skips results/: it scans /work/tmp/imagegen/studio/*/ provenance
sidecars and assigns each output to a pose by workflow + init_image path from
jobs.json and to a candidate by seed - job seed. It also writes the matching
results/<pose>.json (the outputs list rebuilt from the sidecars), so a big run
need not pass every tool result through the agent's context.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path

from PIL import Image

PNG = re.compile(r"/work/tmp/imagegen/[^\s\"']+?\.png")


STUDIO = Path("/work/tmp/imagegen/studio")


def rebuild_results(run: Path) -> None:
    jobs = json.loads((run / "jobs.json").read_text())
    by_init = {j["args"]["init_image"]: j for j in jobs}
    found: dict[str, dict[int, dict]] = {}
    for prov_path in sorted(STUDIO.glob("*/*.png.provenance.json"), key=lambda p: p.stat().st_mtime):
        prov = json.loads(prov_path.read_text())
        init = next((i["path"] for i in prov.get("inputs", []) if i["name"] == "init_image"), None)
        job = by_init.get(init)
        if job is None or prov.get("workflow", {}).get("path") != job["args"]["workflow"]:
            continue
        k = prov["seed"] - job["args"]["overrides"]["seed"]
        if not 0 <= k < job["args"]["count"]:
            continue
        png = str(prov_path).removesuffix(".provenance.json")
        # newest run of a pose wins (sorted by mtime)
        found.setdefault(job["pose"], {})[k] = {"path": png, "seed": prov["seed"],
                                                "provenance_path": str(prov_path)}
    (run / "results").mkdir(exist_ok=True)
    for pose, cands in found.items():
        outs = [cands[k] for k in sorted(cands)]
        (run / "results" / f"{pose}.json").write_text(json.dumps(
            {"rebuiltFrom": "provenance sidecars", "outputs": outs}, indent=1) + "\n")
    missing = sorted({j["pose"] for j in jobs} - set(found))
    print(f"rebuilt results for {len(found)} poses; missing {len(missing)}: {' '.join(missing)}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    ap.add_argument("--from-disk", action="store_true")
    a = ap.parse_args()
    run = Path("art_runs") / a.run
    if a.from_disk:
        rebuild_results(run)
    index: dict[str, list[dict]] = {}
    for res in sorted((run / "results").glob("*.json")):
        pose = res.stem
        text = res.read_text()
        pngs = sorted(set(PNG.findall(text)))
        dst_dir = run / "raw" / pose
        dst_dir.mkdir(parents=True, exist_ok=True)
        rgb = [p for p in pngs if "frame_rgba" not in Path(p).name]
        rgba = [p for p in pngs if "frame_rgba" in Path(p).name]
        if not rgba and rgb and Image.open(rgb[0]).mode in ("RGBA", "LA"):
            rgb, rgba = rgb, rgb  # single RGBA save: the frame is its own matte
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
