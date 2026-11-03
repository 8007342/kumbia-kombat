#!/usr/bin/env python3
"""Rebuild a character-frames family spec's poses[] from the rig output.

The rig (tool/art/rig/standin.py) is the source of truth for poses; this
keeps the family spec in step with it so nobody hand-edits 64 pose records:

  rig.json            -> supportFoot, control/aux/regionMask paths, order
  poses.intent.json   -> phase, intent (plain-English body action for prompts)
  animation-principles.json -> animationPrinciples per pose (by phase/clip),
                         and the spec's top-level animationReferences block

It also normalises the spec to contract 1935-k2ib/v1: no "$comment" keys
inside maps whose keys are validated (regions, frame.native), and the regions
map declares every colour the rig renders.

Usage:
  python3 tool/art/pipeline/sync_family.py tool/art/families/gatekeeper-v3.json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

CONTRACT = "1935-k2ib/v1"
REFERENCES = "tool/art/references/animation-principles.json"


def principles_for(pose_id: str, clip: str, phase: str, refs: dict) -> list[str]:
    drawing = pose_id.split(".", 1)[1] if "." in pose_id else pose_id
    tags = {clip, phase, drawing, drawing.rstrip("_lr0123456789").rstrip("_")}
    out = []
    for p in refs["principles"]:
        ph = set(p.get("phases", []))
        if "*" in ph or ph & tags:
            out.append(p["id"])
    return out


def apply_rig(spec: dict, research: list[str] | None = None) -> tuple[int, int]:
    """Fill spec's poses, regions and animationReferences from its rigInputs."""
    profiles = spec.get("generation", {}).get("profileRules", [])
    inputs_dir = Path(spec["rigInputs"])
    rig = json.loads((inputs_dir / "rig.json").read_text())
    intents_p = inputs_dir / "poses.intent.json"
    intents = json.loads(intents_p.read_text()) if intents_p.exists() else {}
    if isinstance(intents, dict) and isinstance(intents.get("poses"), dict):
        intents = intents["poses"]
    if isinstance(intents, list):
        intents = {i["id"]: i for i in intents}
    refs = json.loads(Path(REFERENCES).read_text())

    spec["contract"] = CONTRACT
    notes = spec.setdefault("$notes", {})

    # regions: declared colours = rig colours; comments move to $notes
    regions = spec.get("regions", {})
    if "$comment" in regions:
        notes["regions"] = regions.pop("$comment")
    for name, colour in rig["regions"].items():
        regions[colour.upper()] = name
    spec["regions"] = {k.upper(): v for k, v in regions.items()}

    native = spec["frame"].get("native")
    if isinstance(native, dict) and "$comment" in native:
        notes["frame.native"] = native.pop("$comment")

    clip_order: dict[str, int] = {}
    poses = []
    used_principles: set[str] = set()
    for rp in rig["poses"]:
        pid = rp["id"]
        clip = pid.split(".", 1)[0]
        order = clip_order.get(clip, 0)
        clip_order[clip] = order + 1
        it = intents.get(pid, {})
        # intent phases read like "down (beat 1, back-step)": the tag is the first word
        phase = (it.get("phase") or pid.split(".", 1)[1]).split(" ", 1)[0].strip(",;")
        base = f"{inputs_dir.as_posix()}/{pid}"
        pr = principles_for(pid, clip, phase, refs)
        used_principles.update(pr)
        profile = next((r["profile"] for r in profiles
                        if clip in r.get("clips", []) or phase in r.get("phases", [])
                        or pid in r.get("poses", [])), spec["generation"].get("defaultProfile", "moderate"))
        support = rp.get("support", "both")
        poses.append({
            "id": pid,
            "clip": clip,
            "order": order,
            "view": it.get("view", "front"),
            "control": {
                "type": "openpose",
                "image": f"{base}.pose.png",
                "aux": [{"type": "depth", "image": f"{base}.depth.png"},
                        {"type": "lineart", "image": f"{base}.lineart.png"}],
            },
            "regionMask": f"{base}.regions.png",
            "supportFoot": support if support in ("left", "right", "both", "none") else "both",
            "accent": phase in ("peak", "accent", "contact", "proud", "finish_a", "finish_b", "nod", "open_hand"),
            "phase": phase,
            "phaseNote": it.get("phase", ""),
            "intent": it.get("description", ""),
            "profile": profile,
            "animationPrinciples": pr,
        })
    spec["poses"] = poses
    for c in spec.get("clips", []):
        c["drawings"] = clip_order.get(c["id"], c.get("drawings", 1))

    spec["animationReferences"] = {
        "registry": REFERENCES,
        "research": research or [
            "plan/research/gatekeeper-dance-2026-11-02.md",
            "plan/dance-fluidity-pass.md",
            "plan/opponent-depth-staging-pass.md",
        ],
        "principlesUsed": sorted(used_principles),
        "sourcesUsed": sorted({s for p in refs["principles"] if p["id"] in used_principles
                               for s in p["sources"]}),
    }
    return len(poses), len(used_principles)


def main(spec_path: str) -> None:
    spec_p = Path(spec_path)
    spec = json.loads(spec_p.read_text())
    n, used = apply_rig(spec)
    spec_p.write_text(json.dumps(spec, indent=1, ensure_ascii=False) + "\n")
    print(f"synced {spec_p}: {n} poses, {used} principles, contract {CONTRACT}")


if __name__ == "__main__":
    main(sys.argv[1])
