# Input, peak dance and individual crowd research — 2026-10-28

Primary-source findings inform the design below; the exact thresholds and
choreography are this project's tuning hypotheses, not research findings.

- Nintendo's [Rhythm Heaven developer interview](https://iwataasks.nintendo.com/interviews/ds/rhythm-heaven/0/2/)
  describes the team's emphasis on immediate, unmistakable input response and
  sharply readable sound effects. Application: keep tap judgment immediate;
  let optional short flicks add a distinct expressive response without moving
  the required targets or making the player drag across the screen. The
  indexed primary-source interview was readable; a later direct fetch timed out.
- The [official Hi-Fi RUSH site](https://hifirush.krafton.com/) describes characters,
  environments and attacks moving with the music. Application: sample crowd
  poses, neighbor notices and recovery from the shared audio transport. A
  frame-driven timer must not accumulate a competing musical timeline.
- [Craig Reynolds' Boids explanation](https://www.red3d.com/cwr/boids/)
  demonstrates coordinated group behavior through individual responses to
  nearby neighbors. Application by analogy: one interested guest can point
  out Mācron to another, with staggered reactions. This is an authored social
  presentation model, not a claim that flocking research proves human audience
  behavior. Neighbor reactions cannot manufacture gameplay credit.

## Implemented controller scope

The two playable rooms keep their authored timing offsets and required four
limb controls. Each call captures its own limb motif and repeats exactly that
motif in the response. Later tiers introduce authored permutations. The two
full-arrangement sustain responses use distinct motifs; reaching the loudest
music and an enthusiastic crowd does not itself clear the room. Existing
later-room definitions retain three/three/four sustain responses, but their
rooms and production choreography are still future work.

Garden requires six of eight required taps during its ramp, then seven at
peak; bar requires seven throughout. A passing response may therefore recover
from a dropped note. Wrong/off-time presses never create hits and an empty
response cannot pass. Full-tier credit still waits for the audible tier-four
arrangement. Optional adornments never supply required taps, tier credit or
clearance. Physical-phone playtesting must validate these initial thresholds.

`CrowdInterestModel` owns five stable guests with individual receptiveness.
Completed passing responses build lasting interest over the four-tier ramp.
Guests progress through occupied, curious, following and participating states,
with neighbor notices staggered over two beats. Clearance adds celebration.
A failed response causes a small interest loss for the nearest guest and one
neighbor; it supplies a deterministic beat/index for a playful near-trip or
accidental bump. It does not make the whole room hostile. Crowd thresholds are
presentation feedback, not an additional potentially blocking win condition.

Accepted optional flicks generate separate local excitement. Alternating flick
directions within 24 beats builds a style chain up to four; repeated
directions restart at one. Bigger chains spread to more guests and linger
longer, without adding lasting interest. The window spans the non-scoring call
between responses, so advanced chains are reachable on the real chart.
Pizazz remains 100 per newly credited
adornment. The style ledger deduplicates replay before mutating the chain.
Unclaimed flicks never count as misses. Midphrase offers require at least
800 ms between target notes, protecting the latest accepted tap, 400 ms flick,
and next earliest tap; the last note is always eligible. Call and response
preview the same offers. Accepted early taps may complete their flick before
the nominal response beat.

Phrase results use a monotonic occurrence sequence and logical audio expiry
beat. In-memory checkpoints preserve committed interest and discard transient
style on pause; an interrupted phrase retains its identity, while a completed
retry is a new occurrence. Read-only render sampling cannot grant credit.
Durable save/reload support remains unimplemented.

## Production choreography contract still to finish

Guests must begin busy with drinks, conversations or their seats. Curious
guests glance and point; followers tap feet; participants clap and dance with
different poses. Increase the fraction visibly standing across successive
rooms, culminating in the entire VIP audience standing during the final peak
before approval. During the musical exit, guests progressively sit or resume
their activities, while a few keep clapping Mācron toward the next room.
Stage budgets should be explicit room data, not inferred from filenames.

These actions need authored multi-frame art, consistent foot pivots, frame
rectangles, facing, transparent gutters and beat durations. Procedural poses
or generated concept sheets are prototypes, not completed sprite atlases.
Keep cue origins clear and use the same readable poses with restrained motion
when reduced motion is enabled.

## Evidence and remaining acceptance

Controller tests cover forgiving required-hit thresholds, distinct peak
motifs, peak-before-clear, failure resetting sustain, pause before/after
commit, style-chain variety and deduplication, early-tap flicks, localized
losses, deterministic render sampling and idle non-escalation. The actual
garden/bar score integration still clears both rooms with taps alone and
preserves musical handoff boundaries. Physical one-thumb play, perceived
timing, native-resolution crowd readability, final art, five-room standing
progression and full-run pacing remain separate acceptance gates.
