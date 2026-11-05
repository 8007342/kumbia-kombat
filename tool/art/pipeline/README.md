# Character-frame pipeline

From a pose vocabulary to a reviewed in-game atlas, with every step scripted and
every frame traceable to its rig pose, workflow, seed and animation principles.
Contract: Tillandsias family spec `1935-k2ib/v1`.

```
tool/art/characters/<id>.json + tool/art/rig/poses.py ──standin.py──▶ art_runs/inputs/<family>/   pose/depth/lineart/regions, rig.json, poses.intent.json
                                         │ check_poses.py (grounding, crossings, clearance)
tool/art/references/animation-principles.json ─┐
tool/art/families/<family>.json ◀──sync_family.py──┘   poses[], phases, profiles, animationReferences
        │ studio.validate_family (MCP)
        ▼
plan_jobs.py ──▶ art_runs/<run>/jobs.json + run.json ; inputs staged on /work/tmp/imagegen/kumbia/<run>/in
        │ studio.run_workflow per job (MCP, GPU)  ── workflows: tool/art/workflows/character-frame-<profile>.api.json
        ▼
collect.py ──▶ art_runs/<run>/raw/<pose>/<k>.png + provenance ; studio.contact_sheet per clip (MCP)
        │ review: pick one candidate per pose -> art_runs/<run>/selection.json
        ▼
studio.finish_pixels (MCP) ──▶ art_runs/<run>/final/<pose>.png  (native grid, locked palette, binary alpha)
        ▼
pack_atlas.py ──▶ <target.out> atlas + .candidate.json (status: candidate)
        │ human acceptance (requireHumanAcceptance)
        ▼
promote: merge the candidate atlas block into assets/art/ensemble/manifest.json
```

## Sheet-driven frames (Qwen)

The rig gives Qwen only a skeleton, and the model sheet gives it the character:
`plan_qwen_frames.py` → `studio.run_workflow` per job → `collect_qwen.py` →
`register_frames.py` → `score_frames.py` → review → `studio.finish_pixels` → `pack_atlas.py`.

- `score_frames.py` only ranks candidates. It can't see an extra arm, a lost hand or a goatee, so
  look at every candidate. It also rewrites `selection.json`, so run it before picking by eye.
- Where the rig's wrists stop short (hands meant to reach a hat brim, or to meet in a clap), move
  them for the drawing in `art_runs/inputs/<family>/skeleton_overrides.json`.
- Each pose's prompt is baked into `art_runs/<run>/workflows/<pose>.api.json`, because the host's
  prompt override didn't reach this node (2001-stpr). Check a job with ComfyUI's `/history` if
  results look unrelated to the prompt.
- `mirror_half.py` builds a symmetric pose from one arm. Only the prompt-less Gatekeeper wave needed
  it; with real prompts the model draws two hands meeting by itself.

## Characters as data

`tool/art/characters/<id>.json`, `styles/<id>.json`, `backends/<id>.json` and
`motion/<set>.json` are the authored source. The family spec and palette are generated.
Edit a definition, then:

```bash
PY=~/.cache/kumbia-art/bin/python
$PY tool/art/pipeline/art.py build gatekeeper --dry-run         # every frame's action; changes nothing
$PY tool/art/pipeline/art.py build gatekeeper                   # rig, spec, recolours, then jobs.json or the atlas
#   run art_runs/<run>/jobs.json through studio.run_workflow, collect, select, finish into final/, then:
$PY tool/art/pipeline/art.py ingest gatekeeper --run <run>      # store the frames; build again to pack
$PY tool/art/pipeline/art.py accept-reference bartender --image <png>   # releases jobs a derived reference holds
$PY tool/art/pipeline/definitions.py character gatekeeper      # refusals name the field
$PY tool/art/pipeline/planner.py plan gatekeeper                # impact of the edit vs HEAD; changes nothing
$PY tool/art/pipeline/planner.py plan-style party-pixel         # which characters a style edit reaches
$PY tool/art/pipeline/compile_family.py gatekeeper              # family spec + palette (--backend <id> to switch)
$PY tool/art/pipeline/ramps.py lut gatekeeper <variant>         # a colour-only variant's table
```

| Module | Stage |
|---|---|
| `art.py` | The whole chain: reuses stored frames, recolours without a GPU, and queues only what is left |
| `stages.py` | Content-addressed store; outputs keyed by the hash of their inputs. Root: `$KUMBIA_ART_CACHE`, else `~/.cache/tillandsias-project/kumbia-art` (a persistent per-project volume: it survives forge restarts, confirmed by macuahuitl-fedora 2026-11-03) |
| `planner.py` | Per-frame update mode (`recolour`, `finish`, `masked`, `full`) and `frame_key`, which covers only what can show in that frame |
| `selection.py` | `{pose: {k, key, accepted}}`; a changed key returns just that frame to review |
| `masked.py` | Changed-region mask, masked job args, and the composite that keeps outside pixels byte-identical |
| `colourmatch.py` | Per-region median match to the definition's colours, before the pixel finish |
| `ramps.py` | Snaps each finished pixel to one ramp its region allows, flags off-ramp pixels, and builds recolour tables |
| `pack_atlas.py` | Atlas plus 64 frames, 20 runtime aliases (`motion/<set>.json`), rig-derived `facing`, `ramps` and `variants` blocks |

Tests: `$PY -m unittest discover -s tool/art/tests`; renderer tests run with the bpy venv
from inside that folder: `~/.cache/kumbia-bpy/bin/python -m unittest test_rig`.

## Where animation research enters

`tool/art/references/animation-principles.json` holds the authorities the team
has adopted (Disney's animation process and *The Illusion of Life*, Richard
Williams, Mariel Cartwright's GDC talk, SLYNYRD, Dead Cells, Ubisoft foot IK,
Simogo) as principles with phases, prompt fragments and rig checks.

- The **rig** applies them as geometry: contrapposto (`pelvis_roll`), planted
  support, no twinning, wrist clearance. `check_poses.py` enforces them.
- `sync_family.py` tags every pose with its `animationPrinciples` by phase and
  writes the spec's `animationReferences` (registry, research docs, principles
  and sources used).
- `plan_jobs.py` appends each principle's `promptFragment`/`negativeFragment`
  to the pose prompt after the pose's plain-English `intent`.
- `pack_atlas.py` writes the principles into every frame's provenance.

Add an authority by adding a source and a principle to the registry, then re-run
`sync_family.py`; nothing else changes.

## Control profiles

Overrides only reach `$seed`, `$prompt` and `$negative_prompt`, so control
strengths are baked per profile by `tool/art/workflows/build_workflows.py`
(`moderate`, `peak`, `overlap`, `turn`; values in `profiles.json`). The spec's
`generation.profileRules` pick a profile per clip/phase/pose. Model file names
live in `tool/art/workflows/models.json`.

## Studio workflows

Editable multi-pass graphs live in `tool/art/workflows/studio/`, with API files generated from them.
Editing, sync, conversion and headless runs: `tool/art/studio/README.md`.

## Environment

```bash
export UV_NATIVE_TLS=1
uv venv ~/.cache/kumbia-art && VIRTUAL_ENV=~/.cache/kumbia-art uv pip install pillow numpy jsonschema
# Blender rig: see tool/art/rig/README.md (~/.cache/kumbia-bpy)
```

`/work/tmp/imagegen/` is wiped on forge teardown; anything worth keeping is
copied into `art_runs/<run>/` by `collect.py`.
