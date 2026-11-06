#!/usr/bin/env python3
"""After packing: all finals per dancer, the pair side by side, and a GIF per clip. Run from the repo root."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw
sys.path.insert(0, "tool/art/rig")
from poses import MOTION_SETS
CLIPS = MOTION_SETS["opponent-64"]
BG = (150, 150, 155, 255)
for c in "ab":
    run = Path(f"art_runs/swing-{c}-20261105a"); final = run / "final"; out = run / "sheets"
    ids = [f"{k}.{d}" for k, v in CLIPS.items() for d in v]
    w, h, cols = 128, 160, 8
    rows = (len(ids) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * w, rows * h), BG); dr = ImageDraw.Draw(sheet)
    for i, p in enumerate(ids):
        im = Image.open(final / f"{p}.png").convert("RGBA").resize((w, h), Image.NEAREST)
        sheet.alpha_composite(im, (i % cols * w, i // cols * h))
        dr.text((i % cols * w + 2, i // cols * h + 1), p.replace("_backward", "").replace("enter_forward", "enter"), fill=(255, 255, 0))
    sheet.convert("RGB").save(out / "finals-all.png")
    for clip, ds in CLIPS.items():
        fr = []
        for d in ds:
            bg = Image.new("RGBA", (256, 320), BG)
            bg.alpha_composite(Image.open(final / f"{clip}.{d}.png").convert("RGBA"))
            fr.append(bg.convert("P", palette=Image.ADAPTIVE, colors=64))
        fr[0].save(out / f"{clip}.gif", save_all=True, append_images=fr[1:], duration=333, loop=0)
pair = ["groove.down_l", "left_hand.peak", "right_foot.peak", "clap.contact", "finish_turn.finish_b"]
sheet = Image.new("RGBA", (len(pair) * 256 * 2, 320), BG)
for i, p in enumerate(pair):
    for j, c in enumerate("ab"):
        sheet.alpha_composite(Image.open(f"art_runs/swing-{c}-20261105a/final/{p}.png").convert("RGBA"), ((i * 2 + j) * 256, 0))
sheet.convert("RGB").save("art_runs/swing-a-20261105a/sheets/pair-finals.png")
