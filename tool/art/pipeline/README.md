# Character-frame pipeline

From a pose vocabulary to a reviewed in-game atlas, with every step scripted and
every frame traceable to its rig pose, workflow, seed and animation principles.
Contract: Tillandsias family spec `1935-k2ib/v1`.

```
tool/art/rig/poses.py ──standin.py──▶ art_runs/inputs/<family>/   pose/depth/lineart/regions, rig.json, poses.intent.json
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

## Environment

```bash
export UV_NATIVE_TLS=1
uv venv ~/.cache/kumbia-art && VIRTUAL_ENV=~/.cache/kumbia-art uv pip install pillow numpy jsonschema
# Blender rig: see tool/art/rig/README.md (~/.cache/kumbia-bpy)
```

`/work/tmp/imagegen/` is wiped on forge teardown; anything worth keeping is
copied into `art_runs/<run>/` by `collect.py`.
