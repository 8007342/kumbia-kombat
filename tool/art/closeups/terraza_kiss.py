#!/usr/bin/env python3
"""La Terraza's close-up, Mācron's half: Tía Purpurina plants a big lipstick kiss on his cheek panel and his antenna
sparks like a sparkler. Drawn from parts by the close-up rig (art_runs/closeups-v3-20261106/scripts/rig.py), on the
lawn kiss's canvases (400x440, floor (200, 425), K 1.4), so his body, mark and the shot's scale .36 can be the lawn's.

Head drawings, each sharing the lawn's head exactly; only the eyes, blush, the kiss mark and the sparks change:
  terraza-mc-rest     round eyes, no mark (the approach)
  terraza-mc-kissed   big arcs, full blush, the lipstick mark on his picture-left cheek panel (the side she is on)
  terraza-mc-spark-a  kissed, with the antenna's orb spitting sparks like a sparkler
  terraza-mc-spark-b  the same, the sparks turned and re-lengthened, for the second clink
And the wide shot's keepsake, terraza-kissmark.png: the mark at his atlas scale, drawn as pixels.

Usage: terraza_kiss.py [out dir]. Prints the contact point and the keepsake's anchor."""
import json, math, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
for base in (ROOT, pathlib.Path("/home/forge/src/kumbia-kombat")):
    if (base / "art_runs/closeups-v3-20261106/scripts/rig.py").exists():
        sys.path.insert(0, str(base / "art_runs/closeups-v3-20261106/scripts")); break
import rig  # noqa: E402
from PIL import Image  # noqa: E402

SIZE = (400, 440); FLOOR = (200, 425); K = 1.4
HEAD_Y = -186
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "assets/art/closeups")

# Her lipstick, from her palette (tool/art/characters/purpurina.json, lips #C8102E), with a shadow and a sheen.
LIP = (200, 16, 46, 255); LIP_LO = (128, 10, 34, 255); LIP_HI = (240, 96, 104, 255)
# The sparkler: white-hot at the core, gold, then orange tips. No pure white (style guide section 2).
HOT = (255, 246, 214, 255); GOLD = (255, 206, 84, 255); EMBER = (246, 132, 36, 255)
MARK_AT = (-54, 40)   # head-relative sprite px: the lower picture-left corner of the cream cheek panel
MARK_TILT = -18
ORB = (0, HEAD_Y - 92)


def kiss_mark(c, at=MARK_AT, s=1.6, tilt=MARK_TILT):
    """A lip print: an upper lip with a cupid's bow and a fuller lower lip, a parting line and two creases."""
    x0, y0 = at[0], HEAD_Y + at[1]
    def p(x, y):
        return rig.rot((x0 + x * s, y0 + y * s), tilt, (x0, y0))
    upper = [p(-14, 0), p(-11, -4), p(-6, -7), p(-2, -6), p(0, -4), p(2, -6), p(6, -7), p(11, -4), p(14, 0)]
    lower = [p(14, 0), p(10, 5), p(4, 8), p(-4, 8), p(-10, 5), p(-14, 0)]
    m = c.poly(upper + lower, LIP)
    c.poly([p(-14, 0), p(-4, 2), p(4, 2), p(14, 0), p(4, 0.6), p(-4, 0.6)], LIP_LO, m)  # the parting
    c.poly(rig.sup(*p(-4, 5.2), 3.2, 1.3, 2, tilt), LIP_HI, m)                        # sheen on the lower lip
    for cx in (-7, 7):                                                                # creases
        c.circles([p(cx, 2.5), p(cx * 1.05, 6.5)], 1.2, LIP_LO, m)


def sparks(c, turn=0.0, seed=0):
    """Short rays and loose dots thrown off the antenna's orb, like a lit sparkler."""
    ox, oy = ORB
    for i in range(9):  # only up and out to the sides: nothing crosses his face
        a = math.radians(-200 + turn + i * 27.5 + (6 if i % 2 else 0))
        r0 = 22 + (i * 7 + seed * 3) % 5
        r1 = r0 + 14 + ((i * 13 + seed * 5) % 4) * 6
        ray = [(ox + math.cos(a) * (r0 + (r1 - r0) * t / 6), oy + math.sin(a) * (r0 + (r1 - r0) * t / 6)) for t in range(7)]
        c.circles(ray[:3], 7, HOT); c.circles(ray[2:5], 6, GOLD); c.circles(ray[4:], 5, EMBER)
        if i % 3 != seed % 3:  # a loose spark past the ray's end
            d = r1 + 9 + (i % 2) * 6
            c.poly(rig.sup(ox + math.cos(a + .18) * d, oy + math.sin(a + .18) * d, 3.6, 3.6, 2), GOLD)


def head(name, eye, blush, mark=False, spark=None):
    c = rig.Canvas(SIZE, FLOOR, K)
    rig.draw_head(c, 0, HEAD_Y, 0, eye, blush)
    if mark:
        kiss_mark(c)
    if spark is not None:
        sparks(c, *spark)
        # The orb glows white-hot at its core, the cyan ring round it kept.
        c.poly(rig.sup(*ORB, 8, 8, 2), HOT)
    im = c.finish(); im.save(OUT / f"terraza-mc-{name}.png", optimize=True)
    return im


def keepsake():
    """The wide shot's mark, at Mācron's atlas scale (his rose is 9 px tall at height .16): 7 by 4 native pixels."""
    R, D, H = LIP[:3], LIP_LO[:3], LIP_HI[:3]
    rows = [
        ".RR.RR.",
        "RRRDRRR",
        "DRRRRRD",
        ".RRHRR.",
    ]
    key = {"R": R, "D": D, "H": H}
    im = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in key:
                im.putpixel((x, y), (*key[ch], 255))
    im.save(OUT / "terraza-kissmark.png", optimize=True)
    return im.size


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    head("rest", "round", 0)
    head("kissed", "bigarc", 3, mark=True)
    head("spark-a", "bigarc", 3, mark=True, spark=(0.0, 0))
    head("spark-b", "bigarc", 3, mark=True, spark=(18.0, 1))
    size = keepsake()
    mark_px = (FLOOR[0] + MARK_AT[0] * K, FLOOR[1] + (HEAD_Y + MARK_AT[1]) * K)
    height = -(ORB[1] - 15)  # orb top, sprite px above the floor: his whole height on the rig
    print(json.dumps({"headContact": [FLOOR[0], round(FLOOR[1] + HEAD_Y * K)], "markCentreArt": [round(v) for v in mark_px],
                      "keepsakeSize": size, "keepsakeAnchor": [3, 3],
                      "keepsakeAtHeights": [round(MARK_AT[0] / height, 3), round((HEAD_Y + MARK_AT[1]) / height, 3)]}))
