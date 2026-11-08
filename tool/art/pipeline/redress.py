#!/usr/bin/env python3
"""Change what a finished atlas's person wears, frame by frame, keeping pose, timing, frame count and atlas layout.

Each drawing is cut from the shipped atlas, set on a flat backdrop in the 256 by 320 native canvas with its floor anchor
at a fixed point, and grown x3 by nearest neighbour. Qwen-Image-Edit then redresses it: first one key drawing from words
alone, then every other drawing from two pictures, the drawing itself and the accepted key ("wear exactly what picture 2
wears"), so the outfit holds from frame to frame. Back at native size each drawing is keyed off the backdrop, snapped to the
character's locked palette (finish_local.py) and packed into the same rects at the same anchors, so the manifest's frame ids,
anchors and pixelsPerUnit stay what the game already plays.

  redress.py <spec> stage key|frames [ids]  bake jobs into art_runs/<run>/ (run them with tool/art/rooms/run_room_jobs.py)
  redress.py <spec> sheet                   every candidate, keyed and finished, beside the old drawing, to the cache
  redress.py <spec> pack                    the picks into assets/art/ensemble/<atlas>-v1.png and the manifest

Spec: tool/art/redress/<atlas>.json. First use: the billiards room's background players (plan/levels/dress-code-2026-11-08.md).
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
sys.path.insert(0, str(REPO / "tool/art/rooms"))
from finish_local import finish, palette_of  # noqa: E402
from finish_run_picks import compress  # noqa: E402
from plates import bake_workflow  # noqa: E402

CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"
STAGE = Path("/work/tmp/imagegen/kumbia")
MANIFEST = REPO / "assets/art/ensemble/manifest.json"
NATIVE = (256, 320)
FOOT = (128, 312)  # where every drawing's floor anchor sits on the native canvas
SCALE = 3


def load(path):
    s = json.loads(Path(path).read_text())
    s["_path"] = str(path)
    return s


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def atlas_entry(s):
    return json.loads(MANIFEST.read_text())["atlases"][s["atlas"]]


def unique_frames(entry):
    """Frame ids that own a drawing; aliases (same rect) are left to follow their source."""
    seen, out = {}, []
    for fid, f in entry["frames"].items():
        key = tuple(f["rect"])
        if key not in seen:
            seen[key] = fid
            out.append(fid)
    return out, {fid: seen[tuple(f["rect"])] for fid, f in entry["frames"].items() if seen[tuple(f["rect"])] != fid}


def offset(frame):
    ax, ay = frame["anchor"]
    return round(FOOT[0] - ax), round(FOOT[1] - ay)


def native_drawing(s, fid, image=None):
    entry = atlas_entry(s)
    atlas = image or Image.open(REPO / "assets/art/ensemble" / entry["image"]).convert("RGBA")
    f = entry["frames"][fid]
    x, y, w, h = f["rect"]
    canvas = Image.new("RGBA", NATIVE, (0, 0, 0, 0))
    canvas.alpha_composite(atlas.crop((x, y, x + w, y + h)), offset(f))
    return canvas


def staged_input(s, fid):
    over = Image.new("RGBA", NATIVE, rgb(s["backdrop"]) + (255,))
    over.alpha_composite(native_drawing(s, fid))
    return over.convert("RGB").resize((NATIVE[0] * SCALE, NATIVE[1] * SCALE), Image.NEAREST)


def stage(s, which, only=""):
    run = s["run"]
    out = REPO / "art_runs" / run
    (out / "workflows").mkdir(parents=True, exist_ok=True)
    st = STAGE / run / "in"
    st.mkdir(parents=True, exist_ok=True)
    size = (NATIVE[0] * SCALE, NATIVE[1] * SCALE)
    jobs = []
    if which == "key":
        k = s["key"]
        staged_input(s, k["frame"]).save(st / f"{k['frame']}.png")
        text = f"{k['prompt']} {s['keepWords']}"
        wf = bake_workflow(["base"], text, f"kk/{run}/key", 4, size)
        path = out / "workflows" / "key.api.json"
        path.write_text(json.dumps(wf, indent=1, ensure_ascii=False) + "\n")
        (out / "workflows" / "key.prompt.txt").write_text(text + "\n")
        jobs.append(dict(name="key", workflow=str(path.relative_to(REPO)), inputs={"base": str(st / f"{k['frame']}.png")},
                         overrides={"seed": k["seed"]}, count=k["count"]))
        pass_no = 2
    else:
        shutil.copy(CACHE / run / s["key"]["pick"], st / "key.png")
        ids, _ = unique_frames(atlas_entry(s))
        ids = [i for i in ids if i not in s.get("derive", {}) and i != s["key"]["frame"] and (not only or i in only.split(","))]
        text = f"{s['framePrompt']} {s['keepWords']}"
        wf = bake_workflow(["layout", "style"], text, f"kk/{run}/frame", 4, size)
        path = out / "workflows" / "frame.api.json"
        path.write_text(json.dumps(wf, indent=1, ensure_ascii=False) + "\n")
        (out / "workflows" / "frame.prompt.txt").write_text(text + "\n")
        for fid in ids:
            staged_input(s, fid).save(st / f"{fid}.png")
            jobs.append(dict(name=fid, workflow=str(path.relative_to(REPO)), inputs={"layout": str(st / f"{fid}.png"), "style": str(st / "key.png")},
                             overrides={"seed": s["frameSeed"]}, count=s["count"]))
        pass_no = 1  # two input pictures: run_room_jobs stands in the billiards p1 graph
    doc = dict(room="billiards", run=run, passNo=pass_no, steps=4, jobs=jobs, how="tool/art/rooms/run_room_jobs.py --jobs <this file>")
    f = out / f"jobs-{which}.json"
    f.write_text(json.dumps(doc, indent=1) + "\n")
    print(f.relative_to(REPO), len(jobs), "jobs")


def shift_to(drawn, ref_big, backdrop):
    """Undo Qwen's small whole-picture shift, matching the backdrop outside the old figure."""
    big = np.asarray(drawn.convert("RGB"), float)
    ref = np.asarray(ref_big, float)
    bg = (np.abs(ref - np.array(backdrop, float)).sum(-1) < 6)
    # The backdrop is flat, so it can't fix a shift: match a band around the old figure's outline instead.
    edge = ndimage.binary_dilation(~bg, iterations=2) & ~ndimage.binary_erosion(~bg, iterations=40)

    def err2(dy, dx):
        return float(np.abs(np.roll(big, (dy, dx), axis=(0, 1)) - ref).sum(-1)[edge][::3].mean())
    best = min((err2(dy, dx), dy, dx) for dy in range(-24, 25, 3) for dx in range(-24, 25, 3))
    best = min((err2(dy, dx), dy, dx) for dy in range(best[1] - 2, best[1] + 3) for dx in range(best[2] - 2, best[2] + 3))
    return Image.fromarray(np.roll(big, best[1:], axis=(0, 1)).astype(np.uint8)), best


def key_off(big, backdrop, tol):
    """RGBA at x3: the backdrop's colour, where it touches the border, becomes transparent; pockets of it too if large."""
    a = np.asarray(big.convert("RGB")).astype(int)
    near = np.abs(a - np.array(backdrop)).max(-1) <= tol
    lab, n = ndimage.label(near)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    clear = np.isin(lab, list(border))
    if n:
        sizes = ndimage.sum(near, lab, range(1, n + 1))
        clear |= np.isin(lab, [i + 1 for i, z in enumerate(sizes) if z >= 30 * SCALE * SCALE])
    body = ~clear
    lab, n = ndimage.label(body)
    if n > 1:
        sizes = ndimage.sum(body, lab, range(1, n + 1))
        keep = [i + 1 for i, z in enumerate(sizes) if z >= max(sizes) * 0.004]
        body = np.isin(lab, keep)
    return Image.fromarray(np.dstack([a, np.where(body, 255, 0)]).astype(np.uint8), "RGBA")


def finished(s, fid, src):
    old = staged_input(s, fid)
    aligned, best = shift_to(Image.open(src), old, rgb(s["backdrop"]))
    rgba = key_off(aligned, rgb(s["backdrop"]), s.get("tolerance", 26))
    return finish_image(rgba, s), best


def finish_image(rgba, s):
    if not s.get("palette"):  # before the palette is locked: the native grid only, colours as drawn
        a = np.asarray(rgba)
        s_ = a[SCALE // 2::SCALE, SCALE // 2::SCALE].copy()
        s_[..., 3] = np.where(s_[..., 3] >= 128, 255, 0)
        return Image.fromarray(s_, "RGBA")
    tmp = CACHE / s["run"] / "_tmp.png"
    rgba.save(tmp)
    return finish(tmp, palette_of(REPO / s["palette"]), SCALE)


def candidates(s, fid):
    if fid == s["key"]["frame"]:
        return sorted((CACHE / s["run"]).glob("key-*.png"))
    return sorted((CACHE / s["run"]).glob(f"{fid}-*.png"))


def on(im, colour=(58, 74, 60)):
    bg = Image.new("RGBA", im.size, colour + (255,))
    bg.alpha_composite(im)
    return bg.convert("RGB")


def sheet(s):
    ids, _ = unique_frames(atlas_entry(s))
    rows = []
    for fid in ids:
        if fid in s.get("derive", {}):
            continue
        cells = [native_drawing(s, fid)]
        for c in candidates(s, fid):
            im, best = finished(s, fid, c)
            cells.append(im)
            print(fid, c.name, "shift", best[1:], round(best[0], 1))
        rows.append(cells)
    w = NATIVE[0] * max(len(r) for r in rows)
    out = Image.new("RGB", (w, NATIVE[1] * len(rows)), (30, 30, 30))
    for j, r in enumerate(rows):
        for i, im in enumerate(r):
            out.paste(on(im), (i * NATIVE[0], j * NATIVE[1]))
    path = CACHE / s["run"] / "candidates-sheet.png"
    out.save(path)
    print(path)


def pack(s):
    doc = json.loads(MANIFEST.read_text())
    entry = doc["atlases"][s["atlas"]]
    ids, aliases = unique_frames(entry)
    finals = {}
    for fid in ids:
        if fid in s.get("derive", {}):
            continue
        pick = s["picks"][fid]
        finals[fid], _ = finished(s, fid, CACHE / s["run"] / pick)
    for fid, how in s.get("derive", {}).items():
        finals[fid] = compress(finals[how["from"]])
    for fid, edit in s.get("handEdits", {}).items():
        a = np.asarray(finals[fid]).copy()
        for x, y, w, h in edit.get("clear", []):  # native-canvas boxes to clear: a stray the keyer kept
            a[y:y + h, x:x + w] = 0
        finals[fid] = Image.fromarray(a, "RGBA")
    # Each drawing keeps its rect where it fits; anything that grew gets a fresh shelf below, and the anchor follows.
    rects = {}
    grow = []
    for fid in ids:
        f = entry["frames"][fid]
        x, y, w, h = f["rect"]
        ox, oy = offset(f)
        bbox = finals[fid].getbbox()
        inside = bbox[0] >= ox and bbox[1] >= oy and bbox[2] <= ox + w and bbox[3] <= oy + h
        if inside:
            rects[fid] = ([x, y, w, h], (ox, oy))
        else:
            grow.append(fid)
    width, height = entry["imageWidth"], entry["imageHeight"]
    cx, cy, shelf = 2, height + 1, 0
    for fid in grow:
        f = entry["frames"][fid]
        ox, oy = offset(f)
        x, y, w, h = f["rect"]
        bx0, by0, bx1, by1 = finals[fid].getbbox()
        nx0, ny0 = min(bx0, ox), min(by0, oy)
        nx1, ny1 = max(bx1, ox + w), max(by1, oy + h)
        nw, nh = nx1 - nx0, ny1 - ny0
        if cx + nw > width:
            cx, cy, shelf = 2, cy + shelf + 2, 0
        rects[fid] = ([cx, cy, nw, nh], (nx0, ny0))
        cx += nw + 2
        shelf = max(shelf, nh)
    height = max(height, cy + shelf + 2) if grow else height
    atlas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for fid in ids:
        (x, y, w, h), (ox, oy) = rects[fid]
        atlas.alpha_composite(finals[fid].crop((ox, oy, ox + w, oy + h)), (x, y))
        f = entry["frames"][fid]
        old_ox, old_oy = offset(f)
        f["anchor"] = [round(f["anchor"][0] + old_ox - ox, 1), round(f["anchor"][1] + old_oy - oy, 1)]
        f["rect"] = [x, y, w, h]
        f["provenance"] = {**{k: v for k, v in f["provenance"].items() if k not in ("sha256",)},
                           "redress": {"run": s["run"], "drawing": s["picks"].get(fid, f"derived from {s.get('derive', {}).get(fid, {}).get('from')}"),
                                       "route": "Qwen edit of the shipped drawing, tool/art/pipeline/redress.py", "accepted": True}}
    for fid, src in aliases.items():
        entry["frames"][fid]["rect"] = list(entry["frames"][src]["rect"])
        entry["frames"][fid]["anchor"] = list(entry["frames"][src]["anchor"])
        entry["frames"][fid]["provenance"] = entry["frames"][src]["provenance"]
    entry["imageWidth"], entry["imageHeight"] = atlas.width, atlas.height
    if s.get("ramps"):
        entry["ramps"] = s["ramps"]
    out = REPO / "assets/art/ensemble" / entry["image"]
    atlas.save(out, optimize=True)
    MANIFEST.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n")
    print(out.relative_to(REPO), atlas.size, "grown:", grow or "none")


if __name__ == "__main__":
    s = load(sys.argv[1])
    cmd = sys.argv[2]
    {"stage": lambda: stage(s, sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else ""), "sheet": lambda: sheet(s), "pack": lambda: pack(s)}[cmd]()
