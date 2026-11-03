#!/usr/bin/env python3
"""Masked regeneration: redraw only what an edit changed (design D5).

changed_mask() finds pixels whose region differs between the old and new rig render,
plus every pixel of the edited regions, then dilates so the edge can blend. job_args()
builds the studio.run_workflow call. composite() puts the result over the previous
frame so that pixels outside the mask stay byte-identical before the pixel finish,
which the workflow alone cannot promise: the latent round trip alters them slightly.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import colour as C  # noqa: E402

DILATE_PX = 12
MASKED_WORKFLOW = "tool/art/workflows/character-frame-masked.api.json"


def changed_mask(old_regions: np.ndarray, new_regions: np.ndarray, edited: list[str], regions: dict[str, str],
                 dilate: int = DILATE_PX) -> np.ndarray:
    """Boolean canvas mask: white means repaint."""
    diff = np.any(old_regions != new_regions, axis=-1)
    for name in edited:
        if name in regions:
            rgb = np.array(C.hex_to_rgb(regions[name]))
            for img in (old_regions, new_regions):
                diff |= np.all(img[..., :3] == rgb, axis=-1) & (img[..., 3] == 255)
    if dilate and diff.any():
        im = Image.fromarray((diff * 255).astype(np.uint8), "L")
        im = im.filter(ImageFilter.MaxFilter(2 * dilate + 1))
        diff = np.asarray(im) > 0
    return diff


def job_args(workflow_args: dict, mask_path: str, previous_frame: str, workflow: str = MASKED_WORKFLOW) -> dict:
    """Turn a planned pose job into its masked form: same controls, seed and prompts."""
    args = {**workflow_args, "workflow": workflow, "mask": mask_path, "init_image": previous_frame}
    return args


def composite(previous: np.ndarray, generated: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """New pixels inside the mask; outside it, the previous frame's exact bytes."""
    out = previous.copy()
    out[mask] = generated[mask]
    return out
