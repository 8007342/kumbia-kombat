#!/usr/bin/env python3
"""Compare two rig.json files. Usage: compare_rig.py OLD NEW [--joints-only]"""
import json, sys
a = json.load(open(sys.argv[1])); b = json.load(open(sys.argv[2]))
joints_only = "--joints-only" in sys.argv
ia, ib = [p["id"] for p in a["poses"]], [p["id"] for p in b["poses"]]
print("ids equal", ia == ib, len(ia))
keys = ("joints", "openpose", "groundY", "pivotX", "support", "pin", "params") if joints_only else None
bad = {}
for p, q in zip(a["poses"], b["poses"]):
    for k in (keys or set(p) | set(q)):
        if p.get(k) != q.get(k):
            bad.setdefault(k, []).append(p["id"])
print("diffs", {k: len(v) for k, v in bad.items()} or "none")
print("meta diffs", [k for k in set(a) | set(b) if k != "poses" and a.get(k) != b.get(k)])
sys.exit(1 if bad else 0)
