"""Draw an OpenPose COCO-18 skeleton, shared by the rig renderer and the frame planner."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

# OpenPose COCO-18 (controlnet_aux convention).
LIMBS = [(1, 2), (1, 5), (2, 3), (3, 4), (5, 6), (6, 7), (1, 8), (8, 9), (9, 10),
         (1, 11), (11, 12), (12, 13), (1, 0), (0, 14), (14, 16), (0, 15), (15, 17)]
COLORS = [(255, 0, 0), (255, 85, 0), (255, 170, 0), (255, 255, 0), (170, 255, 0),
          (85, 255, 0), (0, 255, 0), (0, 255, 85), (0, 255, 170), (0, 255, 255),
          (0, 170, 255), (0, 85, 255), (0, 0, 255), (85, 0, 255), (170, 0, 255),
          (255, 0, 255), (255, 0, 170), (255, 0, 85)]


def draw_openpose(path: Path, pts2d: list, visible: list[bool], canvas: tuple[int, int]) -> None:
    W, H = canvas
    stick = max(4, round(W / 128))
    base = Image.new("RGB", canvas, (0, 0, 0))
    for i, (a, b) in enumerate(LIMBS):
        if not (visible[a] and visible[b]):
            continue
        layer = Image.new("RGB", canvas, (0, 0, 0))
        d = ImageDraw.Draw(layer)
        (x1, y1), (x2, y2) = pts2d[a][:2], pts2d[b][:2]
        length = math.hypot(x2 - x1, y2 - y1)
        ang = math.atan2(y2 - y1, x2 - x1)
        cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
        poly = []
        for t in range(0, 360, 10):
            ex, ey = length / 2 * math.cos(math.radians(t)), stick * math.sin(math.radians(t))
            poly.append((cx + ex * math.cos(ang) - ey * math.sin(ang), cy + ex * math.sin(ang) + ey * math.cos(ang)))
        d.polygon(poly, fill=COLORS[i])
        base = Image.blend(base, Image.composite(layer, base, layer.convert("L").point(lambda v: 255 if v else 0)), 0.6)
    d = ImageDraw.Draw(base)
    for i, pt in enumerate(pts2d):
        if visible[i]:
            x, y = pt[:2]
            d.ellipse((x - stick, y - stick, x + stick, y + stick), fill=COLORS[i])
    base.save(path)
