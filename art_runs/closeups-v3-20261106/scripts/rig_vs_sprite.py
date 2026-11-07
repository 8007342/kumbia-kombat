#!/usr/bin/env python3
"""The rig's idle pose beside the sprite it copies, same height, large and at phone size. usage: rig_vs_sprite.py out.png. Run from the worktree root."""
import json, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from PIL import Image
import rig
hero = json.load(open("assets/art/party/manifest.json"))["atlases"]["hero"]; atlas = Image.open("assets/art/party/" + hero["image"]).convert("RGBA")
x, y, w, h = hero["frames"]["front_idle"]["rect"]; sprite = atlas.crop((x, y, x + w, y + h))
c = rig.Canvas((420, 460), (210, 450), 1.3)
rig.macron(c, arms={"L": ((-92, -72), 5, True, 1, (-1, 1)), "R": ((92, -72), -5, False, 1, (1, 1))})
drawn = c.finish(); drawn.save("/tmp/none.png") if False else None
bb = drawn.getbbox(); drawn = drawn.crop(bb)
S = Image.new("RGBA", (1300, 620), (50, 50, 66, 255))
big = sprite.resize((round(w * 2), round(h * 2)), Image.NEAREST); S.alpha_composite(big, (20, 20)); S.alpha_composite(drawn.resize((drawn.width * 1, drawn.height * 1), Image.NEAREST), (520, 20))
ph = 60  # about what the phone shows of the sprite in the room, logical px x3
for i, im in enumerate((sprite, drawn)):
    k = 180 / im.height; S.alpha_composite(im.resize((round(im.width * k), 180), Image.NEAREST), (1000 + i * 150, 20))
S.save(sys.argv[1])
