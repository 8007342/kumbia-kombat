# Design: the credits roll

## Data

`tool/credits/build_credits.py`, standard library only, reads:

| Source | Gives | Degree |
|---|---|---|
| `tool/credits/base.json` | Tillandsias, Podman, Fedora 45; tools no lock names (Flutter, Dart, CanvasKit, ComfyUI, FFmpeg, Blender, uv, ollama, ...) | 0 for the base, as written for the rest |
| `pubspec.lock`, `.dart_tool/package_graph.json` (else the pub cache's pubspecs) | Dart packages and the graph | 1 for pubspec dependencies and dev dependencies, then the graph's depth |
| `tool/music/mixrs/Cargo.lock` | Rust crates | depth from `mixrs` |
| `tool/**/*.py` imports and `uv run --with`, the forge's venvs | Python distributions | 1 if imported, then Requires-Dist depth among installed ones |
| `package.json`, `tool/**/*.mjs` | Node packages | 1 |
| `tool/**/*.provenance.json`, audio provenance in the cache | model repositories, ComfyUI, its custom nodes | 1, nodes 2 |

Versions come from the locks, the venvs and the tools themselves when they can be run. What can't be
read is listed under `sources` instead of failing. Output is sorted and has no timestamp, so it only
changes when dependencies do, and `--check` says whether the committed file is stale.

## Page

One scroll view driven by a ticker at about 46 px/s, starting a screen below the top. Sizes: header
40, base 26, degree 1 at 18 in one column with its role under it, degree 2 at 12 in 2 or 3 columns,
degree 3 and deeper at 9 in 3 or 4 columns. A drag holds it. A frame's step is capped at 0.1 s so a
stall doesn't jump. Music is one looping `<audio>`, via the console's browser adapter; when the browser
holds the sound back (no tap yet), a speaker button asks for one.

## Placement

`GardenPage` starts an 8-second timer when the finishing conductor completes on the campaign's last
step, if the campaign has more than one level (a level played alone has no credits). The timer pushes
the page, which returns by itself 4 s after its end. `OTRA VUELTA` and dispose cancel the timer.
