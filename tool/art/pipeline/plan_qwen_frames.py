#!/usr/bin/env python3
"""Plan sheet-driven frames: Qwen draws the character from the model sheet, posed by data.

Everything per-character lives in tool/art/characters/<id>.json under `drawing`, and the prompt
templates in tool/art/backends/qwen-frame.json. art.py is the usual way in; this script plans one
run directly.

A pose comes from one of two places:
  - Skeleton (humans): the rig supplies only an OpenPose skeleton, never its mannequin, because a
    colour proxy or a clay figure gets copied, shapes included (art_runs/qwen-trials-20261105/).
    It is scaled down so the larger figure Qwen draws still fits the frame.
  - Reference (`drawing.motion`, non-humans): a sheet view and words, with no second image.

Each pose gets its own workflow, art_runs/<run>/workflows/<pose>.api.json, with its prompt baked in:
studio.run_workflow's prompt override doesn't reach TextEncodeQwenImageEditPlus, though provenance
records it as if it did (seen in ComfyUI's /history on 2026-11-05). Passing none keeps provenance true.

Hand fixes are data, and survive re-planning:
  drawing.poseOverrides   {pose: {description, props, skeletonScale, why}} when words and skeleton disagree
  drawing.skeletonOverrides {pose: {keypoint index: [x, y]}} moves joints for this drawing only, in
                          canvas pixels. Qwen follows the skeleton over the prompt, and the rig's wrists
                          stop short where its big hands would meet, so a clap reads as arms hanging down.

Usage: plan_qwen_frames.py <character> --run <run> [--only clip,pose.id] [--seed N] [--scale 0.8] [--count 4]
Writes art_runs/<run>/jobs.json (jobs.sheet.json first, if a sheet view is missing) and stages inputs
under /work/tmp/imagegen/kumbia/<run>/in/.
"""
from __future__ import annotations

import argparse
import copy
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "rig"))
import definitions as D  # noqa: E402
from poses import INTENT_BY_SET, MOTION_SETS, intent_text  # noqa: E402

STAGE = Path("/work/tmp/imagegen/kumbia")
BACKEND = "qwen-frame"
GREY = (226, 226, 226)
SHEET_CANVAS = (768, 960)


def is_drawn(c: dict) -> bool:
    """Posed by a sheet view and words: no rig, no skeleton."""
    return "motion" in c.get("drawing", {})


def drawing_of(c: dict) -> dict:
    if "drawing" not in c:
        raise D.DefinitionError([f"drawing: {c['id']} has no drawing block, which the qwen route needs"])
    return c["drawing"]


def motion_of(c: dict) -> dict:
    return D.load_motion(drawing_of(c)["motion"] if is_drawn(c) else c["motion"]["set"])


def reserved_clips(c: dict) -> list[str]:
    return [m["id"] for m in motion_of(c).get("clips", []) if m.get("status") == "reserved"]


def pose_table(c: dict) -> dict[str, dict]:
    """Every drawing this character needs, in rig order: {pose: {clip, phase, description, view}}."""
    if is_drawn(c):
        motion = motion_of(c)
        reserved = set(reserved_clips(c))
        for pid, p in motion["poses"].items():
            if p["clip"] in reserved:
                raise D.DefinitionError([f"motion.poses.{pid}: clip {p['clip']!r} is reserved, so it has no drawings yet"])
        return {pid: dict(p) for pid, p in motion["poses"].items()}
    table = {}
    overrides = c["motion"].get("overrides", {})
    intent = INTENT_BY_SET[c["motion"]["set"]]
    for clip, drawings in MOTION_SETS[c["motion"]["set"]].items():
        for name, (_, support) in drawings.items():
            pid = f"{clip}.{name}"
            phase, template = intent[pid]
            text = overrides.get(pid, {}).get("intent", template)
            table[pid] = {"clip": clip, "phase": phase, "support": support,
                          "description": intent_text(text, c["pronouns"])}
    return table


def check_overrides(c: dict, table: dict) -> None:
    """A hand fix keyed to a pose that doesn't exist would silently do nothing."""
    d = drawing_of(c)
    bad = [f"drawing.{field}.{pid}: unknown pose" for field in ("poseOverrides", "skeletonOverrides")
           for pid in d.get(field, {}) if pid not in table]
    if bad:
        raise D.DefinitionError(bad)


def grammar(c: dict) -> dict:
    """Pronoun fields for the templates, with verbs that agree with them."""
    sub, obj, poss = c["pronouns"]
    plural = sub.lower() == "they"
    verbs = {"faces": "face", "keeps": "keep", "holds": "hold", "has": "have"}
    return {"sub": sub, "Sub": sub.capitalize(), "obj": obj, "poss": poss,
            **{k: (v if plural else k) for k, v in verbs.items()}}


def props_text(c: dict, clip: str) -> str:
    """A sentence per prop this clip carries, naming the hand by picture side.

    A figure facing the viewer has its right hand on the left of the picture. "Her right hand" alone
    gave wrong-hand props (LESSONS_LEARNED A5). wording "own-hand" keeps that older sentence, only so
    a run drawn with it stays reproducible.
    """
    g = grammar(c)
    out = []
    for prop in c.get("props", []):
        if clip not in prop.get("clips", []):
            continue
        text = prop.get("text", prop["kind"])
        if prop.get("wording") == "own-hand":
            out.append(f"{g['Sub']} {g['holds']} a {text} in {g['poss']} {prop['hand']} hand. ")
        else:
            side = "left" if prop["hand"] == "right" else "right"
            out.append(f"{g['Sub']} {g['holds']} a {text} in the hand on the {side} side of the picture; "
                       f"{g['poss']} other hand is empty. ")
    return "".join(out)


def _sheet(c: dict) -> dict:
    return drawing_of(c)["sheet"]


def _look(c: dict, view: str | None) -> str:
    d = drawing_of(c)
    return (_sheet(c)["views"].get(view) or {}).get("look", d["look"])


def prompt_for(c: dict, backend: dict, pid: str, pose: dict) -> str:
    d = drawing_of(c)
    fix = d.get("poseOverrides", {}).get(pid, {})
    template = backend["prompts"]["reference" if is_drawn(c) else "skeleton"]
    props = fix["props"] if "props" in fix else props_text(c, pose["clip"])
    return template.format(noun=d["noun"], fits=d["fits"], look=_look(c, pose.get("view")), extra=d.get("extra", ""),
                           description=fix.get("description", pose["description"]), props=props, **grammar(c))


def prompts(c: dict, backend: dict | None = None) -> dict[str, str]:
    backend = backend or D.load_backend(BACKEND)
    table = pose_table(c)
    check_overrides(c, table)
    return {pid: prompt_for(c, backend, pid, p) for pid, p in table.items()}


def sheet_prompt(c: dict, backend: dict, view: str) -> str:
    d, sheet = drawing_of(c), _sheet(c)
    template = backend["prompts"]["sheetFromText" if sheet.get("source", {}).get("styleOnly") else "sheetFromReference"]
    return template.format(noun=d["noun"], fits=d["fits"], look=_look(c, view), extra=d.get("extra", ""),
                           description=sheet["views"][view].get("description", "facing the viewer"), props="", **grammar(c))


def missing_views(c: dict, table: dict | None = None) -> list[str]:
    """Sheet views frames depend on that aren't accepted yet. Frames wait for these."""
    return [v for v, spec in _sheet(c)["views"].items() if not (D.ROOT / spec["image"]).exists()]


def accepted_prompts(c: dict, backend: dict) -> dict[str, str]:
    """{pose: prompt} baked in the run the owner accepted, if the definition names one."""
    run = drawing_of(c).get("accepted", {}).get("run")
    if not run:
        return {}
    node = backend["promptNode"]
    out = {}
    for path in (D.ROOT / "art_runs" / run / "workflows").glob("*.api.json"):
        pid = path.name.removesuffix(".api.json")
        if (D.ROOT / "art_runs" / run / "final" / f"{pid}.png").exists():
            out[pid] = json.loads(path.read_text())[node]["inputs"]["prompt"]
    return out


def scaled(src: Path, dst: Path, scale: float) -> None:
    """Scale about the frame's bottom centre, leaving 5% below the feet."""
    im = Image.open(src).convert("RGB")
    w, h = im.size
    small = im.resize((int(w * scale), int(h * scale)), Image.BILINEAR)
    out = Image.new("RGB", (w, h), (0, 0, 0))
    out.paste(small, ((w - small.width) // 2, h - small.height - int(h * 0.05)))
    out.save(dst)


def stage_source(source: dict, dst: Path) -> None:
    """A sheet job's image 1: the source crop, flat on the light grey edit models expect."""
    im = Image.open(D.ROOT / source["image"]).convert("RGBA")
    if source.get("rect"):
        x, y, w, h = source["rect"]
        im = im.crop((x, y, x + w, y + h))
    cw, ch = SHEET_CANVAS
    factor = max(1, int(min(cw * 0.8 / im.width, ch * 0.8 / im.height)))
    big = im.resize((im.width * factor, im.height * factor), Image.NEAREST)
    out = Image.new("RGBA", SHEET_CANVAS, (*GREY, 255))
    out.paste(big, ((cw - big.width) // 2, (ch - big.height) // 2), big)
    out.convert("RGB").save(dst)


def one_image(workflow: dict) -> dict:
    """The frame graph without its skeleton input: image 1 and words only."""
    wf = copy.deepcopy(workflow)
    wf.pop("2", None)
    for node in wf.values():
        if node.get("class_type") == "TextEncodeQwenImageEditPlus":
            node["inputs"].pop("image2", None)
    return wf


def skeleton_png(c: dict, rig_dir: Path, rig_poses: dict, pid: str, lane: Path, scale: float) -> Path:
    from openpose_draw import draw_openpose

    skel = lane / f"{pid}.skeleton.png"
    source = rig_dir / f"{pid}.pose.png"
    moved = drawing_of(c).get("skeletonOverrides", {}).get(pid)
    if moved:
        pts = [list(pt) for pt in rig_poses[pid]["openpose"]]
        for joint, xy in moved.items():
            pts[int(joint)][:2] = xy
            pts[int(joint)][2] = 1
        adjusted = lane / f"{pid}.adjusted.png"
        with Image.open(source) as im:
            draw_openpose(adjusted, pts, [bool(pt[2]) for pt in pts], im.size)
        source = adjusted
    scaled(source, skel, scale)
    return skel


def plan_run(c: dict, backend: dict, run: str, *, only: set[str] | None = None, runs_root: Path | None = None,
             lane_root: Path | None = None, rig_dir: Path | None = None, stage: bool = True, seed: int | None = None,
             count: int | None = None, scale: float | None = None, workflow_root: str | None = None) -> dict[str, list[dict]]:
    """Bake workflows and return {"sheet": jobs, "frames": jobs}; the caller names the job files.

    stage=False writes workflows and job paths only, leaving the lane and the rig untouched.
    """
    d = drawing_of(c)
    table = pose_table(c)
    check_overrides(c, table)
    drawn = is_drawn(c)
    seed = seed if seed is not None else d.get("seed", c.get("seedBase", 0))
    count = count or d.get("count", backend["countPerPose"])
    default_scale = scale or d.get("skeletonScale", backend["skeletonScale"])
    runs = runs_root or D.ROOT / "art_runs"
    out = runs / run
    workflows = out / "workflows"
    workflows.mkdir(parents=True, exist_ok=True)
    base = json.loads((D.ROOT / backend["workflow"]).read_text())
    node = backend["promptNode"]
    lane = (lane_root or STAGE) / run / "in"
    rig_dir = rig_dir or D.ROOT / "art_runs" / "inputs" / c.get("family", c["id"])
    rig_poses = {}
    if stage:
        lane.mkdir(parents=True, exist_ok=True)
        if not drawn:
            rig_poses = {r["id"]: r for r in json.loads((rig_dir / "rig.json").read_text())["poses"]}

    views = _sheet(c)["views"]
    missing = missing_views(c)
    sheet_files = {}
    for view, spec in views.items():
        sheet_files[view] = lane / f"sheet_{view}.png"
        if stage and view not in missing:
            shutil.copy(D.ROOT / spec["image"], sheet_files[view])

    def bake(graph: dict, pid: str, prompt: str) -> Path:
        wf = copy.deepcopy(graph)
        wf[node]["inputs"]["prompt"] = prompt
        path = workflows / f"{pid}.api.json"
        path.write_text(json.dumps(wf, indent=1) + "\n")
        return path

    def rel(path: Path) -> str:
        try:
            return str(path.relative_to(D.ROOT))
        except ValueError:
            return str(path)

    def job(pid: str, path: Path, inputs: dict) -> dict:
        return {"pose": pid, "args": {"workflow": rel(path), "tier": backend.get("tier", "I1"), "count": count,
                                      "inputs": inputs, "overrides": {"seed": seed}}}

    sheet_jobs = []
    if missing:
        source = _sheet(c).get("source")
        if not source:
            raise D.DefinitionError([f"drawing.sheet.source: needed to draw the missing views {missing}"])
        src = lane / "sheet_source.png"
        if stage:
            stage_source(source, src)
        for view in missing:
            pid = f"sheet.{view}"
            inputs = {"sheet_front": str(src)}
            graph = one_image(base)
            if source.get("styleOnly"):
                # A new person: the style sheet plus a neutral skeleton, so build and framing start right.
                ref = motion_of(c)["referencePose"]
                inputs["pose_proxy"] = str(lane / f"{ref}.skeleton.png")
                graph = base
                if stage:
                    skeleton_png(c, rig_dir, rig_poses, ref, lane, default_scale)
            sheet_jobs.append(job(pid, bake(graph, pid, sheet_prompt(c, backend, view)), inputs))

    frame_jobs = []
    for pid, pose in table.items():
        if only is not None and pid not in only:
            continue
        fix = d.get("poseOverrides", {}).get(pid, {})
        if drawn:
            view = pose.get("view", "front")
            if view not in views:
                raise D.DefinitionError([f"motion.poses.{pid}.view: no sheet view {view!r}"])
            inputs = {"sheet_front": str(sheet_files[view])}
            graph = one_image(base)
        else:
            skel = lane / f"{pid}.skeleton.png"
            if stage:
                skel = skeleton_png(c, rig_dir, rig_poses, pid, lane, fix.get("skeletonScale", default_scale))
            inputs = {"sheet_front": str(sheet_files["front"]), "pose_proxy": str(skel)}
            graph = base
        frame_jobs.append(job(pid, bake(graph, pid, prompt_for(c, backend, pid, pose)), inputs))
    return {"sheet": sheet_jobs, "frames": frame_jobs}


def write_jobs(out: Path, name: str, jobs: list[dict]) -> None:
    (out / name).write_text(json.dumps(jobs, indent=1) + "\n")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("character")
    ap.add_argument("--run", required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--scale", type=float)
    ap.add_argument("--count", type=int, help="candidates per pose: seed, seed+1, ...")
    a = ap.parse_args()
    try:
        c = D.load_character(a.character)
        table = pose_table(c)
        want = [x for x in a.only.split(",") if x]
        only = {p for p in table if not want or p in want or p.split(".")[0] in want}
        planned = plan_run(c, D.load_backend(BACKEND), a.run, only=only, seed=a.seed, count=a.count, scale=a.scale)
    except D.DefinitionError as e:
        sys.exit(f"refused:{a.character}:{e}")
    out = D.ROOT / "art_runs" / a.run
    if planned["sheet"]:
        write_jobs(out, "jobs.sheet.json", planned["sheet"])
        write_jobs(out, "jobs.held.json", planned["frames"])
        print(f"{len(planned['sheet'])} sheet jobs in {out / 'jobs.sheet.json'}; {len(planned['frames'])} frame jobs held for review of the sheet")
        return
    write_jobs(out, "jobs.json", planned["frames"])
    print(f"{len(planned['frames'])} jobs in {out / 'jobs.json'}")


if __name__ == "__main__":
    main()
