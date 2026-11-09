#!/usr/bin/env python3
"""The steps around layer.py for one room, so each room is built the same way.

  python3 tool/music/layer/room.py plan LEVEL    # tempos and stretch ratios, from levels.json
  python3 tool/music/layer/room.py stage LEVEL   # copy low/high into /work/tmp/audio for rubberband
  python3 tool/music/layer/room.py wire LEVEL    # copy the stretched files back, point levels.json at them

Between stage and wire, run audio.transform time_stretch on each staged file with the ratio
`plan` prints, writing <tier>-<bpm>.flac beside it. Tempos: mid keeps its tempo, low is
mid / 1.03 and high mid * 1.03, rounded to whole BPM (owner, 2026-11-09).
"""
import json, os, pathlib, shutil, sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
LEVELS = ROOT / "tool/music/mix/levels.json"
TIERS = ROOT / "tool/music/layer/tiers.json"
STAGE = pathlib.Path("/work/tmp/audio/layered")
LIFT = 1.03


def tempos(mid):
    return {"low": round(mid / LIFT), "mid": mid, "high": round(mid * LIFT)}


def level(cfg, lid):
    return next(l for l in cfg["levels"] if l["id"] == lid)


def main():
    cmd, lid = sys.argv[1], sys.argv[2]
    cfg = json.loads(LEVELS.read_text())
    spec = json.loads(TIERS.read_text())
    lv = level(cfg, lid)
    mid = next(t for t in lv["tiers"] if t["name"] == "mid")
    out = pathlib.Path(os.path.expanduser(f"{spec['mastersDir']}/{spec['outDir']}/{lid}"))
    bpm = tempos(round(mid["bpm"]))
    ratio = {k: round(bpm["mid"] / v, 6) for k, v in bpm.items()}
    if cmd == "plan":
        print(json.dumps({"bpm": bpm, "ratio": ratio, "base": mid["source"]}))
    elif cmd == "stage":
        (STAGE / lid).mkdir(parents=True, exist_ok=True)
        for t in ("low", "high"):
            shutil.copy(out / f"{t}.flac", STAGE / lid / f"{t}.flac")
            print(STAGE / lid / f"{t}.flac", "ratio", ratio[t], "->", STAGE / lid / f"{t}-{bpm[t]}.flac")
    elif cmd == "wire":
        rel = f"{spec['outDir']}/{lid}"
        for t in ("low", "high"):
            name = f"{t}-{bpm[t]}.flac"
            shutil.copy(STAGE / lid / name, out / name)
            shutil.copy(STAGE / lid / f"{name}.provenance.json", out / f"{name}.provenance.json")
        for t in lv["tiers"]:
            n = t["name"]
            t.pop("layer", None)
            t["eq"] = []
            t["bpm"] = bpm[n]
            t["source"] = f"{rel}/{n}.flac" if n == "mid" else f"{rel}/{n}-{bpm[n]}.flac"
            if n == "mid":
                t.pop("followScale", None)
            else:
                t["followScale"] = ratio[n]
        LEVELS.write_text(json.dumps(cfg, indent=1, ensure_ascii=False) + "\n")
        print(json.dumps([(t["name"], t["bpm"], t["source"], t.get("followScale")) for t in lv["tiers"]]))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
