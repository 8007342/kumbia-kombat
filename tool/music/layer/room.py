#!/usr/bin/env python3
"""The steps around layer.py for one room, so each room is built the same way.

  python3 tool/music/layer/room.py plan LEVEL    # tempos and stretch ratios, from levels.json
  python3 tool/music/layer/room.py stage LEVEL   # copy low/high into /work/tmp/audio for rubberband
  python3 tool/music/layer/room.py wire LEVEL    # copy the stretched files back, point levels.json at them

Between stage and wire, run audio.transform time_stretch on each staged file with the ratio
`plan` prints, writing <tier>-<bpm>.wav beside it. Tempos: low is mid / 1.03 and high
mid * 1.03, rounded to whole BPM (owner, 2026-11-09). The `native` tier (mid unless
tiers.json says otherwise) plays the take at its own tempo; the other two are stretched.
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
    # The tier that plays the take at its own tempo: mid, unless tiers.json says
    # otherwise (the lawn's richest take is its top tier). The others are stretched.
    native = spec["levels"][lid].get("native", "mid")
    ratio = {k: round(bpm[native] / v, 6) for k, v in bpm.items()}
    stretched = [t for t in ("low", "mid", "high") if t != native]
    if cmd == "plan":
        print(json.dumps({"bpm": bpm, "ratio": ratio, "native": native, "base": spec["levels"][lid]["base"]}))
    elif cmd == "stage":
        (STAGE / lid).mkdir(parents=True, exist_ok=True)
        for t in stretched:
            shutil.copy(out / f"{t}.wav", STAGE / lid / f"{t}.wav")
            print(STAGE / lid / f"{t}.wav", "ratio", ratio[t], "->", STAGE / lid / f"{t}-{bpm[t]}.wav")
    elif cmd == "wire":
        rel = f"{spec['outDir']}/{lid}"
        for t in stretched:
            name = f"{t}-{bpm[t]}.wav"
            shutil.copy(STAGE / lid / name, out / name)
            shutil.copy(STAGE / lid / f"{name}.provenance.json", out / f"{name}.provenance.json")
        for t in lv["tiers"]:
            n = t["name"]
            t.pop("layer", None)
            t["eq"] = []
            t["bpm"] = bpm[n]
            # The native tier is the approved take's own file, untouched: the mixer's
            # beat and bar-one analysis is level-sensitive, and a trimmed copy moved
            # terraza's bar one by a beat. A native tier with gains of its own (the
            # party narrows its sides) is the layered file, written unscaled.
            if n == native:
                t["source"] = f"{rel}/{n}.wav" if spec["levels"][lid]["tiers"].get(n) else spec["levels"][lid]["base"]
            else:
                t["source"] = f"{rel}/{n}-{bpm[n]}.wav"
            # Followers sit at the grid tier's beats times their stretch against it.
            grid = lv.get("gridTier", "mid")
            if n == grid:
                t.pop("followScale", None)
            else:
                t["followScale"] = round(ratio[n] / ratio[grid], 6)
        LEVELS.write_text(json.dumps(cfg, indent=1, ensure_ascii=False) + "\n")
        print(json.dumps([(t["name"], t["bpm"], t["source"], t.get("followScale")) for t in lv["tiers"]]))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
