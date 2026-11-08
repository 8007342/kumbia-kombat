#!/usr/bin/env python3
"""Write assets/credits.json, the credits roll's data, from the project's real dependency data.

Run from the repository root, after `flutter pub get` so the Dart package graph exists:

    python3 -I tool/credits/build_credits.py            # writes assets/credits.json
    python3 -I tool/credits/build_credits.py --check    # exits 1 if the file is stale

Standard library only. What it reads, and what each item's degree means:

- degree 0: the base, from tool/credits/base.json (Tillandsias, Podman, Fedora).
- degree 1: what the project uses directly: pubspec.yaml's dependencies and dev dependencies, mixrs's
  Cargo.toml dependencies, the third-party modules the Python tools import, package.json, the models
  and engine in the committed provenance records, and base.json's tools.
- degree 2 and more: what those use, by walking each graph: .dart_tool/package_graph.json (or the
  pubspecs in the pub cache when it's missing), Cargo.lock, the venvs' Requires-Dist, the provenance
  records' ComfyUI custom nodes.

Anything it can't read is listed under "sources" with why, so a regeneration on another machine says
what it left out instead of failing. Output is sorted and has no timestamp, so it only changes when the
dependencies do.
"""

from __future__ import annotations

import argparse
import ast
import json
import os
import re
import subprocess
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CACHE = Path(os.environ.get("TILLANDSIAS_PROJECT_CACHE", Path.home() / ".cache/tillandsias-project"))
OUT = ROOT / "assets/credits.json"

# Import names whose distribution is called something else.
DIST_FOR_MODULE = {
    "PIL": "pillow",
    "zxingcpp": "zxing-cpp",
    "cv2": "opencv-python",
    "yaml": "PyYAML",
    "sklearn": "scikit-learn",
    "mathutils": "bpy",
    "bpy_extras": "bpy",
}


def norm(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


class Credits:
    def __init__(self) -> None:
        self.items: dict[tuple[str, str], dict] = {}
        self.sources: list[dict] = []

    def add(self, name, kind, degree, version=None, via=None, **extra):
        key = (kind if kind != "platform" else "tool", norm(name))
        old = self.items.get(key)
        item = {"name": name, "kind": kind, "degree": degree}
        if version:
            item["version"] = str(version)
        if via and degree >= 2:
            item["via"] = via
        item.update({k: v for k, v in extra.items() if v is not None})
        if old is None:
            self.items[key] = item
            return
        if degree < old["degree"]:
            keep = {k: old[k] for k in ("role", "url", "licence", "build") if k in old}
            item = {**keep, **item}
            if degree < 2:
                item.pop("via", None)
            self.items[key] = item
        else:
            if not old.get("version") and version:
                old["version"] = str(version)
            for k, v in extra.items():
                if k != "build" and v is not None:
                    old.setdefault(k, v)
        if degree <= old["degree"] and not extra.get("build"):
            self.items[key].pop("build", None)

    def source(self, what, path, ok, note=None):
        entry = {"what": what, "path": path, "read": ok}
        if note:
            entry["note"] = note
        self.sources.append(entry)


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path).replace(str(Path.home()), "~")


# Dart ------------------------------------------------------------------------------------------


def read_lock(path: Path) -> dict[str, dict]:
    """pubspec.lock's packages: name -> {version, dependency, source}. The lock's YAML is regular
    enough to read by indentation."""
    packages: dict[str, dict] = {}
    current = None
    in_packages = False
    for line in path.read_text().splitlines():
        if line.startswith("packages:"):
            in_packages = True
            continue
        if in_packages and line and not line.startswith(" "):
            in_packages = False
        if not in_packages:
            continue
        m = re.match(r"^  ([A-Za-z0-9_]+):\s*$", line)
        if m:
            current = packages.setdefault(m.group(1), {})
            continue
        m = re.match(r'^    (dependency|source|version):\s*"?([^"]*)"?\s*$', line)
        if m and current is not None:
            current[m.group(1)] = m.group(2)
    return packages


def pubspec_dependencies(text: str) -> tuple[list[str], list[str]]:
    deps: list[str] = []
    dev: list[str] = []
    section = None
    for line in text.splitlines():
        if re.match(r"^\S", line):
            section = {"dependencies:": deps, "dev_dependencies:": dev}.get(line.strip())
            continue
        m = re.match(r"^  ([A-Za-z0-9_]+):", line)
        if m and section is not None:
            section.append(m.group(1))
    return deps, dev


def dart_graph(credits: Credits, dart_tool: Path) -> None:
    lock_path = ROOT / "pubspec.lock"
    lock = read_lock(lock_path)
    credits.source("Dart packages and versions", rel(lock_path), True, f"{len(lock)} packages")
    graph_path = dart_tool / "package_graph.json"
    edges: dict[str, list[str]] = {}
    roots_main: list[str]
    roots_dev: list[str]
    if graph_path.exists():
        graph = json.loads(graph_path.read_text())
        for pkg in graph["packages"]:
            edges[pkg["name"]] = list(pkg.get("dependencies", []))
        root = next(p for p in graph["packages"] if p["name"] in graph["roots"])
        roots_main = list(root.get("dependencies", []))
        roots_dev = list(root.get("devDependencies", []))
        credits.source("Dart package graph", rel(graph_path), True)
    else:
        roots_main, roots_dev = pubspec_dependencies((ROOT / "pubspec.yaml").read_text())
        pub = Path(os.environ.get("PUB_CACHE", CACHE / "pub")) / "hosted/pub.dev"
        missing = []
        for name, info in lock.items():
            spec = pub / f"{name}-{info.get('version')}" / "pubspec.yaml"
            if spec.exists():
                edges[name] = pubspec_dependencies(spec.read_text())[0]
            else:
                missing.append(name)
        credits.source(
            "Dart package graph",
            rel(graph_path),
            False,
            "missing: run flutter pub get. Read the pub cache's pubspecs instead; "
            f"without edges for {', '.join(sorted(missing)) or 'none'}",
        )
    versions = {n: i.get("version") for n, i in lock.items()}
    sdk_names = {n for n, i in lock.items() if i.get("source") == "sdk"}

    def walk(roots, build):
        depth = {r: 1 for r in roots}
        via = {}
        frontier = list(roots)
        while frontier:
            nxt = []
            for name in frontier:
                for dep in edges.get(name, []):
                    if dep not in depth:
                        depth[dep] = depth[name] + 1
                        via[dep] = name
                        nxt.append(dep)
            frontier = nxt
        return depth, via

    main_depth, main_via = walk(roots_main, False)
    dev_depth, dev_via = walk(roots_dev, True)
    names = set(main_depth) | set(dev_depth) | set(lock)
    for name in sorted(names):
        if name in main_depth:
            degree, via, build = main_depth[name], main_via.get(name), None
        elif name in dev_depth:
            degree, via, build = dev_depth[name], dev_via.get(name), True
        else:
            # In the lock but reached by no edge we could read: a Flutter SDK pin.
            degree, via, build = 2, "flutter", None
        version = versions.get(name)
        if name in sdk_names or version == "0.0.0":
            version = None
        credits.add(name, "dart", degree, version, via, build=build)


# Rust ------------------------------------------------------------------------------------------


def rust_graph(credits: Credits) -> None:
    lock_path = ROOT / "tool/music/mixrs/Cargo.lock"
    if not lock_path.exists():
        credits.source("Rust crates", rel(lock_path), False, "missing")
        return
    lock = tomllib.loads(lock_path.read_text())
    packages = lock.get("package", [])
    by_name = {p["name"]: p for p in packages}
    credits.source("Rust crates", rel(lock_path), True, f"{len(packages)} packages")
    root = by_name.get("mixrs")
    if root is None:
        return
    depth = {"mixrs": 0}
    via = {}
    frontier = ["mixrs"]
    while frontier:
        nxt = []
        for name in frontier:
            for dep in by_name.get(name, {}).get("dependencies", []):
                dep = dep.split(" ")[0]
                if dep not in depth:
                    depth[dep] = depth[name] + 1
                    via[dep] = name
                    nxt.append(dep)
        frontier = nxt
    for name, d in depth.items():
        if name == "mixrs":
            continue
        credits.add(name, "rust", d, by_name.get(name, {}).get("version"), via.get(name))


# Python ----------------------------------------------------------------------------------------


def python_imports(credits: Credits) -> set[str]:
    files = sorted(p for p in (ROOT / "tool").rglob("*.py"))
    local = {p.stem for p in files} | {p.name for p in (ROOT / "tool").rglob("*") if p.is_dir()}
    found: set[str] = set()
    for path in files:
        try:
            tree = ast.parse(path.read_text(), str(path))
        except (SyntaxError, UnicodeDecodeError):
            continue
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                mods = [a.name for a in node.names]
            elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
                mods = [node.module]
            else:
                continue
            for mod in mods:
                top = mod.split(".")[0]
                if top in sys.stdlib_module_names or top in local or top == "__future__":
                    continue
                found.add(DIST_FOR_MODULE.get(top, top))
    # `uv run --with <dist>` in the tools' instructions brings in packages as well.
    for path in files + sorted((ROOT / "tool").rglob("*.sh")):
        for dist in re.findall(r"--with[ =]([A-Za-z0-9_.\-]+)", path.read_text(errors="ignore")):
            found.add(dist)
    credits.source("Python tools' imports", "tool/**/*.py", True, f"{len(files)} files")
    return found


def venv_packages(credits: Credits) -> dict[str, dict]:
    """Every distribution in the forge's venvs: normalised name -> {name, version, requires}."""
    dists: dict[str, dict] = {}
    venvs = CACHE / "venvs"
    if not venvs.exists():
        credits.source("Python venvs", rel(venvs), False, "missing")
        return dists
    for venv in sorted(venvs.iterdir()):
        for meta in sorted(venv.glob("lib/python*/site-packages/*.dist-info/METADATA")):
            name = version = None
            requires = []
            for line in meta.read_text(errors="ignore").splitlines():
                if not line.strip():
                    break
                if line.startswith("Name:"):
                    name = line.split(":", 1)[1].strip()
                elif line.startswith("Version:"):
                    version = line.split(":", 1)[1].strip()
                elif line.startswith("Requires-Dist:"):
                    spec = line.split(":", 1)[1].strip()
                    if "extra ==" in spec:
                        continue
                    req = re.match(r"[A-Za-z0-9_.\-]+", spec)
                    if req:
                        requires.append(req.group(0))
            if name:
                dists[norm(name)] = {"name": name, "version": version, "requires": requires}
        cfg = venv / "pyvenv.cfg"
        if cfg.exists():
            credits.source("Python venv", rel(venv), True, cfg.read_text().split("version_info = ")[-1].split()[0] if "version_info" in cfg.read_text() else None)
    return dists


def python_graph(credits: Credits) -> None:
    direct = python_imports(credits)
    dists = venv_packages(credits)
    depth = {norm(d): 1 for d in direct}
    via: dict[str, str] = {}
    shown = {norm(d): d for d in direct}
    frontier = list(depth)
    while frontier:
        nxt = []
        for name in frontier:
            for req in dists.get(name, {}).get("requires", []):
                key = norm(req)
                # Only what's installed: a requirement whose marker excluded it here isn't used.
                if key not in depth and key in dists:
                    depth[key] = depth[name] + 1
                    via[key] = dists.get(name, {}).get("name", name)
                    shown[key] = req
                    nxt.append(key)
        frontier = nxt
    for key, d in depth.items():
        info = dists.get(key, {})
        credits.add(info.get("name", shown[key]), "python", d, info.get("version"), via.get(key))


# Node ------------------------------------------------------------------------------------------


def node_graph(credits: Credits) -> None:
    pkg = ROOT / "package.json"
    data = json.loads(pkg.read_text())
    for section in ("dependencies", "devDependencies"):
        for name, spec in sorted(data.get(section, {}).items()):
            credits.add(name, "node", 1, spec.lstrip("^~"), build=section == "devDependencies" or None)
    scripts = sorted(list((ROOT / "tool").rglob("*.mjs")) + list((ROOT / "tool").rglob("*.js")))
    third = set()
    for path in scripts:
        for spec in re.findall(r"""(?:from|import\(|require\()\s*['"]([^'"]+)['"]""", path.read_text(errors="ignore")):
            if spec.startswith((".", "/", "node:")) or not re.fullmatch(r"(@[a-z0-9~][a-z0-9._~-]*/)?[a-z0-9~][a-z0-9._~-]*(/[\w./-]*)?", spec):
                continue
            third.add(spec.split("/")[0] if not spec.startswith("@") else "/".join(spec.split("/")[:2]))
    for name in sorted(third):
        credits.add(name, "node", 1)
    credits.source("Node scripts and package.json", "package.json, tool/**/*.mjs", True,
                   f"{len(scripts)} scripts, {len(third)} third-party imports")


# Models and engines ----------------------------------------------------------------------------


def provenance(credits: Credits) -> str | None:
    files = sorted((ROOT / "tool").rglob("*.provenance.json"))
    audio = CACHE / "kumbia-audio"
    if audio.exists():
        files += sorted(audio.rglob("*.provenance.json"))[:200]
    comfy = None
    repos: dict[str, dict] = {}
    for path in files:
        try:
            data = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        engine = data.get("engine") or {}
        if engine.get("name") == "comfyui":
            comfy = engine.get("ref") or comfy
            for node in engine.get("nodes", []):
                credits.add(node["name"], "tool", 2, (node.get("commit") or "")[:7] or None, "ComfyUI")
        for model in data.get("models", []):
            repo = model.get("repo")
            if repo:
                repos.setdefault(repo, model)
    for repo, model in sorted(repos.items()):
        credits.add(repo, "model", 1, (model.get("revision") or "")[:7] or None,
                    licence=model.get("licence"))
    credits.source("Model and engine provenance", "tool/**/*.provenance.json, ~/.cache/tillandsias-project/kumbia-audio",
                   bool(files), f"{len(files)} records, {len(repos)} model repositories")
    return comfy


# Tool versions ---------------------------------------------------------------------------------


def run_version(cmd: list[str], pattern: str) -> str | None:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    m = re.search(pattern, out)
    return m.group(1) if m else None


def tool_versions(dart_tool: Path, comfy: str | None, dists: dict) -> dict[str, str | None]:
    flutter = (dart_tool / "version").read_text().strip() if (dart_tool / "version").exists() else None
    dart = None
    for candidate in (CACHE / "dart/dart-sdk/version",):
        if candidate.exists():
            dart = candidate.read_text().strip()
    vision = None
    vpy = ROOT / "tool/metrics/vision.py"
    if vpy.exists():
        m = re.search(r'"(qwen2\.5vl:[^"]+)"', vpy.read_text())
        vision = m.group(1).split(":")[1] if m else None
    return {
        "flutter": flutter,
        "dart": dart,
        "provenance": comfy,
        "vision": vision,
        "ffmpeg": run_version(["ffmpeg", "-version"], r"ffmpeg version (\S+)"),
        "bpy": (dists.get("bpy") or {}).get("version"),
        "uv": run_version(["uv", "--version"], r"uv (\S+)"),
        "python": f"{sys.version_info.major}.{sys.version_info.minor}",
        "node": run_version(["node", "--version"], r"v(\S+)"),
        "rust": run_version(["rustc", "--version"], r"rustc (\S+)"),
    }


# ------------------------------------------------------------------------------------------------

KIND_ORDER = ["platform", "tool", "model", "font", "dart", "rust", "python", "node"]


def build(dart_tool: Path) -> dict:
    base = json.loads((ROOT / "tool/credits/base.json").read_text())
    credits = Credits()
    dart_graph(credits, dart_tool)
    rust_graph(credits)
    python_graph(credits)
    node_graph(credits)
    comfy = provenance(credits)
    dists = venv_packages(Credits())
    versions = tool_versions(dart_tool, comfy, dists)
    for item in base["items"]:
        item = dict(item)
        source = item.pop("versionFrom", None)
        version = item.pop("version", None)
        if source and versions.get(source):
            version = versions[source]
        credits.add(item.pop("name"), item.pop("kind"), item.pop("degree"), version, item.pop("via", None), **item)
    items = sorted(
        credits.items.values(),
        key=lambda i: (i["degree"], KIND_ORDER.index(i["kind"]) if i["kind"] in KIND_ORDER else 99, i["name"].lower()),
    )
    counts: dict[str, int] = {}
    for i in items:
        label = str(min(i["degree"], 3)) + ("+" if i["degree"] >= 3 else "")
        counts[label] = counts.get(label, 0) + 1
    return {
        "schema": "kumbia.credits/v1",
        "generatedBy": "tool/credits/build_credits.py",
        "header": base["header"],
        "music": base["music"],
        "counts": dict(sorted(counts.items())),
        "items": items,
        "sources": credits.sources,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--dart-tool", type=Path, default=ROOT / ".dart_tool",
                        help="the .dart_tool folder that holds package_graph.json")
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument("--check", action="store_true", help="exit 1 if --out differs, write nothing")
    args = parser.parse_args()
    text = json.dumps(build(args.dart_tool), indent=1, ensure_ascii=False) + "\n"
    if args.check:
        same = args.out.exists() and args.out.read_text() == text
        print("credits up to date" if same else f"{rel(args.out)} is stale: run {Path(__file__).name}")
        return 0 if same else 1
    args.out.write_text(text)
    data = json.loads(text)
    print(f"wrote {rel(args.out)}: {len(data['items'])} items, by degree {data['counts']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
