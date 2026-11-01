"""Blender stand-in rig: renders control images for the generative pipeline.

Run with a Python that has `bpy` (Blender as a module), e.g.:

    ~/.cache/kumbia-bpy/bin/python tool/art/rig/standin.py \
        --character gatekeeper --out art_runs/inputs/gatekeeper-v3

For every pose it writes, at the family's generation canvas size:

    <pose>.pose.png     OpenPose COCO-18 skeleton on black (humans only)
    <pose>.depth.png    near = bright, far = dark, black background
    <pose>.regions.png  flat region colours, no antialiasing, transparent bg
    <pose>.lineart.png  white region/silhouette edges on black

plus `rig.json` (per-pose 2D joints, ground baseline, support-foot pivot) and
`contact.png` / `<clip>.gif` previews for human review.

The rig is a hand-keyed stand-in, not final art: proportions only need to be
close enough that ControlNet produces the intended silhouette, support foot and
limb identity. Poses are absolute segment angles in degrees (see `Pose`).
The support foot is planted on the ground line after FK, so the baseline is
identical in every frame. Cameras are orthographic and fixed per family, so
scale never drifts. See plan/asset-pipeline-requirements.md (owner decisions).
"""

from __future__ import annotations

import argparse
import warnings
import json
import math
import sys
from dataclasses import dataclass, field
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from poses import CLIPS_BY_CHARACTER, Pose  # noqa: E402

# ---------------------------------------------------------------- characters


@dataclass(frozen=True)
class Proportions:
    """Segment lengths in metres; the character stands facing -Y."""

    hip_height: float
    torso: float
    neck: float
    head_r: float
    shoulder_half: float
    hip_half: float
    upper_arm: float
    forearm: float
    thigh: float
    shin: float
    foot: float
    ankle_h: float
    limb_r: dict = field(default_factory=dict)
    human: bool = True


GATEKEEPER = Proportions(
    hip_height=0.93, torso=0.50, neck=0.08, head_r=0.115,
    shoulder_half=0.22, hip_half=0.11, upper_arm=0.30, forearm=0.27,
    thigh=0.44, shin=0.42, foot=0.24, ankle_h=0.07,
    limb_r={"torso": 0.20, "belly": 0.21, "arm": 0.06, "fore": 0.05,
            "thigh": 0.085, "shin": 0.065},
)

# Mācron: toy robot, ~.35 adult stature. The rig is authored at adult scale
# and the camera frames it identically, so frames stay comparable; final
# stature comes from the game's floor projection, never from these numbers.
MACRON = Proportions(
    hip_height=0.42, torso=0.30, neck=0.05, head_r=0.30,
    shoulder_half=0.17, hip_half=0.08, upper_arm=0.17, forearm=0.15,
    thigh=0.20, shin=0.18, foot=0.12, ankle_h=0.05,
    limb_r={"torso": 0.15, "belly": 0.15, "arm": 0.055, "fore": 0.055,
            "thigh": 0.065, "shin": 0.065},
    human=False,
)

CHARACTERS = {"gatekeeper": GATEKEEPER, "macron": MACRON}

# Region colours. Gatekeeper matches tool/art/families/gatekeeper-v3.json.
REGIONS = {
    "gatekeeper": {"skin": "#FF0000", "hair": "#00FF00", "cloth": "#0000FF",
                   "hat": "#FFFF00", "shoes": "#00FFFF", "accessory": "#FF00FF",
                   "trousers": "#FF8000"},
    "macron": {"shell": "#FFFFFF", "screen": "#0000FF", "joint": "#00FFFF",
               "antenna": "#FFFF00", "cuff": "#FF00FF", "limb": "#FF8000",
               "chest_light": "#00FF00"},
}

CANVAS = (768, 960)          # generation canvas (family frame.generationCanvas)
ORTHO = {"gatekeeper": 2.5, "macron": 1.8}   # metres of canvas height
CENTER_Z = {"gatekeeper": 1.10, "macron": 0.74}
VIEW_YAW = {"front": 0, "front_3q": 35, "profile": 90, "rear_3q": 145,
            "rear": 180, "rear_3q_opp": -145, "profile_opp": -90,
            "front_3q_opp": -35}

# ---------------------------------------------------------------- FK


def rot(axis: str, deg: float) -> Matrix:
    return Matrix.Rotation(math.radians(deg), 3, axis)


def seg_dir(abd: float, flex: float, side: int, up: bool = False) -> Vector:
    """Direction of a limb segment from absolute angles.

    (abd, flex) are read as a 2D swing away from hanging straight down:
    abd is the outward component, flex the forward (toward the viewer, -Y)
    component, negative abd crosses toward the midline. The swing magnitude is
    hypot(abd, flex) and its heading atan2(flex, abd), so (90, 0) is
    horizontal outward, (180, 0) straight up, (0, 90) straight forward and
    (-90, 60) forward and across the chest. Unlike Euler angles this never
    locks: a forward-pointing arm can still cross inward for a clap.
    """
    swing = math.radians(math.hypot(abd, flex))
    heading = math.atan2(flex, abd)
    h = Vector((side * math.cos(heading), -math.sin(heading), 0))
    v = h * math.sin(swing) + Vector((0, 0, -math.cos(swing)))
    return -v if up else v


def solve(p: Proportions, pose: Pose) -> dict[str, Vector]:
    """Forward kinematics; returns world joint positions before planting."""
    j: dict[str, Vector] = {}
    body = rot("Z", pose.yaw)
    torso_r = body @ rot("Z", pose.twist) @ rot("Y", pose.side_bend) @ rot("X", -pose.lean)
    pelvis = Vector((pose.pelvis_x, pose.pelvis_y, p.hip_height))
    j["pelvis"] = body @ pelvis
    chest = j["pelvis"] + torso_r @ Vector((0, 0, p.torso))
    j["chest"] = chest
    j["neck"] = chest + torso_r @ Vector((0, 0, p.neck))
    head_r = torso_r @ rot("Z", pose.head_turn) @ rot("Y", pose.head_side) @ rot("X", -pose.head_nod)
    j["head"] = j["neck"] + head_r @ Vector((0, 0, p.head_r * (1.0 if p.human else 0.95)))
    j["_head_rot"] = head_r  # type: ignore[assignment]
    for side, s in (("l", 1), ("r", -1)):
        sh = chest + torso_r @ Vector((s * p.shoulder_half, 0, -0.03))
        ua = getattr(pose, f"{side}_arm")
        fa = getattr(pose, f"{side}_fore")
        el = sh + torso_r @ seg_dir(*ua, s) * p.upper_arm
        wr = el + torso_r @ seg_dir(*fa, s) * p.forearm
        j[f"{side}_sho"], j[f"{side}_elb"], j[f"{side}_wri"] = sh, el, wr
        hip = j["pelvis"] + body @ rot("Z", pose.twist * 0.3) @ Vector((s * p.hip_half, 0, 0))
        th = getattr(pose, f"{side}_thigh")
        sn = getattr(pose, f"{side}_shin")
        kn = hip + body @ seg_dir(*th, s) * p.thigh
        an = kn + body @ seg_dir(*sn, s) * p.shin
        toe = an + body @ rot("Z", s * pose.toe_out) @ Vector((0, -p.foot * 0.75, -p.ankle_h * 0.6))
        j[f"{side}_hip"], j[f"{side}_kne"], j[f"{side}_ank"], j[f"{side}_toe"] = hip, kn, an, toe
    return j


def plant(p: Proportions, j: dict, support: str) -> dict:
    """Translate the body so the support foot's ankle sits at ankle height."""
    if support in ("left", "l"):
        z = j["l_ank"].z
    elif support in ("right", "r"):
        z = j["r_ank"].z
    else:
        z = min(j["l_ank"].z, j["r_ank"].z)
    dz = p.ankle_h - z
    out = {}
    for k, v in j.items():
        out[k] = v + Vector((0, 0, dz)) if isinstance(v, Vector) else v
    return out


# ---------------------------------------------------------------- scene


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(h: str) -> tuple[float, float, float]:
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))  # type: ignore[return-value]


def reset_scene(character: str, camera: str) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    sc.cycles.use_denoising = False
    sc.cycles.max_bounces = 0
    sc.render.filter_size = 0.01          # one centre sample per pixel: no AA
    sc.render.resolution_x, sc.render.resolution_y = CANVAS
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.dither_intensity = 0.0     # exact region colours
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0
    sc.view_settings.gamma = 1
    world = bpy.data.worlds.new("w")
    world.color = (0, 0, 0)
    sc.world = world
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ORTHO[character]
    cam = bpy.data.objects.new("cam", cam_data)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cz = CENTER_Z[character]
    if camera == "side-on":
        # Side-on levels look along -X at the character's left profile.
        cam.location = (10, 0, cz)
        cam.rotation_euler = (math.pi / 2, 0, math.pi / 2)
    else:
        cam.location = (0, -10, cz)
        cam.rotation_euler = (math.pi / 2, 0, 0)


_MATS: dict[str, bpy.types.Material] = {}


def emission_mat(name: str, rgb: tuple[float, float, float] | None) -> bpy.types.Material:
    key = name
    if key in _MATS and _MATS[key].name in bpy.data.materials:
        return _MATS[key]
    m = bpy.data.materials.new(name)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", DeprecationWarning)
        m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 1.0
    if rgb is None:  # depth: read the per-vertex attribute
        attr = nt.nodes.new("ShaderNodeAttribute")
        attr.attribute_name = "depth"
        nt.links.new(attr.outputs["Color"], em.inputs["Color"])
    else:
        em.inputs["Color"].default_value = (*[srgb_to_linear(c) for c in rgb], 1)
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    _MATS[key] = m
    return m


def add_capsule(a: Vector, b: Vector, r: float, region: str, regions: dict) -> None:
    d = b - a
    length = d.length
    mid = (a + b) / 2
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=r, depth=max(length, 1e-4), location=mid)
    cyl = bpy.context.object
    cyl.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    _assign(cyl, region, regions)
    for end in (a, b):
        add_sphere(end, r, region, regions)


def add_sphere(c: Vector, r: float, region: str, regions: dict, scale=(1, 1, 1), rot_m: Matrix | None = None) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=r, location=c)
    o = bpy.context.object
    o.scale = scale
    if rot_m is not None:
        o.rotation_euler = rot_m.to_euler()
    _assign(o, region, regions)
    return o


def add_box(c: Vector, size: tuple, region: str, regions: dict, rot_m: Matrix | None = None, bevel: float = 0.0) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1, location=c)
    o = bpy.context.object
    o.scale = size
    if rot_m is not None:
        o.rotation_euler = rot_m.to_euler()
    if bevel:
        mod = o.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 6
        mod.affect = "EDGES"
        bpy.ops.object.transform_apply(scale=True)
        bpy.ops.object.modifier_apply(modifier="bevel")
    _assign(o, region, regions)
    return o


def add_cyl(c: Vector, r: float, depth: float, region: str, regions: dict, rot_m: Matrix | None = None) -> None:
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=r, depth=depth, location=c)
    o = bpy.context.object
    if rot_m is not None:
        o.rotation_euler = rot_m.to_euler()
    _assign(o, region, regions)


def _assign(o: bpy.types.Object, region: str, regions: dict) -> None:
    o.data.materials.append(emission_mat("r_" + region, hex_rgb(regions[region])))


def build_gatekeeper(p: Proportions, j: dict, regions: dict) -> None:
    R = p.limb_r
    up = (j["chest"] - j["pelvis"]).normalized()
    torso_rot = up.to_track_quat("Z", "Y").to_matrix()
    # Stocky torso: belly sphere + chest capsule (shirt = cloth region).
    add_capsule(j["pelvis"] + up * 0.12, j["chest"], R["torso"], "cloth", regions)
    add_sphere(j["pelvis"] + up * 0.18, R["belly"], "cloth", regions, scale=(1.05, 0.95, 1.0), rot_m=torso_rot)
    add_capsule(j["pelvis"], j["pelvis"] + up * 0.1, R["torso"] * 0.95, "trousers", regions)
    add_capsule(j["chest"], j["neck"], 0.055, "skin", regions)
    hr: Matrix = j["_head_rot"]
    add_sphere(j["head"], p.head_r, "skin", regions, scale=(0.92, 0.95, 1.05), rot_m=hr)
    # Hair at the back of the head, hat brim and crown on top.
    add_sphere(j["head"] + hr @ Vector((0, 0.05, 0.0)), p.head_r * 0.9, "hair", regions, scale=(0.95, 0.75, 0.85), rot_m=hr)
    add_sphere(j["head"] + hr @ Vector((0, -0.105, -0.035)), 0.03, "hair", regions, scale=(1.6, 0.6, 0.45), rot_m=hr)  # moustache
    add_cyl(j["head"] + hr @ Vector((0, 0, p.head_r * 0.62)), 0.20, 0.018, "hat", regions, rot_m=hr)
    add_cyl(j["head"] + hr @ Vector((0, 0, p.head_r * 1.05)), 0.115, 0.11, "hat", regions, rot_m=hr)
    for s in ("l", "r"):
        add_capsule(j[f"{s}_sho"], j[f"{s}_elb"], R["arm"], "cloth", regions)       # short sleeve
        add_capsule(j[f"{s}_elb"], j[f"{s}_wri"], R["fore"], "skin", regions)
        add_sphere(j[f"{s}_wri"] + (j[f"{s}_wri"] - j[f"{s}_elb"]).normalized() * 0.06, 0.055, "skin", regions)
        add_capsule(j[f"{s}_hip"], j[f"{s}_kne"], R["thigh"], "trousers", regions)
        add_capsule(j[f"{s}_kne"], j[f"{s}_ank"], R["shin"], "trousers", regions)
        add_capsule(j[f"{s}_ank"], j[f"{s}_toe"], 0.05, "shoes", regions)


def build_macron(p: Proportions, j: dict, regions: dict) -> None:
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


BUILDERS = {"gatekeeper": build_gatekeeper, "macron": build_macron}

# ---------------------------------------------------------------- render


def set_depth_attributes(near: float, far: float, cam_loc: Vector, cam_fwd: Vector) -> None:
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        me = o.data
        attr = me.color_attributes.get("depth") or me.color_attributes.new("depth", "FLOAT_COLOR", "POINT")
        mw = o.matrix_world
        for i, v in enumerate(me.vertices):
            d = (mw @ v.co - cam_loc).dot(cam_fwd)
            g = 1.0 - min(1.0, max(0.0, (d - near) / (far - near)))
            g = srgb_to_linear(g)
            attr.data[i].color = (g, g, g, 1)


def render_to(path: Path, override: bpy.types.Material | None) -> None:
    sc = bpy.context.scene
    sc.view_layers[0].material_override = override
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def project(points: dict) -> dict[str, tuple[float, float, float]]:
    from bpy_extras.object_utils import world_to_camera_view
    sc = bpy.context.scene
    W, H = CANVAS
    out = {}
    for k, v in points.items():
        if not isinstance(v, Vector):
            continue
        c = world_to_camera_view(sc, sc.camera, v)
        out[k] = (c.x * W, (1 - c.y) * H, c.z)
    return out


# OpenPose COCO-18 (controlnet_aux convention).
LIMBS = [(1, 2), (1, 5), (2, 3), (3, 4), (5, 6), (6, 7), (1, 8), (8, 9), (9, 10),
         (1, 11), (11, 12), (12, 13), (1, 0), (0, 14), (14, 16), (0, 15), (15, 17)]
COLORS = [(255, 0, 0), (255, 85, 0), (255, 170, 0), (255, 255, 0), (170, 255, 0),
          (85, 255, 0), (0, 255, 0), (0, 255, 85), (0, 255, 170), (0, 255, 255),
          (0, 170, 255), (0, 85, 255), (0, 0, 255), (85, 0, 255), (170, 0, 255),
          (255, 0, 255), (255, 0, 170), (255, 0, 85)]


def openpose_points(p: Proportions, j: dict) -> list[Vector | None]:
    hr: Matrix = j["_head_rot"]
    h = j["head"]
    r = p.head_r
    face = {
        "nose": h + hr @ Vector((0, -r, -0.02)),
        "r_eye": h + hr @ Vector((-0.04, -r * 0.9, 0.02)),
        "l_eye": h + hr @ Vector((0.04, -r * 0.9, 0.02)),
        "r_ear": h + hr @ Vector((-r * 0.95, 0, 0)),
        "l_ear": h + hr @ Vector((r * 0.95, 0, 0)),
    }
    neck = (j["l_sho"] + j["r_sho"]) / 2
    return [face["nose"], neck, j["r_sho"], j["r_elb"], j["r_wri"], j["l_sho"], j["l_elb"],
            j["l_wri"], j["r_hip"], j["r_kne"], j["r_ank"], j["l_hip"], j["l_kne"], j["l_ank"],
            face["r_eye"], face["l_eye"], face["r_ear"], face["l_ear"]], face


def draw_openpose(path: Path, pts2d: list, visible: list[bool]) -> None:
    W, H = CANVAS
    stick = max(4, round(W / 128))
    base = Image.new("RGB", CANVAS, (0, 0, 0))
    for i, (a, b) in enumerate(LIMBS):
        if not (visible[a] and visible[b]):
            continue
        layer = Image.new("RGB", CANVAS, (0, 0, 0))
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


def finish_depth(path: Path) -> None:
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, (0, 0, 0, 255))
    Image.alpha_composite(bg, im).convert("L").save(path)


def lineart_from_regions(regions_png: Path, out: Path) -> None:
    a = np.asarray(Image.open(regions_png).convert("RGBA")).astype(np.int32)
    key = (a[..., 0] << 24) | (a[..., 1] << 16) | (a[..., 2] << 8) | a[..., 3]
    edge = np.zeros(key.shape, bool)
    edge[:, 1:] |= key[:, 1:] != key[:, :-1]
    edge[1:, :] |= key[1:, :] != key[:-1, :]
    img = Image.fromarray((edge * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
    img.save(out)


def check_regions(path: Path, regions: dict) -> list[str]:
    a = np.asarray(Image.open(path).convert("RGBA"))
    allowed = {tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h in regions.values()}
    opaque = a[..., 3] == 255
    clear = a[..., 3] == 0
    problems = []
    if not np.all(opaque | clear):
        problems.append("semi-transparent pixels")
    cols = {tuple(c) for c in a[opaque][:, :3].reshape(-1, 3)}
    extra = cols - allowed
    if extra:
        problems.append(f"undeclared colours {sorted(extra)[:4]}")
    return problems


# ---------------------------------------------------------------- main


def render_pose(character: str, camera: str, pose_id: str, pose: Pose, support: str, out: Path) -> dict:
    p = CHARACTERS[character]
    regions = REGIONS[character]
    reset_scene(character, camera)
    _MATS.clear()
    j = plant(p, solve(p, pose), support)
    BUILDERS[character](p, j, regions)
    sc = bpy.context.scene
    cam = sc.camera
    cam_fwd = (cam.matrix_world.to_3x3() @ Vector((0, 0, -1))).normalized()
    dist = (Vector((0, 0, CENTER_Z[character])) - cam.location).dot(cam_fwd)
    span = ORTHO[character] * 0.35
    set_depth_attributes(dist - span, dist + span, cam.location, cam_fwd)
    render_to(out / f"{pose_id}.regions.png", None)
    render_to(out / f"{pose_id}.depth.png", emission_mat("depth", None))
    finish_depth(out / f"{pose_id}.depth.png")
    lineart_from_regions(out / f"{pose_id}.regions.png", out / f"{pose_id}.lineart.png")
    problems = check_regions(out / f"{pose_id}.regions.png", regions)
    joints2d = project(j)
    ground_y = round(project({"g": Vector((0, 0, 0))})["g"][1], 2)
    rec = {"id": pose_id, "support": support, "groundY": ground_y,
           "joints": {k: [round(v[0], 1), round(v[1], 1)] for k, v in joints2d.items()},
           "problems": problems}
    sup = {"left": "l_ank", "l": "l_ank", "right": "r_ank", "r": "r_ank"}.get(support)
    rec["pivotX"] = round(joints2d[sup][0] if sup else (joints2d["l_ank"][0] + joints2d["r_ank"][0]) / 2, 1)
    if p.human:
        pts, face = openpose_points(p, j)
        pts2d = [project({"x": v})["x"] for v in pts]
        head_depth = project({"h": j["head"]})["h"][2]
        visible = [True] * 18
        # Hide face points that turn away from the camera (rear views).
        for idx, name in ((0, "nose"), (14, "r_eye"), (15, "l_eye")):
            visible[idx] = pts2d[idx][2] < head_depth
        for idx, name in ((16, "r_ear"), (17, "l_ear")):
            visible[idx] = pts2d[idx][2] < head_depth + p.head_r * 0.5
        draw_openpose(out / f"{pose_id}.pose.png", pts2d, visible)
    return rec


def previews(out: Path, records: list[dict], clips: dict) -> None:
    W, H = CANVAS
    tw, th = W // 4, H // 4
    cols = 8
    rows = math.ceil(len(records) / cols)
    sheet = Image.new("RGB", (cols * tw, rows * th), (40, 40, 48))
    d = ImageDraw.Draw(sheet)
    for i, r in enumerate(records):
        im = Image.open(out / f"{r['id']}.regions.png").convert("RGBA").resize((tw, th), Image.NEAREST)
        x, y = (i % cols) * tw, (i // cols) * th
        sheet.paste(im, (x, y), im)
        gy = y + r["groundY"] / 4
        d.line((x, gy, x + tw, gy), fill=(90, 90, 110))
        d.text((x + 3, y + 3), r["id"], fill=(230, 230, 230))
    sheet.save(out / "contact.png")
    by = {r["id"]: r for r in records}
    for clip, ids in clips.items():
        frames = []
        for pid in ids:
            im = Image.open(out / f"{pid}.regions.png").convert("RGBA").resize((W // 3, H // 3), Image.NEAREST)
            bg = Image.new("RGBA", im.size, (40, 40, 48, 255))
            gy = by[pid]["groundY"] / 3
            ImageDraw.Draw(bg).line((0, gy, im.size[0], gy), fill=(120, 120, 140, 255))
            frames.append(Image.alpha_composite(bg, im).convert("P", palette=Image.ADAPTIVE))
        frames[0].save(out / f"{clip}.gif", save_all=True, append_images=frames[1:], duration=250, loop=0)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--character", choices=sorted(CHARACTERS), required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--camera", default="floor-perspective", choices=["floor-perspective", "side-on"])
    ap.add_argument("--only", help="comma-separated pose ids")
    args = ap.parse_args()
    out = (ROOT / args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    clips = CLIPS_BY_CHARACTER[args.character]
    wanted = set(args.only.split(",")) if args.only else None
    records = []
    clip_ids: dict[str, list[str]] = {}
    for clip, drawings in clips.items():
        for name, (pose, support) in drawings.items():
            pid = f"{clip}.{name}"
            clip_ids.setdefault(clip, []).append(pid)
            if wanted and pid not in wanted:
                continue
            records.append(render_pose(args.character, args.camera, pid, pose, support, out))
            print(f"rendered {pid} problems={records[-1]['problems']}", flush=True)
    meta = {"character": args.character, "camera": args.camera, "canvas": CANVAS,
            "orthoScale": ORTHO[args.character], "regions": REGIONS[args.character],
            "blender": bpy.app.version_string, "poses": records}
    (out / "rig.json").write_text(json.dumps(meta, indent=1))
    if not wanted:
        previews(out, records, clip_ids)
    bad = [r["id"] for r in records if r["problems"]]
    print(f"done {len(records)} poses; region problems: {bad or 'none'}")


if __name__ == "__main__":
    main()
