#!/usr/bin/env python3
"""A close-up as the game draws it: plate cover-fit and dimmed, actors placed by the level's exitShot, at the frame a phone sees.
No title glyphs, just a line where GardenPage's title band starts. usage: stills.py level-id out.png beat [beat...] [--mirror] [--calm]. Run from the worktree root."""
import json, sys
from PIL import Image, ImageDraw
ZOOM = 2  # preview px per unit
W, H = 180, 390  # the view of a 390x844 phone

def ease(x): return 1 - (1 - x) ** 3

def sample(shot, a, beat, calm=False):
    after = beat - shot["contactBeat"]; ap = 1 if calm else max(0, min(1, (beat - shot["closeupFrom"]) / (shot["contactBeat"] - shot["closeupFrom"])))
    closing = 1 - ap * ap; hold = .25
    rec = 0 if (after <= hold or calm) else ease(max(0, min(1, (after - hold) / (shot["closeupTo"] - shot["contactBeat"] - hold))))
    if calm: img = a["impact"]
    elif a.get("frames"):
        img = a["approach"]
        for f in a["frames"]:
            if beat >= f["beat"]: img = f["image"]
    else: img = a["impact"] if 0 <= after < shot.get("impactBeats", .4) else a["approach"]
    return img, (a["entry"][0] * closing + a["recoil"][0] * rec, a["entry"][1] * closing + a["recoil"][1] * rec)

def paste(layer, im, x, y):
    if x <= -im.width or y <= -im.height: return
    box = (max(0, -x), max(0, -y)); layer.alpha_composite(im.crop((box[0], box[1], im.width, im.height)), (max(0, x), max(0, y)))

def still(level, beat, art="assets/art", zoom=ZOOM, calm=False, mirror=False):
    shot = json.load(open(f"levels/{level}.json"))["exitShot"]; c = Image.new("RGBA", (W * zoom, H * zoom), (0, 0, 0, 255))
    plate = Image.open(f"{art}/{shot['plate']}").convert("RGBA"); cover = max(W * zoom / plate.width, H * zoom / plate.height)
    p = plate.resize((round(plate.width * cover), round(plate.height * cover)), Image.NEAREST); c.alpha_composite(p.crop(((p.width - c.width) // 2, (p.height - c.height) // 2, (p.width + c.width) // 2, (p.height + c.height) // 2)).resize(c.size))
    c.alpha_composite(Image.new("RGBA", c.size, (5, 10, 16, 0x8C))); layer = Image.new("RGBA", c.size, (0, 0, 0, 0))
    mx, my = W * shot["contactPoint"][0], H * shot["contactPoint"][1]
    for a in shot["actors"]:
        img, off = sample(shot, a, beat, calm); im = Image.open(f"{art}/{img}").convert("RGBA"); s = a["scale"]
        x = mx + off[0] - a["contact"][0] * s; y = my + off[1] - a["contact"][1] * s
        im = im.resize((max(1, round(im.width * s * zoom)), max(1, round(im.height * s * zoom))), Image.NEAREST)
        paste(layer, im, round(x * zoom), round(y * zoom))
    if mirror: layer = layer.transpose(Image.FLIP_LEFT_RIGHT)
    c.alpha_composite(layer); return c

def band(c, zoom=ZOOM):
    d = ImageDraw.Draw(c); y = .58 * H * zoom; d.line([0, y, c.width, y], fill=(255, 255, 255, 160)); return c

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]; mirror = "--mirror" in sys.argv; calm = "--calm" in sys.argv
    level, out, beats = args[0], args[1], [float(b) for b in args[2:]]; g = 8
    sheet = Image.new("RGBA", ((W * ZOOM + g) * len(beats) + g, H * ZOOM + 2 * g + 14), (28, 28, 34, 255)); d = ImageDraw.Draw(sheet)
    for i, b in enumerate(beats):
        sheet.alpha_composite(band(still(level, b, mirror=mirror, calm=calm)), (g + i * (W * ZOOM + g), g + 14)); d.text((g + i * (W * ZOOM + g), 4), f"beat {b}", fill=(230, 230, 230, 255))
    sheet.save(out)
