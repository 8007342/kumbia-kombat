# Pending gameplay and tap requirements

Audit, 2026-11-06. Nothing here is built by this document. One agent read the listed plans and specs, then checked each claim against the code on `work/1843-play`, which is `work/1841-toda` plus the cue path change. File:line references match the commit that adds this file.

"Read" below means I read the code and didn't run it. Nothing was tried on a phone. Another agent is removing on-screen text in parallel, so the text and meter rows describe this commit, not that work.

## Crowd engagement ruling, built on `work/1844-crow`

The owner's ruling (`owner-rulings-2026-11-05.md:139`) is in the game. Closed or narrowed by this work:

| Row | Status now |
|---|---|
| #32 Crowd arc | **Closed.** Every shipped room's budget is 12, so the arc runs from occupied to all guests on their feet by the phrase before a clean clear |
| #34 Full swing for skilful players | **Closed for what's drawn.** Flawless play ends with every guest celebrating and the separately drawn umbrellas, plants, candles and waiter moving to the beat. Props painted into the plates still wait on #37 |
| #25 Phrase report | **Closed for the crowd.** `PhraseReport`: hits, perfects, gestures, timing spread |
| #26 Skill measure | **Narrowed.** Phrase grades and a level-long average replace Sway and Heat for the crowd. Nothing yet carries between rooms, and #27 and #29 are still open |
| #37 Everything parties up | **Narrowed.** Only the top of the ladder, on existing props. Every player's slow party-up by tier is still open |
| #42 Identical outcomes | **Closed for the crowd and optional moves.** Scene effects on or off still has no test |
| D9, D11, D12 | **Answered by the ruling:** excellent taps or gestures; a clean run ends fully engaged; props dance only at the top |

Still open from this area: #33 pointing, #35 sound rewards, #30 the Pizazz credit key. A recovering player's flick now counts for the crowd but still earns no points.

Rules and numbers are named constants in `CrowdEngagement`, `lib/gameplay/crowd_interest.dart`. `?autoplay=flawless` shows the top of the ladder; plain AutoPlay stays imperfect and clears partly engaged.

## The short version

- **The tap itself is solid. Almost everything the owner asked for on top of it isn't built.** Today's input is one tap, plus one flick that does the same spin in any direction.
- **Do these next:** fix two small credit bugs and add the safety test, then build the shared drag recogniser with sideways spins. Details are under "Recommended order".
- **Three things need the owner soon:** what makes a player count as skilful for full swing, how engaged a cleared room must look, and whether the "Yes I approve" covers the touch report's recommendations.

## What counts as approved

The owner's "Yes I approve the changes and recommendations" isn't written in any plan file, and no file says which report it answered. The only written approval of a plan is the seventh round's "I approve the plan for today's session" (`owner-rulings-2026-11-05.md:101`), and that plan covers fixes, music and art, not input. So I've counted only what the documents state.

| Status | Items | Where |
|---|---|---|
| **Approved, in the owner's words** | No Heat meter on screen. Every room can reach full swing. Optional taps and drags are wanted, so flicks alone are no longer the plan | `owner-rulings-2026-11-05.md:91` |
| **Approved, in the owner's words** | Ignoring optional play costs nothing | `owner-rulings-2026-11-05.md:91`, "still applies" |
| **Approved, in the owner's words** | The big end-of-level word stays as a theme. Early and late differ in shape, motion and effects. The owner asks the teacher for moves on video | `owner-rulings-2026-11-05.md:93` |
| **Approved, in the owner's words** | The rulings table for rounds three to six, quoted row by row below | `owner-rulings-2026-11-05.md:39-91` |
| **Needs confirmation** | All 8 decisions in the touch report, each with a recommendation and no recorded answer | `touch-gestures-and-feedback-2026-11-06.md:559-568` |
| **Needs confirmation** | The progression report's smaller decisions: what a hot run changes at the end, and whether answered dares pay more. Also all its numbers: Heat thresholds, dare rates, budgets, reveal lengths | `progression-and-adornments-2026-11-06.md:621-625, 642` |
| **Partly approved** | Layers. The owner allows them (`owner-rulings:73`) and approved "one room split into layers" for the session (`session-handoff-2026-11-06.md:38`). The report's order, lawn first, then garden and bar, is unconfirmed | `progression-and-adornments-2026-11-06.md:619` |
| **Can't be approved as written, because a ruling already overrides it** | "Flicks only for the first release". "Garden stops at step 3". "No new input types". "Circle / long traced swipe: defer" | Report lines 618, 623, 311; `input-research.md:20`; ruled against at `owner-rulings:85, 89, 91` |

If the owner's sentence did mean the touch report, then its recommendations in row 5 become approved, except where the last row applies. **Please confirm which report it was.**

## Requirements

Size: S is under a day of agent work, M is a few days, L is a week or more or needs new art. Sizes are rough. "Decision" names an item from the list further down.

### Tap and cue layout

| # | Requirement and source | In the code today | Still needed | Size | Depends on | Decision |
|---|---|---|---|---|---|---|
| 1 | Cues start near the play area's centre, curve to match the move, fade in; taps sit farther out, with more variety. Owner, today: "take curves to their final spots that match the direction of the dance move" | **Done on this branch.** `cue_path.dart`, `thumb_layout.dart:10-11`, `garden_page.dart:569-581` | Browser check. Curves follow the limb only, because no other move data exists yet | Done | None | D1 |
| 2 | Zones stay fixed at the bottom. "the visuals should be independent of the controller scheme", `owner-rulings:12` | **Done.** `thumb_layout.dart:18-31`, unchanged; the drawn ring never reaches the judge | Nothing | Done | None | None |
| 3 | Show the player a press was heard, separately from any grade. Touch report line 433 | No. A press gets only text feedback, `garden_page.dart:554-561` | The zone's ring dents on press | S | Text removal | None |
| 4 | Read the system's reduced-motion setting. Touch report line 400 | No. No `disableAnimations` in `lib/`. Only the toggle, starting off, `garden_page.dart:85, 1336` | Start the toggle from the system setting | S | None | None |
| 5 | Judge taps by the event's time, not when the handler runs. `rhythm-combat/spec.md:69-71` | No. `garden_session.dart:283, 480` read the audio clock when called; `garden_page.dart:678` passes the timestamp only to gestures | Measure a stalled frame's effect, then pass the event time | S to M | Audio clock mapping | None |
| 6 | Latency calibration. `roadmap.md:21-26`, `rhythm-combat/spec.md:56-57` | No. Only a comment, `rhythm.dart:9` | Calibration screen and offset. Heat's PERFECT count is unfair to Bluetooth players until this exists | M | None | None |

### Gestures

| # | Requirement and source | In the code today | Still needed | Size | Depends on | Decision |
|---|---|---|---|---|---|---|
| 7 | Tap+drag sideways for spins. "tap+drag sideways for spins", `owner-rulings:85` | Partly. A flick in **any** direction spins: `touch_gesture.dart:44-46` picks a direction, but only the ornament uses it (`garden_page.dart:583-601`) | Sideways means spin, with a curving stroke allowed. Decide what up and down do | M | #10, #11 | D2 |
| 8 | Tap+semi-circle for a hand wave. "tap+semi-circle for a handhave", `owner-rulings:85` | No. No wave drawing: `party_sprites.dart:19-21` has spins only | Shape check, glyph, Mācron 2-3 drawings per hand, opponents 2-3 | L | #7, art, phone test | D2, D3 |
| 9 | Tap+up and down for a foot stomp. "tap+up_and_down for a foot stomp", `owner-rulings:85` | No. No stomp drawing | Shape check, glyph, Mācron 2 drawings, opponents 2 each. `left_foot` and `right_foot` could stand in at first | M to L | #7, art | D2, D3 |
| 10 | See the thumb's path at all. Touch report lines 36, 250 | No. `garden_page.dart:676-705` has down, up and cancel, and no move handler | `onPointerMove` on the same `Listener`, feeding a heading-sequence recogniser | M | None | None |
| 11 | Gestures outlive the phrase. Touch report line 45, progression report line 602 | **Bug, read.** `_prepareCycle` clears the judge (`garden_session.dart:299`), and `flourishGesture` then refuses (`:509-513`). Only the winning phrase is protected (`:386-394`). A late tap on the lawn loses part of its 400 ms | A small record that outlives the judge, and a test at 160 BPM | S | None | None |
| 12 | Complex traces for skilled players later: "a left hand tap then a W to the right", `owner-rulings:85` | No | The report finds no room for it in a normal phrase at 160 BPM, for player or opponent. It needs a break phrase, which changes required charts: `garden_session.dart:67-68` rejects a different note count | L | #7-9, phone timing, music fill | D4 |
| 13 | Animations match the gesture. `owner-rulings:85` | No. The spin plays for any flick, `garden_scene.dart:816` | Each finished leg triggers its pose | M | #7-9 | None |
| 14 | Gesture indicators. "Tap+drag gets its own indicators", `owner-rulings:88` | Partly. A 16 px `open_with` on the cue (`garden_page.dart:951`) and text afterwards (`:981`) | Glyph per shape, ribbon, a guide that starts where the thumb landed, and each leg lighting up | M | #10 | None |
| 15 | A simple-moves alternative. Xbox 107, touch report line 567 | Partly. Keyboard arrows exist, `garden_page.dart:630-640`, but there's no option for touch | An option where any flick stands in for a shape | S | #7 | D5 |
| 16 | Autoplay shows gestures to the owner. Touch report line 382, progression report line 280 | No. It calls credit directly with cycled directions, `party_autoplay.dart:71, 113-114` | Feed made-up points through the real recogniser, plus a show-off mode | S to M | #10 | None |
| 17 | One gesture path in the judge. Touch report line 332 | No. `rhythm.dart:66` and `:74` are two routes, and the first is reached only by old tests and `garden_session.dart:503` | Remove the older route when flicks migrate | S | #10 | None |

### Optional taps

| # | Requirement and source | In the code today | Still needed | Size | Depends on | Decision |
|---|---|---|---|---|---|---|
| 18 | Optional taps. "Optional taps and tap+drag gestures", `owner-rulings:85` | No. Every note in `RhythmJudge` is required, and `expire` counts all of them, `rhythm.dart:88-98` | A separate lane in the judge, outside `_hits`, combo and `expire`, silent on a miss, plus a small cue | M | Text-free stray feedback (#3) | D6 |
| 19 | Where they fit. Progression report lines 300-309 | Not applicable | Garden has 10 slots per phrase. The bar has 10 at 100 BPM and 2 at 112. **The lawn has none**, so "keep the speed up" (`owner-rulings:79`) removes them as tiers rise. A validator should turn them off per tier | S | #18 | D6 |

### Signature moves and dances

| # | Requirement and source | In the code today | Still needed | Size | Depends on | Decision |
|---|---|---|---|---|---|---|
| 20 | Signature moves per dance style. "signature moves for each kind of dance", `owner-rulings:86` | No. Every touch report candidate is unverified by a dancer (line 281) | Level data for style moves, a review flag the loader enforces, then footage, poses and art | L | Teacher video, swing reviewer, #7 | D7 |
| 21 | Mācron's own step comes from the teacher. "Mācron signature step shall come from our salsa master", `owner-rulings:13` | No. Blocked: `signature-moves-footage.md` says nothing has been filmed | Video first. That plan warns Mācron is the hard part | L | Teacher | None |
| 22 | Unused drawings reach the screen. `owner-rulings:45`, `dance-richness-next.md:11-12` | Mostly. The grammar raised the garden from 18 to 43 drawings and the bar from 18 to 35, `dance-richness-next.md:52` | Bar's sideline: a guest covers her on the player's turn (`:65-66`). `enter_forward` and `retreat_backward` aren't wired (`:67-68`) | S to M | Room marks | None |
| 23 | Opponent spins overflow and come more often. `owner-rulings:59` | **Done, not seen on screen.** `challenger_choreography.dart:272`, `choreography.json:303`, every call from tier 1 | Browser check, already listed at `session-handoff-2026-11-06.md:44` | Done | None | None |
| 24 | Bartender's shaker. "we might need to remove that", `dance-richness-next.md:8-10` | Avoided, not decided. Her data skips those drawings (`:58-64`) | Decide, then redraw or not. It conflicts with a report candidate; see "Where documents disagree" | S to M | None | D8 |

### Skill and the opponent

| # | Requirement and source | In the code today | Still needed | Size | Depends on | Decision |
|---|---|---|---|---|---|---|
| 25 | A per-phrase record of how the player did. Progression report line 581 | No. Totals only, `_hits` is private, `garden_session.dart:257-264` | Phrase report: hits, perfects, credited gestures | S | None | None |
| 26 | Skill measure, with no meter on screen. `owner-rulings:91` | No. `heat` appears in `lib/` only in a comment, `exit_shot.dart:235` | Sway and Heat as pure state, with checkpoint and carry | M | #25 | D9 |
| 27 | "shall increase its dance compositions to match the player skill", `owner-rulings:87` | No. Moves come from tier only (`choreography.json:213-228, 303`), and every clearing player reaches tier 4 | Dare schedule from Heat, on the last note; moves in the call; `minHeat` in the data | M to L | #26, #7 | D10 |
| 28 | The player answers it. `owner-rulings:87`; rung 1, progression report line 292 | Partly. The last note always offers a flick, `garden_session.dart:325`, but nothing asks for it | The opponent's invite, a larger offer, the reward firing on the first answer | M | #27 | None |
| 29 | Adornments appear more often for players doing well. "more popular if the player is doing well", `owner-rulings:60` | No. Offers depend on timing gaps only, `garden_session.dart:324-336`. A flick adds a brief guest wave, `crowd_interest.dart:310-326` | Heat-driven offers and rewards | M | #26 | None |
| 30 | Replay fairness. Progression report line 64 | **Bug, read.** The credit key (`garden_session.dart:524`) uses an identity without `_responseSequence` (`:308-309`). A recovering player can flick, hear it, and get no credit | Add the sequence to the key, keeping the pause-replay protection, plus a test | S | None | None |

### The room

| # | Requirement and source | In the code today | Still needed | Size | Depends on | Decision |
|---|---|---|---|---|---|---|
| 31 | The room is the meter. "we can even remove the progress bar from the top", `owner-rulings:81` | No at this commit. Bar and label at `garden_page.dart:832-870` | Remove, and check first-timers can still tell how far they are. Report suggests finish lamps at tier 4 | S | The room reading clearly (#32, #34) | None |
| 32 | Crowd arc. "should start uninterested and be engaged by the tame we clear a level", `owner-rulings:84` | Partly. Guests start occupied (`crowd_interest.dart:128`). **But budgets cap it:** of 12 slots the garden allows 3 interested, the bar and lawn 5 (`levels/garden.json:44`, `bar.json:44`, `pool-garden.json:242`), so most guests stay occupied at the clear | Raise the budgets, or accept this as "warm-ish". The older gradual plan and this ruling pull apart | S (data), L (if more art) | Guest art | D11 |
| 33 | Crowd pointing is reserved. "uninterested->oh!_look!(*points)->now_interested", `owner-rulings:83` | Not as ruled. No pointing clip in `CrowdClip`, `crowd_interest.dart:13-23`. `notice` serves both the curious state (`:338`) and a flick's glance (`:237`). I didn't look at whether its drawings point | Check the drawings, draw a point if needed, trigger only on those two events | M | Guest art | None |
| 34 | Full swing for skilful players; average gets "a warm-ish party". "skillful play should be clearly rewarded", `owner-rulings:89` | No. Same party for everyone who clears. No second budget in `CrowdStageProfile`, `crowd_interest.dart:26-40` | Hot budgets, then props that dance only at the top | L | #26, #37 | D9, D12 |
| 35 | Sound rewards. "add the cheers, whistling, or clapping sounds", `owner-rulings:82` | No. A flick plays a written ornament, `garden_page.dart:583-598`. `cheer` in `lib/` is only a drawing | Shared sample bank scheduled on the beat, off judged beats | M | Audio samples, music rebuild | None |
| 36 | Tiers keep speeding up. "Let's try to keep the speed up", `owner-rulings:79` | **Done for current levels:** garden 92-104, bar 100-112, lawn 128-160, from the score files | Keep it true in new levels. It shrinks gesture and optional-tap room | Done | None | None |
| 37 | Everything parties up. "everything should slowly party up", `owner-rulings:69` | Barely. Only lamp glow reads the ambient sampler, `garden_scene.dart:607`. Plates are flat paintings | Layers, shared props, a beat-based sampler | L | Art; the session plan already has a layer pilot | D12 |

### Text-free feedback

| # | Requirement and source | In the code today | Still needed | Size | Depends on | Decision |
|---|---|---|---|---|---|---|
| 38 | "let's try to get rid of text messages everywhere", `owner-rulings:88` | No at this commit, for example `garden_page.dart:554-561, 981, 1016, 1274`. **Parallel work** | Touch report's Part 6 list. Screen-reader labels must arrive in the same change (report line 524). Text-based widget tests must change | M | None | D13 |
| 39 | Early and late differ in shape, motion and effects. `owner-rulings:93` | No. Colour and words only, `garden_page.dart:554-557` | Ring stops short, ring overshoots, ring closes with a star. Report also moves late's colour away from gold | M | #38 | None |
| 40 | Sparks for follow-throughs and adornments. `owner-rulings:88` | No | Sparks flying from the ribbon to Mācron's limb. Keep the flash limits, report lines 395-407 | M | #14 | None |

### Older gates still open

| # | Requirement and source | In the code today | Still needed | Size | Depends on | Decision |
|---|---|---|---|---|---|---|
| 41 | Physical phone acceptance. `roadmap.md:16-20, 55-59`, `garden-slice/tasks.md:13`, `living-party/tasks.md:12` | Not done, and no test can do it | Android Chrome and iOS Safari, one thumb, taps then gestures. **Also the prerequisite for #8, #9, #12** | M | A person with phones | None |
| 42 | Identical outcomes with effects on or off. `living-party/tasks.md:11`, `play-and-transition-overhaul.md:86-87` | Not done as a test | The "ignoring costs nothing" replay test. Report calls it the most important one | S | None | None |
| 43 | Timestamped input and phrase events. `living-party/tasks.md:4` | Partly. Phrase sequence exists, `garden_session.dart:437`; input timestamps don't | Fold into #5 | S | #5 | None |
| 44 | Cinematics can't change judgment. `cinematic-shot-pipeline/tasks.md:24` | Not done as a test | Same pattern as #42 | S | #42 | None |
| 45 | Style layers don't move cue deadlines. `score-composition-pipeline/tasks.md:33` | Not started. Its route may be stale after the pilot chose rendered takes | Re-scope against `music-rebuild.md`, not this audit's job | S to M | Music | None |
| 46 | Durable save. `roadmap.md:27-30` | Not done | Teaching state and credit dedupe need it across reloads; per run until then | M | None | None |

A keyword search of the open tasks in `character-sprite-pipeline`, `comfyui-studio-pipeline` and `kumbia-foundation` found nothing about input, taps or cues. I didn't read those task lists line by line.

## Where documents disagree, or a requirement is obsolete

| Issue | Says | Says | Standing |
|---|---|---|---|
| Who gets the full party | "Belongs to everyone", progression report line 359, and the fifth round | "staff, umbrellas and plants don't dance" for average players, `owner-rulings:89` | The sixth round is later and wins. The report's ladder needs rewriting. The fifth round's text still reads as everyone |
| Room limits | "Garden stops at step 3", report lines 199-205 | "Every room can reach full swing", `owner-rulings:89` | Report table is obsolete |
| Input types | "No new input types", report line 311 | Tap+drag wanted, `owner-rulings:85` | Report is overruled, and the touch report agrees (line 540) |
| Long traces | "Defer", `input-research.md:20` | Wanted later, `owner-rulings:85` | Overruled, but its stated costs remain true |
| Holds | "Candidate later", `input-research.md:18` | "Long holds stay out", touch report line 540 | Not an owner ruling either way. Treat holds as out until asked |
| Flick direction | "stays free", report line 313 | Sideways means spin, `owner-rulings:85` | Narrowed. Decision D2 sets what's left |
| Rung numbers | Grace note is rung 3, report line 294 | Optional tap is rung 1 and stomp is rung 3, touch report lines 261-263 | **The two ladders use different numbers.** Name rungs by move, not number |
| Shaker | "we might need to remove that", `dance-richness-next.md:8-10` | "Shake the shaker" is the bar's style candidate, touch report line 287 | Direct conflict. D8 |
| Garden's style | Cumbia per the drawings | The music brief is salsa-led, touch report line 285 | Open, and it decides which moves are the garden's signature |
| Moving targets | "no zones that move", report line 311; "without moving the required targets", `input-crowd-research.md:10` | "a little more variability on where the taps appear and are required", owner today | Reconciled this way: zones stay fixed and judge the tap, rings vary inside them. D1 lets the owner say otherwise |
| Cue origin | "Cues travel from mid-screen", report line 413; "Keep cue origins clear", `input-crowd-research.md:81` | Cues now start inside the tap band | Stale. Mid-screen is free of cues, which simplifies the prop mask |
| Flick numbers | 36 px, 300 ms, destination swipe, 500 ms, `rhythm-combat/spec.md:75-85` | 24 px, 400 ms, any direction, 800 ms, `touch_gesture.dart:13`, `rhythm.dart:30`, `garden_session.dart:333` | Spec is stale. `living-party/specs` carries the same older wording |
| Passing a phrase | "Every required note... to pass", `rhythm-combat/spec.md:60-61` | A ratio, 75% or 87.5%, `progression.dart:22-25` | Spec is stale. `input-crowd-research.md:33-34` describes the code |
| Preview length | Minimum 900 ms, `rhythm-combat/spec.md:36` | Always 2 beats, `garden_session.dart:355`, which is 750 ms at 160 BPM | **The lawn's top tier breaks the spec.** The fade-in takes 225 ms of that. Check by playing |
| "OK, you cool" | Approvals like it, `rhythm-combat/spec.md:130`; the code still shows it | No text, `owner-rulings:88` | D13 |
| Finish count on screen | "show remaining finish combinations", `play-and-transition-overhaul.md:22` | No text, no bar, `owner-rulings:81, 88` | Keep the information, drop the words. Lamps are the report's suggestion |
| Tempo | "Keep the existing modest tier tempo progression", `play-and-transition-overhaul.md:35` | "keep the speed up", `owner-rulings:79` | Sixth round wins. Style-driven tempo lifts remain unasked for |
| Label on her waist | "WATCH THE CALL" crosses the Bartender, `dance-richness-next.md:38` | Text is going | Obsolete once text removal lands |
| Roadmap | Written in October; no mention of rounds three to eight | Rulings since | `roadmap.md` needs a refresh. Its items 01, 02 and 09 are still real |

## Decisions for the owner

| # | Decision | My recommendation | Why it matters |
|---|---|---|---|
| D1 | Should a tap have to land near the ring, or is the zone enough? | **Keep the zone,** as built. The ring shows where a note lands, and any tap in its quadrant counts | "Required" could mean exact spots. That would make the game far harder for thumbs, and would change judging |
| D2 | Gestures pass or nothing, with a failed shape still earning the plain flick? | Yes. Also: up or down alone still earns a flick, as the report proposes | Sets the recogniser's whole shape |
| D3 | Points per shape: flat 100 or more for harder ones? | Pay more only once phones show which are harder | Changes the "100 per adornment" rule |
| D4 | Break phrases for the W? | Decide after phone timing. The report has no precedent for a W at this speed | Changes required charts, the one thing every plan protects |
| D5 | A simple-moves option? | Yes, it's cheap | Accessibility |
| D6 | Optional taps: when? | The owner wants them, but they can't exist on the lawn. Build drags first, then a garden trial | The fastest room can't have them, and tempo is rising |
| D7 | Who reviews swing moves? | Name a reviewer. The teacher's stated field is salsa | Blocks the lawn's signature moves |
| D8 | Bartender's shaker: remove, or make it her move? | Owner's taste. It would make a memorable move, but needs every clip consistent | Art cost either way |
| D9 | **What makes a player skilful?** Does full swing need gestures? | Excellent taps **or** gestures reach it, as the report says, so ignoring gestures locks nothing away | The sharpest open conflict: "for skilful players only" against "ignoring costs nothing" |
| D10 | Can a skilled player see harder opponent moves than an average one? | Yes, as optional dares only. Required notes stay the same | Sets how far "composition grows" goes |
| D11 | **How engaged is a cleared room?** Today most guests stay occupied in the first rooms | Raise each room's budget for everyone who clears, and keep the top slice for skill | The ruling says engaged; the data says otherwise |
| D12 | Which props dance for average players at the clear? | Follow the sixth round: lights only, plus some guests | The report's "everyone" ladder is out of date |
| D13 | "OK, YOU COOL" and Pizazz in play: word, nod or voice; number or end only? | A nod, and show Pizazz at the end. Touch report decisions 5 and 6 | The parallel text work may need this soon |

## Recommended order

Small safe fixes first, then the shared parts that block the most, then art. Phone testing comes before art is spent.

| Step | Items | Size | Why here |
|---|---|---|---|
| 1 | Credit bug #30, ledger bug #11, safety test #42, system reduced motion #4 | S each | No decisions needed. Later work builds on all of them |
| 2 | Text-free feedback #38, press response #3, meter removal #31, hit shapes #39 | M | Already running. Removing the bar leaves the room to carry the meter, so check #31 on screen |
| 3 | **Drag recogniser #10, sideways spin #7, gesture indicators #14, autoplay #16, one path #17** | M | Uses drawings that exist. Lets the owner see drags with no new art |
| 4 | Phone test #41, measuring real thumb times and whether anyone finds the drag | M | Every number for stomp, wave and W rests on a pen model the report itself calls weak |
| 5 | Phrase report #25, Heat #26 | S, M | Invisible on its own, and unlocks every skill item |
| 6 | Crowd budgets #32, then skill rewards #29, sound rewards #35, pointing #33 | M | Makes the room honest as the meter |
| 7 | Dare on the last note #27, #28, with existing spins | M | First answer to "match the player skill" |
| 8 | Stomp #9 and wave #8, with art, and matching animation #13 | L | Only after step 4 |
| 9 | Full swing #34 with props #37 | L | Depends on steps 5 and 6 and on the layer pilot |
| 10 | Optional taps #18, #19 in the garden | M | Valuable only where tempo leaves room |
| Later | Signature moves #20, #21 (waiting for video), W #12 (after D4), calibration #6, save #46 | L | Blocked, or depends on earlier measurements |

### Top five to do next

1. **The two credit bugs and the safety test** (#30, #11, #42). Small, needing no decisions, and they make every later gesture trustworthy.
2. **Finish and merge the text-free feedback** (#38, #39, #3), with screen-reader labels in the same change.
3. **The drag recogniser with sideways spins** (#10, #7, #14, #16). This is the first visible step of the owner's sixth-round input, and it needs no new art.
4. **A short phone test** (#41) before committing to stomp and wave art.
5. **Phrase report and Heat** (#25, #26), which unlock opponent growth, full swing and adornment rewards.

## What this audit didn't check

- No game was played, and no drawings were opened. Whether `notice` reads as pointing, and whether the room reads as a meter, need eyes.
- Both bugs (#11, #30) come from reading the code. Neither has a failing test yet.
- Sizes are estimates.
- The two research reports' outside evidence wasn't rechecked. Their own "what's weak" sections still apply.
