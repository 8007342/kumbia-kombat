#!/usr/bin/env python3
"""Mācron's half of the banquet close-up, the sprite grown large and drawn from parts by the close-up rig, like salon-mc-*.
He stands on the picture's right, Don Charolas on its left. reach: his picture-left hand out for the tiny oil can.
take: the can in that hand, held up to look at, its birthday candle lit. sip: the can tipped to the bottom of his face
screen, eyes squeezed shut. happy: the can held low, eyes in big arcs, blushing. The can and its candle are drawn here
as shapes; nothing else changes between drawings but the arm, the eyes and the can.
Usage: comedor_macron.py [out dir]. Writes comedor-mc-{reach,take,sip,happy}.png (400x440) and comedor-can.png
(the can and candle alone, for the reveal on the tray)."""
import json, math, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[3]
for base in (ROOT, pathlib.Path("/home/forge/src/kumbia-kombat")):
    if (base / "art_runs/closeups-v3-20261106/scripts/rig.py").exists():
        sys.path.insert(0, str(base / "art_runs/closeups-v3-20261106/scripts")); break
import rig

SIZE = (400, 440); FLOOR = (200, 470); K = 1.4
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "assets/art/closeups")
GREEN = (38, 92, 62, 255); GREEN_LO = (22, 58, 40, 255); GOLD = (214, 168, 64, 255); GOLD_LO = (150, 108, 34, 255)
TIN = (176, 182, 190, 255); WAX = (246, 196, 214, 255); WAX_STRIPE = (214, 92, 138, 255)
FLAME = (255, 214, 92, 255); FLAME_HI = (255, 246, 200, 255); THIN = 3.2


def can(c, at, s=1.0, tilt=0.0, lit=True):
    """The tiny oil can: a dark green tin with a gold band, a spout at its shoulder, a birthday candle on its lid.
    `at` is the can's bottom centre, sprite px; `tilt` in degrees, positive tips the top toward the picture's left."""
    x, y = at
    def p(u, v): return rig.rot((x + u * s, y + v * s), tilt, (x, y))
    body = [p(-13, 0), p(13, 0), p(13, -30), p(-13, -30)]
    m = rig.inked(c, body, GREEN, THIN)
    c.poly([p(-13, -12), p(13, -12), p(13, -21), p(-13, -21)], GOLD, m)
    c.poly([p(-13, -12), p(13, -12), p(13, -14), p(-13, -14)], GOLD_LO, m)
    c.poly([p(6, 0), p(13, 0), p(13, -30), p(6, -30)], GREEN_LO, m)
    rig.inked(c, [p(-14, -30), p(14, -30), p(11, -35), p(-11, -35)], TIN, THIN)          # the lid's rim
    rig.inked(c, [p(6, -34), p(10, -34), p(16, -46), p(12, -47)], TIN, THIN)            # the spout
    rig.inked(c, [p(-4, -35), p(1, -35), p(1, -58), p(-4, -58)], WAX, THIN * .8)        # the candle
    for v in (-40, -47, -54):
        c.poly([p(-4, v), p(1, v - 3), p(1, v - 1), p(-4, v + 2)], WAX_STRIPE)
    if lit:
        rig.inked(c, rig.sup(*p(-1.5, -66), 4 * s, 7 * s, 2.0, tilt), FLAME, THIN * .7)
        c.poly(rig.sup(*p(-1.5, -64), 1.8 * s, 3.4 * s, 2.0, tilt), FLAME_HI)


REST_L = ((-92, -70), 5, True, 1, (-1, 1)); REST_R = ((92, -70), -5, False, 1, (1, 1))
REACH_L = ((-130, -120), -4, True, 2, (-1, 0))
TAKE_L = ((-90, -140), -12, True, 2, (0, -1))
SIP_L = ((-34, -150), -16, True, 2, (1, -0.4))
HAPPY_L = ((-80, -108), -8, True, 2, (0, -1))
FRAMES = {
    "reach": dict(arms={"L": REACH_L, "R": REST_R}, lean=-4, head_a=-6, eye="round", can=None),
    "take": dict(arms={"L": TAKE_L, "R": REST_R}, head_a=-4, eye="wide", can=((-92, -150), 0, True)),
    "sip": dict(arms={"L": SIP_L, "R": REST_R}, head_a=6, eye="shut", blush=1, can=((-50, -140), 40, True)),
    "happy": dict(arms={"L": HAPPY_L, "R": REST_R}, dy=-6, eye="bigarc", blush=2, can=((-82, -118), 8, True)),
}


def draw(name, spec):
    spec = dict(spec); held = spec.pop("can")
    c = rig.Canvas(SIZE, FLOOR, K)
    front = (lambda cv: can(cv, held[0], 1.3, held[1], held[2])) if held else None
    rig.macron(c, front=front, **spec)
    c.finish().save(OUT / f"comedor-mc-{name}.png", optimize=True)


def can_alone():
    c = rig.Canvas((80, 120), (40, 110), K)
    can(c, (0, 0), 1.3, 0, True)
    c.finish().save(OUT / "comedor-can.png", optimize=True)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for n, s in FRAMES.items(): draw(n, s)
    can_alone()
    print(json.dumps({"drawings": [f"comedor-mc-{n}.png" for n in FRAMES], "can": "comedor-can.png"}))
