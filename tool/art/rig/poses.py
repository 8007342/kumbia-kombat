"""Hand-keyed pose vocabulary for the Blender stand-ins.

Angles are absolute segment directions in degrees (see standin.seg_dir):
  arm/fore/thigh/shin = (abd, flex)
  abd  0 = hanging down, 90 = horizontal outward, 180 = straight up,
       negative = crossing inward toward the body's midline.
  flex positive = toward the viewer (character's forward, -Y).
Body: yaw turns the whole character (0 = facing camera), twist turns the torso
over the hips, lean tips the torso forward, side_bend toward the character's
left, pelvis_x shifts weight toward the character's left (+X).

Each drawing is (Pose, support) where support names the planted foot:
"left", "right" or "both". The renderer plants that ankle on the ground line,
so a weight shift lowers the body instead of sliding it.

`mirror()` swaps left and right in the rig. That is fine for Mācron too: the
render still puts his cuff on the anatomical right arm. Only image mirroring is
forbidden.

Clip names and drawing names for the Gatekeeper match
tool/art/families/gatekeeper-v3.json (14 clips, 64 drawings).
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
    toe_out: float = 12


REST = Pose()


def mirror(p: Pose) -> Pose:
    return replace(
        p, yaw=-p.yaw, twist=-p.twist, side_bend=-p.side_bend, pelvis_x=-p.pelvis_x,
        head_turn=-p.head_turn, head_side=-p.head_side,
        l_arm=p.r_arm, r_arm=p.l_arm, l_fore=p.r_fore, r_fore=p.l_fore,
        l_thigh=p.r_thigh, r_thigh=p.l_thigh, l_shin=p.r_shin, r_shin=p.l_shin,
    )


SWAP = {"left": "right", "right": "left", "both": "both"}


def mirror_clip(clip: dict, rename: dict[str, str] | None = None) -> dict:
    out = {}
    for name, (pose, sup) in clip.items():
        out[(rename or {}).get(name, name)] = (mirror(pose), SWAP[sup])
    return out


# ---------------------------------------------------------------- groove
# Cumbia-flavoured side groove: weight settles into a bent-knee "down" over the
# support leg, passes through centre, rises, then repeats on the other side.
# Arms swing loosely in opposition; hips lead the shoulders slightly.

DOWN_L = Pose(pelvis_x=0.07, side_bend=-4, twist=6, head_side=3,
              l_thigh=(2, 14), l_shin=(2, -8),
              r_thigh=(14, 22), r_shin=(6, -14),
              l_arm=(22, -12), l_fore=(30, 40), r_arm=(18, 18), r_fore=(-10, 70))
PASS_L = Pose(pelvis_x=0.03, twist=3,
              l_thigh=(3, 8), l_shin=(3, -4), r_thigh=(8, 10), r_shin=(4, -6),
              l_arm=(16, -6), l_fore=(18, 30), r_arm=(15, 10), r_fore=(0, 50))
UP_L = Pose(pelvis_x=0.01, side_bend=2, head_side=-2,
            l_thigh=(4, 0), l_shin=(4, 0), r_thigh=(6, 4), r_shin=(6, -2),
            l_arm=(14, 0), l_fore=(10, 24), r_arm=(14, 4), r_fore=(6, 34))
PASS_L2 = Pose(pelvis_x=-0.02, twist=-2,
               l_thigh=(6, 6), l_shin=(4, -4), r_thigh=(3, 4), r_shin=(3, -2),
               l_arm=(14, 6), l_fore=(4, 40), r_arm=(15, -4), r_fore=(14, 28))

GROOVE = {
    "down_l": (DOWN_L, "left"), "pass_l": (PASS_L, "left"),
    "up_l": (UP_L, "both"), "pass_l2": (PASS_L2, "right"),
}
GROOVE |= mirror_clip(GROOVE, {"down_l": "down_r", "pass_l": "pass_r", "up_l": "up_r", "pass_l2": "pass_r2"})

# ---------------------------------------------------------------- limb chains
# prep -> peak (the accent on the note) -> follow (overshoot) -> return.

LEFT_HAND = {
    "prep": (Pose(pelvis_x=-0.03, side_bend=-5, l_arm=(30, -20), l_fore=(10, 10),
                  r_thigh=(6, 10), r_shin=(4, -8), head_turn=10), "both"),
    "peak": (Pose(pelvis_x=-0.04, side_bend=6, l_arm=(155, 10), l_fore=(165, 10),
                  r_arm=(30, 0), r_fore=(-20, 60), head_turn=18, head_nod=-8), "both"),
    "follow": (Pose(pelvis_x=-0.05, side_bend=9, l_arm=(168, 0), l_fore=(195, -5),
                    r_arm=(32, 0), r_fore=(-20, 60), head_turn=22, head_nod=-10), "both"),
    "return": (Pose(pelvis_x=-0.02, side_bend=2, l_arm=(70, 15), l_fore=(40, 50),
                    head_turn=8), "both"),
}
RIGHT_HAND = mirror_clip(LEFT_HAND)

LEFT_FOOT = {
    "prep": (Pose(pelvis_x=-0.06, l_thigh=(6, 30), l_shin=(4, -10),
                  r_thigh=(2, 10), r_shin=(2, -6), l_arm=(25, -10), r_arm=(30, 10)), "right"),
    "peak": (Pose(pelvis_x=-0.07, side_bend=-6, lean=-4, l_thigh=(40, 30), l_shin=(45, 25),
                  r_thigh=(2, 12), r_shin=(2, -8), l_arm=(45, -15), l_fore=(60, 0),
                  r_arm=(50, 10), r_fore=(70, 10), head_turn=12), "right"),
    "follow": (Pose(pelvis_x=-0.07, side_bend=-8, lean=-6, l_thigh=(44, 34), l_shin=(52, 34),
                    r_thigh=(2, 14), r_shin=(2, -10), l_arm=(52, -18), l_fore=(70, -5),
                    r_arm=(55, 12), r_fore=(75, 10), head_turn=14), "right"),
    "return": (Pose(pelvis_x=-0.03, l_thigh=(10, 8), l_shin=(8, -4),
                    r_thigh=(3, 8), r_shin=(3, -6), l_arm=(20, -5), r_arm=(22, 5)), "both"),
}
RIGHT_FOOT = mirror_clip(LEFT_FOOT)

# ---------------------------------------------------------------- locomotion


def walk(yaw: float, direction: int) -> dict:
    """Six-drawing grounded walk; direction +1 toward camera, -1 away."""
    f = direction

    def step(lead: str, phase: str) -> tuple[Pose, str]:
        s = 1 if lead == "l" else -1
        lead_th = {"contact": (4, 28 * f), "down": (4, 20 * f), "pass": (4, 2 * f)}[phase]
        lead_sh = {"contact": (4, 22 * f), "down": (4, 4 * f), "pass": (4, -6 * f)}[phase]
        back_th = {"contact": (4, -18 * f), "down": (4, -10 * f), "pass": (4, 30 * f)}[phase]
        back_sh = {"contact": (4, -30 * f), "down": (4, -36 * f), "pass": (4, -10 * f)}[phase]
        arm_lead = (14, -22 * f) if phase != "pass" else (12, -4 * f)
        arm_back = (14, 22 * f) if phase != "pass" else (12, 4 * f)
        p = Pose(yaw=yaw, twist=-4 * s * f, pelvis_x=0.02 * s,
                 lean=3 * f, head_nod=-2 if phase == "down" else 0)
        if lead == "l":
            p = replace(p, l_thigh=lead_th, l_shin=lead_sh, r_thigh=back_th, r_shin=back_sh,
                        r_arm=arm_lead, l_arm=arm_back, l_fore=(8, 30), r_fore=(8, 30))
        else:
            p = replace(p, r_thigh=lead_th, r_shin=lead_sh, l_thigh=back_th, l_shin=back_sh,
                        l_arm=arm_lead, r_arm=arm_back, l_fore=(8, 30), r_fore=(8, 30))
        support = {"contact": "both", "down": ("left" if lead == "l" else "right"),
                   "pass": ("left" if lead == "l" else "right")}[phase]
        return p, support

    return {f"{ph}_{side}": step(side, ph) for side in ("l", "r") for ph in ("contact", "down", "pass")}


def ordered(d: dict, names: list[str]) -> dict:
    return {n: d[n] for n in names}


WALK_ORDER = ["contact_l", "down_l", "pass_l", "contact_r", "down_r", "pass_r"]
ENTER_FORWARD = ordered(walk(15, 1), WALK_ORDER)      # staged on a diagonal route
RETREAT_BACKWARD = ordered(walk(15, -1), WALK_ORDER)  # keeps facing the player
YIELD_SIDE = ordered(walk(35, 1), WALK_ORDER)

# ---------------------------------------------------------------- social

WATCH = {
    "shift_l": (Pose(yaw=35, pelvis_x=0.05, l_thigh=(3, 4), l_shin=(3, -2), r_thigh=(10, 14), r_shin=(4, -8),
                     l_arm=(30, -10), l_fore=(-40, 60), r_arm=(30, -10), r_fore=(-40, 60), head_turn=-15), "left"),
    "hold_l": (Pose(yaw=35, pelvis_x=0.04, l_thigh=(3, 4), l_shin=(3, -2), r_thigh=(9, 12), r_shin=(4, -6),
                    l_arm=(30, -10), l_fore=(-40, 62), r_arm=(30, -10), r_fore=(-40, 62), head_turn=-15, head_nod=4), "left"),
    "shift_r": (Pose(yaw=35, pelvis_x=-0.05, r_thigh=(3, 4), r_shin=(3, -2), l_thigh=(10, 14), l_shin=(4, -8),
                     l_arm=(30, -10), l_fore=(-40, 60), r_arm=(30, -10), r_fore=(-40, 60), head_turn=-12), "right"),
    "hold_r": (Pose(yaw=35, pelvis_x=-0.04, r_thigh=(3, 4), r_shin=(3, -2), l_thigh=(9, 12), l_shin=(4, -6),
                    l_arm=(30, -10), l_fore=(-40, 62), r_arm=(30, -10), r_fore=(-40, 62), head_turn=-12, head_nod=4), "right"),
}

CLAP = {
    "open": (Pose(l_arm=(18, 40), l_fore=(10, 80), r_arm=(18, 40), r_fore=(10, 80), head_nod=4), "both"),
    "close": (Pose(l_arm=(8, 44), l_fore=(-70, 62), r_arm=(8, 44), r_fore=(-70, 62), head_nod=6), "both"),
    "contact": (Pose(l_arm=(5, 45), l_fore=(-90, 60), r_arm=(5, 45), r_fore=(-90, 60), head_nod=8,
                     l_thigh=(4, 8), l_shin=(4, -6), r_thigh=(4, 8), r_shin=(4, -6)), "both"),
    "release": (Pose(l_arm=(14, 40), l_fore=(-30, 72), r_arm=(14, 40), r_fore=(-30, 72), head_nod=3), "both"),
}

CHALLENGE = {
    "load": (Pose(lean=-6, l_arm=(25, -15), l_fore=(10, 10), r_arm=(25, -15), r_fore=(10, 10),
                  l_thigh=(5, 12), l_shin=(5, -8), r_thigh=(5, 12), r_shin=(5, -8)), "both"),
    "proud": (Pose(lean=-8, head_nod=-10, l_arm=(50, -15), l_fore=(-40, 0), r_arm=(50, -15), r_fore=(-40, 0)), "both"),
    "offer": (Pose(twist=-10, pelvis_x=0.04, r_arm=(80, 40), r_fore=(85, 45), l_arm=(50, -15), l_fore=(-40, 0),
                   head_turn=-12, l_thigh=(3, 4), l_shin=(3, -2), r_thigh=(14, 16), r_shin=(8, -8)), "left"),
    "return": (Pose(r_arm=(30, 10), r_fore=(20, 40), l_arm=(25, -5), l_fore=(5, 30)), "both"),
}

APPROVAL = {
    "load": (Pose(head_nod=-6, l_arm=(18, 0), l_fore=(10, 30), r_arm=(18, 0), r_fore=(10, 30)), "both"),
    "nod": (Pose(head_nod=18, lean=4, l_arm=(16, 4), l_fore=(8, 34), r_arm=(40, 30), r_fore=(-10, 100),
                 l_thigh=(4, 8), l_shin=(4, -6), r_thigh=(4, 8), r_shin=(4, -6)), "both"),
    "release": (Pose(head_nod=4, l_arm=(14, 0), l_fore=(8, 24), r_arm=(16, 6), r_fore=(6, 40)), "both"),
}

REASSURANCE = {
    "notice": (Pose(head_turn=-14, head_side=-6, l_arm=(14, 0), l_fore=(8, 24), r_arm=(14, 0), r_fore=(8, 24)), "both"),
    "open_hand": (Pose(lean=5, head_side=-8, l_arm=(45, 30), l_fore=(70, 50), r_arm=(45, 30), r_fore=(70, 50),
                       l_thigh=(5, 10), l_shin=(5, -8), r_thigh=(5, 10), r_shin=(5, -8)), "both"),
    "settle": (Pose(head_nod=6, l_arm=(20, 10), l_fore=(20, 40), r_arm=(20, 10), r_fore=(20, 40)), "both"),
}

FINISH_TURN = {
    "finish_a": (Pose(side_bend=8, pelvis_x=-0.05, l_arm=(140, 20), l_fore=(150, 10), r_arm=(50, -15),
                      r_fore=(-40, 0), r_thigh=(3, 4), r_shin=(3, -2), l_thigh=(16, 8), l_shin=(20, 2)), "right"),
    "finish_b": (Pose(side_bend=10, pelvis_x=-0.06, head_nod=-8, l_arm=(150, 25), l_fore=(165, 15), r_arm=(50, -15),
                      r_fore=(-40, 0), r_thigh=(3, 6), r_shin=(3, -4), l_thigh=(18, 10), l_shin=(22, 4)), "right"),
    "turn_in": (Pose(yaw=30, twist=10, l_arm=(20, 5), l_fore=(10, 30), r_arm=(20, 5), r_fore=(10, 30)), "both"),
    "turn_out": (Pose(yaw=-30, twist=-10, l_arm=(20, 5), l_fore=(10, 30), r_arm=(20, 5), r_fore=(10, 30)), "both"),
}

GATEKEEPER = {
    "groove": ordered(GROOVE, ["down_l", "pass_l", "up_l", "pass_l2", "down_r", "pass_r", "up_r", "pass_r2"]),
    "left_hand": LEFT_HAND, "right_hand": RIGHT_HAND,
    "left_foot": LEFT_FOOT, "right_foot": RIGHT_FOOT,
    "enter_forward": ENTER_FORWARD, "retreat_backward": RETREAT_BACKWARD, "yield_side": YIELD_SIDE,
    "watch": WATCH, "clap": CLAP, "challenge": CHALLENGE, "approval": APPROVAL,
    "reassurance": REASSURANCE, "finish_turn": FINISH_TURN,
}

# ---------------------------------------------------------------- Mācron pilot
# plan/dance-fluidity-pass.md §Mācron pilot inventory. Same vocabulary, plus
# eight real turn views (front -> 3/4 -> profile -> rear 3/4 -> rear -> ...).

TURN8 = {}
for i, name in enumerate(["front", "front_3q", "profile", "rear_3q", "rear",
                          "rear_3q_opp", "profile_opp", "front_3q_opp"]):
    yaw = [0, 45, 90, 135, 180, 225, 270, 315][i]
    TURN8[name] = (Pose(yaw=yaw, l_arm=(60, 0), l_fore=(80, 10), r_arm=(60, 0), r_fore=(80, 10),
                        l_thigh=(4, 6), l_shin=(4, -4), r_thigh=(10, 14), r_shin=(6, -6)), "left")

MACRON = {
    "groove": GATEKEEPER["groove"],
    "left_hand": LEFT_HAND, "right_hand": RIGHT_HAND,
    "left_foot": LEFT_FOOT, "right_foot": RIGHT_FOOT,
    "turn": TURN8,
    "watch": WATCH, "clap": CLAP,
    "ingress": ENTER_FORWARD, "egress": RETREAT_BACKWARD,
    "proud_finish": ordered(FINISH_TURN, ["finish_a", "finish_b"]),
}

CLIPS_BY_CHARACTER = {"gatekeeper": GATEKEEPER, "macron": MACRON}

assert sum(len(v) for v in GATEKEEPER.values()) == 64, "Gatekeeper v3 target is 64 drawings"
