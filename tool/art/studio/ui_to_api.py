#!/usr/bin/env python3
"""Convert a ComfyUI UI-format workflow to the API format, the way the frontend does.

tool/art/workflows/studio/<name>.json is the one source of truth: what the owner opens and edits
in the studio. <name>.api.json is generated from it for studio.run_workflow, and is never edited.

Two steps, kept apart so the first can be tested against the frontend's real output:

  convert(ui, schemas)   what app.graphToPrompt() returns, recorded under tool/art/studio/recorded/
  bind(api)              a LoadImage titled "$name" gets image "$name", which is what makes
                         run_workflow's inputs/init_image/mask bind to it

Rules taken from the frontend (1.55.17): virtual nodes (notes, reroutes) and muted nodes are left
out, inputs of muted parents are dropped, a bypassed node passes through its input of the same
type, a widget's value is read by its position in widgets_values, and the extra slots that
"control after generate" and "upload" take are skipped.

Usage:
  ui_to_api.py                write every <name>.api.json
  ui_to_api.py --check        exit 1 if any committed API file differs from a fresh conversion
  ui_to_api.py --refresh-schemas [--url http://studio:8188]   rewrite node_schemas.json
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCES = ROOT / "tool" / "art" / "workflows" / "studio"
SNAPSHOT = HERE / "node_schemas.json"
STUDIO_URL = "http://studio:8188"
VIRTUAL = {"Note", "MarkdownNote", "Reroute", "PrimitiveNode"}  # frontend-only: never in /object_info
WIDGET_TYPES = {"INT", "FLOAT", "STRING", "BOOLEAN", "COMBO", "COLOR"}
MODE_ACTIVE, MODE_MUTED, MODE_BYPASSED = 0, 2, 4


class ConversionError(ValueError):
    pass


def load_schemas(path: Path = SNAPSHOT) -> dict:
    return json.loads(path.read_text())


def sources(folder: Path = SOURCES) -> list[Path]:
    """Every committed UI workflow: <name>.json, not .api.json and not a pulled .studio.json."""
    return sorted(p for p in folder.glob("*.json") if not p.name.endswith((".api.json", ".studio.json"))
                  and p.name != "sync_state.json")


def input_specs(schema: dict) -> list[tuple[str, list]]:
    declared = schema["input"]
    out = []
    for section in ("required", "optional"):
        for name in schema.get("input_order", {}).get(section, list(declared.get(section, {}))):
            out.append((name, declared[section][name]))
    return out


def is_widget(spec: list) -> bool:
    kind, opts = spec[0], spec[1] if len(spec) > 1 else {}
    if opts.get("forceInput"):
        return False
    return isinstance(kind, list) or kind in WIDGET_TYPES


def widget_slots(schema: dict) -> list[tuple[str, bool]]:
    """(name, serialized) per entry of widgets_values, in order."""
    slots = []
    for name, spec in input_specs(schema):
        if not is_widget(spec):
            continue
        slots.append((name, True))
        opts = spec[1] if len(spec) > 1 else {}
        if opts.get("control_after_generate"):
            slots.append(("control_after_generate", False))
        if opts.get("image_upload"):
            slots.append(("upload", False))
    return slots


def widget_values(node: dict, schema: dict) -> dict:
    slots = widget_slots(schema)
    values = node.get("widgets_values")
    if isinstance(values, dict):  # some nodes save by name
        return {n: values[n] for n, keep in slots if keep and n in values}
    values = values or []
    if len(values) > len(slots):
        raise ConversionError(f"node {node['id']} ({node['type']}) has {len(values)} widget values, "
                              f"its schema has {len(slots)}: the schema snapshot may be stale")
    return {n: v for (n, keep), v in zip(slots, values) if keep}


class Graph:
    def __init__(self, ui: dict):
        if ui.get("definitions", {}).get("subgraphs"):
            raise ConversionError("subgraphs are not supported: unpack them in the studio first")
        self.nodes = {n["id"]: n for n in ui["nodes"]}
        self.links = {}
        for link in ui.get("links", []):
            if isinstance(link, dict):  # schema version 1
                link = [link["id"], link["origin_id"], link["origin_slot"], link["target_id"], link["target_slot"],
                        link["type"]]
            self.links[link[0]] = link

    def resolve(self, link_id: int | None) -> tuple[str, int] | None:
        """Follow a link back through reroutes and bypassed nodes to the node that makes the value."""
        while link_id is not None:
            link = self.links.get(link_id)
            if link is None:
                raise ConversionError(f"link {link_id} is referenced but not defined")
            parent = self.nodes.get(link[1])
            if parent is None:
                raise ConversionError(f"link {link_id} comes from missing node {link[1]}")
            mode = parent.get("mode", MODE_ACTIVE)
            if mode == MODE_MUTED:
                return None
            if parent["type"] == "Reroute":
                link_id = parent["inputs"][0].get("link")
            elif mode == MODE_BYPASSED:
                link_id = self.bypass_input(parent, link[2], link[5])
            elif parent["type"] in VIRTUAL:
                raise ConversionError(f"node {parent['id']} ({parent['type']}) feeds a link: "
                                      "convert it to a real primitive node")
            else:
                return str(parent["id"]), link[2]
        return None

    @staticmethod
    def bypass_input(node: dict, slot: int, kind: str) -> int | None:
        """The input a bypassed node passes through: the same slot if its type fits, else the first that does."""
        inputs = node.get("inputs", [])
        if slot < len(inputs) and inputs[slot].get("type") == kind:
            return inputs[slot].get("link")
        for item in inputs:
            if item.get("type") == kind:
                return item.get("link")
        return None


def convert(ui: dict, schemas: dict) -> dict:
    """The API prompt app.graphToPrompt() would produce. Keys in numeric node order, inputs in schema order."""
    graph = Graph(ui)
    out = {}
    for node in sorted(ui["nodes"], key=lambda n: n["id"]):
        cls = node["type"]
        if cls in VIRTUAL or node.get("mode", MODE_ACTIVE) in (MODE_MUTED, MODE_BYPASSED):
            continue
        schema = schemas.get(cls)
        if schema is None:
            raise ConversionError(f"node {node['id']}: class {cls} is not in the schema snapshot; "
                                  "run ui_to_api.py --refresh-schemas")
        values = widget_values(node, schema)
        linked = {}
        for item in node.get("inputs", []):
            if item.get("link") is None:
                continue
            source = graph.resolve(item["link"])
            if source is None:  # a muted parent: a widget input falls back to its own value
                continue
            linked[item["name"]] = [source[0], source[1]]
        inputs = {}
        for name, _spec in input_specs(schema):
            if name in linked:
                inputs[name] = linked[name]
            elif name in values:
                inputs[name] = values[name]
        out[str(node["id"])] = {"inputs": inputs, "class_type": cls,
                                "_meta": {"title": node.get("title") or schema.get("display_name") or cls}}
    return out


def bind(api: dict) -> dict:
    """Replace the literal image of each LoadImage titled $name with "$name", for run_workflow."""
    out = json.loads(json.dumps(api))
    for node in out.values():
        title = node.get("_meta", {}).get("title", "")
        if node["class_type"] == "LoadImage" and title.startswith("$"):
            node["inputs"]["image"] = title
    return out


def apply_variant(api: dict, ui: dict, variant: str) -> dict:
    """Lay a named set of widget values from extra.kumbia.variants over the graph."""
    out = json.loads(json.dumps(api))
    for node_id, values in ui["extra"]["kumbia"]["variants"][variant].items():
        out[node_id]["inputs"].update(values)
    return out


def dumps(api: dict) -> str:
    return json.dumps(api, indent=1) + "\n"


def generated_files(path: Path, schemas: dict) -> dict[Path, str]:
    """{API file: contents} for one UI source: the default graph, and one per declared variant."""
    ui = json.loads(path.read_text())
    bound = bind(convert(ui, schemas))
    stem = path.name[:-len(".json")]
    files = {path.with_name(f"{stem}.api.json"): dumps(bound)}
    for variant in sorted(ui.get("extra", {}).get("kumbia", {}).get("variants", {})):
        files[path.with_name(f"{stem}.{variant}.api.json")] = dumps(apply_variant(bound, ui, variant))
    return files


def refresh_schemas(url: str, folder: Path = SOURCES) -> None:
    """Rewrite the snapshot with just the classes the workflows use, minus tooltips and combo lists."""
    with urllib.request.urlopen(f"{url}/object_info") as resp:
        info = json.load(resp)
    used = set()
    for path in sources(folder):
        used |= {n["type"] for n in json.loads(path.read_text())["nodes"]}
    for extra in (HERE / "recorded").glob("*.ui.json"):
        used |= {n["type"] for n in json.loads(extra.read_text())["nodes"]}
    snapshot = {}
    missing = []
    for cls in sorted(used - VIRTUAL):
        if cls not in info:
            missing.append(cls)
            continue
        s = info[cls]
        snapshot[cls] = {k: s[k] for k in ("input", "input_order", "output", "output_name", "display_name",
                                           "python_module") if k in s}
        for section in snapshot[cls]["input"].values():
            for spec in section.values():
                if len(spec) > 1 and isinstance(spec[1], dict):
                    spec[1].pop("tooltip", None)
    SNAPSHOT.write_text(json.dumps(snapshot, indent=1, sort_keys=True) + "\n")
    print(f"wrote {SNAPSHOT.relative_to(ROOT)}: {len(snapshot)} classes")
    if missing:
        sys.exit(f"not in the studio's /object_info: {', '.join(missing)}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--refresh-schemas", action="store_true")
    ap.add_argument("--url", default=STUDIO_URL)
    args = ap.parse_args()
    if args.refresh_schemas:
        refresh_schemas(args.url)
        return
    schemas = load_schemas()
    stale = []
    for path in sources():
        for target, text in generated_files(path, schemas).items():
            if args.check:
                if not target.exists() or target.read_text() != text:
                    stale.append(target)
            else:
                target.write_text(text)
                print(f"wrote {target.relative_to(ROOT)}")
    if stale:
        sys.exit("stale, run ui_to_api.py: " + ", ".join(str(p.relative_to(ROOT)) for p in stale))


if __name__ == "__main__":
    main()
