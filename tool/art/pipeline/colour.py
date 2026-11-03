"""Colour maths shared by the pipeline: OKLab, reserved-ramp gates, per-region ramps."""
from __future__ import annotations

import numpy as np


def hex_to_rgb(h: str) -> tuple[int, int, int]:
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))  # type: ignore[return-value]


def rgb_to_hex(c) -> str:
    return "#{:02X}{:02X}{:02X}".format(*[int(v) for v in c])


_M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
                [0.2119034982, 0.6806995451, 0.1073969566],
                [0.0883024619, 0.2817188376, 0.6299787005]])
_M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
                [1.9779984951, -2.4285922050, 0.4505937099],
                [0.0259040371, 0.7827717662, -0.8086757660]])


def oklab(rgb) -> np.ndarray:
    """sRGB 0-255 -> OKLab with all axes scaled by 100."""
    c = np.asarray(rgb, float) / 255.0
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return 100 * (np.cbrt(c @ _M1.T) @ _M2.T)


def oklab_to_rgb(lab) -> np.ndarray:
    lms = (np.asarray(lab, float) / 100) @ np.linalg.inv(_M2).T
    lin = (lms ** 3) @ np.linalg.inv(_M1).T
    lin = np.clip(lin, 0, 1)
    s = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)
    return np.clip(np.rint(s * 255), 0, 255).astype(int)


# ---------------------------------------------------------------- gates


def _value(term, ch):
    if isinstance(term, str):
        return ch[term]
    if isinstance(term, dict) and "sub" in term:
        a, b = term["sub"]
        return _value(a, ch) - _value(b, ch)
    if isinstance(term, dict) and "mul" in term:
        k, c = term["mul"]
        return k * _value(c, ch)
    return float(term)


def _cond(c, ch) -> bool:
    lhs, rhs = _value(c["lhs"], ch), _value(c["rhs"], ch)
    return {">=": lhs >= rhs, "<=": lhs <= rhs, ">": lhs > rhs, "<": lhs < rhs}[c["op"]]


def gates_hit(rgb, reserved_ramps: list[dict]) -> list[str]:
    """Ids of the reserved-ramp gates this colour matches (shaders/party_palette.frag)."""
    ch = {"r": rgb[0] / 255, "g": rgb[1] / 255, "b": rgb[2] / 255}
    return [g["id"] for ramp in reserved_ramps for g in ramp["gates"] if all(_cond(c, ch) for c in g["all"])]


def nudge_out_of_gates(rgb, reserved_ramps: list[dict]) -> tuple[int, int, int]:
    """Smallest green lift that leaves every gate (gates bound g from above)."""
    r, g, b = rgb
    if not gates_hit((r, g, b), reserved_ramps):
        return (r, g, b)
    for dg in range(1, 256):
        cand = (r, min(255, g + dg), b)
        if not gates_hit(cand, reserved_ramps):
            return cand
    raise ValueError(f"cannot move {rgb_to_hex(rgb)} out of the gates")


class GateViolation(ValueError):
    pass


# ---------------------------------------------------------------- ramps

OFFSETS = {3: (-16, 0, 11), 4: (-26, -13, 0, 10), 5: (-30, -18, -8, 0, 10)}


def make_ramp(colour: str, shades: int) -> list[tuple[int, int, int]]:
    """Dark to light in OKLab, keeping the declared colour itself as one shade."""
    base = oklab(hex_to_rgb(colour))
    out = []
    for off in OFFSETS[shades]:
        if off == 0:
            out.append(hex_to_rgb(colour))
            continue
        lab = base.copy()
        lab[0] = float(np.clip(lab[0] + off, 3, 99))
        # Shadows cool slightly and lose chroma less than highlights: flat game shading.
        k = 0.92 if off < 0 else 0.85
        lab[1:] = lab[1:] * k
        out.append(tuple(int(v) for v in oklab_to_rgb(lab)))
    return out


def colour_entries(c: dict) -> list[dict]:
    """Every coloured part of a definition, in a stable order: id, region, colour, flags."""
    out = [{"id": "skin", "region": "skin", "colour": c["skin"], "recolourable": False, "nudge": False}]
    for g in c["garments"]:
        if "colour" in g:
            out.append({"id": g["id"], "region": g["region"], "colour": g["colour"],
                        "recolourable": g.get("recolourable", False), "nudge": g.get("nudge", False)})
    for p in c.get("props", []):
        out.append({"id": p["id"], "region": "prop", "colour": p["colour"], "recolourable": False, "nudge": False})
    return out


def check_gates(c: dict, style: dict, overrides: dict | None = None) -> dict:
    """Refuse an in-gate colour on a non-recolourable part, or apply its declared nudge.

    Returns {part id: final hex}. Raises GateViolation naming part, colour and gate.
    """
    rr = style.get("reservedRamps", [])
    final, problems = {}, []
    for e in colour_entries(c):
        colour = (overrides or {}).get(e["id"], e["colour"])
        rgb = hex_to_rgb(colour)
        hits = gates_hit(rgb, rr)
        if hits and not e["recolourable"]:
            if e["nudge"]:
                moved = rgb_to_hex(nudge_out_of_gates(rgb, rr))
                final[e["id"]] = moved
                continue
            problems.append(f"{e['id']}: colour {colour.upper()} matches reserved ramp gate {'/'.join(hits)}"
                            f" (nearest colour outside the gates: {rgb_to_hex(nudge_out_of_gates(rgb, rr))})")
            continue
        final[e["id"]] = colour.upper()
    if problems:
        raise GateViolation("; ".join(problems))
    return final


def build_ramps(c: dict, style: dict, overrides: dict | None = None, avoid: tuple[str, ...] = ()) -> dict:
    """Per-part ramps with no colour shared between ramps, all outside the gates.

    Returns {part id: {region, shades: [hex dark..light], nudged: {from: to}}}.
    Parts sharing a region (a waistcoat's buttons, say) keep separate ramps.
    `avoid` lists colours no ramp may take (the outline).
    """
    finals = check_gates(c, style, overrides)
    rr = style.get("reservedRamps", [])
    taken = {hex_to_rgb(a) for a in avoid}
    taken.add(hex_to_rgb(style["outline"]))
    out = {}
    for e in colour_entries(c):
        shades, nudged = [], {}
        for rgb in make_ramp(finals[e["id"]], style["ramp"]["shades"]):
            cand = rgb if e["recolourable"] else nudge_out_of_gates(rgb, rr)
            start = cand
            step = 0
            while cand in taken or (not e["recolourable"] and gates_hit(cand, rr)):
                step += 1
                d = (step + 1) // 2 * (1 if step % 2 else -1)
                cand = (start[0], start[1], max(0, min(255, start[2] + d)))
            taken.add(cand)
            shades.append(rgb_to_hex(cand))
            if cand != tuple(rgb):
                nudged[rgb_to_hex(rgb)] = rgb_to_hex(cand)
        out[e["id"]] = {"region": e["region"], "shades": shades, "nudged": nudged}
    return out
