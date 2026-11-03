# Tasks

## 1. Data model

- [ ] 1.1 Write shot and sequence schemas with tests that valid files pass and unknown characters, poses and props are refused by name
- [ ] 1.2 Add the beat-budget validator against `assets/music/manifest.json`; verify an over-long sequence fails, naming the overrun
- [ ] 1.3 Document shots in `plan/asset-inventory-contract.md` and list the `bar.outro` inventory; verify IDs match the shot files

## 2. Pipeline

- [ ] 2.1 Add closeup cameras and per-shot native sizes to the rig; verify a render's region masks and viewport crop by contact sheet
- [ ] 2.2 Add props (`oil-bottle`, `oil-glass`) and pour poses; verify `check_poses.py` runs with their exemptions recorded
- [ ] 2.3 Add per-region character keys and viewport visibility to the planner; verify the hat-on-face vs hands fixture from the spec
- [ ] 2.4 Add the shot target to the stage graph and pack step; verify an unchanged rebuild does no work

## 3. Pilot

- [ ] 3.1 Add the subset of a Mācron definition these shots need; verify his existing atlas is untouched
- [ ] 3.2 Generate `bar.outro`; deliver a flipbook at game speed and tempo for owner review
- [ ] 3.3 Verify the red-hat edit from `character-sprite-pipeline` task 8.2 rebuilds only in-frame shots, and that the `replay-1` variant applies with no GPU

## 4. Runtime

- [ ] 4.1 Implement a transport-driven shot player and verify with tests that judgments and cue timing are identical with cinematics on and off
- [ ] 4.2 Add reduced-motion cuts and skip; verify progress is identical after skip, interrupt and finish
- [ ] 4.3 Wire `bar.outro` into the bar exit; verify in the preview at phone size, then with owner review

## Workflow follow-up

- Plan the remaining room outros once the pilot is accepted.
