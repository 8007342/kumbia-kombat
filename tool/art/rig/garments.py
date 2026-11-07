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
    cue: tuple | None = None   # (butt, tip) of a held cue in this pose, from cue_line


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
    width, height = c.params.get("moustache", (1.7, 0.45))
    add_sphere(c.j["head"] + hr @ Vector((0, -hd * 0.92, -hd * (0.3 - c.params.get("moustacheLift", 0.0)))), 0.035, c.region, c.regions, scale=(width, 0.6, height), rot_m=hr)


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


def guayabera_stripes(c: Ctx) -> None:
    """Two vertical embroidered stripes on the front of a stocky shirt, flanking the placket.

    They sit on the shirt's surface in the proxy, so every frame starts from the same layout.
    """
    up, _ = _torso_axes(c.j)
    R = c.p.limb_r
    side = (c.j["l_sho"] - c.j["r_sho"]).normalized()
    front = side.cross(up).normalized()
    if front.y > 0:
        front = -front
    offset = c.params.get("offset", 0.4)
    r = c.params.get("radius", 0.016)
    depth = (1 - offset ** 2) ** 0.5
    for sign in (-1, 1):
        top = c.j["chest"] + up * 0.02 + side * sign * offset * R["torso"] + front * depth * R["torso"] * 1.02
        mid = c.j["pelvis"] + up * 0.3 + side * sign * offset * R["torso"] + front * depth * R["belly"] * 1.02
        low = c.j["pelvis"] + up * 0.14 + side * sign * offset * R["belly"] + front * depth * R["belly"] * 0.92
        add_capsule(top, mid, r, c.region, c.regions)
        add_capsule(mid, low, r, c.region, c.regions)


def gold_chains(c: Ctx) -> None:
    """Rope chains hanging in nested Vs from the neck over the chest, down to the belly.

    Only a mask: Qwen draws the chains from the sheet. The mask gives gold a region and a place, and
    the depth test hides it from behind. Params: depths, fractions of the way from chest to pelvis.
    """
    up, _ = _torso_axes(c.j)
    R = c.p.limb_r
    side = (c.j["l_sho"] - c.j["r_sho"]).normalized()
    front = side.cross(up).normalized()  # his own front, which faces away from the camera in a rear view
    r = c.params.get("radius", 0.012)
    top = c.j["chest"] + up * 0.1 + front * R["torso"] * 0.9
    for depth in c.params.get("depths", (0.25, 0.55, 0.85)):
        low = c.j["chest"].lerp(c.j["pelvis"], depth) + front * R["torso"] * 1.08
        for sign in (-1, 1):
            add_capsule(top + side * sign * R["torso"] * 0.5, low, r, c.region, c.regions)


def cue_line(definition: dict, p, j: dict, pose_id: str) -> tuple[Vector, Vector] | None:
    """Where the billiard cue lies in this pose: (butt, tip), from drawing.cue, or None when the pose has no cue.

    drawing.cue = {length, default, clips: {clip: spec}, poses: {pose: spec}}, later wins. A spec says:
      hand    "r" or "l", the wrist that holds it
      through a joint the cue passes through in place of the wrist, for a cue propped on a shoulder
      mode    "planted": the butt on the floor at `butt` [x, y], the line through the wrist (a dance pole).
              "held": through the wrist along `dir` [x, y, z], with `grip` the fraction of the length below the hand.
    World axes: x toward the picture's right, y away from the viewer, z up. The tip is the far end from the butt.
    """
    table = definition.get("drawing", {}).get("cue")
    if not table:
        return None
    clip = pose_id.split(".", 1)[0]
    spec = {**table.get("default", {}), **table.get("clips", {}).get(clip, {}), **table.get("poses", {}).get(pose_id, {})}
    if not spec or spec.get("mode") == "none":
        return None
    wrist = j[spec.get("through", f"{spec.get('hand', 'r')}_wri")]
    length = spec.get("length", table.get("length", 1.5))
    if spec.get("mode") == "planted":
        x, y = spec.get("butt", (0, 0))
        butt = Vector((x, y, 0.0))
        return butt, butt + (wrist - butt).normalized() * length
    axis = Vector(spec["dir"]).normalized()
    butt = wrist - axis * length * spec.get("grip", 0.3)
    return butt, butt + axis * length


def cue_shaft(c: Ctx) -> None:
    """Masks only, like gold-chains: Qwen draws the cue from the sheet. Slim, pale, the upper part of the cue."""
    if c.cue:
        butt, tip = c.cue
        add_capsule(butt.lerp(tip, c.params.get("from", 0.42)), tip, c.params.get("radius", 0.012), c.region, c.regions)


def cue_butt(c: Ctx) -> None:
    if c.cue:
        butt, tip = c.cue
        add_capsule(butt, butt.lerp(tip, c.params.get("to", 0.42)), c.params.get("radius", 0.02), c.region, c.regions)


def waistcoat_buttons(c: Ctx) -> None:
    """Three brass buttons on the chest's front: only so brass has a region for its ramp."""
    up, _ = _torso_axes(c.j)
    side = (c.j["l_sho"] - c.j["r_sho"]).normalized()
    front = side.cross(up).normalized()
    for t in (0.35, 0.5, 0.65):
        add_sphere(c.j["chest"].lerp(c.j["pelvis"], t) + front * c.p.limb_r["torso"] * 1.05, 0.016, c.region, c.regions)


def palette_only(c: Ctx) -> None:
    """No geometry: a colour the sheet draws and the rig has no shape for, such as a cube of chalk in a hand."""


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


# ---------------------------------------------------------------- instruments
# Masks only, like gold-chains: Qwen draws the instrument from the sheet. The mask gives each instrument a region
# for its ramp, and a place in the rig's silhouette, so registration measures the figure with its instrument and
# the scorer doesn't read it as an extra arm. What stands on the floor is fixed in the world, turned by params.yaw
# (poses.BAND_YAW), so it can't wander with the body. What is held follows the wrists.

def _world(c: Ctx, side: float, forward: float, z: float) -> Vector:
    """A point in the stance's frame: side toward the player's left, forward toward where they face."""
    return rot("Z", c.params.get("yaw", 30.0)) @ Vector((side, -forward, z))


def upright_bass(c: Ctx) -> None:
    """Rocks on its spike: the neck runs from the spike through the hand that holds it."""
    spike = _world(c, *c.params.get("spike", (0.24, 0.26)), 0.0)
    axis = (c.j["l_wri"] - spike).normalized()
    m = axis.to_track_quat("Z", "Y").to_matrix()
    body = spike + axis * 0.55
    add_sphere(body, 0.27, c.region, c.regions, scale=(1.0, 0.6, 1.6), rot_m=m)
    add_capsule(spike, body, 0.02, c.region, c.regions)
    add_capsule(body, spike + axis * 1.68, 0.03, c.region, c.regions)
    add_sphere(spike + axis * 1.7, 0.05, c.region, c.regions)


def trumpet_horn(c: Ctx) -> None:
    """From the lips out through the valve hand, flaring at the bell."""
    head, hand = c.j["head"], c.j["l_wri"]
    axis = (hand - head).normalized()
    add_capsule(head + axis * 0.12, head + axis * 0.58, 0.024, c.region, c.regions)
    add_sphere(head + axis * 0.62, 0.09, c.region, c.regions, scale=(1.0, 1.0, 0.45), rot_m=axis.to_track_quat("Z", "Y").to_matrix())


def _conga_spots(c: Ctx):
    return [_world(c, s * c.params.get("apart", 0.3), c.params.get("forward", 0.24), 0.0) for s in (-1, 1)]


def conga_shells(c: Ctx) -> None:
    h = c.params.get("height", 0.78)
    for spot in _conga_spots(c):
        add_cyl(spot + Vector((0, 0, h / 2)), c.params.get("radius", 0.16), h, c.region, c.regions)


def conga_bands(c: Ctx) -> None:
    h = c.params.get("height", 0.78)
    for spot in _conga_spots(c):
        for z in (h - 0.05, 0.04):
            add_cyl(spot + Vector((0, 0, z)), c.params.get("radius", 0.16) + 0.012, 0.03, c.region, c.regions)


def marimba_bars(c: Ctx) -> None:
    """The bars and frame, fixed in the world, and a mallet along each forearm."""
    f, z = c.params.get("forward", 0.3), c.params.get("height", 0.9)
    half = c.params.get("half", 0.75)
    add_box(_world(c, 0, f, z), (half * 2, 0.26, 0.05), c.region, c.regions, rot_m=rot("Z", c.params.get("yaw", 30.0)))
    for s in (-1, 1):
        add_capsule(_world(c, s * half, f, 0.0), _world(c, s * half, f, z), 0.025, c.region, c.regions)
    for side in "lr":
        fore = (c.j[f"{side}_wri"] - c.j[f"{side}_elb"]).normalized()
        tip = c.j[f"{side}_wri"] + fore * 0.3
        add_capsule(c.j[f"{side}_wri"], tip, 0.012, c.region, c.regions)
        add_sphere(tip, 0.035, c.region, c.regions)


def marimba_tubes(c: Ctx) -> None:
    f, z = c.params.get("forward", 0.3), c.params.get("height", 0.9)
    half = c.params.get("half", 0.75) - 0.06
    n = 9
    for i in range(n):
        t = i / (n - 1)
        top, low = z - 0.03, z - 0.52 + 0.3 * t
        add_capsule(_world(c, -half + 2 * half * t, f, top), _world(c, -half + 2 * half * t, f, low), 0.018, c.region, c.regions)


def violin_body(c: Ctx) -> None:
    """Held under the chin on the player's left shoulder, its neck running out to the left hand. Follows the body."""
    chin = c.j["head"].lerp(c.j["l_sho"], 0.6)
    axis = (c.j["l_wri"] - chin).normalized()
    m = axis.to_track_quat("Z", "Y").to_matrix()
    add_sphere(chin + axis * 0.1, 0.11, c.region, c.regions, scale=(1.0, 0.45, 1.75), rot_m=m)
    add_capsule(chin + axis * 0.25, c.j["l_wri"], 0.018, c.region, c.regions)


def violin_bow(c: Ctx) -> None:
    """A thin straight bow from the right hand across the strings, past the violin's body."""
    chin = c.j["head"].lerp(c.j["l_sho"], 0.6)
    across = (chin - c.j["r_wri"])
    tip = c.j["r_wri"] + across.normalized() * c.params.get("length", 0.7)
    add_capsule(c.j["r_wri"], tip, 0.01, c.region, c.regions)


def bongo_pair(c: Ctx) -> None:
    """Two small joined drums on a thin stand at waist height, fixed in the world like the congas."""
    f, z, r = c.params.get("forward", 0.28), c.params.get("height", 0.95), c.params.get("radius", 0.11)
    for s, k in ((-1, 1.0), (1, 0.82)):
        add_cyl(_world(c, s * 0.12, f, z - 0.09), r * k, 0.18, c.region, c.regions)
    add_capsule(_world(c, 0, f, 0.0), _world(c, 0, f, z - 0.18), 0.015, c.region, c.regions)


def jacket_lapels(c: Ctx) -> None:
    """The violet V of a dinner jacket, on the torso's front, so its ramp has a region and a place."""
    up, _ = _torso_axes(c.j)
    R = c.p.limb_r
    side = (c.j["l_sho"] - c.j["r_sho"]).normalized()
    front = side.cross(up).normalized()
    if front.y > 0:
        front = -front
    top = c.j["chest"] + up * 0.06 + front * R["torso"] * 0.95
    low = c.j["chest"].lerp(c.j["pelvis"], 0.55) + front * R["torso"] * 1.02
    for s in (-1, 1):
        add_capsule(top + side * s * R["torso"] * 0.55, low, 0.018, c.region, c.regions)


SHAPES = {
    "brimmed-hat": brimmed_hat, "hat-band": hat_band, "short-hair-moustache": short_hair_moustache,
    "puff": puff, "guayabera-stripes": guayabera_stripes, "shirt-stocky": shirt_stocky, "shirt-fitted": shirt_fitted,
    "waistcoat-fitted": waistcoat_fitted, "sleeve-rolled": sleeve_rolled, "waist-apron": waist_apron,
    "trousers": trousers, "shoes-flat": shoes_flat, "shoes-heeled": shoes_heeled, "gold-chains": gold_chains,
    "cue-shaft": cue_shaft, "cue-butt": cue_butt, "waistcoat-buttons": waistcoat_buttons, "palette-only": palette_only,
    "upright-bass": upright_bass, "trumpet-horn": trumpet_horn, "conga-shells": conga_shells, "conga-bands": conga_bands,
    "marimba-bars": marimba_bars, "marimba-tubes": marimba_tubes, "violin-body": violin_body, "violin-bow": violin_bow, "bongo-pair": bongo_pair, "jacket-lapels": jacket_lapels,
    "macron-body": macron_body,
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


def build_character(definition: dict, p, j: dict, regions: dict, clip: str, prev: dict | None = None, pose_id: str = "") -> None:
    """All geometry for one pose of one character. prev: joints of the previous drawing."""
    cue = cue_line(definition, p, j, pose_id or clip)
    if p.human:
        base_body(p, j, regions)
    for g in definition["garments"]:
        SHAPES[g["shape"]](Ctx(p, j, regions, g["region"], g.get("params", {}), prev, g.get("secondaryMotion"), cue))
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
