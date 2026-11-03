# Proposal

## Why

The owner wants one juicy prompt to be able to start a whole level: its opponent,
audience, room, music, chart, transitions and replay colours. The character, shot and
score pipelines now each take data, but nothing connects them, and two things a level
needs have no pipeline at all: room art with parallax, and charts. Levels 1 and 2 are
the current focus, so this proves the flow on them and leaves level 3 ready for its prompt.

## What Changes

- Add a **level prompt and level brief**: a prompt expands, once, into a committed,
  reviewable brief. Everything downstream reads the brief, never the prompt.
- Add **orchestration only**: the brief compiles into inputs for
  `character-sprite-pipeline`, `cinematic-shot-pipeline` and
  `score-composition-pipeline`, with one combined impact report and stage gates.
- Add **audience as character data**: shared silhouettes, wardrobes and archetype
  motion sets through the character pipeline, plus group formations.
- Add a **room art pipeline**: layered backgrounds, emissive mask, floor calibration,
  side strip and threshold strip, from data.
- Add **chart drafting**: candidate charts validated by rules and approved by playing them.
- Tie **music to character**: each level's brief states how its opponent's look shapes
  its music, over a dominantly Latin base.
- Keep **variants palette-only** for now, while leaving accessories possible later.
- Relax `dynamic-music`: scores must be dominantly Latin, not strictly cumbia percussion.
- Add a level 3 gap inventory and draft prompt in `plan/level-3-readiness.md`.

Out of scope: authoring or generating level 3 or later; replay mode itself; accessories.

## Capabilities

### New Capabilities

- `level-production-pipeline`: turning a level prompt into a reviewed brief and driving
  all asset pipelines from it, with combined impact analysis and gates.
- `room-art-pipeline`: producing layered, calibrated room backgrounds from definitions.

### Modified Capabilities

- `dynamic-music`: the score-identity scenario moves from cumbia percussion in every
  score to a dominantly Latin foundation with declared hints.

## Impact

- **Depends on** the three pipeline changes above, and on rig additions for groups.
- **Code:** new `tool/levels/`, `tool/art/rooms/`; `lib/gameplay` needs data-driven room
  wiring (`rooms.dart`, the hard-coded `garden_to_bar` in `garden_page.dart`, charts in
  `garden_session.dart`) before any third room can run.
- **Host:** generic facilities are recorded in `plan/forge-generic-services.md`.
