#!/usr/bin/env python3
"""Stage inputs and write the studio job list for one family run.

For every pose in a family spec this:
  * copies the pose/depth/lineart controls to the lane volume
    (/work/tmp/imagegen/kumbia/<run>/in/), the only place the studio reads;
  * paints a colour-proxy init from the region mask (family.regionProxyColours)
    on the background colour, so img2img starts from the right silhouette;
  * crops the identity reference once;
  * composes the prompt: style + character + pose intent + the promptFragments
    of the pose's animationPrinciples (tool/art/references/animation-principles.json);
  * writes art_runs/<run>/jobs.json — one entry per pose holding the exact
    studio.run_workflow arguments — and art_runs/<run>/run.json (provenance).

The GPU step is an MCP tool call (studio.run_workflow), so an agent executes
jobs.json; tool/art/pipeline/collect.py then pulls outputs back.

Usage:
  python3 tool/art/pipeline/plan_jobs.py tool/art/families/gatekeeper-v3.json \
      --run gatekeeper-v3-20261102a [--only left_hand.peak,groove.down_l] [--count 4]
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image

LANE = Path("/work/tmp/imagegen/kumbia")
BG = (226, 226, 226)


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def hex_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def proxy(regions_png: Path, regions: dict, proxy_cols: dict, out: Path) -> None:
    im = Image.open(regions_png).convert("RGBA")
    lut = {hex_rgb(c): hex_rgb(proxy_cols[name]) for c, name in regions.items() if name in proxy_cols}
    px = [(lut.get(p[:3], p[:3]) if p[3] >= 128 else BG) for p in im.get_flattened_data()]
    o = Image.new("RGB", im.size)
    o.putdata(px)
    o.save(out)


def compose_prompt(spec: dict, pose: dict, principles: dict) -> tuple[str, str]:
    frags, negs = [], []
    for pid in pose.get("animationPrinciples", []):
        p = principles.get(pid, {})
        if p.get("promptFragment"):
            frags.append(p["promptFragment"])
        if p.get("negativeFragment"):
            negs.append(p["negativeFragment"])
    parts = [spec["style_prompt"], spec["character_prompt"]]
    if pose.get("intent"):
        parts.append(pose["intent"])
    parts += frags
    # dedupe while keeping order; note cfg 1.0 (Lightning) largely ignores negatives
    seen, neg_terms = set(), []
    for t in ", ".join([spec["style_negative"]] + negs).split(", "):
        if t and t not in seen:
            seen.add(t)
            neg_terms.append(t)
    neg = ", ".join(neg_terms)
    return ", ".join(parts), neg


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("spec")
    ap.add_argument("--run", required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--count", type=int, default=None)
    ap.add_argument("--tier", default="I1")
    a = ap.parse_args()

    spec_p = Path(a.spec)
    spec = json.loads(spec_p.read_text())
    refs = json.loads(Path(spec["animationReferences"]["registry"]).read_text())
    principles = {p["id"]: p for p in refs["principles"]}
    gen = spec["generation"]
    count = a.count or gen.get("count_per_pose", 1)
    only = {x for x in a.only.split(",") if x}

    lane = LANE / a.run / "in"
    lane.mkdir(parents=True, exist_ok=True)
    run_dir = Path("art_runs") / a.run
    run_dir.mkdir(parents=True, exist_ok=True)

    ident = spec["references"][0]
    ident_out = lane / "identity.png"
    src = Image.open(ident["image"]).convert("RGBA")
    crop = ident.get("crop")
    if isinstance(crop, dict) and "rect" in crop:
        x, y, w, h = crop["rect"]
        src = src.crop((x, y, x + w, y + h))
    flat = Image.new("RGB", src.size, BG)
    flat.paste(src, mask=src.split()[3])
    flat.save(ident_out)

    jobs = []
    for idx, pose in enumerate(spec["poses"]):
        if only and pose["id"] not in only:
            continue
        pid = pose["id"]
        files = {"pose": Path(pose["control"]["image"])}
        for aux in pose["control"].get("aux", []):
            files[aux["type"]] = Path(aux["image"])
        staged = {}
        for k, f in files.items():
            dst = lane / f"{pid}.{k}.png"
            shutil.copyfile(f, dst)
            staged[k] = str(dst)
        init = lane / f"{pid}.proxy.png"
        proxy(Path(pose["regionMask"]), spec["regions"], spec["regionProxyColours"], init)
        prompt, neg = compose_prompt(spec, pose, principles)
        profile = pose.get("profile", gen.get("defaultProfile", "moderate"))
        wf_inputs = {"pose": staged["pose"], "depth": staged["depth"],
                     "lineart": staged["lineart"], "identity": str(ident_out)}
        wf_text = Path(gen["workflowsByProfile"][profile]).read_text()
        wf_inputs = {k: v for k, v in wf_inputs.items() if f'"${k}"' in wf_text}
        seed = gen["seed_base"] + 100 * idx
        jobs.append({
            "pose": pid,
            "profile": profile,
            "args": {
                "workflow": gen["workflowsByProfile"][profile],
                "tier": a.tier,
                "count": count,
                "inputs": wf_inputs,
                "init_image": str(init),
                "overrides": {"prompt": prompt, "negative_prompt": neg, "seed": seed},
            },
            "animationPrinciples": pose.get("animationPrinciples", []),
            "inputHashes": {k: sha(Path(v)) for k, v in staged.items()},
        })

    (run_dir / "jobs.json").write_text(json.dumps(jobs, indent=1, ensure_ascii=False) + "\n")
    run = {
        "run": a.run,
        "created": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "family": str(spec_p),
        "familySha256": sha(spec_p),
        "contract": spec["contract"],
        "tier": a.tier,
        "countPerPose": count,
        "poses": len(jobs),
        "workflows": {k: sha(Path(v)) for k, v in gen["workflowsByProfile"].items()},
        "identity": {"image": ident["image"], "crop": ident.get("crop"), "sha256": sha(Path(ident["image"]))},
        "animationReferences": spec["animationReferences"],
        "status": "planned",
    }
    (run_dir / "run.json").write_text(json.dumps(run, indent=1, ensure_ascii=False) + "\n")
    print(f"{len(jobs)} jobs -> {run_dir}/jobs.json ; inputs staged in {lane}")


if __name__ == "__main__":
    main()
