#!/usr/bin/env python3
"""Stills and a GIF of the shot, by a port of ExitShot.sample and _drawCloseup: cover-fit plate, 55% darkening, nearest actors, motes.
Review only. Not the game's renderer, no sound. Tempo 100 until beat 8, then 128 (the bridge takes the lawn's base tempo).
usage: preview.py [shot.json] [outdir]"""
import json, math, sys, os
from PIL import Image, ImageDraw
shot = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "art_runs/oil-gulp-20261106/exit-shot.suggested.json"))
OUT = sys.argv[2] if len(sys.argv) > 2 else "art_runs/oil-gulp-20261106/sheets/"
W, H, K = 390, 844, 3  # logical phone, device scale
hold_img = shot.get("impactBeats", .4)
cache = {}
def img(p):
    if p not in cache: cache[p] = Image.open("assets/art/" + p).convert("RGBA")
    return cache[p]
def sample(beat, reduced=False):
    fr, ct, to = shot["closeupFrom"], shot["contactBeat"], shot["closeupTo"]
    after = beat - ct
    ap = 1.0 if reduced else min(1, max(0, (beat - fr) / (ct - fr)))
    closing = 1 - ap * ap; hold = .25
    if after <= hold or reduced: rec = 0.0
    else:
        t = min(1, max(0, (after - hold) / (to - ct - hold))); rec = 1 - (1 - t) ** 2
    striking = 0 <= after < hold_img
    return [(a, a["impact"] if striking or reduced else a["approach"], (a["entry"][0] * closing + a["recoil"][0] * rec, a["entry"][1] * closing + a["recoil"][1] * rec)) for a in shot["actors"]]
def plate():
    p = img(shot["plate"]); c = max(W * K / p.width, H * K / p.height); v = p.resize((round(p.width * c), round(p.height * c)), Image.NEAREST)
    x, y = (v.width - W * K) // 2, (v.height - H * K) // 2; v = v.crop((x, y, x + W * K, y + H * K)).convert("RGBA")
    v.alpha_composite(Image.new("RGBA", v.size, (5, 10, 16, 0x8C))); return v
BASE = None
def frame(beat, reduced=False):
    global BASE
    if BASE is None: BASE = plate()
    f = BASE.copy(); meet = (W * shot["contactPoint"][0], H * shot["contactPoint"][1])
    for a, name, off in sample(beat, reduced):
        art = img(name); s = a["scale"]; ox, oy = meet[0] + off[0] - a["contact"][0] * s, meet[1] + off[1] - a["contact"][1] * s
        if ox > W or oy > H or ox + art.width * s < 0 or oy + art.height * s < 0: continue
        v = art.resize((round(art.width * s * K), round(art.height * s * K)), Image.NEAREST)
        f.alpha_composite(v, (max(0, round(ox * K)), max(0, round(oy * K))), (max(0, -round(ox * K)), max(0, -round(oy * K))))
    age = beat - shot["contactBeat"]
    if 0 <= age < .5 and not reduced:
        d = ImageDraw.Draw(f); t = age / .5
        for i, h in enumerate((-2.5, -1.2, .9, 2.2)):
            r = 10 + 26 * (1 - (1 - t) ** 2); x, y = meet[0] + math.cos(h) * r, meet[1] + math.sin(h) * r; z = (3 if i % 2 == 0 else 2) * K / 2
            c = round(255 * (1 - t)); d.rectangle([x * K - z, y * K - z, x * K + z, y * K + z], fill=(244, 227, 178, 255))
    return f
if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    beats = [6.4, 7.2, 7.9, 8.0, 8.2, 8.34, 8.5, 9.5, 10.9]
    th = 234
    sheet = Image.new("RGB", (th * len(beats) + 1 * th, 506), (0, 0, 0))
    labels = [str(b) for b in beats] + ["reduced motion"]
    for i, (b, l) in enumerate(zip(beats + [8.5], labels)):
        fr = frame(b, reduced=l == "reduced motion").convert("RGB"); d = ImageDraw.Draw(fr); d.line([(0, 549 * 3), (W * K, 549 * 3)], fill=(90, 90, 90), width=3)
        sheet.paste(fr.resize((th, 506), Image.NEAREST), (i * th, 0)); ImageDraw.Draw(sheet).text((i * th + 4, 4), l, fill=(255, 255, 0))
    sheet.save(OUT + "beats.png")
    for b, n in [(7.6, "offer"), (8.0, "contact"), (9.5, "gulp")]:
        frame(b).crop((0, 0, W * K, 660 * 3)).convert("RGB").save(OUT + f"phone-{n}.png", optimize=True)
    ms = 40; t = 0.0; frames = []
    beat = shot["closeupFrom"]
    while beat < shot["closeupTo"]:
        frames.append(frame(beat).crop((0, 0, W * K, 660 * K)).resize((W, 660), Image.NEAREST).convert("RGB").quantize(128, dither=Image.Dither.NONE))
        beat += ms / 1000 * (100 if beat < 8 else 128) / 60
    frames[0].save(OUT + "oil-gulp.gif", save_all=True, append_images=frames[1:], duration=ms, loop=0, optimize=True); print(len(frames), "frames")
