#!/usr/bin/env python3
"""The gallery close-up's plate, cut from the room's own clean painting (plan/levels/galeria-art-2026-11-08.md): the far
doors, the end of the green runner and the polished marble in front of it, where Mācron's boots tap. The same proportions
as the billiards and salon close-ups (470 x 700 plate px). Mācron's feet drawings stand on the canvas floor line; the
scene dims the plate under them.

Run from the repo root with the art venv. CPU, seconds."""
from PIL import Image

room = Image.open("assets/art/galeria/galeria-room.png").convert("RGB")
room.crop((181, 330, 651, 1030)).save("assets/art/closeups/galeria-floor-plate.png", optimize=True)
