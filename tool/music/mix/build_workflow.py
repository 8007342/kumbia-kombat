#!/usr/bin/env python3
"""Writes a one-performance workflow: a parent take, then tiers re-sampled from its latent.

  python3 -I tool/music/mix/build_workflow.py SPEC.json OUT.api.json

SPEC: {"parent": {seed, tags, bpm, key, seconds, lyrics?}, "children": [{name, tags, denoise, seed?, parent?, codes?}]}
A child's latent starts from its `parent` child, or from the parent take. Everything is
written into the graph, so the workflow file alone is the record of the take.
"""
import copy
import json
import pathlib
import sys

BASE = pathlib.Path(__file__).resolve().parents[1] / "workflows" / "ace-xl-turbo.api.json"


def encoder(base, tags, seed, bpm, key, seconds, lyrics):
    node = copy.deepcopy(base["94"])
    node.pop("_meta", None)
    node["inputs"].update(tags=tags, seed=seed, bpm=bpm, keyscale=key, duration=seconds, lyrics=lyrics)
    return node


def build(spec):
    base = json.loads(BASE.read_text())
    p = spec["parent"]
    graph = {k: copy.deepcopy(base[k]) for k in ("104", "105", "106", "78")}
    if spec.get("unet"):
        graph["104"]["inputs"]["unet_name"] = spec["unet"]
    lyrics = p.get("lyrics", "[Instrumental]")
    graph["94"] = encoder(base, p["tags"], p["seed"], p["bpm"], p["key"], p["seconds"], lyrics)
    graph["47"] = copy.deepcopy(base["47"])
    graph["98"] = copy.deepcopy(base["98"])
    graph["98"]["inputs"]["seconds"] = p["seconds"]
    graph["3"] = copy.deepcopy(base["3"])
    graph["3"].pop("_meta", None)
    graph["3"]["inputs"]["seed"] = p["seed"]
    for key in ("steps", "cfg"):
        if key in p:
            graph["3"]["inputs"][key] = p[key]
    graph["18"] = copy.deepcopy(base["18"])
    graph["111"] = copy.deepcopy(base["111"])
    graph["111"]["inputs"]["filename_prefix"] = "audio/kumbia_parent"
    ids = {None: "3"}
    for i, child in enumerate(spec.get("children", [])):
        at = 1000 + 10 * i
        seed = child.get("seed", p["seed"])
        graph[str(at)] = encoder(base, child["tags"], seed, p["bpm"], p["key"], p["seconds"], child.get("lyrics", lyrics))
        if "codes" in child:
            graph[str(at)]["inputs"]["generate_audio_codes"] = child["codes"]
        graph[str(at + 1)] = {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": [str(at), 0]}}
        graph[str(at + 2)] = {"class_type": "KSampler", "_meta": {"title": child["name"]}, "inputs": {
            "model": ["78", 0], "positive": [str(at), 0], "negative": [str(at + 1), 0],
            "latent_image": [ids[child.get("parent")], 0], "seed": seed, "steps": child.get("steps", 8),
            "cfg": 1, "sampler_name": "euler", "scheduler": "simple", "denoise": child["denoise"]}}
        graph[str(at + 3)] = {"class_type": "VAEDecodeAudio", "inputs": {"samples": [str(at + 2), 0], "vae": ["106", 0]}}
        graph[str(at + 4)] = {"class_type": "SaveAudio", "_meta": {"title": child["name"]}, "inputs": {
            "audio": [str(at + 3), 0], "filename_prefix": "audio/kumbia_" + child["name"]}}
        ids[child["name"]] = str(at + 2)
    return graph


if __name__ == "__main__":
    pathlib.Path(sys.argv[2]).write_text(json.dumps(build(json.loads(pathlib.Path(sys.argv[1]).read_text())), indent=1) + "\n")
