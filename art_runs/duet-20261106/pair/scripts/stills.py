#!/usr/bin/env python3
"""Stills of the lawn at game size, a 390x844 phone, from the atlases as the manifests hold them. Same placement arithmetic as garden_scene.dart, including hands joining by their `hold`, but not the game's renderer: a still judges layout, not movement.
Each scene: dict of dancers and Mācron. Usage: stills.py out.png, from the worktree root."""
import json, sys
from PIL import Image, ImageDraw
L = json.load(open("levels/pool-garden.json")); D = L["stage"]["duet"]; HOME = L["stage"]["heroHome"]; M = D["marks"]
ens = json.load(open("assets/art/ensemble/manifest.json"))["atlases"]; hero = json.load(open("assets/art/party/manifest.json"))["atlases"]["hero"]
W, H = 390, 844; K = 844 / 1536  # px per source px on this phone: it fits the height
LEFT = (1024 * K - W) / 2
def H_at(y, stature=1.0): return (151 + (y - .5) * 440) * stature  # plan/duet-foundations.md's table
def project(fl): return (fl[0] * 1024 * K - LEFT, fl[1] * 844)
IM = {k: Image.open(f"assets/art/ensemble/{ens[k]['image']}").convert("RGBA") for k in ("swing-a", "swing-b")}; IH = Image.open(f"assets/art/party/{hero['image']}").convert("RGBA")
STATURE = {"swing-a": 1.0, "swing-b": .9}
def place(atlas, im, frame, ground, scale, flip, S):
    frame = frame if frame in atlas["frames"] else "pair_rest_a"; f = atlas["frames"][frame]; x, y, w, h = f["rect"]; k = scale / f["pixelsPerUnit"]; c = im.crop((x, y, x + w, y + h)).resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
    ax = f["anchor"][0] * k
    if flip: c = c.transpose(Image.FLIP_LEFT_RIGHT); ax = (w - f["anchor"][0]) * k
    S.alpha_composite(c, (max(0, round(ground[0] - ax)), max(0, round(ground[1] - f["anchor"][1] * k))))
def hand(atlas, frame, ground, scale, flip):
    frame = frame if frame in atlas["frames"] else "pair_rest_a"; f = atlas["frames"][frame]; k = scale / f["pixelsPerUnit"]; dx = (f["hold"][0] - f["anchor"][0]) * k
    return (ground[0] + (-dx if flip else dx), ground[1] + (f["hold"][1] - f["anchor"][1]) * k)
def dscale(who, fl):
    a = ens[who]; r = a["frames"]["ready"]; return H_at(fl[1], STATURE[who]) / (r["rect"][3] / r["pixelsPerUnit"])
def hscale(fl):
    r = hero["frames"]["front_idle"]; return H_at(fl[1], .35) / (r["rect"][3] / r["pixelsPerUnit"])
def backdrop():
    bg = Image.open(f"assets/art/{L['background']}" if not L["background"].startswith("assets") else L["background"]).convert("RGBA"); bg = bg.resize((round(bg.width * 844 / bg.height), 844), Image.LANCZOS)
    S = Image.new("RGBA", (W, H)); S.paste(bg, (-(bg.width - W) // 2, 0)); return S
def pair(mid, left, fl, fr, off=None, label=""):
    S = backdrop(); right = "swing-b" if left == "swing-a" else "swing-a"; sp = D["spread"]
    a, b = (mid[0] - sp, mid[1]), (mid[0] + sp, mid[1]); ga, gb = project(a), project(b); sa, sb = dscale(left, a), dscale(right, b)
    ha, hb = hand(ens[left], fl, ga, sa, False), hand(ens[right], fr, gb, sb, True); dx, dy = (hb[0] - ha[0]) / 2, (hb[1] - ha[1]) / 2
    place(ens[left], IM[left], fl, (ga[0] + dx, ga[1] + dy), sa, False, S); place(ens[right], IM[right], fr, (gb[0] - dx, gb[1] - dy), sb, True, S)
    r = project(L["stage"]["heroWatch"]); place(hero, IH, "rear_idle", r, hscale(L["stage"]["heroWatch"]), False, S)
    ImageDraw.Draw(S).text((6, 4), f"{label}  closed {abs(dx) * 2:.0f},{abs(dy) * 2:.0f}px", fill="white"); return S
def spin(who, side, herof, offwho=None, offfl=None, label=""):
    S = backdrop(); gap = D["partnerGap"]; fl = (HOME[0] + (-gap if side == "left" else gap), HOME[1] - D["partnerUpstage"]); flip = side == "right"
    if offwho:
        g = project(offfl); place(ens[offwho], IM[offwho], "skirt_sway_r", g, dscale(offwho, offfl), False, S)
    g = project(fl); s = dscale(who, fl); gh = project(HOME); sh = hscale(HOME); hh = hand(hero, herof, gh, sh, flip); hh2 = hand(ens[who], "spin_reach", g, s, flip); dx, dy = hh[0] - hh2[0], hh[1] - hh2[1]
    place(ens[who], IM[who], "spin_reach", (g[0] + dx, g[1] + dy), s, flip, S); place(hero, IH, herof, gh, sh, flip, S)
    d = ImageDraw.Draw(S); d.line([(0, 549), (W, 549)], fill=(255, 255, 255, 80)); d.text((6, 4), f"{label}  closed {dx:.0f},{dy:.0f}px", fill="white"); return S
def tile(shots, out):
    O = Image.new("RGB", (len(shots) * 400, 860), (30, 30, 30))
    for i, s in enumerate(shots): O.paste(s.convert("RGB"), (i * 400 + 5, 8))
    O.save(out); print(O.size)
if __name__ == "__main__":
    shots = [pair(M["pair0From"], "swing-a", "pair_rest_a", "pair_rest_b", label="call"), pair(M["pair1To"], "swing-a", "pair_arm", "pair_rest_a", label="right hand"), pair(M["pair4To"], "swing-b", "pair_rest_b", "pair_kick", label="left foot"),
             spin("swing-a", "left", "held_front", "swing-b", M["rightSway1"], label="a spins"), spin("swing-b", "right", "held_rear", "swing-a", M["leftSway1"], label="b spins")]
    tile(shots, sys.argv[1])
