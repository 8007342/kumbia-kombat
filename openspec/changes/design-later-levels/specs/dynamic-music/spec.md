## ADDED Requirements

### Requirement: No protected works in generated music

Generated music SHALL be made from genre, instrument, tempo, key and mood words and the project's own
sheets only. No prompt, tag, file name, sheet or seed note SHALL name a protected work or its composer,
and no recording, MIDI file, transcription or cover of one SHALL be given to a model. A piece written
"in the spirit of" a protected work SHALL have its own melody, and SHALL NOT combine that work's hook
contour, accompaniment figure and lead orchestration. Before it ships, a blind listening check SHALL ask
whether any passage sounds like a famous piece, and a yes SHALL discard the take.

Rationale: Khachaturian's *Sabre Dance* (1942), which inspired the restroom's frenzy, is protected until
the end of 2048 in the EU and Armenia (life plus 70), 2037 or later in the US (URAA restoration, upheld in
*Golan v. Holder*, 2012), and 2078 in Mexico (LFDA art. 29, life plus 100). Arrangements and recordings
carry their own rights. A genre and its energy aren't protected, but a combination of elements can be
(*Williams v. Gaye*, 9th Cir. 2018). `plan/levels/later-levels-2026-11-08.md`.

#### Scenario: a prompt naming the piece

- **WHEN** a restroom frenzy take's provenance shows "sabre" or "Khachaturian" in its words
- **THEN** the take is rejected, whatever its timing scores

#### Scenario: a take that sounds familiar

- **WHEN** a listener in the blind check says a frenzy take sounds like a famous classical piece
- **THEN** that take is discarded and another is made
