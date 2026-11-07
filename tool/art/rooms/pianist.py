#!/usr/bin/env python3
"""The salon's pianist, drawn in place on the plate's own piano bench.

The plate paints the piano with its keyboard toward the viewer and its bench in front of it, so the pianist sits with
her back to the room. A rig skeleton of a seated figure from behind is ambiguous (it read as walking), so she is drawn
by Qwen straight onto a crop of the plate: the bench, the piano and the light fix her place, size and perspective.
Frames are edits of the accepted key, each changing only her arms and head. The layer is the difference from the plate,
kept to her polygon, so plate + layer match the key exactly and the plate is never repainted.

  pianist.py stage KEY|FRAMES       bake jobs into art_runs/rooms/salon/pianist/
  pianist.py matte                  cut each kept drawing from the plate, finish to plate pixels, sheet
  pianist.py pack                   atlas assets/art/ensemble/band-piano-v1.png and its manifest entry

Data: tool/art/rooms/pianist.json (crop, picks, polygon, words). plan/levels/salon-art-2026-11-07.md has the story.
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
from plates import bake_workflow  # noqa: E402

CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"
STAGE = Path("/work/tmp/imagegen/kumbia")
SPEC = HERE / "pianist.json"
RUN = "rooms/salon/pianist"
SCALE = 3


def spec():
    return json.loads(SPEC.read_text())


def crop_plate(s):
    x0, y0, x1, y1 = s["crop"]
    return Image.open(REPO / s["plate"]).convert("RGB").crop((x0, y0, x1, y1))


def stage(which):
    s = spec()
    out = REPO / "art_runs" / RUN
    (out / "workflows").mkdir(parents=True, exist_ok=True)
    st = STAGE / RUN / "in"
    st.mkdir(parents=True, exist_ok=True)
    jobs = []
    if which == "KEY":
        base = crop_plate(s)
        size = (base.width * SCALE, base.height * SCALE)
        base.resize(size, Image.NEAREST).save(st / "crop.png")
        items = [("key", s["key"]["prompt"], st / "crop.png", s["key"]["seed"], s["key"]["count"])]
    else:
        key = CACHE / RUN / s["key"]["pick"]
        shutil.copy(key, st / "key.png")
        size = Image.open(key).size
        items = [(f["id"], f["prompt"], st / "key.png", f["seed"], f["count"]) for f in s["frames"] if not f.get("reuse")]
    for name, prompt, base, seed, count in items:
        text = f"{prompt} {s['keepWords']}"
        wf = bake_workflow(["base"], text, f"kk/{RUN}/{name}", 4, size)
        path = out / "workflows" / f"{name}.api.json"
        path.write_text(json.dumps(wf, indent=1, ensure_ascii=False) + "\n")
        (out / "workflows" / f"{name}.prompt.txt").write_text(text + "\n")
        jobs.append(dict(name=name, workflow=str(path.relative_to(REPO)), inputs={"base": str(base)}, overrides={"seed": seed}, count=count))
    doc = dict(room="salon", run=RUN, passNo=2, steps=4, jobs=jobs, how="tool/art/rooms/run_room_jobs.py --jobs <this file>")
    f = out / f"jobs-{which.lower()}.json"
    f.write_text(json.dumps(doc, indent=1) + "\n")
    print(f, len(jobs), "jobs")


def polygon_box(polygon):
    xs, ys = [p[0] for p in polygon], [p[1] for p in polygon]
    return min(xs), min(ys), max(xs), max(ys)


def layer_of(drawn, plate_crop, polygon, thresh):
    """Her pixels: where the drawing differs from the plate, inside her polygon, at plate resolution."""
    from PIL import ImageDraw
    base = np.asarray(plate_crop, float)
    # Qwen nudges the whole crop by a pixel or two between edits: undo it first, at 3x, against the plate outside her
    # polygon, so the piano doesn't step at the polygon's edge.
    big = np.asarray(drawn.convert("RGB"), float)
    ref = np.asarray(plate_crop.resize(drawn.size, Image.NEAREST), float)
    outside = np.ones(base.shape[:2], bool)
    outside[max(0, polygon_box(polygon)[1] - 4):polygon_box(polygon)[3] + 4, max(0, polygon_box(polygon)[0] - 4):polygon_box(polygon)[2] + 4] = False
    outside = np.kron(outside, np.ones((SCALE, SCALE), bool))[:big.shape[0], :big.shape[1]]
    def err(dy, dx):
        return float(np.abs(np.roll(big, (dy, dx), axis=(0, 1)) - ref).sum(-1)[outside][::7].mean())
    best = min((err(dy, dx), dy, dx) for dy in range(-30, 31, 3) for dx in range(-30, 31, 3))
    best = min((err(dy, dx), dy, dx) for dy in range(best[1] - 2, best[1] + 3) for dx in range(best[2] - 2, best[2] + 3))
    big = np.roll(big, best[1:], axis=(0, 1))
    small = np.asarray(Image.fromarray(big.astype(np.uint8)).resize(plate_crop.size, Image.BOX), float)
    diff = np.abs(small - base).sum(-1)
    area = Image.new("L", plate_crop.size, 0)
    ImageDraw.Draw(area).polygon([tuple(p) for p in polygon], fill=255)
    m = (diff > thresh) & (np.asarray(area) > 0)
    m = ndimage.binary_closing(m, iterations=2) & (np.asarray(area) > 0)
    m = ndimage.binary_fill_holes(m)
    lab, n = ndimage.label(m)
    if n:
        sizes = ndimage.sum(m, lab, range(1, n + 1))
        m = lab == (1 + int(np.argmax(sizes)))
    print("  shift", best[1:], "residual", round(float(best[0]), 1))
    return small.astype(np.uint8), m


def matte():
    s = spec()
    plate_crop = crop_plate(s)
    out = CACHE / RUN / "layers"
    out.mkdir(parents=True, exist_ok=True)
    tiles = []
    for f in s["frames"]:
        src = CACHE / RUN / (s["key"]["pick"] if f.get("reuse") == "key" else f["pick"])
        rgb, m = layer_of(Image.open(src), plate_crop, s["polygon"], s.get("threshold", 60))
        rgba = np.dstack([rgb, np.where(m, 255, 0)]).astype(np.uint8)
        Image.fromarray(rgba, "RGBA").save(out / f"{f['id']}.png")
        comp = np.where(m[..., None], rgb, np.asarray(plate_crop))
        tiles.append(Image.fromarray(comp.astype(np.uint8)).resize((plate_crop.width * 3, plate_crop.height * 3), Image.NEAREST))
        print(f["id"], "pixels", int(m.sum()))
    sheet = Image.new("RGB", (sum(t.width for t in tiles), tiles[0].height))
    x = 0
    for t in tiles:
        sheet.paste(t, (x, 0)); x += t.width
    sheet.save(CACHE / RUN / "frames-sheet.png")
    print(CACHE / RUN / "frames-sheet.png")


def pack():
    """One row atlas. Every frame shares the crop's frame, so one anchor (the bench's foot point) fits all."""
    s = spec()
    x0, y0, x1, y1 = s["crop"]
    layers = CACHE / RUN / "layers"
    ims = {f["id"]: Image.open(layers / f"{f['id']}.png") for f in s["frames"]}
    boxes = [im.getbbox() for im in ims.values()]
    bx0, by0 = min(b[0] for b in boxes), min(b[1] for b in boxes)
    bx1, by1 = max(b[2] for b in boxes), max(b[3] for b in boxes)
    fw, fh = bx1 - bx0, by1 - by0
    gut = 2
    atlas = Image.new("RGBA", (gut + len(ims) * (fw + gut), fh + 2 * gut), (0, 0, 0, 0))
    ax, ay = s["anchorPlatePx"]
    cam = s["camera"]
    # Drawn 1:1 with the plate: the standing height the floor gives at her feet, in plate pixels, is her playerHeightPx.
    player_px = round((ay / cam["plateHeight"] - cam["horizonY"]) / cam["eyeHeightAdults"] * cam["plateHeight"])
    ppu = round(player_px / 38.75, 4)
    frames = {}
    for i, (fid, im) in enumerate(ims.items()):
        left = gut + i * (fw + gut)
        atlas.paste(im.crop((bx0, by0, bx1, by1)), (left, gut))
        frames[fid] = {"rect": [left, gut, fw, fh], "anchor": [ax - x0 - bx0, ay - y0 - by0], "pixelsPerUnit": ppu,
                       "facing": "back", "loop": True, "durationBeats": 2.0, "events": [], "supportFoot": "both", "status": "candidate",
                       "provenance": {"run": RUN, "drawing": f"{fid}", "route": "in-place edit of the plate, tool/art/rooms/pianist.py"}}
    for fid, src in s.get("aliases", {}).items():  # the band ladder's other names, the same drawings
        frames[fid] = {**frames[src], "provenance": {**frames[src]["provenance"], "puppet": f"same drawing as {src}"}}
    out = REPO / "assets/art/ensemble/band-piano-v1.png"
    atlas.save(out)
    entry = {"image": out.name, "imageWidth": atlas.width, "imageHeight": atlas.height, "referenceFrame": "relaxed_a",
             "playerHeightPx": player_px, "frames": frames}
    man = REPO / "assets/art/ensemble/manifest.json"
    doc = json.loads(man.read_text())
    doc["atlases"]["band-piano"] = entry
    man.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n")
    print(out, atlas.size, "frame", fw, fh, "top-left on plate", x0 + bx0, y0 + by0)


if __name__ == "__main__":
    cmd = sys.argv[1]
    {"stage": lambda: stage(sys.argv[2]), "matte": matte, "pack": pack}[cmd]()
