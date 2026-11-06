#!/usr/bin/env python3
"""Mācron rebuilt part by part from the dance sprite, so a close-up is the sprite grown large and any pose is drawn, never stretched.
Every part is geometry in the sprite's own pixels (origin on the floor between his feet, y down, measured off atlas frame front_idle), transformed, then drawn with the sprite's heavy ink outline and palette onto one pixel grid.
Nothing is rotated as a bitmap, so rotated edges stay clean and no two frames can disagree about what he looks like."""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 4  # drawing pixels per grid cell
CELL = 2  # art pixels per grid cell, the close-ups' pixel size
# Palette sampled from the sprite. Canon's hexes are only "coordinates": reference art outranks them.
INK = (4, 19, 35, 255); CREAM = (242, 218, 178, 255); CREAM_HI = (251, 240, 211, 255); CREAM_LO = (201, 179, 146, 255)
SCREEN = (1, 53, 68, 255); TEAL = (4, 80, 100, 255); TEAL_LO = (1, 53, 68, 255); TEAL_HI = (23, 106, 109, 255)
CYAN = (3, 227, 245, 255); CYAN_LO = (1, 143, 169, 255); CYAN_HI = (190, 250, 255, 255); LOGO = (23, 106, 109, 255)
BLUSH = (246, 138, 150, 255); BLUSH_HI = (250, 176, 170, 255)
OIL = (20, 9, 8, 255); OIL2 = (120, 58, 18, 255); AMBER = (232, 134, 30, 255); GLASS_LINE = (150, 178, 190, 255); CLEAR = (205, 232, 240, 70); CLEAR2 = (235, 248, 252, 150); GLASS_BASE = (214, 232, 238, 230); GLASS_RIM = (240, 250, 252, 255); SHINE = (255, 255, 255, 190); SHINE2 = (255, 255, 255, 110)
LINE = 5.6  # outline thickness, sprite px: the sprite's own is about this
# The real mark, public/favicon.svg of macron.dev, viewBox 64: a macron bar, the bowl of the a, its stem, the stem of the i, and a dot.
LOGO_BOX = (15, 16, 48, 49)
LOGO_LINES = [[(15, 16), (35, 16)], [(35, 29), (35, 49)], [(48, 32), (48, 49)]]
LOGO_BOWL = [(35, 34), (33, 26), (16, 26), (16, 39), (16, 52), (33, 51), (35, 43)]  # "M35 34c-2-8-19-8-19 5s17 12 19 4", its two curves
LOGO_DOT = (48, 22, 3)


def rot(p, a, c=(0, 0)):
    s, k = math.sin(math.radians(a)), math.cos(math.radians(a)); x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * k - y * s, c[1] + x * s + y * k)


def sup(cx, cy, rx, ry, n=2.0, a=0, steps=72):
    """Superellipse outline: n 2 is an ellipse, higher is boxier. His shapes are all of this family."""
    out = []
    for i in range(steps):
        t = 2 * math.pi * i / steps; c, s = math.cos(t), math.sin(t)
        out.append(rot((cx + rx * abs(c) ** (2 / n) * (1 if c >= 0 else -1), cy + ry * abs(s) ** (2 / n) * (1 if s >= 0 else -1)), a, (cx, cy)))
    return out


def bez(a, b, c, steps=24):
    return [((1 - t) ** 2 * a[0] + 2 * t * (1 - t) * b[0] + t * t * c[0], (1 - t) ** 2 * a[1] + 2 * t * (1 - t) * b[1] + t * t * c[1]) for t in [i / steps for i in range(steps + 1)]]


class Canvas:
    """A layer in sprite coordinates. `to` puts the sprite's floor origin on the art at `origin`, `k` art px per sprite px."""
    def __init__(self, size, origin, k):
        self.size, self.origin, self.k = size, origin, k
        self.n = (size[0] // CELL, size[1] // CELL)
        self.im = Image.new("RGBA", (self.n[0] * SS, self.n[1] * SS), (0, 0, 0, 0))

    def to(self, p):
        q = SS / CELL
        return ((self.origin[0] + p[0] * self.k) * q, (self.origin[1] + p[1] * self.k) * q)

    def r(self, v):
        return v * self.k * SS / CELL

    def mask(self):
        return Image.new("L", self.im.size, 0)

    def poly(self, pts, fill, clip=None):
        m = self.mask(); ImageDraw.Draw(m).polygon([self.to(p) for p in pts], fill=255); self.fill(m, fill, clip); return m

    def circles(self, pts, widths, fill, clip=None):
        """A tube: a run of discs along a path, width varying along it."""
        m = self.mask(); d = ImageDraw.Draw(m); n = len(pts)
        for i, p in enumerate(pts):
            w = widths[i] if isinstance(widths, (list, tuple)) else widths; c = self.to(p); R = self.r(w / 2)
            d.ellipse([c[0] - R, c[1] - R, c[0] + R, c[1] + R], fill=255)
        self.fill(m, fill, clip); return m

    def fill(self, m, colour, clip=None):
        if clip is not None:
            m = Image.fromarray(np.minimum(np.asarray(m), np.asarray(clip)))
        self.im.paste(Image.new("RGBA", self.im.size, colour), (0, 0), m)

    def finish(self):
        """One colour per grid cell, by majority, then tidy the teeth off the edge. Output is art px."""
        a = np.asarray(self.im, dtype=np.uint32); h, w = a.shape[:2]; rows, cols = h // SS, w // SS
        key = (a[..., 0] << 24 | a[..., 1] << 16 | a[..., 2] << 8 | a[..., 3]) * (a[..., 3] >= 128)
        cells = key.reshape(rows, SS, cols, SS).transpose(0, 2, 1, 3).reshape(rows, cols, SS * SS); cells = np.sort(cells, axis=2)
        out = np.zeros((rows, cols, 4), dtype=np.uint8)
        for y in range(rows):
            for x in range(cols):
                v, c = np.unique(cells[y, x], return_counts=True); k = int(v[c.argmax()])
                out[y, x] = (k >> 24 & 255, k >> 16 & 255, k >> 8 & 255, k & 255)
        solid = out[..., 3] > 0
        for _ in range(2):
            n = np.zeros(solid.shape, dtype=int); n[1:] += solid[:-1]; n[:-1] += solid[1:]; n[:, 1:] += solid[:, :-1]; n[:, :-1] += solid[:, 1:]
            for y, x in zip(*np.where(~solid & (n >= 3))):
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if 0 <= y + dy < rows and 0 <= x + dx < cols and solid[y + dy, x + dx]: out[y, x] = out[y + dy, x + dx]; break
            out[solid & (n <= 1)] = 0; solid = out[..., 3] > 0
        return Image.fromarray(out, "RGBA").resize((cols * CELL, rows * CELL), Image.NEAREST)


def inked(c, pts, fill, line=LINE):
    """A closed shape with the sprite's outline: ink grown about its centre by the line width. Returns the fill's mask to clip shading to."""
    mx, my = sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)
    grown = []
    for i, p in enumerate(pts):
        a, b = pts[i - 1], pts[(i + 1) % len(pts)]; tx, ty = b[0] - a[0], b[1] - a[1]; L = math.hypot(tx, ty) or 1; nx, ny = ty / L, -tx / L
        if (p[0] - mx) * nx + (p[1] - my) * ny < 0: nx, ny = -nx, -ny
        grown.append((p[0] + nx * line, p[1] + ny * line))
    c.poly(grown, INK); return c.poly(pts, fill)


def eyes(c, style, head):
    """The face vocabulary is simple shapes on the screen, canon section 18. Round eyes, smiling arcs, and in-betweens."""
    cx, cy, a = head
    for side in (-1, 1):
        e = rot((cx + side * 33, cy + 6), a, (cx, cy)); ex, ey = e
        def p(dx, dy): return rot((ex + dx, ey + dy), a, e)
        if style in ("round", "wide"):
            R = 20 if style == "round" else 23
            c.poly(sup(ex, ey, R, R, 2), CYAN); c.poly(sup(*p(-R * .35, -R * .35), R * .28, R * .28, 2), CYAN_HI)
        elif style == "squash":
            c.poly(sup(ex, ey, 21, 10, 2.3, a), CYAN)
        elif style == "arc":  # the sprite's arcs: a thick half ring, open at the bottom
            pts = [p(math.cos(t) * 16, -math.sin(t) * 15 + 8) for t in [math.pi * i / 16 for i in range(17)]]
            c.circles(pts, 9, CYAN)
        elif style == "bigarc":
            pts = [p(math.cos(t) * 20, -math.sin(t) * 19 + 9) for t in [math.pi * i / 16 for i in range(17)]]
            c.circles(pts, 10, CYAN)
        elif style == "shut":  # squeezed tight on the swallow: chevrons, ">" and "<"
            for q in (bez(p(-side * 15, -12), p(side * 6, -4), p(side * 13, 0), 10), bez(p(side * 13, 0), p(side * 6, 4), p(-side * 15, 12), 10)): c.circles(q, 7.5, CYAN)


def draw_head(c, cx, cy, a=0, style="arc", blush=0, look=0):
    """Measured on the sprite: a wide rounded head that is nearly all screen, ears set low on its sides, orb on a short stem."""
    def h(x, y): return rot((cx + x, cy + y), a, (cx, cy))
    top = h(0, -55); ball = h(0, -92); hi = h(-5, -97)
    stem = [(top[0] + (ball[0] - top[0]) * i / 12, top[1] + (ball[1] - top[1]) * i / 12) for i in range(13)]; c.circles(stem, 11 + LINE * 2, INK); c.circles(stem, 11, TEAL)
    c.poly(sup(*ball, 15 + LINE, 15 + LINE, 2), INK); m = c.poly(sup(*ball, 15, 15, 2), CYAN); c.poly(sup(*h(0, -82), 17, 9, 2, a), CYAN_LO, m); c.poly(sup(*hi, 5, 4, 2, a), CYAN_HI, m)
    for s in (-1, 1):
        e = h(s * 85, 6); m = inked(c, sup(*e, 12, 29, 2.6, a), TEAL); c.poly(sup(*rot((e[0] + s * 3, e[1]), a, e), 4, 18, 2.6, a), CYAN_LO, m)
    m = inked(c, sup(cx, cy, 84, 62, 2.9, a), CREAM)
    c.poly(sup(*h(0, 58), 90, 18, 2.4, a), CREAM_LO, m); c.poly(sup(*h(0, -56), 62, 12, 2.4, a), CREAM_HI, m); c.poly(sup(*h(-68, -8), 5, 26, 2.4, a), CREAM_HI, m)
    s = h(look, 4)
    c.poly(sup(*s, 73, 47, 3.6, a), INK); c.poly(sup(*s, 69, 43, 3.6, a), SCREEN)
    eyes(c, style, (*h(look, 6), a))
    if blush:
        for sd in (-1, 1):
            b = h(sd * 56, 49); rx, ry = 5 + 3 * blush, 2 + 1.2 * blush
            c.poly(sup(*b, rx, ry, 2, a), BLUSH); c.poly(sup(*rot((b[0], b[1] - ry * .3), a, b), rx * .5, ry * .4, 2, a), BLUSH_HI)


def draw_logo(c, cx, cy, width, a=0, colour=LOGO, dot=CYAN):
    """The real āi, from its strokes, in the sprite's teal, with the dot in cyan as the favicon has it. Where the sprite's chest light was."""
    x0, y0, x1, y1 = LOGO_BOX; k = width / (x1 - x0); stroke = 5 * k
    def t(p): return rot((cx + (p[0] - (x0 + x1) / 2) * k, cy + (p[1] - (y0 + y1) / 2) * k), a, (cx, cy))
    for line in LOGO_LINES: c.circles([t(p) for p in [(line[0][0] + (line[1][0] - line[0][0]) * i / 10, line[0][1] + (line[1][1] - line[0][1]) * i / 10) for i in range(11)]], stroke, colour)
    b = LOGO_BOWL
    for i in (0, 3):
        p0, p1, p2, p3 = b[i:i + 4]
        path = [((1 - u) ** 3 * p0[0] + 3 * u * (1 - u) ** 2 * p1[0] + 3 * u * u * (1 - u) * p2[0] + u ** 3 * p3[0], (1 - u) ** 3 * p0[1] + 3 * u * (1 - u) ** 2 * p1[1] + 3 * u * u * (1 - u) * p2[1] + u ** 3 * p3[1]) for u in [j / 24 for j in range(25)]]
        c.circles([t(p) for p in path], stroke, colour)
    c.poly(sup(*t(LOGO_DOT[:2]), LOGO_DOT[2] * k * 1.25, LOGO_DOT[2] * k * 1.25, 2), dot)


def draw_torso(c, cx, cy, a=0, logo=True, look=0):
    """Round belly, a bit fuller than the sprite's so the mark has room. Baby Mācrons in the canon wear it this big."""
    def t(x, y): return rot((cx + x, cy + y), a, (cx, cy))
    inked(c, sup(*t(0, -38), 26, 10, 2.4, a), TEAL_LO)
    m = inked(c, sup(cx, cy, 50, 42, 2.25, a), CREAM)
    c.poly(sup(*t(0, 44), 58, 13, 2.3, a), CREAM_LO, m); c.poly(sup(*t(-40, 2), 10, 34, 2.3, a), CREAM_HI, m)
    if logo: draw_logo(c, *t(1 + look, 5), 50, a)


def draw_arm(c, shoulder, hand, bend=0, cuff=False, ball=True):
    """A short fat capsule from a teal ball joint to a teal mitten. `bend` bows it sideways a little, so it isn't a stick."""
    sx, sy = shoulder; hx, hy = hand; mx, my = (sx + hx) / 2, (sy + hy) / 2; dx, dy = hx - sx, hy - sy; L = math.hypot(dx, dy) or 1; nx, ny = -dy / L, dx / L
    path = bez((sx, sy), (mx + nx * bend, my + ny * bend), (hx, hy)); n = len(path); wid = [27 + 6 * i / (n - 1) for i in range(n)]
    c.circles(path, [w + LINE * 2 for w in wid], INK)
    if ball: c.poly(sup(sx, sy, 14 + LINE, 14 + LINE, 2), INK)
    m = c.circles(path, wid, CREAM)
    c.circles([(p[0] + 1, p[1] + 9) for p in path], [w * .5 for w in wid], CREAM_LO, m); c.circles([(p[0] - 1, p[1] - 6) for p in path], [w * .22 for w in wid], CREAM_HI, m)
    if cuff:
        for f, w in ((.45, 5.5), (.66, 5.5)):
            i = int(f * (n - 1)); p = path[i]; q = path[min(i + 1, n - 1)]; tx, ty = q[0] - p[0], q[1] - p[1]; T = math.hypot(tx, ty) or 1; nnx, nny = -ty / T, tx / T; r = wid[i] / 2 + 1
            c.circles([(p[0] + nnx * r * j / 5, p[1] + nny * r * j / 5) for j in range(-5, 6)], w, CYAN, m)
    if ball: bm = c.poly(sup(sx, sy, 14, 14, 2), TEAL); c.poly(sup(sx - 3, sy - 4, 5, 4, 2), TEAL_HI, bm)


def draw_mitten(c, hand, along=(1, 0)):
    x, y = hand; L = math.hypot(*along) or 1; ax, ay = along[0] / L, along[1] / L; cx, cy = x + ax * 7, y + ay * 7; ang = math.degrees(math.atan2(ay, ax))
    m = inked(c, sup(cx, cy, 19, 17, 2.2, ang), TEAL); c.poly(sup(cx + 1, cy + 9, 18, 9, 2.2, ang), TEAL_LO, m); c.poly(sup(cx - 5, cy - 6, 6, 4, 2, ang), TEAL_HI, m)


def draw_leg(c, hip, foot, toe=0):
    """Teal hip ball, then the rounded cream boot with its teal sole, standing on `foot` (the middle of the sole)."""
    fx, fy = foot
    def t(u, v): return rot((fx + u, fy + v), toe, (fx, fy))
    inked(c, sup(*hip, 13, 13, 2), TEAL)
    boot = []
    for x, y in sup(0, -20, 30, 20, 3.4):
        boot.append(t(x * (.62 + .38 * (y + 40) / 40), y))
    m = inked(c, boot, CREAM)
    c.poly([t(-40, -11), t(40, -11), t(40, 8), t(-40, 8)], TEAL_LO, m); c.poly([t(-40, -11), t(40, -11), t(40, -7), t(-40, -7)], TEAL, m)
    c.poly(sup(*t(-6, -18), 12, 6, 2, toe), CREAM_HI, m); c.poly([t(10, -50), t(40, -50), t(40, -11), t(16, -11)], CREAM_LO, m)


def glass_shape(rim, tilt, length, width):
    """Rim middle, tilt in degrees (0 upright, positive leans the rim to the picture's left), its size in sprite px. Corners rim-left, rim-right, base-right, base-left."""
    def t(u, v): return rot((rim[0] + u, rim[1] + v), -tilt, rim)
    return t, [t(-width / 2, 0), t(width / 2, 0), t(width * .42, length), t(-width * .42, length)]


def draw_glass(c, rim, tilt, fraction, length=166, width=100):
    """The bartender's glass, redrawn so it can tilt: see-through walls over whatever is behind, a heavy base, level oil with an amber edge. The volume is exact."""
    t, pts = glass_shape(rim, tilt, length, width); g = Canvas(c.size, c.origin, c.k)
    g.poly(pts, GLASS_LINE); inner = [t(-width * .44, 5), t(width * .44, 5), t(width * .37, length - 5), t(-width * .37, length - 5)]
    m = g.mask(); ImageDraw.Draw(m).polygon([g.to(p) for p in inner], fill=255)
    g.fill(m, CLEAR)
    well = [t(-width * .40, 8), t(width * .40, 8), t(width * .33, length - 18), t(-width * .33, length - 18)]
    wm = g.mask(); ImageDraw.Draw(wm).polygon([g.to(p) for p in well], fill=255); arr = np.asarray(wm) > 0; total = arr.sum(); rows = arr.sum(axis=1); cum = np.cumsum(rows[::-1])[::-1]
    level = int(np.argmax(cum <= total * fraction)) if fraction > 0 else m.size[1]
    oil = np.zeros_like(arr); oil[level:] = arr[level:]; g.fill(Image.fromarray((oil * 255).astype(np.uint8)), OIL)
    if fraction > 0:
        low = np.zeros_like(arr); band = max(1, int(g.r(5))); low[level + band:] = arr[level + band:]
        hue = np.zeros_like(arr); hue[level:level + band] = arr[level:level + band]; g.fill(Image.fromarray((hue * 255).astype(np.uint8)), AMBER)
        ed = np.zeros_like(arr); ys, xs = np.where(oil)
        if len(ys):  # a warm line around the oil against the glass, as the bartender's glass has
            big = np.asarray(Image.fromarray((arr * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(max(3, int(g.r(4)) | 1)))) > 0; ed = oil & ~big; g.fill(Image.fromarray((ed * 255).astype(np.uint8)), OIL2)
    g.poly([t(-width * .42, length - 17), t(width * .42, length - 17), t(width * .40, length - 2), t(-width * .40, length - 2)], GLASS_BASE)
    g.poly(sup(*t(0, 2), width * .5, 7, 2, -tilt), GLASS_RIM); g.poly(sup(*t(0, 2), width * .42, 3.6, 2, -tilt), CLEAR2)
    g.circles([t(width * .30, 20 + (length - 62) * i / 40) for i in range(41)], 6, SHINE); g.circles([t(-width * .32, 22 + 34 * i / 16) for i in range(17)], 4, SHINE2)
    c.im.alpha_composite(g.im); return t


def macron(c, dx=0, dy=0, lean=0, head_a=0, head_dx=0, head_dy=0, eye="arc", blush=0, arms=None, feet=((-37, 0), (37, 0)), toes=(0, 0), squash=0, logo=True, turn=0, behind=None, between=None, front=None):
    """The whole robot. dy lifts him (a hop), `lean` tips the upper body about the hips, `squash` sinks it. Feet stay where `feet` puts them. `turn` fakes a quarter turn to the picture right: face and mark slide over, the picture-left shoulder comes forward.
    `arms` maps "L" and "R" (picture left and right) to (hand, bend, cuff, layer, mitten direction), layer 0 behind the body, 1 over the belly but under the head, 2 over everything.
    `behind`, `between` and `front` are extra drawing: behind him, between belly and head, after everything. That is where a glass goes."""
    arms = arms or {}
    hipc = (dx, -56 + dy)
    def up(x, y): return rot((dx + x, dy + y), lean, hipc)
    belly = up(0, -90 + squash); headc = up(head_dx, -186 + squash * 1.5 + head_dy)
    shoulders = {"L": up(-50 + turn, -116 + squash), "R": up(50, -116 + squash)}
    def arm(layer):
        for side in "LR":
            if side in arms and arms[side][3] == layer:
                hand, bend, cuff, _, along = arms[side]; draw_arm(c, shoulders[side], hand, bend, cuff); draw_mitten(c, hand, along)
    if behind: behind(c)
    arm(0)
    for f, s, toe in zip(feet, (-1, 1), toes): draw_leg(c, up(s * 32, -45 + squash * .6), (f[0] + dx, f[1] + dy), toe)
    draw_torso(c, *belly, lean, logo, turn * .22)
    arm(1)
    if between: between(c)
    draw_head(c, *headc, lean + head_a, eye, blush, turn * .2)
    arm(2)
    if front: front(c)
