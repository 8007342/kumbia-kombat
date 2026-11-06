#!/usr/bin/env python3
"""Review sheets and GIFs from the packed candidates: each frame drawn at its anchor on one ground line, with live frames beside them. Run from the repo root."""
import json, pathlib
from PIL import Image, ImageDraw
OUT = pathlib.Path("art_runs/spin-20261106a"); C = OUT / "candidate"; SH = OUT / "sheets"; BG = (120, 124, 132, 255)
ens = json.load(open("assets/art/ensemble/manifest.json"))["atlases"]; hero = json.load(open("assets/art/party/manifest.json"))["atlases"]["hero"]
def frame(atlas, f): x, y, w, h = f["rect"]; return atlas.crop((x, y, x + w, y + h))
def strip(items, out, cell, ground, zoom=1):
    W, H = cell; sh = Image.new("RGBA", (W * len(items), H), BG); d = ImageDraw.Draw(sh)
    for i, (label, im, f, ppu0) in enumerate(items):
        k = ppu0 / f["pixelsPerUnit"]
        sh.alpha_composite(im, (i * W + W // 2 - round(f["anchor"][0]), ground - round(f["anchor"][1])))
        d.text((i * W + 3, 2), label, fill=(255, 255, 0))
    d.line([(0, ground), (W * len(items), ground)], fill=(255, 90, 90, 255))
    sh = sh.convert("RGB")
    if zoom != 1: sh = sh.resize((sh.width * zoom, sh.height * zoom), Image.NEAREST)
    sh.save(out)
def gif(frames, out, ms, cell, ground):
    W, H = cell; fr = []
    for im, f in frames:
        bg = Image.new("RGBA", (W, H), BG); bg.alpha_composite(im, (W // 2 - round(f["anchor"][0]), ground - round(f["anchor"][1])))
        fr.append(bg.convert("P", palette=Image.ADAPTIVE, colors=64))
    fr[0].save(out, save_all=True, append_images=fr[1:], duration=ms, loop=0)
for char, live_ids in (("gatekeeper", ["occupied", "challenge_proud", "finish_turn_finish_a"]), ("bartender", ["occupied", "challenge_proud", "finish_turn_finish_a"])):
    cd = json.load(open(C / f"{char}-spin-candidate.candidate.json")); at = Image.open(C / cd["image"]).convert("RGBA"); fr = cd["frames"]
    la = Image.open("assets/art/ensemble/" + ens[char]["image"]).convert("RGBA")
    ppu = fr["spin_front"]["pixelsPerUnit"]; items = [(f"LIVE {k}", frame(la, ens[char]["frames"][k]), ens[char]["frames"][k], ppu) for k in live_ids[:2]]
    order = cd["clips"]["spin"]["order"] + cd["clips"]["flare"]
    items += [((k + (" (mirror)" if "mirrorOf" in fr[k] else "")), frame(at, fr[k]), fr[k], ppu) for k in order]
    strip(items, SH / f"{char}-finals.png", (190, 310), 290)
    for ms, label in ((125, "spin-8"), ):
        gif([(frame(at, fr[k]), fr[k]) for k in cd["clips"]["spin"]["order"]], SH / f"{char}-{label}.gif", ms, (240, 310), 290)
cd = json.load(open(C / "hero-rear-clap-candidate.candidate.json")); at = Image.open(C / cd["image"]).convert("RGBA"); fr = cd["frames"]
la = Image.open("assets/art/party/" + hero["image"]).convert("RGBA"); ri = hero["frames"]["rear_idle"]
items = [("LIVE rear_idle", frame(la, ri), ri, 8.0)] + [(k, frame(at, fr[k]), fr[k], 8.0) for k in fr]
strip(items, SH / "macron-finals.png", (340, 390), 370)
beat = 577  # 104 BPM
gif([(frame(at, fr[k]), fr[k]) for k in ("clap_apart", "clap_together")], SH / "macron-clap-2.gif", beat // 2, (340, 390), 370)
gif([(frame(at, fr[k]), fr[k]) for k in ("clap_apart", "clap_together", "clap_release")], SH / "macron-clap-3.gif", beat // 3, (340, 390), 370)
ov = Image.new("RGBA", (340, 390), BG)
for k, im, f in (("idle", frame(la, ri), ri), ("together", frame(at, fr["clap_together"]), fr["clap_together"])):
    t = im.copy(); t.putalpha(t.getchannel("A").point(lambda v: v // 2)); ov.alpha_composite(t, (170 - round(f["anchor"][0]), 370 - round(f["anchor"][1])))
ov.convert("RGB").save(SH / "macron-overlay-idle-together.png")
