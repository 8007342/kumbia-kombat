# Proposal

## Why

The owner wants every character to dance, and wants a change such as "add a red
hat to character X" to run that character's pipeline and update every frame that
needs it. Today's pipeline is hard-wired to Gatekeeper (rig tables, one family
spec, a frozen reference sheet) and always regenerates whole sets, and its first
run showed quality defects with concrete causes (see design.md, Context). Art and
style are still being discovered, so nothing in the pipeline may assume a final
look.

## What Changes

- Add a declarative **character definition**: body, garments and props, colours,
  prompts, references, motion set and room targets. Adding or editing a character
  means editing data, not pipeline code.
- Add a separate **style definition** that characters reference, so the art
  direction can keep changing without editing each character.
- Compile definitions into the existing studio family spec (contract
  `1935-k2ib/v1`), which stays the interface to the Tillandsias studio.
- Make the pipeline an **incremental stage graph**: each output is keyed by the
  hash of its inputs, so an edit rebuilds only what it affects.
- Add **impact analysis**: before any GPU work, show which frames an edit touches,
  how each will be updated and what it will cost.
- Add **least-work update modes**: deterministic recolour, masked regeneration of
  only the changed regions, or full regeneration.
- Add **runtime-selectable backends** for checkpoints and model kinds, with no
  backend privileged in pipeline code.
- Raise quality: fix the identity picker, real partial denoise and working CFG on
  a full-step backend, masked per-region identity references, sturdier rig
  volumes, per-region colour matching, and a head detail pass.
- Prove generality with two characters on one code path: Gatekeeper, then
  Bartender (the level 2 opponent). Mācron's existing work stays as it is.

Out of scope: runtime gameplay changes, the music score redesign (a separate
change), LoRA training (no trainer exists; revisit after the proof clips), and
promoting art to `main`.

## Capabilities

### New Capabilities

- `character-asset-pipeline`: declaring characters and styles as data, and turning
  them into reviewed in-game atlases through incremental, attributable,
  backend-selectable generation.

### Modified Capabilities

None. `art-direction`'s asset-acceptance requirement already governs what this
pipeline must satisfy, and is unchanged.

## Impact

- **Code:** `tool/art/rig/`, `tool/art/pipeline/`, `tool/art/workflows/`,
  `tool/art/families/` (becomes generated), new `tool/art/characters/`,
  `tool/art/styles/` and `tool/art/backends/`. The `art-family` project skill.
- **Assets:** candidate atlases and manifest blocks for `gatekeeper` and
  `bartender`. Promotion stays human-gated.
- **Runtime:** none, as long as the 20 `challengerFrameIds` remain resolvable.
- **Dependencies on the Tillandsias host:** the `studio.start` fix (hardening
  matcher for #896), and pins for the operator-approved checkpoints (SDXL base 1.0,
  Animagine XL 4.0) and optional models (Qwen-Image-Edit-2511, FLUX.2 klein 4B,
  Wan 2.2 VACE Fun). The pipeline must run on whichever pins are live.
- **Branch:** based on `work/1832-gk64`, which has not merged into `game`.
