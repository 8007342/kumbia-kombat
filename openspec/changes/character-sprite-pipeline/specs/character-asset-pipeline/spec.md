# Spec Delta

## Purpose

Turn declarative character and style definitions into reviewed in-game sprite
atlases, so that any character can be added or edited as data and only the frames
an edit affects are rebuilt.

## ADDED Requirements

### Requirement: Characters are declared as data

The pipeline SHALL build any character from a declarative definition covering body proportions, garments and props, colours, descriptive text, references, motion set and room targets. Adding a humanoid character or editing one SHALL NOT require changing pipeline code.

#### Scenario: second character on the same code path

- **GIVEN** a pipeline that has produced Gatekeeper
- **WHEN** a Bartender definition is added
- **THEN** the same commands SHALL render, generate, finish and pack Bartender with no change to pipeline code

#### Scenario: invalid definition

- **WHEN** a definition names an unknown garment, region, motion set or reference
- **THEN** the pipeline SHALL refuse it with a message naming the field, before any rendering or GPU work

### Requirement: Style is independent of characters

Art style SHALL be declared separately from characters and referenced by them. No style, reference sheet or earlier atlas SHALL be treated as a permanent target by pipeline code.

#### Scenario: changing the art direction

- **WHEN** a style definition is edited
- **THEN** impact analysis SHALL report every character that uses it as affected
- **AND** no character definition SHALL need editing

### Requirement: Impact analysis precedes generation

Before any GPU work, the pipeline SHALL report for an edit which frames are affected, the update mode chosen for each, which accepted frames would return to review, and the estimated image count. A dry run SHALL change nothing.

#### Scenario: previewing an edit

- **GIVEN** a definition edit that changes one garment's colour
- **WHEN** impact analysis runs
- **THEN** it SHALL list only frames in which that garment is visible
- **AND** no file outside the report SHALL change

### Requirement: Builds are incremental

Every stage output SHALL be identified by a hash of all its inputs. A rebuild SHALL reuse any output whose hash is unchanged, and an unchanged definition SHALL produce no new work.

#### Scenario: nothing changed

- **WHEN** a character is rebuilt with no change to its inputs
- **THEN** no images SHALL be generated and the packed atlas SHALL be byte-identical

#### Scenario: an interrupted run resumes

- **GIVEN** a run stopped after some frames completed
- **WHEN** it is started again
- **THEN** completed frames SHALL be reused and only the remainder generated

### Requirement: Edits use the least-work update mode

For each affected frame the pipeline SHALL choose the cheapest mode that can satisfy the edit: recolour for colour-only edits, masked regeneration for changes confined to known regions, and full regeneration otherwise. The caller SHALL be able to force a costlier mode.

#### Scenario: colour edit to an existing garment

- **WHEN** a garment's colour changes and its geometry does not
- **THEN** affected frames SHALL be updated by recolouring, with no GPU use
- **AND** pixels outside that garment's region SHALL stay byte-identical

#### Scenario: adding a garment

- **WHEN** a garment is added, such as a hat on a character without one
- **THEN** the rig SHALL be re-rendered and each frame regenerated only inside the changed region mask
- **AND** pixels outside that mask SHALL stay byte-identical before the pixel finish

### Requirement: Edits reach identity references

A character's identity references SHALL derive from its definition, so that an edit is not reverted by a stale reference. When an edit invalidates a reference, the reference SHALL be rebuilt and reviewed before dependent frames are regenerated.

#### Scenario: stale reference after a design edit

- **GIVEN** a character whose current reference shows no hat
- **WHEN** a hat is added and regeneration is requested
- **THEN** the pipeline SHALL rebuild the reference first and hold dependent frames until it is accepted

### Requirement: Backends are selectable at run time

The generation backend SHALL be chosen per run or per character by name, from any backend whose models are admitted by the studio. Selecting a backend SHALL NOT require pipeline code changes, and the backend SHALL be part of every generated frame's identity.

#### Scenario: switching backend

- **WHEN** the same character is built with a different backend
- **THEN** frames SHALL be generated afresh under that backend
- **AND** outputs of the earlier backend SHALL remain available for comparison

#### Scenario: model not admitted

- **WHEN** the selected backend needs a model the studio refuses
- **THEN** the pipeline SHALL stop before queuing further work and report the refusal verbatim

### Requirement: Candidate selection is measured and fails closed

Automatic candidate selection SHALL score each candidate's per-region colour against the definition and its structure against the rig. A scoring pass that produced no real measurements SHALL fail rather than select.

#### Scenario: scoring produced nothing

- **WHEN** identity scores are missing or identical across all candidates of a pose set
- **THEN** selection SHALL fail with an error and no selection file SHALL be written

#### Scenario: off-model colour

- **GIVEN** a candidate whose hat colour is far from the definition
- **WHEN** candidates for that pose are ranked
- **THEN** it SHALL rank below a candidate within tolerance

### Requirement: Human acceptance governs promotion

Generated frames SHALL remain candidates until accepted by a person. Accepted frames unaffected by an edit SHALL stay accepted, affected frames SHALL return to review, and only accepted sets SHALL be promotable to the runtime manifest.

#### Scenario: partial re-review

- **GIVEN** a fully accepted character
- **WHEN** an edit affects 10 of its frames
- **THEN** exactly those 10 frames SHALL return to review

#### Scenario: unaccepted promotion

- **WHEN** promotion is requested while any required frame is unaccepted
- **THEN** promotion SHALL be refused and name those frames

### Requirement: Output stays runtime compatible

A promoted atlas SHALL satisfy the runtime manifest contract, including every frame ID the game requires of that atlas, a matching image size, one scale per sheet and binary alpha. A set that would break the scene SHALL NOT be promoted.

#### Scenario: required frame IDs

- **WHEN** an opponent atlas of 64 drawings is promoted
- **THEN** all 20 challenger frame IDs SHALL resolve to drawings in that atlas

### Requirement: Output respects the outfit recolour gates

Colours of non-recolourable regions SHALL fail all reserved-ramp gates, so runtime outfit recolouring cannot alter them. A definition or edit that violates this SHALL be reported before generation.

#### Scenario: colour falls inside a gate

- **WHEN** an edit sets a skin, hair or hat colour that matches a reserved ramp gate
- **THEN** the pipeline SHALL refuse the edit and report the gate and colour, or apply a declared nudge and report the resulting colour

### Requirement: Frames are palette-aware

Every finished frame SHALL use only colours from declared per-region ramps, with no colour shared between ramps, so that any region can be recoloured from a table without regenerating art.

#### Scenario: ramp check

- **WHEN** a frame is finished
- **THEN** each opaque pixel SHALL belong to exactly one declared ramp
- **AND** frames with pixels outside any ramp allowed for their region SHALL be flagged for review

### Requirement: Characters declare named palette variants

A definition SHALL be able to declare named variants that override colours or garments. Colour-only variants SHALL be produced without GPU work and without a second atlas.

#### Scenario: replay variant

- **GIVEN** a definition with a colour-only variant `replay-1`
- **WHEN** that variant is built
- **THEN** the pipeline SHALL emit a colour table that, applied to the base atlas, reproduces the recoloured frames exactly
- **AND** no images SHALL be generated

### Requirement: Every frame is attributable

Each output frame SHALL record its definition and style hashes, backend, workflow hash, all model files with hash and licence, seed, prompts, control-input hashes and update mode. Only models the studio admits SHALL appear.

#### Scenario: tracing a frame

- **GIVEN** a frame in a candidate atlas
- **WHEN** its provenance is read
- **THEN** it SHALL resolve to the exact inputs, models and seed that produced it, including every earlier stage for a recoloured or masked frame
