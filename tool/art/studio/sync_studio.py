#!/usr/bin/env python3
"""Keep the studio's workflow sidebar and the repo's workflows in step, in both directions.

The repo is the source of truth: the studio's state doesn't survive it being rebuilt. The owner's
edits in the studio still count, so nothing here overwrites them silently.

sync_state.json records the canonical hash of each workflow as of the last push or pull, which
tells the three kinds of difference apart:

  studio == repo            in sync
  studio == last sync       repo moved on: a push is safe
  repo == last sync         owner edited in the studio: pull it, or push --force to discard it
  all three differ          both changed: pull writes <name>.studio.json beside the source to merge by hand

Commands:
  sync_studio.py status                  what differs (exit 1 if owner edits are waiting)
  sync_studio.py push [--force] [names]  upload workflows and sample inputs; refuses over owner edits
  sync_studio.py diff <name>             what the owner changed, node by node
  sync_studio.py pull [names]            bring owner edits into the repo and regenerate the API files
  sync_studio.py inputs --dir D --pose P upload one staged pose so the workflow runs on it in the studio

Comparison ignores what the frontend rewrites on save with no edit (viewport, node order, execution
order, revision, slot labels, S&R properties, floating point noise in positions). Moving a node or
changing a widget counts as an edit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import ui_to_api as U  # noqa: E402

STATE = U.SOURCES / "sync_state.json"
SAMPLES = U.SOURCES / "samples"
PREFIX = "kumbia-"
STUDIO = U.STUDIO_URL
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))
FRONTEND_PROPERTIES = {"Node name for S&R", "cnr_id", "ver", "aux_id", "enableTabs", "tabWidth", "tabXOffset",
                       "hasSecondTab", "secondTabText", "secondTabOffset", "secondTabWidth", "models"}


def _round(value):
    if isinstance(value, float):
        return round(value)
    if isinstance(value, list):
        return [_round(v) for v in value]
    return value


def edges(ui: dict) -> list:
    """Each link as (from node, from slot, to node, to input name): link ids and slot order get renumbered on save."""
    out = []
    for node in ui.get("nodes", []):
        for item in node.get("inputs", []):
            if item.get("link") is None:
                continue
            link = next(k for k in ui["links"] if (k[0] if isinstance(k, list) else k["id"]) == item["link"])
            origin = link[1:3] if isinstance(link, list) else [link["origin_id"], link["origin_slot"]]
            out.append([*origin, node["id"], item["name"]])
    return sorted(out)


def canonical(ui: dict) -> dict:
    """The parts of a workflow an edit can change, in a stable order."""
    nodes = []
    for node in sorted(ui.get("nodes", []), key=lambda n: n["id"]):
        keep = {"id": node["id"], "type": node["type"], "mode": node.get("mode", 0), "pos": _round(list(node["pos"]))}
        for key in ("title", "color", "bgcolor"):
            if node.get(key):
                keep[key] = node[key]
        keep["widgets_values"] = node.get("widgets_values", [])
        keep["properties"] = {k: v for k, v in node.get("properties", {}).items() if k not in FRONTEND_PROPERTIES}
        nodes.append(keep)
    groups = sorted(({"title": g.get("title"), "bounding": _round(list(g.get("bounding", []))), "color": g.get("color")}
                     for g in ui.get("groups", [])), key=lambda g: (g["title"] or "", g["bounding"]))
    return {"nodes": nodes, "edges": edges(ui), "groups": groups, "kumbia": ui.get("extra", {}).get("kumbia")}


def digest(ui: dict) -> str:
    return hashlib.sha256(json.dumps(canonical(ui), sort_keys=True).encode()).hexdigest()


def diff_lines(studio: dict, repo: dict) -> list[str]:
    a, b = canonical(repo), canonical(studio)
    out = []
    old, new = {n["id"]: n for n in a["nodes"]}, {n["id"]: n for n in b["nodes"]}
    for nid in sorted(old.keys() - new.keys()):
        out.append(f"removed node {nid} ({old[nid]['type']})")
    for nid in sorted(new.keys() - old.keys()):
        out.append(f"added node {nid} ({new[nid]['type']})")
    for nid in sorted(old.keys() & new.keys()):
        for key in sorted(old[nid].keys() | new[nid].keys()):
            if old[nid].get(key) != new[nid].get(key):
                out.append(f"node {nid} ({old[nid].get('title') or old[nid]['type']}) {key}: "
                           f"{json.dumps(old[nid].get(key))[:200]} -> {json.dumps(new[nid].get(key))[:200]}")
    for edge in a["edges"]:
        if edge not in b["edges"]:
            out.append(f"unlinked {edge[0]}:{edge[1]} -> {edge[2]}.{edge[3]}")
    for edge in b["edges"]:
        if edge not in a["edges"]:
            out.append(f"linked {edge[0]}:{edge[1]} -> {edge[2]}.{edge[3]}")
    if a["groups"] != b["groups"]:
        out.append("groups changed")
    if a["kumbia"] != b["kumbia"]:
        out.append("extra.kumbia changed")
    return out


class Studio:
    def __init__(self, url: str = STUDIO):
        self.url = url.rstrip("/")

    @staticmethod
    def _path(name: str) -> str:
        return urllib.parse.quote(f"workflows/{PREFIX}{name}.json", safe="")

    def read(self, name: str) -> dict | None:
        try:
            with OPENER.open(f"{self.url}/api/userdata/{self._path(name)}") as resp:
                return json.load(resp)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            raise

    def write(self, name: str, ui: dict) -> None:
        req = urllib.request.Request(f"{self.url}/api/userdata/{self._path(name)}?overwrite=true",
                                     data=json.dumps(ui).encode(), method="POST",
                                     headers={"Content-Type": "application/json"})
        OPENER.open(req).close()

    def upload_input(self, path: Path, as_name: str | None = None) -> None:
        boundary = uuid.uuid4().hex
        kind = mimetypes.guess_type(path.name)[0] or "image/png"
        body = b"".join([
            f'--{boundary}\r\nContent-Disposition: form-data; name="overwrite"\r\n\r\ntrue\r\n'.encode(),
            f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{as_name or path.name}"\r\n'
            f'Content-Type: {kind}\r\n\r\n'.encode(), path.read_bytes(), f'\r\n--{boundary}--\r\n'.encode()])
        req = urllib.request.Request(f"{self.url}/upload/image", data=body, method="POST",
                                     headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
        OPENER.open(req).close()


def repo_workflows() -> dict[str, Path]:
    return {p.stem: p for p in U.sources()}


def load_state() -> dict:
    return json.loads(STATE.read_text()) if STATE.exists() else {}


def save_state(state: dict) -> None:
    STATE.write_text(json.dumps(state, indent=1, sort_keys=True) + "\n")


def classify(repo: dict, studio: dict | None, base: str | None) -> str:
    """in-sync | missing | repo-ahead | owner-edit | conflict"""
    if studio is None:
        return "missing"
    r, s = digest(repo), digest(studio)
    if r == s:
        return "in-sync"
    if s == base:
        return "repo-ahead"
    if r == base:
        return "owner-edit"
    return "conflict"  # also when nothing was recorded: never assume the studio copy is disposable


def write_source(path: Path, ui: dict) -> None:
    """A stable, diffable form of what the frontend saved, with its API files regenerated."""
    ui = dict(ui)
    ui.pop("revision", None)
    ui.setdefault("extra", {}).pop("ds", None)
    ui["nodes"] = sorted(ui["nodes"], key=lambda n: n["id"])
    path.write_text(json.dumps(ui, indent=1, sort_keys=True) + "\n")
    for target, text in U.generated_files(path, U.load_schemas()).items():
        target.write_text(text)


def cmd_status(studio: Studio, _args) -> int:
    state, waiting = load_state(), 0
    for name, path in repo_workflows().items():
        status = classify(json.loads(path.read_text()), studio.read(name), state.get(name))
        print(f"{name}: {status}")
        waiting += status in ("owner-edit", "conflict")
    return 1 if waiting else 0


def cmd_push(studio: Studio, args) -> int:
    state, refused = load_state(), []
    for name, path in repo_workflows().items():
        if args.names and name not in args.names:
            continue
        ui = json.loads(path.read_text())
        status = classify(ui, studio.read(name), state.get(name))
        if status in ("owner-edit", "conflict") and not args.force:
            refused.append(name)
            print(f"{name}: REFUSED, {status}: the studio copy has changes the repo doesn't. "
                  f"Run `sync_studio.py diff {name}`, then pull it, or push --force to discard them.")
            continue
        if status != "in-sync":
            studio.write(name, ui)
        state[name] = digest(ui)
        print(f"{name}: {'kept' if status == 'in-sync' else 'uploaded'} ({status})")
    save_state(state)
    samples = sorted(SAMPLES.glob("*.png")) if SAMPLES.exists() else []
    for sample in samples:
        studio.upload_input(sample)
    print(f"sample inputs uploaded: {len(samples)}")
    return 1 if refused else 0


def cmd_diff(studio: Studio, args) -> int:
    path = repo_workflows()[args.name]
    remote = studio.read(args.name)
    if remote is None:
        print("not in the studio")
        return 0
    lines = diff_lines(remote, json.loads(path.read_text()))
    print("\n".join(lines) or "no differences")
    return 0


def cmd_pull(studio: Studio, args) -> int:
    state = load_state()
    for name, path in repo_workflows().items():
        if args.names and name not in args.names:
            continue
        repo, remote = json.loads(path.read_text()), studio.read(name)
        status = classify(repo, remote, state.get(name))
        if status == "owner-edit":
            write_source(path, remote)
            state[name] = digest(remote)
            print(f"{name}: pulled; review with `git diff {path.relative_to(U.ROOT)}`")
        elif status == "conflict":
            side = path.with_name(f"{name}.studio.json")
            side.write_text(json.dumps(remote, indent=1, sort_keys=True) + "\n")
            print(f"{name}: BOTH changed: wrote {side.relative_to(U.ROOT)}; the source is untouched. "
                  "Merge by hand, then push --force.")
        else:
            print(f"{name}: nothing to pull ({status})")
    save_state(state)
    return 0


def cmd_inputs(studio: Studio, args) -> int:
    folder = Path(args.dir)
    files = sorted(folder.glob(f"{args.pose}.*.png")) + [folder / n for n in ("ref_head.png", "ref_outfit.png", "identity.png")
                                                         if (folder / n).exists()]
    for f in files:
        studio.upload_input(f)
    print(f"uploaded {len(files)} files for {args.pose}; pick them in the $ Load Image nodes")
    return 0


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--url", default=STUDIO)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    p = sub.add_parser("push")
    p.add_argument("names", nargs="*")
    p.add_argument("--force", action="store_true")
    p = sub.add_parser("diff")
    p.add_argument("name")
    p = sub.add_parser("pull")
    p.add_argument("names", nargs="*")
    p = sub.add_parser("inputs")
    p.add_argument("--dir", required=True)
    p.add_argument("--pose", required=True)
    args = ap.parse_args()
    handler = {"status": cmd_status, "push": cmd_push, "diff": cmd_diff, "pull": cmd_pull, "inputs": cmd_inputs}[args.cmd]
    sys.exit(handler(Studio(args.url), args))


if __name__ == "__main__":
    main()
