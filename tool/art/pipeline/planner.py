#!/usr/bin/env python3
"""Impact analysis: what a definition edit touches, how, and what it costs.

Reads old and new definitions and the rig's per-frame region visibility. Changes
nothing: the report goes to stdout, or to --out when asked.

  planner.py plan <character> [--from REV|FILE] [--backend ID] [--mode MODE] [--selection FILE] [--rig RIG.json] [--out FILE]
  planner.py plan-style <style> [--from REV|FILE]

Without --from, the old definition is the version committed at HEAD.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import colour as C  # noqa: E402
import definitions as D  # noqa: E402
import plan_qwen_frames as Q  # noqa: E402
from stages import key_of  # noqa: E402

MODES = ("none", "recolour", "finish", "masked", "full")
RANK = {m: i for i, m in enumerate(MODES)}
LARGE_VALUE_CHANGE = 35.0  # OKLab L points


def parts_of(c: dict) -> dict[str, dict]:
    """Every coloured or shaped part by id. Region is what decides visibility."""
    out = {"skin": {"region": "skin", "colour": c.get("skin"), "kind": "skin"}}
    for g in c["garments"]:
        out[g["id"]] = {**g, "kind": "garment"}
    for p in c.get("props", []):
        out[p["id"]] = {**p, "region": "prop", "kind": "prop"}
    return out


GEOMETRY_FIELDS = ("shape", "region", "params", "kind", "hand", "clips", "secondaryMotion", "alsoIn")


def diff_definitions(old: dict, new: dict) -> list[dict]:
    """Classify an edit. mode: recolour | masked | finish | full; region set or None for all."""
    changes: list[dict] = []
    a, b = parts_of(old), parts_of(new)
    for pid in sorted(set(a) | set(b)):
        pa, pb = a.get(pid), b.get(pid)
        if pa == pb:
            continue
        if pa is None or pb is None:
            changes.append({"part": pid, "what": "added" if pa is None else "removed", "mode": "masked",
                            "regions": sorted(regions_of(pb or pa))})
            continue
        regions = sorted(regions_of(pa) | regions_of(pb))
        if any(pa.get(f) != pb.get(f) for f in GEOMETRY_FIELDS):
            changes.append({"part": pid, "what": "geometry", "mode": "masked", "regions": regions})
        elif pa.get("colour") != pb.get("colour"):
            ch = {"part": pid, "what": "colour", "mode": "recolour", "regions": regions, "from": pa.get("colour"), "to": pb.get("colour")}
            changes.append(ch)
        else:
            changes.append({"part": pid, "what": "text", "mode": "masked", "regions": regions})
    for field, label in (("body", "body"), ("traits", "traits"), ("demeanor", "demeanor"), ("pronouns", "pronouns"),
                         ("style", "style"), ("backend", "backend"), ("seedBase", "seed"), ("references", "references")):
        if old.get(field) != new.get(field):
            changes.append({"part": label, "what": label, "mode": "full", "regions": None})
    if old.get("drawing") != new.get("drawing"):
        poses = drawing_changes(old, new)
        if poses is None or poses:  # an edit no frame sees, such as a note, changes nothing
            changes.append({"part": "drawing", "what": "drawing", "mode": "full", "regions": None, "poses": poses})
    om, nm = old["motion"], new["motion"]
    if om["set"] != nm["set"]:
        changes.append({"part": "motion", "what": "motion set", "mode": "full", "regions": None})
    else:
        oo, no = om.get("overrides", {}), nm.get("overrides", {})
        for pose in sorted(set(oo) | set(no)):
            if oo.get(pose) != no.get(pose):
                changes.append({"part": "motion", "what": f"pose override {pose}", "mode": "full", "regions": None, "poses": [pose]})
    if old.get("targets") != new.get("targets"):
        changes.append({"part": "targets", "what": "targets", "mode": "finish", "regions": None})
    return changes


def drawing_changes(old: dict, new: dict) -> list[str] | None:
    """Which poses a `drawing` edit reaches, or None for all of them."""
    a, b = old.get("drawing"), new.get("drawing")
    if not a or not b or any(a.get(f) != b.get(f) for f in ("seed", "count", "skeletonScale", "sheet")):
        return None
    pa, pb = Q.prompts(old), Q.prompts(new)
    return sorted(p for p in set(pa) | set(pb) if pa.get(p) != pb.get(p)
                  or a.get("skeletonOverrides", {}).get(p) != b.get("skeletonOverrides", {}).get(p)
                  or a.get("poseOverrides", {}).get(p) != b.get("poseOverrides", {}).get(p))


def visible_regions(rig_pose: dict) -> set[str]:
    return {r for r, n in rig_pose.get("regionPixels", {}).items() if n > 0}


def regions_of(part: dict) -> set[str]:
    return {part["region"], *part.get("alsoIn", [])}


def visible_parts(c: dict, regions: set[str]) -> list[dict]:
    return [p for _, p in sorted(parts_of(c).items()) if regions_of(p) & regions]


def frame_key(c: dict, style: dict, backend: dict, rig_pose: dict) -> str:
    """Identity of one finished frame: only what can show in it.

    A garment hidden in this frame is left out, so editing it keeps the frame's key
    and its acceptance. A shot's viewport can narrow rig_pose's regions the same way.
    """
    return key_of({
        "pose": rig_pose["id"], "params": rig_pose.get("params"), "support": rig_pose.get("support"),
        "override": c["motion"].get("overrides", {}).get(rig_pose["id"]), "motion": c["motion"]["set"],
        "body": c["body"], "traits": c.get("traits"), "demeanor": c.get("demeanor"), "pronouns": c.get("pronouns"),
        "seedBase": c.get("seedBase"), "references": c.get("references"), "targets": c.get("targets"),
        "parts": visible_parts(c, visible_regions(rig_pose)),
        "style": {k: style.get(k) for k in ("prompt", "negative", "frame", "ramp", "outline", "reservedRamps")},
        "backend": backend,
    })


def frame_mode(changes: list[dict], rig_pose: dict, rig_new: dict | None) -> tuple[str, list[str]]:
    mode, why = "none", []
    pid = rig_pose["id"]
    seen = visible_regions(rig_pose) | (visible_regions(rig_new) if rig_new else set())
    for ch in changes:
        if ch.get("poses") and pid not in ch["poses"]:
            continue
        if ch["regions"] is not None and not (set(ch["regions"]) & seen):
            # A region the old rig never rendered can't be judged until the new rig exists.
            if not (ch["what"] == "added" and rig_new is None):
                continue
        if RANK[ch["mode"]] > RANK[mode]:
            mode = ch["mode"]
        why.append(f"{ch['part']}: {ch['what']}")
    return mode, why


def plan(old: dict, new: dict, rig: dict, style: dict, backend: dict, *, new_rig: dict | None = None,
         selection: dict | None = None, force: str | None = None) -> dict:
    changes = diff_definitions(old, new)
    new_by_id = {p["id"]: p for p in (new_rig or {}).get("poses", [])}
    frames, counts = {}, {m: 0 for m in MODES}
    for rp in rig["poses"]:
        mode, why = frame_mode(changes, rp, new_by_id.get(rp["id"]))
        if mode == "masked" and backend.get("route") == "qwen":
            mode = "full"  # the Qwen route redraws; it has no masked pass
        if force and mode != "none" and RANK[force] > RANK[mode]:
            mode = force
        frames[rp["id"]] = {"mode": mode, "reasons": why}
        counts[mode] += 1
    per_pose = backend.get("countPerPose") or style.get("generation", {}).get("count_per_pose", 1)
    images = (counts["masked"] + counts["full"]) * per_pose
    warnings = []
    for ch in changes:
        if ch["what"] == "colour" and ch.get("from") and ch.get("to"):
            dl = abs(C.oklab(C.hex_to_rgb(ch["from"]))[0] - C.oklab(C.hex_to_rgb(ch["to"]))[0])
            if dl > LARGE_VALUE_CHANGE:
                warnings.append(f"{ch['part']}: recolour may look flat (large value change); --mode masked is available")
    if backend.get("negatives") == "ineffective" and images:
        warnings.append(f"backend {backend['id']}: negative prompts have no effect, so the style's negatives will not be honoured")
    selection = selection or {}
    back = sorted(p for p, f in frames.items() if f["mode"] != "none" and isinstance(selection.get(p), dict) and selection[p].get("accepted"))
    generates = images > 0
    ref_action = "none"
    if any(ch["mode"] in ("masked", "full") and ch["what"] not in ("text",) for ch in changes):
        ref_action = "rebuild-then-review" if generates and new.get("references", {}).get("mode") == "derive" else "review"
    elif any(ch["what"] == "colour" for ch in changes):
        ref_action = "recolour"
    return {"character": new["id"], "changes": changes, "counts": counts, "frames": frames,
            "visibilityResolved": new_rig is not None or not any(c["what"] == "added" for c in changes),
            "gpu": generates, "estimatedImages": images, "returnToReview": back,
            "references": ref_action, "warnings": warnings, "dryRun": True}


def plan_style_edit(old: dict, new: dict, characters: list[dict]) -> dict:
    fields = sorted(k for k in set(old) | set(new) if old.get(k) != new.get(k))
    users = sorted(c["id"] for c in characters if c["style"] == new["id"])
    return {"style": new["id"], "changedFields": fields, "affectedCharacters": users if fields else [],
            "mode": "full" if set(fields) - {"description", "$comment"} else "none", "dryRun": True}


def plan_variant(c: dict, variant_id: str) -> dict:
    v = c["variants"][variant_id]
    shaped = bool(v.get("garments"))
    return {"variant": variant_id, "mode": "masked" if shaped else "lut", "gpu": shaped,
            "ownAtlas": shaped, "estimatedImages": None if shaped else 0}


def _old_json(rel: str, ref: str) -> dict:
    p = Path(ref)
    if p.exists():
        return json.loads(p.read_text())
    out = subprocess.run(["git", "show", f"{ref}:{rel}"], cwd=D.ROOT, capture_output=True, text=True)
    if out.returncode:
        raise SystemExit(f"cannot read old definition {ref}:{rel}: {out.stderr.strip()}")
    return json.loads(out.stdout)


def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    pc = sub.add_parser("plan")
    pc.add_argument("character")
    pc.add_argument("--from", dest="ref", default="HEAD")
    pc.add_argument("--backend")
    pc.add_argument("--mode", choices=MODES[1:])
    pc.add_argument("--selection")
    pc.add_argument("--rig")
    pc.add_argument("--new-rig")
    pc.add_argument("--out")
    ps = sub.add_parser("plan-style")
    ps.add_argument("style")
    ps.add_argument("--from", dest="ref", default="HEAD")
    a = ap.parse_args()
    if a.cmd == "plan-style":
        new = D.load_style(a.style)
        old = _old_json(f"tool/art/styles/{a.style}.json", a.ref)
        chars = [json.loads(f.read_text()) for f in sorted((D.ART / "characters").glob("*.json"))]
        print(json.dumps(plan_style_edit(old, new, chars), indent=1, ensure_ascii=False))
        return
    try:
        new = D.load_character(a.character)
        style = D.load_style(new["style"])
        backend = D.resolve_backend(new, style, a.backend)
        C.build_ramps(new, style)
    except (D.DefinitionError, C.GateViolation) as e:
        sys.exit(f"refused:{a.character}:{e}")
    old = _old_json(f"tool/art/characters/{a.character}.json", a.ref)
    rig_path = Path(a.rig) if a.rig else D.ROOT / "art_runs" / "inputs" / old.get("family", a.character) / "rig.json"
    rig = json.loads(rig_path.read_text())
    new_rig = json.loads(Path(a.new_rig).read_text()) if a.new_rig else None
    selection = json.loads(Path(a.selection).read_text()) if a.selection else None
    report = plan(old, new, rig, style, backend, new_rig=new_rig, selection=selection, force=a.mode)
    text = json.dumps(report, indent=1, ensure_ascii=False) + "\n"
    if a.out:
        Path(a.out).write_text(text)
    print(text if not a.out else json.dumps({k: report[k] for k in ("character", "counts", "gpu", "estimatedImages", "references", "warnings")}, indent=1))


if __name__ == "__main__":
    main()
