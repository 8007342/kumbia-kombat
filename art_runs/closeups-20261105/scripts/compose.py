#!/usr/bin/env python3
"""CPU review composites for the close-ups, in PIL, with no sound. Not the game's renderer. Phone: 390x844 logical at 3x. One art pixel is 2
device pixels, so the whole phone is 585x1266 art px; the plate fills the top 65 percent (824 art px, 549 logical). The tap band below it stays empty.
Arms are extended past their canvas by repeating the last row along the arm's slope, until they leave through the frame's left edge."""
import json, pathlib, sys
import numpy as np
from PIL import Image, ImageDraw
F = pathlib.Path.home() / ".cache/tillandsias-project/kumbia-art/closeups-20261105/final"; OUT = pathlib.Path("art_runs/closeups-20261105/sheets")
PW, PH, BAND = 585, 1266, 824
PLATE = sys.argv[1] if len(sys.argv) > 1 else "plate-garden"
def cs(ms):
    """GIF stores centiseconds: round cumulative time, so the error never grows past 5 ms; each frame is at least 20 ms."""
    t, out, done = 0.0, [], 0
    for m in ms:
        t += m; end = int(round(t / 10)) * 10; out.append(max(20, end - done)); done = end
    return out
def L(n): return Image.open(F / f"{n}.png").convert("RGBA")
def _rows_up_to_clean(a, teal_max=4):
    """Lowest row free of the teal elbow ball, so an extended forearm repeats only ivory shell."""
    h = a.shape[0]
    for y in range(h - 1, h - 90, -1):
        r = a[y]; t = (r[:, 3] > 0) & (r[:, 2].astype(int) > r[:, 0].astype(int) + 25) & (r[:, 2] < 140) & (r[:, 2] > 40)
        if t.sum() <= teal_max: return y
    return h - 1
def extend_lower_left(im, rows):
    """Continue a forearm below its canvas: rows past a clean row repeat it, shifted left along the measured slope, so it leaves by the left edge."""
    a = np.asarray(im); h, w = a.shape[:2]; op = a[..., 3] > 0; y0 = _rows_up_to_clean(a)
    ys = [y for y in range(max(0, y0 - 50), y0) if op[y].any()]; cx = [np.where(op[y])[0].max() for y in ys]
    slope = max(0.2, -np.polyfit(ys, cx, 1)[0]); out = np.zeros((h + rows, w, 4), "uint8"); out[:y0 + 1] = a[:y0 + 1]
    for r in range(h + rows - y0 - 1):
        s = int(round((r + 1) * slope))
        if s < w: out[y0 + 1 + r, :w - s] = a[y0, s:]
    return Image.fromarray(out)
def extend_lower_right(im, rows, min_slope=.8):
    """Continue a sleeve or arm cut by its canvas bottom, shifted right so it leaves by the frame's right edge."""
    a = np.asarray(im); h, w = a.shape[:2]; op = a[..., 3] > 0
    ys = [y for y in range(h - 40, h) if op[y].any()]; cx = [np.where(op[y])[0].min() for y in ys]
    out = np.zeros((h + rows, w, 4), "uint8"); out[:h] = a
    if len(ys) < 2 or not op[h - 1].any(): return Image.fromarray(out)
    slope = max(min_slope, np.polyfit(ys, cx, 1)[0])
    for r in range(rows):
        s = int(round((r + 1) * slope))
        if s < w: out[h + r, s:] = a[h - 1, :w - s]
    return Image.fromarray(out)
def band(c, note):
    d = ImageDraw.Draw(c); d.rectangle((0, BAND, PW, PH), fill=(12, 11, 16, 255)); d.line((0, BAND, PW, BAND), fill=(70, 66, 80, 255))
    for i in range(4):
        x = 73 + i * 146; d.ellipse((x - 42, BAND + 150, x + 42, BAND + 234), outline=(52, 50, 60, 255), width=2)
    d.text((16, PH - 58), "tap band: dimmed, inactive, empty of art", fill=(120, 118, 130, 255))
    d.text((16, PH - 40), note, fill=(180, 170, 120, 255)); d.text((16, PH - 22), "REVIEW ONLY. No sound. PIL composite, not the game's renderer.", fill=(180, 170, 120, 255))
def plate(n):
    p = L(n); c = Image.new("RGBA", (PW, PH), (0, 0, 0, 255)); c.paste(p, (0, 0)); c.paste(p.crop((p.width - 1, 0, p.width, p.height)), (584, 0)); return c
GK = {k: extend_lower_right(L(f"gk-{k}"), 120) for k in ("approach", "impact", "recoil")}; MC_RAISE = 110
MC = {k: extend_lower_left(L(f"mc-{k}"), MC_RAISE + 20) for k in ("approach", "impact", "recoil")}
def contact_points():
    g = np.asarray(GK["impact"])[..., 3] > 0; m = np.asarray(MC["impact"])[..., 3] > 0
    gl = np.where(g.any(0))[0].min(); gy = int(np.median(np.where(g[:, gl:gl + 8].any(1))[0]))
    rows = np.where(m[:120].any(1))[0]; mr = np.where(m[:120].any(0))[0].max(); my = int(np.median(np.where(m[:120, mr - 8:mr + 1].any(1))[0]))
    return gl, gy, mr, my
GL, GY, MR, MY = contact_points()
MC_X = 0; MC_Y = BAND - 240 - MC_RAISE       # canvas top; canvas bottom plus extension reach the band or the left edge
CONTACT = (int(MC_X + MR - 2), int(MC_Y + MY))          # 3 art px of overlap at impact
GK_X = PW - GK["impact"].width; GK_Y = CONTACT[1] - GY
if GK_X + GL > CONTACT[0]: print("GK left of frame needs", GK_X + GL - CONTACT[0])
GK_SHIFT = int(CONTACT[0] - (GK_X + GL))
def fists(g, m, gdx=0, mdx=0, mdy=0, note=""):
    c = plate(PLATE); im = GK[g]
    # Any arm shifted left of the frame's right edge would show its cut: GK's canvas stays flush right, with a clamp at 0
    c.alpha_composite(MC[m], (int(MC_X + mdx), int(MC_Y + mdy))) if MC_X + mdx >= 0 else c.alpha_composite(MC[m].crop((-mdx, 0, MC[m].width, MC[m].height)), (0, int(MC_Y + mdy)))
    gx = GK_X + GK_SHIFT + gdx; c.alpha_composite(im.crop((0, 0, im.width - max(0, gx + im.width - PW), im.height)), (gx, GK_Y)); band(c, note); return c
if __name__ == "__main__":
    print("contact art px", CONTACT, "logical", (round(CONTACT[0] / 1.5), round(CONTACT[1] / 1.5)), "fraction of phone height", round(CONTACT[1] / PH, 3), "GK x", GK_X, "left", GL)
    gb, mb = np.asarray(GK["impact"])[..., 3] > 0, np.asarray(MC["impact"])[..., 3] > 0
    print("GK opaque width", int(np.ptp(np.where(gb.any(0))[0])) + 1, "MC opaque height", int(np.ptp(np.where(mb.any(1))[0])) + 1)
    N = "1 art px = 2 device px at 3x (585x1266 art px)."
    fists("impact", "impact", note="Fist bump, contact. " + N).resize((1170, 2532), Image.NEAREST).convert("RGB").save(OUT / "phone-fist-contact-1170x2532.png", optimize=True)
    # Beats at 104 BPM. Impact lands at t = 577 ms. Arms are translated in whole art px.
    B = 60000 / 104; fr, du = [], []
    for k in (6, 5, 4, 3, 2, 1):
        e = k / 6; fr.append(fists("approach", "approach", int(60 * e * e), -int(70 * e * e), int(70 * e * e), f"approach, beat {6 - k}/6 of 1")); du.append(B / 6)
    for _ in range(2): fr.append(fists("impact", "impact", note="IMPACT on the beat")); du.append(B / 6)
    for k in (1, 2, 3, 4):
        fr.append(fists("recoil", "recoil", 8 * k, -6 * k, 4 * k, f"recoil, {k}/4")); du.append(B / 6)
    fr.append(fists("recoil", "recoil", 32, -24, 16, "hold before looping")); du.append(B)
    gif = [f.convert("RGB").quantize(160, method=Image.MEDIANCUT, dither=Image.NONE) for f in fr]
    gif[0].save(OUT / "fist-bump-104bpm.gif", save_all=True, append_images=gif[1:], duration=cs(du), loop=0, optimize=True)
    # Same timing, side by side stills
    st = Image.new("RGB", (PW * 3 + 40, PH), (0, 0, 0))
    for i, (g, gd, md, my, n) in enumerate([("approach", 60, -70, 70, "approach"), ("impact", 0, 0, 0, "impact"), ("recoil", 32, -24, 16, "recoil")]):
        st.paste(fists(g, g, gd, md, my, n).convert("RGB"), (i * (PW + 20), 0))
    st.save(OUT / "fist-three-beats.png", optimize=True)
    # Gulp: glass on the counter, then the hand tilting
    HAND = {k: extend_lower_left(L(f"hand-{k}"), 90) for k in ("hold", "tilt", "low")}; GLASS = L("glass")
    gbx = np.asarray(GLASS)[..., 3] > 0; base = np.where(gbx.any(1))[0].max()
    def gulp(h=None, gx=None, note=""):
        c = plate("plate-bar")
        if gx is not None: c.alpha_composite(GLASS, (gx, 620 - base))
        if h: c.alpha_composite(HAND[h], (0, 760 - 320))
        band(c, note); return c
    gulp(None, 270, "Gulp, glass slides in and stops. " + N).resize((1170, 2532), Image.NEAREST).convert("RGB").save(OUT / "phone-gulp-slide-1170x2532.png", optimize=True)
    gulp("tilt", None, "Gulp, contact: hand tilts, oil lower. " + N).resize((1170, 2532), Image.NEAREST).convert("RGB").save(OUT / "phone-gulp-tilt-1170x2532.png", optimize=True)
    st = Image.new("RGB", (PW * 4 + 60, PH), (0, 0, 0))
    for i, c in enumerate([gulp(None, 270, "slide"), gulp("hold", None, "hold"), gulp("tilt", None, "tilt"), gulp("low", None, "low")]):
        st.paste(c.convert("RGB"), (i * (PW + 20), 0))
    st.save(OUT / "gulp-four-beats.png", optimize=True)
    seq = [gulp(None, 270 + d, "slide") for d in (150, 80, 30, 0)] + [gulp("hold", None, "hold"), gulp("tilt", None, "tilt"), gulp("low", None, "low")]
    dur = [B / 4] * 4 + [B, B, B]
    seq = [f.convert("RGB").quantize(160, method=Image.MEDIANCUT, dither=Image.NONE) for f in seq]
    seq[0].save(OUT / "gulp-104bpm.gif", save_all=True, append_images=seq[1:], duration=cs(dur), loop=0, optimize=True)
