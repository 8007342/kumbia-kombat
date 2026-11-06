#!/usr/bin/env python3
"""Write the lawn's pair staging into levels/pool-garden.json `stage.duet`. Marks are floor coordinates. Exit data stays as it was. Run from the worktree root."""
import json
p = "levels/pool-garden.json"; L = json.load(open(p)); d = L["stage"]["duet"]; exit_keep = d["exit"]
marks = {
    # The middle of the pair, where each call starts and ends.
    "pair0From": [.45, .50], "pair0To": [.54, .46],
    "pair1From": [.50, .47], "pair1To": [.40, .54],
    "pair2From": [.44, .52], "pair2To": [.52, .56],
    "pair3From": [.53, .50], "pair3To": [.42, .46],
    "pair4From": [.46, .50], "pair4To": [.56, .54],
    "pair5From": [.50, .53], "pair5To": [.43, .48],
    # The sides, off the floor, for whoever isn't partnering.
    "rightSway1": [.70, .51], "rightSway2": [.72, .49], "rightSway3": [.72, .47], "rightSway4": [.69, .50], "backRight": [.74, .46],
    "leftSway1": [.30, .47], "leftSway2": [.26, .49], "leftSway3": [.25, .50], "leftArrive": [.27, .48],
    # Crossing behind everyone, to change sides.
    "crossLeft": [.45, .43], "crossRight": [.60, .43], "crossLeftHigh": [.44, .42], "crossRightHigh": [.60, .42],
    "exitLeft": [.31, .56], "exitRight": [.59, .56], "reachLeft": [.37, .585], "reachRight": [.53, .585],
}
A, B = "swing-a", "swing-b"
def turn(partner, left, n, off, steps): return {"partner": partner, "left": left, "from": f"pair{n}From", "to": f"pair{n}To", "off": off, "offSteps": [{"at": a, "to": m} for a, m in steps]}
turns = [
    turn(A, A, 0, "rightSway1", [(11, "rightSway2"), (13, "backRight")]),
    turn(B, A, 1, "leftSway1", [(11, "crossLeft"), (13.5, "crossRight")]),   # A crosses behind, so the next pair has B on the left
    turn(A, B, 2, "leftSway2", [(11, "leftArrive"), (13, "leftSway1")]),
    turn(B, B, 3, "rightSway3", [(11, "crossRightHigh"), (13.5, "crossLeftHigh")]),  # and back
    turn(A, A, 4, "rightSway4", [(11, "rightSway1"), (13, "rightSway2")]),
    turn(B, A, 5, "leftSway3", [(11, "leftSway2"), (13, "leftArrive")]),
]
L["stage"]["duet"] = {
    "marks": marks, "offClip": "skirt_play", "partnerClip": "dance_with",
    "outgoingBeats": 1.25, "incomingBeats": 2.5,
    "partnerGap": .13, "partnerUpstage": .012, "spread": .095,
    "pairFrames": {"rest": ["pair_rest_a", "pair_rest_b"], "arm": "pair_arm", "kick": "pair_kick"},
    "spin": {"beats": 2, "reachFrame": "spin_reach", "catchUpBeats": 1,
             "heroFrames": ["held_front", "held_front34", "held_side", "held_rear34", "held_rear", "held_rear34b", "held_sideb", "held_front34b"]},
    "turns": turns, "exit": exit_keep,
}
json.dump(L, open(p, "w"), indent=2, ensure_ascii=False); open(p, "a").write("\n")
