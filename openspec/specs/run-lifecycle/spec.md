# Run lifecycle and story

## Purpose

Keep short five-level runs recoverable across mobile interruptions and show a minimal visual story.

## Requirements

### Requirement: Five short fights tell the story through actions

The game SHALL use the following ordered route, with visually identifiable
challengers and environments. Names and timing budgets below are design
starting points to tune through playtests, not promises of achieved balance.

| Level | Place / visual objective | Respect | Clean budget |
|---|---|---|---|
| 1 | Mansion garden; friendly gatekeeper steps aside | Mojo | 60 s |
| 2 | Bar; bartender slides over a drink | Swag | 80 s |
| 3 | Cool crowd; circle opens for Mācron | Flow | 95 s |
| 4 | Restroom corridor; urgent shuffle, door opens | Nerve | 45 s |
| 5 | Velvet rope; host welcomes Mācron into VIP | Presence | 110 s |

Traversal, teaching, approval and final tableau SHALL fit inside the 5–8
minute clean-run target. Audio arrangement and challenge budgets must be
reconciled before tuning is accepted. Respites SHALL have no mandatory taps.
Fights are dance challenges, with no injury or humiliation.

#### Scenario: Final victory

WHEN all five fights have passed their full-complexity sustain challenges,
THEN the ranked timer stops on final approval, the camera closes on a high
five between Mācron and Tlatoāni, Tlatoāni says “Chingón”, and gestures toward
a seat beside him, Covi and the guests. Initial entry follows if eligible;
network delay SHALL not block the ending. Ending replay SHALL be skippable.

### Requirement: Resume safely without advancing unheard challenges

The game SHALL save a versioned local checkpoint on committed sequence
results, level transitions, manual pause and lifecycle hide events. A save
SHALL contain run ID, chart/score/rules versions, level, checkpoint phrase,
respect tier, failure streak, style ledger, elapsed timing metadata and
calibration. Writing only on unload is insufficient on mobile browsers.
A partially completed sequence restarts at its checkpoint, with its style
awards rolled back or deduplicated; reload cannot farm Pizazz.

#### Scenario: Audio is interrupted

WHEN the app hides, audio focus is lost, or the player pauses,
THEN input judgement and music scheduling stop, future voices are cancelled,
and a checkpoint persists. On return an explicit resume tap unlocks audio,
then a one-bar count-in re-establishes the audio clock before judgement.
No silent background notes are missed or scored.

#### Scenario: Process is killed

WHEN the player returns after termination,
THEN the last valid checkpoint is offered, with no automatic playback.
An incompatible/corrupt save gives a clear restart option without crashing.

### Requirement: Casual pause and global speedruns remain compatible

Local play SHALL display active play time. A competitive run SHALL use
server elapsed time from start to final approval, including pauses and
reloads; the ranked clock starts at first controllable gameplay, ends before
the victory cutscene, and excludes leaderboard entry. The app SHALL label
ranked elapsed time and explain this once before a ranked run. Offline runs
remain resumable and finish normally, but cannot enter the global table.

#### Scenario: Pausing a competitive run

WHEN the app is hidden for 30 seconds,
THEN gameplay waits safely but competitive elapsed time includes 30 seconds.
Resetting a level never resets either run timer or previously cleared levels.

### Requirement: Minimal motion barriers and dependable controls

The UI SHALL support reduced camera motion, independently adjustable music
and effects, a timing calibration flow, and shape-coded notes. Required
inputs SHALL never demand simultaneous touches or fast repeated swipes.
Portrait and safe areas SHALL work at 320–430 logical-pixel widths.
Camera motion SHALL not move the tap areas or timing targets.

#### Scenario: Reduced motion

WHEN reduced motion is enabled,
THEN musical feedback uses sprite poses, palette and restrained pulses;
spiral cue travel remains readable with a simplified direct-path alternative.
