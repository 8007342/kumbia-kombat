#!/usr/bin/env python3
"""Review sheet: alpha on mid grey, with a caption-free grid. usage: sheet.py out.png cols cellh a.png b.png ..."""
import sys
from PIL import Image
out, cols, ch = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
ims = []
for p in sys.argv[4:]:
    im = Image.open(p).convert("RGBA"); k = ch / im.height
    im = im.resize((int(im.width * k), ch), Image.LANCZOS)
    bg = Image.new("RGBA", im.size, (150, 150, 155, 255)); bg.alpha_composite(im); ims.append(bg.convert("RGB"))
cw = max(i.width for i in ims); rows = (len(ims) + cols - 1) // cols
s = Image.new("RGB", (cols * cw + 8 * (cols - 1), rows * ch + 8 * (rows - 1)), (20, 20, 20))
for n, i in enumerate(ims):
    s.paste(i, ((n % cols) * (cw + 8), (n // cols) * (ch + 8)))
s.save(out)
