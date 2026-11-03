"""Hand-keyed pose vocabulary for the Blender stand-ins.

Angles are absolute segment directions in degrees (see standin.seg_dir):
  arm/fore/thigh/shin = (abd, flex)
  abd  0 = hanging down, 90 = horizontal outward, 180 = straight up,
       negative = crossing inward toward the body's midline.
  flex positive = toward the viewer (character's forward, -Y).
Arms are in the torso frame, legs in the body frame (after yaw only).

Body (positive values; the character's left is screen right):
  yaw         turns the whole character toward its left (0 = facing camera)
  twist       turns the torso over the hips toward its left
  lean        tips the torso forward (negative = chest proud, leaning back)
  side_bend   tips the torso toward its left (lowers the left shoulder)
  pelvis_roll raises the left hip. Contrapposto = pelvis_roll and side_bend
              with the SAME sign (left hip up, left shoulder down).
  pelvis_x    hip push to the left over the planted foot (the weighted legs
              swing about their hips; the planted foot never slides)
  pelvis_y    hip push backward over the planted foot
  head_turn   toward its left; head_side tilts toward its left;
  head_nod    tips the chin down (negative = chin up)
  knee_out    turns every bent knee outward about its hip-ankle line so a
              bend toward the camera reads from the front; l_/r_knee_out
              override it per leg
  l_foot/r_foot  foot pitch, positive = toe down, negative = toe up (heel
              dig). None lets a free foot near the floor rest on its ball.
  pin         which ankle the renderer holds still: "l", "r" or "mid";
              empty = follow the support foot ("both" pins the midpoint).
  both_home   with support "both", IK both ankles onto their home spots so
              feet never slide in a two-foot stance (the shorter leg sets
              the height, the other knee bends). Walk contacts turn it off:
              there the pinned foot sets the height and the other foot
              lands where the leg angles put it.

Each drawing is (Pose, support): support names the weighted foot, "left",
"right" or "both". The renderer plants the pinned ankle at its rest-pose home
in x, y and z, so weight shifts move the body, never the support foot.

`mirror()` swaps left and right in the rig. That is fine for Mācron too: the
render still puts his cuff on the anatomical right arm. Only image mirroring is
forbidden. Mirrored *clips* (right_hand from left_hand) are allowed; within a
single drawing the left and right sides are never twins, except on the clap.

Clip and drawing names of motion set opponent-64 (14 clips, 64 drawings) are
shared by every opponent; tool/art/motion/opponent-64.json holds their metadata. Choreography
follows the approved cumbia research (back-break groove with the accent on the
beat-4 hold, diagonal hand calls, heel-dig foot calls, brim-touch finish).
"""

from __future__ import annotations

from dataclasses import dataclass, replace

A = tuple[float, float]


@dataclass(frozen=True)
class Pose:
    yaw: float = 0
    twist: float = 0
    lean: float = 0
    side_bend: float = 0
    pelvis_x: float = 0
    pelvis_y: float = 0
    pelvis_roll: float = 0
    head_turn: float = 0
    head_side: float = 0
    head_nod: float = 0
    l_arm: A = (12, 0)
    l_fore: A = (8, 18)
    r_arm: A = (12, 0)
    r_fore: A = (8, 18)
    l_thigh: A = (4, 2)
    l_shin: A = (4, -2)
    r_thigh: A = (4, 2)
    r_shin: A = (4, -2)
    toe_out: float = 14
    knee_out: float = 35
    l_knee_out: float | None = None
    r_knee_out: float | None = None
    l_foot: float | None = None
    r_foot: float | None = None
    pin: str = ""
    both_home: bool = True


REST = Pose()
SWAP = {"left": "right", "right": "left", "both": "both"}
PIN_SWAP = {"l": "r", "r": "l", "mid": "mid", "": ""}


def mirror(p: Pose) -> Pose:
    return replace(
        p, yaw=-p.yaw, twist=-p.twist, side_bend=-p.side_bend, pelvis_x=-p.pelvis_x,
        pelvis_roll=-p.pelvis_roll, head_turn=-p.head_turn, head_side=-p.head_side,
        l_arm=p.r_arm, r_arm=p.l_arm, l_fore=p.r_fore, r_fore=p.l_fore,
        l_thigh=p.r_thigh, r_thigh=p.l_thigh, l_shin=p.r_shin, r_shin=p.l_shin,
        l_knee_out=p.r_knee_out, r_knee_out=p.l_knee_out, l_foot=p.r_foot, r_foot=p.l_foot,
        pin=PIN_SWAP[p.pin],
    )


def mirror_clip(clip: dict, rename: dict[str, str] | None = None) -> dict:
    out = {}
    for name, (pose, sup) in clip.items():
        out[(rename or {}).get(name, name)] = (mirror(pose), SWAP[sup])
    return out


def ordered(d: dict, names: list[str]) -> dict:
    return {n: d[n] for n in names}


# Shared arm shapes (torso frame). AKIMBO = fist on the hip, elbow out.
AKIMBO_L = dict(l_arm=(58, -18), l_fore=(-48, -8))
AKIMBO_R = dict(r_arm=(58, -18), r_fore=(-48, -8))
AKIMBO_L_WIDE = dict(l_arm=(68, -26), l_fore=(-40, -14))
AKIMBO_R_WIDE = dict(r_arm=(68, -26), r_fore=(-40, -14))
# Hands clasped behind the back (traditional cumbia man's posture).
BEHIND_L = dict(l_arm=(14, -42), l_fore=(-62, -52))
BEHIND_R = dict(r_arm=(14, -42), r_fore=(-62, -52))

# ---------------------------------------------------------------- groove
# Back-break basic (paso básico): 1 back-step on the ball with the deepest
# knee, 2 replace weight forward, 3 close with a dragged foot and rise,
# 4 THE HOLD: hip pop onto the new support, shoulder dip, wrist roll. Arms
# stay below the shoulders so the groove never reads as a hand call.

DOWN_L = Pose(yaw=12, twist=-14, lean=6, side_bend=6, pelvis_x=0.06, pelvis_roll=9,
              head_turn=2, head_side=-8,
              l_thigh=(8, 34), l_shin=(0, -18),
              r_thigh=(16, -20), r_shin=(14, -44),
              l_arm=(34, 36), l_fore=(24, 88), r_arm=(42, -28), r_fore=(56, 6))
PASS_L = Pose(yaw=8, twist=-4, lean=3, side_bend=2, pelvis_x=0.045, pelvis_roll=5,
              head_side=-3,
              l_thigh=(6, 16), l_shin=(2, -8),
              r_thigh=(12, -6), r_shin=(10, -24),
              l_arm=(26, 14), l_fore=(36, 52), r_arm=(30, -10), r_fore=(42, 26))
UP_L = Pose(yaw=4, twist=4, lean=0, side_bend=-3, pelvis_x=0.0, pelvis_roll=-2,
            head_nod=-8, head_side=3, pin="l",
            l_thigh=(5, 5), l_shin=(4, -3), r_thigh=(5, 6), r_shin=(4, -4),
            l_arm=(20, 0), l_fore=(16, 36), r_arm=(26, 8), r_fore=(30, 44))
PASS_L2 = Pose(yaw=-6, twist=8, lean=2, side_bend=-8, pelvis_x=-0.08, pelvis_roll=-13,
               head_turn=-6, head_side=10, head_nod=4,
               r_thigh=(2, 10), r_shin=(2, -6),
               l_thigh=(20, 24), l_shin=(6, -16),
               r_arm=(46, -12), r_fore=(78, 34), l_arm=(30, 26), l_fore=(-6, 84))

GROOVE = {
    "down_l": (DOWN_L, "left"), "pass_l": (PASS_L, "left"),
    "up_l": (UP_L, "both"), "pass_l2": (PASS_L2, "right"),
}
GROOVE |= mirror_clip(GROOVE, {"down_l": "down_r", "pass_l": "pass_r", "up_l": "up_r", "pass_l2": "pass_r2"})
GROOVE = ordered(GROOVE, ["down_l", "pass_l", "up_l", "pass_l2", "down_r", "pass_r", "up_r", "pass_r2"])

# ---------------------------------------------------------------- limb chains
# Hand call: scoop prep -> peak on one diagonal from the planted (opposite)
# foot through the hip drop to the raised palm -> overshoot -> sweep home.
# The off hand stays on the hip; the free foot never takes weight.

LEFT_HAND = {
    "prep": (Pose(twist=-12, lean=8, side_bend=-4, pelvis_x=-0.05, pelvis_roll=-7,
                  head_turn=16, head_nod=12,
                  r_thigh=(6, 30), r_shin=(0, -18), l_thigh=(16, 34), l_shin=(6, -26),
                  l_arm=(-4, 28), l_fore=(18, 48), **AKIMBO_R), "right"),
    "peak": (Pose(twist=6, lean=-3, side_bend=14, pelvis_x=-0.08, pelvis_roll=-11,
                  head_turn=22, head_nod=-8, head_side=4,
                  r_thigh=(2, 6), r_shin=(2, -3), l_thigh=(24, 6), l_shin=(24, 0),
                  l_arm=(128, 14), l_fore=(144, 10), **AKIMBO_R), "right"),
    "follow": (Pose(twist=10, lean=-4, side_bend=19, pelvis_x=-0.095, pelvis_roll=-13,
                    head_turn=26, head_nod=-10, head_side=6,
                    r_thigh=(2, 8), r_shin=(2, -4), l_thigh=(30, 8), l_shin=(30, 2),
                    l_arm=(148, 18), l_fore=(170, 34), **AKIMBO_R_WIDE), "right"),
    "return": (Pose(twist=2, lean=2, side_bend=4, pelvis_x=-0.03, pelvis_roll=-4, pin="r",
                    head_turn=8, head_nod=2,
                    r_thigh=(5, 10), r_shin=(3, -6), l_thigh=(7, 6), l_shin=(5, -4),
                    l_arm=(74, 22), l_fore=(42, 56), r_arm=(50, -16), r_fore=(-30, 4)), "both"),
}
RIGHT_HAND = mirror_clip(LEFT_HAND)

# Foot call: knee-lift prep -> heel dig (taconazo) on the forward diagonal,
# toe up, chest proud -> hip pop over the support with the heel still down ->
# arrastre, the foot dragged home. Arms stay at hip height.

LEFT_FOOT = {
    "prep": (Pose(twist=-8, lean=6, side_bend=-5, pelvis_x=-0.05, pelvis_roll=-6,
                  head_turn=12, head_nod=14,
                  r_thigh=(4, 30), r_shin=(0, -18),
                  l_thigh=(20, 48), l_shin=(6, -4), l_knee_out=20, l_foot=25,
                  r_arm=(42, -6), r_fore=(60, 30), **AKIMBO_L), "right"),
    "peak": (Pose(twist=10, lean=-6, side_bend=-10, pelvis_x=-0.06, pelvis_roll=7,
                  head_turn=20, head_nod=10, head_side=-4,
                  r_thigh=(2, 30), r_shin=(-2, -18),
                  l_thigh=(30, 18), l_shin=(31, 18), l_foot=-28,
                  l_arm=(46, -22), l_fore=(70, -12), **AKIMBO_R), "right"),
    "follow": (Pose(twist=4, lean=-3, side_bend=6, pelvis_x=-0.09, pelvis_roll=-8,
                    head_turn=14, head_nod=4, head_side=-8,
                    r_thigh=(2, 24), r_shin=(-2, -14),
                    l_thigh=(33, 14), l_shin=(33, 14), l_foot=-28,
                    l_arm=(56, -26), l_fore=(84, -14), **AKIMBO_R_WIDE), "right"),
    "return": (Pose(twist=-2, lean=2, side_bend=2, pelvis_x=-0.03, pelvis_roll=-3, pin="r",
                    head_turn=4,
                    r_thigh=(4, 12), r_shin=(2, -8), l_thigh=(8, 8), l_shin=(6, -6),
                    l_arm=(26, 0), l_fore=(24, 34), r_arm=(32, 6), r_fore=(36, 42)), "both"),
}
RIGHT_FOOT = mirror_clip(LEFT_FOOT)

# ---------------------------------------------------------------- locomotion
# Front-camera walks foreshorten, so they are staged on a diagonal (yaw) with
# the yaw sign constant per clip. The pin follows the foot taking weight.


def paseo(yaw: float) -> dict:
    """Swagger entrance: right hand on the hip, left arm swinging, a soft knee
    drop on each down, the hip rolling over the support, chin-up head bob."""
    out = {}
    for lead, s in (("l", 1), ("r", -1)):
        back = "r" if lead == "l" else "l"
        sup = "left" if lead == "l" else "right"
        roll = 6 * s
        arm_swing = 30 if lead == "r" else -26   # left arm swings opposite the leading leg
        legs = {
            "contact": {f"{lead}_thigh": (6, 30), f"{lead}_shin": (4, 22), f"{lead}_foot": -18,
                        f"{back}_thigh": (6, -20), f"{back}_shin": (6, -34)},
            "down": {f"{lead}_thigh": (6, 26), f"{lead}_shin": (2, -8),
                     f"{back}_thigh": (8, -14), f"{back}_shin": (8, -44)},
            "pass": {f"{lead}_thigh": (4, 4), f"{lead}_shin": (4, -2),
                     f"{back}_thigh": (12, 34), f"{back}_shin": (6, -18)},
        }
        body = {
            "contact": dict(pelvis_roll=0, twist=-8 * s, lean=2, head_nod=-4, side_bend=0),
            "down": dict(pelvis_roll=roll, twist=-6 * s, lean=5, head_nod=4, side_bend=4 * s,
                         pelvis_x=0.03 * s),
            "pass": dict(pelvis_roll=roll * 0.6, twist=-2 * s, lean=1, head_nod=-6, side_bend=2 * s,
                         pelvis_x=0.04 * s),
        }
        arms = {
            "contact": dict(l_arm=(22, arm_swing), l_fore=(20, 40 + arm_swing)),
            "down": dict(l_arm=(26, arm_swing * 0.7), l_fore=(30, 50 + arm_swing * 0.5)),
            "pass": dict(l_arm=(18, 0), l_fore=(16, 34)),
        }
        for ph in ("contact", "down", "pass"):
            pose = Pose(yaw=yaw, pin=lead, both_home=False, **legs[ph], **body[ph], **arms[ph], **AKIMBO_R)
            out[f"{ph}_{lead}"] = (pose, "both" if ph == "contact" else sup)
    return out


def back_steps(yaw: float) -> dict:
    """Retreat as chained cumbia back-steps, still facing the player: the
    free foot reaches back onto its ball, weight rolls back onto it, the
    front foot drags in. Hands stay low: left behind the back, right loose."""
    out = {}
    for lead, s in (("l", 1), ("r", -1)):
        front = "r" if lead == "l" else "l"
        sup = "left" if lead == "l" else "right"
        legs = {
            # lead foot has stepped back onto its ball; weight still split
            "contact": {f"{lead}_thigh": (10, -18), f"{lead}_shin": (10, -30),
                        f"{front}_thigh": (6, 24), f"{front}_shin": (2, -10)},
            # weight rolled back onto the lead foot, knee soft, hip drop
            "down": {f"{lead}_thigh": (6, -4), f"{lead}_shin": (4, -20), f"{lead}_foot": 0,
                     f"{front}_thigh": (8, 28), f"{front}_shin": (8, 4), f"{front}_foot": -10},
            # front foot dragged back past the support (arrastre)
            "pass": {f"{lead}_thigh": (4, 10), f"{lead}_shin": (2, -6),
                     f"{front}_thigh": (12, 2), f"{front}_shin": (8, -16)},
        }
        body = {
            "contact": dict(twist=10 * s, lean=-2, head_nod=-2, side_bend=0, pelvis_roll=-2 * s),
            "down": dict(twist=6 * s, lean=4, head_nod=6, side_bend=5 * s, pelvis_roll=7 * s,
                         pelvis_x=0.03 * s),
            "pass": dict(twist=0, lean=1, head_nod=-4, side_bend=2 * s, pelvis_roll=4 * s,
                         pelvis_x=0.05 * s),
        }
        swing = 28 if lead == "l" else -20
        arms = {
            "contact": dict(r_arm=(30, swing), r_fore=(36, 40 + swing)),
            "down": dict(r_arm=(36, swing * 0.5), r_fore=(50, 46)),
            "pass": dict(r_arm=(24, 0), r_fore=(22, 30)),
        }
        for ph in ("contact", "down", "pass"):
            # Contact pins the front foot (still flat, weighted); the stepping
            # foot is on its ball behind and takes the pin from "down" on.
            pose = Pose(yaw=yaw, head_turn=-yaw * 0.6, pin=front if ph == "contact" else lead,
                        both_home=False, **legs[ph], **body[ph], **arms[ph], **BEHIND_L)
            out[f"{ph}_{lead}"] = (pose, "both" if ph == "contact" else sup)
    return out


def side_yield(yaw: float) -> dict:
    """Paso lateral toward the sideline: left foot steps out, weight follows,
    right foot drags in; second step back on the diagonal with the right foot;
    the last drawing hands the floor over with an open palm."""
    d = {
        "contact_l": (Pose(yaw=yaw, pin="l", both_home=False, twist=-6, side_bend=-4, pelvis_roll=-3, pelvis_x=-0.02,
                           l_thigh=(24, 4), l_shin=(22, 0), r_thigh=(4, 28), r_shin=(2, -16),
                           l_arm=(34, 8), l_fore=(40, 30), **AKIMBO_R), "both"),
        "down_l": (Pose(yaw=yaw, twist=-4, lean=4, side_bend=6, pelvis_x=0.07, pelvis_roll=9,
                        head_nod=5,
                        l_thigh=(4, 26), l_shin=(-2, -16), r_thigh=(26, 28), r_shin=(14, -20),
                        l_arm=(28, 16), l_fore=(30, 50), **AKIMBO_R), "left"),
        "pass_l": (Pose(yaw=yaw, twist=2, side_bend=3, pelvis_x=0.05, pelvis_roll=5, head_nod=-5,
                        l_thigh=(4, 8), l_shin=(2, -4), r_thigh=(6, 2), r_shin=(4, -16),
                        l_arm=(20, 0), l_fore=(18, 34), **AKIMBO_R_WIDE), "left"),
        "contact_r": (Pose(yaw=yaw, pin="r", both_home=False, twist=8, side_bend=-2, pelvis_roll=2,
                           r_thigh=(12, -20), r_shin=(10, -26), l_thigh=(8, 32), l_shin=(4, -18),
                           l_arm=(30, -16), l_fore=(36, 10), r_arm=(32, 18), r_fore=(36, 52)), "both"),
        "down_r": (Pose(yaw=yaw, twist=10, lean=3, side_bend=-6, pelvis_x=-0.06, pelvis_roll=-9,
                        head_nod=6,
                        r_thigh=(6, -6), r_shin=(4, -22), l_thigh=(14, 34), l_shin=(6, -14), l_foot=-10,
                        l_arm=(22, -6), l_fore=(30, 24), r_arm=(40, 24), r_fore=(56, 54)), "right"),
        # Open palm, arm low and wide toward the vacated floor: "your turn".
        "pass_r": (Pose(yaw=yaw, twist=14, lean=-2, side_bend=-4, pelvis_x=-0.05, pelvis_roll=-6,
                        head_turn=-14, head_nod=4, head_side=6,
                        r_thigh=(4, 6), r_shin=(2, -4), l_thigh=(10, 22), l_shin=(6, -14),
                        r_arm=(70, 24), r_fore=(86, 30), **AKIMBO_L), "right"),
    }
    return d


WALK_ORDER = ["contact_l", "down_l", "pass_l", "contact_r", "down_r", "pass_r"]
ENTER_FORWARD = ordered(paseo(16), WALK_ORDER)
RETREAT_BACKWARD = ordered(back_steps(16), WALK_ORDER)
YIELD_SIDE = ordered(side_yield(26), WALK_ORDER)

# ---------------------------------------------------------------- social
# Watch: hands clasped behind the back, a gentle weight rock without a step,
# a small nod on the downbeat. Yaw is constant, head toward the performer.

WATCH = {
    "shift_l": (Pose(yaw=20, twist=-6, side_bend=5, pelvis_x=0.06, pelvis_roll=9, head_turn=-14, head_side=-4,
                     l_thigh=(4, 8), l_shin=(2, -4), r_thigh=(16, 24), r_shin=(6, -14),
                     **BEHIND_L, **BEHIND_R), "left"),
    "hold_l": (Pose(yaw=20, twist=-8, lean=4, side_bend=7, pelvis_x=0.07, pelvis_roll=11, head_turn=-14,
                    head_nod=14, head_side=-6,
                    l_thigh=(6, 22), l_shin=(0, -12), r_thigh=(18, 30), r_shin=(6, -18),
                    l_arm=(16, -46), l_fore=(-60, -54), **BEHIND_R), "left"),
    "shift_r": (Pose(yaw=20, twist=4, side_bend=-5, pelvis_x=-0.06, pelvis_roll=-9, head_turn=-18, head_side=4,
                     r_thigh=(4, 8), r_shin=(2, -4), l_thigh=(16, 24), l_shin=(6, -14),
                     **BEHIND_L, **BEHIND_R), "right"),
    "hold_r": (Pose(yaw=20, twist=6, lean=4, side_bend=-7, pelvis_x=-0.07, pelvis_roll=-11, head_turn=-18,
                    head_nod=6, head_side=6,
                    r_thigh=(6, 22), r_shin=(0, -12), l_thigh=(18, 30), l_shin=(6, -18),
                    r_arm=(16, -46), r_fore=(-60, -54), **BEHIND_L), "right"),
}

# Clap: chest height, symmetric (the one allowed twin), elbows out, palms
# meeting in front of the sternum on the beat with a knee dip. Never overhead,
# never leaning to one side.

CLAP = {
    "open": (Pose(head_nod=-4, l_arm=(34, 30), l_fore=(-12, 98), r_arm=(34, 30), r_fore=(-12, 98),
                  l_thigh=(5, 6), l_shin=(4, -3), r_thigh=(5, 6), r_shin=(4, -3)), "both"),
    "close": (Pose(head_nod=4, lean=2, l_arm=(26, 34), l_fore=(-62, 84), r_arm=(26, 34), r_fore=(-62, 84),
                   l_thigh=(5, 14), l_shin=(4, -8), r_thigh=(5, 14), r_shin=(4, -8)), "both"),
    "contact": (Pose(head_nod=12, lean=5, l_arm=(22, 34), l_fore=(-86, 72), r_arm=(22, 34), r_fore=(-86, 72),
                     l_thigh=(6, 30), l_shin=(2, -18), r_thigh=(6, 30), r_shin=(2, -18)), "both"),
    "release": (Pose(head_nod=0, lean=2, l_arm=(36, 26), l_fore=(-36, 84), r_arm=(36, 26), r_fore=(-36, 84),
                     l_thigh=(5, 12), l_shin=(4, -6), r_thigh=(5, 12), r_shin=(4, -6)), "both"),
}

# Challenge: back-break dip with the hands travelling to the hips -> proud
# señor stance (fists on hips, chest out, chin up, heel forward toe up) ->
# courteous palm-up sweep toward the floor with a head bow -> settle.

CHALLENGE = {
    "load": (Pose(yaw=8, twist=-8, lean=7, side_bend=4, pelvis_x=0.05, pelvis_roll=7, head_nod=10,
                  l_thigh=(6, 30), l_shin=(0, -18), r_thigh=(14, -16), r_shin=(12, -38),
                  l_arm=(40, -4), l_fore=(-10, 20), r_arm=(34, 6), r_fore=(6, 40)), "left"),
    "proud": (Pose(twist=8, lean=-8, side_bend=-5, pelvis_x=-0.05, pelvis_roll=-8, head_nod=-12, head_side=6,
                   head_turn=-6,
                   r_thigh=(3, 6), r_shin=(2, -3), l_thigh=(16, 26), l_shin=(18, 26), l_foot=-30,
                   **AKIMBO_L_WIDE, **AKIMBO_R), "right"),
    "offer": (Pose(twist=-16, lean=8, side_bend=-6, pelvis_x=-0.05, pelvis_roll=-6, head_turn=-18, head_nod=16,
                   r_thigh=(4, 16), r_shin=(2, -10), l_thigh=(16, 20), l_shin=(8, -14),
                   r_arm=(56, 40), r_fore=(64, 60), **AKIMBO_L), "right"),
    "return": (Pose(twist=-4, side_bend=-2, pelvis_x=-0.02, pelvis_roll=-3, pin="r",
                    r_thigh=(4, 8), r_shin=(3, -5), l_thigh=(6, 6), l_shin=(5, -4),
                    r_arm=(32, 10), r_fore=(26, 44), l_arm=(44, -14), l_fore=(-16, 10)), "both"),
}

# Approval: inhale with the chin up -> right palm to the chest with a deep
# nod and knee dip -> open palm out toward the player.

APPROVAL = {
    "load": (Pose(lean=-4, side_bend=-3, pelvis_x=-0.03, pelvis_roll=-5, head_nod=-12, head_side=4, pin="r",
                  r_thigh=(4, 6), r_shin=(3, -3), l_thigh=(8, 12), l_shin=(5, -8),
                  l_arm=(28, -12), l_fore=(30, 14), r_arm=(30, 14), r_fore=(24, 50)), "both"),
    "nod": (Pose(lean=5, twist=-6, side_bend=3, pelvis_x=-0.03, pelvis_roll=-6, head_nod=9, pin="r",
                 r_thigh=(6, 28), r_shin=(1, -16), l_thigh=(10, 30), l_shin=(4, -18),
                 r_arm=(24, 32), r_fore=(-100, 56), l_arm=(36, -16), l_fore=(44, 10)), "both"),
    "release": (Pose(lean=0, twist=8, side_bend=-3, pelvis_x=-0.04, pelvis_roll=-6, head_nod=2, head_side=-6,
                     pin="r",
                     r_thigh=(4, 8), r_shin=(3, -4), l_thigh=(10, 10), l_shin=(6, -6),
                     r_arm=(52, 34), r_fore=(70, 50), **AKIMBO_L), "both"),
}

# Reassurance: a warm head tilt -> both palms up in a small shrug, one higher,
# knees soft ("otra vez") -> a back-break step on the spot inviting the
# player to rejoin the rhythm.

REASSURANCE = {
    "notice": (Pose(twist=6, side_bend=3, pelvis_x=0.03, pelvis_roll=5, head_turn=-10, head_side=-12, pin="l",
                    l_thigh=(4, 6), l_shin=(3, -3), r_thigh=(10, 12), r_shin=(6, -8),
                    l_arm=(22, -6), l_fore=(20, 26), r_arm=(28, 10), r_fore=(34, 44)), "both"),
    "open_hand": (Pose(lean=4, side_bend=-4, pelvis_x=0.02, pelvis_roll=4, head_side=-12, head_nod=6, pin="l",
                       l_thigh=(6, 24), l_shin=(1, -14), r_thigh=(8, 26), r_shin=(3, -14),
                       l_arm=(30, 30), l_fore=(62, 56), r_arm=(44, 32), r_fore=(80, 50)), "both"),
    "settle": (Pose(yaw=10, twist=-12, lean=5, side_bend=5, pelvis_x=0.06, pelvis_roll=8, head_side=-4,
                    l_thigh=(6, 28), l_shin=(0, -16), r_thigh=(14, -18), r_shin=(12, -40),
                    l_arm=(30, 30), l_fore=(30, 74), r_arm=(36, -20), r_fore=(46, 12)), "left"),
}

# Finish: the remate. Right hand travels to the hat brim with the left heel
# forward, toe up, left fist on the hip; then the brim is touched with a head
# dip and chest proud. The hat never leaves the head. Turns: heel pivot,
# lean into the turn, leading arm open at hip height.

FINISH_TURN = {
    "finish_a": (Pose(twist=-6, lean=-4, side_bend=-6, pelvis_x=-0.06, pelvis_roll=-9, head_turn=-8,
                      head_nod=-6,
                      r_thigh=(2, 8), r_shin=(2, -4), l_thigh=(18, 24), l_shin=(20, 24), l_foot=-26,
                      r_arm=(104, 24), r_fore=(-30, 62), **AKIMBO_L), "right"),
    "finish_b": (Pose(twist=-10, lean=-8, side_bend=-7, pelvis_x=-0.08, pelvis_roll=-12, head_turn=-10,
                      head_nod=8, head_side=-2,
                      r_thigh=(2, 10), r_shin=(2, -5), l_thigh=(22, 28), l_shin=(24, 28), l_foot=-30,
                      r_arm=(124, 26), r_fore=(-104, 14), **AKIMBO_L_WIDE), "right"),
    "turn_in": (Pose(yaw=28, twist=6, side_bend=6, lean=3, pelvis_x=0.04, pelvis_roll=6, pin="l",
                     head_turn=-8,
                     l_thigh=(4, 12), l_shin=(2, -8), r_thigh=(12, 20), r_shin=(6, -10), r_foot=-12,
                     l_arm=(56, 20), l_fore=(70, 30), **AKIMBO_R), "both"),
    "turn_out": (Pose(yaw=-28, twist=-6, side_bend=-6, lean=3, pelvis_x=-0.04, pelvis_roll=-6, pin="r",
                      head_turn=8,
                      r_thigh=(4, 12), r_shin=(2, -8), l_thigh=(12, 20), l_shin=(6, -10), l_foot=-12,
                      r_arm=(56, 20), r_fore=(70, 30), **AKIMBO_L), "both"),
}

OPPONENT_64 = {
    "groove": GROOVE,
    "left_hand": LEFT_HAND, "right_hand": RIGHT_HAND,
    "left_foot": LEFT_FOOT, "right_foot": RIGHT_FOOT,
    "enter_forward": ENTER_FORWARD, "retreat_backward": RETREAT_BACKWARD, "yield_side": YIELD_SIDE,
    "watch": WATCH, "clap": CLAP, "challenge": CHALLENGE, "approval": APPROVAL,
    "reassurance": REASSURANCE, "finish_turn": FINISH_TURN,
}

# ---------------------------------------------------------------- Mācron pilot
# plan/dance-fluidity-pass.md §Mācron pilot inventory. Same vocabulary, plus
# eight real turn views (front -> 3/4 -> profile -> rear 3/4 -> rear -> ...).
# He has no hat, so his proud finish keeps the arm-up remate. The turn views
# pin the midpoint between the feet so the figure spins in place.

TURN8 = {}
for i, name in enumerate(["front", "front_3q", "profile", "rear_3q", "rear",
                          "rear_3q_opp", "profile_opp", "front_3q_opp"]):
    yaw = [0, 45, 90, 135, 180, 225, 270, 315][i]
    TURN8[name] = (Pose(yaw=yaw, pin="mid", l_arm=(60, 0), l_fore=(80, 10), r_arm=(60, 0), r_fore=(80, 10),
                        l_thigh=(4, 6), l_shin=(4, -4), r_thigh=(10, 14), r_shin=(6, -6)), "left")

MACRON_FINISH = {
    "finish_a": (Pose(side_bend=12, pelvis_x=-0.05, pelvis_roll=-8, l_arm=(140, 20), l_fore=(150, 10),
                      r_arm=(50, -15), r_fore=(-40, 0), r_thigh=(3, 4), r_shin=(3, -2),
                      l_thigh=(18, 8), l_shin=(22, 2)), "right"),
    "finish_b": (Pose(side_bend=16, pelvis_x=-0.06, pelvis_roll=-11, head_nod=-8, l_arm=(150, 25),
                      l_fore=(165, 15), r_arm=(50, -15), r_fore=(-40, 0), r_thigh=(3, 6), r_shin=(3, -4),
                      l_thigh=(22, 10), l_shin=(26, 4)), "right"),
}

MACRON_PILOT = {
    "groove": OPPONENT_64["groove"],
    "left_hand": LEFT_HAND, "right_hand": RIGHT_HAND,
    "left_foot": LEFT_FOOT, "right_foot": RIGHT_FOOT,
    "turn": TURN8,
    "watch": WATCH, "clap": CLAP,
    "ingress": ENTER_FORWARD, "egress": RETREAT_BACKWARD,
    "proud_finish": MACRON_FINISH,
}

MOTION_SETS = {"opponent-64": OPPONENT_64, "macron-pilot": MACRON_PILOT}

assert sum(len(v) for v in OPPONENT_64.values()) == 64, "opponent target is 64 drawings"

# ---------------------------------------------------------------- intent
# Per-drawing intent templates: (phase, plain-English body action) with {he},
# {him} and {his} filled from the character definition. Sides are the
# character's own: facing the viewer, the character's left is on screen right.
# standin.py writes these to poses.intent.json with the clip and support foot.

OPPONENT_64_INTENT = {
    "groove.down_l": ("down (beat 1, back-step)", "weight sunk on {his} bent left knee, right foot stepped back on its ball with the heel raised, left hip high and pushed out, shoulders tilted the other way, left forearm swinging forward at belly height, right arm low and back, head level facing the viewer"),
    "groove.pass_l": ("pass (beat 2, replace)", "weight rolling forward onto the left foot, knees softening upward, right foot still slightly back on its ball, hips easing toward level, arms loose and low swinging back toward the body"),
    "groove.up_l": ("up (beat 3, close)", "both feet together and flat, legs nearly straight in a small rise, hips almost level, chin lifted proudly, arms relaxed low at the sides with elbows soft"),
    "groove.pass_l2": ("accent (beat 4, the hold)", "hip popped out to {his} right over the straight right leg, right hip high, right shoulder dipped, left knee bent with the left foot resting on its toe, right forearm lifted out at hip height in a wrist roll, left forearm across the belly, head tilted toward {his} left"),
    "groove.down_r": ("down (beat 1, back-step)", "weight sunk on {his} bent right knee, left foot stepped back on its ball with the heel raised, right hip high and pushed out, shoulders tilted the other way, right forearm swinging forward at belly height, left arm low and back, head level facing the viewer"),
    "groove.pass_r": ("pass (beat 2, replace)", "weight rolling forward onto the right foot, knees softening upward, left foot still slightly back on its ball, hips easing toward level, arms loose and low swinging back toward the body"),
    "groove.up_r": ("up (beat 3, close)", "both feet together and flat, legs nearly straight in a small rise, hips almost level, chin lifted proudly, arms relaxed low at the sides with elbows soft"),
    "groove.pass_r2": ("accent (beat 4, the hold)", "hip popped out to {his} left over the straight left leg, left hip high, left shoulder dipped, right knee bent with the right foot resting on its toe, left forearm lifted out at hip height in a wrist roll, right forearm across the belly, head tilted toward {his} right"),
    "left_hand.prep": ("anticipation", "crouched low with weight on the bent right leg, right fist on the hip, left hand scooped down low in front of the left hip, torso turned away to {his} right, head glancing down at the left hand"),
    "left_hand.peak": ("accent", "weight on the straight right foot, right hip pushed out, right fist on the hip, body leaning toward {his} left so one long diagonal runs from the right foot to the left palm thrust high and out at about 45 degrees, left foot on its toe out to the side, head turned up toward the raised hand"),
    "left_hand.follow": ("follow-through", "same diagonal pushed further: left arm reaching higher and the palm rolling forward, torso leaning further toward {his} left, right elbow pushed back on the hip, left toe touch out wider, head following the hand"),
    "left_hand.return": ("settle", "left arm sweeping down in an arc at shoulder height with the elbow bent, right hand low on the hip, both feet flat and close, torso returning upright"),
    "right_hand.prep": ("anticipation", "crouched low with weight on the bent left leg, left fist on the hip, right hand scooped down low in front of the right hip, torso turned away to {his} left, head glancing down at the right hand"),
    "right_hand.peak": ("accent", "weight on the straight left foot, left hip pushed out, left fist on the hip, body leaning toward {his} right so one long diagonal runs from the left foot to the right palm thrust high and out at about 45 degrees, right foot on its toe out to the side, head turned up toward the raised hand"),
    "right_hand.follow": ("follow-through", "same diagonal pushed further: right arm reaching higher and the palm rolling forward, torso leaning further toward {his} right, left elbow pushed back on the hip, right toe touch out wider, head following the hand"),
    "right_hand.return": ("settle", "right arm sweeping down in an arc at shoulder height with the elbow bent, left hand low on the hip, both feet flat and close, torso returning upright"),
    "left_foot.prep": ("anticipation", "weight on the bent right leg, left knee lifted forward and out with the foot off the floor and the toe pointing down, left fist on the hip, right arm low and out for balance, head looking down at the left foot"),
    "left_foot.peak": ("accent", "heel dig: left leg stretched out on a forward diagonal with the left heel on the floor and the toe up, weight on the bent right leg, chest proud and leaning back slightly, right fist on the hip, left arm low and back, head turned toward the left foot"),
    "left_foot.follow": ("follow-through", "left heel still dug in on the diagonal, hip popped over the right foot, shoulders tilted against the hips, right elbow pushed back on the hip, left arm low and out, head on the left foot"),
    "left_foot.return": ("settle", "left foot dragged back along the floor to close beside the right, both feet flat, knees soft, arms relaxed low at the sides"),
    "right_foot.prep": ("anticipation", "weight on the bent left leg, right knee lifted forward and out with the foot off the floor and the toe pointing down, right fist on the hip, left arm low and out for balance, head looking down at the right foot"),
    "right_foot.peak": ("accent", "heel dig: right leg stretched out on a forward diagonal with the right heel on the floor and the toe up, weight on the bent left leg, chest proud and leaning back slightly, left fist on the hip, right arm low and back, head turned toward the right foot"),
    "right_foot.follow": ("follow-through", "right heel still dug in on the diagonal, hip popped over the left foot, shoulders tilted against the hips, left elbow pushed back on the hip, right arm low and out, head on the right foot"),
    "right_foot.return": ("settle", "right foot dragged back along the floor to close beside the left, both feet flat, knees soft, arms relaxed low at the sides"),
    "enter_forward.contact_l": ("contact", "swaggering walk toward the viewer on a slight diagonal, left heel landing in front, right foot behind on its toe, right fist on the hip, left arm swinging back, chin up"),
    "enter_forward.down_l": ("down", "weight dropping into the bent left knee, left hip high, right foot pushing off behind on its toe, right fist on the hip, left arm swinging, head dipping on the beat"),
    "enter_forward.pass_l": ("pass", "standing tall on the straight left leg, right knee swinging forward past it, right fist on the hip, left arm relaxed at the side, chin up"),
    "enter_forward.contact_r": ("contact", "swaggering walk toward the viewer on a slight diagonal, right heel landing in front, left foot behind on its toe, right fist on the hip, left arm swinging forward, chin up"),
    "enter_forward.down_r": ("down", "weight dropping into the bent right knee, right hip high, left foot pushing off behind on its toe, right fist on the hip, left arm swinging forward, head dipping on the beat"),
    "enter_forward.pass_r": ("pass", "standing tall on the straight right leg, left knee swinging forward past it, right fist on the hip, left arm relaxed at the side, chin up"),
    "retreat_backward.contact_l": ("contact", "stepping backward while still facing the viewer, left foot reaching back onto its ball, weight still on the flat right foot, left hand behind the back, right arm low and loose"),
    "retreat_backward.down_l": ("down", "weight rolled back onto the bent left leg, left hip high, right foot in front with the toe lifted, left hand behind the back, right arm low and forward, head nodding"),
    "retreat_backward.pass_l": ("pass", "right foot dragged back along the floor past the straight left leg, left hand behind the back, right arm hanging loose, chin up"),
    "retreat_backward.contact_r": ("contact", "stepping backward while still facing the viewer, right foot reaching back onto its ball, weight still on the flat left foot, left hand behind the back, right arm low and loose"),
    "retreat_backward.down_r": ("down", "weight rolled back onto the bent right leg, right hip high, left foot in front with the toe lifted, left hand behind the back, right arm low, head nodding"),
    "retreat_backward.pass_r": ("pass", "left foot dragged back along the floor past the straight right leg, left hand behind the back, right arm hanging loose, chin up"),
    "yield_side.contact_l": ("contact", "side-step toward the sideline: left leg reaching out sideways with the foot landing, weight still on the bent right leg, right fist on the hip, left arm out low"),
    "yield_side.down_l": ("down", "weight shifted onto the bent left leg, left hip high and pushed out, right foot trailing on its toe, right fist on the hip, head nodding"),
    "yield_side.pass_l": ("pass", "right foot dragged in along the floor to close beside the straight left leg, right fist on the hip, left arm relaxed at the side"),
    "yield_side.contact_r": ("contact", "right foot stepping back on a diagonal onto its ball, left knee bent, arms low and loose, torso turning open"),
    "yield_side.down_r": ("down", "weight settled onto the bent right leg, right hip high, left foot in front with the toe lifted, right forearm coming forward at waist height"),
    "yield_side.pass_r": ("accent (hand-over)", "standing on the right leg, left fist on the hip, right arm held out low and wide with the palm open and up toward the empty floor, head turned toward the open palm with a slight bow, offering the floor"),
    "watch.shift_l": ("pass (weight shift)", "relaxed stance turned slightly to {his} left, hands clasped behind the back, weight on the left foot with the left hip high, right knee soft, head turned to watch the other dancer"),
    "watch.hold_l": ("settle (nod on beat 1)", "hands clasped behind the back, weight sunk on the left foot with both knees softer, head nodding along to the music while watching"),
    "watch.shift_r": ("pass (weight shift)", "relaxed stance turned slightly to {his} left, hands clasped behind the back, weight on the right foot with the right hip high, left knee soft, head turned to watch the other dancer"),
    "watch.hold_r": ("settle", "hands clasped behind the back, weight sunk on the right foot with both knees softer, head tilted with a small nod while watching"),
    "clap.open": ("anticipation", "standing square and upright, both forearms raised in front of the chest with the palms apart and facing each other, elbows out, chin up"),
    "clap.close": ("pass", "both hands swinging together in front of the chest, elbows out, knees starting to bend, head starting to nod"),
    "clap.contact": ("contact (on the beat)", "palms clapped together in front of the chest, elbows out to the sides, both knees dipped, head nodding down with a smile"),
    "clap.release": ("follow-through", "hands bouncing apart in front of the chest, elbows out, knees rising, head level"),
    "challenge.load": ("anticipation", "back-break dip: weight sunk on the bent left leg, right foot back on its ball, torso leaning forward, both hands travelling toward the hips, head lowered"),
    "challenge.proud": ("accent", "proud stance: both fists on the hips with the elbows out, chest pushed out and leaning back, chin raised, weight on the straight right leg, left heel set forward with the toe up"),
    "challenge.offer": ("accent (invitation)", "courteous invitation: weight on the right leg, left fist on the hip, right arm sweeping out low and forward with the palm open and up toward the floor, torso bowing slightly forward, head bowed toward the open hand"),
    "challenge.return": ("settle", "both feet flat, standing easy, right forearm relaxed in front, left hand low near the hip, body upright"),
    "approval.load": ("anticipation", "small inhale: chest lifted and leaning back slightly, chin raised, weight on the right foot, arms loose and slightly away from the body"),
    "approval.nod": ("accent", "right palm pressed flat to the chest, a deep nod with the head bowed, both knees dipped, left arm low and out at the side"),
    "approval.release": ("settle", "left fist on the hip, right arm held out forward at waist height with the palm open toward the viewer, head tilted warmly"),
    "reassurance.notice": ("anticipation", "head tilted to {his} right with a soft warm look, weight on the left foot, arms relaxed low, right forearm slightly forward"),
    "reassurance.open_hand": ("accent", "small friendly shrug: both forearms out at waist height with the palms open and up, the right hand a little higher, both knees softly bent, head tilted"),
    "reassurance.settle": ("settle (invitation)", "a back-break step on the spot: weight on the bent left knee, right foot back on its ball, left forearm forward, right arm low and back, inviting the rhythm back"),
    "finish_turn.finish_a": ("anticipation (remate)", "weight on the straight right leg, left heel set forward with the toe up, left fist on the hip, right hand rising beside the head on its way to the hat brim, chest proud, chin up"),
    "finish_turn.finish_b": ("accent (remate)", "right fingertips touching the front of the hat brim in a courteous salute, the hat still on {his} head, head dipped slightly, chest proud, left elbow out with the fist on the hip, left heel forward with the toe up"),
    "finish_turn.turn_in": ("pass (turn)", "body turned about 30 degrees toward {his} left on a heel pivot, leaning into the turn, left arm open out to the side at hip height, right fist on the hip"),
    "finish_turn.turn_out": ("pass (turn)", "body turned about 30 degrees toward {his} right on a heel pivot, leaning into the turn, right arm open out to the side at hip height, left fist on the hip"),
}

INTENT_BY_SET = {"opponent-64": OPPONENT_64_INTENT}

assert set(OPPONENT_64_INTENT) == {f"{c}.{n}" for c, d in OPPONENT_64.items() for n in d}, "intent ids != pose ids"


def intent_text(template: str, pronouns: list[str]) -> str:
    """Fill {he}/{him}/{his}; templates are authored pronoun-neutral."""
    return template.format(he=pronouns[0], him=pronouns[1], his=pronouns[2])


def apply_overrides(clips: dict, overrides: dict) -> dict:
    """A character's motion overrides: {pose id: {"pose": {param: value}}}. Lists become tuples."""
    out = {c: dict(d) for c, d in clips.items()}
    for pid, ov in overrides.items():
        clip, name = pid.split(".", 1)
        if clip not in out or name not in out[clip]:
            raise KeyError(f"motion.overrides.{pid}: unknown pose")
        if "pose" in ov:
            params = {k: (tuple(v) if isinstance(v, list) else v) for k, v in ov["pose"].items()}
            pose, sup = out[clip][name]
            out[clip][name] = (replace(pose, **params), sup)
    return out
