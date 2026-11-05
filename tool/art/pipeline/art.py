#!/usr/bin/env python3
"""One command from a character definition to a candidate atlas.

  art.py build <character|file.json> [--dry-run] [--prompts] [--only clip,pose.id] [--run ID] [--no-stage] [--backend ID]
  art.py ingest <character> --run ID         after the GPU jobs and pixel finish
  art.py accept-sheet <character> --view V --image PNG   after the owner approves a sheet view
  art.py accept-reference <character> --image PNG        (SDXL route)

build chains definitions, rig, family spec, planner, stages and pack. Frames whose
key is already in the store are reused, colour edits recolour without a GPU, and only
what is left is queued in art_runs/<run>/jobs.json for studio.run_workflow (MCP).
When nothing is left it packs the atlas.

The default route is Qwen (the style's backend, backends/qwen-frame.json): a pose whose
generated prompt equals the one baked in the character's accepted run counts as drawn, and
frames wait in jobs.held.json until every sheet view exists. --backend sdxl-base-1 selects the
older SDXL route, where a definition using derived references holds its jobs until the
current reference is accepted.

State: art_runs/builds/<id>.json (last complete build), art_runs/selections/<id>.json,
art_runs/references/<id>.json. Frames live in the content-addressed store (stages.py).
"""
from __future__ import annotations

import argparse
import dataclasses
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import colour as C  # noqa: E402
import compile_family as CF  # noqa: E402
import definitions as D  # noqa: E402
import masked as M  # noqa: E402
import plan_jobs as PJ  # noqa: E402
import plan_qwen_frames as Q  # noqa: E402
import planner as P  # noqa: E402
import ramps as R  # noqa: E402
import selection as Sel  # noqa: E402
from stages import Store, key_of, sha_file  # noqa: E402

RIG_CODE = ("rig/poses.py", "rig/garments.py", "rig/prims.py", "rig/standin.py", "rig/bodies.json")
GEOMETRY = ("shape", "region", "params", "secondaryMotion", "alsoIn")


@dataclasses.dataclass
class Paths:
    store: Store
    runs: Path = D.ROOT / "art_runs"
    lane: Path = PJ.LANE
    families: Path | None = None
    palettes: Path | None = None
    atlas_dir: Path | None = None   # None: the target's own folder


def _read(p: Path, default=None):
    return json.loads(p.read_text()) if p.exists() else default


def _write(p: Path, doc) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n")


def style_key(style: dict) -> str:
    return key_of({k: style.get(k) for k in ("prompt", "negative", "frame", "ramp", "outline", "reservedRamps")})


def rig_key(c: dict) -> str:
    """Everything the rig render depends on, including the rig's own code."""
    return key_of({
        "body": D.body_of(c),
        "garments": [{f: g.get(f) for f in GEOMETRY} for g in c["garments"]],
        "props": [{f: p.get(f) for f in ("kind", "hand", "clips")} for p in c.get("props", [])],
        "motion": {"set": c["motion"]["set"], "overrides": {k: v.get("pose") for k, v in c["motion"].get("overrides", {}).items()}},
        "camera": [t.get("camera") for t in c.get("targets", [])],
        "code": {f: hashlib.sha256((D.ART / f).read_bytes()).hexdigest() for f in RIG_CODE},
    })


def reference_key(c: dict, style: dict) -> str:
    return key_of({"sources": c["references"]["sources"], "garments": c["garments"], "props": c.get("props", []),
                   "skin": c.get("skin"), "traits": c.get("traits"), "style": style["prompt"]})


def reference_state(c: dict, style: dict, paths: Paths) -> dict:
    """Derived references must be accepted for the current design before frames generate."""
    if c["references"]["mode"] != "derive":
        return {"mode": "source", "hold": False, "image": None}
    key = reference_key(c, style)
    rec = _read(paths.runs / "references" / f"{c['id']}.json", {})
    ok = rec.get("key") == key and rec.get("accepted")
    return {"mode": "derive", "key": key, "hold": not ok, "image": rec.get("image") if ok else None}


def frame_dir(store: Store, frame: str) -> Path:
    return store.path("frame", key_of({"frame": frame}))


def has_frame(store: Store, frame: str) -> bool:
    return store.has("frame", key_of({"frame": frame}))


def plan_build(c: dict, style: dict, backend: dict, rig: dict, record: dict | None, store: Store) -> dict:
    """Decide one action per frame. Changes nothing."""
    changes = P.diff_definitions(record["definition"], c) if record else []
    restyled = bool(record) and record["styleKey"] != style_key(style)
    rebacked = bool(record) and record["backend"] != backend["id"]
    frames = {}
    for rp in rig["poses"]:
        pid = rp["id"]
        key = P.frame_key(c, style, backend, rp)
        old = (record or {}).get("frameKeys", {}).get(pid)
        if has_frame(store, key):
            action, why = "reuse", []
        elif not record or old is None:
            action, why = "full", ["first build of this frame"]
        elif restyled or rebacked:
            action, why = "full", ["style changed" if restyled else "backend changed"]
        else:
            action, why = P.frame_mode(changes, rp, rp)
            if action == "none":
                action, why = "full", ["frame key changed with no classified edit"]
            have = has_frame(store, old)
            if action == "recolour" and not (have and (frame_dir(store, old) / "final.png").exists()):
                action, why = "full", [*why, "previous frame is not in the store"]
            if action in ("masked", "finish") and not (have and (frame_dir(store, old) / "raw.png").exists()):
                action, why = "full", [*why, "previous raw frame is not in the store"]
        frames[pid] = {"key": key, "previous": old, "action": action, "reasons": why}
    counts: dict[str, int] = {}
    for f in frames.values():
        counts[f["action"]] = counts.get(f["action"], 0) + 1
    gen = counts.get("full", 0) + counts.get("masked", 0)
    return {"character": c["id"], "frames": frames, "counts": counts, "changes": changes, "gpu": gen > 0,
            "estimatedImages": gen * style.get("generation", {}).get("count_per_pose", 4)}


def recolour_frames(plan: dict, record: dict, c: dict, style: dict, store: Store) -> int:
    lut = R.lut_between(C.build_ramps(record["definition"], record["style"]), C.build_ramps(c, style))
    n = 0
    for pid, f in plan["frames"].items():
        if f["action"] != "recolour":
            continue
        prev = frame_dir(store, f["previous"])

        def work(out: Path, prev=prev, f=f) -> None:
            a = np.asarray(Image.open(prev / "final.png").convert("RGBA"))
            Image.fromarray(R.apply_lut(a, lut), "RGBA").save(out / "final.png", optimize=False)
            if (prev / "raw.png").exists():
                shutil.copyfile(prev / "raw.png", out / "raw.png")
            _write(out / "provenance.json", {"mode": "recolour", "from": f["previous"], "lut": lut})

        store.run("frame", {"frame": f["key"]}, work)
        n += 1
    return n


def masked_jobs(jobs: list[dict], plan: dict, rig_dir: Path, old_rig_dir: Path | None, c: dict, paths: Paths, run: str) -> list[dict]:
    lane = paths.lane / run / "in"
    out = []
    for job in jobs:
        f = plan["frames"][job["pose"]]
        if f["action"] != "masked" or old_rig_dir is None:
            out.append(job)
            continue
        load = lambda d: np.asarray(Image.open(d / f"{job['pose']}.regions.png").convert("RGBA"))  # noqa: E731
        edited = sorted({r for ch in plan["changes"] for r in (ch["regions"] or [])})
        mask = M.changed_mask(load(old_rig_dir), load(rig_dir), edited, D.rig_regions(c))
        mask_path = lane / f"{job['pose']}.mask.png"
        Image.fromarray((mask * 255).astype(np.uint8), "L").save(mask_path)
        prev = lane / f"{job['pose']}.previous.png"
        shutil.copyfile(frame_dir(paths.store, f["previous"]) / "raw.png", prev)
        out.append({**job, "mode": "masked", "args": M.job_args(job["args"], str(mask_path), str(prev))})
    return out


def pack(spec_path: Path, spec: dict, plan: dict, run: str, paths: Paths, selection: dict) -> None:
    run_dir = paths.runs / run
    (run_dir / "final").mkdir(parents=True, exist_ok=True)
    for pid, f in plan["frames"].items():
        shutil.copyfile(frame_dir(paths.store, f["key"]) / "final.png", run_dir / "final" / f"{pid}.png")
    _write(run_dir / "selection.json", selection)
    cmd = [sys.executable, str(D.ART / "pipeline" / "pack_atlas.py"), str(spec_path), "--run", str(run_dir)]
    if paths.atlas_dir:
        cmd += ["--out-dir", str(paths.atlas_dir)]
    r = subprocess.run(cmd, cwd=D.ROOT, capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(f"pack failed: {r.stderr.strip()}")


def render_rig(c: dict, paths: Paths) -> tuple[Path, bool]:
    """Rig stage: render into the store when its key is new, then publish to art_runs/inputs."""
    def work(out: Path) -> None:
        py = os.environ.get("KUMBIA_BPY_PYTHON", str(Path.home() / ".cache/kumbia-bpy/bin/python"))
        r = subprocess.run([py, str(D.ART / "rig/standin.py"), "--character", c["id"], "--out", str(out)], cwd=D.ROOT, capture_output=True, text=True)
        if r.returncode:
            raise SystemExit(f"rig render failed: {r.stderr.strip()[-800:]}")
        r = subprocess.run([sys.executable, str(D.ART / "rig/check_poses.py"), str(out)], capture_output=True, text=True)
        if r.returncode:
            raise SystemExit(f"check_poses failed:\n{r.stdout[-2000:]}")

    ran_before = len(paths.store.ran)
    src = paths.store.run("rig", {"rig": rig_key(c)}, work)
    dst = paths.runs / "inputs" / c["family"]
    if not dst.exists() or (dst / "rig.json").read_bytes() != (src / "rig.json").read_bytes():
        shutil.rmtree(dst, ignore_errors=True)
        shutil.copytree(src, dst, ignore=shutil.ignore_patterns(".inputs.json"))
    return dst, len(paths.store.ran) > ran_before


def qwen_frame_key(c: dict, style: dict, backend: dict, pid: str, prompt: str, pose: dict, rig_pose: dict | None) -> str:
    """Identity of one Qwen frame: everything the model or the finish sees for this pose."""
    d = c["drawing"]
    sheet = D.ROOT / d["sheet"]["views"][pose.get("view", "front")]["image"]
    seen = P.visible_regions(rig_pose) if rig_pose else set()
    return key_of({
        "backend": backend["id"], "pose": pid, "prompt": prompt, "graph": sha_file(D.ROOT / backend["workflow"]),
        "sheet": sha_file(sheet) if sheet.exists() else None,
        "skeleton": (rig_pose or {}).get("openpose"), "moved": d.get("skeletonOverrides", {}).get(pid),
        "scale": d.get("poseOverrides", {}).get(pid, {}).get("skeletonScale", d.get("skeletonScale", backend["skeletonScale"])),
        "seed": d.get("seed", c.get("seedBase")), "count": d.get("count", backend["countPerPose"]),
        "colours": [[p.get("id"), p.get("colour")] for p in P.visible_parts(c, seen)],
        "targets": c.get("targets"),
        "style": {k: style.get(k) for k in ("frame", "ramp", "outline", "reservedRamps")},
    })


def plan_qwen(c: dict, style: dict, backend: dict, rig: dict | None, record: dict | None, store: Store, only: set[str] | None = None) -> dict:
    """Decide one action per frame on the Qwen route. Changes nothing."""
    table = Q.pose_table(c)
    prompts = Q.prompts(c, backend)
    accepted = Q.accepted_prompts(c, backend)
    if record and (record["backend"] != backend["id"] or "drawing" not in record["definition"]):
        record = None  # built on another route: nothing here carries over
    old_prompts = Q.prompts(record["definition"], backend) if record else {}
    changes = P.diff_definitions(record["definition"], c) if record else []
    restyled = bool(record) and record["styleKey"] != style_key(style)
    rig_by_id = {p["id"]: p for p in (rig or {}).get("poses", [])}
    frames = {}
    for pid, pose in table.items():
        rp = rig_by_id.get(pid)
        key = qwen_frame_key(c, style, backend, pid, prompts[pid], pose, rp)
        old = (record or {}).get("frameKeys", {}).get(pid)
        if has_frame(store, key):
            action, why = "reuse", []
        elif accepted.get(pid) == prompts[pid]:
            action, why = "accepted", []
        elif not record or old is None:
            action = "full"
            why = ["prompt differs from the accepted run"] if pid in accepted else ["no accepted drawing of this pose"]
        elif restyled:
            action, why = "full", ["style changed"]
        elif old_prompts.get(pid) != prompts[pid]:
            action, why = "full", ["prompt changed"]
        else:
            action, why = P.frame_mode(changes, rp or {"id": pid}, rp)
            if action in ("none", "masked"):  # the Qwen route has no masked pass
                action, why = "full", why or ["frame key changed with no classified edit"]
            have = has_frame(store, old)
            needs = {"recolour": "final.png", "finish": "raw.png"}.get(action)
            if needs and not (have and (frame_dir(store, old) / needs).exists()):
                action, why = "full", [*why, "previous frame is not in the store"]
        if only is not None and pid not in only and action in ("full", "finish", "recolour"):
            action, why = "later", ["outside --only"]
        frames[pid] = {"key": key, "previous": old, "action": action, "reasons": why, "prompt": prompts[pid]}
    counts: dict[str, int] = {}
    reasons: dict[str, int] = {}
    for f in frames.values():
        counts[f["action"]] = counts.get(f["action"], 0) + 1
        if f["action"] == "full":
            for r in f["reasons"]:
                reasons[r] = reasons.get(r, 0) + 1
    return {"character": c["id"], "frames": frames, "counts": counts, "changes": changes, "redrawReasons": reasons}


def qwen_cost(backend: dict, c: dict, jobs: int) -> dict:
    per_pose = c["drawing"].get("count", backend["countPerPose"])
    return {"estimatedImages": jobs * per_pose, "estimatedMinutes": round(jobs * backend["secondsPerJob"] / 60, 1),
            "secondsPerJob": backend["secondsPerJob"], "gpu": jobs > 0}


def adopt_accepted(plan: dict, c: dict, store: Store) -> int:
    """Accepted frames join the store under their key, so a mixed wave can pack them."""
    run = c["drawing"]["accepted"]["run"] if plan["counts"].get("accepted") else None
    n = 0
    for pid, f in plan["frames"].items():
        if f["action"] != "accepted":
            continue

        def work(out: Path, pid=pid) -> None:
            shutil.copyfile(D.ROOT / "art_runs" / run / "final" / f"{pid}.png", out / "final.png")
            _write(out / "provenance.json", {"mode": "accepted", "run": run, "pose": pid})

        store.run("frame", {"frame": f["key"]}, work)
        n += 1
    return n


def build_qwen(c: dict, style: dict, backend: dict, paths: Paths, *, run: str | None, dry_run: bool, rig: dict | None,
               only: set[str] | None, stage: bool, show_prompts: bool) -> dict:
    drawn = Q.is_drawn(c)
    record = _read(paths.runs / "builds" / f"{c['id']}.json")
    key = rig_key(c)
    rig_dir = paths.runs / "inputs" / c["family"]
    if not (rig_dir / "rig.json").exists():
        rig_dir = D.ROOT / "art_runs" / "inputs" / c["family"]
    injected = rig is not None
    have_rig = injected or (rig_dir / "rig.json").exists()
    if not injected and have_rig and not drawn:
        rig = json.loads((rig_dir / "rig.json").read_text())
    plan = plan_qwen(c, style, backend, rig, record, paths.store, only)
    needed = {p for p, f in plan["frames"].items() if f["action"] == "full"}
    missing = Q.missing_views(c)
    rendered = False
    # A rig is only worth rendering for frames about to be drawn, or to have one at all.
    stale_rig = not record or record["rigKey"] != key
    needs_render = not injected and not drawn and (not have_rig or (stale_rig and bool(needed)))
    if needs_render and stage and not dry_run:
        rig_dir, rendered = render_rig(c, paths)
        rig = json.loads((rig_dir / "rig.json").read_text())
        plan = plan_qwen(c, style, backend, rig, record, paths.store, only)
    jobs_now = len(missing) if missing else len(needed)
    report = {"character": c["id"], "route": backend["id"], "dryRun": dry_run, **plan, "frames": plan["frames"],
              "jobs": {"sheet": len(missing), "frames": 0 if missing else len(needed), "held": len(needed) if missing else 0},
              "jobsTotal": len(missing) + len(needed), "missingViews": missing, "reservedClips": Q.reserved_clips(c),
              "acceptedRun": c["drawing"].get("accepted", {}).get("run"),
              "rigRender": "none" if drawn else ("needed" if needs_render and dry_run else ("rendered" if rendered else "reused")),
              **qwen_cost(backend, c, len(missing) + len(needed))}
    first = sorted(needed)[0] if needed else next(iter(plan["frames"]))
    report["samplePrompt"] = {first: plan["frames"][first]["prompt"]}
    if show_prompts:
        report["prompts"] = {p: f["prompt"] for p, f in plan["frames"].items()}
    if dry_run:
        return report
    selection, returned = Sel.reconcile(_read(paths.runs / "selections" / f"{c['id']}.json", {}), {p: f["key"] for p, f in plan["frames"].items()})
    report["returnToReview"] = returned
    if not needed and not missing and set(plan["counts"]) <= {"accepted"}:
        report.update(queued=0, held=0, finishQueued=0, packed=False, note="every frame is in the accepted run: nothing to draw or pack")
        return report
    _write(paths.runs / "selections" / f"{c['id']}.json", selection)
    report["recoloured"] = recolour_frames(plan, record, c, style, paths.store) if plan["counts"].get("recolour") else 0
    run = run or f"{c['family']}-{key_of(sorted(f['key'] for f in plan['frames'].values()))[:10]}"
    report["run"] = run
    finish = [p for p, f in plan["frames"].items() if f["action"] == "finish"]
    spec = spec_path = None
    if c.get("status", "active") == "active":
        spec, palette, motion = CF.compile_definition(c, backend["id"])
        _, _, spec_path = CF.write_family(spec, palette, motion, paths.families, paths.palettes)
    os.chdir(D.ROOT)
    run_dir = paths.runs / run
    if needed or finish or missing:
        planned = Q.plan_run(c, backend, run, only=needed, runs_root=paths.runs, lane_root=paths.lane, rig_dir=rig_dir, stage=stage)
        if planned["sheet"]:
            _write(run_dir / "jobs.sheet.json", planned["sheet"])
        name = "jobs.held.json" if missing else "jobs.json"
        if planned["frames"]:
            _write(run_dir / name, planned["frames"])
        _write(run_dir / "pending.json", {p: plan["frames"][p]["key"] for p in sorted(needed | set(finish))})
        if finish:
            _write(run_dir / "finish.queue.json", {p: str(frame_dir(paths.store, plan["frames"][p]["previous"]) / "raw.png") for p in finish})
        report.update(queued=0 if missing else len(planned["frames"]), held=len(planned["frames"]) if missing else 0,
                      sheetQueued=len(planned["sheet"]), finishQueued=len(finish), packed=False)
        return report
    if spec_path is None:
        report.update(queued=0, held=0, finishQueued=0, packed=False,
                      note=f"{c['id']} is {c['status']}: frames are stored, and finish and pack need a family spec, which this status does not have yet")
        return report
    if plan["counts"].get("later"):
        report.update(queued=0, held=0, finishQueued=0, packed=False, note="poses outside --only are still undrawn: nothing packed")
        return report
    adopt_accepted(plan, c, paths.store)
    pack(spec_path, spec, plan, run, paths, selection)
    _write(paths.runs / "builds" / f"{c['id']}.json", {
        "definition": c, "style": {k: style.get(k) for k in ("prompt", "negative", "frame", "ramp", "outline", "reservedRamps", "generation")},
        "styleKey": style_key(style), "backend": backend["id"], "rigKey": key,
        "frameKeys": {p: f["key"] for p, f in plan["frames"].items()}, "run": run})
    report.update(queued=0, held=0, finishQueued=0, packed=True)
    return report


def accept_sheet(c: dict, view: str, image: str) -> dict:
    """Run only after the owner approves a view: frames then draw from this file."""
    views = Q.drawing_of(c)["sheet"]["views"]
    if view not in views:
        raise D.DefinitionError([f"drawing.sheet.views.{view}: no such view (have {sorted(views)})"])
    src, dst = Path(image), D.ROOT / views[view]["image"]
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    side = src.with_name(src.name + ".provenance.json")
    if not side.exists():
        side = src.with_suffix(".provenance.json")
    if side.exists():
        shutil.copyfile(side, dst.with_suffix(".provenance.json"))
    return {"character": c["id"], "view": view, "image": str(dst.relative_to(D.ROOT)), "provenance": side.exists(),
            "missingViews": Q.missing_views(c)}


def build(c: dict, paths: Paths, *, backend_id: str | None = None, run: str | None = None, dry_run: bool = False,
          rig: dict | None = None, only: set[str] | None = None, stage: bool = True, show_prompts: bool = False) -> dict:
    """rig= injects a rig and skips the render (tests, and dry runs over the committed rig)."""
    style = D.load_style(c["style"])
    backend = D.resolve_backend(c, style, backend_id)
    if c.get("status", "active") == "active":
        C.build_ramps(c, style)  # gate refusals before any work
    if backend.get("route") == "qwen":
        return build_qwen(c, style, backend, paths, run=run, dry_run=dry_run, rig=rig, only=only, stage=stage, show_prompts=show_prompts)
    record = _read(paths.runs / "builds" / f"{c['id']}.json")
    key = rig_key(c)
    rig_dir = paths.runs / "inputs" / c["family"]
    rendered = False
    needs_render = rig is None and (not record or record["rigKey"] != key or not (rig_dir / "rig.json").exists())
    if dry_run and needs_render:
        if not (rig_dir / "rig.json").exists():
            return {"character": c["id"], "dryRun": True, "rigRender": "needed", "frames": {}, "counts": {},
                    "note": "no rig yet: frame plan available after the first render"}
    elif needs_render:
        rig_dir, rendered = render_rig(c, paths)
    if rig is None:
        rig = json.loads((rig_dir / "rig.json").read_text())
    plan = plan_build(c, style, backend, rig, record, paths.store)
    ref = reference_state(c, style, paths)
    report = {**plan, "dryRun": dry_run, "rigRender": "needed" if needs_render and dry_run else ("rendered" if rendered else "reused"),
              "referenceHold": ref["hold"]}
    if dry_run:
        return report
    selection, returned = Sel.reconcile(_read(paths.runs / "selections" / f"{c['id']}.json", {}), {p: f["key"] for p, f in plan["frames"].items()})
    _write(paths.runs / "selections" / f"{c['id']}.json", selection)
    report["returnToReview"] = returned
    report["recoloured"] = recolour_frames(plan, record, c, style, paths.store) if plan["counts"].get("recolour") else 0
    run = run or f"{c['family']}-{key_of(sorted(f['key'] for f in plan['frames'].values()))[:10]}"
    report["run"] = run
    spec, palette, motion = CF.compile_definition(c, backend_id)
    _, _, spec_path = CF.write_family(spec, palette, motion, paths.families, paths.palettes)
    os.chdir(D.ROOT)
    needed = {p for p, f in plan["frames"].items() if f["action"] in ("full", "masked")}
    finish = [p for p, f in plan["frames"].items() if f["action"] == "finish"]
    if needed or finish:
        name = "jobs.held.json" if ref["hold"] else "jobs.json"
        jobs = PJ.plan_run(spec_path, run, only=needed or {"\0none"}, lane_root=paths.lane, runs_root=paths.runs,
                           identity=ref["image"], jobs_name=name, tier=backend.get("tier", "I1"))
        old_rig = None
        if record and any(plan["frames"][j["pose"]]["action"] == "masked" for j in jobs):
            old = paths.store.path("rig", key_of({"rig": record["rigKey"]}))
            old_rig = old if (old / "rig.json").exists() else None
        jobs = masked_jobs(jobs, plan, rig_dir, old_rig, c, paths, run)
        _write(paths.runs / run / name, jobs)
        _write(paths.runs / run / "pending.json", {p: plan["frames"][p]["key"] for p in sorted(needed | set(finish))})
        if finish:
            _write(paths.runs / run / "finish.queue.json", {p: str(frame_dir(paths.store, plan["frames"][p]["previous"]) / "raw.png") for p in finish})
        report.update(queued=0 if ref["hold"] else len(jobs), held=len(jobs) if ref["hold"] else 0, finishQueued=len(finish), packed=False)
        return report
    pack(spec_path, spec, plan, run, paths, selection)
    _write(paths.runs / "builds" / f"{c['id']}.json", {
        "definition": c, "style": {k: style.get(k) for k in ("prompt", "negative", "frame", "ramp", "outline", "reservedRamps", "generation")},
        "styleKey": style_key(style), "backend": backend["id"], "rigKey": key,
        "frameKeys": {p: f["key"] for p, f in plan["frames"].items()}, "run": run})
    report.update(queued=0, held=0, finishQueued=0, packed=True)
    return report


def ingest(c: dict, run: str, paths: Paths) -> dict:
    """Record finished frames in the store. Pixels come from art_runs/<run>/final/."""
    run_dir = paths.runs / run
    pending = _read(run_dir / "pending.json")
    if pending is None:
        raise SystemExit(f"no pending.json in {run_dir}")
    selection = _read(run_dir / "selection.json", {})
    missing, stored = [], 0
    for pid, key in pending.items():
        final = run_dir / "final" / f"{pid}.png"
        if not final.exists():
            missing.append(pid)
            continue
        k = (selection.get(pid) or {}).get("k") if isinstance(selection.get(pid), dict) else selection.get(pid)
        raw = run_dir / "raw" / pid / f"{k}.png"

        def work(out: Path, final=final, raw=raw, pid=pid, k=k) -> None:
            shutil.copyfile(final, out / "final.png")
            if raw.exists():
                shutil.copyfile(raw, out / "raw.png")
            _write(out / "provenance.json", {"mode": "generated", "run": run, "pose": pid, "candidate": k})

        paths.store.run("frame", {"frame": key}, work)
        stored += 1
    return {"run": run, "stored": stored, "missing": sorted(missing)}


def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("character")
    b.add_argument("--backend")
    b.add_argument("--run")
    b.add_argument("--dry-run", action="store_true")
    b.add_argument("--prompts", action="store_true", help="include every pose's prompt in the report")
    b.add_argument("--only", default="", help="clips or pose ids to draw now, as a pilot")
    b.add_argument("--no-stage", action="store_true", help="write workflows and jobs, leaving the lane and the rig alone")
    i = sub.add_parser("ingest")
    i.add_argument("character")
    i.add_argument("--run", required=True)
    s = sub.add_parser("accept-sheet")
    s.add_argument("character")
    s.add_argument("--view", required=True)
    s.add_argument("--image", required=True)
    r = sub.add_parser("accept-reference")
    r.add_argument("character")
    r.add_argument("--image", required=True)
    a = ap.parse_args()
    paths = Paths(store=Store())
    try:
        c = D.load_character(a.character)
        if a.cmd == "build":
            only = None
            if a.only:
                want = a.only.split(",")
                only = {p for p in Q.pose_table(c) if p in want or p.split(".")[0] in want}
            rep = build(c, paths, backend_id=a.backend, run=a.run, dry_run=a.dry_run, only=only, stage=not a.no_stage, show_prompts=a.prompts)
            rep = {k: v for k, v in rep.items() if k != "frames"}
        elif a.cmd == "ingest":
            rep = ingest(c, a.run, paths)
        elif a.cmd == "accept-sheet":
            rep = accept_sheet(c, a.view, a.image)
        else:
            style = D.load_style(c["style"])
            rep = {"character": c["id"], "key": reference_key(c, style), "accepted": True, "image": a.image}
            _write(paths.runs / "references" / f"{c['id']}.json", rep)
    except (D.DefinitionError, C.GateViolation) as e:
        sys.exit(f"refused:{a.character}:{e}")
    print(json.dumps(rep, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
