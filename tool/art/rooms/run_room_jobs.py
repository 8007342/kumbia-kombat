#!/usr/bin/env python3
"""Run a room's jobs-*.json from any worktree, one job at a time, and copy each output to the art cache.

studio.run_workflow only reads workflows in the main checkout, and a worktree outside it can't name its own
baked workflow. The room graphs differ only in prompt and file prefix, so each job sends the billiards run's
committed graph with the same number of input images (art_runs/rooms/billiards/run-a/workflows/p1 or p2,
present in the main checkout) and puts this job's baked prompt, prefix, size and the 2511 LoRA in as node overrides.
The baked workflow in art_runs/<run>/workflows/ stays the record; this script refuses to run if the graphs
differ in anything but those fields.

Outputs land in ~/.cache/tillandsias-project/kumbia-art/<run>/<job>-<seed>.png with provenance, the same
names `rooms.py collect` writes, and a line per job goes to `<run cache>/elapsed.jsonl` for the ledger.

Usage: run_room_jobs.py --jobs art_runs/rooms/<room>/<run>/jobs-p1.json [--only NAME] [--count N]
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pipeline"))
from run_jobs import Lane  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
MAIN = Path("/home/forge/src/kumbia-kombat")
GRAPHS = {1: "art_runs/rooms/billiards/run-a/workflows/p1.api.json", 2: "art_runs/rooms/billiards/run-a/workflows/p2.api.json"}
LORA = "Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"
CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"


def strip(wf: dict) -> dict:
    wf = json.loads(json.dumps(wf))
    wf["10"]["inputs"]["prompt"] = ""
    wf["14"]["inputs"]["filename_prefix"] = ""
    wf.get("30", {}).get("inputs", {}).pop("lora_name", None)
    for k in ("width", "height"):
        wf["8"]["inputs"].pop(k, None)
    return wf


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--jobs", required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--count", type=int)
    a = ap.parse_args()
    doc = json.loads((ROOT / a.jobs).read_text())
    graph = GRAPHS[doc["passNo"]]
    lane = Lane()
    out = CACHE / doc["run"]
    out.mkdir(parents=True, exist_ok=True)
    for job in doc["jobs"]:
        if a.only and job["name"] not in a.only.split(","):
            continue
        baked = json.loads((ROOT / job["workflow"]).read_text())
        if strip(baked) != strip(json.loads((MAIN / graph).read_text())):
            sys.exit(f"{job['workflow']} differs from {graph} in more than prompt and prefix; can't stand in")
        count = a.count or job["count"]
        args = dict(workflow=graph, inputs=job["inputs"], count=count,
                    overrides={**job["overrides"], "$node:10.prompt": baked["10"]["inputs"]["prompt"],
                               "$node:14.filename_prefix": baked["14"]["inputs"]["filename_prefix"], "$node:30.lora_name": LORA,
                               "$node:8.width": baked["8"]["inputs"]["width"], "$node:8.height": baked["8"]["inputs"]["height"]})
        t = time.time()
        for attempt in range(3):
            try:
                res = lane.call("studio.run_workflow", args)
                if res.get("isError"):
                    raise RuntimeError(json.dumps(res)[:600])
                break
            except (RuntimeError, ConnectionError, OSError) as e:
                print(f"retry {job['name']} {attempt + 1}: {e}", flush=True)
                time.sleep(20)
                lane = Lane()
        else:
            print(f"FAILED {job['name']}", flush=True)
            continue
        wall = time.time() - t
        text = "".join(c.get("text", "") for c in res.get("content", []))
        try:
            body = json.loads(text)
        except json.JSONDecodeError:
            body = {"raw": text}
        n = 0
        for prov in sorted(Path("/work/tmp/imagegen/studio").glob("st-*/*.provenance.json"), key=lambda p: p.stat().st_mtime):
            if prov.stat().st_mtime < t:
                continue
            pd = json.loads(prov.read_text())
            png = prov.with_name(prov.name.removesuffix(".provenance.json"))
            if not png.exists() or doc["run"] not in json.dumps(pd.get("overrides", pd)):
                continue
            shutil.copy(png, out / f"{job['name']}-{pd['seed']}.png")
            shutil.copy(prov, out / f"{job['name']}-{pd['seed']}.provenance.json")
            n += 1
        rec = dict(job=job["name"], count=count, wall_s=round(wall), elapsed_s=body.get("elapsed_s"), copied=n)
        with open(out / "elapsed.jsonl", "a") as f:
            f.write(json.dumps(rec) + "\n")
        print("ok", json.dumps(rec), flush=True)
        if not n:
            print(text[:1500], flush=True)
    print("DONE", flush=True)


if __name__ == "__main__":
    main()
