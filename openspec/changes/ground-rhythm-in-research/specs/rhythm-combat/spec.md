## MODIFIED Requirements

### Requirement: Audio-clock timing and phrase success

Judgment SHALL use monotonic audible-song time, corrected for measured output
and player input latency as "Judgment against heard time" defines, never frame count.
Perfect is absolute error ≤75 ms; Good is ≤180 ms; later notes expire only after their
late Good boundary, measured in corrected time.
A press SHALL consume at most one nearest unresolved matching-limb note.
Presses nearer another limb's ring SHALL not consume this limb's note. Every required note
in a response phrase SHALL receive Good or Perfect to pass. Stray presses MAY
show feedback but SHALL not themselves fail an otherwise complete phrase.
Minimum intervals between required presses SHALL follow the grip, as "Spacing follows
the grip, above the human floor" defines, replacing the former flat 250 ms rule.
No narrower mandatory window SHALL be used for enthusiast difficulty.

#### Scenario: display stalls

- WHEN a render frame arrives late
- THEN judgments still compare event timestamps to audible song time
- AND missed notes are expired once, independently of the visual frame rate.

## ADDED Requirements

### Requirement: Judgment against heard time

Judgment SHALL compare a press to the moment the player *heard* the note, not the moment
it was scheduled. Heard time SHALL be the audio clock minus the output latency (the
browser's reported `outputLatency + baseLatency`, used only when both are present and
total 0–500 ms, otherwise a per-platform default), minus an input-latency default
(starting at 40 ms on touch), plus the player's calibration offset. A press SHALL be
timestamped from its pointer event and mapped to the audio clock, not from the frame
that handled it. The Perfect (±75 ms) and Good (±180 ms) widths SHALL stay symmetric
around the corrected time.

Rationale: people tap a few tens of ms *ahead* of a beat (negative mean asynchrony;
Repp 2005, *Psychon Bull Rev* 12:969; Repp & Su 2013, 20:403), so a systematic late bias
is pipeline latency. Touchscreens add 50–200 ms (Deber et al., CHI 2015), and Android
Chrome Web Audio adds 80 to 300+ ms on low-end phones (Chromium issue 40103372). The
current windows are already wider than Arcaea's (±100), osu! OD 5's (±150) and Rhythm
Quest's (±125), so they SHALL be centered, not widened.

#### Scenario: reported output latency is applied

- **WHEN** the context reports outputLatency 0.030 and baseLatency 0.010, and a press
  arrives 70 ms after a note's scheduled time on the audio clock, with no calibration
  and a 40 ms input default
- **THEN** the press is judged −10 ms from the note (70 − 40 − 40 = −10), and so Perfect.

#### Scenario: implausible latency is ignored

- **WHEN** the context reports outputLatency 0.9, or reports none
- **THEN** the platform default is used instead, and the choice is visible in the
  diagnostics.

#### Scenario: frame stall doesn't move a tap

- **WHEN** a press's event is handled 100 ms late because of a stalled frame
- **THEN** its judged delta is the same as without the stall.

### Requirement: Tap calibration and bias report

The game SHALL offer a wordless tap-along calibration: a steady beat at the level's
tempo for at least 12 counted taps after a 4-beat lead-in. The offset SHALL be the median
signed asynchrony after discarding taps more than 150 ms from the beat, and SHALL be
stored per device. The offset SHALL shift input judgment only, never the audio.
Calibration SHALL be offered at first play and from pause, and SHALL be skippable.

The game SHALL keep a per-phrase median of signed corrected deltas. If the median of the
last 3 phrases stays beyond ±40 ms, it MAY nudge the offset by half that median at the
next phrase boundary, never by more than ±60 ms in total per session, and never during a
phrase.

Rationale: tapping to audio measures audio plus input latency (Rhythm Quest devlog 10,
DDRKirby(ISQ)). Shipped games shift the input by the measured offset. Bluetooth audio
adds about 150–300 ms (RTINGS: 241 ms on SBC), which no window absorbs. Gentle,
predictable adjustment follows Hunicke & Chapman's Hamlet: "intervene just enough so that
system behavior is relatively stable and predictable over time".

#### Scenario: calibration result

- **WHEN** a player's 14 calibration taps sit at +55 to +70 ms, with one at +240 ms
- **THEN** the +240 tap is discarded and the stored offset is about −62 ms (the median),
  so later presses at +62 ms judge as 0.

#### Scenario: nudge is bounded

- **WHEN** a player's corrected median stays +100 ms late for 20 phrases
- **THEN** the offset moves at phrase boundaries only, and by no more than 60 ms in total
  that session.

### Requirement: Required taps sit on audible onsets

Every required note SHALL coincide with an audible, sharp-attack onset in the music that
plays at that moment: in the rendered mix, or in the stem it represents. An offline audit
SHALL report, per level and tier, the share of required notes within 20 ms of a detected
onset, and SHALL list notes with no onset within 40 ms ("silent taps"). A level SHALL have
at least 95% of its required notes within 20 ms, and no silent taps on beat 1 or on a
phrase's last note. Taps on slow-attack sounds (pads, swells) SHALL align to the attack
peak, not the note start.

Rationale: "Every element of a map should represent the song" (osu! ranking criteria).
Harmonix called charts not tied to the real parts "disconnected" from the music. The
perceived beat of a note moves later as attack and duration grow (Danielsen et al. 2019,
*J Exp Psych: HPP*, "Where is the beat in that note?"). And people notice AV offsets of
about 30–100 ms (Arrighi, Alais & Burr 2006, *J Vision* 6:260).

#### Scenario: audit finds a silent tap

- **WHEN** a chart places a required note on beat 2.5, where the rendered tier has no onset
  within 40 ms
- **THEN** the audit lists the note, and the level fails until the chart or the music changes.

### Requirement: Limbs follow the metric levels the body dances

Charts SHALL map feet primarily to beats and half-bar accents (tambora, kick, the
cha-cha break step), and hands primarily to off-beats and subdivisions (llamador, güiro,
clave strokes, melodic hits). At least 70% of foot notes SHALL fall on beats, and at
least 50% of hand notes on off-beats or clave strokes, from tier 2 up. Tiers 0–1 MAY
use beats for both. Style figures SHALL be charted as the dance counts them:

- cha-cha-chá: 2, 3, 4 & 1, with the chassé "4 & 1" alternating thumbs;
- son clave: a 2- or 4-bar phrase SHALL start on the clave's start and keep its
  direction (3-2 or 2-3) unless the cross is authored on purpose;
- cumbia: feet on the tambora downbeats, hands on the llamador off-beats; the top tier
  MAY add alegre-style syncopations.

Rationale: different body parts lock to different metric levels (Toiviainen, Luck &
Thompson 2010, *Music Perception*), and clear pulse is embodied by the whole body
(Burger et al. 2013, *Front Psychol* 4:183). The cha-cha step is "2, 3, 4&1" with "the
final step on 1 … the first beat of the next measure" (dance pedagogy, Human Kinetics).

#### Scenario: cha-cha figure is fair at the fastest tempo

- **WHEN** a tier charts a cha-cha 4 & 1 at 160 BPM (188 ms per eighth) with the "&" on
  the other thumb
- **THEN** fairnessProblems reports nothing, because 188 ms is above the 170 ms
  cross-thumb floor.

### Requirement: Spacing follows the grip, above the human floor

The minimum interval between required presses SHALL be set per grip, as `MoveLimits`
defines it (starting at: same spot 285 ms, thumb hop 330 ms, cross thumb 170 ms, same
limb 400 ms), not as a flat 250 ms across limbs. No floor SHALL go below 150 ms. Every
level SHALL pass fairnessProblems at every tempo its ladder plays.

Rationale: the fastest rate people can synchronize with is about 100–125 ms per tap
(Repp 2006, *Adv Cogn Psychol*, "Rate limits of sensorimotor synchronization"). Two
thumbs alternating at 170 ms sit well above it. The flat 250 ms rule forbids eighths at
every tempo above 120 BPM, and so forbids the cha-cha chassé.

#### Scenario: eighth notes across thumbs

- **WHEN** a chart alternates thumbs on eighths at 144 BPM (208 ms)
- **THEN** it passes. The same eighths on one thumb's same spot fail at 285 ms.

### Requirement: Syncopation and density by tier

Each tier's chart SHALL report a syncopation index (the share of notes off the beat,
weighted by metric strength as in Witek et al. 2014) and its notes per bar. Tier 0 SHALL
be lowest. Tiers 2–3 SHALL sit in the medium band, starting at 20–40% of notes off the
beat. Tier 4 MAY exceed it, but every phrase SHALL end on a strong beat or the clave's
resolution. Density SHALL not decrease from one tier to the next.

Rationale: "medium degrees of syncopation elicited the most desire to move and the most
pleasure, particularly for participants who enjoy dancing to music", an "inverted
U-shaped relationship" (Witek et al. 2014, PLOS ONE 9:e94446). The band is a starting
value for playtest.

#### Scenario: an all-off-beat tier 2

- **WHEN** a tier-2 chart has 80% of its notes off the beat
- **THEN** the report flags it above the band.

### Requirement: Difficulty curve targets measured pass rates

Playtests SHALL measure response-phrase pass rates per tier. The targets are 85–90% at
tiers 0–2 and 70–80% at tier 4, with a first clear in 1–3 attempts at each fight's
full-tier proof. A failure SHALL show why it failed (early, late or wrong limb), without
milliseconds. The one-tier drop on failure SHALL remain the only automatic difficulty
change, besides the bounded calibration nudge.

Rationale: engagement in a 69,642-session game experiment peaked at about 90% success,
and "less challenging designs were more engaging" (Lomas et al., CHI 2013, as reported by
Khajah et al., CHI 2016). Learning is fastest at about 85% accuracy (Wilson et al. 2019,
*Nat Commun* 10:4646). Flow needs "a balance between challenges and skills" and
immediate feedback (Csikszentmihalyi 1996; Chen 2007, CACM 50(4)). Players prefer to
"feel responsible for failure" (Juul 2013, *The Art of Failure*).

#### Scenario: playtest reading

- **WHEN** the tier-1 pass rate across six players is 60%
- **THEN** the tier is recorded as too hard and its chart is revised before release.
