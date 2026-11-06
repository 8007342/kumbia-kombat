#!/usr/bin/env python3
"""Writes the lawn's duet block and exit shot into levels/pool-garden.json, so the numbers live in one readable place while they are tuned, and the dancers' clips into choreography.json.
Run from the worktree root. The level file stays the authority once this is committed."""
import json

MARKS = {
    "call0": [.47, .54], "call1": [.56, .52], "call2": [.40, .56], "call3": [.44, .52], "call4": [.54, .55], "call5": [.48, .50],
    "danceLeft": [.29, .59], "danceRight": [.63, .59],
    "aEnd0": [.25, .50], "aEnd2": [.66, .50], "aEnd4": [.77, .52],
    "bEnd1": [.76, .53], "bEnd3": [.22, .51], "bEnd5": [.74, .47],
    "rightSway1": [.70, .51], "rightSway2": [.72, .49], "rightSway3": [.72, .47], "rightSway4": [.69, .50],
    "leftSway1": [.30, .47], "leftSway2": [.26, .49], "leftSway3": [.25, .50],
    "leftArrive": [.27, .48],
    "backRight": [.72, .46], "backRight2": [.74, .46], "crossRight": [.60, .43], "crossLeft": [.45, .43], "crossRightHigh": [.60, .42], "crossLeftHigh": [.44, .42],
    "exitLeft": [.31, .56], "exitRight": [.59, .56], "reachLeft": [.37, .585], "reachRight": [.53, .585],
}

def step(at, to): return {"at": at, "to": to}

DUET = {
    "marks": MARKS,
    "offClip": "skirt_play",
    "partnerClip": "dance_with",
    "outgoingBeats": 2,
    "incomingBeats": 2.5,
    "turns": [
        {"lead": "swing-a", "call": "call0", "dance": "danceLeft", "end": "aEnd0",
         "offSteps": [step(5, "rightSway1"), step(12, "rightSway2")]},
        {"lead": "swing-b", "call": "call1", "dance": "danceRight", "end": "bEnd1",
         "offSteps": [step(5, "leftSway1"), step(12, "leftSway2")]},
        {"lead": "swing-a", "call": "call2", "dance": "danceRight", "end": "aEnd2", "note": 0,
         "offSteps": [step(2.5, "backRight"), step(6.5, "crossRight"), step(10, "crossLeft"), step(13.5, "leftArrive")]},
        {"lead": "swing-b", "call": "call3", "dance": "danceLeft", "end": "bEnd3",
         "offSteps": [step(5, "rightSway3"), step(12, "rightSway4")]},
        {"lead": "swing-a", "call": "call4", "dance": "danceRight", "end": "aEnd4",
         "offSteps": [step(5, "leftSway1"), step(12, "leftSway3")]},
        {"lead": "swing-b", "call": "call5", "dance": "danceRight", "end": "bEnd5",
         "offSteps": [step(2.5, "backRight2"), step(6.5, "crossRightHigh"), step(10, "crossLeftHigh"), step(13.5, "leftArrive")]},
    ],
    "exit": {
        "left": "exitLeft", "right": "exitRight", "leftReach": "reachLeft", "rightReach": "reachRight",
        "sideBeats": 1.5, "reachFrom": 2.75, "reachTo": 3.5, "reachFrame": "left_hand_prep",
    },
}
for t in DUET["turns"]: t.pop("note", None)

SHOT = {
    "plate": "closeups/duet-plate.png",
    "celebrateUntil": 3,
    "walkFrom": .5,
    "walkTo": 1.25,
    "heroStep": [.45, .605],
    "heroWaitFrame": "front_idle",
    "dust": False,
    "closeupFrom": 3.5,
    "contactBeat": 4.5,
    "closeupTo": 7.75,
    "contactPoint": [.5, .3],
    "impactBeats": 1,
    "actors": [],  # filled by puppet.py's layout
    "cue": [
        {"beat": 4.5, "track": "peck", "pitch": 60, "velocity": 120},
        {"beat": 5.25, "track": "peck", "pitch": 72, "velocity": 70},
    ],
}

path = "levels/pool-garden.json"; level = json.load(open(path))
for c in level["stage"]["challengers"]: c.pop("floorTrack", None)
level["stage"]["challengers"][0]["mark"] = MARKS["call0"]
level["stage"]["challengers"][1]["mark"] = MARKS["bEnd5"]
level["stage"]["duet"] = DUET
layout = json.load(open("art_runs/duet-20261106/closeup-layout.json")) if __import__("os").path.exists("art_runs/duet-20261106/closeup-layout.json") else None
if layout:
    SHOT["actors"] = layout["actors"]; SHOT["contactPoint"] = layout["contactPoint"]; level["exitShot"] = SHOT
json.dump(level, open(path, "w"), indent=2, ensure_ascii=False); open(path, "a").write("\n")

path = "assets/art/ensemble/choreography.json"; c = json.load(open(path))
clips = {
    "note": "One hand on the back and the other playing with the skirt, while the other dancer has the turn. Mirrors are flips of two drawings. dance_with reaches toward the picture's left; the scene mirrors it when she is on Macron's left.",
    "clips": {
        "skirt_play": {"beatsPerFrame": 1, "frames": ["skirt_sway_r", "skirt_pass_r", "skirt_sway_l", "skirt_pass_l"]},
        "dance_with": {"beatsPerFrame": 1, "frames": ["challenge_offer", "groove_pass_l", "approval_release", "groove_pass_l2", "right_hand_return", "groove_down_l", "challenge_offer", "watch_shift_l"]},
    },
}
c["dancers"]["swing-a"] = clips; c["dancers"]["swing-b"] = clips
json.dump(c, open(path, "w"), indent=2, ensure_ascii=False); open(path, "a").write("\n")
