#!/usr/bin/env python3
"""A review sheet of real-renderer stills from build/duet-review, written by test/lawn_kiss_shot_test.dart. Usage: sheet.py out.png rows name [name ...] (without .png). Stills only: nobody has seen this move yet."""
import pathlib, sys
from PIL import Image, ImageDraw
out, cols = sys.argv[1], int(sys.argv[2]); names = sys.argv[3:]; R = pathlib.Path("build/duet-review"); W, H = 260, 563
S = Image.new("RGB", (cols * W, ((len(names) + cols - 1) // cols) * (H + 14)), (24, 24, 24)); d = ImageDraw.Draw(S)
for i, n in enumerate(names):
    im = Image.open(R / f"{n}.png").convert("RGB").resize((W - 4, H - 4)); x, y = (i % cols) * W, (i // cols) * (H + 14)
    S.paste(im, (x + 2, y + 14)); d.text((x + 3, y + 1), n, fill="white")
S.save(out); print(S.size)
