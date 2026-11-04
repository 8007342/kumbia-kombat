# Tasks

## 1. Foundations (no GPU)

- [x] 1.1 Rebuild `~/.cache/kumbia-art` and `~/.cache/kumbia-bpy`, re-render Gatekeeper to a scratch dir, and verify `check_poses.py` passes and pose IDs match the committed `rig.json`
- [x] 1.2 Fix the inverted region map in `suggest.py` with OKLab ΔE scoring; verify with a test that a synthetic wrong-hat candidate ranks last and that uniform or missing scores abort (D9)
- [x] 1.3 Check whether `~/.cache/tillandsias-project` survives a forge restart (ask macuahuitl-fedora) and pick the cache root; document it in `tool/art/pipeline/README.md`

## 2. Definitions and compiler

- [x] 2.1 Write JSON Schemas for character, style and backend definitions with tests for valid files and for refusals naming the bad field
- [x] 2.2 Author `styles/party-pixel.json` and `characters/gatekeeper.json`, and verify both pass schema validation
- [x] 2.3 Implement the definition-to-family-spec compiler; verify `studio.validate_family` returns `ok` and pose IDs, count and order match the current spec
- [x] 2.4 Add the gate check for non-recolourable colours; verify with a test that an in-gate hat colour is refused with gate and colour named

## 3. Data-driven rig

- [x] 3.1 Move the 64 clips into motion set `opponent-64` with pronoun-neutral intent templates; verify Gatekeeper's `rig.json` joint data is unchanged apart from intended fixes
- [x] 3.2 Implement the parametric garment and prop library with dynamic regions; verify undeclared colours fail and every declared region renders on a sample pose
- [x] 3.3 Apply the baseline body fixes (head, forearms, mitten hands); verify `check_poses.py` passes and review the new contact sheet by eye
- [x] 3.4 Put Mācron behind the same interface; verify his rig output is unchanged by comparing `rig.json`
- [x] 3.5 Update `tool/art/rig/README.md` for definitions and verify its documented commands run as written

## 4. Stage graph and planner

- [x] 4.1 Implement the content-addressed stage runner; verify with tests that an unchanged rebuild does no work and an interrupted run resumes
- [x] 4.2 Implement `art plan`: definition diff to per-frame modes; verify with fixtures for colour-only, garment-added, body and style edits, and that a dry run changes no files
- [x] 4.3 Implement key-based selection state; verify an edit returns only affected frames to review
- [x] 4.4 Implement the recolour mode; verify pixels outside the region are byte-identical and no GPU tool is called
- [x] 4.5 Implement the masked mode's job planning (mask dilation, `$mask`, `$init_image`, `$strength`); verify generated job args against fixtures
- [x] 4.6 Implement per-region colour matching; verify a test frame's region medians move toward target colours while other regions stay unchanged
- [x] 4.7 Add aliases and rig-derived `facing` to `pack_atlas.py`; verify all 20 `challengerFrameIds` resolve with `test/ensemble_sprites_test.dart`'s rules
- [x] 4.8 Implement the ramp stage and flagging after `finish_pixels`; verify with a fixture that every opaque output pixel belongs to one ramp and that off-ramp pixels are reported (D13)
- [x] 4.9 Implement named variants: colour-only variants emit a ramp LUT and manifest `ramps`; verify applying the LUT to the base atlas equals the recoloured frames, byte for byte, with no GPU call
- [x] 4.10 Update `tool/art/pipeline/README.md` with the new stages and verify its commands run

- [x] 4.11 Add one `art build <character>` command chaining definitions, planner, stages and pack, so `plan_jobs.py` only queues what the planner selects; verify with a no-GPU fixture that an unchanged rebuild queues nothing and a colour edit queues nothing but recolours
- [x] 4.12 Make `secondaryMotion` real or refuse it: implement the one-drawing apron and shirt lag, and reject unsupported values by name; verify with a rig test comparing consecutive drawings

## 5. Backends and bake-off (needs studio)

- [x] 5.1 Confirm `studio.start` works and which pins are live; record exact basenames in the backend definitions, and verify by a one-image run per backend (2026-11-04: `studio.start` works; Lightning verified at 16 s including load; `sd_xl_base_1.0` and `animagine-xl-4.0` are refused `model_refused` by `run_workflow` although ComfyUI lists them under `sdxl-full/`; macuahuitl-fedora says the installed tray predates #903; the bare basenames in the backends are right and pass once the tray and studio image are rebuilt from linux-next. Stay on Lightning until its ping). 2026-11-04, after the restart: tray 56.11.4.2+d9475e5090f0dd53; all three backends ran `groove.down_l` at seed 930000 with no refusal, bare basenames confirmed; run `gk-bakeoff-20261104b`
- [x] 5.2 Generate workflows per backend × profile; verify files are deterministic, and that Lightning's real partial denoise uses steps above 4 (2026-11-04: `tool/art/workflows/<backend>/`, checked by `test_workflows.py`; Lightning is 6 of 7 steps, effective denoise 0.857; `character-frame-*` stay byte-identical for the baseline run)
- [x] 5.3 Test mask binding for `attn_mask` through `run_workflow` with one pose; record the result and choose D7's path (2026-11-04, Lightning, `groove.down_l`, seed 930000: LoadImage + ImageToMask into two chained `IPAdapterAdvanced` runs with no refusal; swapping the masks changes hat and trouser colours, so they take effect. D7's masked path is viable. Masks limited to the figure invent text along the bottom edge; a body mask covering everything but the head removed it on this one seed, so use that shape and re-check on more seeds. Thin grey frame bars remain in all masked runs and `crop_position` did not change them. Images in `art_runs/gk-bakeoff-20261104a/review/`)
- [x] 5.4 Run the D10 bake-off on three poses; deliver contact sheets and measured time per image, and record the owner's chosen default in the style definition (2026-11-04: 3 poses x 3 backends, one seed each, plus 4 more SDXL seeds of `left_hand.peak`, in `art_runs/gk-bakeoff-20261104b/review/`. Seconds per image including a model swap: SDXL base 16.2-21.5, Animagine 16.3-18.2, Lightning 9.3-12.7; SDXL batched without swaps 12.6. Owner chose SDXL base as the default on 2026-11-04, recorded in `styles/party-pixel.json`; Lightning stays selectable for previews)
- [x] 5.5 Compare BiRefNet with LayerDiffuse on the same poses; verify binary alpha and that floor shadows are gone, and record the choice (2026-11-04: BiRefNet runs in 3.2 s after a host fetch, one frame: floor shadow removed, peak alpha 25 in that band. Its alpha is soft, interior 254 with about 13,000 edge pixels between, so it needs a threshold; `finish_pixels` not yet run on it. LayerDiffuse, same pose and seed on Lightning: `LayeredDiffusionDecodeRGBA` crashes on ComfyUI v0.40, so use `LayeredDiffusionDecode` with core `JoinImageWithAlpha`, whose alpha comes out inverted and needs correcting. From the colour proxy at 0.857 denoise it gives no separation; from an empty latent the figure reaches about 239 alpha but the background stays near 115 and the floor shadow stays solid. BiRefNet leads provisionally; repeat LayerDiffuse on a full-step backend after the rebuild before recording the choice). 2026-11-04, SDXL base: BiRefNet on all three poses took 2.3-3.1 s each; `finish_pixels` at 96x120 gives alpha only 0 and 255, 22-24 colours, the same bottom row 111, and no floor shadow. LayerDiffuse from an empty latent, `groove.down_l` only, seed 930000: 18.6 s; corrected alpha is almost entirely opaque, so no separation, and the floor shadow is solid. `LayeredDiffusionDecodeRGBA` is now refused `node_not_pinned`, so the crash can't be retested. BiRefNet recommended; LayerDiffuse covered one pose, and the owner accepted BiRefNet on 2026-11-04

## 6. Gatekeeper proof

- [ ] 6.1 Build the model sheet reference through the pipeline and get owner acceptance
- [ ] 6.2 Generate `groove` + `left_hand` (12 drawings) with the winning backend, plus the head detail pass; deliver GIFs at game size for owner review (2026-11-04: 12 drawings, 4 candidates each, in `art_runs/gatekeeper-v3-20261104a`; picked by eye, not through `suggest.py`; GIFs at 150 ms per drawing, 100 BPM at 4 drawings per beat; head detail pass not run; owner review pending)
- [ ] 6.3 Apply review findings; run the full 64 drawings and verify all selection scores are real, with a candidate atlas and review gallery delivered

## 7. Bartender: the generality test

- [x] 7.1 Author `characters/bartender.json` only; verify no pipeline code changes are needed, as shown by the diff touching only definitions and shared library additions
- [x] 7.2 Resolve the plum gate question for apron and trousers with a palette check; record the decision (checked 2026-11-03: trousers clear, apron base hits `plum`; options in design D14, owner chose B on 2026-11-04: apron base `#762D51`, no nudge; `ok:family:bartender-v1`)
- [ ] 7.3 Render, check, and review contact sheet and clip GIFs; verify `check_poses.py` passes on her proportions, with any motion overrides recorded in her definition (machine checks pass 2026-11-03: 64 poses, 0 problems, `ok:family:bartender-v1`; owner approved her silhouette 2026-11-04; clip GIFs not separately reviewed)
- [ ] 7.4 Generate proof clips, then all 64 drawings; deliver a candidate `bartender` atlas and review gallery

## 8. Edit acceptance: "add a red hat"

- [ ] 8.1 Gatekeeper's hat to red: `art plan` reports recolour with no GPU; verify non-hat pixels are byte-identical and the atlas is rebuilt
- [ ] 8.2 Bartender gains a red hat (geometry added): verify the reference is rebuilt first, frames regenerate in masked mode, frames without visible change keep their keys, and seams pass owner review
- [ ] 8.3 Build a colour-only `replay-1` variant for Gatekeeper and Bartender; verify it needs no GPU and review both at game size
- [ ] 8.4 Revert both hat edits; verify cached outputs return with no new images generated
- [ ] 8.5 Update the `art-family` skill with the edit flow (D8); verify by following it end to end from a plain-language request

## 9. Integration

- [ ] 9.1 Promote owner-accepted atlases into `assets/art/ensemble/manifest.json`; verify `flutter analyze` and `flutter test` pass and both scenes render at native size in the preview
- [ ] 9.2 Run the optional Wan VACE groove bake-off if pinned (D11), and record whether it earns a place in the default path

## Workflow follow-up

- Merge mature work into `game` under discipline level 2.
- Archive the change after owner review, then sync the new spec.
- Open a separate change for the music score redesign.
