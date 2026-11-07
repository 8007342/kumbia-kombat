#!/usr/bin/env python3
"""Mācron's half of the matched nod: arms crossed, the sprite grown large, drawn from parts by the close-up rig.
Arms cross above the mark so it still reads. Only his head moves between drawings, and only by this script's numbers, so nothing flickers.
Usage: nod_macron.py [out dir]. Writes nod-mc-{rest,down,up}.png, 400x440, transparent."""
import pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "art_runs/closeups-v3-20261106/scripts"))
import rig

SIZE = (400, 440); FLOOR = (200, 470); K = 1.4
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "assets/art/closeups")
# Picture-left arm over picture-right, hands tucked at the far elbows. (hand, bend, cuff, layer, mitten direction)
ARMS = {"R": ((-38, -104), 7, False, 1, (-1, -.15)), "L": ((38, -98), -7, True, 1, (1, -.15))}
for name, head_dy, eye in (("rest", 0, "squash"), ("down", 15, "arc"), ("up", 3, "squash")):
    c = rig.Canvas(SIZE, FLOOR, K)
    # The mark sits low on the belly, under the folded arms, drawn after them so they can't cover it.
    rig.macron(c, head_dy=head_dy, eye=eye, arms=ARMS, logo=False, between=lambda c: rig.draw_logo(c, 1, -66, 40))
    c.finish().save(OUT / f"nod-mc-{name}.png", optimize=True)
print("ok", OUT)
