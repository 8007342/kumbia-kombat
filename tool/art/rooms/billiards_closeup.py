#!/usr/bin/env python3
"""The billiards close-up's plate and foreground table, cut from the room's own
painting, and a stand-in for The Pool Player until her drawings land: her sheet,
mirrored so her cue is on Macron's side, with the cue tilted by code.

Run from the repo root with the art venv. CPU, seconds."""
from PIL import Image, ImageDraw

OUT = "assets/art/closeups/"
room = Image.open("assets/art/billiards/billiards-room-clean.png").convert("RGB")
room.crop((362, 120, 832, 820)).save(OUT + "pool-chalk-plate.png", optimize=True)
table = room.crop((508, 478, 832, 590)).convert("RGBA")
table.save(OUT + "pool-chalk-table.png", optimize=True)

front = Image.open("tool/art/references/pool-player/front.png").convert("RGBA")
bust = front.crop((120, 60, 560, 620)).transpose(Image.FLIP_LEFT_RIGHT)
TIP_UP, HAND = (370, 40), (370, 330)
BLUE = (70, 110, 220, 255)


def frame(name, tip, chalk=None, wink=False):
    im = bust.copy()
    px = im.load()
    # The painted cue above her hand goes, and one by code takes its place.
    for x in range(352, 392):
        for y in range(0, 322):
            px[x, y] = (0, 0, 0, 0)
    d = ImageDraw.Draw(im)
    d.line([HAND, tip], fill=(26, 16, 24, 255), width=13)
    d.line([HAND, tip], fill=(176, 118, 62, 255), width=7)
    d.line([tip, (tip[0] - (tip[0] - HAND[0]) // 12, tip[1] + 24)], fill=(235, 225, 205, 255), width=7)
    if chalk:
        d.rectangle([chalk[0] - 12, chalk[1] - 12, chalk[0] + 12, chalk[1] + 12], fill=BLUE, outline=(26, 16, 24, 255), width=3)
    if wink:
        d.rectangle([122, 104, 152, 128], fill=(176, 116, 80, 255))
        d.line([(122, 118), (136, 112), (152, 118)], fill=(26, 16, 24, 255), width=5)
    im.save(OUT + f"pool-standin-{name}.png", optimize=True)


frame("chalk-a", TIP_UP, chalk=(370, 26))
frame("chalk-b", TIP_UP, chalk=(384, 34))
frame("wink", TIP_UP, wink=True)
frame("reach", (395, 60), wink=True)
frame("dab", (414, 78))
