#!/usr/bin/env python3
"""Trial: round Qwen's big stair steps and resample to a finer grid. Quantise, blur each colour's mask, take the argmax, then nearest-sample."""
import sys, numpy as np
from PIL import Image, ImageFilter
def resmooth(im, sigma, block, colors=28):
    a = im.split()[3].point(lambda v: 255 if v >= 128 else 0); rgb = im.convert("RGB")
    bg = Image.new("RGB", im.size, (0, 0, 0)); bg.paste(rgb, mask=a)
    q = bg.quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE); pal = np.array(q.getpalette()[:colors * 3]).reshape(-1, 3)
    idx = np.array(q); h, w = idx.shape; best = np.full((h, w), -1.0, np.float32); out = np.zeros((h, w), np.uint8)
    for c in range(colors):
        m = idx == c
        if not m.any(): continue
        b = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(sigma)), np.float32)
        take = b > best; best[take] = b[take]; out[take] = c
    al = np.asarray(a.filter(ImageFilter.GaussianBlur(sigma))) >= 128
    res = np.dstack([pal[out].astype(np.uint8), (al * 255).astype(np.uint8)])
    res = Image.fromarray(res, "RGBA")
    return res.resize((im.width // block, im.height // block), Image.NEAREST)
if __name__ == "__main__":
    src, sig, blk, out = sys.argv[1:5]
    resmooth(Image.open(src).convert("RGBA"), float(sig), int(blk), int(sys.argv[5]) if len(sys.argv) > 5 else 28).save(out)
