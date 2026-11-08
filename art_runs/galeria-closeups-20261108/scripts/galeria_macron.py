#!/usr/bin/env python3
"""Mācron's half of the gallery's win close-up: one perfect double tap of his tiny feet, then his proud face.
Drawn from parts by the close-up rig (art_runs/closeups-v3-20261106/scripts/rig.py), like nod-mc-* and salon-mc-*.
feet-*: the boots grown large on the floor, the canvas top cutting him at the belly (the limb ends off the frame).
Only the picture-right boot moves between rest, up and down; everything else is the same numbers every time.
face-*: the sprite to the knees, like nod-mc-*, chin up and chest out with fists on his hips, then a pleased blink.
Usage: galeria_macron.py [out dir]. Writes galeria-mc-{feet-rest,feet-up,feet-down,proud,proud-blink}.png, 400x440."""
import pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[3]
for base in (ROOT, pathlib.Path("/home/forge/src/kumbia-kombat")):
    if (base / "art_runs/closeups-v3-20261106/scripts/rig.py").exists():
        sys.path.insert(0, str(base / "art_runs/closeups-v3-20261106/scripts")); break
import rig

SIZE = (400, 440)
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "assets/art/closeups")
FEET_FLOOR, FEET_K = (200, 428), 3.0
FACE_FLOOR, FACE_K = (200, 470), 1.4
L, R = (-37, 0), (37, 0)
FEET = {
    "feet-rest": dict(feet=(L, R), toes=(0, 0)),
    # seen from the front a tap is the boot lifted straight up off the marble, square to the floor
    "feet-up": dict(feet=(L, (37, -13)), toes=(0, 0)),
    "feet-down": dict(feet=(L, R), toes=(0, 0), squash=3),
}
AKIMBO = {"L": ((-74, -62), 10, True, 1, (1, .2)), "R": ((74, -62), -10, True, 1, (-1, .2))}
FACE = {
    "proud": dict(lean=-3, head_dy=-5, head_a=-3, eye="bigarc", blush=1, arms=AKIMBO),
    "proud-blink": dict(lean=-3, head_dy=-6, head_a=-5, eye="squash", blush=2, arms=AKIMBO),
}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, spec in FEET.items():
        c = rig.Canvas(SIZE, FEET_FLOOR, FEET_K); rig.macron(c, **spec)
        c.finish().save(OUT / f"galeria-mc-{name}.png", optimize=True)
    for name, spec in FACE.items():
        c = rig.Canvas(SIZE, FACE_FLOOR, FACE_K); rig.macron(c, **spec)
        c.finish().save(OUT / f"galeria-mc-{name}.png", optimize=True)
    print("ok", OUT)
