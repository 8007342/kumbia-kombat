#!/usr/bin/env python3
"""Paint guide images for the close-up plates, from colours sampled out of the levels' plates (median cut). A reference plate
alone made Qwen copy its mansion (2 of 2), so the composition comes from a guide, as rooms do from greyboxes. Output: lane."""
import numpy as np, random
from PIL import Image, ImageDraw, ImageFilter
W, H = 1168, 1648; L = "/work/tmp/imagegen/kumbia/closeups/"
def pal(path, n=24):
    q = Image.open(path).convert("RGB").resize((256, 384), Image.BOX).quantize(n, method=Image.MEDIANCUT)
    p = q.getpalette()[: n * 3]; return sorted([tuple(p[i:i + 3]) for i in range(0, n * 3, 3)], key=sum)
def discs(d_layer, rng, n, ymax, cols):
    d = ImageDraw.Draw(d_layer)
    for _ in range(n):
        r = rng.choice([40, 60, 85, 120]); x = rng.randint(0, W); y = rng.randint(30, ymax); c = rng.choice(cols)
        d.ellipse((x - r, y - r, x + r, y + r), fill=c + (rng.randint(110, 190),))
rng = random.Random(4)
# Garden: sky to foliage gradient, amber discs in the upper half
g = np.zeros((H, W, 3), float)
top, mid, low = np.array((14, 18, 44)), np.array((10, 26, 24)), np.array((6, 10, 10))
for y in range(H):
    t = y / H; g[y] = top * (1 - t * 2) + mid * t * 2 if t < .5 else mid * (2 - t * 2) + low * (t * 2 - 1)
im = Image.fromarray(g.astype("uint8")).convert("RGBA"); l = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(l)
for _ in range(90):
    x, y, r = rng.randint(0, W), rng.randint(int(H * .15), H), rng.randint(40, 170)
    d.ellipse((x - r, y - r, x + r, y + r), fill=rng.choice([(14, 34, 28), (9, 22, 20), (18, 42, 32)]) + (160,))
im.alpha_composite(l.filter(ImageFilter.GaussianBlur(14)))
l = Image.new("RGBA", (W, H), (0, 0, 0, 0)); discs(l, rng, 13, int(H * .55), [(244, 168, 72), (232, 138, 50), (255, 196, 110), (190, 96, 38)])
im.alpha_composite(l.filter(ImageFilter.GaussianBlur(3))); im.convert("RGB").save(L + "guide_garden.png")
# Second try: fewer discs, dimmer, with soft edges, so the lanterns sit behind the fists instead of competing
base = Image.fromarray(g.astype("uint8")).convert("RGBA"); l = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(l); rng2 = random.Random(9)
for _ in range(90):
    x, y, r = rng2.randint(0, W), rng2.randint(int(H * .15), H), rng2.randint(40, 170)
    d.ellipse((x - r, y - r, x + r, y + r), fill=rng2.choice([(14, 34, 28), (9, 22, 20), (18, 42, 32)]) + (160,))
base.alpha_composite(l.filter(ImageFilter.GaussianBlur(14)))
l = Image.new("RGBA", (W, H), (0, 0, 0, 0)); discs(l, rng2, 8, int(H * .45), [(150, 92, 44), (128, 70, 34), (178, 116, 62)])
base.alpha_composite(l.filter(ImageFilter.GaussianBlur(20))); base.convert("RGB").save(L + "guide_garden2.png")
# Bar: dark above, copper counter across the lower part of the visible 65 percent band (plate = top 65 percent of the phone)
g = np.zeros((H, W, 3), float)
for y in range(H):
    g[y] = np.array((22, 13, 12)) * (1 - y / H) + np.array((12, 8, 8)) * (y / H)
im = Image.fromarray(g.astype("uint8")).convert("RGBA"); l = Image.new("RGBA", (W, H), (0, 0, 0, 0)); discs(l, rng, 11, int(H * .5), [(226, 150, 72), (200, 112, 46), (250, 190, 110)])
im.alpha_composite(l.filter(ImageFilter.GaussianBlur(3)))
d = ImageDraw.Draw(im); top = int(H * .62); front = int(H * .9)
for y in range(top, front):
    t = (y - top) / (front - top); d.line((0, y, W, y), fill=(int(150 + 60 * (1 - t)), int(78 + 34 * (1 - t)), int(36 + 18 * (1 - t))))
d.rectangle((0, front, W, front + 26), fill=(240, 170, 104)); d.rectangle((0, front + 26, W, H), fill=(58, 26, 16))
for x in (150, 500, 930):
    d.rectangle((x, top + 8, x + 120, front - 6), fill=(214, 138, 74))
im.convert("RGB").save(L + "guide_bar.png")
print("garden palette", ["#%02x%02x%02x" % c for c in pal("assets/art/garden/garden-mansion.png")][:24])
print("bar palette", ["#%02x%02x%02x" % c for c in pal("assets/art/bar/bar-interior.png")][:24])
