# Rhythm combat

## Purpose

Portrait, one-thumb rhythm battles move Mācron through the party without a
game-over interruption. Required taps earn respect; optional flourishes earn
Pizazz. The five clean fight budgets total 390 seconds; short transitions fit
within the 5–8 minute clean-run target. These are chart-authoring budgets, not
hard time limits or lengths enforced by the prototype model.

## Requirements

### Requirement: Readable four-zone input

The entire usable portrait viewport SHALL be four nonoverlapping quadrants:
upper left = left hand, upper right = right hand, lower left = left foot,
lower right = right foot. Corner targets SHALL show matching SVG silhouettes,
with distinct hand/foot shapes and left/right orientation; color SHALL be
supplementary. Insets SHALL keep targets away from browser chrome and notches.
An opt-in thumb-reach mode SHALL remap both hit regions and cue anchors to a
lower-screen 2×2 pad with the same limb ordering. Layout changes SHALL apply
only between phrases; hit regions and anchors SHALL remain fixed throughout
each phrase. No required chord or simultaneous fingers SHALL be authored.

#### Scenario: one-hand play

- WHEN a phrase asks for left hand, right hand, left hand twice
- THEN four distinct presses in their timing windows pass the phrase
- AND holding, releasing, or optional swiping never creates another tap.

### Requirement: Predictable tornado preview

Notes SHALL appear near center at least two beats before their hit, with a
minimum 900 ms preview and maximum 1500 ms. At their birth their limb silhouette
and destination SHALL be recognizable; opacity SHALL never make that essential
information invisible. A bounded curling trajectory SHALL remain within its
destination quadrant and end at its corner ring. A final half-beat radial ring
SHALL communicate the exact hit moment. Reduced motion SHALL replace curling
with a straight path and disable camera turns/zooms. Camera motion SHALL never
move HUD targets or affect judging. The pure Dart curve is an initial visual
model; device playtests determine density and final opacity.

#### Scenario: double tap preview

- WHEN two same-limb notes are incoming
- THEN both remain individually distinguishable, spaced in time along the path
- AND their target pulses twice, without requiring a double-tap recognizer.

### Requirement: Audio-clock timing and phrase success

Judgment SHALL use monotonic audible-song time, corrected for measured output
and player input latency, never frame count. Perfect is absolute error ≤45 ms;
Good is ≤110 ms; later notes expire only after their late Good boundary.
A press SHALL consume at most one nearest unresolved matching-limb note.
Wrong-zone presses SHALL not consume another limb's note. Every required note
in a response phrase SHALL receive Good or Perfect to pass. Stray presses MAY
show feedback but SHALL not themselves fail an otherwise complete phrase.
There SHALL be a 250 ms chart minimum interval between required presses,
including across different limbs; the restroom MAY use 220 ms after playtests.
No narrower mandatory window SHALL be used for enthusiast difficulty.

#### Scenario: display stalls

- WHEN a render frame arrives late
- THEN judgments still compare event timestamps to audible song time
- AND missed notes are expired once, independently of the visual frame rate.

### Requirement: Optional after-tap flourishes

An authored tap MAY offer a destination swipe. A successful tap SHALL resolve
its required note immediately. A subsequent drag from that same pointer ending
in the indicated destination within 300 ms earns 100 Pizazz, once per authored
note per run. Credit SHALL be deduplicated by run, level, phrase, and note
identity across retries, entrance resets, reloads, and resume. Repeating an
already credited flourish MAY still trigger its musical ornament but SHALL
award no further Pizazz.
The gesture recognizer SHALL require at least 36 logical pixels displacement
and SHALL suppress release-generated taps. Optional swipes SHALL not overlap
the next required tap window; authors SHALL leave at least 500 ms before the
next required press. Missing, reversing, or declining a swipe SHALL never
reduce respect, complexity, or required tap accuracy. A flourish SHALL request
an authored musical ornament at the next safe musical subdivision, never
interrupting the pulse or delaying input feedback.

#### Scenario: flourish without a successful tap

- WHEN a player swipes a missed or unresolved note
- THEN no Pizazz is awarded and the required note remains unresolved.

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
save at the last safe phrase boundary. Resume SHALL use a silent/non-scoring
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
flourish credit, and normalized preview paths. `progression.dart` implements
fight tier and reset rules. Flame input, charts, transport synchronization,
persistence, gestures, SVG HUD, camera choreography, and leaderboard wiring
are subsequent integration work. These models do not yet create a playable
game or synthesize audio.
