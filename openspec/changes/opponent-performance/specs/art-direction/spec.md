# Spec Delta

## ADDED Requirements

### Requirement: Opponent dance is composed from readable motion phases

Each opponent SHALL perform authored preparation, weight transfer, chart-matched accent, follow-through, recovery, and settle. The supporting foot and required limb SHALL remain readable. Character style MAY vary, but arbitrary jumps or unrelated pose changes SHALL not replace the dance phrase.

#### Scenario: demonstrated foot accent

- **WHEN** an opponent demonstrates a foot accent
- **THEN** the corresponding foot moves through a clear preparation and accent while the opposite support foot remains visibly weight-bearing
- **AND** the follow-through returns the lifted foot to a readable grounded pose.

#### Scenario: authored character variation

- **WHEN** two opponents perform the same required limb motif
- **THEN** each may use a distinct personality and body style
- **AND** both preserve the same chart limb, beat accent, support logic, and readable outcome.

### Requirement: Opponent secondary motion preserves cue readability

Secondary motion SHALL follow the main action and SHALL not obscure its active gesture or cue path.

#### Scenario: secondary motion during a required accent

- **WHEN** an opponent's hat, clothing, or body follow-through moves during a required gesture
- **THEN** the required limb and its support remain recognizable at game size.

### Requirement: Animation metadata supports beat-authored review

Animation metadata SHALL identify clip, facing, frame order, ground pivot, support/contact details, loop behavior, beat markers, and provenance. A generated contact sheet SHALL not become a runtime atlas until its bounds, pivots, identity, and motion continuity have been reviewed.

#### Scenario: generated atlas is promoted

- **WHEN** a generated sheet is proposed for runtime
- **THEN** its actual frame bounds, identity, ground anchors, and clip order have been measured and visually reviewed.

### Requirement: Dance-area travel uses grounded locomotion

An opponent or Mācron entering or leaving the dance area SHALL use authored turn, start-step, planted walk, arrival/deceleration, and settle clips. The gait and ground-root route SHALL describe the same travel; moving a root without a matching gait is a visible slide.

#### Scenario: opponent yields the floor

- **WHEN** the opponent finishes its call and yields the performance mark
- **THEN** it turns and walks along the authored room route with visible footfalls and changing perspective scale
- **AND** Mācron enters and settles before the first response cue appears.

### Requirement: Dance-area travel follows room depth and exclusive ownership

Travel SHALL sample the music presentation clock. Actor roots, stature, shadows, draw order, and furniture occlusion SHALL use the same room floor projection. Facing changes SHALL use authored views. Only one actor owns the performance mark; cues wait for arrival, and valid response input finishes before the outgoing route starts.

#### Scenario: perspective during travel

- **WHEN** a dancer moves between floor marks at different depths
- **THEN** its rendered stature, shadow, and draw order change through the same room projection as the background.

#### Scenario: protected final response

- **WHEN** the final required response input or optional flourish remains valid
- **THEN** staging keeps the performer at the dance mark until that interaction window closes
- **AND** the exit then plays its authored turn, walk, and arrival transition without changing judgment.

### Requirement: Animation research remains linked to production standards

The project SHALL keep a cited register separating source findings from Kumbia Kombat's design decisions. Image-generation prompts, frame briefs, and review criteria SHALL reference that register and the current character/style canon. External frame counts or timing values SHALL not be presented as authoritative when the source only supports general principles.

#### Scenario: prepare an opponent animation prompt

- **WHEN** a new opponent clip is sent to an image-generation workflow
- **THEN** its brief specifies identity, action phases, support/contact, view, anchor, beat events, and avoidances using the shared project standard
- **AND** the run record identifies its research and canon references.
