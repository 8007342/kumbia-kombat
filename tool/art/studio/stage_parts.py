#!/usr/bin/env python3
"""Stage the per-pose masks and head-window carrier the studio workflows load.

Run after plan_jobs.py, which stages pose/depth/lineart/proxy/identity. Writes, beside them:

  <pose>.mask.head.png   face and hair only (rig skin + hair inside a disc on the head joint)
  <pose>.mask.face.png   the head pass's repaint area: mask.head plus the neck, minus the hat, because
                         the base pass grows beards below the rig's chin
  <pose>.mask.hat.png    hat crown, brim and band
  <pose>.mask.shirt.png  shirt and its stripes
  <pose>.mask.arms.png   bare arms and hands
  <pose>.mask.legs.png   trousers and shoes
  <pose>.face.png        the rig proxy with a drawn face: flat skin, two eyes and a one-native-pixel mustache
                         placed from the rig's own mustache, so every pose gets the same face at the right tilt
  <pose>.mask.figure.png every rig pixel, for clamping the matte
  <pose>.mask.ref_head.png, <pose>.mask.ref_body.png   attention masks for the two IP-Adapters: head and
                         hat, and everything else including background (a figure-only body mask invented
                         text at the frame's bottom edge, plan/comfyui-cheatsheet.md recipe 2)
  ref_head.png, ref_outfit.png   square crops of the staged identity.png: CLIP vision centre-crops anything
                         else, which would cut the hat or the shoes off a tall reference
  <pose>.embroidery.png, <pose>.mask.embroidery.png  the rig proxy with one embroidery strip, cut once from the
                         staged identity.png, drawn along each rig stripe; every pose gets the same stitches
  <pose>.torsoxy.png     the torso window's x and y, carried the same way as headxy
  <pose>.headxy.png      a blank image whose WIDTH and HEIGHT are the head window's x and y

Why the carrier: core ComfyUI has no node that reads a bounding box from a mask, the studio
refuses ComfyMathExpression (node_not_pinned), and run_workflow can only override $seed, $prompt
and $negative_prompt. Images are the one thing that binds per pose, and GetImageSize turns one
into two INTs, so the graph crops the head window with no per-pose editing.

The garment names follow tool/art/characters/gatekeeper.json: rig regions skin, hair, hat, cloth,
accessory (band and stripes), trousers, shoes.

Usage:
  stage_parts.py --run <run> --only groove.down_l,left_hand.peak
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
INPUTS = ROOT / "art_runs" / "inputs" / "gatekeeper-v3"
STAGE = Path("/work/tmp/imagegen/kumbia")

WINDOW = 256         # head window side in frame pixels; the frame graph's ImageCrop uses the same
HEAD_RADIUS = 72     # disc on the head joint: keeps a raised hand or the neck out of the head mask
NECK_RADIUS = 46     # half-width of the capsule from head joint to neck joint in mask.face
SKIN, INK = (0xB5, 0x65, 0x3A), (0x1C, 0x11, 0x17)  # gatekeeper.json skin and hair
SKIN_SHADE = (0x8E, 0x4C, 0x2B)
MUSTACHE_TALL = 8    # one native pixel at pixelScale 8 (styleGuide.face)
EYE_SPREAD, EYE_LIFT = 26.0, 30.0  # eye offset from the mustache centre, in frame pixels
REGION = {"skin": (255, 0, 0), "hair": (0, 255, 0), "cloth": (0, 0, 255), "hat": (255, 255, 0),
          "shoes": (0, 255, 255), "accessory": (255, 0, 255), "trousers": (255, 128, 0)}


def region(rgba: np.ndarray, name: str) -> np.ndarray:
    return (rgba[..., :3] == REGION[name]).all(axis=-1) & (rgba[..., 3] > 0)


def disc(shape: tuple[int, int], centre: tuple[float, float], radius: float) -> np.ndarray:
    yy, xx = np.mgrid[:shape[0], :shape[1]]
    return (xx - centre[0]) ** 2 + (yy - centre[1]) ** 2 <= radius ** 2


def dilate(mask: np.ndarray, px: int) -> np.ndarray:
    out = mask.copy()
    for _ in range(px):
        grown = out.copy()
        grown[1:] |= out[:-1]
        grown[:-1] |= out[1:]
        grown[:, 1:] |= out[:, :-1]
        grown[:, :-1] |= out[:, 1:]
        out = grown
    return out


def capsule(shape: tuple[int, int], a: tuple[float, float], b: tuple[float, float], radius: float) -> np.ndarray:
    yy, xx = np.mgrid[:shape[0], :shape[1]]
    ax, ay, dx, dy = a[0], a[1], b[0] - a[0], b[1] - a[1]
    t = np.clip(((xx - ax) * dx + (yy - ay) * dy) / max(dx * dx + dy * dy, 1e-6), 0, 1)
    return (xx - ax - t * dx) ** 2 + (yy - ay - t * dy) ** 2 <= radius ** 2


def face_mask(head: np.ndarray, hat: np.ndarray, head_joint: tuple[float, float], neck_joint: tuple[float, float]) -> np.ndarray:
    return (head | capsule(head.shape, head_joint, neck_joint, NECK_RADIUS)) & ~hat


def components(mask: np.ndarray) -> list[np.ndarray]:
    """4-connected components as arrays of (y, x)."""
    seen = np.zeros(mask.shape, bool)
    out = []
    for start in zip(*np.nonzero(mask)):
        if seen[start]:
            continue
        seen[start] = True
        stack, pixels = [start], []
        while stack:
            y, x = stack.pop()
            pixels.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1] and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        out.append(np.array(pixels))
    return out


def mustache_axis(rgba: np.ndarray, head: np.ndarray, hat: np.ndarray) -> tuple[np.ndarray, np.ndarray, float]:
    """(centre xy, unit vector along the mustache, half length) of the rig's mustache: the hair
    component inside the head mask that skin surrounds. Hair at the back of the head touches background."""
    skin = region(rgba, "skin")
    best, best_score = None, -1.0
    for comp in components(region(rgba, "hair") & head):
        ring = np.zeros(head.shape, bool)
        ring[comp[:, 0], comp[:, 1]] = True
        ring = dilate(ring, 2) & ~ring
        score = float((skin & ring).sum()) / max(int(ring.sum()), 1)
        if len(comp) >= 8 and score > best_score:
            best, best_score = comp, score
    if best is None:
        raise SystemExit("no mustache in this pose's head: rear views have no face to draw")
    xy = best[:, ::-1].astype(float)
    centre = xy.mean(axis=0)
    _, _, vt = np.linalg.svd(xy - centre, full_matrices=False)
    axis = vt[0]
    half = float(np.abs((xy - centre) @ axis).max())
    return centre, axis, half


def draw_face(proxy: Image.Image, parts: dict, rgba: np.ndarray) -> Image.Image:
    """Flat skin, two eyes, a thin mustache. The nominal front-view mustache half length is 13 px;
    a shorter one means a turned head, so the eyes close up with it."""
    centre, axis, half = mustache_axis(rgba, parts["head"], parts["hat"])
    up = np.array([-axis[1], axis[0]])
    ys, xs = np.nonzero(parts["hat"])
    if up @ (np.array([xs.mean(), ys.mean()]) - centre) < 0:
        up = -up
    turn = min(half / 13.0, 1.0)
    out = np.array(proxy.convert("RGB"))
    out[parts["head"] & ~region(rgba, "hair")] = SKIN
    out[region(rgba, "hair") & parts["head"]] = SKIN if len(components(region(rgba, "hair") & parts["head"])) == 1 else out[region(rgba, "hair") & parts["head"]]
    yy, xx = np.mgrid[:out.shape[0], :out.shape[1]]
    along = (xx - centre[0]) * axis[0] + (yy - centre[1]) * axis[1]
    across = (xx - centre[0]) * up[0] + (yy - centre[1]) * up[1]
    # Below one native pixel, these only show above the 96x120 size: nose, brows and mouth, in shades of skin.
    out[(np.abs(along) <= 5) & (np.abs(across - 14) <= 11) & parts["head"]] = SKIN_SHADE
    out[(np.abs(along) <= half * 0.5) & (np.abs(across + 12) <= 2) & parts["head"]] = SKIN_SHADE
    out[(np.abs(along) <= half) & (np.abs(across) <= MUSTACHE_TALL / 2) & parts["head"]] = INK
    for side in (-1, 1):
        # On a turned head the far side of the face runs out first: keep the eye on the face.
        reach = EYE_SPREAD * turn
        at = centre + up * EYE_LIFT
        while reach > 8:
            px = at + axis * side * (reach + 9)
            if parts["head"][int(px[1]), int(px[0])]:
                break
            reach -= 2
        ex, ey = reach * side, EYE_LIFT
        out[(((along - ex) / 5.0) ** 2 + ((across - ey) / 6.5) ** 2 <= 1) & parts["head"]] = INK
        out[(np.abs(along - ex) <= 9) & (np.abs(across - ey - 12) <= 2) & parts["head"]] = INK
    return Image.fromarray(out)


def part_masks(rgba: np.ndarray, head_joint: tuple[float, float]) -> dict[str, np.ndarray]:
    """{part: bool mask}. Parts never overlap, and together cover every rig pixel."""
    shape = rgba.shape[:2]
    head_disc = disc(shape, head_joint, HEAD_RADIUS)
    head = (region(rgba, "skin") | region(rgba, "hair")) & head_disc
    hat = region(rgba, "hat")
    # The band is accessory that touches the hat; the stripes are accessory that touches the cloth.
    accessory = region(rgba, "accessory")
    band = accessory & dilate(hat, 4)
    arms = region(rgba, "skin") & ~head
    return {"head": head, "hat": hat | band, "shirt": region(rgba, "cloth") | (accessory & ~band), "arms": arms,
            "legs": region(rgba, "trousers") | region(rgba, "shoes")}


def head_window(head: np.ndarray, canvas: tuple[int, int]) -> tuple[int, int]:
    """Top-left of the WINDOW square centred on the head mask. Never 0: an image can't be 0 wide."""
    ys, xs = np.nonzero(head)
    cx, cy = (int(xs.min()) + int(xs.max())) // 2, (int(ys.min()) + int(ys.max())) // 2
    w, h = canvas
    return max(1, min(cx - WINDOW // 2, w - WINDOW)), max(1, min(cy - WINDOW // 2, h - WINDOW))


TORSO_WINDOW = 384   # torso window side in frame pixels; the frame graph's ImageCrop uses the same
EMBROIDERY_WIDE = 30                 # canvas pixels across a panel
# Pixel boxes on the staged identity.png, per reference, keyed by its size. scale: identity pixels
# to canvas pixels, both at their figure's height. head: hat to chin. outfit: from the shoulders.
# embroidery: a clean run of the left panel, between the bar tacks.
IDENTITY_LAYOUTS = {
    (198, 310): {"head": (45, 0, 145, 100), "outfit": (0, 105, 198, 303),
                 "embroidery": (75, 129, 89, 159), "scale": 2.2},   # gatekeeper-v2, kept for older runs
    (500, 1198): {"head": (110, 0, 390, 280), "outfit": (0, 270, 500, 770),
                  "embroidery": (140, 445, 186, 585), "scale": 0.57},  # accepted model sheet, front view
}


def layout_of(identity: Image.Image) -> dict:
    try:
        return IDENTITY_LAYOUTS[identity.size]
    except KeyError:
        raise SystemExit(f"no layout for an identity image of {identity.size}: add one to IDENTITY_LAYOUTS") from None


def stage_refs(out: Path) -> None:
    identity = Image.open(out / "identity.png").convert("RGB")
    layout = layout_of(identity)
    identity.crop(layout["head"]).save(out / "ref_head.png")
    identity.crop(layout["outfit"]).save(out / "ref_outfit.png")


def stripe_paths(rgba: np.ndarray, parts: dict) -> list[tuple[np.ndarray, np.ndarray]]:
    """(row ys, centre xs) for each rig stripe: the two longest accessory components below the hat."""
    stripes = region(rgba, "accessory") & parts["shirt"]
    out = []
    for comp in sorted(components(stripes), key=len, reverse=True)[:2]:
        rows = np.unique(comp[:, 0])
        out.append((rows, np.array([comp[comp[:, 0] == r, 1].mean() for r in rows])))
    return out


def draw_embroidery(proxy: Image.Image, identity: Image.Image, rgba: np.ndarray, parts: dict) -> tuple[Image.Image, np.ndarray]:
    """Warp one strip along each stripe. The strip mirrors at its ends so it tiles without a jump,
    and each stripe starts at the same place in it, so a stitch keeps its height on the shirt."""
    layout = layout_of(identity)
    strip = np.array(identity.convert("RGB").crop(layout["embroidery"]))
    tall = strip.shape[0]
    out = np.array(proxy.convert("RGB"))
    mask = np.zeros(out.shape[:2], bool)
    for rows, centres in stripe_paths(rgba, parts):
        centres = np.convolve(np.pad(centres, 7, mode="edge"), np.ones(15) / 15, mode="valid")  # no jitter
        for r, c in zip(rows, centres):
            v = int((r - rows[0]) / layout["scale"]) % (2 * tall)
            v = v if v < tall else 2 * tall - 1 - v
            for x in range(int(c - EMBROIDERY_WIDE / 2), int(c + EMBROIDERY_WIDE / 2)):
                if parts["shirt"][r, x]:
                    u = int((x - c + EMBROIDERY_WIDE / 2) / EMBROIDERY_WIDE * strip.shape[1])
                    out[r, x] = strip[v, min(u, strip.shape[1] - 1)]
                    mask[r, x] = True
    return Image.fromarray(out), mask


def stage_pose(pose: dict, regions: Path, out: Path) -> dict:
    """Needs <pose>.proxy.png already staged in `out` by plan_jobs.py."""
    rgba = np.array(Image.open(regions).convert("RGBA"))
    parts = part_masks(rgba, tuple(pose["joints"]["head"]))
    for name, mask in parts.items():
        Image.fromarray((mask * 255).astype("uint8"), "L").save(out / f"{pose['id']}.mask.{name}.png")
    face = face_mask(parts["head"], parts["hat"], tuple(pose["joints"]["head"]), tuple(pose["joints"]["neck"]))
    Image.fromarray((face * 255).astype("uint8"), "L").save(out / f"{pose['id']}.mask.face.png")
    figure = rgba[..., 3] > 0
    head_and_hat = dilate(parts["head"] | parts["hat"], 16)
    for name, mask in {"figure": figure, "ref_head": head_and_hat, "ref_body": ~head_and_hat}.items():
        Image.fromarray((mask * 255).astype("uint8"), "L").save(out / f"{pose['id']}.mask.{name}.png")
    draw_face(Image.open(out / f"{pose['id']}.proxy.png"), parts, rgba).save(out / f"{pose['id']}.face.png")
    identity = Image.open(out / "identity.png")
    embroidery, emb_mask = draw_embroidery(Image.open(out / f"{pose['id']}.proxy.png"), identity, rgba, parts)
    embroidery.save(out / f"{pose['id']}.embroidery.png")
    Image.fromarray((emb_mask * 255).astype("uint8"), "L").save(out / f"{pose['id']}.mask.embroidery.png")
    ys, xs = np.nonzero(region(rgba, "cloth"))
    tx = max(1, min((int(xs.min()) + int(xs.max())) // 2 - TORSO_WINDOW // 2, rgba.shape[1] - TORSO_WINDOW))
    ty = max(1, min((int(ys.min()) + int(ys.max())) // 2 - TORSO_WINDOW // 2, rgba.shape[0] - TORSO_WINDOW))
    Image.new("L", (tx, ty)).save(out / f"{pose['id']}.torsoxy.png")
    x, y = head_window(parts["head"], (rgba.shape[1], rgba.shape[0]))
    Image.new("L", (x, y)).save(out / f"{pose['id']}.headxy.png")
    return {"pose": pose["id"], "window": [x, y, WINDOW, WINDOW], "pixels": {k: int(v.sum()) for k, v in parts.items()}}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--run", required=True)
    ap.add_argument("--only", required=True, help="comma-separated pose ids")
    ap.add_argument("--inputs", type=Path, default=INPUTS)
    ap.add_argument("--out", type=Path, help="default: the run's staged in/ folder")
    args = ap.parse_args()
    out = args.out or STAGE / args.run / "in"
    out.mkdir(parents=True, exist_ok=True)
    rig = {p["id"]: p for p in json.loads((args.inputs / "rig.json").read_text())["poses"]}
    stage_refs(out)
    for pid in args.only.split(","):
        print(json.dumps(stage_pose(rig[pid], args.inputs / f"{pid}.regions.png", out)))


if __name__ == "__main__":
    main()
