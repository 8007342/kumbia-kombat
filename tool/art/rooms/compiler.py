"""Room spec to greybox guide, id map, floor.json, prompts and level marks.

Coordinates: s runs along the room's main axis (towards the vanishing point), t to its right, z up.
The unit is one standing adult. The camera has no roll and verticals stay vertical, so standing
height at a floor point depends only on its image y: (y - horizon) / eyeHeight, which is the
runtime's PartyFloorPlane formula. A room is painted back to front, in the order it is listed.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
STYLE = json.loads((HERE / "style.json").read_text())
LOGICAL_WIDTH = 180.0  # PartyViewport.logicalWidth


class RoomError(Exception):
    """The room is refused. Every message names the field or element at fault."""

    def __init__(self, message, painted=None):
        super().__init__(message)
        self.painted = painted  # (painter, camera, floor, report) so a refused layout can still be looked at


COLOURS = {
    "sky": (20, 28, 70), "trees": (14, 60, 50), "lawn": (70, 140, 60), "path": (165, 150, 130), "joint": (95, 85, 75),
    "hedge": (20, 90, 60), "wall": (235, 220, 185), "roof": (170, 80, 50), "glass": (120, 170, 190),
    "inner": (90, 75, 70), "water": (30, 200, 220), "deck": (215, 205, 180), "glow": (92, 150, 62),
    "gate": (235, 220, 185), "lamp": (255, 225, 130), "lights": (255, 225, 130), "floor": (150, 120, 110),
    "panel": (95, 70, 110), "window": (60, 110, 160), "pilaster": (235, 215, 180), "stage": (150, 60, 70),
    "door": (240, 190, 110),
}
IDS = {name: i + 1 for i, name in enumerate(COLOURS)}

TOP_KEYS = {"id", "title", "camera", "phone", "safe", "tapBand", "cast", "walkable", "standable", "paint", "story",
            "marks", "props", "scene", "zones", "keep", "styleRef", "level", "comment", "genSize", "platforms"}
CAMERA_KEYS = {"horizonY", "eyeHeightAdults", "focalPx", "vanishingX", "originBottomX"}
MARK_KEYS = {"heroHome", "heroEntrance", "heroRetreat", "challengers", "guests", "route", "plants", "routeFacing", "pathEnd"}


class Camera:
    W, H = 1024, 1536

    def __init__(self, c):
        unknown = set(c) - CAMERA_KEYS
        if unknown or CAMERA_KEYS - set(c):
            raise RoomError(f"camera: unknown {sorted(unknown)}, missing {sorted(CAMERA_KEYS - set(c))}")
        self.hz, self.eye, self.f = c["horizonY"] * self.H, c["eyeHeightAdults"], c["focalPx"]
        self.vpx = c["vanishingX"] * self.W
        self.yaw = math.atan((self.vpx - self.W / 2) / self.f)
        self.d = np.array([math.sin(self.yaw), math.cos(self.yaw)])
        self.n = np.array([math.cos(self.yaw), -math.sin(self.yaw)])
        y0 = self.f * self.eye / (self.H - self.hz)
        self.p0 = np.array([(c["originBottomX"] * self.W - self.W / 2) * y0 / self.f, y0])

    def depth(self, s, t):
        return float((self.p0 + s * self.d + t * self.n)[1])

    def proj(self, s, t, z=0.0):
        x, y = self.p0 + s * self.d + t * self.n
        return (self.W / 2 + self.f * x / y, self.hz + self.f * (self.eye - z) / y)

    def adult_px(self, y_px):
        return (y_px - self.hz) / self.eye

    def floor_at(self, x_frac, y_frac):
        """Inverse projection: the (s, t) of an image point on the floor."""
        q = np.linalg.solve(self.homography(), [x_frac * self.W, y_frac * self.H, 1.0])
        return float(q[0] / q[2]), float(q[1] / q[2])

    def homography(self):
        A, b = [], []
        for s, t in [(0, -1), (0, 1), (8, -1), (8, 1)]:
            u, v = self.proj(s, t)
            A.append([s, t, 1, 0, 0, 0, -u * s, -u * t]); b.append(u)
            A.append([0, 0, 0, s, t, 1, -v * s, -v * t]); b.append(v)
        return np.append(np.linalg.solve(np.array(A, float), np.array(b, float)), 1).reshape(3, 3)


class Painter:
    def __init__(self, cam):
        self.cam = cam
        self.col = Image.new("RGB", (cam.W, cam.H), COLOURS["sky"])
        self.idm = Image.new("L", (cam.W, cam.H), IDS["sky"])
        self.dc, self.di = ImageDraw.Draw(self.col), ImageDraw.Draw(self.idm)
        self.lamps = []        # glow centres in image pixels
        self.full_area = {}    # id: pixels it would cover with nothing in front of it
        self.lines = {}        # floor lines (s,t) lists, for drift measurement

    def _clip(self, world, near=0.5):
        out = []
        for i, a in enumerate(world):
            b = world[(i + 1) % len(world)]
            da, db = self.cam.depth(a[0], a[1]) - near, self.cam.depth(b[0], b[1]) - near
            if da >= 0:
                out.append(a)
            if (da >= 0) != (db >= 0):
                k = da / (da - db)
                out.append(tuple(a[j] + k * (b[j] - a[j]) for j in range(3)))
        return out

    def poly(self, pts, name):
        pts = [tuple(p) for p in pts]
        self.dc.polygon(pts, fill=COLOURS[name]); self.di.polygon(pts, fill=IDS[name])

    def wpoly(self, world, name):
        w = self._clip([tuple(q) + (0.0,) * (3 - len(q)) for q in world])
        if len(w) >= 3:
            self.poly([self.cam.proj(*q) for q in w], name)

    def count(self, world, name):
        """Pixels a floor polygon would cover unoccluded, inside the frame."""
        w = self._clip([tuple(q) + (0.0,) * (3 - len(q)) for q in world])
        m = Image.new("1", (self.cam.W, self.cam.H)); ImageDraw.Draw(m).polygon([self.cam.proj(*q) for q in w], fill=1)
        self.full_area[name] = self.full_area.get(name, 0) + int(np.asarray(m).sum())

    def line(self, a, b, name, width=3):
        self.dc.line([a, b], fill=COLOURS[name], width=width); self.di.line([a, b], fill=IDS[name], width=width)

    def disc(self, x, y, r, name):
        box = [x - r, y - r, x + r, y + r]
        self.dc.ellipse(box, fill=COLOURS[name]); self.di.ellipse(box, fill=IDS[name])

    # ---- primitives, each one kind in a spec's "paint" list ----
    def backdrop(self, id, y):
        """Silhouette in image fractions, x evenly spaced, down to below the horizon."""
        W, H = self.cam.W, self.cam.H
        pts = [(W * i / (len(y) - 1), v * H) for i, v in enumerate(y)]
        self.poly(pts + [(W, self.cam.hz + 8), (0, self.cam.hz + 8)], id)

    def ground(self, id, s, t, count=False):
        q = [(s[0], t[0]), (s[0], t[1]), (s[1], t[1]), (s[1], t[0])]
        self.wpoly(q, id)
        if count:
            self.count(q, id)

    def field(self, id):
        """Everything below the horizon."""
        y = self.cam.hz + 6
        self.dc.rectangle([0, y, self.cam.W, self.cam.H], fill=COLOURS[id]); self.di.rectangle([0, y, self.cam.W, self.cam.H], fill=IDS[id])

    def paving(self, id, s, t, every, lanes, joint="joint"):
        self.ground(id, s, t)
        lines = []
        # lines stop in front of the camera: a point behind it would project across the picture
        near = next(v for v in np.arange(s[0], s[1], .05) if min(self.cam.depth(v, t[0]), self.cam.depth(v, t[1])) > .6)
        s = (float(near), s[1])
        for sj in np.arange(max(s[0], 0), s[1], every):
            self.line(self.cam.proj(sj, t[0]), self.cam.proj(sj, t[1]), joint)
            lines.append([(float(sj), float(v)) for v in np.linspace(t[0], t[1], 16)])
        self.lines["cross"] = [p for ln in lines for p in ln]
        for k, tj in enumerate(np.linspace(t[0], t[1], lanes + 1)):
            self.line(self.cam.proj(s[0], tj), self.cam.proj(s[1], tj), joint)
            self.lines[f"lane-{k}"] = [(float(v), float(tj)) for v in np.linspace(s[0], s[1], 90)]

    def wall(self, id, a, b, z):
        self.wpoly([(*a, z[0]), (*b, z[0]), (*b, z[1]), (*a, z[1])], id)

    def box(self, id, s, t, z, top=None):
        """Painter order: the two faces towards the camera, then the top."""
        self.wall(id, (s[0], t[0]), (s[0], t[1]), z)
        self.wall(id, (s[0], t[0]), (s[1], t[0]), z) if t[0] > 0 else self.wall(id, (s[0], t[1]), (s[1], t[1]), z)
        self.wpoly([(s[0], t[0], z[1]), (s[0], t[1], z[1]), (s[1], t[1], z[1]), (s[1], t[0], z[1])], top or id)

    def arcade(self, id, a, b, bays, z, column=0.14):
        """Columns with round arches between them: a wall with its bays cut out."""
        a, b = np.array(a, float), np.array(b, float)
        sp = (b - a) / bays
        for i in range(bays + 1):
            c = a + sp * i
            w = sp / np.hypot(*sp) * column
            self.wall(id, tuple(c - w), tuple(c + w), (0, z[1]))
        rise = min(.5 * np.hypot(*sp), z[1] - z[0])
        for i in range(bays):
            p, q = a + sp * i, a + sp * (i + 1)
            pts = []
            for k in range(13):
                th = math.pi * k / 12
                u = (1 - math.cos(th)) / 2
                c = p + (q - p) * u
                pts.append((c[0], c[1], z[1] - rise + rise * math.sin(th)))
            pts += [(q[0], q[1], z[1]), (p[0], p[1], z[1])]
            self.wpoly(pts, id)

    def hip(self, id, s, t, z, rise):
        mid = ((s[0] + s[1]) / 2, (t[0] + t[1]) / 2, z + rise)
        self.wpoly([(s[1], t[0], z), (s[1], t[1], z), mid], id)
        self.wpoly([(s[0], t[0], z), (s[1], t[0], z), mid], id)
        self.wpoly([(s[0], t[1], z), (s[1], t[1], z), mid], id)
        self.wpoly([(s[0], t[0], z), (s[0], t[1], z), mid], id)

    def gate(self, id, s, t, height, post=.3, thick=.35):
        self.box(id, (s, s + thick), (t[0] - post, t[0]), (0, height))
        self.box(id, (s, s + thick), (t[1], t[1] + post), (0, height))
        self.wpoly([(s, t[0] - post, height), (s, t[1] + post, height), (s, t[1] + post, height + .35), (s, t[0] - post, height + .35)], id)

    def lantern(self, at, height=1.1, id="wall", lamp="lamp"):
        u, v = self.cam.proj(*at)
        _, top = self.cam.proj(*at, height)
        a = self.cam.adult_px(v)
        self.dc.rectangle([u - a * .025, top, u + a * .025, v], fill=COLOURS[id]); self.di.rectangle([u - a * .025, top, u + a * .025, v], fill=IDS[id])
        self.disc(u, top, max(3, a * .06), lamp)
        self.lamps.append((u, top))

    def pools(self, id, at, r=.9):
        """Pools of warm light on the ground, where props will stand."""
        for s, t in at:
            pts = [(s + r * math.cos(k * math.pi / 12), t + r * math.sin(k * math.pi / 12)) for k in range(24)]
            self.wpoly(pts, id)

    def string(self, id, a, b, sag=.3, n=11):
        """String of lights between two world points: a sagging line of small dots."""
        pts = []
        for i in range(n):
            u = i / (n - 1)
            q = [a[j] + (b[j] - a[j]) * u for j in range(3)]
            q[2] -= sag * 4 * u * (1 - u)
            x, y = self.cam.proj(*q)
            pts.append((x, y))
        for p, q in zip(pts, pts[1:]):
            self.line(p, q, "joint", 1)
        for x, y in pts:
            self.disc(x, y, 3, id)

    def repeat(self, of, count, start, step, **kw):
        """The same primitive stepped along s: its `s`, or its `a` and `b`, move by step per copy."""
        for i in range(count):
            d = dict(kw)
            off = start + i * step
            if "s" in d:
                d["s"] = [v + off for v in d["s"]]
            if "a" in d:
                d["a"], d["b"] = [d["a"][0] + off, d["a"][1]], [d["b"][0] + off, d["b"][1]]
            getattr(self, of)(**d)

    def discs(self, id, at, r):
        """Glowing shapes hung in the air at [s, t, z], such as chandeliers."""
        for s, t, z in at:
            x, y = self.cam.proj(s, t, z)
            self.disc(x, y, r * self.cam.f / self.cam.depth(s, t), id)
            self.lamps.append((x, y))


PRIMITIVES = {"backdrop", "field", "ground", "paving", "wall", "box", "arcade", "hip", "gate", "lantern", "pools", "string", "repeat", "discs"}


def load_spec(path):
    path = Path(path)
    if not path.exists():
        path = HERE / f"{path}.json"
    try:
        spec = json.loads(path.read_text())
    except FileNotFoundError:
        raise RoomError(f"no room spec at {path}") from None
    unknown = set(spec) - TOP_KEYS
    if unknown:
        raise RoomError(f"unknown fields: {sorted(unknown)}")
    missing = {"id", "camera", "phone", "safe", "tapBand", "cast", "walkable", "paint", "story", "marks", "zones"} - set(spec)
    if missing:
        raise RoomError(f"missing fields: {sorted(missing)}")
    unknown = set(spec["marks"]) - MARK_KEYS
    if unknown:
        raise RoomError(f"marks: unknown fields {sorted(unknown)}")
    return spec


def paint(spec, cam):
    p = Painter(cam)
    for i, op in enumerate(spec["paint"]):
        op = dict(op)
        kind = op.pop("kind", None)
        if kind not in PRIMITIVES:
            raise RoomError(f"paint[{i}].kind: unknown primitive {kind!r}; expected one of {sorted(PRIMITIVES)}")
        name = op.get("id")
        if name is not None and name not in COLOURS:
            raise RoomError(f"paint[{i}].id: unknown zone {name!r}; expected one of {sorted(COLOURS)}")
        try:
            getattr(p, kind)(**op)
        except TypeError as e:
            raise RoomError(f"paint[{i}] ({kind}): {e}") from None
    return p


def phone_crop(width, height, cam=Camera):
    """Central source x range a phone's cover transform shows."""
    vis = (width / height) / (cam.W / cam.H)
    return ((1 - vis) / 2, 1 - (1 - vis) / 2)


def compile_room(spec):
    """Returns (painter, camera, floor dict, report). Raises RoomError listing every problem it found."""
    cam = Camera(spec["camera"])
    p = paint(spec, cam)
    ids = np.asarray(p.idm)
    W, H = cam.W, cam.H
    problems, report = [], {}

    def present(names, field):
        for n in names:
            if n not in IDS:
                problems.append(f"{field}: unknown zone {n!r}")

    walkable = spec["walkable"]; standable = spec.get("standable", walkable)
    present(walkable, "walkable"); present(standable, "standable")
    walk_ids = [IDS[n] for n in walkable if n in IDS]; stand_ids = [IDS[n] for n in standable if n in IDS]

    # --- the phone crop is hard: the declared safe box must be inside what the phone shows
    x0, x1 = phone_crop(*spec["phone"].values())
    sx, sy = spec["safe"]["x"], spec["safe"]["y"]
    report["phoneVisibleX"] = [round(x0, 3), round(x1, 3)]
    if sx[0] < x0 or sx[1] > x1:
        problems.append(f"safe.x {sx} leaves the {spec['phone']['width']}x{spec['phone']['height']} crop {x0:.3f}..{x1:.3f}")
    band = spec["tapBand"]["y"]
    if sy[1] > band[0]:
        problems.append(f"safe.y bottom {sy[1]} runs into the tap band at {band[0]}")

    # --- story elements must sit in the box. Roofs may run under the HUD (top), never out of the sides
    report["story"] = {}
    for el in spec["story"]:
        unknown = set(el) - {"name", "ids", "ignoreTop", "minOpen"}
        if unknown:
            problems.append(f"story.{el.get('name')}: unknown fields {sorted(unknown)}")
        present(el["ids"], f"story.{el['name']}.ids")
        mask = np.isin(ids, [IDS[n] for n in el["ids"] if n in IDS])
        if not mask.any():
            problems.append(f"story.{el['name']}: none of {el['ids']} is visible")
            continue
        ys, xs = np.nonzero(mask)
        b = [xs.min() / W, ys.min() / H, (xs.max() + 1) / W, (ys.max() + 1) / H]
        report["story"][el["name"]] = [round(v, 3) for v in b]
        if b[0] < sx[0] or b[2] > sx[1]:
            problems.append(f"story.{el['name']}: x {b[0]:.3f}..{b[2]:.3f} leaves the phone-safe box x {sx[0]}..{sx[1]}")
        if b[3] > sy[1]:
            problems.append(f"story.{el['name']}: reaches y {b[3]:.3f}, below the safe box bottom {sy[1]}")
        if not el.get("ignoreTop") and b[1] < sy[0]:
            problems.append(f"story.{el['name']}: rises to y {b[1]:.3f}, above the safe box top {sy[0]} (the HUD)")
        if "minOpen" in el:
            name, need = el["minOpen"]["id"], el["minOpen"]["ratio"]
            seen = int((ids == IDS[name]).sum()); full = p.full_area.get(name, 0)
            ratio = seen / full if full else 0
            report["story"][el["name"] + ".open"] = round(ratio, 3)
            if ratio < need:
                problems.append(f"story.{el['name']}: only {ratio:.0%} of {name} shows between its columns; needs {need:.0%}")

    # --- tap band: only calm floor down there, and no marks or story in it
    allow = spec["tapBand"]["allow"]; present(allow, "tapBand.allow")
    region = ids[int(band[0] * H):int(band[1] * H), int(x0 * W):int(x1 * W)]
    bad = sorted({n for n, v in IDS.items() if n not in allow and (region == v).any()})
    if bad:
        problems.append(f"tapBand: {bad} show inside the band y {band[0]}..{band[1]}; only {allow} may")

    # --- marks and routes
    marks = spec["marks"]
    H_ = cam.homography()

    def at(st):
        x, y = cam.proj(*st)
        return x, y

    def check(name, st, zones, in_band_ok=False):
        x, y = at(st)
        ix, iy = int(round(x)), int(round(y))
        if not (0 <= ix < W and 0 <= iy < H):
            problems.append(f"marks.{name}: {st} projects off the plate at ({x:.0f}, {y:.0f})")
            return
        pad = 3
        win = ids[max(iy - pad, 0):iy + pad + 1, max(ix - pad, 0):ix + pad + 1]
        if not np.isin(win, zones).all():
            problems.append(f"marks.{name}: {st} at ({x / W:.3f}, {y / H:.3f}) stands on {sorted({k for k, v in IDS.items() if (win == v).any()})}, not on {'walkable' if zones == walk_ids else 'standable'} ground")
        if y <= cam.hz:
            problems.append(f"marks.{name}: above the horizon")
        if not (sx[0] <= x / W <= sx[1]) and not in_band_ok:
            problems.append(f"marks.{name}: x {x / W:.3f} leaves the phone-safe box")
        if y / H > band[0] and not in_band_ok:
            problems.append(f"marks.{name}: foot y {y / H:.3f} is in the tap band (starts {band[0]})")

    check("heroHome", marks["heroHome"], walk_ids)
    check("heroEntrance", marks["heroEntrance"], walk_ids, in_band_ok=True)
    check("heroRetreat", marks["heroRetreat"], walk_ids, in_band_ok=True)
    for c in marks.get("challengers", []):
        check(f"challengers.{c['id']}.mark", c["mark"], walk_ids)
        check(f"challengers.{c['id']}.yieldMark", c["yieldMark"], walk_ids + stand_ids)
    route = marks.get("route", [])
    for i, st in enumerate(route):
        check(f"route[{i}]", st, walk_ids)
    if route and "pathEnd" in marks:
        last = at(route[-1]); end = at(marks["pathEnd"])
        if abs(last[1] - end[1]) > 40:
            problems.append(f"marks.route: ends {abs(last[1] - end[1]):.0f}px short of pathEnd")
    for i, st in enumerate(marks.get("guests", [])):
        check(f"guests[{i}]", st, stand_ids)
    for i, st in enumerate(marks.get("plants", [])):
        check(f"plants[{i}]", st, stand_ids + walk_ids, in_band_ok=True)
    for i, prop in enumerate(spec.get("props", [])):
        check(f"props[{i}] {prop['id']}", prop["at"], stand_ids)

    # --- cast size is settled here, before any art
    hero_y = at(marks["heroHome"])[1]
    logical_h = LOGICAL_WIDTH * spec["phone"]["height"] / spec["phone"]["width"]
    stature = spec["cast"]["heroStature"]
    adult_frac = (hero_y - cam.hz) / cam.eye / H
    hero_logical = adult_frac * stature * logical_h
    report["cast"] = {
        "adultAtHeroMarkSourcePx": round(adult_frac * H, 1),
        "heroAtMarkLogical": round(hero_logical, 1),
        "heroAtMarkDp": round(hero_logical * spec["phone"]["width"] / LOGICAL_WIDTH, 1),
        "reference": "garden 38.4 logical (83 dp), bar 66.7 logical (145 dp) at the same phone",
    }
    if hero_logical < spec["cast"]["minHeroLogical"]:
        problems.append(f"cast: Mācron is {hero_logical:.1f} logical px at heroHome; needs at least {spec['cast']['minHeroLogical']}. Lower the camera, or raise the horizon")

    floor = {
        "image": [W, H], "horizonY": cam.hz / H, "vanishingX": cam.vpx / W, "eyeHeightAdults": cam.eye, "focalPx": cam.f,
        "floorHomography_st_to_px": H_.tolist(), "ids": IDS, "walkable": walkable, "standable": standable,
        "safe": spec["safe"], "tapBand": spec["tapBand"], "phone": spec["phone"], "phoneVisibleX": report["phoneVisibleX"],
        "platforms": platform_tops(spec, cam), "lines": p.lines, "lampsNormalized": [[round(x / W, 4), round(y / H, 4)] for x, y in p.lamps],
        "walkablePixels": int(np.isin(ids, walk_ids).sum()),
        "note": "Adult height at foot y, as a fraction of image height: (y - horizonY) / eyeHeightAdults",
    }
    if problems:
        raise RoomError("room refused:\n  - " + "\n  - ".join(problems), painted=(p, cam, floor, report))
    return p, cam, floor, report


def prompts(spec):
    """Generated from the same data as the greybox (A5): only zones the guide really paints are described."""
    painted = set()
    for op in spec["paint"]:
        if "id" in op:
            painted.add(op["id"])
        if op.get("kind") == "lantern":
            painted.add("lamp")
    for name in spec["zones"]:
        if name not in painted and name not in COLOURS:
            raise RoomError(f"zones.{name}: unknown zone")
    missing = sorted(n for n in painted if n not in spec["zones"] and n not in ("joint",))
    if missing:
        raise RoomError(f"zones: painted zones without any wording: {missing}")
    names = STYLE["colourNames"]
    layout = " ".join(f"The {names[n]} {'are' if names[n].endswith(('dots', 'lines')) else 'area is'} {z['layout']}"
                      for n, z in spec["zones"].items() if n in painted)
    final = " ".join(z["paint"] for n, z in spec["zones"].items() if n in painted and z.get("paint"))
    fill = dict(style=STYLE["styleBlock"], empty=STYLE["emptySet"], scene=spec.get("scene", ""))
    return {
        "pass1": STYLE["pass1"].format(zones=layout, **fill).strip(),
        "pass2": STYLE["pass2"].format(zones=final, keep=spec["keep"], **fill).strip(),
    }


def platform_tops(spec, cam):
    """Raised surfaces people can stand on, such as a bandstand, from the box each one names in `paint`.

    A figure on top keeps the scale of the floor point under it: its feet go at proj(s, t, z), its height comes
    from the image y of proj(s, t, 0), through the same (y - horizon) / eye as anywhere else.
    """
    tops = []
    for platform in spec.get("platforms", []):
        boxes = [p for p in spec["paint"] if p.get("kind") == "box" and p.get("id") == platform["box"]]
        if len(boxes) != 1:
            raise RoomError(f"platforms: {platform['id']} names box {platform['box']!r}, found {len(boxes)}")
        s, t, z = boxes[0]["s"], boxes[0]["t"], boxes[0]["z"][1]
        corners = [(s[0], t[0]), (s[0], t[1]), (s[1], t[1]), (s[1], t[0])]
        tops.append({"id": platform["id"], "s": s, "t": t, "heightAdults": z,
                     "topCornersFrac": [[round(v, 4) for v in (cam.proj(a, b, z)[0] / cam.W, cam.proj(a, b, z)[1] / cam.H)] for a, b in corners],
                     "note": platform.get("note", "")})
    return tops


def level_fragment(spec, cam, floor):
    """The geometry half of a level file, in the fractions levels/*.json use."""
    W, H = cam.W, cam.H
    marks = spec["marks"]

    def frac(st, nd=3):
        x, y = cam.proj(*st)
        return [round(x / W, nd), round(y / H, nd)]

    hero = frac(marks["heroHome"])
    ref_y = 0.40 if cam.hz / H < .35 else round((cam.hz / H + 1) / 2, 2)
    # Waypoints spaced by world distance: equal screen speed looks wrong on a long diagonal.
    route = marks.get("route", [])
    faces = marks.get("routeFacing", ["sideRight"] + ["rear"] * (len(route) - 1))
    lens = [0.0]
    for a, b in zip(route, route[1:]):
        lens.append(lens[-1] + math.dist(a, b))
    waypoints = [{"at": round(l / lens[-1], 3), "x": frac(st)[0], "y": frac(st)[1], "facing": f}
                 for st, l, f in zip(route, lens, faces)]
    return {
        "stage": {
            "calibration": "unverifiedStoryboard",
            "floor": {"horizonY": round(cam.hz / H, 4), "referenceFootY": ref_y,
                      "referenceHeight": round((ref_y - cam.hz / H) / cam.eye, 4)},
            "heroHome": hero, "heroEntrance": frac(marks["heroEntrance"]), "heroRetreat": frac(marks["heroRetreat"]),
            "challengers": [{"id": c["id"], "atlas": c["atlas"], "mark": frac(c["mark"]), "yieldMark": frac(c["yieldMark"])}
                            for c in marks.get("challengers", [])],
        },
        "crowd": {
            "guests": [frac(g) for g in marks.get("guests", [])],
            "props": [{**{k: v for k, v in pr.items() if k != "at"}, "at": frac(pr["at"])} for pr in spec.get("props", [])],
        },
        "scenery": {"lamps": floor["lampsNormalized"], "plants": [frac(g) for g in marks.get("plants", [])]},
        "departure": {"originY": hero[1], "waypoints": waypoints},
    }


def write_outputs(spec, out):
    p, cam, floor, report = compile_room(spec)
    texts = prompts(spec)
    frag = level_fragment(spec, cam, floor)
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    (out / "REFUSED-overlay.png").unlink(missing_ok=True)
    p.col.save(out / "greybox-1024.png")
    gw, gh = spec.get("genSize", [832, 1248])
    p.col.resize((gw, gh), Image.LANCZOS).save(out / "greybox.png")
    p.idm.save(out / "ids.png")
    overlay(p.col.copy(), spec, cam, floor, frag).save(out / "overlay.png")
    (out / "floor.json").write_text(json.dumps(floor, indent=1) + "\n")
    (out / "level.fragment.json").write_text(json.dumps(frag, indent=1, ensure_ascii=False) + "\n")
    (out / "report.json").write_text(json.dumps(report, indent=1, ensure_ascii=False) + "\n")
    for k, v in texts.items():
        (out / f"prompt-{k}.txt").write_text(v + "\n")
    return report


def preview_refused(spec, error, out):
    """A refused room writes only its overlay, named so nobody generates from it."""
    p, cam, floor, _ = error.painted
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    frag = level_fragment(spec, cam, floor)
    overlay(p.col.copy(), spec, cam, floor, frag).save(out / "REFUSED-overlay.png")
    return out / "REFUSED-overlay.png"


def overlay(im, spec, cam, floor, frag):
    """Crop lines, safe box, tap band, a floor grid and sized figures at the marks: the first thing a person reviews."""
    W, H = cam.W, cam.H
    d = ImageDraw.Draw(im, "RGBA")
    x0, x1 = floor["phoneVisibleX"]
    d.rectangle([x0 * W, 0, x1 * W, H - 1], outline=(255, 0, 255, 255), width=3)
    s = spec["safe"]
    d.rectangle([s["x"][0] * W, s["y"][0] * H, s["x"][1] * W, s["y"][1] * H], outline=(255, 255, 255, 255), width=2)
    band = spec["tapBand"]["y"]
    d.rectangle([x0 * W, band[0] * H, x1 * W, band[1] * H], fill=(255, 0, 80, 50))
    d.line([0, cam.hz, W, cam.hz], fill=(255, 255, 0, 255), width=2)
    Hm = np.array(floor["floorHomography_st_to_px"])

    def fig(x, y, stature, col):
        h = (y - cam.hz) / cam.eye * stature
        d.rectangle([x - h * .17, y - h, x + h * .17, y], outline=col, width=3)

    st = frag["stage"]
    fig(st["heroHome"][0] * W, st["heroHome"][1] * H, spec["cast"]["heroStature"], (0, 255, 255, 255))
    for c in st["challengers"]:
        fig(c["mark"][0] * W, c["mark"][1] * H, 1, (255, 255, 255, 255))
    for g in frag["crowd"]["guests"]:
        fig(g[0] * W, g[1] * H, 1, (255, 200, 0, 255))
    for w_ in frag["departure"]["waypoints"]:
        d.ellipse([w_["x"] * W - 5, w_["y"] * H - 5, w_["x"] * W + 5, w_["y"] * H + 5], fill=(0, 255, 255, 255))
    return im
