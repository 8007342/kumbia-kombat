"""Blender mesh primitives and flat region materials for the stand-in rig."""

from __future__ import annotations

import warnings

import bpy
from mathutils import Matrix, Vector


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(h: str) -> tuple[float, float, float]:
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))  # type: ignore[return-value]


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
