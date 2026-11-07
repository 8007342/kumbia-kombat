#!/usr/bin/env python3
"""The billiards close-up's plate and foreground table, cut from the room's own
painting.

Run from the repo root with the art venv. CPU, seconds."""
from PIL import Image

OUT = "assets/art/closeups/"
room = Image.open("assets/art/billiards/billiards-room-clean.png").convert("RGB")
room.crop((362, 120, 832, 820)).save(OUT + "pool-chalk-plate.png", optimize=True)
table = room.crop((508, 478, 832, 590)).convert("RGBA")
table.save(OUT + "pool-chalk-table.png", optimize=True)
