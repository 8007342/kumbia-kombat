# Spec Delta

## Purpose

Turn a short style prompt into a complete interactive score of tiers, transitions and
variants as lightweight note data, with complexity measured and quality reviewed by ear.

## ADDED Requirements

### Requirement: A prompt becomes a reviewable brief

A text prompt SHALL expand into a structured brief declaring form, harmony, groove, tempo, instruments and how each tier builds intensity. The brief SHALL be committed, editable and sufficient to reproduce the score.

#### Scenario: style prompt

- **WHEN** a level's prompt asks for slow chill country ambient with a hint of death metal
- **THEN** a brief SHALL be produced for review, naming how those styles appear in tempo, voices and harmony, before any score is built

### Requirement: Scores build deterministically from the brief

A brief, its motifs and a seed SHALL always produce byte-identical score JSON and MIDI. No model SHALL run at game runtime.

#### Scenario: rebuild

- **WHEN** a score is rebuilt from unchanged inputs
- **THEN** its outputs SHALL be byte-identical

### Requirement: A complete score set is produced

One brief SHALL produce everything a level needs: five tiers, success phrases, bridges, adornments and MIDI previews, passing the existing score validator.

#### Scenario: new level music

- **WHEN** a brief is built for a room
- **THEN** all assets the music manifest requires for that room SHALL exist and validate

### Requirement: Complexity is measured and gated

Each score SHALL pass measured thresholds for variety and intensity: limited exact or transposed repetition, independent voices, harmonic movement, and rising arrangement density across tiers. Failing scores SHALL NOT be promoted.

#### Scenario: transposed repeats

- **WHEN** a score's phrases are mostly transposed copies of one pattern
- **THEN** the gate SHALL fail and name the repeated material

#### Scenario: louder is not richer

- **WHEN** a higher tier differs from the lower one mostly by velocity
- **THEN** the gate SHALL fail

### Requirement: Models contribute candidates only

Motifs from any model SHALL be imported as quantised candidates with provenance and licence, fitted to the brief's key and meter, and accepted by a person. Scores SHALL build without any model available.

#### Scenario: model unavailable

- **WHEN** no music engine is reachable
- **THEN** the pipeline SHALL still build a score from authored and LLM-written motifs

#### Scenario: audio source

- **WHEN** ACE-Step audio is used as a source
- **THEN** only transcribed note data SHALL enter the score, and no audio SHALL ship

### Requirement: Styles and intensity change on musical boundaries

Style layers and tier changes SHALL take effect at authored phrase boundaries through the transport, without moving previewed cue deadlines.

#### Scenario: style change during play

- **WHEN** a style layer is requested mid-phrase
- **THEN** it SHALL begin at the next authored boundary and no scheduled cue time SHALL change

### Requirement: Assets stay lightweight and synthesised

Scores SHALL be note events played by the built-in synth, with no samples or recorded stems. Each score set's size SHALL be measured against a declared budget.

#### Scenario: over budget

- **WHEN** a score set exceeds its size budget
- **THEN** the build SHALL report the overrun and promotion SHALL be refused

### Requirement: People approve by listening

Promotion SHALL require human listening approval. Measured gates SHALL NOT be treated as evidence that music sounds good.

#### Scenario: gates pass

- **WHEN** a score passes every gate but has no listening approval
- **THEN** it SHALL remain a candidate
