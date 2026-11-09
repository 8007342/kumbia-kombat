#!/usr/bin/env bash
# Measures every rendered .ogg of the named levels, one line each, with gate failures.
#   tool/music/layer/report.sh bar cool-crowd
here=$(cd "$(dirname "$0")" && pwd)
files=()
for l in "$@"; do files+=(assets/music/rendered/$l/*.ogg); done
uv run --no-project --with numpy --with soundfile python -I "$here/measure.py" "${files[@]}" 2>&1 | python3 -c '
import sys, json
for l in sys.stdin:
    try: r = json.loads(l)
    except ValueError: print(l.strip()); continue
    r["f"] = "/".join(r["file"].split("/")[-2:])
    r["why"] = "; ".join(r["fails"])
    print("{f:30} corr {corr:+.2f} neg {negWindows:4.0%} clip {clipRuns:2} drop {dropouts} cent {centroidHz:5} bass {bassDb:5} on/s {onsetsPerS:.2f} lufs {lufs:6} {why}".format(**r))'
