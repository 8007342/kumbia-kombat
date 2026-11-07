#!/usr/bin/env python3
"""Where the compute went: cloud models against the local GPU and CPU.

    tool/metrics/ledger.py          a plain table
    tool/metrics/ledger.py --json   everything, including each local job

MEASURED: cloud tokens as the API reported them; tool calls; images returned to
a cloud model; timestamps; each studio job's elapsed_s and stages_ms.
PROXY: cloud "compute time" isn't knowable from here. We report tokens, and the
time an agent waited on the model (its request to its reply, retries and queueing
included). No dollar or energy figure is given, because none is known.
ESTIMATE: disk-only jobs' GPU time, from gaps between output file times (it reads
about 20% low against 22 jobs with both figures, as it misses the first image's
model load), and image tokens, width x height / 750. Both are labelled.

Sources: Claude Code transcripts (only the sessions still on disk), the studio's
job folders (deleted when the forge shuts down), provenance files in the art and
audio caches, plan/compute-ledger.jsonl in each checkout, assets/. Stdlib only.
"""
import argparse
import base64
import collections
import fnmatch
import glob
import json
import os
import re
import struct
import sys
from datetime import datetime

HOME = os.path.expanduser("~")
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TRANSCRIPTS = os.environ.get("KUMBIA_TRANSCRIPTS", HOME + "/.claude/projects/-home-forge-src-kumbia-kombat")
JOB_ROOT = "/work/tmp/imagegen/studio"
CACHES = [HOME + "/.cache/tillandsias-project/kumbia-art", HOME + "/.cache/tillandsias-project/kumbia-audio",
          "/home/forge/src/kumbia-kombat/art_runs", REPO + "/art_runs"]
LEDGER_GLOBS = [
    REPO + "/plan/compute-ledger.jsonl",
    "/home/forge/src/kumbia-kombat/plan/compute-ledger.jsonl",
    "/home/forge/src/kumbia-kombat/wt/*/plan/compute-ledger.jsonl",
    HOME + "/.cache/tillandsias-project/kumbia-wt/*/plan/compute-ledger.jsonl",
]
MEDIA = (".png", ".m4a", ".ogg", ".svg", ".otf", ".mid")
TOKEN_KEYS = {"input": "input_tokens", "cache_read": "cache_read_input_tokens",
              "cache_write": "cache_creation_input_tokens", "output": "output_tokens"}


def when(text):
    return datetime.fromisoformat(text.replace("Z", "+00:00")).timestamp() if text else None


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "".join(b.get("text", "") for b in content if isinstance(b, dict))
    return ""


def image_size(b64):
    """(width, height) from a PNG or JPEG header, or None."""
    try:
        raw = base64.b64decode(b64[:200000] + "=" * (-len(b64[:200000]) % 4))
    except ValueError:
        return None
    if raw[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", raw[16:24])
    if raw[:2] == b"\xff\xd8":
        i = 2
        while i + 9 < len(raw):
            if raw[i] != 0xFF:
                i += 1
                continue
            marker = raw[i + 1]
            if marker in range(0xC0, 0xD0) and marker not in (0xC4, 0xC8, 0xCC):
                h, w = struct.unpack(">HH", raw[i + 5:i + 9])
                return w, h
            i += 2 + struct.unpack(">H", raw[i + 2:i + 4])[0]
    return None


def flac_seconds(path):
    try:
        with open(path, "rb") as f:
            head = f.read(42)
    except OSError:
        return None
    if head[:4] != b"fLaC":
        return None
    packed = int.from_bytes(head[18:26], "big")
    rate = packed >> 44
    return (packed & ((1 << 36) - 1)) / rate if rate else None


def union_seconds(spans):
    total, end = 0.0, None
    for a, b in sorted(spans):
        if end is None or a > end:
            total += b - a
            end = b
        elif b > end:
            total += b - end
            end = b
    return total


def new_agent(session, agent, label):
    return {"session": session, "agent": agent, "label": label, "messages": 0,
            "tokens": dict.fromkeys(TOKEN_KEYS, 0), "first": None, "last": None,
            "model_wait_s": 0.0, "tool_calls": 0, "images_in": 0}


def job_from_result(data, agent, ts):
    if not isinstance(data, dict):
        return None
    data = data.get("result") if isinstance(data.get("result"), dict) else data
    if "job" not in data or "elapsed_s" not in data:
        return None
    outputs = data.get("outputs") or []
    stages = data.get("stages_ms") or {}
    run = sum(v for k, v in stages.items() if k.startswith("run")) / 1000
    wait = stages.get("gpu_wait", 0) / 1000
    kinds = collections.Counter(o.get("kind", "?") for o in outputs)
    return {"job": data["job"], "agent": agent, "source": "transcript",
            "workflow": (data.get("provenance") or {}).get("workflow"),
            "kind": kinds.most_common(1)[0][0] if kinds else "?",
            "count": len(outputs) or data.get("count", 0),
            "elapsed_s": data["elapsed_s"], "gpu_run_s": run or max(data["elapsed_s"] - wait, 0),
            "gpu_wait_s": wait, "run_estimated": False, "at": ts}


def read_transcripts():
    files = sorted(glob.glob(TRANSCRIPTS + "/**/*.jsonl", recursive=True), key=lambda p: "/subagents/" in p)
    agents, jobs = [], {}
    seen_msg, seen_tool, seen_uuid = set(), {}, set()
    tools = collections.defaultdict(lambda: {"calls": 0, "wall_s": 0.0})
    images = collections.Counter()
    image_bytes = image_tokens = pasted = 0
    image_paths = set()
    models = collections.defaultdict(lambda: dict.fromkeys(TOKEN_KEYS, 0))
    spans = []
    failures = local_vision_cmds = 0

    for path in files:
        is_sub = "/subagents/" in path
        name = os.path.basename(path)[:-6]
        session = path.split("/")[-3] if is_sub else name
        label = "main"
        if is_sub:
            try:
                with open(path[:-6] + ".meta.json") as f:
                    label = json.load(f).get("description", name)
            except (OSError, ValueError):
                label = name
        a = new_agent(session, "main" if not is_sub else name.replace("agent-", ""), label)
        agents.append(a)
        previous_ts, open_msg = None, None

        def close():
            nonlocal open_msg
            if open_msg and open_msg["start"] is not None:
                spans.append((open_msg["start"], open_msg["end"]))
                a["model_wait_s"] += open_msg["end"] - open_msg["start"]
            open_msg = None

        with open(path, errors="replace") as f:
            for raw in f:
                try:
                    o = json.loads(raw)
                except ValueError:
                    continue
                kind = o.get("type")
                if kind not in ("user", "assistant"):
                    continue
                uuid = o.get("uuid")
                if uuid in seen_uuid:
                    continue
                seen_uuid.add(uuid)
                ts = when(o.get("timestamp"))
                if ts is not None:
                    a["first"] = ts if a["first"] is None else min(a["first"], ts)
                    a["last"] = ts if a["last"] is None else max(a["last"], ts)
                m = o.get("message") or {}
                content = m.get("content")

                if kind == "assistant":
                    mid, model = m.get("id"), m.get("model", "?")
                    if not open_msg or open_msg["id"] != mid:
                        close()
                        open_msg = {"id": mid, "start": previous_ts, "end": ts}
                    open_msg["end"] = ts
                    if mid not in seen_msg and model != "<synthetic>":
                        seen_msg.add(mid)
                        a["messages"] += 1
                        usage = m.get("usage") or {}
                        for k, key in TOKEN_KEYS.items():
                            a["tokens"][k] += usage.get(key) or 0
                            models[model][k] += usage.get(key) or 0
                    for block in content if isinstance(content, list) else []:
                        if isinstance(block, dict) and block.get("type") == "tool_use" and block["id"] not in seen_tool:
                            seen_tool[block["id"]] = {"name": block["name"], "ts": ts, "input": block.get("input") or {}}
                            tools[block["name"]]["calls"] += 1
                            a["tool_calls"] += 1
                            if block["name"] == "Bash" and re.search(r"inference:11434|vision\.py", str(block.get("input"))):
                                local_vision_cmds += 1
                    continue

                close()
                previous_ts = ts
                if not isinstance(content, list):
                    continue
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    if block.get("type") == "image":
                        pasted += 1
                    if block.get("type") != "tool_result":
                        continue
                    call = seen_tool.get(block.get("tool_use_id"))
                    if not call or call.get("done"):
                        continue
                    call["done"] = True
                    tool = call["name"]
                    if ts and call["ts"]:
                        tools[tool]["wall_s"] += max(ts - call["ts"], 0)
                    result = block.get("content")
                    for x in result if isinstance(result, list) else []:
                        if isinstance(x, dict) and x.get("type") == "image":
                            where = call["input"].get("file_path", "") if tool == "Read" else tool.split("__")[-1]
                            ext = os.path.splitext(where)[1].lower() or where
                            images[f"Read {ext}" if tool == "Read" else ext] += 1
                            image_paths.add(where)
                            a["images_in"] += 1
                            data = (x.get("source") or {}).get("data", "")
                            image_bytes += len(data) * 3 // 4
                            size = image_size(data)
                            if size:
                                image_tokens += size[0] * size[1] / 750
                    if re.search(r"studio_|image_generate", tool):
                        text = text_of(result)
                        try:
                            parsed = json.loads(text)
                        except ValueError:
                            parsed = None
                            if re.search(r"run_workflow|queue_workflow", tool):
                                failures += 1
                        if isinstance(parsed, dict) and parsed.get("status") == "failed":
                            failures += 1
                        job = job_from_result(parsed, a["agent"], ts)
                        if job and job["job"] not in jobs:
                            jobs[job["job"]] = job
        close()

    return {"agents": agents, "jobs": jobs, "tools": tools, "models": models, "spans": spans,
            "images": images, "image_bytes": image_bytes, "image_tokens_est": int(image_tokens),
            "images_distinct": len(image_paths), "pasted": pasted, "failures": failures,
            "local_vision_cmds": local_vision_cmds}


def run_name(workflow, inputs):
    for text in [workflow or ""] + [i.get("path", "") for i in inputs or []]:
        m = re.search(r"art_runs/(?:rooms/)?([^/]+)|/kumbia/([^/]+)/", text)
        if m:
            return m.group(1) or m.group(2)
    return os.path.basename(workflow or "unknown").replace(".api.json", "")


def read_job_dirs(jobs):
    """Adds what only the job folders know: audio length, the run, and jobs no transcript reported."""
    audio_seconds = 0.0
    for d in sorted(glob.glob(JOB_ROOT + "/st-*")):
        name = os.path.basename(d)
        provs, outs = [], []
        for f in os.listdir(d):
            (provs if f.endswith(".provenance.json") else outs).append(os.path.join(d, f))
        if not provs:
            continue
        try:
            with open(provs[0]) as f:
                prov = json.load(f)
        except (OSError, ValueError):
            prov = {}
        flacs = [p for p in outs if p.endswith(".flac")]
        seconds = sum(flac_seconds(p) or 0 for p in flacs)
        audio_seconds += seconds
        job = jobs.get(name)
        if not job:
            times = sorted(os.path.getmtime(p) for p in outs) or [0]
            m = re.match(r"st-(\d+)-", name)
            start = int(m.group(1)) / 1000 if m else times[0]
            elapsed = max(os.path.getmtime(p) for p in provs) - start
            n = len(outs)
            run = (times[-1] - times[0]) * n / (n - 1) if n > 1 else elapsed
            job = jobs[name] = {
                "job": name, "agent": "(job folder only)", "source": "disk",
                "workflow": (prov.get("workflow") or {}).get("path"),
                "kind": "audio" if flacs else "image", "count": n,
                "elapsed_s": round(elapsed, 1), "gpu_run_s": round(min(run, elapsed), 1),
                "gpu_wait_s": None, "run_estimated": True, "at": start}
        job["audio_s"] = round(seconds, 1)
        job["run"] = run_name((prov.get("workflow") or {}).get("path"), prov.get("inputs"))
    for job in jobs.values():
        job.setdefault("run", run_name(job.get("workflow"), None))
    return jobs


def all_time_outputs():
    """Every local output with a provenance file in the caches or job folders, by content."""
    seen = {}
    for root in CACHES + [JOB_ROOT]:
        for base, _, names in os.walk(root):
            for n in names:
                if not n.endswith(".provenance.json"):
                    continue
                path = os.path.join(base, n)
                try:
                    with open(path) as f:
                        p = json.load(f)
                except (OSError, ValueError):
                    continue
                out = path[: -len(".provenance.json")]
                seen.setdefault(p.get("output_sha256") or path, (out, p.get("at", "")))
    res = {"image": 0, "audio": 0, "other": 0, "audio_seconds": 0.0, "audio_unread": 0, "first": None, "last": None}
    for out, at in seen.values():
        if out.endswith((".png", ".webp", ".jpg")):
            res["image"] += 1
        elif out.endswith((".flac", ".wav", ".mp3", ".ogg")):
            res["audio"] += 1
            s = flac_seconds(out)
            if s is None:
                res["audio_unread"] += 1
            else:
                res["audio_seconds"] += s
        else:
            res["other"] += 1
        if at:
            res["first"] = min(res["first"] or at, at)
            res["last"] = max(res["last"] or at, at)
    return res


def read_ledger():
    lines, bad, paths = set(), 0, set()
    for pattern in LEDGER_GLOBS:
        paths.update(glob.glob(pattern))
    for path in paths:
        with open(path, errors="replace") as f:
            for raw in f:
                if raw.strip():
                    lines.add(raw.strip())
    totals = collections.defaultdict(lambda: {"lines": 0, "seconds": 0.0, "count": 0})
    for raw in lines:
        try:
            o = json.loads(raw)
            t = totals[o.get("kind", "?")]
            t["seconds"] += float(o.get("seconds") or 0)
            t["count"] += int(o.get("count") or 0)
            t["lines"] += 1
        except (ValueError, TypeError, AttributeError):
            bad += 1
    return {"by_kind": dict(totals), "files": sorted(paths), "bad_lines": bad}


def read_assets():
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "asset_provenance.json")) as f:
        rules = json.load(f)["rules"]
    # A file named in code or level data is probably used; this doesn't prove it's on screen.
    corpus = []
    for pattern in ("lib/**/*.dart", "levels/**/*.json", "assets/**/*.json", "pubspec.yaml"):
        for path in glob.glob(os.path.join(REPO, pattern), recursive=True):
            with open(path, errors="replace") as f:
                corpus.append(f.read())
    corpus = "\n".join(corpus)
    classes = collections.defaultdict(lambda: {"files": 0, "bytes": 0, "named_files": 0, "named_bytes": 0})
    unmatched = []
    for base, _, names in os.walk(os.path.join(REPO, "assets")):
        for name in names:
            if not name.endswith(MEDIA):
                continue
            full = os.path.join(base, name)
            rel = os.path.relpath(full, REPO)
            cls = next((r["class"] for r in rules if fnmatch.fnmatch(rel, r["glob"])), None)
            if cls is None:
                cls = "unclassified"
                unmatched.append(rel)
            medium = "audio" if name.endswith((".m4a", ".ogg", ".mid")) else "art"
            c = classes[f"{cls} / {medium}"]
            size = os.path.getsize(full)
            c["files"] += 1
            c["bytes"] += size
            if rel in corpus or name in corpus:
                c["named_files"] += 1
                c["named_bytes"] += size
    return {"classes": dict(classes), "unclassified": sorted(unmatched)}


def build():
    t = read_transcripts()
    jobs = read_job_dirs(t["jobs"])
    kinds = collections.defaultdict(lambda: {"jobs": 0, "outputs": 0, "elapsed_s": 0.0, "gpu_run_s": 0.0,
                                              "gpu_wait_s": 0.0, "jobs_run_estimated": 0, "audio_s": 0.0})
    runs = collections.defaultdict(lambda: {"jobs": 0, "outputs": 0, "gpu_run_s": 0.0})
    for j in jobs.values():
        k = kinds[j["kind"]]
        k["jobs"] += 1
        k["outputs"] += j["count"]
        k["elapsed_s"] += j["elapsed_s"]
        k["gpu_run_s"] += j["gpu_run_s"]
        k["gpu_wait_s"] += j["gpu_wait_s"] or 0
        k["jobs_run_estimated"] += j["run_estimated"]
        k["audio_s"] += j.get("audio_s", 0)
        r = runs[j["run"]]
        r["jobs"] += 1
        r["outputs"] += j["count"]
        r["gpu_run_s"] += j["gpu_run_s"]
    agents = t["agents"]
    for a in agents:
        a["span_s"] = round(a["last"] - a["first"], 1) if a["first"] else 0
        a["model_wait_s"] = round(a["model_wait_s"], 1)
    total = dict.fromkeys(TOKEN_KEYS, 0)
    for a in agents:
        for k in total:
            total[k] += a["tokens"][k]
    firsts = [a["first"] for a in agents if a["first"]]
    lasts = [a["last"] for a in agents if a["last"]]
    return {
        "measured_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "cloud": {
            "sessions": sorted({a["session"] for a in agents}), "agents": agents,
            "tokens": total, "by_model": dict(t["models"]),
            "window": [firsts and min(firsts), lasts and max(lasts)],
            "wall_clock_s": round(max(lasts) - min(firsts), 1) if firsts else 0,
            "sum_agent_span_s": round(sum(a["span_s"] for a in agents), 1),
            "sum_model_wait_s": round(sum(a["model_wait_s"] for a in agents), 1),
            "any_model_generating_s": round(union_seconds(t["spans"]), 1),
            "tools": {k: {"calls": v["calls"], "wall_s": round(v["wall_s"], 1)} for k, v in t["tools"].items()},
            "images": {"returned_to_cloud": dict(t["images"]), "total": sum(t["images"].values()),
                       "distinct_sources": t["images_distinct"], "bytes": t["image_bytes"],
                       "tokens_estimate_w_h_over_750": t["image_tokens_est"], "pasted_in_prompts": t["pasted"]},
        },
        "local": {
            "gpu_by_kind": dict(kinds), "gpu_by_run": dict(runs), "failed_submissions": t["failures"],
            "jobs": sorted(jobs.values(), key=lambda j: j.get("at") or 0),
            "ledger": read_ledger(), "bash_commands_calling_local_vision": t["local_vision_cmds"],
            "all_time_outputs": all_time_outputs(),
        },
        "assets": read_assets(),
    }


def n(x):
    return f"{int(x):,}"


def hms(s):
    s = int(s)
    return f"{s // 3600}h{s % 3600 // 60:02d}m{s % 60:02d}s"


def mb(b):
    return f"{b / 1e6:.1f} MB"


def table(rows, right=()):
    widths = [max(len(str(r[i])) for r in rows) for i in range(len(rows[0]))]
    for idx, r in enumerate(rows):
        print("  ".join(str(c).rjust(w) if i in right else str(c).ljust(w) for i, (c, w) in enumerate(zip(r, widths))).rstrip())
        if idx == 0:
            print("  ".join("-" * w for w in widths))
    print()


def report(d):
    c, l = d["cloud"], d["local"]
    print(f"Compute ledger, measured {d['measured_at']}")
    print("Measured: tokens, tool calls, images, timestamps, studio job times. Proxy for cloud compute: tokens and")
    print("waiting on the model. Estimate: image tokens; GPU time of jobs known only from their folder. No costs.\n")

    print(f"CLOUD, {len(c['sessions'])} session(s) on disk, {len(c['agents'])} agents. Earlier sessions' transcripts are gone, so they aren't here.")
    rows = [("agent", "label", "msgs", "input", "cache read", "cache write", "output", "span", "model wait", "tools", "images")]
    for a in sorted(c["agents"], key=lambda a: -a["tokens"]["cache_read"]):
        t = a["tokens"]
        rows.append((a["agent"][:8], a["label"][:40], a["messages"], n(t["input"]), n(t["cache_read"]), n(t["cache_write"]),
                     n(t["output"]), hms(a["span_s"]), hms(a["model_wait_s"]), a["tool_calls"], a["images_in"]))
    t = c["tokens"]
    rows.append(("TOTAL", "", sum(a["messages"] for a in c["agents"]), n(t["input"]), n(t["cache_read"]), n(t["cache_write"]), n(t["output"]),
                 hms(c["sum_agent_span_s"]), hms(c["sum_model_wait_s"]), sum(a["tool_calls"] for a in c["agents"]),
                 sum(a["images_in"] for a in c["agents"])))
    table(rows, right=(2, 3, 4, 5, 6, 7, 8, 9, 10))
    print(f"Wall clock, first event to last: {hms(c['wall_clock_s'])}. At least one model generating: {hms(c['any_model_generating_s'])}.")
    print("Agent spans and model waits overlap, so their totals exceed the wall clock.\n")

    rows = [("model", "input", "cache read", "cache write", "output")]
    for m, u in c["by_model"].items():
        rows.append((m, n(u["input"]), n(u["cache_read"]), n(u["cache_write"]), n(u["output"])))
    table(rows, right=(1, 2, 3, 4))

    i = c["images"]
    print(f"CLOUD VISION: {i['total']} images returned to a cloud model, {i['distinct_sources']} distinct sources, {mb(i['bytes'])}.")
    print(f"About {n(i['tokens_estimate_w_h_over_750'])} tokens on first reading (estimate, w x h / 750), already inside the totals above.")
    print("Rereading them from cache each later turn is inside cache read and can't be split out.")
    print(f"Images pasted into prompts, counted apart: {i['pasted_in_prompts']}.")
    table([("source", "images")] + sorted(i["returned_to_cloud"].items(), key=lambda kv: -kv[1]), right=(1,))

    rows = [("tool", "calls", "wall")]
    for k, v in sorted(c["tools"].items(), key=lambda kv: -kv[1]["calls"]):
        rows.append((k.replace("mcp__host-browser__", ""), v["calls"], hms(v["wall_s"])))
    print("TOOL CALLS. Wall is call to result, so it includes queueing, and background commands return at once.")
    table(rows, right=(1, 2))

    print("LOCAL GPU, one row per kind. GPU run excludes queue wait; elapsed includes it.")
    rows = [("kind", "jobs", "outputs", "GPU run", "queue wait", "elapsed", "audio", "jobs with estimated run")]
    for k, v in sorted(l["gpu_by_kind"].items()):
        rows.append((k, v["jobs"], v["outputs"], hms(v["gpu_run_s"]), hms(v["gpu_wait_s"]), hms(v["elapsed_s"]),
                     f"{v['audio_s'] / 60:.1f} min" if v["audio_s"] else "", v["jobs_run_estimated"]))
    table(rows, right=(1, 2, 3, 4, 5, 6, 7))
    print(f"Submissions refused or failed before running: {l['failed_submissions']}.\n")

    rows = [("run", "jobs", "outputs", "GPU run")]
    for k, v in sorted(l["gpu_by_run"].items(), key=lambda kv: -kv[1]["gpu_run_s"]):
        rows.append((k, v["jobs"], v["outputs"], hms(v["gpu_run_s"])))
    table(rows, right=(1, 2, 3))

    print("LOCAL, plan/compute-ledger.jsonl across checkouts. gpu-* lines repeat the jobs above and aren't added to them.")
    rows = [("kind", "lines", "items", "seconds")]
    for k, v in sorted(l["ledger"]["by_kind"].items()):
        rows.append((k, v["lines"], v["count"], hms(v["seconds"])))
    if len(rows) > 1:
        table(rows, right=(1, 2, 3))
    print(f"Bash commands calling the local vision model: {l['bash_commands_calling_local_vision']}. Without vision.py they leave no ledger line.\n")

    o = l["all_time_outputs"]
    print(f"ALL-TIME LOCAL OUTPUTS with a provenance file, by content, {o['first']} to {o['last']}:")
    print(f"{n(o['image'])} images, {n(o['audio'])} audio takes, {o['audio_seconds'] / 60:.1f} min read from FLAC headers ({o['audio_unread']} takes unreadable).")
    print("No compute time exists for those made before this session's transcripts.\n")

    print("IN assets/, media files only, classified by tool/metrics/asset_provenance.json:")
    print("Named = the file's name appears in lib/, levels/, a manifest or pubspec.yaml, which doesn't prove it's on screen.")
    print("Each rendered music take ships twice, as .m4a and .ogg.")
    rows = [("class / medium", "files", "bytes", "named files", "named bytes")]
    for k, v in sorted(d["assets"]["classes"].items(), key=lambda kv: -kv[1]["bytes"]):
        rows.append((k, v["files"], mb(v["bytes"]), v["named_files"], mb(v["named_bytes"])))
    table(rows, right=(1, 2, 3, 4))
    if d["assets"]["unclassified"]:
        print("Unclassified: " + ", ".join(d["assets"]["unclassified"]))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--json", action="store_true")
    args = p.parse_args()
    data = build()
    if args.json:
        json.dump(data, sys.stdout, indent=1, ensure_ascii=False)
        print()
    else:
        report(data)


if __name__ == "__main__":
    main()
