#!/usr/bin/env python3
"""The Pool Player's close-up frames, from the picked Qwen drawings in art_runs/pool-closeup-20261107a/picks.json.

Each drawing is halved and snapped to the puppet's 2-pixel grid, so her pixels match Mācron's at the shot's one scale.
Code adds only what Qwen can't hold: the cue's run out to the antenna, the blue on its tip, and enough body below the
drawing to reach the foreground table, whose edge hides it. The tip's art pixel on the dab goes to pool-chalk-art.json.

Usage: pack_pool_closeup.py [--preview OUT.png]
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

RUN = Path("art_runs/pool-closeup-20261107a")
RAW = Path.home() / ".cache/tillandsias-project/kumbia-art/pool-closeup-20261107a/raw"
OUT = Path("assets/art/closeups")
CELL = 2
W, H = 440, 620      # art pixels: the drawing's 384 x 480, plus the cue's run and the body under the table
TIP_DAB_X = 433      # the dab: at the shot's .36, this puts her head in view x 0 to 45 with the tip on the antenna
TIP_REACH_X = 397
WINK_TIP = (264, 176, 282, 196)   # the white tip on the picked wink, ck.wink 989722
BLUE, BLUE_DARK, INK = (58, 96, 224), (34, 62, 170), (10, 26, 46)


def snap(im: Image.Image) -> np.ndarray:
    """Half size, then one colour per grid cell, by majority: the same grid as Mācron's drawings."""
    a = np.asarray(im.convert("RGBA").resize((384, 480), Image.NEAREST), dtype=np.uint32)
    h, w = a.shape[:2]
    key = (a[..., 0] << 24 | a[..., 1] << 16 | a[..., 2] << 8 | a[..., 3]) * (a[..., 3] >= 128)
    out = np.zeros((h, w, 4), dtype=np.uint8)
    for y in range(0, h - CELL + 1, CELL):
        for x in range(0, w - CELL + 1, CELL):
            v, c = np.unique(key[y:y + CELL, x:x + CELL], return_counts=True)
            k = int(v[c.argmax()])
            out[y:y + CELL, x:x + CELL] = (k >> 24 & 255, k >> 16 & 255, k >> 8 & 255, k & 255)
    return out


def canvas(frame: np.ndarray) -> np.ndarray:
    """Onto the full canvas, with the bottom row carried down: a plain column of her, which the table hides the end of."""
    out = np.zeros((H, W, 4), dtype=np.uint8)
    h = frame.shape[0]
    out[:h, :frame.shape[1]] = frame
    out[h:, :frame.shape[1]] = frame[h - CELL]
    return out


def cue_band(frame: np.ndarray, x: int) -> tuple[int, int]:
    """The opaque run at this column, where the level cue leaves the picture's right edge."""
    ys = np.where(frame[:, x, 3] > 0)[0]
    return int(ys.min()), int(ys.max()) + 1


def run_cue(out: np.ndarray, tip_x: int, x0: int, y0: int, y1: int) -> None:
    """The cue's level shaft out to its tip, one column repeated from the drawing, and a chalked tip with ink round it."""
    col = out[y0:y1, x0 - CELL].copy()
    for x in range(x0, tip_x - 6, CELL):
        out[y0:y1, x:x + CELL] = col[:, None]
    out[y0:y1, tip_x - 6:tip_x + 2, :3] = BLUE
    out[y1 - CELL:y1, tip_x - 6:tip_x + 2, :3] = BLUE_DARK
    out[y0:y1, tip_x - 6:tip_x + 2, 3] = 255
    out[y0:y1, tip_x + 2:tip_x + 4, :3] = INK
    out[y0:y1, tip_x + 2:tip_x + 4, 3] = 255
    out[y0 - CELL:y0, tip_x - 6:tip_x + 2, :3] = INK
    out[y0 - CELL:y0, tip_x - 6:tip_x + 2, 3] = 255
    out[y1:y1 + CELL, tip_x - 6:tip_x + 2, :3] = INK
    out[y1:y1 + CELL, tip_x - 6:tip_x + 2, 3] = 255


def white_tip_to_blue(out: np.ndarray, box: tuple[int, int, int, int]) -> None:
    """An upright cue's white tip, once chalked. The box is measured on the picked drawing, since hair and collar are as pale."""
    x0, y0, x1, y1 = box
    area = out[y0:y1, x0:x1]
    rgb = area[..., :3].astype(int)
    pale = (rgb.min(-1) > 170) & (area[..., 3] > 0)
    area[pale, :3] = BLUE


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview")
    a = ap.parse_args()
    picks = json.loads((RUN / "picks.json").read_text())
    def drawn(pid: str) -> np.ndarray:
        return snap(Image.open(RAW / pid / f"{picks[pid]}.png"))
    frames = {"chalk-a": canvas(drawn("ck.chalk_a")), "chalk-b": canvas(drawn("ck.chalk_b")), "wink": canvas(drawn("ck.wink"))}
    white_tip_to_blue(frames["wink"], WINK_TIP)
    reach = drawn("ck.reach")
    y0, y1 = cue_band(reach, 380)
    base = canvas(reach)
    # The hand on the shaft is in the drawing; the cue's run starts past the picture's old edge.
    for name, tip in (("reach", TIP_REACH_X), ("dab", TIP_DAB_X)):
        f = base.copy()
        run_cue(f, tip, 382, y0, y1)
        frames[name] = f
    for name, f in frames.items():
        Image.fromarray(f).save(OUT / f"pool-player-{name}.png")
    tip_y = (y0 + y1) // 2
    art = json.loads((OUT / "pool-chalk-art.json").read_text())
    art.update(playerContact=[TIP_DAB_X + 3, tip_y], scale=0.36, size=[W, H], cueBand=[y0, y1])
    (OUT / "pool-chalk-art.json").write_text(json.dumps(art, indent=1) + "\n")
    print("tip", art["playerContact"], "band", y0, y1)
    if a.preview:
        S = 0.36 * 4
        view = Image.new("RGBA", (180 * 4, 390 * 4), (70, 50, 40, 255))
        mac = Image.open(OUT / "pool-macron-arc-blush.png").convert("RGBA")
        def put(im, contact, at):
            im = im.resize((int(im.width * S), int(im.height * S)), Image.NEAREST)
            view.alpha_composite(im, (max(0, 0), 0)) if False else None
            x, y = round(at[0] * 4 - contact[0] * S), round(at[1] * 4 - contact[1] * S)
            layer = Image.new("RGBA", view.size, (0, 0, 0, 0))
            layer.paste(im, (x, y))
            view.alpha_composite(layer)
        put(mac, art["macronContact"], (119, 78))
        put(Image.fromarray(frames["dab"]), art["playerContact"], (119, 78))
        table = Image.new("RGBA", (180 * 4, 165 * 4), (30, 70, 50, 255))
        view.paste(table, (0, 225 * 4))
        view.convert("RGB").resize((360, 780), Image.NEAREST).save(a.preview)


if __name__ == "__main__":
    main()
