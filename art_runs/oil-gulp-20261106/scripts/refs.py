#!/usr/bin/env python3
"""Stage references on the lane: atlas Macron and sheet bartender, flat on light grey, plus large crops of each hand."""
import json
from PIL import Image
R = "/work/tmp/imagegen/kumbia/oil-gulp/in/"
GREY = (222, 222, 222, 255)
def flat(im):
    bg = Image.new("RGBA", im.size, GREY); bg.alpha_composite(im); return bg.convert("RGB")
m = json.load(open("assets/art/party/manifest.json"))["atlases"]["hero"]["frames"]["front_idle"]["rect"]
atlas = Image.open("assets/art/party/macron-dance-v1.png").convert("RGBA")
x, y, w, h = m
fr = atlas.crop((x, y, x + w, y + h))
a = fr.split()[3].point(lambda v: 255 if v >= 128 else 0); fr.putalpha(a)
pad = Image.new("RGBA", (w + 80, h + 60), (0, 0, 0, 0)); pad.alpha_composite(fr, (40, 30))
flat(pad).resize(((w + 80) * 3, (h + 60) * 3), Image.NEAREST).save(R + "mac_front.png")
# his hand, the side away from the body, large; mitten and cuffs of the atlas
flat(pad).crop((150, 165, 305, 290)).resize((155 * 6, 125 * 6), Image.NEAREST).save(R + "mac_hand.png")
bt = Image.open("tool/art/references/bartender/front.png").convert("RGB")
bt.save(R + "bt_front.png")
bt.crop((430, 390, 580, 610)).resize((150 * 4, 220 * 4), Image.NEAREST).save(R + "bt_hand.png")
