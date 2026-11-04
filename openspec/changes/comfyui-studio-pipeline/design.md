# Design

## Context

Motivation is in proposal.md, and requirements are in the `comfyui-studio-pipeline` spec.
Evidence, links and confidence labels are in `plan/research/comfyui-production-2026-11.md`,
with recipes in `plan/comfyui-cheatsheet.md`. This design stays at the level of passes and
contracts: graph details belong to the workflows.

**Current graph.** One KSampler (SDXL base, `pixel-art-xl`, 28 steps, denoise 0.7) from a flat
rig proxy, OpenPose + depth + lineart controls and one IP-Adapter, then BiRefNet and a
deterministic reduction to 96x120 on a locked palette.

**What constrains the design.**

| Constraint | Effect |
|---|---|
| `run_workflow` overrides reach `$seed`, `$prompt`, `$negative_prompt`, and named image inputs | Per-frame numbers travel as images |
| Classes must be pinned, separately from `object_info` | Each new class gets a one-image proof first |
| No Impact Pack, KJNodes, UltimateSDUpscale, or upscale model | Detail passes use core nodes and rig masks |
| Face about 15 x 10-13 native, hat about 31 x 10-14 | Face can't be left to a sampler (measured) |
| 8x canvas: one native pixel is one latent cell, offset (0,0) | No upscale stage; no grid detection for SDXL |
| 12.6 s per SDXL image, 64 drawings x 4 candidates | About 54 minutes per pass, so later passes run on selected candidates only |

**Work in parallel.** Another agent is building `tool/art/studio/` and
`tool/art/workflows/studio/`, including a `frame-multipass` graph with base, shirt, hat, head
and matte passes. Its approach matches this design. Where the two differ, this design records
intent and the implementation's real findings take precedence, then this document is updated.

## Goals / Non-Goals

**Goals:** identity that holds across 64 drawings; workflows anyone can open, read and adjust;
passes that can be rerun and judged alone; decisions that can be traced to a source or a test.

**Non-Goals:** full automation of art judgement; a runtime compositor; replacing the stage
graph, definitions or review flow; LoRA training in this change; new packs in the default path.

## The pass sequence

Numbers are starting points. Sources and confidence are in the cheatsheet.

| # | Pass | When | Runs on | Output | Gate |
|---|---|---|---|---|---|
| P0 | Rig render, with painted proxy detail | Rig or garment change | CPU | Proxy, controls, region masks, part placement | `check_poses.py` |
| P1 | Model sheet | Character edit | GPU | Accepted head and outfit references | Human acceptance |
| P2 | Head parts (D5) | Model sheet change | GPU, then human | Native head-and-hat library | Human acceptance |
| P3 | Base frame | Per candidate | GPU, denoise 0.5-0.7 | Whole frame at 8x | Identity and grid scores |
| P4 | Region passes: hat, shirt | Selected candidates | GPU, masked, about 0.35 | Frame with exact pixels outside masks | Outside pixels identical |
| P5 | Head detail | Only if parts are rejected | GPU, cropped, 0.4-0.5 | Frame | Head variance gate |
| P6 | Edit repair | Flagged frames only | GPU, Qwen-Image-Edit-2511 | Frame | Silhouette IoU against rig |
| P7 | Matte | Every frame | GPU, brief | Binary alpha, clamped to the rig | No floor shadow; bounded edge area |
| P8 | Colour match | Every frame | CPU, `colourmatch.py` | Frame | Region ΔE |
| P9 | Pixel finish | Every frame | CPU, `finish_pixels`, `ramps.py` | 96x120 frame | Palette and alpha checks |
| P10 | Part composite and cleanup | Every frame | CPU | Final frame and layer data | Orphan count; clip review |
| P11 | Pack | Set accepted | CPU, `pack_atlas.py` | Atlas, manifest, layers | Human acceptance |

Colour and palette stay outside the sampler, because these steps are deterministic and they
already work on the rig's regions. Selection (D9 of `character-sprite-pipeline`) runs after P3,
so later passes are spent only on chosen candidates.

## Decisions

### D1. UI JSON is the source, API JSON is generated and checked

`tool/art/workflows/studio/<name>.json` is the source: what the owner opens and edits, with
layout and notes. `<name>.api.json` is generated from it, never hand-edited, and a check fails
if a fresh conversion differs. Converter output is compared with the frontend's own
`graphToPrompt`.

Why: API JSON loads without a layout, so it can't be the editable form (Comfy docs). Pixel
Studio shows this arrangement working on a similar scale. mor-o's API-only repo notes the cost
of the alternative.

Alternative, keep generating from `build_workflows.py`: rejected as the long-term source, as
nobody can tune it visually. Old workflows stay byte-identical so baseline runs reproduce.

### D2. A repeatable, two-way studio sync

A command pushes committed UI workflows into the studio's userdata (`POST /userdata/workflows%2F…`)
and pulls edited ones back so git shows the change. Push never silently destroys an operator's
unsaved edit: it refuses, or reports, when studio and repo differ from the last sync.

Open: whether userdata survives a studio restart. The sync makes that harmless, since a push
restores it. Verify and record.

### D3. Source graphs stay flat for now

Use groups and notes rather than subgraphs in committed sources. Subgraphs are attractive for
reuse, but our only evidence on API flattening is a community script, and Pixel Studio keeps its
own workflows flat for this reason. Revisit after one test against the frontend's real output,
including whether `$` titles survive flattening. Blueprints are fine for operator exploration.

### D4. Per-frame values travel as images; each pass has its own save node

Masks, references and crop positions are bound as images. Positions use a carrier image whose
size holds x and y, read by `GetImageSize` (`tool/art/studio/stage_parts.py`). If the host's
`$node:<id>.<input>` overrides land, this can simplify.

Each pass is individually saved and keyed, so a change reruns only what follows it. One graph
with several save nodes is fine for editing. If `run_workflow` returns just one save node's outputs,
as an old comment in `build_workflows.py` says, the pipeline runs passes as separate jobs: verify
this first. Denoise stays baked per workflow, since `$strength` can't share a KSampler with `$seed`.

### D5. Head-and-hat parts are composited at build time (test first)

A 15-pixel face isn't something a sampler holds steady, and it's what the owner sees first.

- **Buckets:** group frames by `head_turn`, `head_nod`, `head_side` and body yaw from `rig.json`.
  Expect on the order of 15 buckets; count before committing.
- **Authoring:** make each bucket from the model sheet at high resolution, reduce it to native,
  and have a person accept it, hand-correcting where worthwhile. Corrections stay in git.
- **Placement:** the rig gives each frame its head anchor, rounded to whole native pixels.
- **Clipping:** the part shows only inside that frame's visible head, hair and hat region. A hand in
  front stays in front, with no draw-order logic.
- **Hybrid order:** the base pass still draws the whole figure, so neck and shoulders stay coherent.

Interim step: paint a real face into the proxy. This costs little and helps whichever route wins.

**Expected to break** (reasoned, not observed): rotation can't be faked, so each tilt needs its own
drawing; heads may look pasted on, since they don't take the body's shading; 1-pixel anchor jumps can
read as jitter; neck seams need a look at game size.

**Decision rule:** run one clip at game size against the P5 route, and the owner decides. If parts lose,
P5 becomes the route, and masked overlays (D6) are unaffected.

Alternatives: per-frame head pass only (P5), rejected as the first choice since it leaves the variance
in place; FaceID, rejected (research section 2); AI decomposition of frames, rejected (D7).

### D6. Overlays and a layer manifest keep runtime composition open

The owner plans hats, gloves, chains and coats in a later pass. Each frame's layer data records
`{part, sourceKey, anchor, clip, order}` in the manifest beside the atlas. The atlas stays baked and the
game keeps working as it does, so this costs nothing at runtime today.

A garment added in masked mode gives its overlay directly: the changed pixels inside the rig's region
mask on the same canvas. Garments that change the silhouette, such as coats, stay whole-frame variants,
since mor-o reports that this case remains unsolved.

A runtime compositor needs its own change. It would need to justify itself by memory savings or a real
need for combinations, with a check that the shipped look doesn't change.

### D7. No AI layer decomposition

Qwen-Image-Layered, See-through and LayerDiffuse aren't part of this path. The rig already gives exact
per-frame region masks. These tools work on one high-resolution image, Qwen-Image-Layered isn't on disk,
and LayerDiffuse gave no useful separation in task 5.5. Reconsider only for concept art, such as splitting
an approved model sheet into parts.

### D8. Identity references

- Don't use `style and composition` on `IPAdapterAdvanced`: `weight_composition` is hidden and fixed at
  1.0. ControlNet carries the pose. Confirm against the installed source.
- Use two chained adapters, each with a square crop: head crop on the head mask, outfit crop on a mask
  covering everything but the head (task 5.3 found this shape avoids invented text, on one seed).
- Test `linear` against `style transfer` for both. This revises `character-sprite-pipeline` D7, which
  chose `style transfer` before these findings. Style-only is documented as not carrying content, which
  may be why pattern and face detail don't transfer.
- References come only from the accepted model sheet (P1).

### D9. Edit models are for sheets and repairs, not every frame

Qwen-Image-Edit-2511 is the model-sheet candidate and repair tool. FLUX.2 klein is the fast alternative.
Contract for any edit-model pass: input on a flat background at an integer upscale; output returned to the
frame's own grid and palette; silhouette checked against the rig. Pixel Studio's single-developer benchmark
is the only sprite-specific evidence, so a repair is accepted only by the same gates as any other frame.

40 steps per frame is the cost without a Lightning LoRA, which is the reason to run it only on flagged
frames.

### D10. Edges are cleaned deterministically

BiRefNet's alpha is soft, with about 13,000 edge pixels on the frame measured in task 5.5. Keep matte
pixels only inside a slightly dilated rig silhouette, then cut to binary. Move `finish.sample` to
`majority`: on our sample the centre pixel strays from its cell in up to 4.9% of foreground cells, so this
is a modest gain. Add orphan-pixel cleanup in the repo. PixelOE-style outline expansion is a trial, since it
would add a dependency that needs review.

Measure uniform-cell share per frame. On our sample it was 60-69% at denoise 0.56 and 36-46% at 0.7, so it
may serve as a free candidate score. Treat this as provisional until it's checked against owner picks.

### D11. Trials that stay out of the default path

- **Wan VACE:** the single D11 bake-off from `character-sprite-pipeline` stands. Our Wan 2.2 Fun files have
  no official template to copy, so settings need finding by test.
- **Character LoRA:** the likely next step after proof clips, using accepted frames and the model sheet.
  `TrainLoraNode` is a core class in our studio, which may remove the need for a trainer pack. Pinning and
  the owner's go-ahead are both open.
- **Fixed seed across a clip:** whether a shared seed reduces drift is untested and costs little to test.
  Our seed policy varies seed by pose today.

### D12. Keys extend the stage graph

Each pass gets a stage key, as in `character-sprite-pipeline` D4:

| Stage | Key covers |
|---|---|
| Model sheet | Sources, garments, style, workflow hash, seed |
| Head parts | Model sheet key, bucket, native size, palette, correction file hash |
| Base | Current generate key, plus reference key |
| Region pass | Base key, mask hash, region prompt, workflow hash |
| Edit repair | Upstream key, reference key, instruction, workflow hash |
| Matte | Upstream key, rig silhouette hash, clamp setting |
| Part composite | Finish key, part keys, anchor, clip mask hash |

A corrected head therefore re-composites without a GPU, and a changed model sheet invalidates what depends
on it, with the owner seeing the impact first.

### D13. Decisions carry their source

Each pass's settings record where they came from: tool default, template, or our test. Anything from a test
names its run. Workflow notes carry the same reason, so the graph explains itself in the studio. The
cheatsheet checks its class names against `object_info`.

## Risks / Trade-offs

- [Head parts look pasted on] → the one-clip test decides, and P5 is ready as the fallback.
- [Bucket count grows and approaches 64] → count before authoring; merge buckets, and use P5 for rare ones.
- [Nobody is available to hand-correct pixels] → parts can be accepted uncorrected, and corrections are
  optional. The cost is lower quality.
- [Multi-pass multiplies time] → later passes run on selected candidates only; measure per pass.
- [Masked passes leave seams] → composite in image space, feather and review at game size.
- [Region passes reintroduce drift] → compare before and after on the same scores, and drop a pass that
  doesn't earn its time.
- [A new class is refused] → one-image proof before building on it; report refusals verbatim, and don't
  work around them.
- [Studio edits and git diverge] → sync reports conflicts and API drift fails the check.
- [IP-Adapter pack is maintenance-only] → the plan uses stable features, and edit models and LoRA are the
  exit if ComfyUI moves on.
- [Evidence is thin] → every pass has a measured gate, and a pass stays only if it wins on our frames.

## Migration Plan

1. Keep `character-frame-*`, `<backend>/*` and earlier `art_runs/` unchanged as baselines.
2. Prove the IP-Adapter change and the painted proxy on the existing single pass, before adding passes, so
   each gain is measured alone.
3. Add passes one at a time, on the 12-drawing proof clip.
4. Decide on head parts from that clip.
5. Move `art.py` to the sequence once the clip is accepted, then run all 64.

Rollback: nothing changes at runtime until promotion, which is per atlas and reversible through git.

## Open Questions

- Does `run_workflow` return every save node's output in one graph?
- Does the installed IP-Adapter match upstream on the hidden composition weight?
- Which VAE does `sdxl_vae.safetensors` contain, and does swapping it improve edges? The LoRA card asks for a
  fixed VAE.
- Is the pixel LoRA harmful in upscaled crops?
- How many head buckets does `opponent-64` really need, for Gatekeeper and for Bartender?
- Who hand-corrects pixels, if anyone? This is for the owner.
- Does a head library still work if Bartender's hair moves, or does hair need its own part?
