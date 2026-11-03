# Spec Delta

## MODIFIED Requirements

### Requirement: Five authored instrumental compositions

The game SHALL ship original precomposed MIDI-like note scores for Garden/Mojo,
Bar/Swag, Crowd/Flow, Restroom/Nerve, and VIP/Presence. `assets/music/README.md`
defines the catalog. The Crowd asset may retain the stable ID `crowd_duende`;
player-facing copy SHALL call the stat Flow. The core musical output SHALL be
synthesized note events; recorded stems SHALL NOT provide core arrangements.
Sound effects and future nonmusical ambience are outside this restriction.

Every score SHALL contain five explicit arrangement tiers, two-bar transition
boundaries, authored melody and answer phrases, and optional adornment motifs.
The 32-bar forms use Invitation, Answer, Lift, and Approval sections; the short
16-bar restroom form uses Invitation and Answer. Section names alone SHALL NOT
award approval. MIDI exports SHALL be review artifacts generated from the same
note data. Generated data SHALL be deterministic, versioned, and independently
validated; no live generative model is needed to play a song.

Each score SHALL be dominantly Latin in rhythm and MAY carry hints of other styles.
A level's style SHOULD follow its character.

#### Scenario: score identity

- GIVEN all five scores and identical synth voices
- WHEN their full melodies are compared or auditioned
- THEN each has a distinct authored pitch/rhythm phrase and harmonic form
- AND every score retains an audible, dominantly Latin rhythmic identity and its own lead identity.
