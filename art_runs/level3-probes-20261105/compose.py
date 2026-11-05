#!/usr/bin/env python3
"""CPU-only proof on one probe plate: floor calibration from the greybox, front layer and water from its id map."""
import json, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
C = "/home/forge/.cache/tillandsias-project/kumbia-art/level3-probes-20261105/"
OUT = sys.argv[1]
calib = json.load(open("guide/floor.json")); Hm = np.array(calib["floorHomography_st_to_px"]); W, H = calib["image"]; IDS = calib["ids"]
hz, eye = calib["horizonY"] * H, calib["eyeHeightAdults"]
plate = Image.open(C + "c3-970221.png").convert("RGB").resize((W, H), Image.LANCZOS)
ids = np.asarray(Image.open("guide/greybox-ids-1024.png"))

def st(s, t):
    q = Hm @ np.array([s, t, 1.0]); return q[:2] / q[2]

def adult(y): return (y - hz) / eye

def alpha_bbox(im):
    return im.getchannel("A").point(lambda v: 255 if v > 128 else 0).getbbox()

def place(base, path, foot, height, flip=False, crop=None):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im.getchannel("A")).copy(); a[a < 128] = 0; a[a >= 128] = 255  # binary alpha, as the finisher does
    im.putalpha(Image.fromarray(a)); im = im.crop(crop or alpha_bbox(im))
    if flip: im = im.transpose(Image.FLIP_LEFT_RIGHT)
    k = height / im.height; im = im.resize((max(1, int(im.width * k)), int(height)), Image.LANCZOS)
    base.alpha_composite(im, (int(foot[0] - im.width / 2), int(foot[1] - im.height)))
    return (foot[0], foot[1], height)

# 1. water: id map says where, colour keeps only pixels the model really painted as water
rgb = np.asarray(plate).astype(float)
waterid = ids == IDS["water"]
R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
cyan = (B > R + 40) & (G > R + 30) & (B > 90)
print("water: id pixels", waterid.sum(), "of which painted cyan", (waterid & cyan).sum(), "cyan outside id, within 40px", (cyan & ~waterid).sum())
m = Image.fromarray((waterid * 255).astype("uint8")).filter(ImageFilter.MaxFilter(21)); mask = (np.asarray(m) > 0) & cyan
print("water mask pixels", mask.sum())
def water(frame):
    a = np.asarray(plate).copy().astype(float)
    Y, X = np.where(mask)
    # four frames: horizontal bands of light ripple sideways, palette-cycling style, in 4px cells
    phase = frame * np.pi / 2
    cx, cy = X // 4, Y // 4
    b = np.sin(cx * .9 + cy * 2.3 + phase) + .6 * np.sin(cx * .35 - cy * 1.1 - phase)
    a[Y, X] = np.clip(a[Y, X] * (1 + .16 * np.sign(b) * (np.abs(b) > .55))[:, None], 0, 255)
    return Image.fromarray(a.astype("uint8")).convert("RGBA")

# 2. front layer: pool-house columns come back over anything placed inside
front = Image.fromarray((((ids == IDS["wall"]) * 255)).astype("uint8"))
def scene(frame, cast=True):
    b = water(frame)
    if cast:
        q = [(st(*p)) for p in [(13.5, -7.0), (13.0, -11.0), (12.5, -8.6)]]
        for f, x in zip(q, ["swimmer", "swimmer", "swimmer"]):
            h = adult(f[1]) * .42
            place(b, C + "swimmer-970175.png", (f[0], f[1] + 3), h, crop=(180, 130, 590, 460))
        b.paste(plate.convert("RGBA"), (0, 0), front)   # columns over swimmers
        for s, t, p, fl in [(3.0, -4.6, "guest-970176.png", False), (2.3, -6.6, "guest-970176.png", True), (6.1, -3.6, "guest-970176.png", False), (5.1, -7.4, "guest-970176.png", True)]:
            f = st(s, t); place(b, C + p, f, adult(f[1]))
        # the dance: two women across the path, Macron coming up it at 0.35 adult
        fa = st(1.25, -.42); fb = st(1.25, .55); fm = st(.55, -.25)
        place(b, C + "dancer-dance-970173.png", fa, adult(fa[1]))
        place(b, C + "dancer-b-970161.png", fb, adult(fb[1]) * .94)
        place(b, C + "mac-rear3q-970131.png", fm, adult(fm[1]) * .35)
        print("marks: dancer foot px", np.round(fa), "adult px", round(adult(fa[1])), "macron foot", np.round(fm), "height px", round(adult(fm[1]) * .35))
    return b.convert("RGB")

s = scene(0)
d = ImageDraw.Draw(s); vis = .693; x0 = W * (1 - vis) / 2
review = s.copy(); dv = ImageDraw.Draw(review); dv.rectangle([x0, 0, W - x0, H - 1], outline=(255, 0, 255), width=3)
review.save(OUT + "/proof-scene.png")
# phone-size views: 390x844 cover crop
vw = int(H * 390 / 844); xx = (W - vw) // 2
s.crop((xx, 0, xx + vw, H)).resize((390, 844), Image.LANCZOS).save(OUT + "/proof-phone-390x844.png")
# water frames, crop of the pool
strip = Image.new("RGB", (4 * 420 + 18, 200), (0, 0, 0))
for i in range(4):
    strip.paste(scene(i, cast=False).crop((40, 300, 660, 520)).resize((420, 149)).resize((420, 200), Image.NEAREST), (i * 426, 0))
strip.save(OUT + "/proof-water-frames.png")
gif = [scene(i, cast=False).crop((40, 300, 660, 520)) for i in range(4)]
gif[0].save(OUT + "/proof-water.gif", save_all=True, append_images=gif[1:], duration=220, loop=0)
