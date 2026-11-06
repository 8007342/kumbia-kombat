#!/usr/bin/env python3
"""Sprite frames from the atlas, enlarged on a flat ground, as Qwen references. usage: refs.py outdir frame [frame...]. Run from the worktree root."""
import json, sys
from PIL import Image
OUT = sys.argv[1].rstrip("/") + "/"; S = 1664; GROUND = (214, 214, 220, 255)
hero = json.load(open("assets/art/party/manifest.json"))["atlases"]["hero"]; atlas = Image.open("assets/art/party/" + hero["image"]).convert("RGBA")
for name in sys.argv[2:]:
    x, y, w, h = hero["frames"][name]["rect"]; im = atlas.crop((x, y, x + w, y + h)); k = (S * .86) / max(w, h)
    big = im.resize((round(w * k), round(h * k)), Image.LANCZOS); bg = Image.new("RGBA", (S, S), GROUND); bg.alpha_composite(big, ((S - big.width) // 2, (S - big.height) // 2))
    bg.convert("RGB").save(OUT + name + ".png"); print(name, im.size)
