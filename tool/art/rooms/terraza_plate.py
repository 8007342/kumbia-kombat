#!/usr/bin/env python3
"""La Terraza's plate: the accepted pass-2 painting with its floor taken down to night.

Every pass 2 painted the terrace floor as bright honey limestone (tap-band luma 100-120, against the other rooms'
dark floors), which would fight the cues. Words didn't get a chance to fix it: this grades the painted floor by
code instead, keeping its own tiles and texture. The floor is the guide's floor zone (ids.png), so the balustrade,
planters and stair head are untouched. Toward the thumbs it darkens further and cools toward the night sky's blue;
near the balustrade, under the festoon bulbs and the stair lanterns, it keeps more of its warmth.

Usage: terraza_plate.py <pass-2 png> <out png>
"""
import sys

import numpy as np
from PIL import Image

from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FLOOR_ID, JOINT_ID = 17, 5   # compiler.IDS["floor"], compiler.IDS["joint"] (joint ids above the floor are the strings' wires)
NEAR_GAIN, FAR_GAIN = .32, .62
TINT = np.array([.98, .96, 1.04])


def grade(src: Path, out: Path) -> dict:
    im = np.asarray(Image.open(src).convert("RGB")).astype(float)
    H, W = im.shape[:2]
    ids = np.asarray(Image.open(ROOT / "art_runs/rooms/terraza/ids.png").resize((W, H), Image.NEAREST))
    rows = np.arange(H)[:, None]
    floor = (ids == FLOOR_ID) | ((ids == JOINT_ID) & (rows > H * .4))
    top = int(np.nonzero(floor.any(1))[0].min())
    t = np.clip((rows - top) / (H - top), 0, 1)
    gain = FAR_GAIN - (FAR_GAIN - NEAR_GAIN) * t
    lum = im.mean(2, keepdims=True)
    dark = (im * .6 + lum * .4) * TINT * gain[..., None]
    graded = np.where(floor[..., None], dark, im)
    Image.fromarray(np.clip(graded, 0, 255).astype("uint8")).save(out)
    band = graded[int(.65 * H):int(.97 * H)]
    return {"floorTop": top, "bandLumaBefore": round(float(im[int(.65 * H):int(.97 * H)].mean()), 1),
            "bandLumaAfter": round(float(band.mean()), 1)}


if __name__ == "__main__":
    print(grade(Path(sys.argv[1]), Path(sys.argv[2])))
