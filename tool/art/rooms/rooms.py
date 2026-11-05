#!/usr/bin/env python3
"""Room art commands. Run with the art venv: ~/.cache/tillandsias-project/venvs/kumbia-art/bin/python

  rooms.py compile <room>                 greybox, ids, floor.json, prompts, level fragment; refuses a bad layout
  rooms.py plan <room> --run R --pass 1   bake workflows and write art_runs/R/jobs-*.json for studio.run_workflow
  rooms.py collect --run R                copy finished studio outputs to the persistent art cache
  rooms.py verify --run R                 confirm at ComfyUI /history that jobs carried the planned prompts (A1)
  rooms.py sheet <room> --run R           candidates at phone crop beside the accepted rooms, with numbers
  rooms.py proof <room> --run R --plate P floor overlay and a cast proof with real sprites
  rooms.py level <room> --out levels/x.json  write a draft level file from the room's calibration
  rooms.py check <room> --level F         check a level file's marks against the compiled room
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import compiler  # noqa: E402

OUT = compiler.REPO / "art_runs/rooms"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("compile"); c.add_argument("room"); c.add_argument("--out")
    w = sub.add_parser("where"); w.add_argument("room"); w.add_argument("xy", nargs="+", type=float, help="image fractions x y [x y ...]")
    p = sub.add_parser("plan"); p.add_argument("room"); p.add_argument("--run", required=True); p.add_argument("--pass", dest="pass_no", type=int, choices=[1, 2], required=True)
    p.add_argument("--count", type=int, default=8); p.add_argument("--seed", type=int, default=980000); p.add_argument("--steps", type=int, default=4)
    p.add_argument("--from", dest="bases", nargs="*", default=[]); p.add_argument("--name"); p.add_argument("--append", default="", help="extra sentence for this setup, kept in the workflow")
    k = sub.add_parser("collect"); k.add_argument("--run", required=True)
    f = sub.add_parser("verify"); f.add_argument("--run", required=True)
    h = sub.add_parser("sheet"); h.add_argument("room"); h.add_argument("--run", required=True); h.add_argument("--glob", default="*"); h.add_argument("--cols", type=int, default=8); h.add_argument("--height", type=int, default=506); h.add_argument("--out")
    q = sub.add_parser("proof"); q.add_argument("room"); q.add_argument("--run", required=True); q.add_argument("--plate", required=True)
    l = sub.add_parser("level"); l.add_argument("room"); l.add_argument("--out", required=True); l.add_argument("--base", default="levels/bar.json"); l.add_argument("--background", required=True)
    v = sub.add_parser("check"); v.add_argument("room"); v.add_argument("--level", required=True)
    a = ap.parse_args()
    try:
        if a.cmd == "compile":
            spec = compiler.load_spec(a.room)
            out = Path(a.out) if a.out else OUT / spec["id"]
            rep = compiler.write_outputs(spec, out)
            import json
            print(json.dumps(rep, ensure_ascii=False, indent=1))
            print("wrote", out)
        elif a.cmd == "plan":
            import plates
            out, doc = plates.plan(a.room, a.run, a.pass_no, a.count, a.seed, a.steps, a.bases, a.name, a.append)
            print(out); print(len(doc["jobs"]), "jobs,", sum(j["count"] for j in doc["jobs"]), "images, prompt", doc["promptSha256"][:12])
        elif a.cmd == "collect":
            import plates
            print(*plates.collect(a.run), "frames")
        elif a.cmd == "verify":
            import plates
            print(plates.verify(a.run))
        elif a.cmd == "sheet":
            import plates
            out, rows = plates.sheet(a.room, a.run, a.glob, a.cols, a.out, a.height)
            print(out)
            for r in rows:
                print(r["file"], "sat", r["sat"], "val", r["val"], "bandLuma", r["bandLuma"], "bandEdge", r["bandEdge"], "drift", r["drift"] and r["drift"]["median"])
        elif a.cmd == "proof":
            import plates
            meas, out = plates.proof(a.room, a.run, a.plate)
            print(out); print(meas)
        elif a.cmd == "level":
            import plates
            plates.write_level(a.room, a.out, a.base, a.background); print("wrote", a.out)
        elif a.cmd == "check":
            import plates
            print(plates.check_level(a.room, a.level))
        elif a.cmd == "where":
            cam = compiler.Camera(compiler.load_spec(a.room)["camera"])
            for x, y in zip(a.xy[::2], a.xy[1::2]):
                print(f"({x}, {y}) -> s, t = {cam.floor_at(x, y)[0]:.2f}, {cam.floor_at(x, y)[1]:.2f}")
    except compiler.RoomError as e:
        print(e, file=sys.stderr)
        if e.painted and a.cmd == "compile":
            print("look at", compiler.preview_refused(spec, e, out), file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
