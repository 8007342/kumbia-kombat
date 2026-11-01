# Asset pipeline requirements (Kumbia Kombat → forge image pipeline)

Status: consumer requirements, 2026-11-01. Audience: the Tillandsias forge
team designing the ComfyUI surface (design row `1935-k2ib`, owner
calmecacpilli; coordinator macuahuitl-fedora; studio/models work in
demon_attack-forge). Kumbia is the first heavy consumer: it needs hundreds of
identity-locked, pose-controlled, pixel-finished dance frames, not single
illustrations.

Companion documents in this repo:

- `plan/asset-inventory-contract.md` — every clip/pose the game needs, the
  manifest schema the runtime actually parses, recolor-ramp constraints.
- `plan/generative-animation-research.md` — sourced research on identity
  lock, pose control, mocap sourcing, pixel finishing and licences.
- `plan/dance-fluidity-pass.md`, `plan/opponent-depth-staging-pass.md` — the
  animation doctrine and the blocked Gatekeeper v3 / Mācron travel v2 pass.
- `assets/art/STYLEGUIDE.md` — perspective, crowd budgets, palette rules.
- Unmerged `origin/work/2610-pipe`: `plan/sprite-generation-pipeline.md`
  (immutable `art_runs/<run-id>/{inputs,raw,processed,review,run.json}`,
  run-manifest fields, five generation stages, first proof = one challenger
  four-to-eight-key cumbia phrase) and `plan/animation-research-register.md`.
  This document is the forge-facing summary; that plan remains the
  project-side procedure and should merge alongside it.

## Findings from the inventory that shape the pipeline

- Runtime only reads `party/manifest.json` and `ensemble/manifest.json`; a
  missing frame ID or PNG size mismatch fails the whole scene. Extra manifest
  keys are ignored, so the pipeline may emit planned fields now.
- On-screen size comes from floor projection ÷ a reference frame's height, so
  each sheet needs exactly one scale and one `pixelsPerUnit`.
- Mācron renders ~63 px tall in the garden and ~110 px in the bar at 360×640.
  A single 32×40 native grid cannot land on whole-number scales in both rooms.
  **Owner decision 2026-11-01: native pixel size is per room.** Rooms may also
  use different camera treatments (see Owner decisions below).
- Memory: the current 1.5-megapixel contact sheets decode to ~6 MiB each
  (~54 MiB loaded, ~72 MiB more for outfit variants) against a 16 MiB plan.
  Deliver tightly packed native-resolution atlases.
- Current PNGs have body alpha 251–253 and 9–12% fringe pixels; target is
  binary alpha.
- Mācron is never mirrored (single-arm cuff); the pipeline must not use mirror
  symmetry for him.
- Replacing guest art requires updating `test/outfit_palette_test.dart` pixel
  fixtures and the ensemble frame-count tests.

## Forge sources read (trunk `551f69d`, 2026-11-01)

- `openspec/changes/local-image-generation/{proposal,design}.md` (not yet
  archived into `openspec/specs/local-image-generation`; that path did not
  resolve on trunk at this date).
- `images/imagegen/tiers.tsv`: I0 SDXS-512, I1 SDXL-Lightning-4step
  (openrail++), I2/I3 FLUX.1-schnell Q4/Q8 GGUF (apache-2.0).
- Coordinator message 2026-11-01: RTX A5000 24 GB host; forges currently cap
  at I1 until fix #679; ComfyUI studio = sibling container on :8188, read-only
  model cache, no egress, not yet on trunk; LoRA training "in the design";
  file I/O and a `comfy.run_workflow`-style tool are undecided (`1935-k2ib`).

What that means for us today: `image.generate` is text-to-image only. It has
no reference image, ControlNet, img2img, inpaint or LoRA input, and output in
`/work/tmp/imagegen/` is deleted at forge teardown. That is enough for
backgrounds and concept boards; it cannot produce animation frames that hold
identity and pose. Everything below R1–R4 depends on the ComfyUI surface.

## Why Kumbia needs more than text-to-image

Current sheets (`assets/art/party/macron-dance-v1.png`,
`assets/art/ensemble/gatekeeper-v2.png`) were generated as whole 4×4 / 5×4
grids. Observed defects: per-cell scale and proportion drift, a missing pose
replaced by a duplicate, reversed side views faking a 360° turn, cells whose
bounds overlap (the lost Gatekeeper v3 had to drop 6 of 56 drawings), no
support-foot continuity between neighbouring drawings, and anti-aliased
"pixel-ish" edges rather than a native grid. Our doctrine forbids hiding this
with blur, crossfades or optical-flow inbetweens; the frames themselves must
be right.

## Requirements

Priority: **P0** blocks the next playable pass; **P1** blocks crowd scale-up;
**P2** improves throughput.

### R1 — Headless workflow execution from a forge (P0)

- An MCP tool (proposed `comfy.run_workflow`) taking: a workflow JSON in
  ComfyUI API format committed in *our* repo (`tool/art/workflows/*.json`),
  named input files (pose/depth/reference PNGs from our repo), and parameter
  overrides (seed, prompt, strength). Returns output paths + provenance; no
  base64, matching the `1871-47ex` result schema.
- Inputs travel forge → studio by path (shared mount like
  `/work/tmp/imagegen/`), not by agent tokens.
- Batch: one call may enqueue N jobs (e.g. 16 poses × 1 seed) and report
  progress; jobs are deterministic for the same workflow + inputs + seed +
  model hashes.
- Without this, every frame costs an interactive agent turn, which is exactly
  what exhausted session limits on 2026-10-28.

### R2 — Pose / structure control (P0)

- Humans (opponents, guests): OpenPose/DWPose skeleton control on the active
  base (SDXL: xinsir OpenPose SDXL — pending operator licence approval).
- Mācron is a toy robot with a big screen-face head, short limbs and an
  antenna; human OpenPose skeletons do not fit him. Needs depth and/or
  lineart/silhouette control from a puppet we render (Depth-Anything-V2-Small
  pending approval; a lineart/canny ControlNet with a shippable licence).
- We will author the control images ourselves from beat-timed choreography
  (see R8); the pipeline only has to accept them.
- Control must work together with R3 identity conditioning in one workflow.

### R3 — Identity lock per character (P0)

- Reference-image conditioning (IP-Adapter, Apache-2.0, non-InsightFace
  variants) so a single approved "model sheet" drives every frame.
- Character LoRA training (P1) from 15–40 approved frames per character, on
  a base whose licence permits it. Characters: Mācron, Gatekeeper,
  Bartender, three more opponents, Tlatoāni; guest silhouettes share a style
  LoRA rather than one each.
- Edit-model alternative: if Qwen-Image-Edit / FLUX.2-klein are approved,
  "same character, new pose" editing from a reference is acceptable as long
  as R2 control is honoured.

### R4 — Sheet and frame contract (P0)

- Prefer **one frame per image** at a fixed canvas (e.g. 512×640 or 768×960)
  with the character's ground contact at a fixed baseline and fixed scale
  across the batch. Grids are acceptable only if the workflow guarantees
  non-overlapping cells.
- Transparent background: BiRefNet / BEN2 / rembg (u2net) — never RMBG-1.4/2.0.
- Output PNGs with alpha; metadata sidecar per frame (see R7).

### R5 — Deterministic pixel finish (P0, can run in our repo)

- Downscale to the native grid (planned 48×64 for adult opponents, Mācron at
  .35 adult stature), nearest-neighbour or k-centroid; palette quantize to a
  locked per-character palette; 1px outline cleanup; alpha threshold (no
  semi-transparent fringe).
- Preserve the reserved plum/pink cloth ramp used for runtime outfit recolor
  (exact values and tolerances in `asset-inventory-contract.md` §2;
  `lib/gameplay/outfit_palette.dart`). Skin, hair, face must never fall inside
  that ramp.
- We can implement this as a repo script (`tool/art/`) if the studio does not
  ship a node; a studio node is welcome but not required.

### R6 — Crowd variation at scale (P1)

- Combinatorial batches: silhouette × body type × hair × skin × outfit ×
  accessory, each producing the same clip set (seated idle, notice, follow,
  stand-up 4, standing idle, step-touch, clap with visible contact, cheer,
  sit-down 4). Seed-addressable so a guest can be regenerated.
- Budget target: 12 guests per room × 5 rooms with shared silhouettes and
  palette swaps; memory budget is measured on phones before expanding.

### R7 — Provenance and durability (P0)

Per output frame: workflow JSON (or its hash + committed path), every model,
LoRA, ControlNet and adapter file with sha256 and licence, seed, prompt,
negative prompt, control/reference input hashes, engine version, timestamp.
We commit selected outputs plus this record into `assets/art/**/provenance.json`.
Because `/work/tmp/imagegen/` is ephemeral, the tool result should say so and
we copy immediately.

### R8 — Motion sources (P1, our side, needs licence review)

Realistic dance motion comes from choreography, not from the image model.
We will author pose keys from beat-timed choreography (`challenger_choreography.dart`,
the 24-beat cinematic exchange) and optionally from CC-licensed motion capture
retargeted to simple rigs, rendered to OpenPose/depth images per key and
breakdown. Candidate mocap sources and their licences are assessed in
`generative-animation-research.md`; none is adopted until its licence is
confirmed for a shippable game.

### R9 — Studio review surface (P1)

For a human art director (the owner) and agents:

- Flipbook of a clip at a given BPM with beat-relative holds (from our
  `durationBeats`/`events`), nearest-neighbour zoom at 1×/4×, onion skin of
  previous/next drawing, and a ground-line overlay to catch foot sliding.
- Side-by-side view of the control image and the result.
- Per-frame accept / reject / regenerate-with-new-seed; pivot/anchor nudge.
- Export the accepted set to our manifest JSON (`rect`, `anchor`,
  `pixelsPerUnit`, plus planned `facing`, `loop`, `durationBeats`, `events`,
  `status`, `provenance`) — schema in `asset-inventory-contract.md` §1.

### R10 — Video models (P2, optional)

Pose-driven video models could propose breakdowns between our keys, but we
would select individual frames and re-finish them; we never ship raw
interpolated sequences. Only relevant if a shippable-licence model fits 24 GB.

## Production order once R1–R5 exist

1. Regenerate the two lost sheets from `opponent-depth-staging-pass.md`:
   Gatekeeper v3 (64 drawings) and Mācron travel v2 (16 drawings), as
   per-frame jobs with control images.
2. Mācron pilot inventory (`dance-fluidity-pass.md`): grounded groove,
   four limb chains, dedicated left-hand peak, eight real turn views, social
   clips.
3. Bartender adaptation of the opponent target.
4. Crowd v3 via R6, then remaining rooms' backgrounds (text-to-image is enough
   there; parallax layers need inpaint/outpaint).

## Acceptance for the pipeline (from our side)

- 16 consecutive Mācron frames from one workflow pass a native-size review:
  same head size ±1 px, antenna and face screen intact, ground contact on the
  baseline, no duplicate/mirrored fake views.
- A Gatekeeper limb chain (prep → peak → follow → return) keeps the support
  foot planted within 1 native pixel.
- Re-running a committed workflow with the recorded seed and model hashes
  reproduces the frame bit-exactly or within a documented tolerance.
- Every model in the run is on the shippable licence list.

## Convergence with demon_attack's project-local pipeline

demon_attack-forge reported (2026-11-01; branch
`research/local-image-large-models`, not yet pushed, so not cited by path) a
`tools/asset_pipeline/pipeline.py` with `families/<name>.json` specs and
stages plan → generate → ingest → process → review → accept → pack. Its
`process` stage (OKLab matte + Otsu, crop, BOX downscale into a fixed slot,
OKLab palette snap, binary alpha, despeckle, 1px outline, QA gates) already
covers most of R5, and `pack` refuses atlases without human acceptance.

Agreed direction: one shared contract instead of per-project clients —
**family spec JSON + queue/results JSON + provenance schema** — generalised
for Kumbia with:

- `cells[]` with fixed `baseline`/`pivot` per frame (ground contact), and
  constant scale per character across a batch;
- `poses[]` naming clip + drawing + control-image path (R2, R8);
- `reservedRamps[]` protected from palette snap (R5 recolor ramp);
- `references[]` for identity conditioning (R3);
- export to Kumbia's manifest (R9) as a pack target.

Generation runs against ComfyUI's HTTP API-format workflow JSON (:8188)
once the studio lands (drafts #791/#793/#794); until then only
`image.generate` text-to-image is available.

demon_attack's files are readable on GitHub (`8007342/demon_attack`, branch
`research/local-image-large-models`, head `bd3b89a`):
`tools/asset_pipeline/{pipeline.py,README.md,families/ship.json}` and
`plan/asset-pipeline/licence-review.md` (official-card licence table).
Its palette snap is `snap_to_palette()`; our recolor gates become a post-snap
QA check that needs a cloth/non-cloth region mask per pose (open problem:
segmentation vs. a mask rendered from our rig).

## Owner decisions (2026-11-01)

1. **Native pixel size per room.** Each room declares its own native grid.
   Characters that appear in several rooms (Mācron above all) keep one
   accepted high-resolution source set; the pixel finish runs once per room
   target, producing a per-room atlas. A family spec therefore carries
   `targets[]` per room rather than a single `frame.native`.
2. **Per-room perspective.** Rooms need not share the rear/three-quarter
   floor perspective. Level 4 (restroom dash, storyboard R01) is the candidate
   for a **side-on** level: actors move on a horizontal ground line with no
   floor-projection scaling. It needs true profile walk/dance views for Mācron
   and the restroom attendant, side-view backgrounds/parallax strips, and
   staging marks along one axis. The rig makes this a camera change, not new
   choreography.
3. **Motion source: Blender stand-ins, hand-keyed.** Cumbia is absent from
   every licensable mocap set, so pose keys are authored on simple Blender
   stand-in rigs (one per character silhouette, a non-human rig for Mācron)
   at beat-timed key and breakdown frames. They render the OpenPose,
   depth/lineart and flat-colour region-mask PNGs the contract expects.
   Filmed reference and mocap are deferred.
4. **Branching.** Mature work merges into `game`; partial work and drafts
   stay on `work/*` branches.

## Model approval request (Kumbia, for the operator)

All verified on official cards in demon_attack's `licence-review.md` or in
`generative-animation-research.md`. In priority order:

| # | File | Licence | Kumbia use |
|---|---|---|---|
| 1 | xinsir/controlnet-union-sdxl-1.0 | apache-2.0 | OpenPose for humans + depth/lineart for Mācron in one model |
| 2 | h94/IP-Adapter SDXL Plus (non-FaceID) | apache-2.0 (verify weights card) | Identity reference per character |
| 3 | LayerDiffusion/layerdiffusion-v1 `layer_xl_*` | creativeml-openrail-m | Native transparent SDXL output (cleaner alpha than matting) |
| 4 | ZhengPeng7/BiRefNet or PramaLLC/BEN2 | mit | Matte fallback |
| 5 | SDXL base 1.0 | openrail++ | Full-step base: Lightning's 4-step/CFG-0 regime may weaken ControlNet and IP-Adapter and ignores negatives — A/B before committing |
| 6 | nerijs/pixel-art-xl | creativeml-openrail-m | Pixel-art style LoRA for SDXL |
| 7 | Depth-Anything-V2-Small | apache-2.0 | Depth from reference art when no rig render exists |
| 8 | kohya-ss sd-scripts / ostris ai-toolkit | Apache-2.0 / MIT | Character LoRA training (later) |

Never: Depth-Anything-V2 Base/Large (cc-by-nc), any FLUX.1-dev ControlNet,
InsightFace-based FaceID/InstantID/PuLID, Zero123++ weights, RMBG.

## Open questions for `1935-k2ib`

1. Will ControlNet / IP-Adapter / img2img be exposed through the light
   `image.generate` (sd.cpp supports ControlNet and LoRA) before ComfyUI lands?
   That alone would unblock R2 for humans.
2. Exact I/O mount shared between forge and studio, and its lifetime.
3. Where trained LoRAs live (project repo vs model cache) and who approves them.
4. ~~Batch jobs without per-call consent?~~ Answered by the operator via the
   coordinator, 2026-11-01: approvals are standing (they expire per session or
   by time once enforcement exists), so batches at an approved tier need no
   per-call consent. Recorded on `1935-k2ib`. Each model/LoRA/ControlNet file
   still needs its own operator licence approval.

Q1 (ControlNet/LoRA inputs on `image.generate` via sd.cpp) is being filed by
the coordinator as its own small packet.

## Progress log

- 2026-11-01: contract `1935-k2ib/v0` committed on Tillandsias
  `work/1935-k2ib` @ `84236b088`
  (`plan/issues/comfyui-studio-family-contract-v0-2026-11-01.md`), with
  Kumbia's Gatekeeper family as the `character-frames` example.
- 2026-11-01: interim `image.generate` on Tillandsias `work/1954-gdi6` @
  `f3bab082b` accepts `control_net` + `control_image` (caller PNG under
  `/work/tmp/imagegen`, no detector) and `loras` with weights; results carry
  file sha256 + licence. One control image per call, no region masks. No
  ControlNet/LoRA pinned yet. Kumbia submitted pins for operator approval:
  - `xinsir/controlnet-openpose-sdxl-1.0` @ `23f966cd5cfdd3f7729c903e243d87152162d2b7`,
    `diffusion_pytorch_model.safetensors`, sha256 `b8524e557a7df60d081f5d4a0eb109967d107df217943bf88c2d99b9ebcc06c5` (apache-2.0)
  - `xinsir/controlnet-union-sdxl-1.0` @ `801a4a3fa3d4c936f4feea95b98607bc6726f80c`,
    `diffusion_pytorch_model_promax.safetensors`, sha256 `9fae2e50cb431bfcbe05822b59ec2228df545ef27f711dea8949e9f4ed9f7cdc` (apache-2.0; studio only)
  - `nerijs/pixel-art-xl` @ `8bf4a4d9ea283e00a51fafda8e0539f8248ea037`,
    `pixel-art-xl.safetensors`, sha256 `4234637cb80c998f41e348e6a6cb6bc20d8d038b2b0f256b6129b3b5e353eef7` (creativeml-openrail-m)
  - Open risk: sd.cpp may support ControlNet on SD1.5 only; verify on the pinned tag.
