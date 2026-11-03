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
  decode -> SaveImage (rgb) ; BiRefNet -> SaveImage (matte)

Control starting values come from the animation research
(plan/research/gatekeeper-dance-2026-11-02.md §control stack); the summed
strength stays at about 2.0 so controls do not fight the identity adapter.
Lightning quantises start/end windows to quarters.

Usage: python3 tool/art/workflows/build_workflows.py   (writes *.api.json beside this file)
"""
from __future__ import annotations

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent

PROFILES = {
    # name: openpose (str, end), depth (str, end), lineart (str, end), denoise
    "moderate": {"pose": (0.90, 0.75), "depth": (0.40, 0.50), "lineart": (0.30, 0.50), "denoise": 0.70,
                 "use": "groove, walks, watch, settle"},
    "peak":     {"pose": (1.00, 1.00), "depth": (0.60, 0.50), "lineart": (0.40, 0.75), "denoise": 0.60,
                 "use": "exaggerated accents: hand/foot peaks, finish, offer"},
    "overlap":  {"pose": (0.80, 0.75), "depth": (0.70, 0.75), "lineart": (0.50, 0.75), "denoise": 0.60,
                 "use": "clap, hands on hip, hand to chest, behind back"},
    "turn":     {"pose": (0.45, 0.50), "depth": (0.70, 0.75), "lineart": (0.60, 0.75), "denoise": 0.60,
                 "use": "turns, rear and near-profile views"},
}


def build(profile: dict, m: dict) -> dict:
    s = m["sampler"]
    g: dict[str, dict] = {}

    def node(nid, cls, inputs, title=None):
        g[str(nid)] = {"class_type": cls, "inputs": inputs}
        if title:
            g[str(nid)]["_meta"] = {"title": title}
        return [str(nid), 0]

    ckpt = node(1, "CheckpointLoaderSimple", {"ckpt_name": m["checkpoint"]})
    model, clip, vae = ["1", 0], ["1", 1], ["1", 2]
    node(2, "LoraLoader", {"model": model, "clip": clip, "lora_name": m["lora_pixel"],
                           "strength_model": 0.8, "strength_clip": 0.8})
    model, clip = ["2", 0], ["2", 1]

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
    node(32, "KSampler", {"model": model, "positive": p, "negative": n, "latent_image": lat,
                          "seed": 0, "steps": s["steps"], "cfg": s["cfg"], "sampler_name": s["sampler_name"],
                          "scheduler": s["scheduler"], "denoise": profile["denoise"]}, "$seed")
    rgb = node(33, "VAEDecode", {"samples": ["32", 0], "vae": vae})
    node(34, "SaveImage", {"images": rgb, "filename_prefix": "frame"}, "save rgb")

    node(40, "LoadRembgByBiRefNetModel", {"model": m["birefnet_model"], "device": "AUTO"})  # local file: the studio has no egress
    node(41, "RembgByBiRefNet", {"model": ["40", 0], "images": rgb})
    node(42, "SaveImage", {"images": ["41", 0], "filename_prefix": "frame_rgba"}, "save rgba")
    return g


def main() -> None:
    m = json.loads((HERE / "models.json").read_text())
    for name, prof in PROFILES.items():
        wf = build(prof, m)
        out = HERE / f"character-frame-{name}.api.json"
        out.write_text(json.dumps(wf, indent=1) + "\n")
        print(f"wrote {out.relative_to(HERE.parent.parent.parent)} ({prof['use']})")
    (HERE / "profiles.json").write_text(json.dumps(PROFILES, indent=1) + "\n")


if __name__ == "__main__":
    main()
