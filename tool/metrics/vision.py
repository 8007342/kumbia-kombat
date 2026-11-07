#!/usr/bin/env python3
"""Ask the local vision model about images, and record the time spent.

    tool/metrics/vision.py "Does any figure have an extra limb?" a.png [b.png ...]

Prints the model's answer on stdout. Uses ollama's /api/chat at
http://inference:11434 with qwen2.5vl:7b and keep_alive 0, so the model leaves
the GPU when it answers. It shares the GPU with ComfyUI, so call it between jobs
(check mcp__host-browser__gpu_status yourself; this script does not).

Appends one line to plan/compute-ledger.jsonl in the git checkout you run it
from (or KUMBIA_COMPUTE_LEDGER). Set KUMBIA_AGENT, or pass --agent, to name
yourself. Stdlib only.

How to ask, from the trial in plan/compute-ledger-2026-11-07.md: crop to one
figure, never a whole sheet, and ask it to count ("How many separate human heads
are drawn in this image? Reply with only a number."; the same for hands). Asked
"is there a fault?" it mostly says NO. A NO or a clean count isn't a pass.
"""
import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

URL = os.environ.get("KUMBIA_VISION_URL", "http://inference:11434")
MODEL = os.environ.get("KUMBIA_VISION_MODEL", "qwen2.5vl:7b")


def ledger_path():
    env = os.environ.get("KUMBIA_COMPUTE_LEDGER")
    if env:
        return env
    try:
        root = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    return os.path.join(root, "plan", "compute-ledger.jsonl")


def ask(question, paths, model=MODEL, keep_alive=0, timeout=900, num_predict=None):
    """Returns (answer, stats). Stats are ollama's own, in seconds."""
    images = []
    for path in paths:
        with open(path, "rb") as f:
            images.append(base64.b64encode(f.read()).decode())
    body = {
        "model": model,
        "stream": False,
        "keep_alive": keep_alive,
        "options": {"temperature": 0},
        "messages": [{"role": "user", "content": question, "images": images}],
    }
    if num_predict:
        body["options"]["num_predict"] = num_predict
    request = urllib.request.Request(
        URL + "/api/chat",
        json.dumps(body).encode(),
        {"Content-Type": "application/json"},
    )
    # The inference host is on the enclave: never route it through a proxy.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    started = time.monotonic()
    with opener.open(request, timeout=timeout) as response:
        reply = json.load(response)
    ns = 1e9
    return reply["message"]["content"], {
        "seconds": round(time.monotonic() - started, 2),
        "load_s": round(reply.get("load_duration", 0) / ns, 2),
        "prompt_s": round(reply.get("prompt_eval_duration", 0) / ns, 2),
        "eval_s": round(reply.get("eval_duration", 0) / ns, 2),
        "eval_tokens": reply.get("eval_count", 0),
    }


def record(agent, what, model, count, stats):
    line = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "agent": agent, "what": what, "kind": "local-vision",
        "seconds": stats["seconds"], "count": count, "model": model,
        "load_s": stats["load_s"], "eval_tokens": stats["eval_tokens"],
    }
    path = ledger_path()
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a") as f:
            f.write(json.dumps(line, ensure_ascii=False) + "\n")
    except OSError as e:
        print(f"vision.py: could not write {path}: {e}", file=sys.stderr)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("question")
    p.add_argument("images", nargs="+")
    p.add_argument("--model", default=MODEL)
    p.add_argument("--keep-alive", default=0, type=int, help="seconds to stay on the GPU; default 0 releases it")
    p.add_argument("--agent", default=os.environ.get("KUMBIA_AGENT", "unnamed"))
    p.add_argument("--what", default=None, help="ledger note; default is the first image's name")
    p.add_argument("--num-predict", type=int, default=None, help="cap on answer tokens")
    p.add_argument("--timeout", type=int, default=900, help="seconds to wait for an answer")
    p.add_argument("--stats", action="store_true", help="print timings on stderr")
    args = p.parse_args()

    try:
        answer, stats = ask(args.question, args.images, args.model, args.keep_alive, args.timeout, args.num_predict)
    except (urllib.error.URLError, OSError, KeyError, ValueError) as e:
        detail = e.read().decode(errors="replace") if isinstance(e, urllib.error.HTTPError) else e
        print(f"vision.py: {detail}", file=sys.stderr)
        return 2
    print(answer)
    record(args.agent, args.what or os.path.basename(args.images[0]), args.model, len(args.images), stats)
    if args.stats:
        print(json.dumps(stats), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
