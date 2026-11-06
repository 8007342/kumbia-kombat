#!/usr/bin/env python3
"""The finished skirt frames from the packed atlases, as the loop plays them, at 2x and at about game size (190 px), on the lawn's dark path colour. Writes sheets/skirt-finals.png. Run from the worktree root."""
import json, pathlib
from PIL import Image, ImageDraw
ENS = pathlib.Path("assets/art/ensemble"); m = json.load(open(ENS / "manifest.json"))["atlases"]; OUT = pathlib.Path("art_runs/duet-20261106/sheets"); OUT.mkdir(exist_ok=True)
LOOP = ["skirt_sway_r", "skirt_pass_r", "skirt_sway_l", "skirt_pass_l"]; CW, CH = 330, 540
S = Image.new("RGB", (CW * 4 + 8, 2 * CH + 220 * 2), (16, 24, 48)); d = ImageDraw.Draw(S); y = 0
for dancer in ("swing-a", "swing-b"):
    a = m[dancer]; im = Image.open(ENS / a["image"]).convert("RGBA")
    for i, name in enumerate(LOOP):
        x0, y0, w, h = a["frames"][name]["rect"]; ax = a["frames"][name]["anchor"][0]; f = im.crop((x0, y0, x0 + w, y0 + h))
        big = f.resize((w * 2, h * 2), Image.NEAREST); S.paste(big, (i * CW + round(CW / 2 - ax * 2), y + CH - 10 - big.height), big); d.text((i * CW + 4, y + 2), f"{dancer} {name}", fill="white")
        k = 190 / 248; sm = f.resize((round(w * k), round(h * k)), Image.BILINEAR); S.paste(sm, (i * CW + round(CW / 2 - ax * k), y + CH + 205 - sm.height), sm)
    y += CH + 220
S.save(OUT / "skirt-finals.png", optimize=True); print(S.size)
