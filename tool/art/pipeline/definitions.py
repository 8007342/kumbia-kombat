#!/usr/bin/env python3
"""Load and validate character, style and backend definitions.

Every refusal names the offending field, before any rendering or GPU work.

Usage: definitions.py character|style|backend <id>   (exit 1 with one line per problem)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

ART = Path(__file__).resolve().parents[1]
ROOT = ART.parents[1]
LIBRARY = json.loads((ART / "rig" / "library.json").read_text())
BODIES = json.loads((ART / "rig" / "bodies.json").read_text())


class DefinitionError(ValueError):
    def __init__(self, problems: list[str]):
        super().__init__("; ".join(problems))
        self.problems = problems


def _schema(kind: str) -> dict:
    return json.loads((ART / "schemas" / f"{kind}.schema.json").read_text())


def _field(err) -> str:
    return ".".join(str(p) for p in err.absolute_path) or "(top level)"


def schema_problems(kind: str, data: dict) -> list[str]:
    errs = Draft202012Validator(_schema(kind)).iter_errors(data)
    return [f"{_field(e)}: {e.message}" for e in sorted(errs, key=lambda e: list(map(str, e.absolute_path)))]


def character_problems(c: dict, root: Path = ROOT) -> list[str]:
    """Schema plus the closed vocabularies a schema cannot express."""
    out = schema_problems("character", c)
    if out:
        return out
    if not (ART / "styles" / f"{c['style']}.json").exists():
        out.append(f"style: unknown style {c['style']!r}")
    if c.get("backend") and not (ART / "backends" / f"{c['backend']}.json").exists():
        out.append(f"backend: unknown backend {c['backend']!r}")
    if c["body"]["preset"] not in BODIES:
        out.append(f"body.preset: unknown body preset {c['body']['preset']!r}")
    if not (ART / "motion" / f"{c['motion']['set']}.json").exists():
        out.append(f"motion.set: unknown motion set {c['motion']['set']!r}")
    seen: dict[str, str] = {}
    for i, g in enumerate(c["garments"]):
        if g["shape"] not in LIBRARY["shapes"]:
            out.append(f"garments.{i}.shape: unknown garment shape {g['shape']!r}")
        if g["region"] not in LIBRARY["regions"]:
            out.append(f"garments.{i}.region: unknown region {g['region']!r}")
        if g["id"] in seen:
            out.append(f"garments.{i}.id: duplicate id {g['id']!r}")
        seen[g["id"]] = g["region"]
    for i, p in enumerate(c.get("props", [])):
        if p["kind"] not in LIBRARY["props"]:
            out.append(f"props.{i}.kind: unknown prop kind {p['kind']!r}")
    for i, r in enumerate(c.get("references", {}).get("sources", [])):
        if not (root / r["image"]).exists():
            out.append(f"references.sources.{i}.image: missing reference file {r['image']!r}")
    regions = rig_regions(c)
    colours = [LIBRARY["regions"][r] for r in regions if r in LIBRARY["regions"]]
    if len(set(colours)) != len(colours):
        out.append(f"garments: regions {sorted(regions)} share a flat mask colour")
    for vid, v in c.get("variants", {}).items():
        for key in v.get("colours", {}):
            if key != "skin" and key not in seen and key not in {p["id"] for p in c.get("props", [])}:
                out.append(f"variants.{vid}.colours.{key}: unknown garment or prop {key!r}")
    if c.get("status", "active") == "active":
        for req in ("family", "pronouns", "skin", "traits", "references", "targets", "seedBase"):
            if req not in c:
                out.append(f"{req}: required for an active character")
    return out


def rig_regions(c: dict) -> dict[str, str]:
    """Region name -> flat mask colour, for the regions this character renders."""
    if any(g["shape"] == "macron-body" for g in c["garments"]):
        names = list(c["garments"][0].get("params", {}).get("regions", []))
    else:
        names = ["skin"] + [g["region"] for g in c["garments"]]
        if c.get("props"):
            names.append("prop")
    return {n: LIBRARY["regions"][n] for n in dict.fromkeys(names) if n in LIBRARY["regions"]}


def _load(kind: str, folder: str, ident: str, problems) -> dict:
    p = ART / folder / f"{ident}.json"
    if not p.exists():
        raise DefinitionError([f"{kind}: no definition {p.relative_to(ROOT)}"])
    d = json.loads(p.read_text())
    bad = problems(d)
    if bad:
        raise DefinitionError(bad)
    return d


def load_character(ident: str) -> dict:
    return _load("character", "characters", ident, character_problems)


def load_style(ident: str) -> dict:
    return _load("style", "styles", ident, lambda d: schema_problems("style", d))


def load_backend(ident: str) -> dict:
    return _load("backend", "backends", ident, lambda d: schema_problems("backend", d))


def load_motion(ident: str) -> dict:
    p = ART / "motion" / f"{ident}.json"
    return json.loads(p.read_text())


def resolve_backend(character: dict, style: dict, override: str | None = None) -> dict:
    """--backend beats the character, which beats the style default (design D6)."""
    return load_backend(override or character.get("backend") or style["backend"])


def body_of(c: dict) -> dict:
    b = json.loads(json.dumps(BODIES[c["body"]["preset"]]))
    for k, v in c["body"].get("overrides", {}).items():
        if isinstance(v, dict):
            b[k].update(v)
        else:
            b[k] = v
    b.pop("$comment", None)
    return b


def main() -> None:
    kind, ident = sys.argv[1], sys.argv[2]
    try:
        {"character": load_character, "style": load_style, "backend": load_backend}[kind](ident)
    except DefinitionError as e:
        for p in e.problems:
            print(f"refused:{kind}:{ident}:{p}")
        sys.exit(1)
    print(f"ok:{kind}:{ident}")


if __name__ == "__main__":
    main()
