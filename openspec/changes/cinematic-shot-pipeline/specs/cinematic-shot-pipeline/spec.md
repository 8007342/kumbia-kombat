# Spec Delta

## Purpose

Produce short, beat-timed story shots from declarative data, using the same
characters as gameplay, so that a character edit updates every shot it affects.

## ADDED Requirements

### Requirement: Shots are declared as data

Each shot SHALL declare its duration in beats, viewport, background, cast, drawings and props. Creating or changing a shot SHALL NOT require pipeline code changes for existing camera and prop kinds.

#### Scenario: invalid shot

- **WHEN** a shot names an unknown character, pose, prop or background
- **THEN** the pipeline SHALL refuse it, naming the field, before rendering

### Requirement: Character edits reach affected shots

Impact analysis of a character or style edit SHALL list every shot depending on it. Only shots where the edited region is visible inside the viewport SHALL be rebuilt.

#### Scenario: hat on a closeup of hands

- **GIVEN** one shot framing Bartender's face and another framing only her hands
- **WHEN** a hat is added to Bartender
- **THEN** impact analysis SHALL list the face shot as affected and the hands shot as unchanged

### Requirement: Shots stay within cinematic timing rules

Shots SHALL be timed in transport beats, never wall-clock time, and SHALL NOT change judgments, cue timing or touch regions. Each shot SHALL be 2 to 4 drawings with authored holds, and sequences SHALL fit their authored musical bridge.

#### Scenario: sequence too long

- **WHEN** a sequence's total beats exceed its musical bridge
- **THEN** validation SHALL fail, naming the sequence and the overrun

#### Scenario: tempo differs on replay

- **GIVEN** a sequence authored in beats
- **WHEN** it plays at a faster tier
- **THEN** every shot SHALL stay aligned to the same musical boundaries

### Requirement: Shots have reduced-motion and skip behaviour

Every sequence SHALL declare a reduced-motion form using fixed cuts without zoom or shake. Skipping or interrupting a sequence SHALL leave game progress identical to finishing it.

#### Scenario: reduced motion

- **WHEN** reduced motion is enabled during a transition
- **THEN** the sequence SHALL show its fixed cuts and still land on the same musical boundary

### Requirement: Shot art carries no text and is reviewed

Shot images SHALL contain no baked text, follow the character's ramps, and remain candidates until a person accepts them at game size, with the same provenance as dance frames.

#### Scenario: unaccepted shot

- **WHEN** a sequence contains an unaccepted drawing
- **THEN** promotion SHALL be refused, naming that drawing

### Requirement: Palette variants apply to shots

A character's named palette variant SHALL apply to its shots through the same colour table, without regenerating them.

#### Scenario: replay variant in a transition

- **GIVEN** a colour-only variant of Bartender
- **WHEN** the pour sequence is prepared for that variant
- **THEN** its drawings SHALL use the variant's colours with no images generated
