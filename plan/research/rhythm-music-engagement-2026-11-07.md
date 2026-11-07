# Rhythm, music and engagement: a cheatsheet with sources

Researched 2026-11-07 by RESEARCH (branch `work/1879-rsch`) for the owner's request:
taps and combos that feel "one and the same" with the music and the dance, latency
acceptance for "late" taps, and the hard-to-measure musical qualities backed by
studies. The spec changes built on this note are in
`openspec/changes/ground-rhythm-in-research/`.

## How to read the tags

- **[M] Measured.** A peer-reviewed experiment or a device measurement gives the number.
- **[R] Review or theory.** A published review or a theoretical framework from a recognised author.
- **[D] Designer practice.** A shipped game's documentation, wiki or developer devlog. This is opinion, or at best convention, not a study.
- **[Ours]** Our own proposal, derived from the above. The owner can reverse it.

**How the sources were checked.** WebFetch and curl couldn't reach any site from the forge
this session: every fetch failed with "connection reset". Every source was found
through web search, and every quotation in "quotes" below appeared verbatim in the
search snippets of that source. Items marked **(memory, verify)** are numbers I know
from the literature but couldn't re-read today. Treat them as approximate until
someone checks the paper.

## The one-paragraph answer

Humans don't tap late. In a hundred years of tapping studies they tap *early*,
by a few tens of milliseconds (negative mean asynchrony). When a phone game logs
mostly "late" taps, the cause is the pipeline: the sound leaves the speaker tens to
hundreds of milliseconds after the game scheduled it, and the touch reaches the code
50–200 ms after the finger lands. Our windows (Perfect ±75, Good ±180) are already
wider than most rhythm games', so widening them isn't the fix. The fix is to judge
against the moment the player *heard*, corrected for output and input latency, plus
a tap calibration. "Feeling one with the music" has measurable correlates. Taps
should sit on audible onsets. Syncopation should stay medium (the groove inverted U).
Feet should take the beat and hands the off-beats and subdivisions, as dancers' bodies
do. Phrases should begin and end on hypermetric boundaries. Peaks should land where
new instruments enter.

---

## 1. Timing perception and sensorimotor synchronization

| Finding | Number | Tag | Source |
|---|---|---|---|
| Taps lead the beat (negative mean asynchrony, NMA) | "a few tens of milliseconds" ahead. Typical 20–50 ms in non-musicians, smaller in musicians (memory, verify) | [R][M] | Repp 2005; Repp & Su 2013 |
| NMA in a recent field sample | mean about −82 ms in young adults, about 85% of taps early | [M] | Nature Sci Rep 2026, s41598-026-38073-x |
| NMA isn't universal | absent or reversed in some cultural groups | [M] | Polak et al., arXiv 2107.03971 |
| Fastest tapping you can keep in sync with | IOI about 100–125 ms (8–10 Hz) for auditory beats | [R][M] | Repp 2006 (Adv Cogn Psychol), "Rate limits of SMS"; Repp 2005 |
| Slowest pulse you can keep in sync with | about 1800 ms IOI (0.56 Hz) | [R] | same |
| Syncing to a visual flash is much worse | limit about 450 ms IOI (2.2 Hz) for flashes | [M] | Repp 2003, as cited |
| Untrained people tapping on tablets | consistency 0.73 (range 0.64–0.80), lower than in lab studies, partly because "the device touchscreen (sampling rate between 60 and 240 Hz)" is imprecise | [M] | Zagala, Foster & Dalla Bella 2021, Front Psychol 12:607676 |
| Just-noticeable timing deviation in a regular beat | about 2.5% of the IOI for 250–1000 ms IOIs, about 6 ms below 240 ms (memory, verify) | [M] | Friberg & Sundberg 1995, JASA |
| Preferred or most natural tempo | about 2 Hz (500 ms, 120 BPM) (memory, verify) | [M] | Moelants 2002 (ICMPC); Fraisse 1982 |

**Quotes.**
- Repp & Su 2013: the mean asynchrony "is usually negative", which is called
  "negative mean asynchrony (NMA)", and "the standard deviation of asynchronies"
  indexes stability. Sensorimotor synchronization: A review of recent research
  (2006–2012). *Psychonomic Bulletin & Review* 20:403–452.
  https://link.springer.com/article/10.3758/s13423-012-0371-2
- Repp 2005. Sensorimotor synchronization: A review of the tapping literature.
  *Psychonomic Bulletin & Review* 12(6):969–992.
  http://users.df.uba.ar/anita/f1_labo/clase1/repp%20psycho%20bull%20rev%202006%20synchro%20tapping%20review.pdf
- Repp 2006. Rate limits of sensorimotor synchronization. *Advances in Cognitive Psychology*.
  https://doaj.org/article/dc3f29b3977e4adf8dfe9aa998eb40de
- Zagala, Foster & Dalla Bella 2021. Commentary: A Tablet-Based Assessment of Rhythmic
  Ability. *Frontiers in Psychology* 12:607676. https://pmc.ncbi.nlm.nih.gov/articles/PMC8329329/
- Polak et al. 2021. The classical mean negative asynchrony in sensorimotor
  synchronization is not universal in humans. https://arxiv.org/pdf/2107.03971
- Testing sensorimotor timing across age and music experience in a real-world environment.
  *Scientific Reports* 2026. https://www.nature.com/articles/s41598-026-38073-x

**What it means for us.**
- At our tempos (136–160 BPM) a beat is 441–375 ms, an eighth 221–188 ms and a sixteenth
  110–94 ms. Our Good window (±180 ms) is nearly a full eighth note on each side.
  A tap judged Good can be audibly a half-eighth off, so the visual feedback must be
  honest: "early" or "late" ([Ours]).
- Human error is early, so a systematic *late* bias in our logs is a latency bug, not
  human slowness ([Ours], from NMA).
- The cross-thumb minimum in `lib/gameplay/garden_session.dart` (170 ms) is above
  the human floor (100–125 ms) with room to spare. Same-limb 400 ms is very safe.
  The spec's "250 ms chart minimum interval… including across different limbs"
  disagrees with the code (170 ms cross-thumb). Section 7 resolves this.

## 2. Audio-visual simultaneity, and seeing a dancer on the beat

| Finding | Number | Tag | Source |
|---|---|---|---|
| The simultaneity window is asymmetric | about 50–80 ms tolerated when the audio leads, about 150–250 ms when the visual leads | [R] | as summarised from Vroomen & Keetels 2010 and later reviews |
| The window is narrow and fixed when the audio leads, wide and trainable when the visual leads | qualitative | [M] | Cecere et al. 2016 (ResearchGate 299379498) |
| Watching drumming: the audio delay needed to look in sync shrinks as tempo rises | about 100 ms at 1 Hz down to about 30 ms at 4 Hz | [M] | Arrighi, Alais & Burr 2006, *J Vision* 6:260 |
| A bouncing human figure (point-light) improves beat perception and tapping | qualitative, larger when the audio beat is degraded | [M] | Su 2014, *Brain and Cognition* |
| Lag adaptation: people recalibrate to a constant AV or motor lag after exposure | qualitative | [M] | Heron et al.; Sugano et al. 2010, *Exp Brain Res* (s00221-009-2047-3) |

**Quotes.**
- Cecere et al.: the binding window "appears narrower and non-malleable for
  auditory-leading stimulus pairs and wider and trainable for visual-leading pairs".
  https://www.researchgate.net/publication/299379498
- Vroomen & Keetels 2010 (Perceptual intersensory synchrony, *Atten Percept Psychophys*),
  as quoted by citing papers: "the brain must have some tolerance for audiovisual (AV)
  temporal discrepancies". https://www.frontiersin.org/journals/human-neuroscience/articles/10.3389/fnhum.2021.629437/full
- Arrighi, Alais & Burr 2006. Perceptual synchrony of audiovisual streams for natural and
  artificial motion sequences. *Journal of Vision* 6(3):260–268. https://flore.unifi.it/handle/2158/250649
- Su 2014. Visual enhancement of auditory beat perception across auditory interference
  levels. *Brain and Cognition*. Abstract: "the visual beat improved the perception of
  … and the synchronization to … the auditory rhythms". https://pmc.ncbi.nlm.nih.gov/articles/PMC5120798

**What it means for us.**
- A dancer's accent pose (foot contact, hip pop) may land up to about 30–50 ms *before*
  the sound and still read as one event. A pose that lands *after* the sound reads as
  late much sooner. When in doubt, lead with the picture: schedule visual accents
  against the latency-corrected audible time, never against the scheduled time
  ([Ours], from the asymmetry).
- Su's result supports making Mācron's and the challenger's bounce visible on every
  beat. It is beat information, not decoration.

## 3. Device latency: what the phone adds

| Source of lag | Number | Tag | Source |
|---|---|---|---|
| Touchscreen end-to-end tap latency, commercial devices | 50–200 ms; "up to 125 ms" per the 2013 study | [M] | Deber et al., CHI 2015; Jota et al., CHI 2013 |
| Tap latency people can't perceive | below about 24 ms | [M] | Jota, Ng, Dietz & Wigdor, CHI 2013 |
| Android native audio, best case (Pixel, AAudio or OpenSL) | about 18 ms round trip (Pixel XL, 192-frame buffer) | [M] | Android Open Source Project, latency measurements |
| Android Chrome Web Audio, user reports | baseLatency reported at 80 ms; measured tap-to-sound 300 ms on a Samsung A10, versus 70 ms native on the same phone; 450–800 ms on a Galaxy Tab A | [M] (user reports) | Chromium issue 40103372 |
| iOS Safari Web Audio | sparse reports, tens of ms on recent phones | weak | blogs |
| Bluetooth SBC | about 150–300 ms (Sony WH-1000XM5 on SBC: 241 ms) | [M] | RTINGS latency tests |
| aptX Low Latency, LE Audio LC3 | about 40 ms, if both ends support it | [M] (vendor) | RTINGS and vendor material |

**Quotes.**
- MDN: `outputLatency` is "an estimation of the output latency of the current audio
  context … the time … between the browser passing an audio buffer out of an audio
  graph over to the host system's audio subsystem to play, and the time at which the
  first sample in the buffer is actually processed by the audio output device." It is
  marked "Baseline 2025". https://developer.mozilla.org/en-US/docs/Web/API/AudioContext/outputLatency
- Chromium issue 40103372: two devices both reported "4 ms base latency" but measured
  very differently. https://issues.chromium.org/issues/40103372
- Jota et al. 2013, "How fast is fast enough? A study of the effects of latency in
  direct-touch pointing tasks", CHI 2013: 2291–2300. Deber et al. 2015 summarise it:
  users "are unable to perceive latency in response to tapping that is less than 24 ms".
  https://dcmpx.remotevs.com/com/tactuallabs/www/SL/papers/howMuchFasterIsFastEnoughCHI15.pdf
- AOSP audio latency measurements. https://source.android.com/devices/audio/latency/measurements
- RTINGS, headphone latency. https://www.rtings.com/headphones/learn/latency

**Platform support (search summaries, verify on a device).** Chrome and Edge expose
`outputLatency`. Safari exposes `baseLatency` but reportedly not `outputLatency`.
Some Android builds report 0 or implausible values. **No window can absorb Bluetooth
lag**, so it needs calibration.

## 4. How rhythm games calibrate and judge

**Calibration [D].**
- Rhythm Quest devlog 10 (DDRKirby(ISQ)): "Having a user tap to an audio signal will
  give you the sum of audio latency + input latency. Similarly, having an user tap to a
  visual signal will give you the sum of video latency + input latency." Calibrate the
  two separately. Rhythm Doctor does A/V sync first, then a tap test.
  https://ddrkirbyisq.medium.com/rhythm-quest-devlog-10-latency-calibration-fb6f1a56395c
- The Guitar Hero method, as described by a developer: "if the calibration test in
  guitar hero tells the game your TV is 30ms behind in latency, the game handicaps your
  input by 30ms". The game shifts the judgment, not the audio.
  https://steamcommunity.com/app/1286350/discussions/0/4846392474903976294
- Moving-note games care less about the visual offset, because "since the arrows move
  at a constant speed we can predict where they will be in the future".
  https://github.com/LastExceed/offsets-in-rythmgames

**Judgment windows (± ms around the note) [D].**

| Game | Tightest | Middle | Widest accepted | Source |
|---|---|---|---|---|
| osu! (standard), OD 5 | 300: 80−6·OD = 50 | 100: 140−8·OD = 100 | 50: 200−10·OD = 150 | osu! wiki, Overall difficulty |
| osu! (standard), OD 0 (easiest) | 80 | 140 | 200 | same |
| osu!mania | 300g: 16; 300: 64−3·OD | … | … | same |
| Arcaea (mobile) | Max Pure 25 | Pure 50 | Far 100 (Lost beyond about 120) | wikiwiki.jp/rhythmgame/Arcaea; moegirl |
| StepMania 3.9 defaults | 22.5 | 45 / 90 | 135 / 180 | flashflashrevolution forum |
| DDR | Marvelous about 16.7 (1 frame) | Perfect about 33 (2 frames) | … | remywiki (fan wiki) |
| ITG | Fantastic about 21.5 | Excellent about 43 | … | fan reference (unofficial) |
| Rhythm Quest (casual, hit or miss) | — | — | about 125, "a 16th note" | Rhythm Quest devlog 14 |
| **Kumbia Kombat today** | **Perfect 75** | — | **Good 180** | `lib/gameplay/rhythm.dart` |

- Rhythm Quest devlog 14: "My timing windows are lenient for this reason as well -- you
  can sometimes be a 16th note / 125 milliseconds off in either direction and still get
  credit for the note." https://ddrkirby.com/rhythm-quest/devlog/14.html
- osu! wiki. https://osu.ppy.sh/wiki/en/Beatmap/Overall_difficulty
- Arcaea. https://wikiwiki.jp/rhythmgame/Arcaea

**Reading [Ours].** Our accept window (±180) is wider than every listed game's except
osu! at its very easiest setting (OD 0, ±200), and wider than casual Rhythm Quest (±125).
Our Perfect (±75) is about the width of others' *middle* grade. Late taps being "Good" rather than "Perfect" is a centering problem
(latency), not a width problem.

## 5. Charting to the music

**Designer authorities [D].**
- osu! simplified ranking criteria: "Every element of a map should represent the song."
  The same page says this "might be the most controversial part of ranking a map".
  https://osu.ppy.sh/wiki/Ranking_criteria/Simplified_ranking_criteria
- osu! ranking criteria: "No two hit objects can be placed on the same tick."
  https://osu.ppy.sh/wiki/Ranking_criteria
- Harmonix, on Guitar Hero (Escapist, 2008): the note charts are "disconnected" from the
  music. Rock Band "material was easier when the actual guitar parts were easier",
  whereas Guitar Hero "seemed focused on ratcheting up difficulty".
  https://escapistmagazine.com/?p=68950
- Guitar Hero modding guide: "notes should fall evenly on or between these beatlines as
  much as possible". https://mariteaux.somnolescent.net/modding/guitar-hero/tutorials/authoring-expert-guitar/
- MercuryMapper guide: "guide the player into patterns by priming them beforehand".
  https://siamesederp.github.io/MercuryMapper-Tutorial/Charting
- XDRV guide: "essential charting" reduces complicated rhythms to their essential
  pattern, but can give "a generic feeling".
  https://theblockiest.github.io/xdrv-charting-guide/patterns/general-practices

**Where accents fall in our styles [R, pedagogy].** Counts are in eighths: 1 & 2 & 3 & 4 &.

| Pattern | Strokes | Source |
|---|---|---|
| Son clave 3-2 | bar A: 1, 2&, 4; bar B: 2, 3 | soundbrenner.com/blogs/articles/son-clave; Chromatone |
| Son clave 2-3 | bar A: 2, 3; bar B: 1, 2&, 4 | same |
| Cha-cha-chá step (ballroom) | 2, 3, 4 & 1: break on 2–3, chassé on 4&1, "the final step on 1 is the first beat of the next measure" | Human Kinetics excerpt; rounddancing.net |
| Cha-cha-chá (Cuban or round count) | 1, 2, 3, 4& ("one, two, three, cha-cha") | newworldencyclopedia.org; rounddancing.net |
| Cumbia (Colombian) | 2/4 feel; llamador "marks the weak pulses, the offbeats"; tambora anchors the downbeats; guacharaca "chu-chucu-chu", the pattern "the feet follow"; alegre improvises syncopated accents | Wikipedia (Cumbia); cumbia.fm; masterclass.com |
| Son and salsa tumbao (bass) | anticipates: the "and" of 2, then 4 | Wikipedia (Tumbao) |

- Cha-cha: https://us.humankinetics.com/blogs/excerpt/rhythmic-step-pattern-for-cha-cha ;
  https://rounddancing.net/dance/articles/guest/bahr/thatpesky4and1.html
- Clave: https://www.soundbrenner.com/blogs/articles/son-clave ; https://chromatone.center/theory/rhythm/system/clave/
- Cumbia: https://www.wikipedia.org/wiki/Cumbia ; https://www.cumbia.fm/en/blog/traditional-cumbia-instruments

**The perceptual centre of a note [M].** The "beat" of a sound isn't its acoustic onset.
"Attack and duration were the primary cues for P-center location", and slow-attack,
long sounds have later, wider P-centers. A tap on a pad or a bass swell is heard later
than its onset. A tap on a güiro or clave is heard right at its onset. Danielsen et al.
2019, *J Exp Psych: HPP*.
https://jyx.jyu.fi/bitstream/handle/123456789/63979/where%20is%20the%20beataccepted.pdf
**[Ours]:** chart required taps on percussive, sharp-attack events. If a tap must follow
a soft melodic note, align it to the note's attack peak, not the MIDI start.

## 6. Groove, the urge to move, and syncopation

| Finding | Number | Tag | Source |
|---|---|---|---|
| Medium syncopation maximises the urge to move and pleasure | an inverted U, strongest "for participants who enjoy dancing" | [M] | Witek et al. 2014, PLOS ONE 9:e94446 |
| Groove is predicted by the quality of sensorimotor coupling | correlational | [M] | Janata, Tomic & Haberman 2012, *J Exp Psych: General* 141:54–75 |
| The inverted U holds for rhythmic but not harmonic complexity | — | [M] | Matthews et al. 2019/2020 (as cited) |
| A standard groove rating scale | EGQ: 3 items for the urge to move (α = .92) and 3 for pleasure (α = .97) | [M] | Senn et al. 2020, *Music Perception* 38(1):46–65 |
| Different body parts lock to different metric levels | eigenmovements of body parts sync to different metric levels | [M] | Toiviainen, Luck & Thompson 2010, *Music Perception* |
| Clear pulse leads to whole-body movement; faster tempo surfaces higher metric levels | — | [M] | Burger et al. 2013, *Front Psychol* 4:183; Burger 2014, *Front Hum Neurosci* 8:903 |

**Quotes.**
- Witek et al.: "medium degrees of syncopation elicited the most desire to move and the
  most pleasure, particularly for participants who enjoy dancing to music", and the
  authors conclude "an inverted U-shaped relationship between syncopation,
  body-movement and pleasure". https://doaj.org/article/743d9013fbde436999b78a244c718d37
- Madison 2006, as adopted by Janata et al.: groove is "wanting to move some part of the
  body in relation to some aspect of the sound". https://zenodo.org/record/997607
- Burger et al. 2013: "clear pulses seemed to be embodied with the whole body … and
  distinctly related to certain body parts, such as head and hand movement".
  https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2013.00183/pdf
- Senn et al. 2020, Experience of Groove Questionnaire. https://www.aminer.org/pub/6219480a5aee126c0fe515c6/experience-of-groove-questionnaire

**What it means for us [Ours].**
- Measure each tier's chart syncopation with a standard index: Longuet-Higgins & Lee, or
  Witek's weighted index (memory, verify the formula). Tier 0 should be low. Tiers 2–3
  should be medium, the groove peak. Tier 4 may push higher, but it should resolve on
  strong beats at phrase ends.
- Limb mapping by metric level, after Toiviainen and Burger: **feet on beats and
  half-bars** (tambora, kick, the cha-cha break step), **hands on off-beats and
  subdivisions** (llamador, güiro, clave strokes, melodic hits). The pad then "plays the
  band" the way the body dances it.

## 7. Dance and music as one

- **Cha-cha's 4&1 is the dance.** A chart that taps 2, 3, 4, &, 1 *is* the step. At 136
  BPM the "4 &" gap is 221 ms, and at 160 BPM it is 188 ms. That fits the code's 170 ms
  cross-thumb floor, if the "&" changes thumb, but not the spec's 250 ms text ([Ours]).
- **Accent agreement [Ours, from Toiviainen/Burger/Su].** Every required tap is a body
  event: foot taps are foot contacts, and hand taps are arm accents. The animation
  frame for the hit pose should land on the corrected audible time, with up to about
  40 ms visual lead allowed.
- **Call and response maps to music's call and response.** Son and cumbia already
  alternate a sung *pregón* or lead line with a *coro* or answer. The challenger's call
  should sit on the lead instrument's phrase, and the response on the answer (coro) slot.

## 8. Engagement, difficulty and failure

| Finding | Number | Tag | Source |
|---|---|---|---|
| Flow needs clear goals, immediate feedback and a challenge-skill balance | eight or nine components | [R] | Csikszentmihalyi 1990/1996; Chen 2007, CACM 50(4):31 |
| Different players have different flow zones | qualitative | [R][D] | Chen 2007 |
| In a large game experiment, easier designs were more engaging | 576 designs, 69,642 sessions; engagement peaked at about 90% success | [M] | Lomas et al., CHI 2013 (as reported by Khajah et al. CHI 2016 and a DiGRA review) |
| Fastest learning at about 85% accuracy | error 15.87% | [M] (models) | Wilson et al. 2019, *Nature Communications* 10:4646 |
| Dynamic difficulty should be gentle and predictable | "intervene just enough so that system behavior is relatively stable and predictable over time" | [D][M] | Hunicke & Chapman, Hamlet (2004/2005) |
| Players prefer to feel responsible for failure | survey | [M] | Juul, *The Art of Failure* (MIT Press 2013); "Fear of Failing?" |

**Quotes.**
- Chen 2007: "If the challenge is beyond that ability, the activity becomes so
  overwhelming that it generates anxiety. If the challenge fails to engage the player,
  the player quickly loses interest and tends to leave the game." Also "Different
  players have different Flow Zones."
  https://khoury.northeastern.edu/~lieber/courses/csu670/f08/materials/p31-chen-flow-in-games.pdf
- Juul 2013, p. 54: "it is only through feeling responsible for failure (which we
  dislike) that we can feel responsible for escaping failure (which we like)".
  https://jesperjuul.net/text/fearoffailing/
- Wilson, Shenhav, Straccia & Cohen 2019, The Eighty Five Percent Rule for optimal
  learning: "the optimal error rate for training is around 15.87%". The rule strictly
  applies to binary tasks. https://ideas.repec.org/a/nat/natcom/v10y2019i1d10.1038_s41467-019-12552-4.html
- Lomas, Patel, Forlizzi & Koedinger 2013. Optimizing challenge in an educational game
  using large-scale design experiments. CHI 2013: 89–98. https://www.stat.cmu.edu/~brian/463-663/project-part-one/Optimizing%20Challenge.pdf
- Hunicke & Chapman, AI for Dynamic Difficulty Adjustment in Games (Hamlet).
  https://users.cs.northwestern.edu/~hunicke/pubs/Hamlet.pdf

**Measurable engagement instruments.**
- PENS (Ryan, Rigby & Przybylski 2006): competence, autonomy, relatedness, intuitive
  controls and presence. It is proprietary (Immersyve).
  https://game-evaluation.github.io/questionnaires/repository/pens.html
- GEQ (Game Engagement or Experience Questionnaire): 19 or 28 items on a 7-point scale.
  Its factor structure is only partly supported (Johnson et al. 2018).
- EGQ for groove (above). Gold-MSI for listener musical sophistication (Müllensiefen et
  al. 2014) (memory, verify).
- Behavioural proxies, the Lomas style: voluntary retries, session length, and the share
  of players who reach tier 4. These need no survey.

**What it means for us [Ours].**
- Target pass rates: about 85–90% of response phrases passed at tiers 0–2, falling to
  about 70–80% at tier 4. Measure them from AutoPlay-free playtests.
- The existing "failure drops a tier" rule is a DDA in Hamlet's spirit. Keep it one step
  and predictable, which it is.
- Show *why* a phrase failed (early, late, wrong limb) so failure feels owned (Juul).

## 9. The hard-to-measure musical qualities

| Quality | What studies say | Tag | Measurable proxy |
|---|---|---|---|
| **Natural transitions** | Medina-Gray: seam "smoothness" is judged on "meter, timbre, pitch, volume, and abruptness" | [R] | Per seam: meter continuity (does the downbeat land on the grid), loudness jump in LUFS, spectral-centroid jump, pitch-class overlap of the last and first bars, and onset abruptness |
| **Switch on musical boundaries** | ABZU (GDC 2017): sync points "usually at the beginning of each measure"; Phillips: segments carry markers at "convenient and logical points" | [D] | Every switch lands on a bar, and ideally on a 4/8-bar phrase |
| **Tension and release** | Farbood 2012: tension follows loudness, harmony, pitch height, onset frequency and tempo. Harmony integrates over about 22 s, other features over 1–4 s. Loudness weighs most | [M] | A curve of loudness, onset density and centroid per bar. Each tier ramp should rise and resolve at the cadence |
| **Peaks and chills** | Chills accompany the "entrance of new voices or instruments" and loudness rises (Grewe 2007). Dopamine rises in the caudate in the about 15 s *before* the peak, and in the nucleus accumbens at it (Salimpoor 2011) | [M] | Put the new instrument entry at the tier-up boundary. The 2–4 bars before it should build (density and loudness rising) |
| **Repetition vs variety** | Margulis: repetition is "a quasi-magical agent of musicalisation". Huron's ITPRA: expectation drives emotion; prediction success is itself rewarding | [R] | Motif recurrence: about 50–75% of bars restate a motif (opinion), with one novel element per 4–8 bars |
| **Groove** | inverted U on syncopation (Witek) | [M] | A syncopation index per tier, plus EGQ ratings in playtests |

**Quotes.**
- Medina-Gray 2019, Analyzing Modular Smoothness in Video Game Music. *Music Theory
  Online* 25.3: the article introduces "a method for analyzing smoothness at modular
  seams through a particular focus on the musical aspects of meter, timbre, pitch,
  volume, and abruptness". https://www.mtosmt.org/ojs/index.php/mto/article/view/492
- Farbood 2012, A Parametric, Temporal Model of Musical Tension. *Music Perception*
  29(4):387–428. https://bpb-us-e1.wpmucdn.com/wp.nyu.edu/dist/f/11865/files/2020/08/Farbood_2012_Musical_Tension.pdf
- Farbood & Upham 2013: "The optimal time windows for harmony were considerably longer,
  around 22 seconds". https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2013.00998/pdf
- Grewe, Nagel, Kopiez & Altenmüller 2007, Listening to music as a re-creative process.
  *Music Perception* 24(3):297–314. https://sysmus17.qmul.ac.uk/wp-content/uploads/2017/08/bannister_chills.pdf
  (secondary summary)
- Salimpoor et al. 2011, Anatomically distinct dopamine release during anticipation and
  experience of peak emotion to music. *Nature Neuroscience* 14:257–262.
  https://www.zlab.mcgill.ca/publications/docs/salimpoor_2011_nn.pdf
- Blood & Zatorre 2001. *PNAS* 98:11818. https://pmc.ncbi.nlm.nih.gov/articles/PMC58814
- Margulis, Why repetition can turn almost anything into music (Aeon), and *On Repeat*
  (OUP 2014). https://aeon.co/essays/why-repetition-can-turn-almost-anything-into-music
- Huron 2006, *Sweet Anticipation* (MIT Press).
- Phillips, GDC 2021. https://www.gamedeveloper.com/audio/horizontal-resequencing-and-dynamic-transitions-for-game-music-composers-from-spyder-to-sackboy-gdc-2021-
- ABZU at GDC 2017. https://gamedeveloper.com/audio/video-game-music-systems-at-gdc-2017-tools-and-tips-for-composers

## 10. Playtest protocol for what can't be measured by script

Proposal. 6–10 players who are not developers, on their own phones, with wired or
built-in audio and one Bluetooth case noted separately.

1. **Calibration first.** A tap-along, then log the signed median offset, so later
   numbers are latency-free.
2. **Log per tap:** signed delta after correction, limb, and the note's metric position
   (beat, off-beat, clave stroke).
3. **Log per phrase:** pass or fail, tier, retries, and the time to the next voluntary retry.
4. **After each level, 7-point ratings:** EGQ "urge to move" and "pleasure"; "the taps
   matched the music"; "the dancer moved with the music"; "the change into the next
   section sounded natural".
5. **Pass bars (proposal):** median corrected delta within ±25 ms; "taps matched the
   music" median ≥ 5/7; transition naturalness ≥ 5/7; a tier-0–2 pass rate of 85–90%.
6. **A/B test** one variable per session: current chart vs onset-aligned chart, or
   offset on vs off.

## Top findings in one list

1. Humans tap early (NMA, tens of ms). Logged "late" bias is pipeline latency.
2. Phone touch latency is 50–200 ms. Android Chrome Web Audio is 80 to 300+ ms on cheap
   phones. Bluetooth adds 150–300 ms.
3. `outputLatency` exists (Baseline 2025) but isn't reliable everywhere, so calibration
   is required.
4. Our ±75/±180 windows are already among the widest: wider than Arcaea (25/50/100),
   osu! OD5 (50/100/150) and Rhythm Quest (125), and short only of osu! OD0's ±200.
   Center them, don't widen them.
5. AV simultaneity is asymmetric: visual lead is fine up to about 100+ ms, audio lead
   only about 50–80 ms. Let the dancer's accent pose lead slightly.
6. The groove inverted U: medium syncopation is best (Witek 2014).
7. Feet to beats, hands to subdivisions (Toiviainen 2010; Burger 2013).
8. Cha-cha's 2-3-4&1 fits the 170 ms cross-thumb floor at 136–160 BPM. The spec's 250 ms
   text forbids it.
9. Chills come at instrument entries and loudness rises. Anticipation peaks about 15 s
   before (Grewe 2007; Salimpoor 2011).
10. Engagement peaked at about 90% success (Lomas 2013). Learning is fastest at about 85%
    (Wilson 2019).
