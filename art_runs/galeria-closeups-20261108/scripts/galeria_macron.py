#!/usr/bin/env python3
"""Mācron's half of the gallery's win close-up: one perfect double tap of his tiny feet, then his proud face.
Drawn from parts by the close-up rig (art_runs/closeups-v3-20261106/scripts/rig.py), like nod-mc-* and salon-mc-*.
Every canvas is the shape of the close-up's view (360x780 px = 180 x 390 units at scale .5), so whatever runs off a
canvas edge runs off the screen: nothing ends mid-screen (style guide 8.1, rule 5).
feet-*: the camera on the marble at his picture-right boot, grown huge and centred. Leg and belly run off the top
and left. Only that boot moves between rest, up and down.
proud, proud-blink: his face, chin up, smiling arcs and a blush, then a pleased squeeze of the eyes. Ears and boots
run off the sides and the bottom.
Usage: galeria_macron.py [out dir]. Writes galeria-mc-{feet-rest,feet-up,feet-down,proud,proud-blink}.png, 360x780."""
import pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[3]
for base in (ROOT, pathlib.Path("/home/forge/src/kumbia-kombat")):
    if (base / "art_runs/closeups-v3-20261106/scripts/rig.py").exists():
        sys.path.insert(0, str(base / "art_runs/closeups-v3-20261106/scripts")); break
import rig

SIZE = (360, 780)
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "assets/art/closeups")
L, R = (-37, 0), (37, 0)
FEET = dict(floor=(180, 760), k=5.0, base=dict(dx=-37, eye="round", head_dy=6))
FACE = dict(floor=(180, 840), k=2.6, base=dict(arms={"L": ((-70, -40), 8, True, 1, (0, 1)), "R": ((70, -40), -8, True, 1, (0, 1))}))
DRAWINGS = {
    "feet-rest": (FEET, dict(feet=(L, R))),
    # seen from the front a tap is the boot lifted straight up off the marble, square to the floor
    "feet-up": (FEET, dict(feet=(L, (37, -11)))),
    "feet-down": (FEET, dict(feet=(L, R), squash=2)),
    "proud": (FACE, dict(lean=-2, head_dy=-6, head_a=-3, eye="bigarc", blush=1)),
    "proud-blink": (FACE, dict(lean=-2, head_dy=-7, head_a=-5, eye="squash", blush=2)),
}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("galeria-mc-*.png"):
        old.unlink()
    for name, (shot, spec) in DRAWINGS.items():
        c = rig.Canvas(SIZE, shot["floor"], shot["k"]); rig.macron(c, **{**shot["base"], **spec})
        c.finish().save(OUT / f"galeria-mc-{name}.png", optimize=True)
    print("ok", OUT)
