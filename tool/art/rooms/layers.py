"""Split a painted plate into a clean plate and separately drawn props.

Input is a room's layer spec, tool/art/rooms/layers/<room>.json. Mattes come from hand-placed polygons
and a colour rule. Fills come from Qwen removal runs, pasted only under the matte, and frames bend the
prop's own pixels, so at rest plate + props match the painted original. "Layers" in
tool/art/rooms/README.md has the route and what failed.

  layers.py matte <room>     each prop's matte and a review sheet
  layers.py crops <room>     stage crops and bake a removal workflow for each prop with a fill prompt
  layers.py plate <room>     paste the fills into the plate, and report the seam
  layers.py frames <room>    bake the atlas, and write the level's "layers" block
  layers.py sheet <room>     phone-size before and after, at rest and at both extremes
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage, sparse
import scipy.sparse.linalg  # noqa: F401  (makes sparse.linalg available)

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"
GUTTER = 2  # RoomLayerProp.gutter
PHONE = (390, 844)


def load_spec(room):
    return json.loads((HERE / "layers" / f"{room}.json").read_text())


def source_rgb(spec):
    return np.asarray(Image.open(REPO / spec["source"]).convert("RGB"))


def polygon_mask(size, points):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon([tuple(p) for p in points], fill=255)
    return np.asarray(mask) > 0


def colour_rule(rgb, rule):
    """True where a pixel belongs to the prop rather than to what's behind it."""
    r, g, b = [rgb[..., i].astype(float) for i in range(3)]
    if rule == "not-sky":  # navy sky and clouds have blue far above green; a dark teal frond doesn't, and near-black is frond too
        return ~((b > g * 1.7) & (b > r * 1.7) & (b > 55))
    if rule == "all":
        return np.ones(rgb.shape[:2], bool)
    if rule == "foliage":  # green over warm plaster or wood
        return (g > r * 1.02) & (g > b * .85)
    if rule == "water":  # cyan and its pale glints; beige columns have far less blue than green
        return (b >= g * .92) & (b > 120)
    if rule == "string":  # a dark wire with yellow bulbs
        return (np.maximum(np.maximum(r, g), b) < 70) | ((g > 185) & (b < 120) & (r > 200))
    if rule == "lantern":  # amber glass and near-black iron over violet: violet keeps blue above red
        return (r > b * 1.12) | (np.maximum(np.maximum(r, g), b) < 42)
    if rule == "bright":  # crystal and candle flames over emerald wall and a near-black ceiling: bright, and not green
        return (np.maximum(np.maximum(r, g), b) > 105) & ~((g > r * 1.15) & (g > b))
    if rule == "bulb":  # festoon bulbs against a night sky: bright and warm, red well above blue
        return (np.maximum(np.maximum(r, g), b) > 150) & (r > b + 8)
    if rule == "crystal":  # crystal, brass and candle flames over red damask: bright, and green well above a red wall's
        return (np.maximum(np.maximum(r, g), b) > 100) & (g > r * .5)
    if rule == "marble":  # a white marble figure in a lit cream niche: bright and nearly grey
        mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
        return (mx > 110) & (mx - mn < 45)
    raise ValueError(rule)


def matte(rgb, prop):
    """The prop's hard matte: polygon and colour rule, gaps closed, specks dropped."""
    h, w = rgb.shape[:2]
    area = polygon_mask((w, h), prop["polygon"])
    keep = area & colour_rule(rgb, prop.get("rule", "all"))
    keep = ndimage.binary_closing(keep, iterations=prop.get("close", 1)) & area
    labels, n = ndimage.label(keep)
    if n:
        sizes = ndimage.sum(keep, labels, range(1, n + 1))
        keep = np.isin(labels, 1 + np.flatnonzero(sizes >= prop.get("minSpeck", 12)))
    return keep


def bbox(mask, pad=0):
    ys, xs = np.nonzero(mask)
    return int(xs.min()) - pad, int(ys.min()) - pad, int(xs.max()) + 1 + pad, int(ys.max()) + 1 + pad


def cmd_matte(room):
    spec = load_spec(room)
    rgb = source_rgb(spec)
    im = Image.fromarray(rgb)
    out = CACHE / spec["run"] / "mattes"
    out.mkdir(parents=True, exist_ok=True)
    tiles = []
    for prop in spec["props"]:
        m = matte(rgb, prop)
        box = bbox(m, 6)
        box = (max(box[0], 0), max(box[1], 0), min(box[2], rgb.shape[1]), min(box[3], rgb.shape[0]))
        vis = rgb.copy()
        vis[~m] = (vis[~m] * .25 + np.array([120, 0, 120]) * .75).astype("uint8")
        a, b = im.crop(box), Image.fromarray(vis).crop(box)
        tile = Image.new("RGB", (a.width * 2 + 4, a.height))
        tile.paste(a, (0, 0))
        tile.paste(b, (a.width + 4, 0))
        tiles.append(tile.resize((tile.width * 2, tile.height * 2), Image.NEAREST))
        print(prop["id"], "box", box, "pixels", int(m.sum()))
    sheet = Image.new("RGB", (max(t.width for t in tiles), sum(t.height + 6 for t in tiles)), (30, 30, 30))
    y = 0
    for t in tiles:
        sheet.paste(t, (0, y))
        y += t.height + 6
    sheet.save(out / "sheet.png")
    print(out / "sheet.png")


def seamless(plate, art, mask, clamp=24.0):
    """Poisson clone: keep the fill's detail, and make its edge equal the plate's.

    The model drifts in tone across a crop, so one flat colour shift left a tinted patch beside a bright
    lamp. This solves for a smooth correction that meets the plate at the mask's edge. Each edge difference
    is clamped: where the edge crosses something the fill doesn't have, like a frond left in the plate, an
    unclamped solve smears that colour across the whole fill. A prop that lit its surroundings, like a lantern,
    needs a wider clamp, or the glow it left behind shows the mask as a hard shape.
    """
    h, w = mask.shape
    index = -np.ones((h, w), int)
    ys, xs = np.nonzero(mask)
    index[ys, xs] = np.arange(len(ys))
    rows, cols, vals = [], [], []
    rhs = np.zeros((len(ys), 3))
    for i, (y, x) in enumerate(zip(ys, xs)):
        rows.append(i), cols.append(i), vals.append(4.0)
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if not (0 <= ny < h and 0 <= nx < w):
                rows.append(i), cols.append(i), vals.append(-1.0)
                continue
            if mask[ny, nx]:
                rows.append(i), cols.append(index[ny, nx]), vals.append(-1.0)
            else:
                rhs[i] += np.clip(plate[ny, nx] - art[ny, nx], -clamp, clamp)
    solve = sparse.linalg.factorized(sparse.csc_matrix((vals, (rows, cols)), shape=(len(ys), len(ys))))
    out = plate.copy()
    for c in range(3):
        out[ys, xs, c] = art[ys, xs, c] + solve(rhs[:, c])
    return out


def build_plate(spec):
    """The source with each filled prop's dilated matte replaced by its fill, seamlessly."""
    rgb = source_rgb(spec)
    plate = rgb.astype(float)
    report = {}
    h, w = rgb.shape[:2]
    for prop in spec["props"]:
        fill = prop.get("fill")
        if not fill:
            continue
        mask = polygon_mask((w, h), fill["polygon"]) if "polygon" in fill else matte(rgb, prop)
        mask = ndimage.binary_dilation(mask, iterations=fill.get("dilate", 2))
        if fill.get("tile"):  # a plain repeating surface (a tablecloth's folds): tile a clean strip of the source across
            sx0, sy0, sx1, sy1 = fill["tile"]
            strip = rgb[sy0:sy1, sx0:sx1].astype(float)
            layer = plate.copy()
            ys, xs = np.nonzero(mask)
            layer[ys, xs] = strip[np.clip(ys - sy0, 0, sy1 - sy0 - 1), (xs - sx0) % (sx1 - sx0)]
            plate = seamless(plate, layer, mask, fill.get("edgeClamp", 24.0))
            report[prop["id"]] = dict(maskPixels=int(mask.sum()), route="tile")
            continue
        if fill.get("harmonic"):  # thin things only: a wire and its bulbs close up from their edges, with no GPU
            plate = seamless(plate, np.full_like(plate, plate[mask].mean()), mask, 1000.0)
            report[prop["id"]] = dict(maskPixels=int(mask.sum()), route="harmonic")
            continue
        x0, y0, x1, y1 = fill["box"]
        keep = np.zeros(mask.shape, bool)
        keep[max(y0, 0):y1, max(x0, 0):x1] = True
        if (mask & ~keep).any():
            raise SystemExit(f"{prop['id']}: its mask leaves the fill's box")
        art = np.asarray(Image.open(CACHE / spec["run"] / fill["image"]).convert("RGB").resize((x1 - x0, y1 - y0), Image.BOX), float)
        layer = plate.copy()
        top, left = max(-y0, 0), max(-x0, 0)
        layer[max(y0, 0):y1, max(x0, 0):x1] = art[top:, left:]
        cap = fill.get("cap")
        if cap:  # the model redraws a ledge a little wider than the real one, so keep only what's above it
            layer[cap["top"]:y1, x0:x1] = layer[cap["top"] - 1, x0:x1]
        plate = seamless(plate, layer, mask, fill.get("edgeClamp", 24.0))
        if cap:  # and rebuild the ledge's hidden strip from clean stone just below the prop
            cx0, cy0, cx1, cy1 = cap["box"]
            stone = ndimage.uniform_filter1d(plate[cap["fromRow"], cx0:cx1], 15, axis=0, mode="nearest")  # no streaks
            plate[cy0:cy1, cx0:cx1] = stone
        drift = np.abs(plate[mask] - layer[mask]).mean(axis=0)
        report[prop["id"]] = dict(meanCorrection=[round(float(v), 1) for v in drift], maskPixels=int(mask.sum()))
    return np.clip(plate + .5, 0, 255).astype("uint8"), report


def cmd_crops(room):
    """Stage each prop's crop and bake its removal workflow. Queue them with studio.run_workflow, one at a time."""
    from plates import STAGE, bake_workflow
    spec = load_spec(room)
    rgb = Image.fromarray(source_rgb(spec))
    run, stage = spec["run"], STAGE / spec["run"] / "in"
    stage.mkdir(parents=True, exist_ok=True)
    out = REPO / "art_runs/rooms/layers" / room
    out.mkdir(parents=True, exist_ok=True)
    for prop in spec["props"]:
        drawn = prop.get("drawn") or {}
        if "prompt" in drawn:  # a drawn prop: the crop at 3x, edited, so inplace.align can find it again
            x0, y0, x1, y1 = drawn["box"]
            size = ((x1 - x0) * 3, (y1 - y0) * 3)
            rgb.crop(drawn["box"]).resize(size, Image.NEAREST).save(stage / f"{prop['id']}.png")
            wf = bake_workflow(["base"], drawn["prompt"] + " " + spec["keepWords"], f"kk/{run}/{prop['id']}", 4, size)
            (out / f"{prop['id']}.api.json").write_text(json.dumps(wf, indent=1, ensure_ascii=False) + "\n")
            print(prop["id"], "drawn", stage / f"{prop['id']}.png", out / f"{prop['id']}.api.json")
        fill = prop.get("fill") or {}
        if "prompt" not in fill:
            continue
        rgb.crop(fill["box"]).resize((832, 832), Image.LANCZOS).save(stage / f"{prop['id']}.png")
        wf = bake_workflow(["base"], fill["prompt"] + " " + spec["keepWords"], f"kk/{run}/{prop['id']}", 4, (832, 832))
        (out / f"{prop['id']}.api.json").write_text(json.dumps(wf, indent=1, ensure_ascii=False) + "\n")
        print(prop["id"], stage / f"{prop['id']}.png", out / f"{prop['id']}.api.json")


def cmd_plate(room):
    spec = load_spec(room)
    plate, report = build_plate(spec)
    out = REPO / spec["plate"]
    Image.fromarray(plate).save(out, optimize=True)
    for k, v in report.items():
        print(k, v)
    print(out, out.stat().st_size // 1024, "KB")


def warp_frame(rgb, alpha, warp, v):
    """Bend the prop about its pivot: nothing at the pivot, the full reach at its far end."""
    h, w = alpha.shape
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    if "sag" in warp:  # a string held at both ends: nothing at the ends, the most in the middle
        x0, x1 = warp["sag"]["between"]
        drop = v * warp["sag"]["px"] * np.sin(np.pi * np.clip((xs - x0) / (x1 - x0), 0, 1))
        iy = np.clip(np.round(ys - drop).astype(int), 0, h - 1)
        return rgb[iy, xs.astype(int)], alpha[iy, xs.astype(int)]
    if "glow" in warp:  # a bulb that brightens on the beat: the same pixels, warmer and brighter, nothing moves
        g = warp["glow"]
        lift = 1 + v * g.get("gain", .3)
        warm = np.array(g.get("tint", [1.0, .96, .82]))
        out = rgb.astype(float)
        out[alpha] = np.clip(out[alpha] * lift * (1 + v * (warm - 1)) + v * g.get("add", 18), 0, 255)
        if g.get("grow") and v >= .5:  # at the peak a one-pixel halo of the bulb's light round each bulb
            ring = ndimage.binary_dilation(alpha, iterations=g["grow"]) & ~alpha
            halo = np.array(g.get("halo", [255, 186, 92]), float)
            out[ring] = out[ring] * (1 - .55 * v) + halo * .55 * v
            return out.astype("uint8"), alpha | ring
        return out.astype("uint8"), alpha
    if "wave" in warp:  # ripples across a surface
        shift = v * warp["wave"]["px"] * np.sin(2 * np.pi * ys / warp["wave"]["every"] + xs / warp["wave"].get("along", 40))
        ix = np.clip(np.round(xs + shift).astype(int), 0, w - 1)
        return rgb[ys.astype(int), ix], alpha[ys.astype(int), ix]
    px, py = warp["pivot"]
    far = warp["far"]
    dx, dy = xs - px, ys - py
    r = np.hypot(dx, dy)
    theta = v * warp.get("reachPx", 0) / far * (r / far) ** (warp.get("power", 1.5) - 1)
    c, s = np.cos(-theta), np.sin(-theta)
    stretch = 1 + v * warp.get("stretchPx", 0) / far  # > 1 reaches away from the pivot
    sx = px + (dx * c - dy * s)
    sy = py + (dx * s + dy * c) / stretch
    ix = np.clip(np.round(sx).astype(int), 0, w - 1)
    iy = np.clip(np.round(sy).astype(int), 0, h - 1)
    return rgb[iy, ix], alpha[iy, ix]


def frame_values(prop):
    n = prop["frames"]
    if prop["motion"] == "sway":
        mid = n // 2
        return [(i - mid) / mid for i in range(n)]
    return [i / (n - 1) for i in range(n)]


def drawn_frames(rgb, prop):
    """Frames that are drawings: Qwen edits of the prop's box, each cut to the polygon. The first frame is the plate
    itself, so at rest nothing differs. Each edit is aligned to the plate around the polygon first, as inplace.py does."""
    from inplace import align
    d = prop["drawn"]
    x0, y0, x1, y1 = d["box"]
    base = Image.fromarray(rgb).crop((x0, y0, x1, y1))
    poly = [[px - x0, py - y0] for px, py in prop["polygon"]]
    area = polygon_mask(base.size, poly)
    frames = [np.asarray(base)]
    for name in d["images"]:
        small, _ = align(Image.open(CACHE / prop.get("run", d.get("run", "")) / name), base, [poly])
        frames.append(np.where(area[..., None], small, np.asarray(base)).astype("uint8"))
    # The whole polygon, opaque: its rest frame is the plate itself, and a ragged changed-pixels mask would mix the
    # plate and the edit at the peak.
    keep = area
    bx0, by0, bx1, by1 = bbox(keep, 1)
    out = []
    for f in frames:
        fr = np.zeros((by1 - by0, bx1 - bx0, 4), "uint8")
        fr[..., :3] = f[by0:by1, bx0:bx1]
        fr[..., 3] = keep[by0:by1, bx0:bx1] * 255
        fr[fr[..., 3] == 0] = 0
        out.append(fr)
    return (x0 + bx0, y0 + by0, bx1 - bx0, by1 - by0), out


def prop_frames(rgb, prop):
    """All frames on the full plate's grid, cropped to a box that holds the prop at any frame."""
    if "drawn" in prop:
        return drawn_frames(rgb, prop)
    h, w = rgb.shape[:2]
    m = matte(rgb, prop)
    warped = [warp_frame(rgb, m, prop["warp"], v) for v in frame_values(prop)]
    if prop.get("keepInside"):  # panes of a lantern: what moves stays behind the glass
        warped = [(c, m) for c, _ in warped]
    union = np.zeros((h, w), bool)
    for _, a in warped:
        union |= a
    x0, y0, x1, y1 = bbox(union)
    frames = []
    for c, a in warped:
        out = np.zeros((y1 - y0, x1 - x0, 4), "uint8")
        out[..., :3] = c[y0:y1, x0:x1]
        out[..., 3] = a[y0:y1, x0:x1].astype("uint8") * 255
        out[out[..., 3] == 0] = 0
        frames.append(out)
    return (x0, y0, x1 - x0, y1 - y0), frames


def bake(spec):
    rgb = source_rgb(spec)
    rows = []
    for prop in spec["props"]:
        if prop.get("fillOnly"):  # painted out of the plate and never drawn again, such as a reflection in the tap band
            continue
        rows.append((prop, *prop_frames(rgb, prop)))
    width = max(len(f) * (b[2] + GUTTER) for _, b, f in rows)
    height = sum(b[3] + GUTTER for _, b, _f in rows)
    atlas = np.zeros((height, width, 4), "uint8")
    y = 0
    entries = []
    for prop, (left, top, w, h), frames in rows:
        for i, frame in enumerate(frames):
            x = i * (w + GUTTER)
            atlas[y:y + h, x:x + w] = frame
        entries.append(dict(id=prop["id"], atlas=spec["atlas"].removeprefix("assets/art/"), atlasY=y, left=left, top=top, width=w, height=h,
                            frames=len(frames), motion=prop["motion"], periodBeats=prop["periodBeats"], instance=prop["instance"], kind=prop["kind"],
                            **{k: prop[k] for k in ("minTier", "phaseBeats") if k in prop}))
        y += h + GUTTER
    return atlas, entries, rows


def cmd_frames(room):
    spec = load_spec(room)
    atlas, entries, _ = bake(spec)
    out = REPO / spec["atlas"]
    Image.fromarray(atlas).save(out, optimize=True)
    print(out, atlas.shape, out.stat().st_size // 1024, "KB")
    level = REPO / spec["level"]
    text = level.read_text()
    text = re.sub(r',\n  "layers": \{.*?\n  \}(?=\n\})', "", text, flags=re.S)
    lines = ",\n".join("      " + json.dumps(e, ensure_ascii=False) for e in entries)
    h, w = source_rgb(spec).shape[:2]
    block = f'  "layers": {{\n    "plateWidth": {w},\n    "plateHeight": {h},\n    "props": [\n{lines}\n    ]\n  }}'
    text = re.sub(r"\n\}\s*$", ",\n" + block + "\n}\n", text)
    text = re.sub(r'("background": ")[^"]*(")', lambda m: m[1] + spec["plate"].removeprefix("assets/art/") + m[2], text, count=1)
    json.loads(text)
    level.write_text(text)
    for e in entries:
        print(e)


def composite(plate, rows, pick):
    """The plate with each prop at the frame `pick(prop, frames)` gives."""
    out = Image.fromarray(plate).convert("RGBA")
    for prop, (left, top, _w, _h), frames in rows:
        out.alpha_composite(Image.fromarray(frames[pick(prop, frames)]), (left, top))
    return out.convert("RGB")


def phone(im, scale=PHONE):
    W, H = im.size
    vw = int(round(H * scale[0] / scale[1]))
    x = (W - vw) // 2
    return im.crop((x, 0, x + vw, H)).resize(scale, Image.BOX)


def cmd_sheet(room):
    spec = load_spec(room)
    source = Image.open(REPO / spec["source"]).convert("RGB")
    plate = np.asarray(Image.open(REPO / spec["plate"]).convert("RGB"))
    _, _, rows = bake(spec)
    rest = lambda prop, f: len(f) // 2 if prop["motion"] == "sway" else 0
    low = lambda prop, f: 0
    high = lambda prop, f: len(f) - 1
    views = [("painted original", source), ("clean plate", Image.fromarray(plate)), ("plate + props at rest", composite(plate, rows, rest)),
             ("one extreme", composite(plate, rows, low)), ("other extreme", composite(plate, rows, high))]
    a = np.asarray(phone(source), float)
    b = np.asarray(phone(views[2][1]), float)
    print("rest against original at phone size: mean", round(float(np.abs(a - b).mean()), 3), "max", int(np.abs(a - b).max()))
    gap = 8
    crop_h = int(PHONE[1] * .42)
    sheet = Image.new("RGB", (len(views) * (PHONE[0] + gap), PHONE[1] + 22 + crop_h * 2 + gap), (24, 24, 24))
    d = ImageDraw.Draw(sheet)
    for i, (name, view) in enumerate(views):
        x = i * (PHONE[0] + gap)
        d.text((x + 4, 4), name, fill=(255, 255, 255))
        small = phone(view)
        sheet.paste(small, (x, 22))
        # The same phone pixels, doubled, so the top of the room can be judged closely.
        sheet.paste(small.crop((0, 0, PHONE[0], crop_h)).resize((PHONE[0], crop_h * 2), Image.NEAREST), (x, 22 + PHONE[1] + gap))
    out = CACHE / spec["run"] / "before-after.png"
    sheet.save(out)
    print(out, sheet.size)
    motion_preview(spec, plate, rows, CACHE / spec["run"] / "motion.gif")


def preview_frame(prop, frames, beat, swing):
    """RoomLayerProp.frameAt and partyPropStrength, for a preview only: the game's own code is the rule."""
    wake = (prop["instance"] * .371 % 1) * .35
    strength = min(max((swing - wake) / (1 - wake), 0), 1)
    on_beat = np.cos(2 * np.pi * (beat - prop.get("phaseBeats", 0)) / prop["periodBeats"])
    if prop["motion"] == "sway":
        mid = len(frames) // 2
        return mid + int(np.floor(mid * strength * on_beat + .5))
    return int(np.floor((len(frames) - 1) * strength * (1 + on_beat) / 2 + .5))


def motion_preview(spec, plate, rows, out, bpm=None, fps=12):
    """The top of a phone's view through the awakening: swing 0, then growing, then full. For a person's eye."""
    bpm = bpm or spec.get("previewBpm", 120)
    images = []
    seconds = 16
    for i in range(seconds * fps):
        t = i / fps
        swing = min(max((t - 2) / 8, 0), 1)
        swing = swing ** 3 * (swing * (6 * swing - 15) + 10)  # quintic, as CrowdEngagement.reveal
        beat = t * bpm / 60
        view = phone(composite(plate, rows, lambda prop, f: preview_frame(prop, f, beat, swing)))
        images.append(view.crop((0, 0, PHONE[0], int(PHONE[1] * .42))).convert("P", palette=Image.ADAPTIVE, colors=128))
    images[0].save(out, save_all=True, append_images=images[1:], duration=int(1000 / fps), loop=0, optimize=True)
    print(out, out.stat().st_size // 1024, "KB")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["matte", "crops", "plate", "frames", "sheet"])
    parser.add_argument("room")
    args = parser.parse_args()
    {"matte": cmd_matte, "crops": cmd_crops, "plate": cmd_plate, "frames": cmd_frames, "sheet": cmd_sheet}[args.command](args.room)


if __name__ == "__main__":
    main()
