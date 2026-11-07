#!/usr/bin/env python3
"""Mācron's half of the rose handoff, the sprite grown large and drawn from parts by the close-up rig, like nod-mc-*.
He stands on the picture's right, Don Terciopelo on its left. reach: his picture-left hand out for the rose. take: the
rose in that hand, held up to look at. tuck: the hand at his antenna, tucking the rose behind it. rest: the rose stays
behind the antenna, both hands down, blushing arcs. The rose is drawn behind the antenna's stem, so the stem crosses it.
Only the arm, the eyes and the rose change between drawings; legs, belly and mark are the same numbers every time.
Usage: salon_macron.py [out dir]. Writes salon-mc-{reach,take,tuck,rest}.png (400x440) and salon-rose.png (the wide
shot's rose, native pixels) and prints the rose's anchors."""
import json, math, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[3]
for base in (ROOT, pathlib.Path("/home/forge/src/kumbia-kombat")):
    if (base / "art_runs/closeups-v3-20261106/scripts/rig.py").exists():
        sys.path.insert(0, str(base / "art_runs/closeups-v3-20261106/scripts")); break
import rig
from PIL import Image

SIZE = (400, 440); FLOOR = (200, 470); K = 1.4
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "assets/art/closeups")
# The rose's colours: the red from Don Terciopelo's palette, a velvet shadow, a leaf green kept dark under the room's gold.
RED = (196, 30, 46, 255); RED_LO = (122, 18, 34, 255); RED_HI = (236, 92, 92, 255)
LEAF = (46, 112, 58, 255); LEAF_LO = (24, 66, 36, 255)
THIN = 3.2
ROSE = 1.5  # bloom scale: about the size of his mitten, so it reads in the close-up  # the rose's outline: thinner than his, it is a small thing


def rose(c, at, size=1.0, tilt=0.0, stem=(0, 1), stem_len=34):
    """A rose bloom centred at `at` (sprite px), its stem running along `stem` from under the bloom."""
    x, y = at; s = size
    L = math.hypot(*stem) or 1; ux, uy = stem[0] / L, stem[1] / L
    path = [(x + ux * (8 + i * stem_len / 10) * s, y + uy * (8 + i * stem_len / 10) * s) for i in range(11)]
    c.circles(path, 3.5 * s + THIN * 2, rig.INK); c.circles(path, 3.5 * s, LEAF_LO)
    mid = path[5]; nx, ny = -uy, ux
    leaf = rig.sup(mid[0] + nx * 7 * s, mid[1] + ny * 7 * s, 7 * s, 3.6 * s, 2, math.degrees(math.atan2(uy, ux)) + 35)
    m = rig.inked(c, leaf, LEAF, THIN); c.poly(rig.sup(mid[0] + nx * 8 * s, mid[1] + ny * 8.5 * s, 5 * s, 1.6 * s, 2, math.degrees(math.atan2(uy, ux)) + 35), LEAF_LO, m)
    m = rig.inked(c, rig.sup(x, y, 12 * s, 11 * s, 2.2, tilt), RED, THIN)
    c.poly(rig.sup(x + 1 * s, y + 5 * s, 10 * s, 5 * s, 2.2, tilt), RED_LO, m)
    for r, a0 in ((7.5, 200), (4.5, 20)):  # the petals' spiral, two dark arcs
        arc = [(x + math.cos(math.radians(a0 + t * 14)) * r * s, y - 1 * s + math.sin(math.radians(a0 + t * 14)) * r * 0.8 * s) for t in range(12)]
        c.circles(arc, 2.2 * s, RED_LO, m)
    c.poly(rig.sup(x - 4 * s, y - 5 * s, 3.4 * s, 2.2 * s, 2, tilt), RED_HI, m)


HEAD = (0, -186)
TUCK = (-24, -262)          # the bloom, tucked on the picture-left side of the antenna, under its orb
REST_L = ((-92, -70), 5, True, 1, (-1, 1)); REST_R = ((92, -70), -5, False, 1, (1, 1))
REACH_L = ((-128, -134), -4, True, 2, (-1, 0))
TAKE_L = ((-96, -150), -12, True, 2, (0, -1))
TUCK_L = ((-58, -258), -10, True, 0, (1, -0.4))  # behind the head: only the mitten shows, at the rose
FRAMES = {
    "reach": dict(arms={"L": REACH_L, "R": REST_R}, lean=-4, head_a=-6, eye="round", rose=None),
    "take": dict(arms={"L": TAKE_L, "R": REST_R}, head_a=-4, eye="round", rose=("hand", (-100, -186), (0.25, 1))),
    "tuck": dict(arms={"L": TUCK_L, "R": REST_R}, head_a=4, eye="arc", blush=1, rose=("antenna", TUCK, (-0.7, 1))),
    "rest": dict(arms={"L": REST_L, "R": REST_R}, eye="arc", blush=2, rose=("antenna", TUCK, (-0.7, 1))),
}


def draw(name, spec):
    spec = dict(spec); kind = spec.pop("rose")
    c = rig.Canvas(SIZE, FLOOR, K)
    behind = front = None
    if kind and kind[0] == "antenna":
        # Behind everything, so the antenna's stem crosses the bloom: the rose is behind the antenna.
        behind = lambda cv: rose(cv, kind[1], ROSE, -20, kind[2], 22)
    elif kind:
        # In the hand, drawn after the arm so the mitten holds the stem and the bloom shows above it.
        front = lambda cv: rose(cv, kind[1], ROSE, 10, kind[2], 26)
    rig.macron(c, behind=behind, front=front, **spec)
    im = c.finish(); im.save(OUT / f"salon-mc-{name}.png", optimize=True)
    return im


def wide_rose():
    """The wide shot's rose, at Mācron's atlas scale: a few native pixels, drawn as pixels, not shrunk."""
    R, D, H, G, g, I = RED[:3], RED_LO[:3], RED_HI[:3], LEAF[:3], LEAF_LO[:3], rig.INK[:3]
    rows = [
        "..IIII..",
        ".IHRRDI.",
        "IRRDRRDI",
        "IRDRRDRI",
        ".IDDDDI.",
        "..IgII..",
        ".IGgI...",
        "..IgI...",
        "...I....",
    ]
    key = {"I": I, "R": R, "D": D, "H": H, "G": G, "g": g}
    im = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in key: im.putpixel((x, y), (*key[ch], 255))
    im.save(OUT / "salon-rose.png", optimize=True)
    return im.size


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for n, s in FRAMES.items(): draw(n, s)
    size = wide_rose()
    tuck_px = (FLOOR[0] + TUCK[0] * K, FLOOR[1] + TUCK[1] * K)
    print(json.dumps({"closeupRoseCentre": [round(v) for v in tuck_px], "wideRoseSize": size,
                      "wideRoseAnchor": "bottom of the stem, column 3 row 8; place it beside the antenna stem, under the orb"}))
