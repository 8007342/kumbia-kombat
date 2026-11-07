#!/usr/bin/env python3
"""Writes The Pool Player's dance with the cue into characters/pool-player.json: the pose table reads better as code.

She keeps the shared 64 names, and the legs and hips of the table. What changes is what her arms do, since one hand
holds a cue: her right hand (the picture's left), planted like a dance pole, swung as a flourish, sighted like a shot.
"""
import json
from pathlib import Path

HERE = Path(__file__).parents[1] / "characters/pool-player.json"
c = json.loads(HERE.read_text())

HOLD = dict(r_arm=[26, 10], r_fore=[44, 34])
FREE_HIP = dict(l_arm=[58, -18], l_fore=[-48, -8])
POLE = "Her right hand grips a long billiard cue that stands on the floor beside her like a dance pole."
O = {}


def pose(pid, intent, **params):
    O[pid] = {"intent": intent, "pose": params}


# Groove: the table's hips and legs, right hand on the planted cue, so the cue rocks as she sways round it.
for pid, text in {
    "groove.down_l": "weight sunk on {his} bent left knee, right foot stepped back on its ball with the heel raised, left hip high and pushed out, shoulders tilted the other way, left forearm swinging forward at belly height, head level facing the viewer",
    "groove.pass_l": "weight rolling forward onto the left foot, knees softening upward, right foot still slightly back on its ball, hips easing toward level, left arm loose and low",
    "groove.up_l": "both feet together and flat, legs nearly straight in a small rise, hips almost level, chin lifted proudly, left arm relaxed low at the side with a soft elbow",
    "groove.pass_l2": "hip popped out to {his} right over the straight right leg, right hip high, right shoulder dipped toward the cue, left knee bent with the left foot resting on its toe, left forearm across the belly, head tilted toward {his} left",
    "groove.down_r": "weight sunk on {his} bent right knee, left foot stepped back on its ball with the heel raised, right hip high and pushed out toward the cue, shoulders tilted the other way, left arm low and back, head level facing the viewer",
    "groove.pass_r": "weight rolling forward onto the right foot, knees softening upward, left foot still slightly back on its ball, hips easing toward level, left arm loose and low",
    "groove.up_r": "both feet together and flat, legs nearly straight in a small rise, hips almost level, chin lifted proudly, left arm relaxed low at the side with a soft elbow",
    "groove.pass_r2": "hip popped out to {his} left over the straight left leg, left hip high, left shoulder dipped, right knee bent with the right foot resting on its toe, left forearm lifted out at hip height in a wrist roll, head tilted toward {his} right",
}.items():
    pose(pid, text, **HOLD)

# Free-hand call: she leans away from the planted cue at arm's length, free arm thrown high.
pose("left_hand.prep", "crouched low with weight on the bent right leg, left hand scooped down low in front of the left hip, torso turned away to {his} right, head glancing down at the left hand", r_arm=[30, 12], r_fore=[50, 30])
pose("left_hand.peak", "leaning far away from the planted cue with the right arm stretched straight out to hold it, like a dancer swinging out from a pole, one long diagonal from the cue hand through the chest to the left palm thrust high and out at about 45 degrees, left foot on its toe out to the side, head turned up toward the raised hand", r_arm=[62, 8], r_fore=[66, 12])
pose("left_hand.follow", "same lean pushed further: right arm straight, hanging out from the planted cue, left arm reaching higher and the palm rolling forward, left toe touch out wider, head following the hand", r_arm=[68, 8], r_fore=[70, 12])
pose("left_hand.return", "left arm sweeping down in an arc at shoulder height with the elbow bent, right hand on the planted cue, both feet flat and close, torso returning upright", r_arm=[32, 10], r_fore=[46, 30])

# Cue-hand call: the twirl, an arc round the hand across four drawings.
pose("right_hand.prep", "crouched low with weight on the bent left leg, left fist on the hip, right hand low in front of the right hip holding the cue near its butt, the cue slanting up and out across the picture, torso turned away to {his} left, head glancing at the cue", r_arm=[36, 26], r_fore=[34, 60])
pose("right_hand.peak", "weight on the straight left foot, left fist on the hip, body leaning toward {his} right, right arm thrust high and out holding the cue near its butt, the long cue swung up over {his} head and slanting across the top of the picture, right foot on its toe out to the side, head turned up toward the cue", r_arm=[122, 14], r_fore=[132, 10])
pose("right_hand.follow", "right arm high, the cue swung further round so that it lies nearly level above {his} head, torso leaning further toward {his} right, left elbow pushed back on the hip, right toe touch out wider, head following the cue", r_arm=[130, 16], r_fore=[150, 16])
pose("right_hand.return", "the right arm coming down with the elbow bent, the cue swinging back upright beside {him} with its butt nearing the floor, left hand low on the hip, both feet flat and close, torso returning upright", r_arm=[38, 12], r_fore=[50, 34])

# Foot calls: the feet speak; the cue stays planted and steadies her.
pose("left_foot.prep", "weight on the bent right leg, left knee lifted forward and out with the foot off the floor and the toe pointing down, left fist on the hip, head looking down at the left foot", **HOLD)
pose("left_foot.peak", "heel dig: left leg stretched out on a forward diagonal with the left heel on the floor and the toe up, weight on the bent right leg, chest proud and leaning back slightly, left arm low and back, head turned toward the left foot", **HOLD)
pose("left_foot.follow", "left heel still dug in on the diagonal, hip popped over the right foot, shoulders tilted against the hips, left arm low and out, head on the left foot", **HOLD)
pose("left_foot.return", "left foot dragged back along the floor to close beside the right, both feet flat, knees soft, left arm relaxed low at the side", **HOLD)
pose("right_foot.prep", "weight on the bent left leg, right knee lifted forward and out with the foot off the floor and the toe pointing down, left fist on the hip, head looking down at the right foot", r_arm=[40, 10], r_fore=[50, 30])
pose("right_foot.peak", "heel dig: right leg stretched out on a forward diagonal with the right heel on the floor and the toe up, weight on the bent left leg, chest proud and leaning back slightly, left fist on the hip, head turned toward the right foot", r_arm=[46, 10], r_fore=[56, 26])
pose("right_foot.follow", "right heel still dug in on the diagonal, hip popped over the left foot, shoulders tilted against the hips, left elbow pushed back on the hip, head on the right foot", r_arm=[46, 10], r_fore=[56, 26])
pose("right_foot.return", "right foot dragged back along the floor to close beside the left, both feet flat, knees soft, left arm relaxed low at the side", **HOLD)

# Watching: both hands stacked on the planted cue in front of her, leaning on it, patient.
STACK_R = dict(r_arm=[10, 40], r_fore=[-30, 62])
STACK_L = dict(l_arm=[12, 44], l_fore=[-105, 58])
pose("watch.shift_l", "relaxed stance turned slightly to {his} left, both hands stacked one over the other on the upright cue in front of {his} chest, leaning on it, weight on the left foot with the left hip high, right knee soft, head turned to watch the other dancer", **STACK_R, **STACK_L)
pose("watch.hold_l", "both hands stacked on the upright cue, weight sunk on the left foot with both knees softer, head nodding along to the music while watching", **STACK_R, **STACK_L)
pose("watch.shift_r", "relaxed stance turned slightly to {his} left, both hands stacked one over the other on the upright cue in front of {his} chest, leaning on it, weight on the right foot with the right hip high, left knee soft, head turned to watch the other dancer", **STACK_R, **STACK_L)
pose("watch.hold_r", "both hands stacked on the upright cue, weight sunk on the right foot with both knees softer, head tilted with a small nod while watching", **STACK_R, **STACK_L)

# Clap: the free palm slaps the shaft of the upright cue, held in front of her chest.
CENTRE = dict(r_arm=[18, 36], r_fore=[-44, 70])
pose("clap.open", "standing square and upright, the cue upright in {his} right hand in front of {his} chest, left forearm raised with the palm open and away from the cue, elbows out, chin up", **CENTRE, l_arm=[40, 26], l_fore=[10, 96])
pose("clap.close", "the left palm swinging in toward the upright cue held in front of {his} chest, elbows out, knees starting to bend, head starting to nod", **CENTRE, l_arm=[26, 34], l_fore=[-70, 84])
pose("clap.contact", "left palm slapped against the shaft of the upright cue just above the right hand, in front of the chest, elbows out to the sides, both knees dipped, head nodding down with a smile", **CENTRE, l_arm=[20, 34], l_fore=[-108, 70])
pose("clap.release", "the left palm bouncing away from the upright cue, elbows out, knees rising, head level", **CENTRE, l_arm=[36, 26], l_fore=[-30, 84])

# Challenge: chalks up, stands proud on the cue, sights down it at the player, settles ready.
pose("challenge.load", "back-break dip: weight sunk on the bent left leg, right foot back on its ball, torso leaning forward a little, the right hand low at the hip holding the cue slanted up across {his} body so its tip comes to just below {his} chin, the left hand twisting a small blue cube of chalk on the tip, a sly look down at the tip", r_arm=[24, 20], r_fore=[20, 60], l_arm=[34, 52], l_fore=[-132, 64])
pose("challenge.proud", "proud stance: left fist on the hip with the elbow out, right hand on the planted cue, chest pushed out and leaning back, chin raised, weight on the straight right leg, left heel set forward with the toe up", r_arm=[30, 10], r_fore=[50, 30], l_arm=[68, -26], l_fore=[-40, -14])
pose("challenge.offer", "bent far forward at the hips taking a shot on an imaginary table, turned toward the right of the picture, the cue level and pointing to the right of the picture, the left hand forward on the shaft as a bridge, the right hand back near the hip on the butt of the cue, {his} chin just above the cue, sighting along it with one eye narrowed, feet apart, back leg straight", yaw=35, twist=0, lean=52, side_bend=0, pelvis_roll=0, head_turn=0, head_nod=-34, head_side=0, l_thigh=[8, 26], l_shin=[4, -10], r_thigh=[14, -14], r_shin=[12, -20], r_arm=[16, -40], r_fore=[4, 44], l_arm=[40, 70], l_fore=[18, 84], pelvis_x=-0.08, pin="r")
pose("challenge.return", "both feet flat, standing easy, right hand on the planted cue, left hand low near the hip, body upright, ready", **HOLD)

pose("approval.load", "small inhale: chest lifted and leaning back slightly, chin raised, weight on the right foot, right hand on the planted cue, left arm loose and slightly away from the body", **HOLD)
pose("approval.nod", "left palm pressed flat to the chest, a deep nod with the head bowed, both knees dipped, right hand on the planted cue", **HOLD, l_arm=[24, 32], l_fore=[-100, 56])
pose("approval.release", "left arm held out forward at waist height with the palm open toward the viewer, right hand on the planted cue, head tilted warmly", **HOLD, l_arm=[52, 34], l_fore=[70, 50])

pose("reassurance.notice", "head tilted to {his} right with a soft warm look, weight on the left foot, right hand on the planted cue, left arm relaxed low", **HOLD)
pose("reassurance.open_hand", "small friendly shrug: left forearm out at waist height with the palm open and up, right hand on the planted cue, both knees softly bent, head tilted", **HOLD)
pose("reassurance.settle", "a back-break step on the spot: weight on the bent left knee, right foot back on its ball, left forearm forward, right hand on the planted cue, inviting the rhythm back", **HOLD)

# Finish: a salute with the cue, then the stick held out at arm's length, upright. No hat.
pose("finish_turn.finish_a", "weight on the straight right leg, left heel set forward with the toe up, left fist on the hip, the right hand lifting the cue up off the floor and rising to the shoulder, chest proud, chin up", r_arm=[40, 20], r_fore=[-6, 90], **FREE_HIP)
pose("finish_turn.finish_b", "the cue held straight up in front of {his} face in the right hand like a fencer's salute, its tip above {his} head, head dipped slightly, chest proud, left elbow out with the fist on the hip, left heel forward with the toe up", r_arm=[24, 36], r_fore=[-96, 96], l_arm=[68, -26], l_fore=[-40, -14])
# Turns: she pivots round the planted cue with it as her partner.
pose("finish_turn.turn_in", "body turned about 30 degrees toward {his} left on a heel pivot, circling the planted cue as a partner, right arm stretched to it behind {him}, left arm open out to the side at hip height", r_arm=[50, -10], r_fore=[58, 0])
pose("finish_turn.turn_out", "body turned about 30 degrees toward {his} right on a heel pivot, swinging in round the planted cue as a partner, chest close to it, right hand on it at shoulder height, left fist on the hip", r_arm=[40, 26], r_fore=[50, 60], **FREE_HIP)

# Walks: carried, tip up, butt off the floor. Arrival and leaving aren't a dance call.
WALK = "She carries a long billiard cue upright in her right hand, its butt just clear of the floor."
for clip in ("enter_forward", "yield_side"):
    for n, text in {
        "contact_l": "walk toward the viewer on a slight diagonal, left heel landing in front, right foot behind on its toe, chin up, left arm swinging back",
        "down_l": "walk, weight settling on the bent left knee, right foot passing behind, left arm low",
        "pass_l": "walk, rising over the straight left leg, right knee passing forward, left arm low",
        "contact_r": "walk, right heel landing in front, left foot behind on its toe, left arm swinging forward",
        "down_r": "walk, weight settling on the bent right knee, left foot passing behind, left arm low",
        "pass_r": "walk, rising over the straight right leg, left knee passing forward, left arm low",
    }.items():
        pose(f"{clip}.{n}", text if clip == "enter_forward" else text.replace("toward the viewer on a slight diagonal", "sideways out of the way"), r_arm=[20, 14], r_fore=[28, 34], l_arm=[20, 0 if "back" not in text else -20], l_fore=[16, 20])
pose("yield_side.pass_r", "standing on the right leg, the cue upright in {his} right hand beside {him}, left arm held out low and wide with the palm open and up toward the empty floor, head turned toward the open palm with a slight bow, offering the floor", r_arm=[20, 14], r_fore=[28, 34], l_arm=[44, 16], l_fore=[70, 40])

c["motion"]["overrides"] = O
c["motion"]["set"] = "opponent-cue"
P = {"mode": "planted", "hand": "r", "butt": [-0.42, -0.05], "words": POLE}
LEVEL = "Both hands are on the cue, taking aim."
CARRY = {"mode": "held", "hand": "r", "dir": [0, 0, 1], "grip": 0.5, "words": WALK}
c["drawing"]["cue"] = {
    "length": 1.6,
    "default": {"mode": "planted", "hand": "r", "butt": [-0.42, -0.05]},
    "clips": {
        "groove": P,
        "left_hand": {**P, "butt": [-0.38, -0.05]},
        "left_foot": P, "right_foot": P,
        "enter_forward": CARRY, "yield_side": CARRY,
        "watch": {"mode": "planted", "hand": "r", "butt": [0.08, -0.32], "otherHand": 50, "words": "A long billiard cue stands on the floor in front of her, and she leans on it with both hands."},
        "clap": {"mode": "held", "hand": "r", "dir": [0, 0, 1], "grip": 0.42, "words": "She holds a long billiard cue upright in her right hand."},
        "challenge": P, "approval": P, "reassurance": P,
        "right_hand": {"mode": "held", "hand": "r", "dir": [0.6, 0, 0.8], "grip": 0.22, "words": "She swings a long billiard cue in her right hand, gripped near its butt, the one cue in the picture."},
        "finish_turn": P,
        "spin": {"mode": "held", "hand": "r", "dir": [0, 0, 1], "grip": 0.5, "words": "She carries one long billiard cue upright in her right hand through the spin, its butt just clear of the floor."},
    },
    "poses": {
        "right_hand.prep": {"mode": "held", "dir": [0.75, -0.2, 0.62], "grip": 0.2},
        "right_hand.peak": {"mode": "held", "dir": [0.82, -0.45, 0.35], "grip": 0.2},
        "right_hand.follow": {"mode": "held", "dir": [0.9, -0.4, 0.1], "grip": 0.17},
        "right_hand.return": {"mode": "planted", "butt": [-0.46, -0.05], "words": POLE},
        "challenge.load": {"otherHand": "tip", "mode": "held", "dir": [0.42, -0.2, 0.88], "grip": 0.52, "words": "She holds a long billiard cue slanted across her body in her right hand, and chalks its tip with her left."},
        "challenge.offer": {"mode": "held", "dir": [0.75, -0.65, -0.02], "grip": 0.36, "otherHand": 215, "words": LEVEL},
        "clap.contact": {"otherHand": 60},
        "finish_turn.finish_a": {"mode": "held", "dir": [-0.05, 0, 1], "grip": 0.42, "words": "She holds a long billiard cue upright in her right hand."},
        "finish_turn.finish_b": {"mode": "held", "dir": [0, 0, 1], "grip": 0.42, "words": "She holds a long billiard cue upright in her right hand."},
        "finish_turn.turn_in": {"mode": "planted", "butt": [-0.5, 0.15], "words": POLE},
        "finish_turn.turn_out": {"mode": "planted", "butt": [-0.36, -0.2], "words": POLE},
    },
}
c["drawing"]["extra"] = ("Both eyes are open. This is a grown woman of about sixty, fully clothed. There is exactly one billiard cue, long, slim, "
                         "straight and rigid, with a pale wooden shaft, a white tip and a dark wooden butt: it lies along the thin white line in "
                         "image 2. Do not draw the line itself. ")
c["drawing"]["sheet"]["views"]["front"]["stageScale"] = 0.84
c["drawing"]["sheet"]["views"]["back"]["stageScale"] = 0.84
c["drawing"]["sheet"]["views"]["back"]["stageFlip"] = True  # the accepted back has the cue in the picture's left: from behind that's her left hand
c["drawing"]["count"] = 2
c["drawing"]["score"] = {"silhouetteTolerance": 30}
for g in c["garments"]:
    if g["id"] == "shirt":
        g["alsoIn"] = ["prop"]
existing = {g["id"] for g in c["garments"]}
extra = [
    {"id": "brass", "shape": "waistcoat-buttons", "region": "accessory", "colour": "#D6A632", "alsoIn": ["cloth", "skin", "hair"], "text": "brass buttons and small gold stud earrings"},
    {"id": "chalk", "shape": "palette-only", "region": "accessory", "colour": "#3E8EDE", "alsoIn": ["skin", "prop"], "text": "a small cube of blue billiard chalk"},
    {"id": "cue_shaft", "shape": "cue-shaft", "region": "prop", "colour": "#C9984F", "alsoIn": ["skin", "shirt", "cloth", "trousers"], "text": "pale wooden cue shaft with a white tip"},
    {"id": "cue_butt", "shape": "cue-butt", "region": "prop_dark", "colour": "#6B3A1E", "alsoIn": ["skin", "trousers", "shoes"], "text": "dark wooden cue butt"},
]
c["garments"] += [g for g in extra if g["id"] not in existing]
c["$comment"] = "The Pool Player, the billiards room opponent. The owner accepted sheets 989001 (front) and 989101 and 989103 (back; the second is back-alt.png) on 2026-11-07. Her dance with the cue is written by pool-player.cue-source.py; the cue is a mask (cue-shaft, cue-butt) and a line in each skeleton."
HERE.write_text(json.dumps(c, indent=1, ensure_ascii=False) + "\n")
