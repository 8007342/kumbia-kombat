#!/usr/bin/env python3
"""The lawn kiss with Mācron's whole body, the sprite grown large. Three layers, because the kiss has to go over his head and his body has to go over the hedge:
head under the dancers, hedge over their cut-off shoulders, then body in front of the hedge and the mark on his belly on its own.
The mark is a separate actor so a mirrored close-up can keep reading the right way round: see keep-logo-reading.patch beside this folder. Writes assets/art/closeups/duet-macron-*.png. Run from the worktree root. usage: kiss.py [outdir]"""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import numpy as np
from PIL import Image
import rig

SIZE = (400, 440); FLOOR = (200, 425); K = 1.4
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "assets/art/closeups")
HEAD_Y = -186  # sprite px above the floor, as the rig stands him: the middle of the head


def canvas():
    return rig.Canvas(SIZE, FLOOR, K)


# Head alone: every drawing shares it exactly, only the eyes and the blush change.
for name, eye, blush in (("round", "round", 0), ("wide", "wide", 0), ("squash", "squash", 1), ("arc", "bigarc", 2), ("arc-blush", "bigarc", 3)):
    c = canvas(); rig.draw_head(c, 0, HEAD_Y, 0, eye, blush); c.finish().save(OUT / f"duet-macron-{name}.png", optimize=True)

silhouette = canvas(); rig.draw_head(silhouette, 0, HEAD_Y, 0, "arc", 0); hole = np.asarray(silhouette.finish())[..., 3] > 0


def body(name, arms, squash=0):
    """Neck down, no mark. His arms stop short of the head, and the head's outline is cut out, so the layers can't fight."""
    c = canvas(); c.poly(rig.sup(0, 4, 80, 7, 2), (4, 12, 10, 170))
    rig.draw_leg(c, (-32, -45), (-37, 0)); rig.draw_leg(c, (32, -45), (37, 0))
    rig.draw_torso(c, 0, -90, 0, logo=False)
    for side, s in (("L", -50), ("R", 50)):
        hand, bend, cuff, along = arms[side]; rig.draw_arm(c, (s, -116), hand, bend, cuff); rig.draw_mitten(c, hand, along)
    im = np.array(c.finish()); im[hole] = 0; Image.fromarray(im, "RGBA").save(OUT / f"duet-macron-body-{name}.png", optimize=True)


# Standing and swaying: arms easy. The kiss: hands fly out. After: hands tucked in, shy and delighted.
body("rest", {"L": ((-90, -70), 5, True, (-1, 1)), "R": ((90, -70), -5, False, (1, 1))})
body("kiss", {"L": ((-100, -94), -7, True, (-1, -.4)), "R": ((100, -94), 7, False, (1, -.4))})
body("shy", {"L": ((-66, -60), 12, True, (1, 1)), "R": ((66, -60), -12, False, (-1, 1))})

# The mark alone. Its art is its canvas, so swapping the mark is swapping this file.
c = canvas(); rig.draw_logo(c, 0, -85, 50); c.finish().save(OUT / "duet-macron-logo.png", optimize=True)
print("head contact", (FLOOR[0], round(FLOOR[1] + HEAD_Y * K)))
