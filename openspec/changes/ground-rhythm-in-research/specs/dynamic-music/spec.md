## ADDED Requirements

### Requirement: Seams sound continuous

Every music seam (tier change, success phrase, bridge, room change) SHALL land on a bar
line of the outgoing music, and SHOULD land on a 4- or 8-bar phrase boundary. A seam
report SHALL measure, per seam: whether the incoming downbeat falls on the outgoing bar
grid (within 5 ms); the loudness step across the seam (short-term LUFS, 400 ms on each
side), at most 3 LU unless the seam is an authored accent; the spectral-centroid step;
and the pitch-class overlap of the last outgoing and first incoming bar. Seams outside
these limits SHALL be listed for listening. A seam SHALL count as natural only after
listeners judge it so (median ≥ 5 of 7 on "the change sounded natural" in the playtest
protocol). The metrics alone SHALL NOT approve it.

Rationale: Medina-Gray (2019, *Music Theory Online* 25.3, "Analyzing Modular
Smoothness in Video Game Music") judges smoothness at modular seams by "meter, timbre,
pitch, volume, and abruptness". ABZU's music system placed sync points "usually at the
beginning of each measure" (GDC 2017), and Phillips marks segments at "convenient and
logical points" for switching (GDC 2021). The owner heard the current transitions as
"way too obvious".

#### Scenario: a loud seam

- **WHEN** a bridge enters 6 LU louder than the bar before it, without an authored accent
- **THEN** the seam report lists it for listening and remixing.

### Requirement: Tension builds into tier changes and resolves at cadences

Each score SHALL report a per-bar tension proxy: loudness, onset density and spectral
centroid, after Farbood's model. The 2–4 bars before a tier-up boundary SHALL rise in at
least two of the three. Each phrase's final bar SHALL fall or hold, a release, unless it
leads straight into a peak. A new instrument or voice SHALL enter at each tier-up
boundary from tier 1 to tier 4.

Rationale: perceived tension tracks loudness, harmony, pitch height and onset frequency,
and loudness carries the most weight (Farbood 2012, *Music Perception* 29:387; Farbood
2016). Harmony integrates over about 22 s, other features over 1–4 s (Farbood & Upham
2013). Chills come with "the entrance of new voices or instruments" and loudness rises
(Grewe et al. 2007, *Music Perception* 24:297). Dopamine rises in the caudate in the
roughly 15 s of anticipation before a peak, and in the nucleus accumbens at it
(Salimpoor et al. 2011, *Nat Neurosci* 14:257).

#### Scenario: flat build

- **WHEN** the 4 bars before a tier-3 boundary have flat loudness and density
- **THEN** the report flags the boundary as an unbuilt peak.

### Requirement: Repetition with variation

Each score's motifs SHALL recur, so that the room hook is restated in at least half of
its bars, with an authored variation (register, rhythm, orchestration or harmony) at
least every 8 bars. No two consecutive 8-bar spans SHALL be identical at the same tier.
The proportions are starting values for listening.

Rationale: repetition is "a quasi-magical agent of musicalisation" (Margulis, *On
Repeat*, OUP 2014; Aeon essay). Expectation that is set up and then confirmed or varied
drives musical emotion (Huron 2006, *Sweet Anticipation*, ITPRA).

#### Scenario: verbatim loop

- **WHEN** a tier plays the same 8 bars twice in a row with no variation
- **THEN** the score fails the repetition check.

### Requirement: Dance accents agree with musical accents

A dancer's accent frame (foot contact, hip or arm hit) SHALL be scheduled against the
latency-corrected heard time of the musical accent it represents. It MAY lead the sound
by up to 40 ms, and SHALL NOT trail it by more than 20 ms. The challenger's and Mācron's
beat bounce SHALL stay visible on every beat while music plays. The call SHALL sit on the
lead line's phrase and the response on the answer (coro) slot of the arrangement.

Rationale: audio-visual simultaneity tolerates the visual leading far more than the
audio leading: about 150–250 ms vs about 50–80 ms (Vroomen & Keetels 2010, as
summarised by later reviews). For drumming video, the needed delay is about 30–100 ms,
depending on tempo (Arrighi, Alais & Burr 2006). A bouncing human figure improves beat
perception and synchronization (Su 2014, *Brain and Cognition*).

#### Scenario: late pose

- **WHEN** a foot-contact frame shows 60 ms after the kick it represents is heard
- **THEN** the choreography check flags it.

### Requirement: Groove is rated, not assumed

Each level's release candidate SHALL be rated in playtest on the Experience of Groove
Questionnaire's two scales, urge to move and pleasure (Senn et al. 2020, *Music
Perception* 38:46; α = .92 and .97), and on "the taps matched the music" and "the dancer
moved with the music", on 7-point scales. A level SHALL reach a median of at least 5 on
each before promotion, or the shortfall SHALL be recorded for the owner. Ratings SHALL
be collected after calibration, so latency doesn't masquerade as bad music.

Rationale: groove is "wanting to move some part of the body in relation to some aspect
of the sound" (Madison 2006, adopted by Janata, Tomic & Haberman 2012, *J Exp Psych:
General* 141:54). Its quality tracks sensorimotor coupling, which is measured only by
asking or watching people.

#### Scenario: low groove rating

- **WHEN** the bar level's median "urge to move" is 3.5
- **THEN** it isn't promoted without a note to the owner naming the shortfall.
