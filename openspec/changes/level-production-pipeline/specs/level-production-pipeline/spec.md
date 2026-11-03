# Spec Delta

## Purpose

Let one prompt start a whole level, by expanding it into a reviewed brief that drives
the character, room, score, chart and shot pipelines through shared gates.

## ADDED Requirements

### Requirement: A prompt expands into a committed level brief

A level prompt SHALL expand into a structured brief covering opponent, audience, room, music, chart, transitions and variants. All downstream work SHALL read the brief, so builds are reproducible without re-running any language model.

#### Scenario: same brief, same plan

- **GIVEN** a committed level brief
- **WHEN** the level is planned twice
- **THEN** both plans SHALL be identical and no language model SHALL run

#### Scenario: invalid brief

- **WHEN** a brief names an unknown character, room, score or motion set
- **THEN** it SHALL be refused, naming the field, before any pipeline starts

### Requirement: Levels orchestrate existing pipelines

The level pipeline SHALL produce only inputs for the character, shot, score and room pipelines and SHALL rely on their own builds, caches and acceptance. It SHALL NOT generate images or notes itself.

#### Scenario: reused character

- **GIVEN** a level whose opponent already has accepted frames
- **WHEN** the level is built with that definition unchanged
- **THEN** no frames SHALL be regenerated

### Requirement: Level impact is reported as one plan

Before any GPU or model work, the pipeline SHALL report per pipeline what a level or edit would build, reuse and return to review, with estimated image and score counts.

#### Scenario: character edit across a level

- **WHEN** a hat is added to a level's opponent
- **THEN** the plan SHALL list affected frames and in-frame shots, and SHALL report the room and score as unchanged

### Requirement: Production passes through ordered gates

A level SHALL pass brief approval, then design proofs for characters and music, then full generation, then an in-game review. A later gate SHALL NOT start until the earlier one is accepted by a person.

#### Scenario: unapproved brief

- **WHEN** generation is requested for a brief without approval
- **THEN** it SHALL be refused, and SHALL name the missing approval

### Requirement: Music follows the character on a Latin base

Each level brief SHALL declare how its opponent's look and role shape the music, and a dominantly Latin rhythmic base. Other styles SHALL be declared as hints or layers with where they enter.

#### Scenario: brief without a Latin base

- **WHEN** a music brief declares no Latin rhythmic base
- **THEN** validation SHALL fail

#### Scenario: character influence recorded

- **WHEN** a level brief is approved
- **THEN** it SHALL state the opponent's influence on rhythm, voices and harmony

### Requirement: Charts are drafted, validated and played

A level's chart SHALL be a candidate until a person has played it. Candidates SHALL pass rules for phrase form, rest placement, cue lead, thumb reach, clean budget and musical alignment, and chart notes SHALL never depend on animation timing.

#### Scenario: chart breaks a rule

- **WHEN** a candidate leaves less than the two-beat cue lead
- **THEN** validation SHALL fail, naming the note

#### Scenario: not yet played

- **WHEN** a chart passes every rule but has no play approval
- **THEN** it SHALL remain a candidate

### Requirement: Audience is declared with the level

A level brief SHALL declare its audience by shared silhouettes, wardrobes, archetype clips and formations, built through the character pipeline. Audience figures SHALL stay within the room's crowd budgets and never resemble an unverified Covi.

#### Scenario: shared silhouettes

- **WHEN** a level declares twelve guests from three silhouettes and four wardrobes
- **THEN** three atlases SHALL be built, and wardrobes SHALL be colour tables

### Requirement: Groups are reviewed composed

Any scene with several figures SHALL be checked in its formation at game size: floor depth order, overlap, reserved cue areas and the challenger's silhouette against the group.

#### Scenario: group hides the challenger

- **WHEN** a formation covers the challenger's silhouette or a cue origin beyond its limit
- **THEN** the group check SHALL fail, naming the figures

### Requirement: Variants are palette-only until accessories are enabled

Level variants SHALL be colour-only under the default policy. Definitions SHALL stay able to express accessories, and enabling them SHALL NOT need a redesign of the brief.

#### Scenario: accessory requested today

- **WHEN** a replay variant adds a hat under the default policy
- **THEN** it SHALL be refused with a message naming the policy

### Requirement: Levels become runtime data

A promoted level SHALL be playable from data alone, with its room, opponent, score, chart, bridge and sequences resolved by ID rather than per-level code.

#### Scenario: adding a room

- **WHEN** a third room's accepted data is registered
- **THEN** the game SHALL transition into it with no per-room code change
