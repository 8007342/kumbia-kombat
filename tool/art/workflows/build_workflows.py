#!/usr/bin/env python3
"""Generate the committed ComfyUI API-format workflows for character frames.

One template, one variant per control profile. ComfyUI studio overrides only
reach nodes titled $seed, $prompt and $negative_prompt, so control strengths
and denoise are baked per profile here; the job planner picks the profile per
pose (tool/art/pipeline/plan_jobs.py).

Graph (SDXL-Lightning, 4 steps, cfg 1):
  checkpoint -> LoRA pixel-art-xl -> IP-Adapter (identity reference)
  prompt/negative -> ControlNet openpose -> union(depth) -> union(lineart)
  init: colour-proxy render ($init_image) -> VAEEncode -> KSampler(denoise)
  decode -> SaveImage (rgb); matte keyed locally (tool/art/pipeline/matte.py)

Control starting values come from the animation research
(plan/research/gatekeeper-dance-2026-11-02.md §control stack); the summed
strength stays at about 2.0 so controls do not fight the identity adapter.
Lightning quantises start/end windows to quarters.

Two sets are written. character-frame-*.api.json are the legacy Lightning graphs
that run gatekeeper-v3-20261103a used; they stay byte-identical so that baseline
remains reproducible. <backend>/<profile>.api.json (and <backend>/masked.api.json)
come from tool/art/backends/*.json and are what compile_family.py prefers.

Usage: python3 tool/art/workflows/build_workflows.py   (writes *.api.json beside this file)
"""
from __future__ import annotations

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent

PROFILES = {
    # name: openpose (str, end), depth (str, end), lineart (str, end), denoise
    "moderate": {"pose": (0.90, 0.75), "depth": (0.40, 0.50), "lineart": (0.30, 0.50), "denoise": 0.85,
                 "use": "groove, walks, watch, settle"},
    "peak":     {"pose": (1.00, 1.00), "depth": (0.60, 0.50), "lineart": (0.40, 0.75), "denoise": 0.85,
                 "use": "exaggerated accents: hand/foot peaks, finish, offer"},
    "overlap":  {"pose": (0.80, 0.75), "depth": (0.70, 0.75), "lineart": (0.50, 0.75), "denoise": 0.85,
                 "use": "clap, hands on hip, hand to chest, behind back"},
    "turn":     {"pose": (0.45, 0.50), "depth": (0.70, 0.75), "lineart": (0.60, 0.75), "denoise": 0.85,
                 "use": "turns, rear and near-profile views"},
}


MASKED_DENOISE = 0.75  # baked: one KSampler can't carry both the $seed and $strength titles
BACKENDS = HERE.parent / "backends"


def effective_denoise(steps: int, denoise: float) -> float:
    """What ComfyUI's KSampler really does: it schedules int(steps/denoise) steps and
    runs the last `steps`, so 4 steps at 0.85 is 4 of 4, a full repaint."""
    return steps / int(steps / denoise)


def check_partial_denoise(backend_id: str, steps: int, denoise: float) -> None:
    if denoise < 1.0 and int(steps / denoise) <= steps:
        raise SystemExit(f"backend {backend_id}: {steps} steps at denoise {denoise} truncates to a "
                         f"full repaint (int({steps}/{denoise}) = {int(steps / denoise)}); raise steps")


def backend_models(backend: dict, m: dict) -> dict:
    """models.json with the backend's checkpoint, LoRAs and sampler laid over it."""
    s = backend["sampler"]
    return {**m, "checkpoint": backend["checkpoint"], "loras": backend.get("loras", []),
            "sampler": {"steps": s["steps"], "cfg": s["cfg"], "sampler_name": s["name"], "scheduler": s["scheduler"]}}


def backend_workflows(backend: dict, m: dict) -> dict[str, dict]:
    """{file stem: workflow} for one backend across every control profile, plus masked."""
    bm = backend_models(backend, m)
    steps, denoise = backend["sampler"]["steps"], backend["denoise"]
    check_partial_denoise(backend["id"], steps, denoise)
    check_partial_denoise(backend["id"], steps, MASKED_DENOISE)
    out = {name: build({**prof, "denoise": denoise}, bm) for name, prof in PROFILES.items()}
    out["masked"] = build({**PROFILES["moderate"], "denoise": denoise}, bm, masked=True)
    return out


def build(profile: dict, m: dict, masked: bool = False) -> dict:
    s = m["sampler"]
    g: dict[str, dict] = {}

    def node(nid, cls, inputs, title=None):
        g[str(nid)] = {"class_type": cls, "inputs": inputs}
        if title:
            g[str(nid)]["_meta"] = {"title": title}
        return [str(nid), 0]

    ckpt = node(1, "CheckpointLoaderSimple", {"ckpt_name": m["checkpoint"]})
    model, clip, vae = ["1", 0], ["1", 1], ["1", 2]
    # Legacy graphs: the one pixel LoRA at 0.8. Backend graphs: whatever they declare.
    # Later LoRAs get ids above the graph's fixed range so the first keeps node 2.
    loras = m.get("loras", [{"name": m["lora_pixel"], "weight": 0.8}])
    for i, lora in enumerate(loras):
        nid = 2 if i == 0 else 100 + i
        node(nid, "LoraLoader", {"model": model, "clip": clip, "lora_name": lora["name"],
                                 "strength_model": lora["weight"], "strength_clip": lora["weight"]})
        model, clip = [str(nid), 0], [str(nid), 1]

    # IP-Adapter is optional: models.json "ipadapter": null drops it (and the
    # $identity input) until a file is pinned and licence-admitted; identity
    # then rests on the colour-proxy init image and the prompt.
    if m.get("ipadapter"):
        ref = node(3, "LoadImage", {"image": "$identity"}, "identity reference")
        # Explicit loaders: the pinned CLIP-vision file is not named the way
        # IPAdapterUnifiedLoader's presets expect.
        node(4, "IPAdapterModelLoader", {"ipadapter_file": m["ipadapter"]})
        node(8, "CLIPVisionLoader", {"clip_name": m["clip_vision"]})
        node(5, "IPAdapterAdvanced", {
            "model": model, "ipadapter": ["4", 0], "clip_vision": ["8", 0], "image": ref,
            "weight": 0.7, "weight_type": "style and composition", "combine_embeds": "concat",
            "start_at": 0.0, "end_at": 1.0, "embeds_scaling": "V only"})
        model = ["5", 0]

    pos = node(6, "CLIPTextEncode", {"clip": clip, "text": "$prompt"}, "$prompt")
    neg = node(7, "CLIPTextEncode", {"clip": clip, "text": "$negative_prompt"}, "$negative_prompt")

    cn_pose = node(10, "ControlNetLoader", {"control_net_name": m["controlnet_openpose"]})
    cn_union = node(11, "ControlNetLoader", {"control_net_name": m["controlnet_union"]})
    cn_depth = node(12, "SetUnionControlNetType", {"control_net": cn_union, "type": "depth"})
    cn_line = node(13, "SetUnionControlNetType", {"control_net": cn_union, "type": "canny/lineart/anime_lineart/mlsd"})

    img_pose = node(14, "LoadImage", {"image": "$pose"}, "openpose control")
    img_depth = node(15, "LoadImage", {"image": "$depth"}, "depth control")
    img_line = node(16, "LoadImage", {"image": "$lineart"}, "lineart control")

    p, n = pos, neg
    for nid, cn, img, key in ((20, cn_pose, img_pose, "pose"), (21, cn_depth, img_depth, "depth"),
                              (22, cn_line, img_line, "lineart")):
        st, end = profile[key]
        node(nid, "ControlNetApplyAdvanced", {"positive": p, "negative": n, "control_net": cn, "image": img,
                                              "strength": st, "start_percent": 0.0, "end_percent": end, "vae": vae})
        p, n = [str(nid), 0], [str(nid), 1]

    init = node(30, "LoadImage", {"image": "$init_image"}, "colour proxy init")
    lat = node(31, "VAEEncode", {"pixels": init, "vae": vae})
    if masked:
        # Repaint only inside the rig's changed-region mask (white = repaint).
        msk_img = node(35, "LoadImage", {"image": "$mask"}, "changed region mask")
        msk = node(36, "ImageToMask", {"image": msk_img, "channel": "red"})
        lat = node(37, "SetLatentNoiseMask", {"samples": lat, "mask": msk})
    node(32, "KSampler", {"model": model, "positive": p, "negative": n, "latent_image": lat,
                          "seed": 0, "steps": s["steps"], "cfg": s["cfg"], "sampler_name": s["sampler_name"],
                          "scheduler": s["scheduler"], "denoise": MASKED_DENOISE if masked else profile["denoise"]}, "$seed")
    rgb = node(33, "VAEDecode", {"samples": ["32", 0], "vae": vae})
    node(34, "SaveImage", {"images": rgb, "filename_prefix": "frame"}, "save rgb")
    # Matte: BiRefNet is not installed in the studio yet (2026-11-03: its model
    # list is empty), and run_workflow returns one save node's outputs only, so
    # the matte is keyed from the plain background by tool/art/pipeline/matte.py.
    return g


def main() -> None:
    m = json.loads((HERE / "models.json").read_text())
    for name, prof in PROFILES.items():
        wf = build(prof, m)
        out = HERE / f"character-frame-{name}.api.json"
        out.write_text(json.dumps(wf, indent=1) + "\n")
        print(f"wrote {out.relative_to(HERE.parent.parent.parent)} ({prof['use']})")
    masked = HERE / "character-frame-masked.api.json"
    masked.write_text(json.dumps(build(PROFILES["moderate"], m, masked=True), indent=1) + "\n")
    print(f"wrote {masked.relative_to(HERE.parent.parent.parent)} (masked regeneration)")
    (HERE / "profiles.json").write_text(json.dumps(PROFILES, indent=1) + "\n")
    for path in sorted(BACKENDS.glob("*.json")):
        backend = json.loads(path.read_text())
        if backend.get("role") != "pose-frame":
            continue
        folder = HERE / backend["id"]
        folder.mkdir(exist_ok=True)
        for stem, wf in backend_workflows(backend, m).items():
            (folder / f"{stem}.api.json").write_text(json.dumps(wf, indent=1) + "\n")
        print(f"wrote {folder.relative_to(HERE.parent.parent.parent)}/ ({backend['sampler']['steps']} steps, "
              f"effective denoise {effective_denoise(backend['sampler']['steps'], backend['denoise']):.3f})")


if __name__ == "__main__":
    main()
