"""Per-region colour matching before the pixel finish (design D7).

Moves each region's median toward the definition's colour in OKLab, using rig masks.
Global matching would be thrown off by pose: a raised arm changes the global colour
statistics. Pixels outside a region's mask are never touched by that region.
"""
from __future__ import annotations

import numpy as np

import colour as C


def match_regions(rgb: np.ndarray, masks: dict[str, np.ndarray], targets: dict[str, str], strength: float = 1.0,
                  min_pixels: int = 30) -> tuple[np.ndarray, dict]:
    """Returns the matched uint8 image and {region: distance before, after}."""
    lab = C.oklab(rgb.astype(float))
    out = lab.copy()
    report = {}
    touched = np.zeros(rgb.shape[:2], bool)
    for name, m in masks.items():
        if name not in targets or m.sum() < min_pixels:
            continue
        target = C.oklab(C.hex_to_rgb(targets[name]))
        median = np.median(lab[m], axis=0)
        shift = (target - median) * strength
        out[m] = lab[m] + shift
        touched |= m
        report[name] = {"before": round(float(np.linalg.norm(target - median)), 2),
                        "after": round(float(np.linalg.norm(target - np.median(out[m], axis=0))), 2)}
    res = rgb.copy()
    res[touched] = C.oklab_to_rgb(out[touched]).astype(rgb.dtype)
    return res, report
