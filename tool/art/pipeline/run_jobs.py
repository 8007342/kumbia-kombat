#!/usr/bin/env python3
"""Run a job list through this lane's studio, one job at a time, from any worktree.

studio.run_workflow only reads workflows inside the main checkout, so a job planned in a worktree can't
name its baked workflow. Each job here sends the committed graph instead, with the baked prompt and the
LoRA as node overrides. It talks to the lane's own MCP socket, the same route the MCP tools use, so the
host's pins, licence checks and GPU queue all apply.

Provenance records an empty `prompt` for this route, because the override isn't a $prompt: the baked
workflow in art_runs/<run>/workflows/ is the record, and --verify compares it with ComfyUI's /history.

Usage: run_jobs.py --run <run> [--skip pose,pose] [--only pose,pose] [--jobs FILE] [--verify]
Skips a pose that already has its candidates in the art cache, so it is safe to restart.
"""
from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[3]
GRAPH = "tool/art/workflows/qwen-frame.api.json"
LORA = "Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"
CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"
STUDIO = os.environ.get("KUMBIA_STUDIO_URL", "http://studio:8188")


class Lane:
    def __init__(self) -> None:
        self.s = socket.socket(socket.AF_UNIX)
        self.s.connect(os.environ["TILLANDSIAS_CONTROL_SOCKET"])
        self.f = self.s.makefile("rwb")
        self.n = 0
        self.rpc("initialize", {"protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": {"name": "run_jobs", "version": "1"}})
        self.f.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}).encode() + b"\n")
        self.f.flush()

    def rpc(self, method: str, params: dict) -> dict:
        self.n += 1
        self.f.write(json.dumps({"jsonrpc": "2.0", "id": self.n, "method": method, "params": params}).encode() + b"\n")
        self.f.flush()
        while True:
            line = self.f.readline()
            if not line:
                raise ConnectionError("the lane closed the connection")
            msg = json.loads(line)
            if msg.get("id") == self.n:
                if "error" in msg:
                    raise RuntimeError(json.dumps(msg["error"])[:400])
                return msg["result"]

    def call(self, tool: str, args: dict) -> dict:
        return self.rpc("tools/call", {"name": tool, "arguments": args})


def args_for(job: dict) -> dict:
    prompt = json.loads((ROOT / job["args"]["workflow"]).read_text())["10"]["inputs"]["prompt"]
    a = dict(job["args"], workflow=GRAPH)
    a["overrides"] = {**job["args"]["overrides"], "$node:30.lora_name": LORA, "$node:10.prompt": prompt}
    return a


def verify(jobs: list[dict]) -> None:
    """What the engine received, against what the plan baked, for each skeleton it still remembers."""
    history = json.load(urlopen(f"{STUDIO}/history?max_items=2000", timeout=60))
    seen: dict[str, set[str]] = {}
    for item in history.values():
        graph = item["prompt"][2]
        image = str(graph.get("2", {}).get("inputs", {}).get("image", ""))
        if image and "prompt" in graph.get("10", {}).get("inputs", {}):
            seen.setdefault(image.split(" ")[0], set()).add(graph["10"]["inputs"]["prompt"])
    good = bad = missing = 0
    for job in jobs:
        want = json.loads((ROOT / job["args"]["workflow"]).read_text())["10"]["inputs"]["prompt"]
        got = seen.get(job["args"]["inputs"]["pose_proxy"]) or next((v for k, v in seen.items() if k.endswith(job["args"]["inputs"]["pose_proxy"].split("/in/")[-1])), None)
        if not got:
            missing += 1
        elif want in got:
            good += 1
        else:
            bad += 1
            print("differs", job["pose"])
    print(f"engine prompts: {good} match, {bad} differ, {missing} not in history")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    ap.add_argument("--jobs", default="jobs.json")
    ap.add_argument("--skip", default="")
    ap.add_argument("--only", default="")
    ap.add_argument("--verify", action="store_true")
    a = ap.parse_args()
    jobs = json.loads((ROOT / "art_runs" / a.run / a.jobs).read_text())
    if a.verify:
        verify(jobs)
        return
    skip, only = set(filter(None, a.skip.split(","))), set(filter(None, a.only.split(",")))
    lane = Lane()
    raw = CACHE / a.run / "raw"
    for i, job in enumerate(jobs):
        pose = job["pose"]
        have = len(list((raw / pose).glob("*.png"))) if (raw / pose).is_dir() else 0
        if pose in skip or (only and pose not in only) or have >= job["args"]["count"]:
            continue
        for attempt in range(3):
            t = time.time()
            try:
                res = lane.call("studio.run_workflow", args_for(job))
                text = json.dumps(res)
                if res.get("isError"):
                    raise RuntimeError(text[:400])
                print(f"ok {i + 1}/{len(jobs)} {pose} {time.time() - t:.0f}s", flush=True)
                break
            except (RuntimeError, ConnectionError, OSError) as e:
                print(f"retry {pose} {attempt + 1}: {e}", flush=True)
                time.sleep(20)
                if isinstance(e, (ConnectionError, OSError)):
                    lane = Lane()
        else:
            print(f"FAILED {pose}", flush=True)
            continue
        subprocess.run([sys.executable, str(ROOT / "tool/art/pipeline/collect_qwen.py"), "--run", a.run], cwd=ROOT, capture_output=True)
    print("WAVE DONE", flush=True)


if __name__ == "__main__":
    main()
