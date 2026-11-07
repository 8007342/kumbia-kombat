#!/usr/bin/env python3
"""Run a command and report the peak memory of its process tree, polled from /proc.

  python3 -I tool/music/mixrs/compare/peak_tree.py [--every 0.05] -- COMMAND...

Prints wall seconds, the peak of the tree's summed RSS and of the largest single process.
RSS counts shared pages once per process, so the sum can overstate a tree of forks.
"""
import json
import os
import subprocess
import sys
import time


def tree(root):
    kids = {}
    for name in os.listdir("/proc"):
        if not name.isdigit():
            continue
        try:
            with open(f"/proc/{name}/stat") as f:
                text = f.read()
            ppid = int(text[text.rindex(")") + 2:].split()[1])
        except OSError:
            continue
        kids.setdefault(ppid, []).append(int(name))
    seen, todo = [], [root]
    while todo:
        pid = todo.pop()
        seen.append(pid)
        todo.extend(kids.get(pid, []))
    return seen


def rss_mb(pid):
    try:
        with open(f"/proc/{pid}/statm") as f:
            return int(f.read().split()[1]) * 4096 / 1e6
    except (OSError, IndexError):
        return 0.0


def main():
    argv = sys.argv[1:]
    every = 0.05
    if argv and argv[0] == "--every":
        every, argv = float(argv[1]), argv[2:]
    if argv and argv[0] == "--":
        argv = argv[1:]
    start = time.time()
    proc = subprocess.Popen(argv)
    peak_sum = peak_one = 0.0
    while proc.poll() is None:
        rows = [rss_mb(p) for p in tree(proc.pid)]
        peak_sum = max(peak_sum, sum(rows))
        peak_one = max(peak_one, max(rows, default=0.0))
        time.sleep(every)
    print(json.dumps({"wall_s": round(time.time() - start, 2), "tree_peak_mb": round(peak_sum),
                      "largest_process_mb": round(peak_one), "exit": proc.returncode}), file=sys.stderr)
    return proc.returncode


if __name__ == "__main__":
    sys.exit(main())
