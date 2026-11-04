# Spec Delta

## Purpose

Produce consistent character frames through committed, editable ComfyUI workflows and a
multi-pass sequence per frame, with each pass independently rerun, judged and traced to its
source, and keep composition from parts possible without requiring it at runtime.

## ADDED Requirements

### Requirement: Editable workflows are the source of truth

Each studio workflow SHALL be committed as a UI-format file that opens in the studio with its layout and explanatory notes. The API-format file used by `studio.run_workflow` SHALL be generated from it and SHALL NOT be edited by hand.

#### Scenario: opening a workflow

- **WHEN** the operator loads a committed workflow in the studio
- **THEN** all nodes, groups and notes SHALL appear with their layout and with no missing-node errors

#### Scenario: generated file drifts

- **GIVEN** a committed UI-format workflow and its API-format file
- **WHEN** the API file differs from a fresh conversion
- **THEN** the workflow check SHALL fail and name the file

#### Scenario: conversion matches the frontend

- **WHEN** a workflow is converted by the repository's converter
- **THEN** the result SHALL match a recording of the frontend's own conversion for that workflow, apart from documented differences

### Requirement: Studio loading is repeatable and two-way

A single command SHALL install every committed workflow into the studio. A second command SHALL bring operator edits back as a reviewable repository change, with the API file regenerated.

#### Scenario: fresh studio

- **GIVEN** a studio with no saved workflows
- **WHEN** the install command runs
- **THEN** every committed workflow SHALL be listed by the studio and open unchanged

#### Scenario: edit in the studio

- **WHEN** the operator saves a change in the studio and the pull command runs
- **THEN** the change SHALL appear as a repository diff, and the API file SHALL match the new source

#### Scenario: an install would overwrite unsynced edits

- **GIVEN** a workflow changed in the studio since the last sync
- **WHEN** the install command runs
- **THEN** it SHALL NOT replace that workflow silently and SHALL report the conflict

### Requirement: Runs accept per-frame values through bindable inputs only

Workflows SHALL take per-frame values through the studio's supported bindings: titled seed and prompt nodes, and named image inputs. A workflow SHALL NOT require editing per frame. New node classes SHALL be proven with a one-image `studio.run_workflow` run before a workflow depends on them, because `object_info` does not imply a class is permitted.

#### Scenario: crop position per pose

- **WHEN** a pass needs a per-pose crop position
- **THEN** that position SHALL reach the graph through a bound input, with the same committed workflow used for every pose

#### Scenario: class refused

- **WHEN** a run is refused `node_not_pinned`
- **THEN** the refusal SHALL be reported verbatim, and no guard SHALL be relaxed to continue

### Requirement: Frames are produced by a sequence of named passes

Frame generation SHALL be a declared sequence of passes. Each pass SHALL have named inputs, a separately saved output, its own cache key and a quality gate. Rerunning a pass SHALL reuse earlier outputs and rebuild only later ones.

#### Scenario: changing one pass

- **GIVEN** a frame with all passes cached
- **WHEN** the settings of a later pass change
- **THEN** earlier passes SHALL NOT rerun, and that pass and those after it SHALL

#### Scenario: inspecting a pass

- **WHEN** a person reviews a frame
- **THEN** each pass's output SHALL be available to view on its own

#### Scenario: a pass does not earn its place

- **WHEN** comparison on the proof clip shows a pass gives no improvement in the measures or the owner's review
- **THEN** that pass SHALL be disabled in the style or backend definition, with the result recorded

### Requirement: Later passes do not disturb unmasked pixels

A pass limited to a region SHALL leave all pixels outside its mask byte-identical to its input, by compositing in image space after decoding.

#### Scenario: hat pass

- **WHEN** a hat region pass completes
- **THEN** every pixel outside the dilated hat mask SHALL equal the input frame

### Requirement: Identity references are explicit and masked

Identity references SHALL come from an accepted model sheet. Head and outfit references SHALL be separate square crops, each limited by a rig-derived mask. Workflows SHALL NOT use an IP-Adapter weight type whose effective weights differ from the workflow's visible values.

#### Scenario: hidden composition weight

- **WHEN** a pose-frame workflow is checked
- **THEN** it SHALL be refused if `IPAdapterAdvanced` uses `style and composition`

#### Scenario: reference is out of date

- **GIVEN** an accepted model sheet
- **WHEN** a garment or colour edit changes it
- **THEN** frames depending on it SHALL be reported as stale, and the sheet SHALL need acceptance again before use

### Requirement: Edit models are bounded by the frame's grid and palette

A pass using an edit model SHALL take its input on a flat background at an integer upscale, and SHALL return its result to the frame's own native grid and locked palette. Its output SHALL meet the same gates as any other frame, plus a silhouette comparison with the rig.

#### Scenario: repairing a flagged frame

- **WHEN** selection flags a frame and the repair pass runs
- **THEN** the repaired frame SHALL be kept only if its silhouette and region scores pass, and otherwise the frame SHALL stay flagged for review

#### Scenario: transparent input

- **WHEN** a frame with transparency is prepared for an edit model
- **THEN** transparency SHALL be replaced with the flat background before the model sees it

### Requirement: Head-and-hat parts are evaluated before adoption

The pipeline SHALL support compositing an accepted native-resolution head-and-hat part into a frame, positioned and clipped by that frame's rig data. Adoption SHALL depend on an owner review of one clip at game size against the per-frame head pass. Partial assets SHALL be limited to rigid parts and rig-masked overlays. AI layer decomposition and limb-level parts SHALL NOT be part of the default path.

#### Scenario: hand in front of the head

- **GIVEN** a frame where a hand overlaps the hat
- **WHEN** the part is composited
- **THEN** only the frame's visible head, hair and hat pixels SHALL take the part, and the hand SHALL remain on top

#### Scenario: part corrected by hand

- **WHEN** a person corrects a head part and commits it
- **THEN** the frames using it SHALL be recomposited with no GPU work, and other frames SHALL keep their keys

#### Scenario: parts lose the review

- **WHEN** the owner prefers the per-frame head pass
- **THEN** that pass SHALL become the configured route with no change to the workflows of other passes

### Requirement: Layer data keeps runtime composition open

Packing SHALL be able to record, per frame, which parts formed it, with their anchor, clip reference and order. The baked atlas SHALL remain sufficient for the game, and existing runtime behaviour SHALL NOT depend on that data.

#### Scenario: current runtime

- **WHEN** a pack with layer data is loaded by the current game
- **THEN** rendering SHALL match the same atlas without it

#### Scenario: a later garment overlay

- **WHEN** an accessory is added in masked mode
- **THEN** its changed pixels within the rig's region mask SHALL be recordable as an overlay aligned to the base frame's canvas

### Requirement: Mattes are constrained by the rig

The final alpha SHALL be binary, and no opaque pixel SHALL fall outside the rig's silhouette dilated by a declared margin.

#### Scenario: stray matte pixels

- **WHEN** the matte includes a shadow or artefact outside the margin
- **THEN** those pixels SHALL be transparent in the final frame, and the count SHALL be recorded

### Requirement: Settings and practice carry their sources

Pass settings SHALL record whether each value comes from a tool default, an official template or a named test run. A project cheatsheet SHALL list recipes using verified node classes, and SHALL have a check that compares them to the studio's `object_info`.

#### Scenario: a value changes after a test

- **WHEN** a test changes a pass's value
- **THEN** the definition or workflow note SHALL name the run behind the new value

#### Scenario: a class disappears

- **WHEN** a studio upgrade removes a class named in the cheatsheet
- **THEN** the check SHALL print its name
