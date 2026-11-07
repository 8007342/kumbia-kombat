#!/usr/bin/env python3
"""A still of the close-up as the scene places it, on a 390x844 phone, for layout: same contact, scale, entry and recoil arithmetic as ExitShot.sample, and the same dim over the plate. A still is not a moving review.
Usage: preview.py out.png beat [beat ...], from the worktree root, reading levels/pool-garden.json."""
import json, sys
from PIL import Image, ImageDraw
level = json.load(open("levels/pool-garden.json")); shot = level["exitShot"]; P = 390 / 180; H = 844 / P
A = "assets/art/"
def ease(t): return 1 - (1 - t) ** 2
def clamp(t): return max(0.0, min(1.0, t))
def frame(beat):
    S = Image.new("RGBA", (390, 844), (10, 16, 32, 255))
    pl = Image.open(A + shot["plate"]).convert("RGBA"); k = max(390 / pl.width, 844 / pl.height); pl = pl.resize((round(pl.width * k), round(pl.height * k)), Image.NEAREST)
    S.alpha_composite(pl, ((390 - pl.width) // 2, (844 - pl.height) // 2)); S.alpha_composite(Image.new("RGBA", S.size, (5, 10, 16, 0x8C)))
    mx, my = 180 * shot["contactPoint"][0], H * shot["contactPoint"][1]
    ap = clamp((beat - shot["closeupFrom"]) / (shot["contactBeat"] - shot["closeupFrom"])); closing = 1 - ap * ap; after = beat - shot["contactBeat"]
    rec = 0 if after <= .25 else ease(clamp((after - .25) / (shot["closeupTo"] - shot["contactBeat"] - .25)))
    for a in shot["actors"]:
        name = a["approach"]
        for f in a.get("frames", []):
            if f["beat"] <= beat: name = f["image"]
        art = Image.open(A + name).convert("RGBA"); s = a["scale"]; w, h = art.size; art = art.resize((max(1, round(w * s * P)), max(1, round(h * s * P))), Image.NEAREST)
        ox = mx + a["entry"][0] * closing + a["recoil"][0] * rec - a["contact"][0] * s; oy = my + a["entry"][1] * closing + a["recoil"][1] * rec - a["contact"][1] * s
        layer = Image.new("RGBA", S.size); layer.paste(art, (round(ox * P), round(oy * P))); S.alpha_composite(layer)
    b = ImageDraw.Draw(S); b.rectangle([0, 549, 389, 549], fill=(255, 255, 255, 60))  # the tap band's top
    return S
beats = [float(b) for b in sys.argv[2:]]
out = Image.new("RGB", (len(beats) * 400, 860), (30, 30, 30)); d = ImageDraw.Draw(out)
for i, b in enumerate(beats): out.paste(frame(b).convert("RGB"), (i * 400 + 5, 14)); d.text((i * 400 + 8, 1), f"beat {b}", fill="white")
out.save(sys.argv[1]); print(out.size)
