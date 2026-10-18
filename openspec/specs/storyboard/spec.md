# Storyboard flow contract

## Purpose

Specify the visual sequence and music-safe camera behavior for all five social challenges and the VIP ending.

## Requirements

### Requirement: five continuous social challenges
The game SHALL stage Garden/Mojo, Bar/Swag, Cool Crowd/Flow, Restroom/Nerve and VIP/Presence in that order. The authored sequence IDs and asset handoffs in `plan/storyboard.md` SHALL guide visual production. Challenge resolution SHALL be driven by combat state and music transport, not cinematic elapsed time. Each chapter SHALL establish an obstructed route, demonstrate dance invitation, mirror player response, show growing respect, sustain full musical complexity through final proof and visibly open the route.

#### Scenario: seamless gate
- **WHEN** a challenger accepts the final full-complexity proof and the approval animation plays
- **THEN** the path opens and Mācron resumes forward traversal without a mission summary screen
- **AND** decorative swipes remain optional

### Requirement: reversible setbacks
Failed phrases SHALL show playful recovery and repeat; repeated failures MAY return the player to the same level entrance according to combat tuning. Later stage reset cost SHALL increase through lost local progress. Reset animation SHALL remain brief, and completed earlier stages SHALL remain complete. No game-over scene is required.

#### Scenario: repeated failure remains local
- **WHEN** a repeated-failure threshold returns Mācron to the current level entrance
- **THEN** completed earlier stages remain complete and recovery proceeds without a game-over screen

### Requirement: music-safe camera choreography
Rear over-shoulder approach SHALL be the default. Side-view combos, eased pans and modest zooms SHALL be authored at phrase boundaries; fixed cue positions and input timing SHALL remain authoritative. Reduced motion SHALL preserve all gameplay cues while removing camera orbit, snap zoom and decorative shake.

#### Scenario: reduced motion
- **WHEN** reduced motion is enabled during a side-view phrase
- **THEN** cue positions and timing remain intact while camera orbit, snap zoom and decorative shake are absent

### Requirement: complete VIP conclusion
Upon the last required VIP success, the timer SHALL stop before the ending. The authored closeup SHALL depict Tlatoāni and tiny Mācron high-fiving, Tlatoāni saying exactly “Chingón”, and a gesture inviting Mācron to the adjacent seat. A wide view SHALL establish Covi and partygoers once verified art exists. Ending skip/reload SHALL preserve completion and produce at most one submitted result.

#### Scenario: skip the ending
- **WHEN** a completed run skips or reloads during the high-five sequence
- **THEN** completion persists and no duplicate result is submitted

### Requirement: honest production state
Concept sheets SHALL be identified as concepts until frame bounds, anchors and animation continuity have been checked. Garden runtime background SHALL contain no baked HUD, captions or characters. Subsequent level backgrounds and cutscene animation SHALL remain tracked as unfinished production tasks until their actual files exist and are integrated.

#### Scenario: concept asset handoff
- **WHEN** a generated concept sheet lacks verified frame bounds or animation continuity
- **THEN** its production status remains concept and it is not declared a finished animation atlas
