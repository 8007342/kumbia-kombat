"""Paint a room's floor apart from its walls, for a true grid and a calm surface. Words failed on it twice.

The plate keeps everything above the floor. Below, slabs and joints are drawn from the room's camera, so they
can't drift, and the room's own walls and lamps are mirrored into the polish: verticals stay vertical in this
camera, so a mirror about each column's contact line is the true reflection. `floors/<room>.json` holds the
trace and the look. `README.md`, "Floors".

  floor.py matte <room> <plate-id>     the floor's matte on the plate, for checking the trace
  floor.py paint <room> <plate-id>     the finished composite, in the run's cache folder
  floor.py texture <room> <image> ...  use a flat painted slab texture instead of the procedural one
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

from compiler import Camera, load_spec

HERE = Path(__file__).resolve().parent
CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"
W, H = 1024, 1536


def load(room):
    spec = json.loads((HERE / "floors" / f"{room}.json").read_text())
    return spec, Camera(load_spec(room)["camera"])


def source(spec, plate):
    raw = Image.open(CACHE / spec["plates"][plate]["image"]).convert("RGB").resize((W, H), Image.LANCZOS)
    return np.asarray(raw).astype(float)


def matte(spec, plate, rgb):
    trace = spec["plates"][plate]
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon([tuple(p) for p in trace["polygon"]], fill=255)
    area = np.asarray(mask) > 0
    hi, lo = rgb.max(axis=2), rgb.min(axis=2)
    sat = (hi - lo) / np.maximum(hi, 1)
    rule = spec["rule"]
    floorlike = (hi >= rule["minValue"]) & (hi <= rule["maxValue"]) & (sat <= rule["maxSaturation"])
    for x0, y0, x1, y1 in trace.get("alwaysFloor", []):  # painted spills, such as an orange runner on the floor
        floorlike[y0:y1, x0:x1] = True
    keep = ndimage.binary_closing(floorlike & area, iterations=rule.get("close", 3)) & area
    labels, _ = ndimage.label(keep)
    keep = labels == labels[H - 20, W // 2]
    keep = ndimage.binary_fill_holes(keep) & area
    # closing and filling must not swallow a pilaster's base
    solid = hi > rule["maxValue"] * 1.15
    for x0, y0, x1, y1 in trace.get("alwaysFloor", []):
        solid[y0:y1, x0:x1] = False
    return ndimage.binary_fill_holes(keep & ~ndimage.binary_dilation(solid, iterations=1))


def world_grid(cam):
    """(s, t) of every pixel on the floor plane."""
    ys, xs = np.mgrid[0:H, 0:W]
    inv = np.linalg.inv(cam.homography())
    q = inv @ np.stack([xs.ravel(), np.maximum(ys.ravel(), cam.hz + 4), np.ones(xs.size)])  # above the horizon is never floor
    return (q[0] / q[2]).reshape(H, W), (q[1] / q[2]).reshape(H, W)


def noise(shape, sigma, seed):
    n = ndimage.gaussian_filter(np.random.default_rng(seed).standard_normal(shape), sigma, mode="wrap")
    return n / n.std()


def sample_world(field, s, t, span):
    """Read a square world texture at floor coordinates, wrapping."""
    n = field.shape[0]
    return ndimage.map_coordinates(field, [(s / span % 1) * n, (t / span % 1) * n], order=1, mode="wrap")


def albedo(spec, cam, s, t, texture=None):
    look = spec["look"]
    every, lane = look["slabS"], look["slabT"]
    base = np.array(look["base"], float)
    i, j = np.floor(s / every).astype(int), np.floor((t - look.get("offsetT", 0)) / lane).astype(int)
    rng = np.random.default_rng(look["seed"])
    jitter = rng.normal(0, look["slabJitter"], (97, 89))[i % 97, j % 89]
    tone = 1 + jitter
    if texture is None:
        field = noise((1024, 1024), 6, look["seed"]) * .6 + noise((1024, 1024), 30, look["seed"] + 1)
        tone = tone * (1 + look["mottle"] * sample_world(field, s, t, 12))
        colour = base[None, None, :] * tone[..., None]
    else:
        tx = np.asarray(texture).astype(float)
        span = look["textureSpan"]
        channels = [sample_world(tx[..., c], s, t, span) for c in range(3)]
        colour = np.stack(channels, axis=2) * tone[..., None]
    return colour


def joints(spec, s, t):
    """Thin lines of constant screen weight: how far each pixel is from a joint, in pixels."""
    look = spec["look"]
    ds_dy, ds_dx = np.gradient(s)
    dt_dy, dt_dx = np.gradient(t)
    every, lane = look["slabS"], look["slabT"]
    fs = np.abs(((s + every / 2) % every) - every / 2) / np.maximum(np.hypot(ds_dx, ds_dy), 1e-6)
    ft = np.abs(((t - look.get("offsetT", 0) + lane / 2) % lane) - lane / 2) / np.maximum(np.hypot(dt_dx, dt_dy), 1e-6)
    return np.minimum(fs, ft)


def reflection(rgb, mask, cam, spec):
    """Mirror each column about its contact line, blurring more with distance from the wall."""
    look = spec["look"]
    # the contact is the top of the run reaching the bottom edge, so floor seen behind the bandstand doesn't count
    top = H - np.minimum.accumulate(mask[::-1], axis=0).sum(axis=0)
    out = np.zeros_like(rgb)
    dist = np.zeros((H, W))
    ys, xs = np.mgrid[0:H, 0:W]
    src = 2 * top[None, :] - ys
    dist = np.where(mask, ys - top[None, :], 0).astype(float)
    # lamps are far brighter than eight bits can say: lift them, so their long streaks survive the blur
    hi, lo = rgb.max(axis=2, keepdims=True), rgb.min(axis=2, keepdims=True)
    lamp = np.clip((hi / 255 - .6) / .3, 0, 1) * np.clip(((hi - lo) / np.maximum(hi, 1) - .3) / .25, 0, 1)
    bright = rgb * (1 + look["hdr"] * lamp)
    valid = src >= 0
    for c in range(3):
        out[..., c] = np.where(valid & mask, bright[np.clip(src, 0, H - 1), xs, c], 0)
    levels = [(look["blurNear"], 0), (look["blurMid"], 220), (look["blurFar"], 620)]
    stack = [np.stack([ndimage.gaussian_filter(out[..., c], (sy, sy * look["blurSide"])) for c in range(3)], 2) for sy, _ in levels]
    weights = np.clip(dist / 220, 0, 1)[..., None], np.clip((dist - 220) / 400, 0, 1)[..., None]
    blended = stack[0] * (1 - weights[0]) + stack[1] * weights[0]
    blended = blended * (1 - weights[1]) + stack[2] * weights[1]
    fade = look["reflect"] * np.exp(-dist / look["reflectFall"])[..., None]
    return blended * fade


def lamp_pools(spec, plate, s, mask):
    """Long soft streaks under each hanging lamp, which the walls' mirror can't reach."""
    look = spec["look"]
    glow = np.zeros((H, W, 3))
    ys, xs = np.mgrid[0:H, 0:W]
    for x, y, strength in spec["plates"][plate].get("lampStreaks", []):
        w = look["streakWidth"] * (1 + (ys - y).clip(0) / 500)
        across = np.exp(-(((xs - x) / w) ** 2))
        along = np.exp(-(((ys - y) / look["streakLength"]) ** 2)) * (ys > y - 80)
        glow += (strength * across * along)[..., None] * np.array(look["streak"], float)
    return glow * mask[..., None]


def pixelate(colour, cell):
    h, w = colour.shape[:2]
    small = Image.fromarray(np.clip(colour, 0, 255).astype(np.uint8)).resize((w // cell, h // cell), Image.BOX)
    return small


def paint(room, plate, texture=None, name=None):
    spec, cam = load(room)
    rgb = source(spec, plate)
    mask = matte(spec, plate, rgb)
    s, t = world_grid(cam)
    look = spec["look"]
    colour = albedo(spec, cam, s, t, texture)
    colour = colour + reflection(rgb, mask, cam, spec) + lamp_pools(spec, plate, s, mask)
    # bottom of the walls and the bandstand sit on the floor: a soft contact shadow
    inside = ndimage.distance_transform_edt(mask)
    colour *= (1 - look["contact"] * np.exp(-inside / look["contactReach"]))[..., None]
    # the tap band stays quiet: calm the very near floor toward a low, even tone
    calm = np.clip((np.mgrid[0:H, 0:W][0] - look["calmFrom"] * H) / (look["calmTo"] * H - look["calmFrom"] * H), 0, 1)[..., None] * look["calm"]
    colour = colour * (1 - calm) + np.mean(colour[mask], axis=0)[None, None, :] * calm * look["calmTone"]
    cell = look["cell"]
    small = pixelate(np.where(mask[..., None], colour, rgb), cell).quantize(look["colours"], method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    grained = np.asarray(small.resize((W // cell * cell, H // cell * cell), Image.NEAREST)).astype(float)
    full = np.array(rgb)
    gh, gw = grained.shape[:2]
    floor = np.array(rgb); floor[:gh, :gw] = grained
    # joints go on the finished grain, two pixels fine, so they stay thin at the far end as in the bar
    near = ndimage.zoom(ndimage.minimum_filter(joints(spec, s, t), 2)[::2, ::2], 2, order=0)[:H, :W]
    line = np.zeros((H, W, 1)); line[:near.shape[0], :near.shape[1], 0] = near < look["jointWidth"]
    lit = np.exp(-(np.mgrid[0:H, 0:W][0] - cam.hz) / look["jointFall"])[..., None]
    shade = floor * look["jointDark"] + np.array(look["jointGlint"], float) * (.25 + .75 * lit)
    floor = floor * (1 - line) + shade * line
    edge = ndimage.gaussian_filter(mask.astype(float), .6)[..., None]
    full = full * (1 - edge) + floor * edge
    out = CACHE / spec["run"]
    out.mkdir(parents=True, exist_ok=True)
    name = name or f"{plate}-code"
    path = out / f"{name}.png"
    Image.fromarray(np.clip(full, 0, 255).astype(np.uint8)).save(path)
    Image.fromarray((mask * 255).astype(np.uint8)).save(out / f"{plate}-mask.png")
    lum = (0.299 * full[..., 0] + 0.587 * full[..., 1] + 0.114 * full[..., 2])[mask]
    print(path, "floor luma median", round(float(np.median(lum)), 1), "p10", round(float(np.percentile(lum, 10)), 1), "p90", round(float(np.percentile(lum, 90)), 1))
    return path


def cmd_matte(room, plate):
    spec, cam = load(room)
    rgb = source(spec, plate)
    mask = matte(spec, plate, rgb)
    view = rgb.copy()
    view[mask] = view[mask] * .4 + np.array([0, 255, 90]) * .6
    out = CACHE / spec["run"]
    out.mkdir(parents=True, exist_ok=True)
    Image.fromarray(view.astype(np.uint8)).crop((0, 500, W, 950)).save(out / f"{plate}-matte-view.png")
    print(out / f"{plate}-matte-view.png")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["matte", "paint", "texture"])
    ap.add_argument("room")
    ap.add_argument("plate")
    ap.add_argument("--image")
    ap.add_argument("--name")
    a = ap.parse_args()
    if a.cmd == "matte":
        cmd_matte(a.room, a.plate)
    elif a.cmd == "paint":
        paint(a.room, a.plate, name=a.name)
    else:
        paint(a.room, a.plate, texture=Image.open(a.image).convert("RGB"), name=a.name)


if __name__ == "__main__":
    main()
