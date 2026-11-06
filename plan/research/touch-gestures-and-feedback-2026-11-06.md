# Touch gestures and text-free feedback

Research for the owner's sixth-round notes, 2026-11-06. Desk research only: nothing here was tried on a phone, and no code changed.

**How to read the labels**

| Label | Meaning |
|---|---|
| **[O]** | I read it in this repository |
| **[P]** | I loaded and read the page or source myself |
| **[X]** | I saw it only as a search excerpt. The page itself wasn't read, or wouldn't load |
| **[C]** | I computed it here from repository data |
| **[J]** | My judgement. Not evidence |

Many pages failed to load (connection resets): Sekaipedia, Iwata Asks, the University of Washington recognizer pages, the $1 and CLC papers, the Android docs and Smashing Magazine. Those are [X]. Fan wikis are the only source for most rhythm-game details, and no developer has published the thresholds.

## The proposal in brief

- **The tap never waits.** A required tap is judged the instant the thumb lands, as it is today. Everything else is a decoration on that same touch, so a misread gesture can never cost a required note. [O, J]
- **The last note of a phrase is the stage.** On the lawn, notes are 281 to 586 ms apart, which leaves no room for anything mid-phrase. Only the last note has room, because the next required tap is 3.5 to 4.3 seconds away. [C]
- **The note tells you the move.** A hand note offers a wave (a semi-circle). A foot note offers a stomp (up and down). Any note can spin (sideways). Nothing to memorise.
- **Each shape is a list of headings,** not a template match. The game knows which shape it offered, so it only asks "did this stroke do that?", and can light each leg of the shape as the thumb finishes it.
- **Gestures score pass or nothing.** Timing precision stays with the tap. Every touch rhythm game I could check does some version of this.
- **The W needs its own moment.** My rough estimate is 1.1 to 2.5 beats at 160 BPM, so it spills over the start of the next call. The clean answer is a "break phrase", the opponent's solo answered by the player's, which changes the required chart. That's the owner's decision.
- **Timing feedback uses the ring's own shape.** The approach ring already works like a clock. Early leaves it visibly unfinished and shrinking; late overshoots it with a tail, swelling outward; perfect closes it with a star. All three remain distinct without colour.
- **Almost all gameplay text can go.** The list and replacements are in Part 6. What stays: the big end-of-level word (the owner's answer), errors, the wordmark, numbers, and hidden labels for screen readers.

## Part 1: what the game does today [O]

| Fact | Where |
|---|---|
| Four zones fill the band from 65% to 97% of the height, split at 81% and at the middle. A touch is resolved by zone, not by the icon | `thumb_layout.dart` |
| Tap judged on pointer-down: perfect within ±75 ms, accepted within ±180 ms | `rhythm.dart`, `garden_page.dart` line 685 |
| Flick: the same pointer travels at least 24 logical pixels and lifts within 400 ms of the press. Dominant axis picks one of four directions. **Any direction earns credit**; the direction only selects a musical ornament | `touch_gesture.dart`, `rhythm.dart` |
| A note offers a flick only if the next note is at least 800 ms away (180 + 180 + 400 + 40), or it's the last note | `garden_session.dart` `_flourishDestination` |
| The listener has down, up and cancel handlers, with **no pointer-move handler**. Paths can't be seen at all today | `garden_page.dart` lines 683-713 |
| The offer is a 16-pixel `Icons.open_with` on the cue, then "FLICK FOR STYLE" in 8-point type after the tap | `garden_page.dart` lines 970-990 |
| Pizazz is 100 per credited flick, deduplicated per phrase and note | `rhythm.dart`, `garden_session.dart` |
| Autoplay calls `flourishGesture` directly, bypassing the gesture code | `party_autoplay.dart` |
| Mācron has 16 frames, including `spin_front`, `profile`, `spin_rear`. Challengers have 20, including `turn_in`, `turn_out`. Neither has a wave or stomp drawing | `party_sprites.dart`, `challenger_choreography.dart` |
| The spec's requirement title is already "Catchy call and response without text instruction" | `openspec/specs/rhythm-combat/spec.md` line 118 |

Three problems found while reading:

1. **Late flicks are cut off at speed.** `_prepareCycle` clears `_judge` when the phrase rolls over, 1.25 beats after the lawn's last note. `flourishGesture` then refuses. A tap 180 ms late has only 289 ms of its 400 ms left at 160 BPM, and it falls short from 136 BPM up. The code handles this only for the winning phrase (the comment in `advance()`). This hasn't been run, but the arithmetic is simple. Gestures on the last note need a ledger that outlives the judge. [O, C]
2. **The spec has drifted from the code.** The spec says 36 pixels, 300 ms, a destination swipe and 500 ms clearance. The code and `plan/input-research.md` say 24 pixels, 400 ms, any direction and 800 ms. [O]
3. **Required taps use the audio clock when the handler runs, not the event's time.** The spec's scenario says judgments "compare event timestamps to audible song time", and the browser does supply a timestamp ([Flutter's `pointer_binding.dart`](https://raw.githubusercontent.com/flutter/flutter/master/engine/src/flutter/lib/web_ui/lib/src/engine/pointer_binding.dart), [P]). A stalled frame would therefore move a tap late. Not measured. Separate from this work, but worth a test. [O]

## Part 2: what the time allows

### The lawn, `levels/pool-garden.json` [C]

Offsets in beats: `0, 1, 1.75, 3, 4, 5, 5.75, 6.75`. Tempos 128 to 160 BPM (`assets/music/scores/pool_swing.json`). One beat is 469 ms at 128 and 375 ms at 160.

| Note | Gap to next (beats) | Gap at 128 / 144 / 160 (ms) | Left after an on-time tap, before the next note can be accepted, at 128 / 160 | Left after a tap 180 ms late, at 128 / 160 |
|---|---|---|---|---|
| 0 | 1 | 469 / 417 / 375 | 289 / 195 | 109 / 15 |
| 1 | 0.75 | 352 / 312 / 281 | 172 / 101 | **-8 / -79** |
| 2 | 1.25 | 586 / 521 / 469 | 406 / 289 | 226 / 109 |
| 3 | 1 | 469 / 417 / 375 | 289 / 195 | 109 / 15 |
| 4 | 1 | 469 / 417 / 375 | 289 / 195 | 109 / 15 |
| 5 | 0.75 | 352 / 312 / 281 | 172 / 101 | **-8 / -79** |
| 6 | 1 | 469 / 417 / 375 | 289 / 195 | 109 / 15 |
| 7, last | 1.25 to the next call | 586 / 521 / 469 | Next **required** tap is 9.25 beats away: 4,336 / 3,854 / 3,469 ms | Same |

Note the 0.75-beat gaps: at those, two notes' acceptance windows overlap once a tap runs late. Nothing can be added there.

| Level | BPM | Longest mid-phrase gap | Last note to next call | Last note to next required tap |
|---|---|---|---|---|
| `garden` | 92-104 | 1.5 beats, 978-865 ms | Same 1.5 beats | 9.5 beats, 6.2-5.5 s |
| `bar` | 100-112 | 1.5 beats, 900-804 ms | Same 1.5 beats | 9.5 beats, 5.7-5.1 s |
| `pool-garden` | 128-160 | 1.25 beats, 586-469 ms | 1.25 beats, 586-469 ms | 9.25 beats, 4.3-3.5 s |

Which limb the last note uses, so which move it can offer: [O]

| Level | Base, then variants |
|---|---|
| `garden` | left hand; left hand, right foot, right foot, right hand, left foot |
| `bar` | right foot; right hand, left foot, left foot, left hand, right foot |
| `pool-garden` | right hand; right foot, left hand, right hand, right foot, left hand |

All three levels get a mix of hands and feet, so wave and stomp both come up without changing a chart.

### How long a thumb takes to draw a shape

**Weak evidence, so treat these as a starting guess to measure.** The usual model is CLC ([Cao and Zhai 2007](https://dl.acm.org/doi/pdf/10.1145/1240624.1240850)): add up the time for each straight line, T = 68.8 · L^0.469, and for each curve; corners cost nothing of their own. The constants come from an excerpt of [Cao's later review](https://caoxiang.net/papers/fthci_GestureReview.pdf). I'm assuming L is in millimetres. [X] Its limits are:

- It was fitted to **pens, not thumbs**.
- It ranked gestures well (R² above .90) but [was off by 30%, and over-predicted practised unistrokes by more than 40%](https://gery.casiez.net/publications/Interact2011-vatavu.pdf). [X]
- A later hand-gesture study reported that [corners do cost time](https://link.springer.com/chapter/10.1007/978-3-319-22698-9_38). [X]

Scale: a phone 390 logical pixels wide is roughly 65-70 mm, so about 0.17 mm per pixel. [J] My range is the model's figure × 0.6 to × 1.3.

| Shape | Assumed size | Model | Range [C, J] | In beats at 128 | In beats at 160 |
|---|---|---|---|---|---|
| Spin: one sideways leg | 40 px, 7 mm | 171 ms | 100-220 ms | 0.2-0.5 | 0.3-0.6 |
| Stomp: up and down | Two legs of 30 px, 5 mm | 292 ms | 175-380 ms | 0.4-0.8 | 0.5-1.0 |
| Wave: semi-circle | 94 px path, 16 mm | 252 ms as a line; curves run slower | 150-500 ms | 0.3-1.1 | 0.4-1.3 |
| Zigzag of three legs | Legs of 45 px, 8 mm | 534 ms | 320-700 ms | 0.7-1.5 | 0.9-1.9 |
| **W: four legs** | Legs of 45 px, 8 mm | 712 ms | **430-930 ms** | 0.9-2.0 | **1.1-2.5** |

### What this means [J]

| Limit | Value |
|---|---|
| Lawn, mid-phrase | **No gestures.** Note 2's 586 ms at 128 BPM would still fall short of the existing 800 ms rule, and it's shorter at every other tier |
| Lawn, last note, ending before the next call starts | One leg comfortably. A stomp only for fast players |
| Lawn, last note, allowed to run into the call | Stomp and wave are fine with a 2-beat limit (938-750 ms). W needs about 3 beats (1,406-1,125 ms) |
| Garden and bar, mid-phrase | The flick stays where it is (notes 3 and 7). Longer shapes on the last note only, to keep one simple rule |
| Later levels | The owner wants tempo to keep rising. Time in beats grows with tempo, so the W only gets harder |

Running into the next call costs nothing in score. It does cost attention, because the call's first note arrives 1.25 beats after the last response note, and its cue appears 2 beats early. So the player is watching a thumb while the next call begins. Skilled players can choose that for a stomp. A W takes up about the first three of the call's eight notes' worth of time, which is why it needs the break phrase (Part 5).

The same problem applies to the opponent's demonstration, and is worse. A W shown on the call's last note runs into the player's first required taps. **The opponent can't show a W in the normal chart without overlapping the player's turn.** The owner's fourth round accepted a spin overflowing the turn, but a spin doesn't have to be read and copied.

## Part 3: evidence from other games

### Touch rhythm games

| Game | How it's shown and played | What's judged | Grade | Lesson |
|---|---|---|---|---|
| **Project Sekai** | [Flick notes with arrows. Directional flicks show left or right; plain forward arrows accept any direction](https://www.sekaipedia.org/wiki/Settings). A flick is [registered when swiped, and often must start slightly early. Slight diagonals count if they lean the right way](https://note.com/t_note_1226/n/nf1f9a9ec4169?hl=en) | [Perfect ±41.7, Great to ±83.3, Good to ±108.3 ms](https://www.sekaipedia.org/wiki/Rhythm_game_mechanics). [Flicks only Perfect, Great or Miss](https://projectsekai.fandom.com/f/p/4400000000000111016). Wrong direction [gets Great, not Miss](https://x.com/pjsekai_eng/status/1552565386528587776). Trace notes: any contact counts | X | Directions are tolerant, and a wrong one is only a smaller reward |
| **Arcaea** | Arcs are held and followed | Tap: [shiny Pure ≤25, Pure ≤50, Far ≤100 ms](https://arcaea.miraheze.org/wiki/Gameplay_and_scoring), with [early or late named inside the grade](https://en.namu.wiki/w/%ED%8C%90%EC%A0%95(%EB%A6%AC%EB%93%AC%20%EA%B2%8C%EC%9E%84)). [Arcs only Pure or Lost](https://arcaea.fandom.com/wiki/Scoring) | X | Precision for taps, pass or fail for paths |
| **Cytus II** | [Drag: head note with arrow, small follow-up notes. Flick: tap then horizontal movement](https://cytus.fandom.com/wiki/Cytus_II). Flicks are held back to harder difficulties | [Drag and flick only Perfect or Miss](https://en.namu.wiki/w/Cytus%20II) | X | New shapes appear only at higher difficulty |
| **Phigros** | Tap, hold, flick and drag | [Perfect ±80 ms, Good ±160, Bad ±180. Flick and drag only Perfect or Miss](https://phigros.fandom.com/wiki/Game_Mechanics). One source says you ["don't have to worry too much about timing"](https://en.namu.wiki/w/Phigros/%EC%8B%9C%EC%8A%A4%ED%85%9C) on flicks. Sources disagree on drag | X | Windows very close to ours; generous for a shipped game |
| **Deemo** | [Yellow slide notes register only by motion; a still finger doesn't count. Top grade shows an orange glow](https://deemo.fandom.com/wiki/Gameplay) | Tiers by closeness | X | Colour and glow can carry the grade |
| **VOEZ** | [Swipe notes: large blue arrow, swipe that way. A wiki says a tap or flick counts as a hit, so a swipe can't be missed by flicking](https://en.namu.wiki/w/VOEZ/%EC%8B%9C%EC%8A%A4%ED%85%9C) | Pre-release: Perfect, Great, Ok, Miss | X | Forgiving |
| **osu!** (nothing specific to osu!droid was found) | [Slider: tap the head, then keep inside a follow circle larger than the ball](https://osu.ppy.sh/wiki/en/Gameplay/Hit_object/Slider) | 300, 100, 50 | X | The tolerance around a path is bigger than what's drawn |
| **Muse Dash** | Two lanes | [Perfect about ±50 ms, Great to about ±130 in a fan mod's measure](https://github.com/Azn9/MDAccuracyIndicatorMod). [Early/late shown on Greats, never on Misses; finer grading is opt-in](https://steamcommunity.com/sharedfiles/filedetails/?id=2331971286) | X | Show early and late only when they're useful. Don't explain a miss |
| **Elite Beat Agents** | [Ring closes on a marker. Phrase markers: tap the head, hold and follow a ball along a trail; an arrow marks a turnaround. Spin markers fill a meter](https://strategywiki.org/wiki/Elite_Beat_Agents/Gameplay) | 300, 100, 50 | X | A moving ball shows the speed as well as the path. Best teaching model for a trace |
| **Project Diva f (Vita)** | [Star notes: swipe anywhere on the screen. The note's shape names the input](https://projectdiva.wiki/wiki/Introduction_to_Project_DIVA). Players [couldn't change it, and a help item allowing any button capped the rank](https://gamefaqs.gamespot.com/vita/668736-hatsune-miku-project-diva-f/answers/367661-can-you-change-from-the-touch-screen-controls). In Mega Mix+, [early/late is a subtle lighting tilt that players find hard to notice](https://steamcommunity.com/app/1761390/discussions/0/3422185980116444483) | Cool, Fine and lower | X | Location-free swipes work. Subtle early/late cues fail |
| **Rhythm Heaven (DS)** | Tap, hold, flick, slide. [The team tried an edge tap first, judged it too hard, moved to the flick, and found the sound gave a good sense of timing](https://iwataasks.nintendo.com/interviews/ds/rhythm-heaven/0/2/). [About 2-3 months of research and 6 of adapting](https://en.wikipedia.org/wiki/Rhythm_Heaven_(video_game)), from a garbled excerpt | Reviews: [picky about registering a flick; movements under a certain speed don't count; "is your rhythm off, or did the game not pick up your flick?"](http://www.honestgamers.com/12135/ds/rhythm-heaven/review.html) | X | **The strongest warning here.** Players must be able to tell "the game didn't hear me" from "I was off" |
| **Rhythm Heaven Megamix, Fever** | [Megamix's stylus mode keeps tap and hold but drops the flick. Fever dropped motion for more accurate buttons](https://en.wikipedia.org/wiki/Rhythm_Heaven_Megamix) | | X | The series moved away from flicks when accuracy mattered |
| **Patapon** | [A pulsing border gives the rhythm. The Patapons sing the command back](https://blog.playstation.com/2017/08/01/marching-to-the-beat-of-their-own-drum-an-interview-with-the-creators-of-patapon/). Producer: ["the most satisfying stimulus usually comes from the sound and music"](https://www.gamedeveloper.com/audio/the-rhythm-of-creation-hiroyuki-kotani-and-patapon). The irregular "don, dodon, dodon" was too hard for many | [Off-beat input loses the fever](https://en.wikipedia.org/wiki/Patapon) | X | Sound first. The answering sound *is* the reward |
| **Space Channel 5** | [Simon Says routine with a tiny vocabulary: directions plus "chu". The team stripped all effects to check that presses mapped to music](https://en.wikipedia.org/wiki/Space_Channel_5) | Rating rises and falls | X | Few words, repeated. Test it without effects first |
| **Dance Central** (extra) | [Flashcards show the opening pose. Complex moves get two images, and the critical body parts are filled in](https://alexgoldgames.squarespace.com/dance-central) | Per move | X, first-hand | A filled-in limb says what matters without a word |
| **Wizards Unite** (extra, not rhythm) | [Traced glyphs graded by speed and accuracy, with a green tolerance band](https://wizardsunite.gamepress.gg/beginners/spell-trace-practice-tool). [Guides say speed counts more; a glyph too far off shows "Spell Incomplete"](https://www.imore.com/how-cast-masterful-spells-harry-potter-wizards-unite) | Four grades | X | Mobile tracing with a visible corridor has shipped at mass scale |

**Patterns I take from this [J]:**

1. **Gesture notes get coarser judgment than taps.** Sekai, Arcaea, Cytus II and Phigros all do it. This is the most consistent finding here.
2. **Shape of the note names the input.** Sekai, VOEZ and Diva all use an arrow or star. Ours is one small icon on the cue and needs to become a real glyph.
3. **Tolerance is bigger than what's drawn.** osu!, Wizards Unite and Sekai's leaning diagonals.
4. **Complex gestures arrive with higher difficulty,** not all at once.
5. **The failure to avoid is Rhythm Heaven DS's:** a silent non-registration that looks like a timing error.

I found no game that asks for a W-like trace from a thumb on a fixed zone in a rhythm game at 160 BPM. **The W has no precedent I can point to.** Elite Beat Agents' turnarounds, with a stylus on a dedicated marker, are the closest.

### Learning timing by feel

The owner wants players to "improve by feel". The research I found is adjacent, not direct.

| Finding | Source | Grade |
|---|---|---|
| Tapping to sound is more accurate than tapping to flashes. **Moving visuals pace far better than static flashes** | [Repp and Su review](https://link.springer.com/article/10.3758/s13423-012-0371-2), [Comstock et al.](https://www.researchgate.net/publication/325927835_Sensorimotor_synchronization_to_auditory_and_visual_rhythms_behavioral_and_neural_differences) | X |
| Learning from visual feedback fell away more when feedback was removed; audio-based learning lasted better. The authors say modality and information type were confounded earlier | [Bimanual coordination study](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4764518/) | X, not rhythm tapping as such |
| Feedback should fade so learners build their own timing | [A study guide](https://fiveable.me/motor-learning-control/unit-13/timing-rhythm-movement/study-guide/c7p0yizjBMUTcWF5), a general claim | X, weak |
| Keep the signed error for feedback, don't silently change windows | [Developer article](https://dev.to/skywalker_2de7de5f97df567/building-fair-rhythm-game-judgement-windows-in-javascript-1og9) | X, weak |

**I found no study testing early/late icons in a game.** My reading [J]: the moving ring and the music do the teaching. The grade mark is a small correction after the fact, so it should show direction and rough size at a glance and stay out of the way.

## Part 4: gesture recognition

### Starting a drag without misfiring a tap

| Evidence | Grade |
|---|---|
| [Flutter's `kTouchSlop` is 18 pixels. It began at 8 and was raised because targets were too hard to hit](https://api.flutter.dev/flutter/gestures/kTouchSlop-constant.html) | P |
| Android docs [describe touch slop and a minimum fling velocity](https://developer.android.com/develop/ui/views/touch-and-input/gestures/viewgroup). The commonly quoted 8 dp wasn't confirmed | X |
| Xbox guideline 107: [controls should activate on release, **except** where activating on the press is essential, like a piano](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/107). A rhythm tap is that exception | P |

This problem is **already solved by the game's structure.** The `Listener` sits outside Flutter's gesture arena, so a tap counts at the press, with no waiting to see whether it becomes a drag. [O] A drag can't steal a tap, and an unrecognised drag loses nothing. The spec's "holding, releasing, or optional swiping never creates another tap" stays exactly as is.

The remaining misfire is the other way: a sloppy tap earning a gesture credit. Today's 24 pixels sits above Flutter's 18. Keep it.

### Which recognizer

| Option | Evidence | Fit |
|---|---|---|
| **$1 Unistroke** | [About 100 lines, no training. It can't distinguish gestures whose identity depends on orientation, aspect ratio or location, because it's rotation-invariant. Resampling discards timing](https://faculty.washington.edu/wobbrock/pubs/uist-07.01.pdf). [Protractor's paper says it distorts narrow gestures](https://perso.lisn.upsaclay.fr/anab/teaching/M2R-2011/5-gestures/protractor-chi2010.pdf) [X] | Poor. Sideways versus up-down is decided by orientation. It's also a classifier run on a finished stroke |
| **$P, $P+, $Q** | [Ignores stroke number, **order and direction**. Over 99% accuracy with 5+ samples](https://depts.washington.edu/acelab/proj/dollar/pdollar.html). [$Q is optimised for low-power devices](https://depts.washington.edu/acelab/proj/dollar/index.html) [X] | Poor. Direction is the point here |
| **Protractor** | [Can be sensitive to orientation; handles different aspect ratios](https://perso.lisn.upsaclay.fr/anab/teaching/M2R-2011/5-gestures/protractor-chi2010.pdf) [X] | Usable, but solves a harder problem than we have |
| **Directional tokens** | The $1 paper mentions [Siger, which turns strokes into directional tokens](https://faculty.washington.edu/wobbrock/pubs/uist-07.01.pdf) [X]. Marking menus: [error rates stay under 10% up to 8 directions at 2 levels, and rise with both breadth and depth](https://www.billbuxton.com/MMExpert.html) [X]. A later source: [multi-stroke marks reached depth 3 at breadth 8 with 93% accuracy](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/7603633) [X] | **Best fit** |

**Those marking-menu numbers are for pens and mice.** I found no thumb data. Still, they give a shape for the ladder: four directions, not eight, and more legs is the real cost. A W has four legs, which is past where the pen studies stopped. [J]

### Heading-sequence matching, and why [J]

**The game only needs to verify, not to classify.** It knows what the note offered. That removes confusion between shapes, the hard part of every recognizer above.

Other reasons:

- Direction counts.
- Works live: each finished leg can light up, which addresses the Rhythm Heaven problem directly.
- A few lines of pure code, deterministic, and easy to test with listed points.
- Any size counts, within limits, so a small W from a cramped hand is fine.

**Starting tolerances, all to be tuned on phones:**

| Rule | Starting value | Why |
|---|---|---|
| A leg starts | After 18 px of travel | Flutter's slop |
| Heading | Four 90° sectors, so ±45° around a direction, with hysteresis at the boundary | Sekai accepts leaning swipes [X] |
| A new leg | The direction changes by more than 60° and holds for 12 px | Ignores thumb wobble |
| Spin | One sideways leg, at least 24 px, allowed to curve | A thumb moving sideways swings in an arc, so it mustn't be judged as a straight line |
| Stomp | Two opposite vertical legs, each at least 18 px. Either order | Up first is natural from a foot zone near the bottom |
| Wave | Heading keeps turning the same way through at least 120°, path at least 48 px. Either rotation | Must exceed the thumb's natural curve when moving sideways, which I'd guess is 30-60° |
| W or zigzag | Four alternating vertical legs with net sideways travel. Either sideways direction | Left-handed and one-handed players |
| Deadline | In **beats** from the accepted tap: spin as today's 400 ms, stomp and wave 2 beats, W 3 beats | |
| Stops being tracked | Pointer up, cancel or deadline | |

### Thumb reach

| Evidence | Grade |
|---|---|
| [Of 780 people touching a phone: 49% one-handed, 36% cradled, 15% two hands. People change grip often](https://www.uxmatters.com/mt/archives/2014/09/insights-on-switching-centering-and-gestures-for-touchscreens.php) (Hoober, 2013, figures quoted by several secondary sources) | X |
| Trudeau et al.: [sideways-swinging thumb movement (adduction and abduction) beat bending movement (flexion and extension). Outward beat inward. Smaller phones did better](https://journals.sagepub.com/doi/10.1177/0018720811423660). This was reciprocal tapping with 20 people, not drawing | X |
| Trudeau and Dennerlein: [deep thumb flexion is the main cause of poor performance. Frequent targets should sit away from the base of the thumb](https://stacks.cdc.gov/view/cdc/224411) | X |
| [Thumb reach is predictable from device size, grip and hand](https://www.researchgate.net/publication/266655612_Modeling_the_functional_area_of_the_thumb_on_mobile_touchscreen_surfaces) (Bergstrom-Lehtovirta and Oulasvirta, 2014), and [comfortable reach differs from maximum reach](https://nhenze.net/uploads/Fingers%E2%80%99-Range-and-Comfortable-Area-for-One-Handed-Smartphone-Interaction-Beyond-the-Touchscreen.pdf) | X, **no millimetre figures obtained** |
| Vibration: [no iOS Safari version supports it](https://caniuse.com/mdn-api_navigator_vibrate). Haptics can't carry feedback | X |

What this suggests [J]:

- **Sideways is the easiest thumb gesture, and up-and-down is harder.** That's the ladder's order: spin before stomp, and a W bends the thumb four times.
- **Traces should head toward the screen's middle.** The owner's example does this: left hand tap, W to the right. A left zone's W goes right; a right zone's goes left. That moves away from the side edges and keeps the moving thumb from covering its own path, for a two-thumb grip. A one-handed player will sometimes have to draw toward the base of the thumb, the weakest place, so both directions earn credit.
- **Size limit.** I couldn't get millimetre figures. Start with a 96 px wide W (about 16 mm) and let any size above the minimum count. Then measure.

### Browser conflicts

| Fact | Grade |
|---|---|
| Flutter's full-page mode [sets `touch-action: none` on the host, "to prevent the browser from doing any native touch handling"](https://raw.githubusercontent.com/flutter/flutter/master/engine/src/flutter/lib/web_ui/lib/src/engine/view_embedder/embedding_strategy/full_page_embedding_strategy.dart). The built `build/web/main.dart.js` has the same call. So nothing is needed for scroll or zoom. `web/index.html` needs no change | P, O |
| [`touch-action` governs panning and zooming; the app gets `pointercancel` when the browser takes over](https://developer.mozilla.org/en-US/docs/Web/CSS/touch-action) | P |
| Flutter uses [coalesced pointer moves when available, and the DOM event's timestamp. On iOS it sends cancels for touches abandoned to native gestures](https://raw.githubusercontent.com/flutter/flutter/master/engine/src/flutter/lib/web_ui/lib/src/engine/pointer_binding.dart) | P (`master`, not this project's exact version) |
| **iOS edge swipe back:** `touch-action` isn't what these sources rely on. They use `preventDefault` on `touchstart` near the edge, and [it can still lose when the page is scrolling](https://lists.w3.org/Archives/Public/public-webapps-github/2025May/0267.html). Sources conflict on standalone mode. No Apple statement found | X, anecdotal |
| **Android:** [mandatory system gestures can't be opted out of; other gesture areas can be excluded natively, up to 200 dp per edge; taps are guaranteed to reach the window inside gesture insets](https://developer.android.com/reference/android/view/WindowInsets.Type). Those exclusions are a native View API, and I found no web equivalent | X, plus J |
| Latency: [noticeable difference about 69 ms for tapping and 11 ms for dragging](https://www.academia.edu/71207892/How_Much_Faster_is_Fast_Enough) on direct touch; other papers differ | X |
| Native Flutter [waits for the next frame on touch](https://github.com/flutter/flutter/issues/110431), and iOS has had an extra frame. **I found no measurement of mobile-browser touch latency or Flutter web's** | X |

What this suggests [J]:

- **Nothing will stop the home-bar swipe or the edge-back swipe.** So: judge the tap, then simply don't track gestures that start in a side or bottom band of 24 px. If the system takes the touch, `pointercancel` voids the gesture silently. The tap is already safe.
- **The zones go down to 97% of the height.** An up-first stomp and inward traces keep away from the bottom edge.
- **The trail will visibly lag the thumb.** No phone reaches 11 ms. The gap is fine as long as the trail leads the eye to the guide, and nothing should be judged from the drawn trail.
- **Coalesced events are good news:** the recogniser sees more points than frames.
- **Read `pointermove` on `Listener`, not `GestureDetector`.** Staying out of the arena preserves the instant tap.

## Part 5: the proposal [J]

### The vocabulary ladder

Lowest first. Each rung is a shape; what it means comes from the limb and the level.

| Rung | Gesture | Dance meaning | Who | Where | Art needed |
|---|---|---|---|---|---|
| 0 | **Tap** on a required note | Limb move | Everyone | All notes | Exists |
| 1 | **Optional tap** (grace note) | Small clap or stamp | Anyone | Garden and bar's low tiers only. **None on the lawn** per the progression report's table | 0, plus small sounds |
| 2 | **Sideways drag** (today's flick) | **Spin.** Left or right chooses the way | Anyone | Any note already eligible | **0 frames for Mācron** (`spin_front`, `profile`, `spin_rear`), opponents use `turn_in`, `turn_out` |
| 3 | **Up and down,** from a foot note | **Stomp** | Warmed-up players, tier 1+ | Last note | Mācron 2 (knee up, impact), opponents 2 each. Could reuse `left_foot`, `right_foot` for the first pass |
| 3 | **Semi-circle,** from a hand note | **Hand wave** | Warmed-up players, tier 1+ | Last note | Mācron 2-3 per hand, opponents 2-3 |
| 4 | **Style move,** one per level | See below | Skilled, tier 2+ | Last note | 3-5 per dancer |
| 5 | **Mācron's signature step** | **From the salsa teacher, on video. Nothing proposed here.** Same input limits. The interview's beginner, confident and showing-off versions could map to rungs | | | Depends on footage. The footage plan warns Mācron is the hard part |
| 6 | **W or long trace** | Showing off | Experts | Break phrases at tier 3+ | 2-4 per dancer, plus the ribbon, plus the break phrase's music |

**Why a sideways drag and a flick are the same input.** Physically they're one movement at different speeds. If flick and drag were separate, players would have to guess which one they did. So every rung 2 stroke is the same recognizer: a short fast one and a slow one both count, as long as they end before the deadline.

**Today's up and down flicks** on mid-phrase notes still work and still earn credit. Up-and-down *flicks* give an ornament. Up-and-down *both ways* gives a stomp.

**Rule for animations ("Animations match the gesture").** Mācron's tap move starts at the press, as now. Each finished leg triggers its pose, so a W produces four visible beats of motion. On success the pose resolves into the finish. On failure he simply finishes his tap move. [J]

### Style moves per level

**Every entry here is a candidate. A dancer must check it. None of these has been checked.**

| Level | Style, as recorded in the plan | Candidate | Gesture | Source for the candidate | Who checks |
|---|---|---|---|---|---|
| `garden` | Cumbia per the Gatekeeper's drawings; the music brief is salsa-led, an open question [O] | **Arrastre:** the dragged foot | Long slow sideways, on a foot note | `plan/research/gatekeeper-dance-2026-11-02.md` documents it | Salsa teacher, who is already being asked about cumbia at 92 BPM |
| `garden` | Same | **Circular arm styling** | Full arc, on a hand note | Same document | Same |
| `bar` | "Swag", Latin-electronic over cumbia. No agreed dance vocabulary found [O] | **Shake the shaker:** in-character gesture, not a dance step | Four quick up-and-down legs | The storyboard's bartender and shaker | Owner: it's character, not technique |
| `pool-garden` | Savoy-style Lindy Hop and Charleston [O] | **Charleston kick** | Quick V on a foot note | `plan/research/swing-duet-research-2026-11-05.md` | Swing reviewer |
| `pool-garden` | Same | **Swing-out swap:** partners change ends | Long arc | Same, and the progression report's rung 5 | Swing reviewer |
| `pool-garden` | Same | **W as alternating kicks** | W, in the break | My stretch: treat this one with suspicion | Swing reviewer |

The swing research notes that dancers simplify as tempo rises. So a rule of "fast levels get sharp, short moves" has a real-world basis. It also means the W at 160 BPM is the wrong way round for this style unless a reviewer says otherwise.

### Break phrases: the only clean home for the W

An ordinary phrase has 8 notes spread across 8 beats. A break phrase would stop the required notes at beat 4 or 5:

```
Call:     note note note note note | opponent's solo, with ribbon, beats 5-8
Response: note note note note note | player's free 3-4 beats: W, or nothing, music fills
```

At 160 BPM four beats is 1,500 ms, which covers my W range. Lindy Hop's breakaway is a real precedent for the idea of a solo break.

**Costs:**
- `FightChart.validate` requires every variant to keep the note count. This must change.
- `requiredHits` uses a ratio of note count, so a shorter phrase changes its meaning.
- The music must fill the gap. If the player ignores the W, they hear a good break, not a hole.
- It reopens the "Required notes stay fixed" rule.

**Recommendation:** Ship rungs 2 and 3 first. Decide the W only after phone measurements.

### Judgment and scoring

| Question | Rule |
|---|---|
| A gesture and a required tap on one note | The tap is judged at the press, fully, first. The gesture can only start from an accepted tap |
| Tap was early or late, but accepted | The gesture stays available. Its deadline counts from the actual press |
| Tap missed | Spec scenario stands: no gesture. The stroke is ignored |
| Ignored gesture | Costs nothing. Same as today |
| Failed gesture | Costs nothing. **Doesn't touch** `_hits`, `combo`, `lastGrade`, `lastTiming`, tier, the clock or crowd interest. Doesn't show a miss. The trail fades to dust, no sound |
| Pointer cancelled by the system | Voided with no visible failure at all |
| Next required tap comes during a gesture | A second thumb's tap is judged as normal. With one thumb, lifting ends the gesture. A partly finished gesture gets nothing, and no penalty |
| Grading | **Pass or nothing.** No "good" and "perfect" gesture. Timing precision belongs to the tap. Pattern 1 above |
| Spin direction | Free, as today, and it chooses the look and the ornament |
| Wrong shape on an offered note | A sideways drag on a stomp offer is still a plain flick if the note qualifies, and earns the flick reward. Sekai's example: wrong answers get a smaller reward, not a miss |
| Points | Placeholder for the owner: 100 for a spin, as now; 150 for stomp or wave; 300 for style moves; 500 for the W. Never needed for clearing, the top grade or a gate |
| Replay | Same dedupe key as flicks. The progression report's `_phraseIdentity` bug should be fixed first, or a recovering player's gesture gets no credit |
| Style chain | Extend "different direction" to "different shape" |
| Party | A success drives the crowd reactions the owner listed: points, cheers, whistles, clapping. It raises Sway under the existing rule. Crowd pointing is reserved for this and for uninterested-to-interested |
| Ledger | Gestures live in their own small record that outlives `_judge`, fixing the late-flick bug in Part 1 |

**A test can prove the safety rule:** the same taps, with gestures on, off, succeeded or failed, must produce the same `hits`, `combo`, `progress`, tier sequence and elapsed time. The progression report already calls for this.

### Data in `levels/*.json`

The shapes live in code; levels only pick them. Checked at load, like the rest of the level data.

```json
"chart": {
  "offsets": [0, 1, 1.75, 3, 4, 5, 5.75, 6.75],
  "gestures": {
    "spinEverywhereEligible": true,
    "lastNote": {
      "hand": { "shape": "wave",  "fromTier": 1, "move": "wave" },
      "foot": { "shape": "stomp", "fromTier": 1, "move": "stomp" }
    },
    "style": [
      {
        "id": "charleston-kick",
        "shape": "vee",
        "limb": "foot",
        "fromTier": 2,
        "deadlineBeats": 2,
        "move": "charleston_kick",
        "review": "unverified"
      }
    ]
  }
}
```

The existing `flourishDestination` stays until flicks migrate.

The loader should reject:
- A shape whose minimum time doesn't fit its deadline at the level's fastest tier.
- A mid-phrase long shape, or any shape with less than the gap rule's clearance.
- A move whose drawings are missing from a dancer's atlas, the way `requireFrames` does now.
- A `review` other than `approved` in a release build, following the `"calibration": "unverifiedStoryboard"` pattern already in `stage`. This keeps an invented step from shipping as if it were real.
- Dare moves using limb-accent drawings, as the progression report asks.

### Testing with autoplay

| Test | How |
|---|---|
| Shapes recognised | Each shape's ideal points, at several sizes, rotated ±25°, with seeded jitter, must pass. Pure Dart, no widgets |
| Plain taps don't earn | Wobbles under 18 px, and 40 px slides at a slow pace past the deadline, must not credit |
| Safety | The invariance test above, for every level and tier |
| Chart fit | The loader's rules run on all three levels |
| Timing edge | Late tap at 160 BPM still has its full window, fixing the Part 1 bug |
| Autoplay | **Feed synthesised points through the real recogniser,** rather than calling the credit function. The owner's review then sees the true trail and sparks, with normal judgment. Autoplay's stroke must be shaped by a beat-based speed, so it also tests the deadlines. The progression report noted autoplay reaches only 1 dare in the garden; it needs a show-off pattern |
| Real strokes | Record strokes on phones as JSON, with consent, keep them as fixtures. Replay through the recogniser whenever a tolerance changes |
| Reduced motion | Same results with effects replaced |
| Keyboard | Arrow keys already cover flicks. Stomp and wave as key sequences (up, down; left, up, right) via the same recogniser |

**Phone test, before committing to rungs 3+:** a handful of people, at both grip styles, on an iPhone and an Android phone. Measure: how often a plain tap earns a gesture; completion rate per shape and tempo; **the real time per shape** to replace my estimate; how often the system takes the touch; whether anyone notices the offer unprompted (the progression report's open worry).

## Part 6: indicators, without text

### Limits that apply to everything

| Rule | Evidence | Grade |
|---|---|---|
| No more than 3 flashes in any second, unless the combined flashing area stays under .006 steradians (25% of any 10° field). In the reference 1024×768 setup that's 341 × 256 CSS px, 87,296 px² | [WCAG 2.2, Understanding 2.3.1](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html) | P |
| A general flash is a pair of opposing luminance changes of 10% or more of maximum, with the darker state below 0.80. A red flash involves saturated red | Same | P |
| Don't convey essentials by colour alone | [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/basic/), [Xbox 103](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103) | X |
| Avoid flicker; give effect options | [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/basic/) | X |
| Dragging and shape input need an alternative, or simplified controls | [Xbox 107](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/107) | P |
| `prefers-reduced-motion` reaches Flutter web's `disableAnimations`: [PR](https://github.com/flutter/flutter/pull/180041) [X], and `build/web/main.dart.js` subscribes to the query [O]. **The game reads only its own "CALM CAMERA" toggle, starting off, so a player's system setting is ignored today** [O] | | |

**At our tempos** [C, J]:

- The lawn's fastest notes are 3.6 per second. A bright per-note flash can pass 3 per second, so it relies on the **area** escape. A 58 px ring is about 2,600 px². Even a 120 px burst is about 11,300 px². Both are far under the limit.
- WCAG's pixel figure assumes a desktop setup, and a phone is held closer. I'd keep the combined flashing area under about 20,000 px² as a margin. That's my number, not WCAG's.
- The beat itself at 160 BPM is 2.67 per second. A whole-screen pulse on every beat stays under 3. **Eighth notes would be 5.3, which fails.** So full-room light can't pulse faster than the beat, and no red.
- **Trust a check, not arithmetic,** before release. W3C points to [PEAT](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html) for this.

### Colour-blind check of today's colours [C]

I simulated the current feedback colours with the Machado 2009 matrices, using matrix values from memory, and measured distance in CIELAB (higher is more different; under about 20 reads as close in small marks, my rule of thumb).

| Pair | Normal | Red-blind | Green-blind | Blue-blind |
|---|---|---|---|---|
| Perfect gold / late orange | 32 | 30 | **21** | **18** |
| Early blue / late orange | 80 | 50 | 63 | 102 |
| Perfect gold / early blue | 87 | 76 | 83 | 86 |
| Early blue / flourish mint | 30 | 29 | 28 | **9** |
| Flourish mint / cream | 41 | **11** | **21** | 52 |

Early and late are well separated. **Perfect and late are close even with normal sight,** and worst under colour blindness. Mint against cream fails for red-blind players. This makes shape mandatory, and argues for moving late to a redder hue while keeping away from saturated red, and adding a dark outline, because the scene behind changes.

### Why ring shape can carry early and late

The cue already fills like a clock (`CircularProgressIndicator`, `_cue`, [O]). The grade can be the ring's own end state. It needs no new symbols, so it's the same image as the timing cue itself. It also shows size, not just direction.

### The icon set

Everything sits on a thin dark outline. Marks are small, and they last about 250-300 ms, so that they clear before the next note at 281 ms gaps.

| Event | Shape | Motion | Colour | Effect, sound | Reduced motion |
|---|---|---|---|---|---|
| **Touch heard**, any press in a zone | The zone's ring dents | Shrinks 8% in one frame, springs back | Cream | None. This says "I heard you" before any judgment | Instant brighten, no motion |
| **Perfect** | Ring **closes fully**, with a four-point star on it | Star pops outward | Gold | 3-4 sparks rise. Clean extra shimmer on the hit sound | Star shown still, 200 ms |
| **Early** | Ring **stops short**: a gap on the clock before 12, sized to how early. Small chevron at the gap | Ring **shrinks inward**, as if pulled back | Cool blue | Two droplets drift up. Tap sound as normal | Gap shown still |
| **Late** | Ring **runs past** 12 with a tail, sized to how late | Ring **swells outward** and smears | Warm orange, moved redder | Two embers fall | Tail shown still |
| **Missed note** | Cue dissolves | Fades | Same as cue | Nothing. No X, no red, no explanation | Fades |
| **Stray tap** | Dent only | As "touch heard" | Cream | Nothing. Replaces "KEEP THE PULSE" | |
| **Offer** on a cue | A **glyph** on the note, large enough to read, replacing the 16 px `open_with`: sideways swoosh; double-ended vertical; arc; zigzag | Glyph gently draws itself once on the 2-beat approach | Mint with outline | | Static |
| **Trail**, thumb moving | Ribbon from the press point. Width tapers from the head | Follows the thumb. Ahead of it, a dotted **guide** for the rest of the shape, starting from wherever the thumb landed, not a fixed place | Mint, then gold as legs finish | **Each finished leg goes solid with a tick and a spark.** This is how the player knows it's been heard | No sparks. Dots fill |
| **Follow-through** done | Whole ribbon flares | Spark stream **flies up from the ribbon to Mācron's limb**, linking the thumb to the scene | Gold | Party sound and music fill; crowd points | Ribbon stays bright, limb glows, sound unchanged |
| **Gesture failed** | Ribbon crumbles | Fades to dust | Grey | Nothing. No shake | Fades |
| **Opponent's demo** | Same ribbon and glyph, from the dancer's limb, in screen space | Runs at the speed the player must match | Gold, the call's colour | Plays the move's sound | Held pose plus glyph |

**Occlusion.** A thumb covers what it's touching, so the ring under it can't be the only place. Also show the grade **above the touch point** (about 70 px up, inside the zones' upper part), and let Mācron's limb glint. This is my inference; the occlusion papers weren't read.

**Fading.** Show early and late on every note for the first room or two, then only when a phrase leans one way. The player can opt out. Weak evidence, as noted above.

**A tendency tell, for the phrase.** If most notes in a phrase ran early, Mācron's next idle leans forward, and if late, leans back. One glance after each phrase, in the character's body. The owner asked for improving by feel, and this may be the most direct way. Untested.

### Teaching a gesture without words

| Step | When | What the player sees |
|---|---|---|
| 1 | Show moves already run from tier 1 | Opponent spins, no question asked |
| 2 | First offer | Opponent performs the move with ribbon. Same glyph on the call's cue |
| 3 | First answer chance | Glyph on the response's last cue. **A dot runs the path at tempo, from the thumb's zone,** once. Elite Beat Agents' ball is the model |
| 4 | First success | Everything fires, including the opponent's nod. This teaches the reward |
| 5 | After | Dot gone. Glyph stays. After two ignored offers in a room, the large pulse goes (the progression report's rule) |
| 6 | Higher tiers | The same shape meets new limbs and faster music |

The ribbon is **in screen space, not mirrored.** A W drawn left-to-right on screen by the opponent is drawn left-to-right by the thumb. Copying a facing dancer's body would be a mirror-image puzzle that nobody needs.

**The opponent's composition grows with the player,** as the owner asked: a dare's complexity can follow the same pass-based signals, without changing required notes.

### Every place text shows today, and what replaces it

From `lib/gameplay/garden_page.dart` unless noted. [O]

| Line | Text | When | Replacement |
|---|---|---|---|
| 536 | `PERFECT` | Tap | Star on closed ring |
| 538 | `GOOD · a little early` | Tap | Short ring, shrinking |
| 540 | `GOOD · a little late` | Tap | Tailed ring, swelling |
| 543 | `KEEP THE PULSE` | Stray tap | Dent only |
| 609-612 | `¡PIZAZZ!`, `¡STYLE ×n!` | Flick | Spark stream. Chain shown by more sparks and guests. Sound |
| 200 | `level.copy.resetLine`: `BACK TO THE GATE` | Reset | Mācron's walk back already shows it |
| 202 | `FIND THE GROOVE` | Failed phrase | Mācron's recover pose, opponent repeats |
| 204 | `MOJO +` | Passed phrase | Room warms; a guest reacts |
| 758 | `K / K` | Header | Keep as the small logo, or drop in play |
| 771 | `KUMBIA KOLISEUM` | Header | Drop in play; keep on title |
| 781 | `AUTOMATIC RUN` | Autoplay used | Robot icon stays lit |
| 791 | Tooltip `Pause` | Header | Keep as tooltip and screen-reader label; not shown on a phone |
| 799, 1232 | `01 / 05`, `01 / THE GARDEN` | Header, cover | N doors or lamps, one lit per room; number OK |
| 808, 811 | `AutoPlay`, tooltips | Button | Keep for screen readers |
| 824 | `AUTO` | Under robot icon | Drop |
| 843 | `MOJO`, `GRACE` | Top bar | **Removed with the progress bar,** per the owner |
| 853 | `n PIZAZZ` | Top bar | Small sparkle plus number, or end only. Owner's call |
| 862-875 | Progress bar | Top | Removed. The room is the meter |
| 881 | `FULL SUPPORT · n FINISH PHRASES` | Tier 4 | Room at peak; one lamp per finish phrase, or none |
| 983 | `FLICK FOR STYLE` | After tap | Glyph and guide |
| 1020-1026 | `READY n` | Count-in | Four pulsing beat lamps, with the count-in clicks |
| 1022 | `FEEL THE PULSE` | Intro | Zones pulse to the beat |
| 1023 | `WATCH THE CALL` | Call | Spotlight on opponent, zones dim, diamond cues (already distinct) |
| 1026 | `YOUR TURN` | Response | Opponent's existing `invite` pose, spotlight to Mācron, zones brighten, ring cues |
| 1025 | `PEAK GROOVE · n TO GO` | Tier 4 | Room at peak, finish lamps |
| 1053 | `n STEPS IN FLOW` | Combo | Trail of small lights at Mācron's feet, or sparks growing |
| 1071 | `RESPECT EARNED. KEEP DANCING.` | Clear | Opponent's `approve` and the room |
| 1108 | `LOOK. LISTEN. REPEAT.`, `TAP WHEN THE ICON LANDS.` | Bottom | Drop. Cues teach it |
| 1141, 1206 | `clearedTitle`: `MUCHO MOJO.` | Clear | **Stays.** The owner's answer: the big word is a consistent theme |
| 1152 | `OK, YOU COOL.` | Clear | Opponent nods, or a speech bubble's icon. The owner may want it spoken. Ties to the spec's text |
| 1167 | `exitLine`: `OUT TO THE LAWN` | Exit | The camera and path already do this |
| 1191 | `RESPECT EARNED`, `TAKE A BREATH`, `A LITTLE ROBOT. A BIG NIGHT.` | Cover | Drop; title screen has art. Pause: a pause icon |
| 1208 | `STILL GROOVIN'.` | Pause | Pause icon |
| 1208 | `KUMBIA KOMBAT` | Title | **Stays:** wordmark |
| 1227 | `clearedClaim`: `THE GATE IS YOURS.` | Clear | Gate opens on screen |
| 1229 | `Your groove will wait for you.` | Pause | Drop |
| 1241 | `n PERFECT · n PIZAZZ` | Clear | Star plus number, sparkle plus number |
| 1251 | `invitation`: `Mirror the rhythm...` | Cover | Drop; opponent's gesture |
| 1277 | `Tap anywhere in the matching zone...` | Cover | Drop; a silent looping demo of a tap, maybe |
| 1310-1316 | `ENTRA AL RITMO >`, `SEGUIMOS >`, `OTRA VUELTA >`, `WAKING THE MUSIC…`, `FOLLOW THE GROOVE` | Button | Play icon, resume icon, replay icon, spinner, walking icon. Keep the words as hidden labels |
| 1336, 1367 | `+/- CALM CAMERA` | Option | Icon toggle with hidden label. See below |
| 1345 | `nextLine`, `A KUMBIA KOLISEUM NIGHT` | Cover | Drop; next-room lamp |
| 1007 | `semanticsLabel: limb.name` | Hidden | Keep, and say it properly: "left hand" |
| 674, 239, 280, 376, 443-445; `garden_scene.dart` 121 | Load and sound-permission errors | Failure | **Stays as text,** with an icon. A failure explanation can't be drawn |
| `lib/landing/landing_page.dart` | `KumbiaKombat` | Unused by `main.dart` | No change |
| `levels/*.json`, `levels/index.json` | `invitation`, `clearedClaim`, `resetLine`, `exitLine`, `nextLine`, `metric` label | | Stop showing them. They may stay as hidden labels |

### What must stay as text

| What | Why | Evidence |
|---|---|---|
| Hidden labels on all controls and cues | Screen readers need them. The page can look text-free and still be labelled. Only 1 `Semantics` widget and one `semanticsLabel` exist today [O], so **this needs adding** | Xbox 107; [J] |
| Load, audio-permission and connection errors | Only words can say "tap to allow sound" | [J] |
| The big word at the end of a level | Owner's answer, 2026-11-06 | [O] |
| The wordmark, and numbers | Logo, not message. Digits read in any language | [J] |
| Any legal and credit screen | License and consent notes require it. The teacher's credit is promised in `plan/signature-moves-footage.md`. A credits page isn't in the game yet | [O] |
| Settings and menus when they arrive | Icons alone get ambiguous fast. Label them | [J] |
| Leaderboard and names | Player-created | [O, spec] |

Also, an option to turn on word labels would cost little, for players who struggle with icons. Owner's call. The calm-camera toggle should start from the player's system setting.

## Part 7: rules this overturns or changes

| Rule | Where | Status | Change |
|---|---|---|---|
| "No new input types... no holds" | Progression report | **Overturned** by the sixth round | Tap+drag is in. Long holds stay out |
| "Circle / long traced swipe: Defer" | `plan/input-research.md` line 20 | **Overturned** by the owner | Now wanted, with its stated costs still true |
| "Flick direction stays free" | Progression report | **Narrowed** | True for spins. Other shapes are specified, though wrong shapes still earn the flick |
| "Optional after-tap flourishes": destination swipe, 36 px, 300 ms, 500 ms | `openspec/specs/rhythm-combat/spec.md` lines 70-85 | **Already stale,** must be rewritten | Local shape after accepted tap; numbers per shape, in beats |
| "Holding, releasing, or optional swiping never creates another tap" | Same, line 29 | **Keep** | Core safety |
| "Missing, reversing, or declining a swipe SHALL never reduce..." | Same | **Keep** | Extended to all shapes |
| "Optional adornments never supply required taps, tier credit or clearance" | `plan/input-crowd-research.md` | **Keep** | |
| "Pizazz remains 100 per newly credited adornment" | Same, and the spec | **Must change** if shapes pay more | Owner's call on values |
| Style chain counts directions | Same, `garden_session.dart` | **Extend** | Counts shapes |
| "Minimal approvals (for example 'OK, you cool')" | Spec line 124 | **Change** | Pose or sound; the title of that requirement already agrees |
| "Charts and judgment stay fixed" | `plan/party-overhaul-research.md` line 59 | **Reworded earlier to "required notes"** for optional taps. Break phrases break even that | Only if the owner approves breaks |
| "Chart variants must preserve note count" | `FightChart.validate` | **Must change** for break phrases only | |
| One-thumb controls | `openspec/specs/kumbiakombat/spec.md`, rhythm-combat | **Keep for required play** | Every shape can be done with one thumb, though two may be easier for the W |
| `requireFrames` reserves accent drawings from grooves | `dance_grammar.dart` | **Extend** | Also to gestures, per the progression report |
| Level `copy` fields required by the loader | `level_definition.dart` line 447 | **Change** | Mostly optional, hidden labels |
| Widget tests assert on text | `test/widget_test.dart`, `test/garden_lifecycle_test.dart`, `test/level_fake_test.dart`, `test/level_registry_test.dart` | **Must change** | Find by key or hidden label |
| Roadmap item 09, "color-independent cues" | `plan/roadmap.md` | **Advanced** | This design does it, pending the device pass |

## Decisions for the owner

1. **Break phrases for the W?** Yes changes required charts. No means the W lives on the last note only, overlapping the next call. I'd measure first.
2. **Pass-or-nothing for gestures?** I recommend yes. It means no "perfect W".
3. **Points per shape.** Flat 100, or more for harder shapes?
4. **Bar's style move:** an in-character shaker shake, or a real dance step from the teacher?
5. **`OK, YOU COOL.`:** does it stay as a word, become a nod, or become a voice?
6. **Pizazz during play:** a number on screen, or end of level only?
7. **Should a simple-moves option** let any flick stand in for a shape, with full reward? Xbox 107 argues for it. It's cheap. I'd say yes.

## What's weak in this report

- **Thumb time per shape** is a pen model with assumed scale. It could be off by a lot. This is the number the plan most depends on.
- **Tolerances** are starting guesses. Nothing here came from thumb studies of drawn shapes.
- **Rhythm-game details** come from fan wikis and excerpts; no developer publishes direction or distance thresholds.
- **Mobile-browser and Flutter web touch latency:** no measurement found.
- **iOS edge-swipe behaviour:** anecdotal and conflicting. Needs a phone.
- **Thumb comfort:** no millimetre figures obtained.
- **Early/late glyphs improving players' timing:** untested anywhere I could find.
- **Every dance mapping** is unverified until the teacher and swing reviewer see it.
- **The colour-blind numbers** rest on matrices from memory and CIELAB distance, a rough measure.
