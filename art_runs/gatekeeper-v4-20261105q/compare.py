#!/usr/bin/env python3
"""Measure every final against v3 (build-v3-v4.json), then write the owner's per-clip GIFs and before/after sheet.

Finals sit on one 256x320 canvas registered to the rig, so GIF frames are comparable without aligning them.
Downscaled copies only, to keep the repo small. Usage (from the repo root): compare.py
"""
import json, statistics, sys
from pathlib import Path
from PIL import Image, ImageDraw
sys.path.insert(0, str(Path(__file__).parent))
from measure_build import measure

RUN = Path("art_runs/gatekeeper-v4-20261105q")
OLD = Path("art_runs/gatekeeper-v3-20261105q/final")
SHEETS = RUN / "sheets"
BG = (120, 130, 125, 255)
poses = [j["pose"] for j in json.loads((RUN / "jobs.json").read_text())]
rows, clips = {}, {}
for p in poses:
    _, c3, t3 = measure(OLD / f"{p}.png")
    _, c4, t4 = measure(RUN / "final" / f"{p}.png")
    rows[p] = {"v3": [round(float(c3), 3), round(float(t3), 3)], "v4": [round(float(c4), 3), round(float(t4), 3)]}
    clips.setdefault(p.split(".")[0], []).append(p)
med = lambda i, v: round(statistics.median(r[v][i] for r in rows.values()), 3)
summary = {"medianCentralOverHeight": {"v3": med(0, "v3"), "v4": med(0, "v4")},
           "medianTorsoOverHeight": {"v3": med(1, "v3"), "v4": med(1, "v4")},
           "posesWiderThanV3": int(sum(r["v4"][0] > r["v3"][0] for r in rows.values())),
           "narrowestV4": min(rows, key=lambda p: rows[p]["v4"][0]),
           "note": "central: connected run through the chest-to-belly band; torso: shirt colour only, less reliable after the palette finish."}
(RUN / "build-v3-v4.json").write_text(json.dumps({"summary": summary, "poses": rows}, indent=1) + "\n")
print(json.dumps(summary, indent=1))

def flat(path, size=None):
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, BG); bg.alpha_composite(im)
    bg = bg.convert("RGB")
    return bg.resize(size, Image.LANCZOS) if size else bg

W, H = 160, 200
for clip, ps in clips.items():
    fr = []
    for p in ps:
        c = Image.new("RGB", (2 * W + 4, H), (30, 30, 34))
        c.paste(flat(OLD / f"{p}.png", (W, H)), (0, 0)); c.paste(flat(RUN / "final" / f"{p}.png", (W, H)), (W + 4, 0))
        d = ImageDraw.Draw(c); d.text((3, 2), "v3", fill=(255, 255, 0)); d.text((W + 7, 2), "v4", fill=(255, 255, 0))
        fr.append(c.convert("P", palette=Image.ADAPTIVE, colors=64))
    fr[0].save(SHEETS / f"{clip}.gif", save_all=True, append_images=fr[1:], duration=220, loop=0, optimize=True)

key = ["groove.down_l", "left_hand.peak", "left_foot.peak", "enter_forward.down_l", "watch.hold_l", "clap.contact", "challenge.proud", "finish_turn.finish_b"]
cw, ch = 200, 250
src = Image.open("assets/art/garden/gatekeeper.png").convert("RGB")
src = src.resize((int(src.width * (2 * ch + 4) / src.height), 2 * ch + 4), Image.LANCZOS)
sheet = Image.new("RGB", (src.width + 8 + len(key) * (cw + 4), 2 * ch + 4), (30, 30, 34))
sheet.paste(src, (0, 0))
d = ImageDraw.Draw(sheet); d.text((4, 2), "source art", fill=(255, 255, 0))
for i, p in enumerate(key):
    x = src.width + 8 + i * (cw + 4)
    for y, root, tag in ((0, OLD, "v3"), (ch + 4, RUN / "final", "v4")):
        sheet.paste(flat(root / f"{p}.png").crop((16, 40, 240, 320)).resize((cw, ch), Image.LANCZOS), (x, y))
        d.text((x + 3, y + 2), f"{tag} {p}  {rows[p][tag][0]:.2f}", fill=(255, 255, 0))
sheet.save(SHEETS / "before-after-v3-v4.png", optimize=True)
