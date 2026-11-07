#!/usr/bin/env python3
"""The salon close-up's plate, cut from the room's own clean painting: the right arched mirror with the garden in it,
the middle and right chandeliers above and the gilded panel between, for the rose handoff (plan/levels/salon-2026-11-07.md).
The same proportions as the billiards close-up's plate (470 x 700 plate px). No foreground: TERCIOPELO's actors are busts
and end at the frame's bottom edge.

Run from the repo root with the art venv. CPU, seconds."""
from PIL import Image

room = Image.open("assets/art/salon/salon-room.png").convert("RGB")
room.crop((362, 60, 832, 760)).save("assets/art/closeups/salon-rose-plate.png", optimize=True)
