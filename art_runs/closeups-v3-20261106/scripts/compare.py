#!/usr/bin/env python3
"""Sheets for judging the redraw: the sprite beside the close-up at phone pixels, the old drawings beside the new, all frames.
usage: compare.py sheetsdir olddir qwen.png. olddir holds the previous oil-gulp-mc2-gulp3.png and duet-macron-arc-blush.png. Run from the worktree root."""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from PIL import Image, ImageDraw
import stills
OUT, OLD, QWEN = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]; BG = (40, 36, 48, 255); TXT = (235, 235, 235, 255)
hero = json.load(open("assets/art/party/manifest.json"))["atlases"]["hero"]; atlas = Image.open("assets/art/party/" + hero["image"]).convert("RGBA")
def sprite(name):
    x, y, w, h = hero["frames"][name]["rect"]; return atlas.crop((x, y, x + w, y + h))

def fit(im, h):
    return im.resize((round(im.width * h / im.height), h), Image.NEAREST)

def row(items, h, path, pad=14):
    """items are (label, image); all shown at the same height, on one line."""
    ims = [(l, fit(i, h)) for l, i in items]; W = sum(i.width for _, i in ims) + pad * (len(ims) + 1)
    S = Image.new("RGBA", (W, h + 34), BG); d = ImageDraw.Draw(S); x = pad
    for l, i in ims:
        S.alpha_composite(i, (x, 26)); d.text((x, 8), l, fill=TXT); x += i.width + pad
    S.save(path)

def crop(im):
    return im.crop(im.getbbox())

cu = "assets/art/closeups/"
gulp = lambda n: crop(Image.open(f"{cu}oil-gulp-mc3-{n}.png").convert("RGBA"))
kiss_parts = lambda body, head: crop(Image.alpha_composite(Image.alpha_composite(Image.open(f"{cu}duet-macron-{body}.png").convert("RGBA"), Image.open(f"{cu}duet-macron-{head}.png").convert("RGBA")), Image.open(f"{cu}duet-macron-logo.png").convert("RGBA")))

# Same height, side by side: is it the same character?
row([("the sprite, front_idle", sprite("front_idle")), ("Qwen from the sprite (not used)", crop(Image.open(QWEN).convert("RGBA"))), ("new kiss body", kiss_parts("body-rest", "round")), ("new gulp, relief", gulp("relief")), ("previous gulp", crop(Image.open(OLD / "oil-gulp-mc2-gulp3.png").convert("RGBA"))), ("previous kiss", crop(Image.open(OLD / "duet-macron-arc-blush.png").convert("RGBA")))], 420, OUT / "vs-sprite-large.png")
# Phone pixels: 3 device px per logical px, 180 units is 390 logical. The sprite as the wide shot shows him, the close-ups as they play.
k = 390 / 180 * 3
row([("sprite groove, wide-shot size", sprite("groove_left")), ("gulp 3", gulp("gulp3")), ("gulp 5", gulp("gulp5")), ("hop", gulp("hop"))], 300, OUT / "vs-sprite-frames.png")
for level, name, beats in (("bar", "gulp-phone", (7, 7.75, 8, 8.5, 9, 9.5, 10, 10.5, 10.75, 11.25)), ("pool-garden", "kiss-phone", (3.8, 4.5, 4.75, 5, 5.75))):
    ims = [stills.band(stills.still(level, b, zoom=2)) for b in beats]; cols = 5; w, h = ims[0].size
    S = Image.new("RGBA", (cols * (w + 8) + 8, ((len(ims) + cols - 1) // cols) * (h + 24) + 8), BG); d = ImageDraw.Draw(S)
    for i, (b, im) in enumerate(zip(beats, ims)):
        x, y = 8 + i % cols * (w + 8), 8 + i // cols * (h + 24); d.text((x, y), f"beat {b}", fill=TXT); S.alpha_composite(im, (x, y + 16))
    S.save(OUT / f"{name}.png")
