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

### Requirement: Looping and gameplay checkpoints preserve clock authority

The transport SHALL provide an opt-in complete-form loop mode. In this mode
absolute beat position SHALL increase continuously through form boundaries, and
score-local position SHALL wrap modulo the written form length. A seam SHALL
schedule the next form's first attack exactly once, without restarting the audio
context or clearing the tempo map. Tier changes SHALL remain phrase-aligned on
the absolute timeline, including at a seam. Finite playback SHALL remain the
default for score previews.

An explicit seek SHALL cancel sounding and queued voices, restore a supplied
checkpoint tier, clear pending tier intents, and leave the transport paused at
the requested absolute beat. A phrase restart SHALL perform that operation at
the current music-phrase start and resume after a requested count-in. Ordinary
pause/resume SHALL preserve pending tier intents; checkpoint rewinds SHALL
replace them with restored gameplay state. Judgment SHALL stay disabled while
`countingIn` is true. The game may seek its own offset checkpoint grid rather
than the music's bar-aligned phrase grid.

#### Scenario: tempo change at the repeating form boundary

- GIVEN a looping score with a pending tier change at its final boundary
- WHEN the audio clock reaches that boundary
- THEN absolute beat position continues forward, the new tempo applies continuously
- AND the first note of the next form is scheduled exactly once
- AND no opponent approval is implied by the loop.

#### Scenario: replay a gameplay checkpoint

- GIVEN future attacks have been scheduled and gameplay needs to replay a phrase
- WHEN it seeks an earlier checkpoint with the saved tier
- THEN queued attacks and sounding voices from the old timeline are cancelled
- AND the transport remains paused at that checkpoint until resume
- AND resume holds that beat during the count-in before scheduling new attacks.

### Requirement: Platform-safe gameplay audio factory

`createGameAudio()` SHALL expose activation, disposal, audio-clock access,
scheduling, silence and lead timbre through a shared Dart interface. Conditional
imports SHALL isolate web JS interop from VM tests and native application builds.
The implemented web backend SHALL release its AudioContext on disposal and
reject activation after disposal. The unsupported native stub SHALL report
`ready == false` and throw on activation or scheduling; it SHALL never simulate
an advancing clock that could allow a silent scored run.

#### Scenario: widget tests or unsupported native platform

- GIVEN a non-web build imports the gameplay audio factory
- WHEN it constructs the default backend
- THEN the import and construction succeed without loading browser libraries
- AND activation explicitly reports unsupported audio while readiness stays false.

### Requirement: Original room success phrases and composed tonal bridges

Each of the five rooms SHALL have its own original two-bar success/exit phrase,
derived from that room's melody and tonal identity. Its first bar SHALL recall the
room's call, and its second bar SHALL answer with a distinctive tonic coda. The VIP
success phrase SHALL also serve as the final musical tag. Successful approval
SHALL trigger this authored phrase after the next uncommitted music-phrase boundary;
approval SHALL NOT trigger an immediate silence or generic success sound in place
of the composed exit.

Four distinct two-bar bridges SHALL connect Garden A minor to Bar C minor, Bar C
minor to Crowd D Dorian, Crowd D Dorian to Restroom E minor, and Restroom E minor to
VIP F major. Each bridge SHALL use a written percussion-only first bar to establish
the destination's base tempo without unresolved pitched overlap, then a second bar
that introduces the destination's original motif and a dominant pickup. This is an
arranged harmonic transition, not pitch-shifting or crossfading recordings. A tempo
step at the bridge downbeat is an authored choice; no continuous tempo ramp is
claimed. Room intro beats provide visual breathing room while the composition
continues. These phrases SHALL require no gameplay input and SHALL award no extra
progress or Pizazz.

#### Scenario: identifiable success theme

- GIVEN a room is approved after its full-tier challenge
- WHEN its next safe musical boundary arrives
- THEN that room's own success phrase quotes its melody and resolves its tonic
- AND the music continues into its matching bridge or the final VIP ending.

### Requirement: Shared-clock transition conductor

`TransitionConductor` SHALL schedule source retirement, success, bridge and the next
looping room on one existing audio backend and device clock. Every segment's first
downbeat SHALL coincide exactly with the preceding segment's written end time.
Starting or naturally completing a transition segment SHALL NOT invoke backend-wide
silence, reset the audio context, or cancel a successor's already-scheduled voices.
The source SHALL stop scheduling attacks at its retirement timestamp; normal
instrument releases MAY decay naturally across a boundary. Score data and visual
assets SHALL be preloaded before the handoff is committed.

The conductor SHALL expose playing/paused/completed state, live boundary timestamps,
and the next room's transport. Gameplay MAY adopt that transport once its count-in
flag clears, without restarting it; subsequent room intro beats remain input-free.
The conductor SHALL have no internal timers. One external pump owns all segments
until adoption, then gameplay pumps the adopted transport. It SHALL also permit
successive handoffs from its running destination without silencing the backend.
`finish()` SHALL schedule the room's success phrase and let its final notes release
naturally; finishing a prototype room SHALL not falsely imply later rooms are ready.

Explicit pause, application interruption and scheduling starvation SHALL cancel all
queued and sounding voices across the shared backend. Coordinated resume SHALL
preserve each active or future segment's relative position, shift remaining device
timestamps by one common offset and preserve a source's pending retirement. A future
segment whose attacks were queued before pause SHALL be scheduled exactly once at
its new boundary. Normal handoffs SHALL insert neither a silent count-in nor a loading
wait between composed segments; an explicit resume may use the normal count-in.

#### Scenario: source, success, bridge and destination share boundaries

- GIVEN a playing source and all three subsequent scores have been loaded
- WHEN a handoff is committed
- THEN the source retires on its next uncommitted phrase boundary
- AND success starts at that timestamp, bridge starts at success end, and the next
  room starts at bridge end on the same device clock
- AND no transport completion cancels the next segment's queued voices.

#### Scenario: pause with a bridge attack already queued

- GIVEN the success phrase is playing and lookahead has queued the bridge downbeat
- WHEN the player pauses and later resumes
- THEN the shared queue is cancelled completely during pause
- AND success resumes from its frozen beat after the resume count-in
- AND the bridge downbeat and next room move together to their new timestamps
- AND the bridge attack is queued exactly once at its new boundary.
