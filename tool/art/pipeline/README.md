# Character-frame pipeline

From a character definition to a reviewed in-game atlas, with every step scripted and every frame
traceable to its prompt, skeleton, sheet and seed. Contract: Tillandsias family spec `1935-k2ib/v1`.

```
tool/art/characters/<id>.json  (identity words, sheet, props, hand fixes, under `drawing`)
tool/art/backends/qwen-frame.json  (prompt templates, workflow, cost per job)
        │ art.py build <c> --dry-run [--prompts]     jobs, images, minutes; changes nothing
        ▼
art.py build <c> --run <run> ──▶ jobs.sheet.json, then jobs.json ; per-pose workflows ; inputs on the lane
        │ studio.run_workflow per job (MCP, GPU)     art.py accept-sheet after the owner approves a view
        ▼
collect_qwen.py ─▶ register_frames.py ─▶ character_check.py ─▶ score_frames.py ─▶ review by eye
        │ studio.finish_pixels (MCP): native grid, locked palette, binary alpha
        ▼
art.py ingest ─▶ art.py build ─▶ pack_atlas.py: atlas + .candidate.json
        │ human acceptance (requireHumanAcceptance)
        ▼
promote.py ──▶ merges the candidate atlas block into assets/art/ensemble/manifest.json
```

`.claude/skills/art-family/SKILL.md` is the step-by-step version.

## How a frame is planned

The rig gives Qwen only a skeleton, and the model sheet gives it the character.

- **Prompts are generated**, from the character's `drawing` and the pose's words in the same motion data as
  the skeleton. Each is baked into `art_runs/<run>/workflows/<pose>.api.json`, because the host's prompt
  override didn't reach this node (2001-stpr). Check a job with ComfyUI's `/history` if results look
  unrelated to the prompt.
- **Hand fixes are data.** `drawing.poseOverrides` rewrites a pose's words (say `why`) when they disagree with
  its skeleton, which otherwise draws both (A5). `drawing.skeletonOverrides` moves joints where the rig's
  wrists stop short, such as a clap or a hat brim. An override for an unknown pose is refused.
- **A long held prop lies where the pose says.** `drawing.cue` gives each clip or pose a line: planted on the floor through the wrist, or held along a direction, with `otherHand` to land the free wrist on it. The rig renders it as a mask (`cue-shaft`, `cue-butt`), and planning draws it into the skeleton as a white line, which Qwen followed in nearly every frame. Register with `--thin-prop`, so the body alone sets height and floor. A line drawn in by mistake shows as a thin white stroke: look for it. `tool/art/rig/cue_sheet.py` shows every pose's line before any GPU.
- **Props** carry a hand and clips. The prompt names the hand by picture side. Bartender's `wording: own-hand`
  only keeps her accepted run reproducible, so leave it out of anything new.
- **Accepted work costs nothing.** `drawing.accepted.run` names a run, and a pose whose generated prompt equals
  the one baked there counts as drawn. That compares prompts, not skeletons, so clear it after a rig edit.
- **The rig** renders when a character has none or its definition moved on from the last build. Without a build
  record the committed rig stands, so pass `--render-rig` after a body or garment edit. Rendering needs the bpy venv.
- **Keys** cover the prompt, sheet, skeleton, graph, seed and visible colours. One fix redraws one pose, and a
  colour edit recolours with no GPU. The route has no masked pass.

`art.py` dry-runs at 92 s a job and 4 images a job, from the backend file. Reproducibility:
`test_qwen_route.py` holds all 64 Bartender prompts, the job args and the graph equal to the accepted run.

## Review tools

- `cue_review.py`, `merge_runs.py` and `finish_run_picks.py` take a family with fixes from several runs to an atlas: gather the runs, read the sheets, write `{picks: {pose: seed}}` in `art_runs/<run>/picks.json`, then finish and pack. `promote.py --new` adds an atlas the manifest doesn't have. (`finish_picks.py` is a different tool: it bakes the medallion swing and the nod for the BlinBlin dancer.)

- `score_frames.py` only ranks candidates, and can't see an extra arm, a lost hand or a goatee, so look at every
  candidate. It rewrites `selection.json`, so run it before picking by eye. A knee looks for its `trousers`
  garment unless `drawing.score.knee` names others. It aborts, writing nothing, on missing poses (`--partial`
  allows them), a colour found in no candidate, or uniform scores.
- `character_check.py <c> --run <run> [--dir DIR]` compares build (central width over height) across the sheet,
  the frames and `drawing.buildReference`, and names missing clips. Advisory, and `--strict` exits 1. Calibrated
  on few frames: Gatekeeper v3 0.294 is flagged against sheet 0.396, the v4 pilot 0.363 and the Bartender's 0.221
  against 0.216 aren't. It reads an arm touching the body as body, so it compares poses only roughly.
- `mirror_half.py` builds a symmetric pose from one arm. Only the prompt-less Gatekeeper wave needed it; with real
  prompts the model draws two hands meeting by itself.

## Characters as data

`tool/art/characters/<id>.json`, `styles/<id>.json`, `backends/<id>.json` and `motion/<set>.json` are the authored
source. The family spec and palette are generated. Edit a definition, then:

```bash
PY=~/.cache/kumbia-art/bin/python
$PY tool/art/pipeline/art.py build gatekeeper --dry-run --prompts   # every frame's action; changes nothing
$PY tool/art/pipeline/art.py build gatekeeper --run <run>           # rig, spec, recolours, then the job lists or the atlas
$PY tool/art/pipeline/art.py build gatekeeper --sheet <png> --only clap  # a pilot on a candidate sheet
$PY tool/art/pipeline/art.py accept-sheet macron --view front --image <png>   # after the owner approves it
$PY tool/art/pipeline/art.py ingest gatekeeper --run <run>          # store the frames; build again to pack
$PY tool/art/pipeline/definitions.py character gatekeeper           # refusals name the field
$PY tool/art/pipeline/planner.py plan gatekeeper                    # impact of the edit vs HEAD; changes nothing
$PY tool/art/pipeline/planner.py plan-style party-pixel             # which characters a style edit reaches
$PY tool/art/pipeline/compile_family.py gatekeeper                  # family spec + palette
$PY tool/art/pipeline/ramps.py lut gatekeeper <variant>             # a colour-only variant's table
```

A new character is one file and one command: `art.py build tool/art/tests/fixtures/trial-dancer.json --dry-run
--prompts` needs no rig, Blender or GPU, and reports 65 jobs, 260 images and about 100 minutes. A new humanoid
needs no code, though a skirt has no rig shape yet (`waist-apron` stands in, and only silhouettes notice).

| Module | Stage |
|---|---|
| `art.py` | The whole chain: reuses stored frames, recolours without a GPU, and queues only what is left |
| `plan_qwen_frames.py` | Prompts, per-pose workflows, staging and job lists |
| `stages.py` | Content-addressed store; outputs keyed by the hash of their inputs. Root: `$KUMBIA_ART_CACHE`, else `~/.cache/tillandsias-project/kumbia-art` (a persistent per-project volume: it survives forge restarts, confirmed by macuahuitl-fedora 2026-11-03) |
| `planner.py` | Per-frame update mode and impact report. `art.py --dry-run` is the authority on what a Qwen run costs |
| `selection.py` | `{pose: {k, key, accepted}}`; a changed key returns just that frame to review |
| `colourmatch.py` | Per-region median match to the definition's colours, before the pixel finish |
| `ramps.py` | Snaps each finished pixel to one ramp its region allows, flags off-ramp pixels, and builds recolour tables |
| `pack_atlas.py` | Atlas plus 64 frames, 20 runtime aliases (`motion/<set>.json`), rig-derived `facing`, `ramps` and `variants` blocks |

Tests: `$PY -m unittest discover -s tool/art/tests`; renderer tests run with the bpy venv from inside that folder:
`~/.cache/kumbia-bpy/bin/python -m unittest test_rig`.

## Mācron

He's non-human, so his route has no OpenPose. `characters/macron.json` is `status: drawn`, and
`motion/macron-drawn.json` holds his clips. His rig stays for its pilot poses and plays no part here.

1. **Sheet.** Six views drawn from `front_idle` in his accepted atlas, for the owner to approve with `accept-sheet`.
2. **Pose.** A sheet view plus words, with one image and no second control. Chosen over a rendered rig silhouette
   because a mannequin gets copied (A4), and the probes drew him on model this way
   (`art_runs/level3-probes-20261105/sheets/cast-macron.png`). The fist, rear walk and sip wording come from them.
3. **Registration.** `register_frames.py --character macron`: every frame 720 canvas px tall on one floor point, or
   the pose's `heightScale`. `registration.json` gives the atlas's `pixelsPerUnit` (6.4865), so a standing frame
   matches `front_idle`'s 37 world units. The game then draws him at stature 0.35 (`garden_scene.dart` `_addHero`).
4. **Clips.** `fist_bump` 3, `gulp` 3, `rear34_walk` 4, `high_five` 3, and `signature_step`, reserved, with no poses
   until the salsa teacher's step arrives. 19 jobs, 76 images, about 29 minutes. `pilot` lists what to try first, for `--only`.

The plan is committed in `art_runs/macron-v1-planned/`, and a test holds it to the definition. To run it:
`art.py build macron --run <run>`, which stages inputs, then `studio.run_workflow` on `jobs.sheet.json`.

**Unproven until a GPU runs it:** whether a walk cycle holds together from words alone, the likeliest place for
touch-up (only single poses were probed); full-figure gulp and high five (the gulp probe was chest-up, and the
high five was never drawn); cuff side across views, which his current atlas doesn't keep on one arm either;
whether registration by height holds when a raised arm passes his antenna. The owner hasn't yet said whether the
probe views count as him.

**Not built:** finish and pack. `studio.finish_pixels` takes a family spec, and `drawn` characters have none, nor
a locked palette. Colours and a spec come once a reviewed wave exists.

**What the game needs (`lib/`, not changed here):**

- `party_sprites.dart`: `PartyAtlasDefinition` is one image, and `manifest.json`'s `atlases.hero` is the only source
  of his frames, read by `requireFrames(heroFrameIds)`. `pack_atlas.py` writes the ensemble manifest, which he doesn't
  read. So his clips need a second hero atlas, or a repack of `macron-dance-v1.png` that also holds them.
- `heroSpriteFrame` picks one frame from gameplay state, with no notion of a clip. Fist bump, gulp and high five need
  the beat-locked sequence player (engine audit, need 11). `rear34_walk` also needs a three-quarter `DepartureFacing`.
- `_addHero` scales from `front_idle` in the same atlas, so a second atlas needs its own reference or the
  `pixelsPerUnit` above. A fist bump needs a contact point (audit needs 12) and the signature step a level-brief field
  (need 21).

## The older SDXL route

`art.py build <c> --backend sdxl-base-1` still plans 64 poses and 256 images with `plan_jobs.py`, `collect.py` and the
multi-pass workflows. It made no accepted frames, so don't use it for new art. It has what Qwen doesn't: masked
regeneration (`masked.py`) and derived references (`art.py accept-reference`).

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
- On the SDXL route, `plan_jobs.py` appends each principle's `promptFragment`/`negativeFragment`
  to the pose prompt after the pose's plain-English `intent`. The Qwen route doesn't use these.
- `pack_atlas.py` writes the principles into every frame's provenance.

Add an authority by adding a source and a principle to the registry, then re-run
`sync_family.py`; nothing else changes.

## Control profiles (SDXL route)

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
copied to the art cache by `collect_qwen.py`, so run that during a wave.
