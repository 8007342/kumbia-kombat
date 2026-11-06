#!/usr/bin/env python3
"""Every finished pair drawing, native size doubled, with a red dot on its `hold`. Usage: final_sheet.py out.png, from the worktree root."""
import json, sys
from PIL import Image, ImageDraw
M = json.load(open("assets/art/ensemble/manifest.json"))["atlases"]; N = ["pair_rest_a", "pair_rest_b", "pair_arm", "pair_kick", "spin_reach"]
S = Image.new("RGB", (len(N) * 400, 1040), (74, 120, 78)); d = ImageDraw.Draw(S)
for r, who in enumerate(("swing-a", "swing-b")):
    im = Image.open(f"assets/art/ensemble/{M[who]['image']}").convert("RGBA")
    for c, n in enumerate(N):
        f = M[who]["frames"][n]; x, y, w, h = f["rect"]; t = im.crop((x, y, x + w, y + h)).resize((w * 2, h * 2), Image.NEAREST); X, Y = c * 400 + 4, r * 520 + 16
        S.paste(t, (X, Y), t); d.text((X, Y - 14), f"{who} {n}", fill="white"); hx, hy = f["hold"]; d.ellipse([X + hx * 2 - 3, Y + hy * 2 - 3, X + hx * 2 + 3, Y + hy * 2 + 3], fill=(255, 40, 40))
S.save(sys.argv[1]); print(S.size)
