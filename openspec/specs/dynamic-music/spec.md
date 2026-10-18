# Dynamic original music

## Purpose

Make musical confidence audible in the portrait, one-hand dance battles. Required
taps build a precomposed synth cumbia arrangement and its tempo. Mistakes thin the
arrangement at a safe phrase boundary. Optional tap-then-swipe flourishes color the
music and earn Pizazz without changing progression. The five rooms feel related,
but have their own tune, harmony, register, and instrumental personality.

## Requirements

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

#### Scenario: score identity

- GIVEN all five scores and identical synth voices
- WHEN their full melodies are compared or auditioned
- THEN each has a distinct authored pitch/rhythm phrase and harmonic form
- AND every score retains audible cumbia percussion and its own lead identity.

### Requirement: Progression owns musical intensity

The game SHALL send an arrangement-tier intent from required-cue results. Tiers
0–4 are Pulse, Groove, Harmony, Melody, and Full ensemble. Tempo increases by
three BPM per tier inside each room's authored tempo range. Tier changes SHALL
land at a two-bar boundary and affect both arrangement selection and tempo as one
transaction. A miss SHALL reduce confidence through the gameplay rules and queue
the resulting musical reduction; it SHALL NOT silence the pulse abruptly or
restart the tune. Inputs before a pending boundary SHALL coalesce to the latest
valid gameplay intent without moving already-scheduled audio.

The campaign owns clean target budgets [60, 80, 95, 45, 110] seconds, phrase passes
per tier [1, 2, 2, 1, 3], and full-tier challenge passes [2, 2, 3, 3, 4], in room
order. These are campaign definitions, not independent music approval rules.
390 seconds plus compact transitions targets a clean five-to-eight-minute run.
The music adapter SHALL reconcile score form with that state through authored
phrase vamps and cadences. Reaching score EOF SHALL NOT pass a room. If approval
arrives before a form ends, finish the current phrase and exit via a composed
cadence; if the form ends before approval, repeat a compatible phrase. Failure
or recovery can extend a run beyond the flawless-run target.

#### Scenario: tier increase at a boundary

- GIVEN tier 1 is playing and a required-cue pass earns tier 2
- WHEN the game requests tier 2 between phrase boundaries
- THEN the scheduled phrase stays rhythmically intact
- AND the next uncommitted two-bar boundary adds harmony and three BPM
- AND visual cues and input judgments use that same updated tempo map.

#### Scenario: final sustained challenge

- GIVEN full arrangement is audible
- WHEN the player has not completed the room's full-tier challenge passes
- THEN the opponent does not approve and the music continues its authored form
- AND a failed challenge can reduce complexity according to gameplay rules.

### Requirement: Adornments cannot replace required taps

A successful optional tap-then-swipe gesture SHALL choose a written ornament for
its swipe direction, quantized to the next safe sixteenth-note subdivision and
limited to at most one accepted ornament per invitation. It SHALL leave required
cue judgment, tier progress, completion gates, and tempo unchanged. Pizazz is its
only reward. An omitted or failed ornament SHALL carry no progression penalty.
The optional phrase's touch area and timing SHALL not steal the required beat.
The playback adapter SHALL suppress ornaments during count-ins, suspension,
room transitions, and after the current form's last safe beat.

#### Scenario: flourish versus progress

- GIVEN a required tap followed by an optional right swipe
- WHEN the swipe is accepted
- THEN the authored rising `shine` motif plays at the next safe subdivision
- AND only Pizazz changes because of the swipe
- AND the required tap keeps its own already-recorded result.

### Requirement: Audio-clock authority and bounded scheduling

The synth backend SHALL expose its audio timeline in seconds and schedule attack
and release timestamps on that timeline. Flame frame deltas, widget animation
time, and wall-clock timers SHALL NOT advance the musical position. The transport
SHALL map piecewise tempo sections continuously between beats and audio seconds.
The UI SHALL query the transport for visual phase; input timestamps SHALL be
mapped into that same domain, adjusted once for calibrated input/output latency.

The foundation uses 120 ms lookahead and a nominal 20 ms pump. Device sample
scheduling provides precision; the timer merely fills the queue. Tempo edits
SHALL not invalidate notes already handed to the device. Note releases crossing
a tempo boundary SHALL use the mapped end beat. Future scores with long held
notes across editable boundaries require a backend reschedule strategy or an
explicit tie split; current authored phrases avoid this case. A backend SHALL
bound voice count, preserve the bass and pulse preferentially under load, and
report underruns/drops for diagnostics. The current prototype caps at 96 scheduled
or active voices and records dropped voice requests; priority stealing remains
integration work.

#### Scenario: frame stall and safe recovery

- GIVEN the scheduling horizon has expired by more than 25 ms
- WHEN the pump resumes after a blocked UI or background interruption
- THEN the transport pauses at its last safely scheduled beat
- AND cancels queued attacks and sounding voices
- AND emits no avalanche of late notes or automatic gameplay misses
- AND requires a count-in before judgment resumes.

### Requirement: Pause, resume, and activation

Audio SHALL begin only after a player gesture successfully activates the device.
The app SHALL show activation progress and an actionable failure state when the
device is unavailable. Visibility loss, application suspension, audio focus loss,
or explicit pause SHALL freeze judgment and transport together. Pause SHALL cancel
future attacks and release voices with a short clickless fade. Resume SHALL anchor
the frozen beat to a new audio start time following a one-bar audiovisual count-in;
no scoring is active during the count-in. Held notes cut by pause need not retrigger;
the next written attack resumes. Pending tier intent SHALL be reconciled with the
gameplay snapshot before continuing. Room changes SHALL cancel old score and
ornament voices, and a score-load generation token SHALL reject stale async loads.

#### Scenario: suspended browser

- GIVEN the browser AudioContext is suspended
- WHEN a frame or delayed timer arrives
- THEN no gameplay beat advances because of that frame or timer
- AND the player sees a paused state until audio resumes successfully.

### Requirement: Web and native capability contract

Web SHALL use Web Audio `currentTime`, scheduled source starts/stops, and a user
activation path. The implemented prototype uses oscillators, filtered generated
noise, envelopes, and one context; an AudioWorklet is a later option for DSP or
larger instrument budgets. Web Audio's clock and suspend/resume semantics are
specified by the [Web Audio specification](https://www.w3.org/TR/webaudio-1.0/).
Browser output timestamp/latency support varies; use capability detection and a
manual calibration flow, with no invented fixed universal latency.

Native SHALL implement the same backend interface with an audio render callback,
a sample-frame clock and timestamped event queue. Android should use an appropriate
low-latency Oboe/AAudio path; Android's [low-latency guide](https://developer.android.com/games/sdk/oboe/low-latency-audio)
requires callback-based rendering and suitable stream settings. Select and verify
the iOS backend against Apple audio-session/focus documentation when implementing
it. No native backend or measured native latency is delivered by this foundation.
Native platform glue SHALL not issue one platform-channel call per note.

#### Scenario: unsupported or unavailable audio

- GIVEN audio activation fails or the device is absent
- WHEN the user attempts a scored run
- THEN the run remains unstarted and explains how to retry
- AND a silent demo is clearly identified as a demo with scoring disabled.

### Requirement: Asset provenance and quality verification

All distributed music assets SHALL carry provenance, generation instructions and
license status. Imported soundfonts or samples require explicit compatible licenses
and attribution before inclusion. Current scores and procedural synth contain no
third-party music or recorded audio; `assets/music/LICENSE.md` records this.

Automated acceptance SHALL cover five valid unique scores; valid MIDI type 1 files
with balanced note-on/off and exact form lengths; five increasing arrangement
tiers; valid adornments; deterministic regeneration; tempo continuity; duplicate
prevention; tier intent coalescing; pause/resume position; scheduler starvation;
backend unavailability; score completion without opponent approval; and gameplay
isolation of ornaments. Browser/device acceptance SHALL additionally check gesture
activation, portrait controls, tier changes, suspend/resume, voice cleanup, input
calibration, mixing headroom, physical-speaker sound quality, and a complete clean
run within five to eight minutes. Compile success is not a listening test.


#### Scenario: music acceptance review

- **WHEN** a score or synth revision is proposed
- **THEN** asset and transport validation SHALL pass and physical listening review SHALL remain required before release.
