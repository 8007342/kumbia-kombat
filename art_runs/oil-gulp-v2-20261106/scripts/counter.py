#!/usr/bin/env python3
"""The bar counter in front of Macron in the gulp close-up, so his torso has somewhere to go. Flat bands on a 2-pixel grid. usage: counter.py out.png"""
import sys
from PIL import Image, ImageDraw
W, H = 600, 500
im = Image.new("RGB", (W, H), (34, 16, 26)); d = ImageDraw.Draw(im)
d.rectangle([0, 0, W, 5], fill=(226, 150, 62)); d.rectangle([0, 6, W, 11], fill=(120, 62, 32)); d.rectangle([0, 12, W, 25], fill=(58, 28, 30)); d.rectangle([0, 26, W, 31], fill=(12, 6, 12))
d.rectangle([0, 44, W, 47], fill=(196, 128, 54)); d.rectangle([0, 48, W, 49], fill=(90, 50, 30))
for x in range(20, W, 110):
    d.rectangle([x, 62, x + 92, H], fill=(44, 21, 32)); d.rectangle([x, 62, x + 92, 63], fill=(70, 34, 40)); d.rectangle([x, 62, x + 1, H], fill=(70, 34, 40)); d.rectangle([x + 91, 62, x + 92, H], fill=(18, 8, 14))
    for y in range(90, H, 26): d.rectangle([x + 10, y, x + 54 + (y % 3) * 10, y], fill=(38, 18, 28))
im.resize((W * 2, H * 2), Image.NEAREST).convert("P", palette=Image.ADAPTIVE, colors=16).save(sys.argv[1], optimize=True)
