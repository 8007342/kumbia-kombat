#!/usr/bin/env python3
"""The oil gulp as the sprite grown large: standing on the bar, feet planted, both hands around a glass nearly his size.
Writes assets/art/closeups/oil-gulp-mc3-*.png. Run from the worktree root. usage: gulp.py [outdir]"""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import rig

SIZE = (560, 520); ORIGIN = (172, 506); K = 1.3
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "assets/art/closeups")
GL, GW = 166, 100  # the glass, sprite px: the one in the bartender's hand at this scale


def side(pose, x, y):
    dx, dy, lean, squash = pose.get("dx", 0), pose.get("dy", 0), pose.get("lean", 0), pose.get("squash", 0)
    return rig.rot((dx + x, dy + y + squash), lean, (dx, -56 + dy))


def frame(name, glass=None, far=None, near=None, **pose):
    """glass = (rim, tilt, oil left). Both his arms go to the glass from behind the belly, so the mark stays clear: he has quarter-turned to it, with no third shoulder on show.
    far and near are the hands on it, in glass coordinates (across, along), with (bend, mitten direction): far under the glass, near over it."""
    c = rig.Canvas(SIZE, ORIGIN, K); arms = dict(pose.pop("arms", {})); front = None; behind = None
    if glass:
        rim, tilt, oil = glass; t, _ = rig.glass_shape(rim, tilt, GL, GW)
        def behind(cv):
            hand = t(*far[:2]); rig.draw_arm(cv, side(pose, 46, -112), hand, far[2], False); rig.draw_mitten(cv, hand, far[3])
        def front(cv):
            rig.draw_glass(cv, rim, tilt, oil, GL, GW)
            hand = t(*near[:2]); rig.draw_arm(cv, side(pose, 56, -100), hand, near[2], True, ball=False); rig.draw_mitten(cv, hand, near[3])
    # A soft shadow on the bar, so his feet stand on something, and stay there when he hops.
    shadow = pose.pop("shadow", True)
    if shadow: c.poly(rig.sup(pose.get("dx", 0), 4, 74, 6, 2), (20, 8, 8, 170))
    rig.macron(c, arms=arms, behind=behind, front=front, **pose)
    c.finish().save(OUT / f"oil-gulp-mc3-{name}.png", optimize=True)


REST_L = ((-92, -70), 5, True, 1, (-1, 1)); REST_R = ((92, -70), -5, False, 1, (1, 1))
UP_L = ((-104, -122), -10, True, 1, (-1, -1)); UP_R = ((104, -122), 10, False, 1, (1, -1))
REACH_L = ((-84, -66), 6, True, 1, (-1, 1)); REACH_R = ((112, -118), 8, False, 1, (1, 0))

# Waiting: he's still dancing. Sway, sway, then eyes wide and a hand out for it.
frame("sway1", arms={"L": UP_L, "R": REST_R}, lean=-5, head_a=-5, squash=3, eye="arc")
frame("sway2", arms={"L": REST_L, "R": UP_R}, lean=5, head_a=5, squash=3, eye="arc")
frame("reach", arms={"L": REACH_L, "R": REACH_R}, lean=2, head_a=5, squash=5, eye="round", turn=8)

# Glug by glug: the glass tips further at his chin, the body tips back with it, the eyes squeeze, the oil falls by volume.
FAR = (-44, 46, 6, (1, 0)); NEAR = (8, 34, 12, (1, 0))
T = dict(turn=14)
frame("gulp1", glass=((118, -188), 12, .94), far=FAR, near=NEAR, lean=-1, head_a=-3, squash=2, eye="round", **T)
frame("gulp2", glass=((92, -170), 38, .72), far=FAR, near=NEAR, lean=-5, head_a=-9, eye="arc", **T)
frame("gulp3", glass=((78, -158), 60, .46), far=FAR, near=NEAR, lean=-9, head_a=-15, squash=-2, eye="arc", **T)
frame("gulp4", glass=((70, -152), 84, .22), far=FAR, near=NEAR, lean=-12, head_a=-20, squash=-3, eye="shut", toes=(0, -4), **T)
frame("gulp5", glass=((64, -150), 106, .05), far=FAR, near=NEAR, lean=-14, head_a=-24, squash=-3, eye="shut", toes=(0, -7), **T)


def down(cv):
    """The empty glass set down on the bar beside him, a thud of relief."""
    rig.draw_glass(cv, (150, -166), 0, 0, GL, GW)


def after(name, **pose):
    c = rig.Canvas(SIZE, ORIGIN, K); c.poly(rig.sup(pose.get("dx", 0), 4, 74 - abs(pose.get("dy", 0)) * .5, 6, 2), (20, 8, 8, 170)); c.poly(rig.sup(150, 3, 52, 4, 2), (20, 8, 8, 170))
    rig.macron(c, behind=down, **pose)
    c.finish().save(OUT / f"oil-gulp-mc3-{name}.png", optimize=True)


# Done: the glass thuds down, a little squash of relief, a wiggle each way and a hop.
OUT_L = ((-100, -116), -10, True, 1, (-1, -1)); OUT_R = ((100, -116), 10, False, 1, (1, -1)); LOW_L = ((-90, -76), 5, True, 1, (-1, 1)); LOW_R = ((90, -76), -5, False, 1, (1, 1))
after("relief", arms={"L": LOW_L, "R": LOW_R}, squash=10, eye="bigarc", head_dy=4)
after("wiggle1", arms={"L": OUT_L, "R": LOW_R}, lean=-8, head_a=-8, squash=4, eye="bigarc", toes=(-3, 0))
after("wiggle2", arms={"L": LOW_L, "R": OUT_R}, lean=8, head_a=8, squash=4, eye="bigarc", toes=(0, 3))
after("hop", arms={"L": OUT_L, "R": OUT_R}, dy=-26, squash=-4, eye="bigarc", toes=(-8, 8))
