"""Motion set opponent-samba: Tía Purpurina, the terrace's opponent (plan/levels/mansion-act-two-2026-11-08.md, section 9).

Imported at the end of poses.py, which registers it in MOTION_SETS and INTENT_BY_SET. Kept in its own file so
the shared table stays small and other sets can land beside it without touching the same lines.

The 64 shared drawing names, so every shared choreography table plays her, with the groove redrawn as samba no pé,
the ball-change step on the spot, per side over one beat: a flat step down on 1 with the hips dropped, a quick
ball change behind on "e", the same foot again on "and", and on "a" the hip rolled out high over the straight leg
with the free foot flicked out on its toe. That last drawing lands where the chart's hip-hand sits (the beat's last
sixteenth). Samba arms throughout: elbows out, forearms loose at the waist, hands flicking. Then an eight-view spin
with the boa flying, her charisma (boa twirl, a laugh with the head thrown back, a blown kiss), and the win's
confetti, which LA LLUVIA DE CONFETI also loops.
"""
from __future__ import annotations

from dataclasses import replace

from poses import (AKIMBO_L, AKIMBO_R, OPPONENT_64, OPPONENT_64_INTENT, Pose, _SPIN_NAMES, mirror_clip, ordered)

_ARMS_LOW = dict(l_arm=(62, 24), l_fore=(30, 56), r_arm=(62, 24), r_fore=(30, 56))  # samba arms: elbows out, forearms forward at the waist

_SB_DOWN_L = Pose(twist=-6, lean=2, side_bend=5, pelvis_x=0.06, pelvis_roll=9, head_side=-4, head_nod=-4, pin="l",
                  both_home=False, l_thigh=(6, 16), l_shin=(4, -16), r_thigh=(10, -10), r_shin=(8, -34), r_foot=30,
                  **_ARMS_LOW)
_SB_BALL_L = Pose(twist=4, lean=0, side_bend=-2, pelvis_x=-0.02, pelvis_roll=-4, head_side=2, head_nod=-2, pin="l",
                  both_home=False, l_thigh=(8, 10), l_shin=(6, -10), r_thigh=(6, -6), r_shin=(4, -12), r_foot=30,
                  l_arm=(56, 34), l_fore=(14, 72), r_arm=(76, 10), r_fore=(70, 30))
_SB_STEP_L = Pose(twist=-4, lean=1, side_bend=4, pelvis_x=0.05, pelvis_roll=7, head_side=-2, head_nod=-6, pin="l",
                  both_home=False, l_thigh=(6, 14), l_shin=(4, -14), r_thigh=(10, -10), r_shin=(8, -34), r_foot=24,
                  l_arm=(76, 10), l_fore=(70, 30), r_arm=(56, 34), r_fore=(14, 72))
_SB_HIP_L = Pose(twist=-8, lean=-4, side_bend=10, pelvis_x=0.09, pelvis_roll=14, head_turn=10, head_side=6, head_nod=-10,
                 pin="l", l_thigh=(4, 4), l_shin=(4, -3), r_thigh=(26, 6), r_shin=(22, -4), r_foot=40,
                 **AKIMBO_L, r_arm=(122, 10), r_fore=(142, 8))
SAMBA_GROOVE = {"down_l": (_SB_DOWN_L, "left"), "pass_l": (_SB_BALL_L, "both"),
                "up_l": (_SB_STEP_L, "left"), "pass_l2": (_SB_HIP_L, "left")}
SAMBA_GROOVE |= mirror_clip(SAMBA_GROOVE, {"down_l": "down_r", "pass_l": "pass_r", "up_l": "up_r", "pass_l2": "pass_r2"})
SAMBA_GROOVE = ordered(SAMBA_GROOVE, ["down_l", "pass_l", "up_l", "pass_l2", "down_r", "pass_r", "up_r", "pass_r2"])

# The spin: arms up and open, the boa flying out, about the feet.
SPIN_BOA = {name: (Pose(yaw=45 * i, pin="mid", head_nod=-8, l_arm=(118, 10), l_fore=(132, 10), r_arm=(104, 10),
                        r_fore=(120, 10), l_thigh=(4, 6), l_shin=(4, -4), r_thigh=(10, 18), r_shin=(6, -10)), "both")
            for i, name in enumerate(_SPIN_NAMES)}

_EASY_R = dict(side_bend=-4, pelvis_x=-0.05, pelvis_roll=-8, pin="r",
               r_thigh=(4, 4), r_shin=(3, -2), l_thigh=(12, 12), l_shin=(8, -6))
_EASY_L = dict(side_bend=4, pelvis_x=0.05, pelvis_roll=8, pin="l",
               l_thigh=(4, 4), l_shin=(3, -2), r_thigh=(12, 12), r_shin=(8, -6))
BOA = {
    # Both hands on the boa's ends: one high over the head, one low, the boa looping round behind her shoulders.
    "a": (Pose(twist=6, head_turn=-8, head_nod=-8, **_EASY_R, l_arm=(150, 10), l_fore=(164, 4),
               r_arm=(40, 20), r_fore=(52, 30)), "both"),
    "b": (Pose(twist=-8, head_turn=10, head_nod=-10, **_EASY_L, r_arm=(150, 10), r_fore=(164, 4),
               l_arm=(40, 20), l_fore=(52, 30)), "both"),
}
LAUGH = {
    # The laugh you can see: the head thrown back, a hand on the chest, then both hands on the belly, shoulders up.
    "a": (Pose(lean=-8, head_nod=-26, head_side=4, **_EASY_R, r_arm=(24, 34), r_fore=(-96, 52),
               l_arm=(40, 10), l_fore=(70, 16)), "both"),
    "b": (Pose(lean=-12, head_nod=-30, head_side=-4, side_bend=-3, pelvis_x=-0.04, pelvis_roll=-6, pin="r",
               r_thigh=(4, 4), r_shin=(3, -2), l_thigh=(16, 18), l_shin=(12, -10), l_foot=30,
               l_arm=(24, 26), l_fore=(-60, 50), r_arm=(24, 26), r_fore=(-60, 50)), "right"),
}
KISS = {
    # A kiss blown toward the picture's right, where Mācron is: fingertips at the lips, then the hand flung out.
    "a": (Pose(yaw=14, head_nod=-4, head_turn=8, **_EASY_R, **AKIMBO_L, r_arm=(26, 40), r_fore=(-150, 40)), "both"),
    "b": (Pose(yaw=20, lean=6, head_nod=2, head_turn=12, **_EASY_R, **AKIMBO_L, r_arm=(84, 30), r_fore=(92, 34)), "both"),
}
CONFETTI = {
    # The throw: both hands scooped low by the left hip full of confetti, then flung up high and wide.
    "a": (Pose(twist=-10, lean=6, side_bend=6, pelvis_x=0.05, pelvis_roll=8, head_nod=8, head_turn=-6, pin="l",
               both_home=False, l_thigh=(6, 14), l_shin=(4, -14), r_thigh=(10, -10), r_shin=(8, -34), r_foot=24,
               l_arm=(30, 10), l_fore=(20, 30), r_arm=(30, 30), r_fore=(-20, 50)), "left"),
    "b": (Pose(lean=-8, head_nod=-16, pin="mid", l_thigh=(8, 6), l_shin=(5, -4), r_thigh=(8, 6), r_shin=(5, -4),
               l_arm=(140, 10), l_fore=(156, 6), r_arm=(140, 10), r_fore=(156, 6)), "both"),
}

OPPONENT_SAMBA = {**OPPONENT_64, "groove": SAMBA_GROOVE, "spin": SPIN_BOA, "boa": BOA, "laugh": LAUGH, "kiss": KISS,
                  "confetti": CONFETTI}
OPPONENT_SAMBA = {c: OPPONENT_SAMBA[c] for c in [*OPPONENT_64, "spin", "boa", "laugh", "kiss", "confetti"]}
# Her shorter legs put the trailing foot of the shared side-step a few pixels under the floor: bend that knee a little more.
OPPONENT_SAMBA["yield_side"] = {**OPPONENT_SAMBA["yield_side"],
                                "pass_l": (replace(OPPONENT_SAMBA["yield_side"]["pass_l"][0], r_thigh=(6, 8), r_shin=(4, -22)), "left")}

_SB = "samba no pé: "
_ARMS = "samba arms with the elbows out and both forearms loose at waist height, the hands flicking"
SAMBA_INTENT = {
    "groove.down_l": ("down (count 1, step)", _SB + "a quick flat step down onto the bent left leg, the right foot just behind on its toe with the heel raised, hips dropped and swung out to {his} left, " + _ARMS + ", head bobbing, a big joyful open-mouthed smile"),
    "groove.pass_l": ("pass (count e, ball change)", _SB + "a quick ball change, the right foot tucked just behind the left on its ball, both knees springy and bent, hips swinging back through the middle, the left forearm flicked up in front of the chest and the right forearm out to the side, a big joyful smile"),
    "groove.up_l": ("up (count and, step)", _SB + "stepping down onto the bent left leg again, the right foot just behind on its toe, hips swinging to {his} left, the right forearm flicked up in front of the chest and the left forearm out to the side, head bobbing, a big joyful smile"),
    "groove.pass_l2": ("accent (count a, the hip)", _SB + "the hip rolled out high to {his} left over the straight left leg, the right foot flicked out to the side on its toe, the left fist on the hip, the right arm raised high in a flourish, shoulders shimmying, head tilted back, laughing"),
    "groove.down_r": ("down (count 1, step)", _SB + "a quick flat step down onto the bent right leg, the left foot just behind on its toe with the heel raised, hips dropped and swung out to {his} right, " + _ARMS + ", head bobbing, a big joyful open-mouthed smile"),
    "groove.pass_r": ("pass (count e, ball change)", _SB + "a quick ball change, the left foot tucked just behind the right on its ball, both knees springy and bent, hips swinging back through the middle, the right forearm flicked up in front of the chest and the left forearm out to the side, a big joyful smile"),
    "groove.up_r": ("up (count and, step)", _SB + "stepping down onto the bent right leg again, the left foot just behind on its toe, hips swinging to {his} right, the left forearm flicked up in front of the chest and the right forearm out to the side, head bobbing, a big joyful smile"),
    "groove.pass_r2": ("accent (count a, the hip)", _SB + "the hip rolled out high to {his} right over the straight right leg, the left foot flicked out to the side on its toe, the right fist on the hip, the left arm raised high in a flourish, shoulders shimmying, head tilted back, laughing"),
    "finish_turn.finish_a": ("anticipation (remate)", "weight on the straight right leg, left heel set forward with the toe up, left fist on the hip, the right hand rising to the big curls beside {his} head, chest proud, chin up"),
    "finish_turn.finish_b": ("accent (remate)", "the right hand fluffing the big curls at {his} temple with a flourish, head tilted, chest proud, left elbow out with the fist on the hip, left heel forward with the toe up, a delighted grin"),
    "boa.a": ("anticipation (charisma)", "standing easy on the right leg, twirling the feather boa: the left hand on the left of the picture held high above the head holding one end of the boa, the right hand low by the hip holding the other end, the boa looping round behind her shoulders, head tilted, a playful grin"),
    "boa.b": ("accent (charisma)", "standing easy on the left leg, twirling the feather boa the other way: the right hand on the right of the picture held high above the head holding one end of the boa, the left hand low by the hip holding the other end, the boa swinging out in a wide loop, head tilted, laughing"),
    "laugh.a": ("anticipation (charisma)", "a big laugh: leaning back with the head thrown back, mouth wide open laughing and eyes squeezed shut, the right hand pressed flat on the chest, the left arm loose at the side, shoulders up"),
    "laugh.b": ("accent (charisma)", "a big belly laugh: leaning back with the head thrown right back, mouth wide open laughing and eyes squeezed shut, both hands on the belly, shoulders shaking, the left foot lifted off the floor with the toe pointed"),
    "kiss.a": ("anticipation (charisma)", "turned a little toward the right of the picture, the left fist on the hip, the right fingertips pressed to the puckered lips, eyes twinkling, about to blow a kiss"),
    "kiss.b": ("accent (charisma)", "turned a little toward the right of the picture, blowing a kiss: the right arm flung out toward the right of the picture at shoulder height with the palm open and up, lips puckered, the left fist on the hip, a wink"),
    "confetti.a": ("anticipation (confetti)", "a samba step onto the bent left leg, leaning forward, both hands cupped together low beside the left hip holding a big handful of colourful paper confetti, looking down at it with a cheeky grin"),
    "confetti.b": ("accent (confetti)", "throwing confetti: both arms flung up high and wide above the head, a shower of colourful paper confetti bursting from both open hands into the air, leaning back, head thrown back, mouth wide open laughing"),
}
_SPIN_BOA_WORDS = {
    "front": "facing the viewer in the middle of a joyful spin on the spot, both arms raised high and open, the feather boa flying out",
    "34_r": "turned three-quarters toward the right of the picture, spinning on the spot, both arms raised, the feather boa flying out",
    "side_r": "in profile facing the right of the picture, spinning on the spot, both arms raised, the feather boa flying out",
    "back34_r": "turned mostly away from the viewer, the face hidden, spinning on the spot, the back of the big curly hair showing, both arms raised",
    "back": "seen from directly behind in the middle of a spin, only the back of {his} big curly hair and the back of the gold dress showing, both arms raised, the feather boa round the shoulders",
    "back34_l": "turned mostly away from the viewer, the face hidden, spinning on the spot, the back of the big curly hair showing, both arms raised",
    "side_l": "in profile facing the left of the picture, spinning on the spot, both arms raised, the feather boa flying out",
    "34_l": "turned three-quarters toward the left of the picture, coming back round to the viewer, both arms raised high and open, laughing",
}
SAMBA_INTENT |= {f"spin.{k}": ("pass (spin)", v) for k, v in _SPIN_BOA_WORDS.items()}
OPPONENT_SAMBA_INTENT = {**OPPONENT_64_INTENT, **SAMBA_INTENT}
assert set(OPPONENT_SAMBA_INTENT) == {f"{c}.{n}" for c, d in OPPONENT_SAMBA.items() for n in d}, "intent ids != pose ids"
