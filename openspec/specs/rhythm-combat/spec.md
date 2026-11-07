# Rhythm combat

## Purpose

Portrait, one-thumb rhythm battles move Mācron through the party without a
game-over interruption. Required taps earn respect; optional flourishes earn
Pizazz. The five clean fight budgets total 390 seconds; short transitions fit
within the 5–8 minute clean-run target. These are chart-authoring budgets, not
hard time limits or lengths enforced by the prototype model.

## Requirements

### Requirement: Readable four-ring input

The lower portrait viewport SHALL show four rings in a 2×2 pad, each in its own
quadrant: LH/RH above LF/RF. This SHALL be the only layout; there is no corner
mode. Matching SVG silhouettes identify each move. Required destinations SHALL
vary modestly and deterministically by the note's beat and id, by bounded named
amounts, and the whole ring SHALL stay within its quadrant on every supported
phone. A tap SHALL count for a note when it lands within a generous radius of
that note's ring: at least 72 logical pixels, and a fifth of the screen width
on wider phones. Those areas MAY overlap. Among notes whose timing window is
open, a tap SHALL go to the nearest ring by distance, with equal distances going
to the note closer in time. Each area SHALL stay reachable on every supported
phone and clear of the pause and AutoPlay buttons. Each note's destination SHALL
remain immutable from preview birth through judgment. Simultaneously visible
notes MAY show separate destination rings, including doubles. Moving markers
SHALL NOT shrink or move a ring's tap area. No required chord or simultaneous
fingers SHALL be authored.

#### Scenario: one-hand play

- WHEN a phrase asks for left hand, right hand, left hand twice
- THEN four distinct presses in their timing windows pass the phrase
- AND holding, releasing, or optional swiping never creates another tap.

#### Scenario: a tap outside every area

- WHEN a tap lands outside the area of every note whose window is open
- THEN it consumes no note, breaks no combo and fails nothing
- AND inside the pad the ring on its side dents to show it was heard.

### Requirement: Predictable curved preview

Notes SHALL appear at a varied, deterministic point near the center of the play
area at least two beats before their hit, with a minimum 900 ms preview and
maximum 1500 ms, on their own limb's side of it, and SHALL fade in smoothly over the first part of that approach so that new notes
don't crowd the center. Their limb silhouette and previewed judgment ring SHALL
be readable once faded in. A bounded curve whose bend follows the move, leaving
sideways toward the limb's side and then rising into a hand's ring or dropping
onto a foot's, SHALL stay within its own quadrant of the play area and end at
its own previewed judgment ring. A final half-beat radial ring
SHALL communicate the exact hit moment. Reduced motion SHALL replace the curve
with a straight path to the limb's home, without variation, and disable camera turns/zooms. Camera motion SHALL never
move HUD targets or affect judging. The pure Dart curve is an initial visual
model; device playtests determine density and final opacity.

#### Scenario: double tap preview

- WHEN two same-limb notes are incoming
- THEN both remain individually distinguishable, spaced in time along the path
- AND their target pulses twice, without requiring a double-tap recognizer.

### Requirement: Audio-clock timing and phrase success

Judgment SHALL use monotonic audible-song time, corrected for measured output
and player input latency, never frame count. Perfect is absolute error ≤75 ms;
Good is ≤180 ms; later notes expire only after their late Good boundary.
A press SHALL consume at most one nearest unresolved matching-limb note.
Presses nearer another limb's ring SHALL not consume this limb's note. Every required note
in a response phrase SHALL receive Good or Perfect to pass. Stray presses MAY
show feedback but SHALL not themselves fail an otherwise complete phrase.
There SHALL be a 250 ms chart minimum interval between required presses,
including across different limbs; the restroom MAY use 220 ms after playtests.
No narrower mandatory window SHALL be used for enthusiast difficulty.

#### Scenario: display stalls

- WHEN a render frame arrives late
- THEN judgments still compare event timestamps to audible song time
- AND missed notes are expired once, independently of the visual frame rate.

### Requirement: Optional moves after a tap

A required tap's judged time SHALL be the press, and which ring it belongs to
SHALL be decided at the press, by the near-ring rule. A note MAY invite an
optional move drawn by the same pointer after an accepted tap:

- a sideways drag for a spin, which MAY curve;
- a semi-circle for a hand wave, on a phrase's last hand note from tier 1;
- up and down, in either order, for a foot stomp, on a phrase's last foot note
  from tier 1;
- a full circle, on a phrase's last hand note from tier 3.

Any move drawn on an eligible note SHALL count, whichever was invited, and a
stroke that is no shape in particular SHALL earn the plain flick if it travelled
past the touch slop. There SHALL be no requirement to draw in one of four
directions. Moves are pass or nothing: timing precision belongs to the tap.

A note SHALL be eligible only if the next required note leaves clearance for the
late tap, the move and the next early tap, as the chart's rule defines, or if it
is the phrase's last note. A mid-phrase move SHALL have 400 ms from the press. A
last note's move SHALL have 2 beats from the press, or 2.5 for a full circle,
and never less than 400 ms. These chances SHALL outlive the phrase's judge, so a
late tap's move crossing into the next call still counts. A move SHALL land as
soon as the invited shape is complete, without waiting for the lift, and a thumb
held past the deadline SHALL be read as drawn so far.

Each performance earns 100 Pizazz once: a retry of a failed phrase is a new
performance, and a pause's replay is not. Holding, releasing, or drawing SHALL
never create another tap. Missing, reversing, declining or fumbling a move SHALL
never change hits, combo, grades, tier, tempo, the clock, respect or required tap
accuracy. A cancelled pointer SHALL void the stroke with no visible failure. A
move SHALL request an authored musical ornament at the next safe musical
subdivision, never interrupting the pulse or delaying input feedback.

The recogniser's numbers SHALL be generated data, not constants edited in runtime
code, and it SHALL run within a frame on a phone and on Flutter web with no native
plugin.

#### Scenario: move without a successful tap

- WHEN a player draws on a missed or unresolved note
- THEN no Pizazz is awarded and the required note remains unresolved.

#### Scenario: move ignored or fumbled

- WHEN the same taps are played with moves ignored, performed, or too late
- THEN hits, combo, grades, tier, results and elapsed time are identical.

#### Scenario: late tap at the fastest tempo

- WHEN a last note is tapped 180 ms late at 160 BPM and its move lands after the
  phrase has rolled over
- THEN the move still counts, against the phrase it belongs to.

### Requirement: Moves are invited by drawing them

A cue that invites a move SHALL draw its path, from the point where the thumb
lands, with no words: a dot, the path, and an arrowhead for direction. While the
thumb is down after an accepted tap, the rest of the shape SHALL show as a dotted
guide from wherever it landed, under the thumb's own trail. A move that lands SHALL
flare, and one that doesn't SHALL fade silently, with no miss shown. Under reduced
motion the path SHALL show whole and still. AutoPlay SHALL perform moves by feeding
a stroke through the same recogniser.

### Requirement: Five progressively consequential fights

| Fight | Respect | Clean budget | Passes per tier | Full-tier passes | Consecutive failures before entrance reset |
| --- | --- | --- | --- | --- | --- |
| Garden / mansion gate | Mojo | 60 s | 1 | 2 | 5 |
| Bar | Swag | 80 s | 2 | 2 | 5 |
| Cool crowd | Flow | 95 s | 2 | 3 | 4 |
| Restroom rush | Nerve | 45 s | 1 | 3 | 4 |
| VIP | Presence | 110 s | 3 | 4 | 3 |

Each fight SHALL start at complexity tier 0 and progress through tiers 1–4.
The counts above apply per completed response phrase. A failed phrase SHALL
reduce complexity by one tier (floor 0), clear tier progress and full-tier
streak, and replay a learnable equivalent phrase. Success SHALL clear the
consecutive-failure count. Reaching tier 4 SHALL not clear a fight: the player
must pass its listed full-tier phrases while the complete arrangement plays.
Music changes SHALL be requested immediately but applied by the conductor at
its safe authored boundary. Entrance reset SHALL reset current-fight respect
and tier progress only, preserving completed fights, elapsed time, and earned
Pizazz. More lost progress and stricter failure thresholds make later resets
costlier; no lives, currency penalty, or game-over screen SHALL exist.

#### Scenario: failure at full complexity

- WHEN a player fails a VIP phrase at tier 4
- THEN tier 3 is requested, full-tier successes clear, and a retry follows
- AND VIP remains locked until tier 4 is rebuilt and four final phrases pass.

### Requirement: Catchy call and response without text instruction

Every fight SHALL introduce its challenger with a short readable dance call,
then request the player's response with the same limb motifs and timing.
Demonstration time SHALL be non-scoring and visibly distinct from response.
Initial garden phrases SHALL teach one limb at a time before alternating and
double presses. Later charts SHALL introduce syncopation and cross-body motifs,
without making Pizazz mandatory. Minimal approvals (for example “OK, you cool”)
and challenger stepping aside SHALL communicate progression.

#### Scenario: readable call and response

- **WHEN** a challenger demonstrates a new phrase
- **THEN** demonstration is non-scoring and the player receives matching readable response cues.

### Requirement: Pause, timing, and finish

Visibility loss, app background, audio suspension, and explicit pause SHALL
save at the last safe phrase boundary. A paused run SHALL keep the game image
visible and frozen under a wordless frame in the style of a paused videotape,
with a big translucent pause icon. Tapping anywhere SHALL turn the icon into a
play triangle that fades out. Errors SHALL still appear as words, and a screen
reader SHALL still get a label. The frame's noise SHALL stay low contrast and
change at no more than two steps a second; reduced motion SHALL remove its
jitter and shorten the fade. Resume SHALL use a silent/non-scoring
count-in and replay the interrupted phrase without adding misses. The local
active-play timer SHALL exclude paused time. Ranked elapsed time SHALL use
server elapsed time and include pauses, reloads, demonstrations, responses,
retries, entrance resets, and transitions. The two timers SHALL be clearly
distinguished wherever both appear. Competitive timing and replay validation
remain a server integration task; the local model SHALL not be represented
as cheat protection. Completion SHALL freeze both timers at final challenger
approval when the final required challenge completes, before the high five.
Global ordering SHALL be ranked server elapsed milliseconds ascending, then
Pizazz descending for exact ties; arcade entry SHALL accept three letters.

#### Scenario: interrupted challenge

- **WHEN** the app hides during a response
- **THEN** the interrupted phrase SHALL resume from a safe checkpoint with count-in and no background misses.

## Implementation status

`lib/gameplay/rhythm.dart` implements tap judgment, note expiry, optional
optional move credit, and normalized preview paths. `progression.dart` implements
fight tier and reset rules. Flame input, charts, transport synchronization,
persistence, gestures, SVG HUD, camera choreography, and leaderboard wiring
are subsequent integration work. These models do not yet create a playable
game or synthesize audio.
