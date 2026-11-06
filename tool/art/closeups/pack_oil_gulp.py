#!/usr/bin/env python3
"""Pack the oil gulp close-up from raws into assets/art/closeups. Run from the repo root.

Qwen paints these on a big loose grid (about 15 raw px for the head, against 8 in the fist bump), and sampling that grid would
give pixels twice the fist's. So each raw is quantised, every colour's mask is blurred and the strongest wins, which rounds the
stair steps while flat shapes stay flat. The result is then nearest-sampled at BLOCK raw px, shown at scale 2/3 (2 device px at 3x).
Raws: ~/.cache/tillandsias-project/kumbia-art/oil-gulp-20261106/raw/. Prompts, guides and workflows: art_runs/oil-gulp-20261106/.
"""
import json, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi

RAW = os.path.expanduser("~/.cache/tillandsias-project/kumbia-art/oil-gulp-20261106/raw/")
OUT = "assets/art/closeups/oil-gulp-"
BLOCK = 4
EXTEND_RIGHT = 56  # art px: her shirt sleeve carries on past the screen's right edge
# name: raw, blur sigma in raw px (about a third of the painted cell), contact point in art px on this piece
PIECES = {
    "bt-offer": ("bt-offer2/2103", 3.5, "glass"),
    "bt-empty": ("bt-empty/4101", 3.5, "same:bt-offer"),
    "mc-reach": ("mc-reach2/2201", 4.5, "reach"),
    "mc-gulp": ("mc-gulp4/5002", 5.0, "glass"),
    "mc-low": ("mc-low2/5102", 5.0, "same:mc-gulp"),
}
# Everything below this raw y, right of this raw x, is a puddle or drip the model added under the glass.
CUT = {"mc-gulp": (860, 1420), "mc-low": (860, 1390)}
# The low frame's oil drips out of the glass's lower corner: clear the drip's polygon, then redraw that stretch of outline.
PATCH = {"mc-low": dict(clear=[(1000, 1290), (1128, 1272), (1188, 1390), (1000, 1400)], ink=[(1130, 1274), (1188, 1386), (1260, 1352)])}


def largest(mask):
    lab, n = ndi.label(mask)
    if n < 2:
        return mask
    sizes = ndi.sum(mask, lab, range(1, n + 1))
    return lab == 1 + int(np.argmax(sizes))


def resmooth(im, sigma, colors=160):
    """Round big stair steps, keep flat colour."""
    a = np.asarray(im.split()[3]) >= 128
    a = largest(a)
    flat = Image.new("RGB", im.size, (0, 0, 0))
    flat.paste(im.convert("RGB"), mask=Image.fromarray((a * 255).astype(np.uint8)))
    q = flat.quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = np.array(q.getpalette()[: colors * 3]).reshape(-1, 3).astype(np.uint8)
    idx = np.array(q)
    best = np.full(idx.shape, -1.0, np.float32)
    out = np.zeros(idx.shape, np.uint8)
    for c in np.unique(idx):
        soft = ndi.gaussian_filter((idx == c).astype(np.float32), sigma)
        take = soft > best
        best[take], out[take] = soft[take], c
    alpha = ndi.gaussian_filter(a.astype(np.float32), sigma) >= 0.5
    return np.dstack([pal[out], (alpha * 255).astype(np.uint8)])


def glow(a, strength):
    """Happy eyes: brighten the cyan arcs and lift the dark screen around them. Stays inside the screen, so no halo on the plate."""
    r, g, b = [a[..., i].astype(int) for i in range(3)]
    cyan = (g > 170) & (b > 170) & (r < 150) & (a[..., 3] > 0)
    screen = (r < 40) & (g > 25) & (g < 90) & (b > 30) & (b < 110)
    lab, n = ndi.label(cyan)
    keep = np.zeros_like(cyan)
    for i in range(1, n + 1):  # the two eye arcs: not the antenna ball or the cuff bands, by being surrounded by screen
        blob = lab == i
        if blob.sum() > 40 and (ndi.binary_dilation(blob, iterations=2) & ~blob & screen).sum() > blob.sum() * .25:
            keep |= blob
    near = ndi.binary_dilation(keep, iterations=strength) & screen
    nearer = ndi.binary_dilation(keep, iterations=max(1, strength // 2)) & screen
    out = a.copy()
    out[near, :3] = (8, 78, 94)
    out[nearer, :3] = (12, 118, 134)
    out[keep, :3] = (120, 248, 255)
    return out


def tile_right(a, n):
    """Run a sleeve off the screen: its last column's cloth repeats, with a thin outline, instead of ending at the canvas edge."""
    h, w = a.shape[:2]
    col = a[:, w - 2].copy()
    rows = np.where((col[:, 3] > 0) & (col[:, :3].astype(int).sum(1) > 200))[0]
    ext = np.zeros((h, n, 4), a.dtype)
    if len(rows):
        top, bot = int(rows.min()), int(rows.max())
        ext[top:bot + 1] = col[top:bot + 1][:, None]
        cloth = col[(top + bot) // 2]
        dark = ext[top:bot + 1][:, 0, :3].astype(int).sum(1) <= 200
        ext[top:bot + 1][dark] = cloth
        ext[max(0, top - 3):top] = (8, 10, 24, 255)
        ext[bot + 1:bot + 4] = (8, 10, 24, 255)
    return np.concatenate([a[:, : w - 1], ext], axis=1)


def piece(name):
    raw, sigma, _ = PIECES[name]
    im = Image.open(f"{RAW}{raw}.png").convert("RGBA")
    if name in CUT:
        x, y = CUT[name]
        arr = np.array(im)
        arr[y:, x:, 3] = 0
        im = Image.fromarray(arr)
    if name in PATCH:
        arr = np.array(im)
        mask = Image.new("L", im.size, 0)
        ImageDraw.Draw(mask).polygon(PATCH[name]["clear"], fill=255)
        arr[np.asarray(mask) > 0, 3] = 0
        im = Image.fromarray(arr)
        ImageDraw.Draw(im).line(PATCH[name]["ink"], fill=(8, 10, 24, 255), width=15)
    a = resmooth(im, sigma)
    a = a[BLOCK // 2 :: BLOCK, BLOCK // 2 :: BLOCK]
    if name == "mc-gulp":
        a = glow(a, 3)
    if name == "mc-low":
        a = glow(a, 5)
    if name.startswith("bt"):
        a = tile_right(a, EXTEND_RIGHT)
    return a


def glass_centre(a, name):
    """The glass's middle, measured on the drawing: the bbox of clear and oil-dark pixels away from arm and head."""
    r, g, b = [a[..., i].astype(int) for i in range(3)]
    op = a[..., 3] > 0
    if name == "bt-offer":
        dark = (r + g + b < 120) & op  # oil and outline
        lab, n = ndi.label(dark)
        sizes = ndi.sum(dark, lab, range(1, n + 1))
        ys, xs = np.where(lab == 1 + int(np.argmax(sizes)))
        return int(np.median(xs)), int(np.median(ys))
    return GULP_GLASS


GULP_GLASS = (294, 260)  # by eye on the drawing, the glass's middle, near the mitten


def plate():
    """Bar plate, from the room itself: counter and mirror, softened and quantised, so the wide and the close-up share a place."""
    src = Image.open("assets/art/bar/bar-interior.png").convert("RGB")
    crop = src.crop((250, 60, 774, 800))  # lamps and mirror above, counter behind the glass, floor below
    soft = crop.filter(ImageFilter.GaussianBlur(2.5)).resize((468, 660), Image.BILINEAR)
    arr = np.asarray(soft, np.float32) * .78  # the engine then darkens by 55%; keep the lamps from competing with the eyes
    q = Image.fromarray(arr.astype(np.uint8)).quantize(48, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q.save(OUT + "plate.png", optimize=True)
    return list(q.size)


def main():
    meta = {"pieces": {}, "notes": "contact is the art pixel that should land on the shot's contactPoint"}
    arrays = {n: piece(n) for n in PIECES}
    contacts = {}
    contacts["bt-offer"] = glass_centre(arrays["bt-offer"], "bt-offer")
    contacts["bt-empty"] = contacts["bt-offer"]
    contacts["mc-gulp"] = glass_centre(arrays["mc-gulp"], "mc-gulp")
    contacts["mc-low"] = contacts["mc-gulp"]
    # Reach: the mitten's right edge stops on the left wall of her glass.
    arr = arrays["mc-reach"]
    ys, xs = np.where(arr[..., 3] > 0)
    right = int(xs.max())
    band = ys[np.abs(xs - right) < 4]
    glass_half = 65  # art px from the glass's middle to its wall on bt-offer
    contacts["mc-reach"] = (right + glass_half - 3, int(band.mean()))
    for name, a in arrays.items():
        Image.fromarray(a, "RGBA").save(OUT + name + ".png", optimize=True)
        meta["pieces"][name] = {"file": f"oil-gulp-{name}.png", "size": [a.shape[1], a.shape[0]], "contact": list(contacts[name])}
    Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(OUT + "empty.png")
    meta["pieces"]["empty"] = {"file": "oil-gulp-empty.png", "size": [1, 1], "contact": [0, 0]}
    meta["plate"] = {"file": "oil-gulp-plate.png", "size": plate()}
    json.dump(meta, open("assets/art/closeups/oil-gulp-art.json", "w"), indent=1)
    print(json.dumps(meta))


main()
