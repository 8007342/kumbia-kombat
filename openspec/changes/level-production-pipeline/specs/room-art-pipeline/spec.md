# Spec Delta

## Purpose

Produce each room's layered background, masks and strips from a definition, calibrated
to the floor plane that characters stand on, so rooms can be iterated like characters.

## ADDED Requirements

### Requirement: Rooms are declared as data

A room definition SHALL declare its style, palette focus, camera, floor plane, layers, props and reserved zones. Rooms SHALL be built by the same content-addressed stages and backends as characters.

#### Scenario: invalid room

- **WHEN** a room names an unknown layer kind or backend
- **THEN** it SHALL be refused, naming the field, before generation

### Requirement: Rooms have separated layers

A room SHALL produce independent back, middle, floor and front layers and an emissive mask, with hidden areas filled so parallax reveals no holes.

#### Scenario: parallax offset

- **WHEN** layers are composited with the largest allowed parallax offset
- **THEN** no transparent gaps SHALL appear in the frame

### Requirement: Room art contains no people or text

Room layers SHALL contain no characters, baked UI, captions or readable lettering, and generated candidates that do SHALL be flagged for review.

#### Scenario: person in a background

- **WHEN** a person is found in a candidate at review
- **THEN** it SHALL be rejected and regenerated

### Requirement: Rooms keep cue areas readable

Each room SHALL declare its reserved cue and thumb zones. Layers SHALL meet a contrast and detail limit in those zones against the cue colours.

#### Scenario: busy cue origin

- **WHEN** a layer exceeds the detail limit at the cue origin
- **THEN** the check SHALL fail, naming the zone

### Requirement: Floor calibration comes from the accepted art

A room's floor plane SHALL be recalibrated against its accepted art, with a reference character shown at near and far marks for review before promotion.

#### Scenario: uncalibrated room

- **WHEN** a room with a placeholder floor plane is promoted
- **THEN** promotion SHALL be refused

### Requirement: Edits rebuild only affected layers

A room edit SHALL rebuild only the layers it reaches, and accepted unaffected layers SHALL stay accepted.

#### Scenario: emissive tweak

- **WHEN** only the emissive mask's definition changes
- **THEN** no other layer SHALL be regenerated
