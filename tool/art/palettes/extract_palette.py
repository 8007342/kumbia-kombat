#!/usr/bin/env python3
"""Extract a locked tillandsias.palette/v1 file from approved character art.

Usage:
  python3 tool/art/palettes/extract_palette.py \
      --source assets/art/ensemble/gatekeeper-v2.png \
      --name gatekeeper --colours 31 --outline '#1A1018' \
      --out tool/art/palettes/gatekeeper.json

Only opaque pixels (alpha >= 128) are sampled. Colours come from Pillow's
median-cut quantiser (deterministic for the same input), sorted dark to light
by luma so the index order is stable; the family outline is forced in at
index 0. Reordering a published palette is a version change (contract D12).

--avoid-gates <family spec> nudges any colour that a reserved ramp's recolor
gate would match (contract check palette_fails_all_gates) to the nearest RGB
value that misses every gate by at least half a code value, so the party
shader can never recolor the character and boundary rounding cannot flip it.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


def luma(rgb: tuple[int, int, int]) -> float:
    r, g, b = rgb
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


MARGIN = 0.5 / 255  # a condition must fail by this much to count as failed


def _val(term, rgb: dict[str, float]) -> float:
    if isinstance(term, (int, float)):
        return float(term)
    if isinstance(term, str):
        return rgb[term]
    if "mul" in term:
        k, ch = term["mul"]
        return float(k) * _val(ch, rgb)
    if "sub" in term:
        a, b = term["sub"]
        return _val(a, rgb) - _val(b, rgb)
    raise ValueError(f"unknown gate term {term!r}")


def _cond_fails(cond, rgb) -> bool:
    lhs, rhs = _val(cond["lhs"], rgb), _val(cond["rhs"], rgb)
    if cond["op"] == ">=":
        return lhs < rhs - MARGIN
    if cond["op"] == "<=":
        return lhs > rhs + MARGIN
    raise ValueError(f"unknown gate op {cond['op']!r}")


def gates_hit(c: tuple[int, int, int], gates: list[dict]) -> list[str]:
    rgb = dict(zip("rgb", (v / 255 for v in c)))
    return [g["id"] for g in gates if not any(_cond_fails(x, rgb) for x in g["all"])]


def nudge(c: tuple[int, int, int], gates: list[dict], radius: int = 24) -> tuple[int, int, int]:
    best = None
    for dr in range(-radius, radius + 1):
        for dg in range(-radius, radius + 1):
            for db in range(-radius, radius + 1):
                d = dr * dr + dg * dg + db * db
                if best is not None and d >= best[0]:
                    continue
                n = (c[0] + dr, c[1] + dg, c[2] + db)
                if all(0 <= v <= 255 for v in n) and not gates_hit(n, gates):
                    best = (d, n)
    if best is None:
        raise SystemExit(f"no gate-free colour within {radius} of {c}")
    return best[1]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True, action="append",
                    help="approved art PNG (repeatable)")
    ap.add_argument("--name", required=True)
    ap.add_argument("--colours", type=int, default=31)
    ap.add_argument("--merge", type=int, default=20,
                    help="merge colours closer than this RGB distance (weighted to the more common)")
    ap.add_argument("--outline", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--avoid-gates", metavar="SPEC",
                    help="family spec whose reservedRamps gates every colour must miss")
    a = ap.parse_args()

    pixels: list[tuple[int, int, int]] = []
    hashes = {}
    for src in a.source:
        data = Path(src).read_bytes()
        hashes[src] = hashlib.sha256(data).hexdigest()
        im = Image.open(src).convert("RGBA")
        pixels += [p[:3] for p in im.get_flattened_data() if p[3] >= 128]
    if not pixels:
        raise SystemExit("no opaque pixels")

    strip = Image.new("RGB", (len(pixels), 1))
    strip.putdata(pixels)
    k = a.colours * 3
    q = strip.quantize(colors=k, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q.getpalette()[: k * 3]
    counts = sorted(q.getcolors(maxcolors=1 << 16), reverse=True)  # most common first
    cols: list[tuple[int, int, int]] = []
    for _, i in counts:
        c = tuple(pal[i * 3: i * 3 + 3])
        if all(sum((x - y) ** 2 for x, y in zip(c, d)) ** 0.5 >= a.merge for d in cols):
            cols.append(c)
        if len(cols) == a.colours:
            break

    nudged = {}
    if a.avoid_gates:
        spec = json.loads(Path(a.avoid_gates).read_text())
        gates = [g for r in spec.get("reservedRamps", []) for g in r["gates"]]
        for i, c in enumerate(cols):
            if gates_hit(c, gates):
                n = nudge(c, gates)
                nudged["#%02X%02X%02X" % c] = "#%02X%02X%02X" % n
                cols[i] = n

    outline = a.outline.upper()
    hexes = [f"#{r:02X}{g:02X}{b:02X}" for r, g, b in sorted(cols, key=luma)]
    hexes = [outline] + [h for h in hexes if h != outline]

    doc = {
        "schema": "tillandsias.palette/v1",
        "name": a.name,
        "colours": hexes,
        "transparent": None,
        "$provenance": {
            "tool": "tool/art/palettes/extract_palette.py",
            "sources": hashes,
            "method": f"median-cut {a.colours * 3}, merge<{a.merge}, top {a.colours} by count, alpha>=128, luma order, outline at 0",
        },
    }
    if a.avoid_gates:
        doc["$provenance"]["avoidGates"] = {"spec": a.avoid_gates, "nudged": nudged}
    Path(a.out).write_text(json.dumps(doc, indent=1) + "\n")
    print(f"wrote {a.out}: {len(hexes)} colours" + "".join(f"; {k}->{v}" for k, v in nudged.items()))


if __name__ == "__main__":
    main()
