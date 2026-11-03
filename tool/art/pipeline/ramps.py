#!/usr/bin/env python3
"""Palette-aware frames (design D13): the ramp stage, recolouring and variants.

After studio.finish_pixels a frame only knows the shared palette, where a hat and
trousers may land on the same cream. apply_ramps() uses the rig mask to give every
opaque pixel one shade of one ramp allowed for its region. From then on a colour
says which part it is, so recolouring is a table lookup: no GPU, and every other
pixel stays byte-identical.

  ramps.py apply  <character> <pose> IN.png OUT.png [--rig-dir DIR] [--target ROOM]
  ramps.py lut    <character> <variant>      prints the variant's colour table
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import colour as C  # noqa: E402
import definitions as D  # noqa: E402

OFF_RAMP_DISTANCE = 20.0  # OKLab x100; further than this from any allowed shade is worth a look


def native_mask(regions_png: Path, size: tuple[int, int], scale: int) -> np.ndarray:
    """The rig's region render at native size, centre-sampled like finish_pixels."""
    a = np.asarray(Image.open(regions_png).convert("RGBA"))
    w, h = size
    ys = (np.arange(h) * scale + scale // 2).clip(0, a.shape[0] - 1)
    xs = (np.arange(w) * scale + scale // 2).clip(0, a.shape[1] - 1)
    return a[np.ix_(ys, xs)]


def _allowed_by_pixel(mask: np.ndarray, regions: dict[str, str], radius: int) -> dict[str, np.ndarray]:
    out = {}
    h, w = mask.shape[:2]
    for name, colour in regions.items():
        hit = np.all(mask[..., :3] == np.array(C.hex_to_rgb(colour)), axis=-1) & (mask[..., 3] == 255)
        grown = hit.copy()
        for _ in range(radius):
            g = grown.copy()
            g[1:, :] |= grown[:-1, :]
            g[:-1, :] |= grown[1:, :]
            g[:, 1:] |= grown[:, :-1]
            g[:, :-1] |= grown[:, 1:]
            grown = g
        out[name] = grown
    return out


def apply_ramps(frame: np.ndarray, mask: np.ndarray, ramps: dict, regions: dict[str, str], outline: str,
                radius: int = 2) -> tuple[np.ndarray, dict]:
    """Snap every opaque pixel to one shade of a ramp its region allows.

    Pixels the generator put outside any mask region still get the nearest shade of
    any ramp, and are counted in the report as offMask; pixels far from every allowed
    shade count as offRamp. Both are review signals, never silent repairs.
    """
    every: list[tuple[int, int, int]] = []
    usable: dict[str, list[int]] = {}
    for part in ramps.values():
        idx = list(range(len(every), len(every) + len(part["shades"])))
        every.extend(C.hex_to_rgb(s) for s in part["shades"])
        for r in [part["region"], *part.get("alsoIn", [])]:
            usable.setdefault(r, []).extend(idx)
    out_rgb = C.hex_to_rgb(outline)
    allowed = _allowed_by_pixel(mask, regions, radius)
    all_lab = C.oklab(np.array(every + [out_rgb], float))
    palette = np.array(every + [out_rgb], np.uint8)
    res = frame.copy()
    opaque = frame[..., 3] >= 128
    lab = C.oklab(frame[..., :3].astype(float))
    dist = np.linalg.norm(lab[:, :, None, :] - all_lab[None, None, :, :], axis=-1)
    union = np.zeros(opaque.shape, bool)
    gate = np.zeros(dist.shape, bool)
    gate[..., -1] = True  # the outline is always allowed
    for r, m in allowed.items():
        union |= m
        if r in usable:
            gate[m] |= np.isin(np.arange(dist.shape[-1]), usable[r])
    off_mask = opaque & ~union
    gate[off_mask] = True
    best = np.where(gate, dist, np.inf).argmin(axis=-1)
    d = np.take_along_axis(dist, best[..., None], axis=-1)[..., 0]
    res[..., :3][opaque] = palette[best][opaque]
    res[..., 3] = np.where(opaque, 255, 0)
    res[..., :3][~opaque] = 0
    report = {"opaque": int(opaque.sum()), "offMask": int(off_mask.sum()),
              "offRamp": int((opaque & (d > OFF_RAMP_DISTANCE)).sum())}
    report["flagged"] = bool(report["offMask"] or report["offRamp"])
    return res, report


def colours_in(frame: np.ndarray) -> set[str]:
    px = frame[frame[..., 3] > 0][:, :3]
    return {C.rgb_to_hex(c) for c in np.unique(px, axis=0)} if len(px) else set()


def check_frame(frame: np.ndarray, ramps: dict, outline: str) -> list[str]:
    """Colours in a frame that belong to no declared ramp."""
    known = {outline.upper()} | {s for p in ramps.values() for s in p["shades"]}
    return sorted(colours_in(frame) - known)


# ---------------------------------------------------------------- tables


def lut_between(old: dict, new: dict) -> dict[str, str]:
    """{old shade: new shade} for every part present in both ramp sets, changed shades only."""
    lut = {}
    for pid, part in old.items():
        if pid not in new:
            continue
        for a, b in zip(part["shades"], new[pid]["shades"]):
            if a != b:
                lut[a] = b
    return lut


def apply_lut(frame: np.ndarray, lut: dict[str, str]) -> np.ndarray:
    """Recolour by exact colour match; every pixel not in the table is untouched."""
    res = frame.copy()
    for a, b in lut.items():
        hit = np.all(frame[..., :3] == np.array(C.hex_to_rgb(a), dtype=frame.dtype), axis=-1) & (frame[..., 3] > 0)
        res[..., :3][hit] = C.hex_to_rgb(b)
    return res


def variant_lut(c: dict, style: dict, variant_id: str) -> dict[str, str]:
    """A colour-only variant as a table over the base ramps. Refuses shape changes."""
    v = c["variants"][variant_id]
    if v.get("garments"):
        raise ValueError(f"variant {variant_id} changes garments: it needs masked mode and its own atlas")
    return lut_between(C.build_ramps(c, style), C.build_ramps(c, style, v.get("colours", {})))


def manifest_block(c: dict, style: dict) -> dict:
    """`ramps` and `variants` for a manifest atlas block. Ignored by today's runtime."""
    base = C.build_ramps(c, style)
    block = {"ramps": {k: {"region": v["region"], "alsoIn": v["alsoIn"], "shades": v["shades"]} for k, v in base.items()}}
    variants = {vid: variant_lut(c, style, vid) for vid, v in c.get("variants", {}).items() if not v.get("garments")}
    if variants:
        block["variants"] = variants
    return block


def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    pa = sub.add_parser("apply")
    pa.add_argument("character")
    pa.add_argument("pose")
    pa.add_argument("input")
    pa.add_argument("output")
    pa.add_argument("--rig-dir")
    pa.add_argument("--target")
    pl = sub.add_parser("lut")
    pl.add_argument("character")
    pl.add_argument("variant")
    a = ap.parse_args()
    c = D.load_character(a.character)
    style = D.load_style(c["style"])
    if a.cmd == "lut":
        if a.variant not in c.get("variants", {}):
            sys.exit(f"refused:{a.character}:variants.{a.variant}: no such variant (have: {sorted(c.get('variants', {}))})")
        print(json.dumps(variant_lut(c, style, a.variant), indent=1))
        return
    target = next((t for t in c["targets"] if not a.target or t["room"] == a.target))
    rig_dir = Path(a.rig_dir) if a.rig_dir else D.ROOT / "art_runs" / "inputs" / c["family"]
    frame = np.asarray(Image.open(a.input).convert("RGBA"))
    mask = native_mask(rig_dir / f"{a.pose}.regions.png", (frame.shape[1], frame.shape[0]), target["pixelScale"])
    res, report = apply_ramps(frame, mask, C.build_ramps(c, style), D.rig_regions(c), style["outline"])
    Image.fromarray(res, "RGBA").save(a.output, optimize=False)
    print(json.dumps(report))


if __name__ == "__main__":
    main()
