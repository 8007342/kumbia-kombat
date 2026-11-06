#!/usr/bin/env python3
"""The lawn kiss close-up as a puppet. Mācron's head is cut once from the gulp's clean drawing and his eyes are drawn by code, so nothing flickers between frames and only the eyes and blush change.
The two dancers are Qwen drawings snapped to the same pixel grid: one drawing each for the kiss and one for the smile, both cut off above the chest, so the close-up shows heads, collars and shoulders only.
The plate is cropped from the lawn's own background, and a foreground hedge from the same painting hides where his body ends. Writes assets/art/closeups/duet-*.png and closeup-layout.json. Run from the worktree root."""
import json, pathlib, sys
import numpy as np
from PIL import Image, ImageDraw

RUN = pathlib.Path("art_runs/duet-20261106"); HOME = pathlib.Path.home() / ".cache/tillandsias-project/kumbia-art/duet-20261106/raw"
OUT = pathlib.Path("assets/art/closeups"); PICK = json.load(open(RUN / "picks.json"))["closeup"]
SCALE = .36  # world units per art pixel, the same for every actor, so pixels match
CELL = 2     # Mācron's source drawing holds one colour per 2 px, which sets the grid
INK = (6, 12, 28, 255); SCREEN = (2, 42, 54, 255); CYAN = (40, 255, 255, 255); CYAN_DIM = (20, 170, 190, 255); BLUSH = (246, 138, 150, 255); BLUSH2 = (250, 176, 170, 255)

def snap(im, cell=CELL):
    """One colour per grid cell, by majority, so a drawing shares the puppet's pixel size."""
    a = np.asarray(im.convert("RGBA"), dtype=np.uint32); h, w = a.shape[:2]; rows, cols = h // cell, w // cell
    key = (a[..., 0] << 24 | a[..., 1] << 16 | a[..., 2] << 8 | a[..., 3]) * (a[..., 3] >= 128)
    out = np.zeros((rows, cols, 4), dtype=np.uint8)
    for y in range(rows):
        for x in range(cols):
            v, c = np.unique(key[y * cell:(y + 1) * cell, x * cell:(x + 1) * cell], return_counts=True); k = int(v[c.argmax()])
            out[y, x] = (k >> 24 & 255, k >> 16 & 255, k >> 8 & 255, k & 255)
    return Image.fromarray(out, "RGBA").resize((cols * cell, rows * cell), Image.NEAREST)

# Mācron: the gulp's `reach` drawing is square-on with level eyes. Keep the head, neck and the middle of the torso; the arms go.
src = Image.open("art_runs/oil-gulp-v2-20261106/frames/reach.png").convert("RGBA")
keep = Image.new("L", src.size, 0); d = ImageDraw.Draw(keep); d.rectangle([0, 0, 416, 234], fill=255); d.rectangle([104, 234, 238, 300], fill=255)
body = Image.new("RGBA", src.size, (0, 0, 0, 0)); body.paste(src, (0, 0), keep)
# Face screen, as measured on that drawing: wipe the arcs, then each frame paints its own eyes.
EYES = [(142, 138), (205, 138)]; SCREEN_BOX = (103, 97, 235, 185)
face = np.array(body); bx0, by0, bx1, by1 = SCREEN_BOX
region = face[by0:by1, bx0:bx1]; cyan = (region[..., 1] > 150) & (region[..., 0] < 120)
region[cyan] = SCREEN; face[by0:by1, bx0:bx1] = region; body = Image.fromarray(face, "RGBA")
# Blush sits on the ivory cheek below the screen's outer corners.
CHEEKS = [(110, 197), (222, 197)]

def block_circle(d, cx, cy, r, fill):
    for y in range(-r, r + 1, CELL):
        for x in range(-r, r + 1, CELL):
            if x * x + y * y <= r * r: d.rectangle([cx + x, cy + y, cx + x + CELL - 1, cy + y + CELL - 1], fill=fill)

def macron(name, eyes, blush=0):
    im = body.copy(); d = ImageDraw.Draw(im)
    for cx, cy in EYES:
        if eyes == "round":
            block_circle(d, cx, cy, 25, CYAN_DIM); block_circle(d, cx, cy, 22, CYAN); block_circle(d, cx - 8, cy - 8, 5, (235, 255, 255, 255))
        elif eyes == "wide":
            block_circle(d, cx, cy, 28, CYAN_DIM); block_circle(d, cx, cy, 25, CYAN); block_circle(d, cx - 9, cy - 9, 6, (235, 255, 255, 255))
        elif eyes == "squash":  # half-way: the circle flattened, on its way to an arc
            for x in range(-24, 25, CELL):
                h = int(14 * (1 - (x / 25) ** 2) ** .5); d.rectangle([cx + x, cy - h - 2, cx + x + CELL - 1, cy + h // 3], fill=CYAN)
        else:  # arc: a thick smiling curve
            for x in range(-24, 25, CELL):
                y = int(-13 * (1 - (x / 25) ** 2) ** .5) + 6; d.rectangle([cx + x, cy + y, cx + x + CELL - 1, cy + y + 8], fill=CYAN)
    for cx, cy in CHEEKS:
        if blush >= 1:
            # A small soft oval, only ever on the ivory: its size is the whole animation.
            rx, ry = 6 + 4 * blush, 2 + 2 * blush
            for y in range(-ry, ry + 1, CELL):
                for x in range(-rx, rx + 1, CELL):
                    if (x / rx) ** 2 + (y / ry) ** 2 <= 1:
                        d.rectangle([cx + x, cy + y, cx + x + CELL - 1, cy + y + CELL - 1], fill=BLUSH if (x / rx) ** 2 + (y / ry) ** 2 < .45 else BLUSH2)
    im.save(OUT / f"duet-macron-{name}.png", optimize=True); return im.size

for name, eyes, blush in [("round", "round", 0), ("wide", "wide", 0), ("squash", "squash", 1), ("arc", "arc", 2), ("arc-blush", "arc", 3)]: macron(name, eyes, blush)

def dancer(tag, pick, name, flip=False):
    """Qwen art to the puppet's grid and her atlas palette, cut off above the chest: nothing below the collar and shoulder line stays."""
    im = Image.open(HOME / pick["pose"] / f"{pick['seed']}.png").convert("RGBA")
    k = pick["fit"] / 1024; im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    w, h = im.size; a = np.array(im); a[pick["cutY"]:] = 0; a[..., 3] = (a[..., 3] >= 128) * 255; im = Image.fromarray(a, "RGBA")
    im = snap(im); im = im.quantize(colors=48, method=Image.FASTOCTREE, dither=Image.NONE).convert("RGBA")
    im.save(OUT / f"duet-{tag}-{name}.png", optimize=True); return im.size

layout_actors = []
for tag in ("a", "b"):
    p = PICK[tag]
    for name in ("kiss", "smile"): dancer(tag, p[name], name)

# Plate: the lit pavilion and its string lights, cropped from the lawn's painting. Scene dims it.
bg = Image.open("assets/art/pool-garden/pool-garden-v1-draft.png").convert("RGB"); bw, bh = bg.size
bg.crop((150, 130, 620, 830)).save(OUT / "duet-plate.png", optimize=True)

# Foreground: the hedge from the same painting, with a rough top, wide enough for a tablet, so his body ends behind leaves.
hedge = bg.crop((870, 480, 1024, 1180)).rotate(90, expand=True).convert("RGBA"); hw, hh = hedge.size
a = np.array(hedge); rng = np.random.default_rng(1846); top = 0
for x in range(0, hw, 6):
    cut = 6 + int(rng.integers(0, 14)); a[:cut, x:x + 6, 3] = 0
hedge = Image.fromarray(a, "RGBA").crop((0, 0, 700, 154)); hedge.save(OUT / "duet-hedge.png", optimize=True)

meet = (.5, .29); X = lambda dx: dx / SCALE  # contact point is the middle of his face
FACE = (165, 138)  # where the middle of his face is on his drawing
CHEEK_DX = 85      # art pixels from the face's middle to each cheek's kiss point
frames = [(3.5, "round"), (4.5, "wide"), (4.75, "squash"), (5, "arc"), (5.5, "arc-blush")]
actors = [{
    "approach": "closeups/duet-macron-round.png", "impact": "closeups/duet-macron-arc-blush.png",
    "frames": [{"beat": b, "image": f"closeups/duet-macron-{n}.png"} for b, n in frames],
    "contact": list(FACE), "scale": SCALE, "entry": [0, 0], "recoil": [0, 0],
}]
for tag, side in (("a", -1), ("b", 1)):
    p = PICK[tag]; lips = p["lips"]
    actors.append({
        "approach": f"closeups/duet-{tag}-smile.png", "impact": f"closeups/duet-{tag}-kiss.png",
        "frames": [{"beat": 3.5, "image": f"closeups/duet-{tag}-smile.png"}, {"beat": 4.25, "image": f"closeups/duet-{tag}-kiss.png"}, {"beat": 5.5, "image": f"closeups/duet-{tag}-smile.png"}],
        "contact": [lips[0] - side * CHEEK_DX, lips[1] - (CHEEK_DX and p.get("dropY", 18))], "scale": SCALE,
        "entry": [side * 70, 8], "recoil": [side * 13, 2],
    })
actors.append({"approach": "closeups/duet-hedge.png", "impact": "closeups/duet-hedge.png", "contact": [350, -97], "scale": SCALE, "entry": [0, 0], "recoil": [0, 0]})
json.dump({"contactPoint": list(meet), "actors": actors}, open(RUN / "closeup-layout.json", "w"), indent=1)
print("ok")
