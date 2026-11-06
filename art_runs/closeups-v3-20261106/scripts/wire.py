#!/usr/bin/env python3
"""Point the two levels' exitShot at the redrawn art. Only exitShot changes: every beat, cue and title timing stays as it was. Ran once on the old four-actor blocks; kept as the record, not to re-run. Run from the worktree root."""
import json

def gulp(s):
    bt, _, counter = s["actors"]
    g = lambda n: f"closeups/oil-gulp-mc3-{n}.png"
    frames = [(6, "sway1"), (6.5, "sway2"), (7, "sway1"), (7.5, "reach"), (8, "gulp1"), (8.5, "gulp2"), (9, "gulp3"), (9.5, "gulp4"), (10, "gulp5"), (10.5, "relief"), (10.75, "wiggle1"), (11, "wiggle2"), (11.25, "hop")]
    mc = {"approach": g("reach"), "impact": g("gulp3"), "frames": [{"beat": b, "image": g(n)} for b, n in frames],
          "contact": [298, 341], "scale": .31, "entry": [0, 0], "recoil": [0, 0]}
    bt["contact"] = [90, 169]  # his glass starts where the bartender's is
    s["actors"] = [counter, bt, mc]

def kiss(s):
    head, a, b, hedge = s["actors"]; m = lambda n: f"closeups/duet-macron-{n}.png"; contact = [200, 165]; scale = head["scale"]
    head["contact"] = contact
    a["contact"][0] += 20; b["contact"][0] -= 20  # his head is nearly all screen: kiss the rim, not the screen
    s["actors"] = [head, a, b, hedge,
        {"approach": m("body-rest"), "impact": m("body-shy"), "frames": [{"beat": 3.5, "image": m("body-rest")}, {"beat": 4.5, "image": m("body-kiss")}, {"beat": 5.5, "image": m("body-shy")}], "contact": contact, "scale": scale, "entry": [0, 0], "recoil": [0, 0]},
        {"approach": m("logo"), "impact": m("logo"), "contact": contact, "scale": scale, "entry": [0, 0], "recoil": [0, 0]}]

for path, fn in (("levels/bar.json", gulp), ("levels/pool-garden.json", kiss)):
    text = open(path).read(); raw = json.loads(text); fn(raw["exitShot"]); new = json.dumps(raw, indent=2, ensure_ascii=False) + "\n"; open(path, "w").write(new)
