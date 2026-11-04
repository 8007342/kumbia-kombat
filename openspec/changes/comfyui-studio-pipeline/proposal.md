# Proposal

## Why

The owner has said we've been winging ComfyUI: one sampling pass per frame, then picking
from the outputs. Our samples show the result. Identity drifts between frames (shirt detail,
hat shade, faces, beards on some seeds), edges are messy, and small faces are weak.

Research (`plan/research/comfyui-production-2026-11.md`) points to specific causes. Our
IP-Adapter applies the reference's composition at a hidden 1.0, and its reference is a tall
crop that gets centre-cropped. The face is about 15 native pixels wide, which one pass can't
hold steady across 64 drawings. Workflows are also generated as API JSON, so nobody can open,
understand or adjust them in the studio.

The owner wants professional practice: several passes per image, several editing processes,
editable workflows, and references recorded in specs and cheatsheets.

## What Changes

- Make **committed, editable workflows** the source of truth: UI-format JSON that opens in the
  studio with its layout, from which the API JSON is generated and checked.
- Load workflows into the studio **repeatably**, and bring operator edits back to git.
- Replace the single pass with a **named sequence of passes per frame**, each with its own
  inputs, saved output, cache key and quality gate.
- Fix the **identity references**: no hidden composition weight, square crops, and separate
  head and outfit references on rig masks.
- Add an owner-accepted **model sheet** step, with Qwen-Image-Edit-2511 as a candidate maker.
- Add **head-and-hat parts**, as a tested option: a small native-resolution library composited
  into frames at build time, placed and clipped by the rig.
- Add an optional **edit-model repair pass** for frames that selection flags.
- Clamp the **matte** to the rig's silhouette, and add `majority` sampling and pixel cleanup
  to the finish.
- Record a **layer manifest** beside each atlas, so runtime composition stays possible
  without being required.

**Partial assets, stated plainly.** The findings support rigid head-and-hat parts and
rig-masked overlays. They don't support AI layer decomposition, or limb-level paper dolls at
96x120. Nothing demonstrates the head library on AI art at this size, so a one-clip test
decides whether it stays. See design D5.

Out of scope: a runtime compositor in Flutter, LoRA training (the owner is waiting for proof
clips), video generation in the default path, new node packs, and any change to `main`.

## Capabilities

### New Capabilities

- `comfyui-studio-pipeline`: editable committed workflows, repeatable studio loading, the
  per-frame pass sequence, identity references, parts and overlays, and each pass's quality
  gates.

### Modified Capabilities

None directly. `character-asset-pipeline`, proposed in `character-sprite-pipeline` and not yet
archived, is extended rather than replaced: its stage graph gains per-pass stages. Once this
change is accepted, `character-sprite-pipeline`'s design decisions D6 and D7 and tasks 6.x
should be read together with this design.

## Impact

- **Code:** `tool/art/studio/` and `tool/art/workflows/studio/`, which a parallel task is
  building now. `tool/art/pipeline/` for pass stages, parts, matte clamp and cleanup.
  `tool/art/rig/` for painted proxy detail and head buckets.
- **Definitions:** additive fields in `tool/art/characters/` and `tool/art/styles/`.
- **Assets:** candidate atlases and additive manifest keys. Promotion stays human-gated.
- **Runtime:** none. Extra manifest keys are already ignored.
- **Host:** pins for classes not yet run (`node_not_pinned` applies whatever `object_info`
  lists), including edit-model classes; optional licence review of a Lightning LoRA for 2511.
- **Depends on:** `character-sprite-pipeline`'s stage graph, masks, colour match and ramps.
