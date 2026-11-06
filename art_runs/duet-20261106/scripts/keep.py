#!/usr/bin/env python3
"""Copy a studio job's outputs into the art cache at once, since the lane folder dies with the forge, and draw a review sheet: each candidate large and at game size (height 190 px, as a dancer stands near the front).
Usage: keep.py <pose> <job id> [<job id> ...] ; sheet at raw/<pose>/sheet.png."""
import json, pathlib, shutil, sys
from PIL import Image, ImageDraw
RAW = pathlib.Path.home() / ".cache/tillandsias-project/kumbia-art/duet-20261106/raw"
pose = sys.argv[1]; out = RAW / pose; out.mkdir(parents=True, exist_ok=True)
for job in sys.argv[2:]:
    src = pathlib.Path("/work/tmp/imagegen/studio") / job
    for png in sorted(src.glob("*.png")):
        seed = json.load(open(f"{png}.provenance.json")).get("seed", png.stem)
        shutil.copy(png, out / f"{seed}.png"); shutil.copy(f"{png}.provenance.json", out / f"{seed}.provenance.json")
names = sorted(out.glob("[0-9]*.png"))
W, H, G = 420, 520, 190
S = Image.new("RGB", (len(names) * (W + G // 2 + 12), H + 16), (58, 96, 62)); d = ImageDraw.Draw(S)
for i, p in enumerate(names):
    im = Image.open(p).convert("RGBA"); b = im.getbbox(); crop = im.crop(b); x = i * (W + G // 2 + 12)
    k = min(W / crop.width, H / crop.height); big = crop.resize((round(crop.width * k), round(crop.height * k)), Image.LANCZOS); S.paste(big, (x, 16), big)
    k = G / crop.height; small = crop.resize((max(1, round(crop.width * k)), G), Image.LANCZOS); S.paste(small, (x + W, H + 16 - G), small); d.text((x + 2, 2), p.stem, fill="white")
S.save(out / "sheet.png"); print(out / "sheet.png", S.size)
