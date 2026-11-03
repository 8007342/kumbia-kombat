# Proposal

## Why

Levels should end in short storytelling transitions: a few sub-second views with
slight animation, such as the defeated Bartender pouring a glass of motor oil that
Mācron deliciously gulps before the next scene. These shots show the same
characters, so a design edit like "add a hat" must reach them as well as the dance
atlases, or the story would contradict the game.

## What Changes

- Add **shots as data**: each declares its beats, viewport, background, cast, poses,
  props and its reduced-motion fallback. Sequences chain shots into a transition.
- Reuse the character pipeline's rig, stage graph, backends, ramps and acceptance
  rather than building a second image path. Closeups add per-shot cameras and native
  sizes, and shot-specific poses and props.
- Make **shots dependents of characters**, so impact analysis of a character edit
  lists affected shots, and only shots where the edit is actually in frame.
- Pilot with the bar-to-crowd transition. Change the Bar acceptance action from a
  festive drink to the motor-oil pour.
- Define the manifest contract a later runtime player reads. Building that player is
  a follow-up task group here, gated on the pilot passing art review.

Out of scope: voice, baked captions (the spec keeps text in UI), and video-model
generation, which stays a possible backend role under `character-sprite-pipeline`.

## Capabilities

### New Capabilities

- `cinematic-shot-pipeline`: declaring short beat-timed shots as data and producing
  reviewed shot assets that follow character edits.

### Modified Capabilities

- `art-direction`: stage 2's acceptance action becomes the motor-oil pour.

## Impact

- **Depends on** `character-sprite-pipeline` (definitions, stage graph, planner,
  ramps) and on Mācron gaining a definition for his closeups.
- **Code:** new `tool/art/shots/`; camera and prop additions in `tool/art/rig/`;
  shot targets in the planner and pack step. Later, a `lib/gameplay` shot player.
- **Docs:** `plan/storyboard.md` B01 updated; `plan/asset-inventory-contract.md`
  gains the shot inventory.
