## MODIFIED Requirements

### Requirement: Progression owns musical intensity

The game SHALL send an arrangement-tier intent from required-cue results. Tiers
0–4 are Party groove, Percussion lift, Countermelody, Full melody, and Full ensemble.
Tier zero SHALL already contain the room hook, restrained harmony, bass and
percussion; escalation SHALL add authored musical detail rather than only volume. Tempo increases by
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
- AND the next uncommitted two-bar boundary adds countermelody and three BPM
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
cue judgment, tier progress, completion gates, and tempo unchanged. Pizazz, localized transient crowd excitement and expressive dance responses
are its rewards; lasting required mastery remains separate. An omitted or failed ornament SHALL carry no progression penalty.
The optional phrase's touch area and timing SHALL not steal the required beat.
The playback adapter SHALL suppress ornaments during count-ins, suspension,
room transitions, and after the current form's last safe beat.

#### Scenario: flourish versus progress

- GIVEN a required tap followed by an optional right swipe
- WHEN the swipe is accepted
- THEN the authored rising `shine` motif plays at the next safe subdivision
- AND Pizazz and localized expressive crowd responses change because of the swipe
- AND the required tap keeps its own already-recorded result.

### Requirement: Original room success phrases and composed tonal bridges

Each of the five rooms SHALL have its own original two-bar success/exit phrase,
derived from that room's melody and tonal identity. Its first bar SHALL recall the
room's call, and its second bar SHALL answer with a distinctive tonic coda. The VIP
success phrase SHALL also serve as the final musical tag. The second approval
bar SHALL thin accompaniment and soften attacks while preserving its musical
answer, allowing staggered crowd settling before travel. Successful approval
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
