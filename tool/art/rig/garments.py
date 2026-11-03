"""Parametric garments and props: how a character definition becomes geometry.

Each shape draws one flat region colour, so every garment has a mask that can be
scored, recoloured or regenerated on its own. Add a shape here and to
library.json; definitions can then use it with no other change.
"""

from __future__ import annotations

from dataclasses import dataclass

from mathutils import Matrix, Vector

from prims import add_box, add_capsule, add_cyl, add_sphere


HEM = 0.84  # fraction of the shin a trouser leg covers
HEM_DRAG = 0.045  # metres a lagging hem may trail the hips, about two native pixels


def rot(axis, deg: float) -> Matrix:
    import math
    return Matrix.Rotation(math.radians(deg), 3, axis)


@dataclass
class Ctx:
    p: object
    j: dict
    regions: dict
    region: str
    params: dict
    prev: dict | None = None   # joints of the previous drawing, for one-drawing lag
    lag: str | None = None     # the garment's secondaryMotion


def hem_lag(c: Ctx) -> Vector:
    """Sideways drag of a hem on lag-1: it is still where the hips were one drawing ago."""
    if c.lag != "lag-1" or c.prev is None:
        return Vector((0, 0, 0))
    now = (c.j["l_hip"] + c.j["r_hip"]) / 2
    was = (c.prev["l_hip"] + c.prev["r_hip"]) / 2
    # Cloth settles a little: a big hip travel must not fling the hem out of the silhouette.
    return Vector((max(-HEM_DRAG, min(HEM_DRAG, was.x - now.x)), 0, 0))


def _torso_axes(j: dict):
    up = (j["chest"] - j["pelvis"]).normalized()
    return up, up.to_track_quat("Z", "Y").to_matrix()


def base_body(p, j: dict, regions: dict) -> None:
    """Skin everywhere a garment may leave open: head, neck, arms, hands, legs."""
    R = p.limb_r
    add_capsule(j["chest"], j["neck"], 0.06, "skin", regions)
    hr: Matrix = j["_head_rot"]
    add_sphere(j["head"], p.head_r, "skin", regions, scale=(0.95, 0.95, 1.05), rot_m=hr)
    for s in ("l", "r"):
        add_capsule(j[f"{s}_sho"], j[f"{s}_elb"], R["fore"], "skin", regions)
        add_capsule(j[f"{s}_elb"], j[f"{s}_wri"], R["fore"], "skin", regions)
        fore = (j[f"{s}_wri"] - j[f"{s}_elb"]).normalized()
        # Mitten hand: large and simple, longer than wide, so it reads at sprite
        # size and the generator paints a hand rather than a stump.
        add_sphere(j[f"{s}_wri"] + fore * R["hand"] * 0.95, R["hand"], "skin", regions,
                   scale=(0.82, 0.62, 1.25), rot_m=fore.to_track_quat("Z", "Y").to_matrix())
        add_capsule(j[f"{s}_hip"], j[f"{s}_kne"], R["shin"] * 0.9, "skin", regions)
        # Rounded leg ends stop above the ankle so they never dip below the ground line.
        add_capsule(j[f"{s}_kne"], j[f"{s}_kne"].lerp(j[f"{s}_ank"], HEM), R["shin"] * 0.9, "skin", regions)
        add_capsule(j[f"{s}_kne"].lerp(j[f"{s}_ank"], HEM), j[f"{s}_ank"], 0.05, "skin", regions)


def brimmed_hat(c: Ctx) -> None:
    hr, hd, R = c.j["_head_rot"], c.p.head_r, c.p.limb_r
    add_cyl(c.j["head"] + hr @ Vector((0, 0, hd * 0.74)), R["brim"], 0.022, c.region, c.regions, rot_m=hr)
    add_cyl(c.j["head"] + hr @ Vector((0, 0, hd * 1.2)), R["crown"], 0.14, c.region, c.regions, rot_m=hr)


def hat_band(c: Ctx) -> None:
    hr, hd, R = c.j["_head_rot"], c.p.head_r, c.p.limb_r
    add_cyl(c.j["head"] + hr @ Vector((0, 0, hd * 0.92)), R["crown"] * 1.03, 0.045, c.region, c.regions, rot_m=hr)


def short_hair_moustache(c: Ctx) -> None:
    hr, hd = c.j["_head_rot"], c.p.head_r
    add_sphere(c.j["head"] + hr @ Vector((0, hd * 0.4, 0.0)), hd * 0.9, c.region, c.regions, scale=(0.97, 0.75, 0.85), rot_m=hr)
    add_sphere(c.j["head"] + hr @ Vector((0, -hd * 0.92, -hd * 0.3)), 0.035, c.region, c.regions, scale=(1.7, 0.6, 0.45), rot_m=hr)


def puff(c: Ctx) -> None:
    """Hair tied up in a rounded puff, with a band of hair around the skull."""
    hr, hd = c.j["_head_rot"], c.p.head_r
    add_sphere(c.j["head"] + hr @ Vector((0, 0.05, hd * 0.2)), hd * 0.98, c.region, c.regions, scale=(1.02, 0.85, 0.9), rot_m=hr)
    add_sphere(c.j["head"] + hr @ Vector((0, 0.04, hd * 1.25)), hd * 0.95, c.region, c.regions, scale=(1.15, 1.05, 0.95), rot_m=hr)


def _sleeves(c: Ctx, length: float) -> None:
    R = c.p.limb_r
    for s in ("l", "r"):
        add_capsule(c.j[f"{s}_sho"], c.j[f"{s}_elb"], R["arm"], c.region, c.regions)
        if length > 0:
            add_capsule(c.j[f"{s}_elb"], c.j[f"{s}_elb"].lerp(c.j[f"{s}_wri"], length), R["fore"] * 1.08, c.region, c.regions)


def _hem(c: Ctx, up: Vector, r: float, at: float) -> None:
    """Lower edge of a fitted garment, trailing the hips when it lags."""
    drag = hem_lag(c)
    if drag.length > 1e-4:
        add_sphere(c.j["pelvis"] + up * at + drag * 0.8, r * 0.92, c.region, c.regions, scale=(1.0, 0.9, 0.6))


def shirt_stocky(c: Ctx) -> None:
    """Broad chest capsule, round belly, short sleeves."""
    up, tr = _torso_axes(c.j)
    R = c.p.limb_r
    add_capsule(c.j["pelvis"] + up * 0.16, c.j["chest"] - up * 0.02, R["torso"], c.region, c.regions)
    add_sphere(c.j["chest"] - up * 0.06, R["torso"], c.region, c.regions, scale=(1.12, 0.9, 0.85), rot_m=tr)
    add_sphere(c.j["pelvis"] + up * 0.2 + hem_lag(c) * 0.5, R["belly"], c.region, c.regions, scale=(1.0, 1.0, 0.95), rot_m=tr)
    _sleeves(c, 0.0)


def shirt_fitted(c: Ctx) -> None:
    """Slim torso with a closed collar; sleeves come from sleeve-rolled."""
    up, tr = _torso_axes(c.j)
    R = c.p.limb_r
    add_capsule(c.j["pelvis"] + up * 0.12, c.j["chest"] - up * 0.02, R["torso"], c.region, c.regions)
    add_sphere(c.j["chest"] - up * 0.04, R["torso"], c.region, c.regions, scale=(1.1, 0.85, 0.85), rot_m=tr)
    add_capsule(c.j["chest"] + up * 0.02, c.j["neck"], 0.075, c.region, c.regions)
    _hem(c, up, R["torso"], 0.12)


def waistcoat_fitted(c: Ctx) -> None:
    """Fully buttoned waistcoat closed up to the collar, over a fitted shirt."""
    up, tr = _torso_axes(c.j)
    R = c.p.limb_r
    add_capsule(c.j["pelvis"] + up * 0.10, c.j["chest"] - up * 0.05, R["torso"] * 1.06, c.region, c.regions)
    add_sphere(c.j["chest"] - up * 0.07, R["torso"] * 1.04, c.region, c.regions, scale=(1.1, 0.87, 0.85), rot_m=tr)
    _hem(c, up, R["torso"] * 1.06, 0.10)


def sleeve_rolled(c: Ctx) -> None:
    _sleeves(c, c.params.get("length", 0.35))


def waist_apron(c: Ctx) -> None:
    """Apron from the waist to mid-thigh, hinged at the waistband.

    Without secondaryMotion the hem counter-swings against the hip tilt. With lag-1 it
    trails the hips by one drawing, so it settles after the body moves.
    """
    import math
    up, tr = _torso_axes(c.j)
    R = c.p.limb_r
    hips = (c.j["l_hip"] + c.j["r_hip"]) / 2
    width = (c.p.hip_half + R["thigh"]) * 2.0
    drop = c.p.thigh * c.params.get("length", 0.62)
    add_capsule(c.j["l_hip"] + up * 0.09, c.j["r_hip"] + up * 0.09, R["thigh"] * 1.32, c.region, c.regions)
    if c.lag == "lag-1":
        deg = max(-20.0, min(20.0, math.degrees(math.atan2(hem_lag(c).x * 1.6, drop))))
        swing = rot("Y", -deg)
    else:
        swing = rot("Y", -0.6 * (c.j["l_hip"].z - c.j["r_hip"].z) * 100)
    hinge = hips + Vector((0, -R["thigh"] * 1.05, 0.05))
    add_box(hinge + swing @ Vector((0, 0, -drop / 2)), (width, 0.05, drop), c.region, c.regions, rot_m=swing, bevel=0.015)


def trousers(c: Ctx) -> None:
    up, _ = _torso_axes(c.j)
    R = c.p.limb_r
    add_capsule(c.j["l_hip"] + up * 0.04, c.j["r_hip"] + up * 0.04, R["thigh"] * 1.25, c.region, c.regions)
    for s in ("l", "r"):
        add_capsule(c.j[f"{s}_hip"], c.j[f"{s}_kne"], R["thigh"], c.region, c.regions)
        add_capsule(c.j[f"{s}_kne"], c.j[f"{s}_kne"].lerp(c.j[f"{s}_ank"], HEM), R["shin"], c.region, c.regions)


def shoes_flat(c: Ctx) -> None:
    for s in ("l", "r"):
        an, toe = c.j[f"{s}_ank"], c.j[f"{s}_toe"]
        add_capsule(an, toe, 0.052, c.region, c.regions)
        add_sphere(an, 0.066, c.region, c.regions)


def shoes_heeled(c: Ctx) -> None:
    for s in ("l", "r"):
        an, toe = c.j[f"{s}_ank"], c.j[f"{s}_toe"]
        add_capsule(an, toe, 0.042, c.region, c.regions)
        add_box(an + Vector((0, 0.03, -0.035)), (0.035, 0.035, 0.07), c.region, c.regions)


def _macron(p, j: dict, regions: dict) -> None:
    R = p.limb_r
    up = (j["chest"] - j["pelvis"]).normalized()
    torso_rot = up.to_track_quat("Z", "Y").to_matrix()
    add_capsule(j["pelvis"], j["chest"], R["torso"], "shell", regions)
    add_sphere(j["chest"] + torso_rot @ Vector((0, -R["torso"] * 0.95, -0.12)), 0.03, "chest_light", regions)
    add_capsule(j["chest"], j["neck"], 0.05, "joint", regions)
    hr: Matrix = j["_head_rot"]
    # Big rounded head shell with a dark screen on the front face.
    add_box(j["head"], (0.62, 0.52, 0.50), "shell", regions, rot_m=hr, bevel=0.14)
    add_box(j["head"] + hr @ Vector((0, -0.215, -0.01)), (0.48, 0.12, 0.34), "screen", regions, rot_m=hr, bevel=0.07)
    for s in (1, -1):  # ear pods
        add_cyl(j["head"] + hr @ Vector((s * 0.31, 0, 0)), 0.08, 0.05, "joint", regions, rot_m=hr @ rot("Y", 90))
    top = j["head"] + hr @ Vector((0, 0, 0.25))
    add_capsule(top, top + hr @ Vector((0, 0, 0.12)), 0.018, "joint", regions)
    add_sphere(top + hr @ Vector((0, 0, 0.16)), 0.05, "antenna", regions)
    for s in ("l", "r"):
        add_sphere(j[f"{s}_sho"], 0.065, "joint", regions)
        add_capsule(j[f"{s}_sho"], j[f"{s}_elb"], R["arm"], "limb", regions)
        add_capsule(j[f"{s}_elb"], j[f"{s}_wri"], R["fore"], "limb", regions)
        if s == "r":  # canon: subtle modular cuff on the anatomical right arm only
            mid = j["r_elb"].lerp(j["r_wri"], 0.45)
            add_capsule(mid - (j["r_wri"] - j["r_elb"]).normalized() * 0.025,
                        mid + (j["r_wri"] - j["r_elb"]).normalized() * 0.025, R["fore"] * 1.12, "cuff", regions)
        add_sphere(j[f"{s}_wri"] + (j[f"{s}_wri"] - j[f"{s}_elb"]).normalized() * 0.04, 0.06, "joint", regions)
        add_sphere(j[f"{s}_hip"], 0.06, "joint", regions)
        add_capsule(j[f"{s}_hip"], j[f"{s}_kne"], R["thigh"], "limb", regions)
        add_capsule(j[f"{s}_kne"], j[f"{s}_ank"], R["shin"], "limb", regions)
        add_capsule(j[f"{s}_ank"], j[f"{s}_toe"], 0.055, "joint", regions)


def macron_body(c: Ctx) -> None:
    """Toy robot: a single shape holding all of his regions. Never humanoid base."""
    _macron(c.p, c.j, c.regions)


SHAPES = {
    "brimmed-hat": brimmed_hat, "hat-band": hat_band, "short-hair-moustache": short_hair_moustache,
    "puff": puff, "shirt-stocky": shirt_stocky, "shirt-fitted": shirt_fitted,
    "waistcoat-fitted": waistcoat_fitted, "sleeve-rolled": sleeve_rolled, "waist-apron": waist_apron,
    "trousers": trousers, "shoes-flat": shoes_flat, "shoes-heeled": shoes_heeled, "macron-body": macron_body,
}


def prop_shaker(c: Ctx, at: Vector, axis: Vector) -> None:
    m = axis.to_track_quat("Z", "Y").to_matrix()
    add_cyl(at, 0.05, 0.16, "prop", c.regions, rot_m=m)
    add_cyl(at + axis * 0.1, 0.033, 0.05, "prop", c.regions, rot_m=m)


def prop_bottle(c: Ctx, at: Vector, axis: Vector) -> None:
    m = axis.to_track_quat("Z", "Y").to_matrix()
    add_cyl(at, 0.05, 0.2, "prop", c.regions, rot_m=m)
    add_cyl(at + axis * 0.15, 0.02, 0.1, "prop", c.regions, rot_m=m)


def prop_glass(c: Ctx, at: Vector, axis: Vector) -> None:
    add_cyl(at, 0.045, 0.1, "prop", c.regions, rot_m=axis.to_track_quat("Z", "Y").to_matrix())


PROPS = {"shaker": prop_shaker, "bottle": prop_bottle, "glass": prop_glass}


def build_character(definition: dict, p, j: dict, regions: dict, clip: str, prev: dict | None = None) -> None:
    """All geometry for one pose of one character. prev: joints of the previous drawing."""
    if p.human:
        base_body(p, j, regions)
    for g in definition["garments"]:
        SHAPES[g["shape"]](Ctx(p, j, regions, g["region"], g.get("params", {}), prev, g.get("secondaryMotion")))
    for pr in definition.get("props", []):
        if pr.get("clips") and clip not in pr["clips"]:
            continue
        s = "l" if pr["hand"] == "left" else "r"
        fore = (j[f"{s}_wri"] - j[f"{s}_elb"]).normalized()
        at = j[f"{s}_wri"] + fore * 0.08
        axis = (fore.cross(Vector((0, 1, 0)))).normalized()
        if axis.length < 1e-3 or axis.z < 0:
            axis = -axis if axis.length >= 1e-3 else Vector((0, 0, 1))
        PROPS[pr["kind"]](Ctx(p, j, regions, "prop", {}), at, axis)
