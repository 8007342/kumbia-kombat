#!/usr/bin/env python3
"""People drawn in place on a room plate, several to a crop, each cut out as its own atlas.

The general form of pianist.py. Qwen draws a group straight onto a crop of the plate, so the plate's furniture, light
and perspective fix each person's place, size and occlusion (a diner behind a table is drawn behind the table). Every
frame is an edit of the accepted key that changes only the people. Each figure's layer is where a frame differs from
the plate inside that figure's polygon, after undoing the small whole-crop shift Qwen adds between edits. One atlas
per figure, 1:1 with the plate when its anchor sits at `anchorPlatePx`.

  inplace.py <spec> stage KEY|FRAMES   bake jobs into art_runs/<run>/ (run them with run_room_jobs.py)
  inplace.py <spec> matte              cut every figure from every kept drawing, sheet to the cache
  inplace.py <spec> pack               one atlas per figure into assets/art/ensemble/, manifest entries

Spec: tool/art/rooms/inplace/<name>.json. First use: the comedor's diners (plan/levels/comedor-art-2026-11-08.md).
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
from plates import bake_workflow  # noqa: E402
from pianist import polygon_box  # noqa: E402

CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"
STAGE = Path("/work/tmp/imagegen/kumbia")
SCALE = 3


def load(path):
    s = json.loads(Path(path).read_text())
    s["_path"] = str(path)
    return s


def crop_plate(s):
    x0, y0, x1, y1 = s["crop"]
    return Image.open(REPO / s["plate"]).convert("RGB").crop((x0, y0, x1, y1))


def stage(s, which):
    run = s["run"]
    out = REPO / "art_runs" / run
    (out / "workflows").mkdir(parents=True, exist_ok=True)
    st = STAGE / run / "in"
    st.mkdir(parents=True, exist_ok=True)
    if which == "KEY":
        base = crop_plate(s)
        size = (base.width * SCALE, base.height * SCALE)
        base.resize(size, Image.NEAREST).save(st / "crop.png")
        items = [("key", s["key"]["prompt"], st / "crop.png", s["key"]["seed"], s["key"]["count"])]
    else:
        key = CACHE / run / s["key"]["pick"]
        shutil.copy(key, st / "key.png")
        size = Image.open(key).size
        items = [(f["id"], f["prompt"], st / "key.png", f["seed"], f["count"]) for f in s["frames"]
                 if not f.get("reuse") and (which == "FRAMES" or f["id"] in which.split(","))]
    jobs = []
    for name, prompt, base, seed, count in items:
        text = f"{prompt} {s['keepWords']}"
        wf = bake_workflow(["base"], text, f"kk/{run}/{name}", 4, size)
        path = out / "workflows" / f"{name}.api.json"
        path.write_text(json.dumps(wf, indent=1, ensure_ascii=False) + "\n")
        (out / "workflows" / f"{name}.prompt.txt").write_text(text + "\n")
        jobs.append(dict(name=name, workflow=str(path.relative_to(REPO)), inputs={"base": str(base)}, overrides={"seed": seed}, count=count))
    doc = dict(room=s["room"], run=run, passNo=2, steps=4, jobs=jobs, how="tool/art/rooms/run_room_jobs.py --jobs <this file>")
    f = out / f"jobs-{'key' if which == 'KEY' else 'frames'}.json"
    f.write_text(json.dumps(doc, indent=1) + "\n")
    print(f, len(jobs), "jobs")


def align(drawn, plate_crop, polygons):
    """Undo Qwen's whole-crop shift at 3x against the plate outside every figure, then bring it to plate pixels."""
    big = np.asarray(drawn.convert("RGB"), float)
    ref = np.asarray(plate_crop.resize(drawn.size, Image.NEAREST), float)
    outside = np.ones(plate_crop.size[::-1], bool)
    for poly in polygons:
        x0, y0, x1, y1 = polygon_box(poly)
        outside[max(0, y0 - 4):y1 + 4, max(0, x0 - 4):x1 + 4] = False
    outside = np.kron(outside, np.ones((SCALE, SCALE), bool))[:big.shape[0], :big.shape[1]]

    def err(dy, dx):
        return float(np.abs(np.roll(big, (dy, dx), axis=(0, 1)) - ref).sum(-1)[outside][::7].mean())
    best = min((err(dy, dx), dy, dx) for dy in range(-30, 31, 3) for dx in range(-30, 31, 3))
    best = min((err(dy, dx), dy, dx) for dy in range(best[1] - 2, best[1] + 3) for dx in range(best[2] - 2, best[2] + 3))
    big = np.roll(big, best[1:], axis=(0, 1))
    small = np.asarray(Image.fromarray(big.astype(np.uint8)).resize(plate_crop.size, Image.BOX), float)
    return small, best


def figure_mask(small, plate_crop, polygon, thresh):
    diff = np.abs(small - np.asarray(plate_crop, float)).sum(-1)
    area = Image.new("L", plate_crop.size, 0)
    ImageDraw.Draw(area).polygon([tuple(p) for p in polygon], fill=255)
    inside = np.asarray(area) > 0
    m = (diff > thresh) & inside
    m = ndimage.binary_closing(m, iterations=2) & inside
    m = ndimage.binary_fill_holes(m)
    lab, n = ndimage.label(m)
    if n:
        sizes = ndimage.sum(m, lab, range(1, n + 1))
        m = lab == (1 + int(np.argmax(sizes)))
    return m


def recolour(rgb, m, rule):
    """Turn one garment's hue inside a figure's mask, keeping value and saturation: a twin's dress, deterministic."""
    import colorsys
    out = rgb.copy()
    lo, hi = rule["hue"]
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        r, g, b = out[y, x] / 255.0
        h, sat, v = colorsys.rgb_to_hsv(r, g, b)
        if lo <= h * 360 <= hi and sat >= rule.get("minSat", .25):
            out[y, x] = np.array(colorsys.hsv_to_rgb((h + rule["shift"] / 360) % 1, sat, v)) * 255
    return out


def source(s, f):
    return CACHE / s["run"] / (s["key"]["pick"] if f.get("reuse") == "key" else f["pick"])


def matte(s):
    plate_crop = crop_plate(s)
    out = CACHE / s["run"] / "layers"
    out.mkdir(parents=True, exist_ok=True)
    polys = [g["polygon"] for g in s["figures"]]
    rows = []
    for f in s["frames"]:
        small, best = align(Image.open(source(s, f)), plate_crop, polys)
        comp = np.asarray(plate_crop).copy()
        for g in s["figures"]:
            m = figure_mask(small, plate_crop, g["polygon"], s.get("threshold", 24))
            px = recolour(small, m, g["recolour"]) if "recolour" in g else small
            rgba = np.dstack([px.astype(np.uint8), np.where(m, 255, 0).astype(np.uint8)])
            Image.fromarray(rgba, "RGBA").save(out / f"{g['id']}-{f['id']}.png")
            comp = np.where(m[..., None], px.astype(np.uint8), comp)
        print(f["id"], "shift", best[1:], "residual", round(best[0], 1))
        rows.append(Image.fromarray(comp.astype(np.uint8)).resize((plate_crop.width * 2, plate_crop.height * 2), Image.NEAREST))
    sheet = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y)); y += r.height
    sheet.save(CACHE / s["run"] / "frames-sheet.png")
    print(CACHE / s["run"] / "frames-sheet.png")


def pack(s):
    x0, y0, _, _ = s["crop"]
    cam = s["camera"]
    layers = CACHE / s["run"] / "layers"
    man = REPO / "assets/art/ensemble/manifest.json"
    doc = json.loads(man.read_text())
    for g in s["figures"]:
        ims = {f["id"]: Image.open(layers / f"{g['id']}-{f['id']}.png") for f in s["frames"]}
        boxes = [im.getbbox() for im in ims.values() if im.getbbox()]
        bx0, by0 = min(b[0] for b in boxes), min(b[1] for b in boxes)
        bx1, by1 = max(b[2] for b in boxes), max(b[3] for b in boxes)
        ax, ay = g["anchorPlatePx"]
        # The engine wants each anchor inside its rect (party_sprites.dart), so a figure cut at a table top gets
        # transparent rows down to its floor point. Nothing moves on screen.
        fw, fh = bx1 - bx0, max(by1 - by0, ay - y0 - by0 + 1)
        gut = 2
        atlas = Image.new("RGBA", (gut + len(ims) * (fw + gut), fh + 2 * gut), (0, 0, 0, 0))
        # 1:1 with the plate: the standing height the floor gives at the anchor, in plate pixels.
        player_px = round((ay / cam["plateHeight"] - cam["horizonY"]) / cam["eyeHeightAdults"] * cam["plateHeight"])
        ppu = round(player_px / 38.75, 4)
        frames = {}
        for i, (fid, im) in enumerate(ims.items()):
            left = gut + i * (fw + gut)
            atlas.paste(im.crop((bx0, by0, bx1, by1)), (left, gut))
            frames[fid] = {"rect": [left, gut, fw, fh], "anchor": [ax - x0 - bx0, ay - y0 - by0], "pixelsPerUnit": ppu,
                           "facing": "front", "loop": True, "durationBeats": 2.0, "events": [], "supportFoot": "both",
                           "status": "candidate",
                           "provenance": {"run": s["run"], "drawing": fid, "route": "in-place edit of the plate, tool/art/rooms/inplace.py"}}
        for fid, src in s.get("aliases", {}).items():
            frames[fid] = {**frames[src], "provenance": {**frames[src]["provenance"], "puppet": f"same drawing as {src}"}}
        out = REPO / "assets/art/ensemble" / f"{g['atlas']}-v1.png"
        atlas.save(out)
        doc["atlases"][g["atlas"]] = {"image": out.name, "imageWidth": atlas.width, "imageHeight": atlas.height,
                                      "referenceFrame": s["frames"][0]["id"], "playerHeightPx": player_px, "frames": frames}
        print(g["atlas"], atlas.size, "frame", fw, fh, "top-left on plate", x0 + bx0, y0 + by0)
    man.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    s = load(sys.argv[1])
    cmd = sys.argv[2]
    {"stage": lambda: stage(s, sys.argv[3]), "matte": lambda: matte(s), "pack": lambda: pack(s)}[cmd]()
