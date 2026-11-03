# Tasks

## 1. Foundations (no GPU)

- [ ] 1.1 Rebuild `~/.cache/kumbia-art` and `~/.cache/kumbia-bpy`, re-render Gatekeeper to a scratch dir, and verify `check_poses.py` passes and pose IDs match the committed `rig.json`
- [ ] 1.2 Fix the inverted region map in `suggest.py` with OKLab ΔE scoring; verify with a test that a synthetic wrong-hat candidate ranks last and that uniform or missing scores abort (D9)
- [ ] 1.3 Check whether `~/.cache/tillandsias-project` survives a forge restart (ask macuahuitl-fedora) and pick the cache root; document it in `tool/art/pipeline/README.md`

## 2. Definitions and compiler

- [ ] 2.1 Write JSON Schemas for character, style and backend definitions with tests for valid files and for refusals naming the bad field
- [ ] 2.2 Author `styles/party-pixel.json` and `characters/gatekeeper.json`, and verify both pass schema validation
- [ ] 2.3 Implement the definition-to-family-spec compiler; verify `studio.validate_family` returns `ok` and pose IDs, count and order match the current spec
- [ ] 2.4 Add the gate check for non-recolourable colours; verify with a test that an in-gate hat colour is refused with gate and colour named

## 3. Data-driven rig

- [ ] 3.1 Move the 64 clips into motion set `opponent-64` with pronoun-neutral intent templates; verify Gatekeeper's `rig.json` joint data is unchanged apart from intended fixes
- [ ] 3.2 Implement the parametric garment and prop library with dynamic regions; verify undeclared colours fail and every declared region renders on a sample pose
- [ ] 3.3 Apply the baseline body fixes (head, forearms, mitten hands); verify `check_poses.py` passes and review the new contact sheet by eye
- [ ] 3.4 Put Mācron behind the same interface; verify his rig output is unchanged by comparing `rig.json`
- [ ] 3.5 Update `tool/art/rig/README.md` for definitions and verify its documented commands run as written

## 4. Stage graph and planner

- [ ] 4.1 Implement the content-addressed stage runner; verify with tests that an unchanged rebuild does no work and an interrupted run resumes
- [ ] 4.2 Implement `art plan`: definition diff to per-frame modes; verify with fixtures for colour-only, garment-added, body and style edits, and that a dry run changes no files
- [ ] 4.3 Implement key-based selection state; verify an edit returns only affected frames to review
- [ ] 4.4 Implement the recolour mode; verify pixels outside the region are byte-identical and no GPU tool is called
- [ ] 4.5 Implement the masked mode's job planning (mask dilation, `$mask`, `$init_image`, `$strength`); verify generated job args against fixtures
- [ ] 4.6 Implement per-region colour matching; verify a test frame's region medians move toward target colours while other regions stay unchanged
- [ ] 4.7 Add aliases and rig-derived `facing` to `pack_atlas.py`; verify all 20 `challengerFrameIds` resolve with `test/ensemble_sprites_test.dart`'s rules
- [ ] 4.8 Update `tool/art/pipeline/README.md` with the new stages and verify its commands run

## 5. Backends and bake-off (needs studio)

- [ ] 5.1 Confirm `studio.start` works and which pins are live; record exact basenames in the backend definitions, and verify by a one-image run per backend
- [ ] 5.2 Generate workflows per backend × profile; verify files are deterministic, and that Lightning's real partial denoise uses steps above 4
- [ ] 5.3 Test mask binding for `attn_mask` through `run_workflow` with one pose; record the result and choose D7's path
- [ ] 5.4 Run the D10 bake-off on three poses; deliver contact sheets and measured time per image, and record the owner's chosen default in the style definition
- [ ] 5.5 Compare BiRefNet with LayerDiffuse on the same poses; verify binary alpha and that floor shadows are gone, and record the choice

## 6. Gatekeeper proof

- [ ] 6.1 Build the model sheet reference through the pipeline and get owner acceptance
- [ ] 6.2 Generate `groove` + `left_hand` (12 drawings) with the winning backend, plus the head detail pass; deliver GIFs at game size for owner review
- [ ] 6.3 Apply review findings; run the full 64 drawings and verify all selection scores are real, with a candidate atlas and review gallery delivered

## 7. Bartender: the generality test

- [ ] 7.1 Author `characters/bartender.json` only; verify no pipeline code changes are needed, as shown by the diff touching only definitions and shared library additions
- [ ] 7.2 Resolve the plum gate question for apron and trousers with a palette check; record the decision
- [ ] 7.3 Render, check, and review contact sheet and clip GIFs; verify `check_poses.py` passes on her proportions, with any motion overrides recorded in her definition
- [ ] 7.4 Generate proof clips, then all 64 drawings; deliver a candidate `bartender` atlas and review gallery

## 8. Edit acceptance: "add a red hat"

- [ ] 8.1 Gatekeeper's hat to red: `art plan` reports recolour with no GPU; verify non-hat pixels are byte-identical and the atlas is rebuilt
- [ ] 8.2 Bartender gains a red hat (geometry added): verify the reference is rebuilt first, frames regenerate in masked mode, frames without visible change keep their keys, and seams pass owner review
- [ ] 8.3 Revert both edits; verify cached outputs return with no new images generated
- [ ] 8.4 Update the `art-family` skill with the edit flow (D8); verify by following it end to end from a plain-language request

## 9. Integration

- [ ] 9.1 Promote owner-accepted atlases into `assets/art/ensemble/manifest.json`; verify `flutter analyze` and `flutter test` pass and both scenes render at native size in the preview
- [ ] 9.2 Run the optional Wan VACE groove bake-off if pinned (D11), and record whether it earns a place in the default path

## Workflow follow-up

- Merge mature work into `game` under discipline level 2.
- Archive the change after owner review, then sync the new spec.
- Open a separate change for the music score redesign.
