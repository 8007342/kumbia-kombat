# Richer moves inside a beat: doubles, pairs and splits

Built 2026-11-07 on `work/1862-dubl`, for the owner's twelfth round: "we'll add double taps, even taps in double spots like left and right or left then right, in the same beat, that should compensate for the lower speed. The music feels sharper and more rich, and so should be the dance, even if the tempo is slower ;)"

Nobody has played this. Tests prove that notes land, that autoplay clears and that numbers hold their limits. They don't prove any of it feels good. Every limit below is a starting value.

## For the owner: what to check

**On screen, on autoplay (either mode), lawn then bar:**
- [ ] From the lawn's second tier, two cues sometimes travel tied by a cord: both together, or with a small arrow for one then the other.
- [ ] A cue with a second ring around it means that spot gets pressed twice.
- [ ] The cord and rings can be read at phone size, and don't clutter the pad at the top tier.
- [ ] In the call, the opponent claps for "both hands". On the lawn, both dancers raise an arm.
- [ ] Mācron flings both arms wide when both hands land. This borrows a drawing from his spin, so say if it reads wrong.
- [ ] A quick left then right looks like a quick left then right, on him and on the opponent.
- [ ] The lawn's last tier (136 BPM) feels like the richest part of that song.
- [ ] The bar still feels harder than the lawn.
- [ ] The Garden is unchanged.

**On thumbs, one on each side of the phone:**
- [ ] Both hands together: does landing them feel like one move? Do they both count?
- [ ] A double on one spot at 136 BPM, 331 ms apart: comfortable, too easy, too hard?
- [ ] Left then right at 160 BPM, 188 ms apart: does it land?
- [ ] Playing the top tier with single taps only still clears, and doesn't feel punished.
- [ ] Landing every press feels clearly better: more sparks, a warmer room, a bigger score.
- [ ] Is 13 presses in a phrase at the top tier fun, or too much?

**On a keyboard:** Q, W, A and S play all three moves (tested on the real page). A held key shouldn't repeat: the page ignores repeat events, which I read in the code and didn't test.

## What was built

| Move | The player does | Data |
|---|---|---|
| Double tap | Same spot twice | `"move": "doubleTap", "gap": 0.75` |
| Pair | Two spots at once, one thumb each | `"move": "pair", "with": "rightHand"` |
| Quick split | One spot, then one on the other side | `"move": "split", "with": "rightHand", "gap": 0.5` |

**Data.** `chart.rich` in a level file holds `limits` and `patterns`. A pattern key is 0 for `limbs` and n for `variants[n-1]`, and it replaces that pattern's limbs and offsets with eight steps. A chart without `rich` plays as it did: the Garden's golden fingerprint is byte-identical. A level is free to enrich tier 0 too; the shipped charts don't.

**The rule that changed on purpose.** Offsets may now repeat, because a pair's notes share one. Steps must still start after the press before them. Every pattern must keep the same number of **steps**, in place of the old same number of notes. Pairs and splits must use both sides of the phone, because a thumb can't press two spots or cross the phone in time.

**How clearing counts: steps, not notes.** `requiredHits` counts steps, and a step lands if either of its presses lands. So half a pair clears that step.
- Why: leniency is the owner's stated value, and a phrase should never get harder to *clear* because it got richer. The bar for clearing stays exactly where it was.
- "One dropped note per eight-note phrase" keeps its meaning as one dropped step in eight, at every tier, because every pattern has eight steps. Had every press counted, a 13-press phrase at the peak would need 12 of them. A player tapping each step once would land 8 and fail, so a phrase would get harder to clear as it got richer, which is what the owner asked to avoid.
- A second press missed never breaks the combo. The combo breaks only when a whole step goes by.

**How skill is rewarded.** Finishing a step (both presses) pays 50 pizazz, against 100 for an optional move, and once per performance, so a pause's replay can't farm it. It sets sparks on the ring and makes guests look over. It counts as a move in the phrase report, so a clean phrase with one becomes "excellent", the fastest way up the room. It also lifts a scrappy or loose phrase by the existing move credit. Each press lands or misses and earns its own PERFECT.

**A pair's tolerance.** Each press of a pair keeps the judge's whole ±180 ms window, so two thumbs a few milliseconds apart always both count. On top of that, `pairToleranceMs` (80) makes two presses that close share the better grade, either way round, because to a player they're one gesture.

## The numbers

Beat lengths, in ms:

| BPM | Beat | ¾ beat | ½ beat | ¼ beat |
|---|---|---|---|---|
| 160 (lawn HIGH) | 375 | 281 | 188 | 94 |
| 144 (lawn MID) | 417 | 312 | 208 | 104 |
| 136 (lawn LOW) | 441 | 331 | 221 | 110 |
| 112 (bar HIGH) | 536 | 402 | 268 | 134 |
| 106 (bar MID) | 566 | 425 | 283 | 142 |
| 100 (bar LOW) | 600 | 450 | 300 | 150 |

Limits, in `chart.rich.limits`, tunable per level:

| Limit | Value | Why | Fact or guess |
|---|---|---|---|
| `sameSpotMs` | 285 | One thumb, same spot, one step. The progression report's number | Guess: the report calls it "my starting rule, not a measured thumb limit", and it was written for optional taps |
| `sameLimbMs` | 400 | Same limb in two steps. Above 360, so good windows never touch | Existing rule |
| `thumbHopMs` | 330 | One thumb to the other spot on its side | Guess. The lawn's old rule was a whole beat |
| `crossThumbMs` | 170 | Two thumbs, one after the other | Guess |
| `phraseEndMs` | 100 | The last note's window must end this long before the phrase, or the next phrase would cut it off | Safety margin |
| `pairToleranceMs` | 80 | Pair presses this close share a grade | Guess |

**Is a same-thumb double in half a beat at 136 BPM (221 ms) playable under the existing rules? No.** It fails `sameSpotMs` (285), the old 400 ms same-limb rule, and the good windows overlap (±180 ms needs 360). So the shipped doubles use **three quarters of a beat**: 331 ms at 136, 402 at the bar's 112, 425 at 106. Inside a single step the overlapping windows do no harm, because a press judged against the wrong half still lands the step. So the only reason left against 221 ms is the thumb. To try it, set `"gap": 0.5` on a double and lower `sameSpotMs` in the level file. A test will hold you to whatever limit you set.

No lawn double plays at 160, where ¾ of a beat is 281 ms and misses the floor by 4 ms. Doubles are only in the top tier.

**Splits** use half a beat: 188 ms at 160, 221 at 136, 268 at 112, on two thumbs.

**What only a thumb can settle:** all of the "guess" rows. Whether 13 presses at the top tier is fun. Whether a hand-to-opposite-foot split feels different from a same-height one. Whether players notice the second press matters at all, or just take the easy clear.

## The charts

Each tier has eight steps. Tier 4 has two patterns, one per final challenge.

| Lawn tier | Tempo | Presses | Doubles | Pairs | Splits | Presses a second |
|---|---|---|---|---|---|---|
| 0 | 144 | 8 | | | | 2.40 |
| 1 | 144 | 9 | | 1 | | 2.70 |
| 2 | 160 | 10 | | 1 | 1 | 3.33 |
| 3 | 160 | 11 | | 2 | 1 | 3.67 |
| 4, first | 136 | 13 | 2 | 2 | 1 | 3.68 |
| 4, second | 136 | 13 | 1 | 2 | 2 | 3.68 |

| Bar tier | Tempo | Presses | Doubles | Pairs | Splits |
|---|---|---|---|---|---|
| 0 | 100 | 8 | | | |
| 1 | 100 | 10 | | 2 | |
| 2 | 106 | 11 | | 2 | 1 |
| 3 | 106 | 12 | 1 | 2 | 1 |
| 4, first | 112 | 12 | 1 | 2 | 1 |
| 4, second | 112 | 13 | 1 | 2 | 2 |

Across all patterns the lawn has 16 richer steps and the bar 18, and the bar keeps the higher offbeat share. `play complexity rises through the campaign` now counts both. The Garden has none. The lawn's top tier holds all three moves in each pattern, and is the only part of that song with doubles.

**Assumption to check at merge.** The tempos above assume tiers map to takes as lawn 144, 144, 160, 160, 136 and bar 100, 100, 106, 106, 112. The render agent owns that mapping, and it isn't merged. The table lives in `test/rich_moves_test.dart` and, for the lawn, `tool/music/validate_pool.mjs`. If the merged mapping differs, those fail or need another look.

**Until the rendered music merges,** the lawn's tier 4 plays the synth at 160 BPM, not 136, so its doubles are 281 ms there: 4 ms under the floor. They still play and clear. The rendered ladder fixes it.

**Do the offsets sit on the music?** Measured, not heard. Folding note onsets onto the beat in the approved lawn takes (`themes-20261106/lows-lawn`): MID has clear peaks on the beat and near ⅔ of a beat, close to the chart's ¾ (35 ms off) and 70 ms from ½. So MID's tier has no half-beat moves. LOW has clusters around ⅜ to ½ and ¾ to ⅞, so both ½ and ¾ have something under them. HIGH came out flat, so this says nothing either way about the 188 ms splits there. The beat phase in this measure is estimated, and none of it says how it sounds. Against the synth's swing, a half-beat press isn't on the swung offbeat.

## Visuals, with no text

- **Pair:** a thicker cord between the two cues.
- **Split:** a thinner cord with an arrowhead toward the cue that comes second.
- **Double:** a short cord between the two, and each wears a second ring. The ring stays on after the first press, so the second still reads.
- The cord appears in the call too, in gold, which is what teaches it. Cues keep their curved paths. Screen readers get "Press twice".
- **Cue separation.** The existing tests now read the richer patterns and were not loosened: different limbs keep a full cue apart once faded in, and one lane keeps its .35 floor, on every test screen. To hold that, the charts keep same-limb notes in two steps well apart (1.25 beats at the least, most at 1.5 or more), and notes on a quarter position now land alternately by bar. That moves where x.25 and x.75 notes land by up to 8% of screen width. The Garden has none of those.

## The dance, with drawings that exist

Art reads the music beat and can't move the score.

| Move | Opponent, in the call | Mācron, on the taps |
|---|---|---|
| Pair of hands | The clap every dancer has, with its contact on the note. On the lawn, both dancers raise an arm | `spin_front`, the one drawing with both arms flung wide, if both presses landed |
| Pair of feet (no chart uses it yet) | The limb's own accent | The crouch, `anticipate` |
| Hand with foot (no chart uses it) | The limb's own accent | The latest limb's accent |
| Double | The same accent twice | The same accent twice |
| Split | One side's accent, then the other's | One side's accent, then the other's |

**Tried and rejected:** stitching Mācron's left-hand and right-hand drawings down the middle. His head and chest split visibly (checked by eye on a composite).

**Drawings I'd want, not drawn:**
1. Mācron, both arms up, front view. `spin_front` is mid-spin, with one foot lifted.
2. Mācron, a two-footed hop or stomp.
3. Mācron and each opponent, a quick double pump of one arm, and of one leg.
4. Opponents, a two-footed hop, if charts come to want a pair of feet.

## Verification

- `flutter test`: 497 pass, 457 at the start of today. `flutter analyze lib test`: the same 4 notes in `battle_staging.dart`. `node tool/music/validate_pool.mjs`: passes.
- New: `test/rich_moves_test.dart` (rules, limits against the real files at their tempos, judging, grades, autoplay) and `test/rich_moves_page_test.dart` (the real page: Q/W/A/S, and two real pointers down at once).
- Autoplay, flawless and with errors, clears the lawn and bar from the real level files, reaching tier 4 and finishing richer steps. On a flawless run the session's count of finished steps equals exactly the sum of what the charts ask.
- **Golden:** the Garden's fingerprint is unchanged. In the bar, the 12 samples before the win are unchanged, since they fall in tier 0. The 7 from the win on moved, because the win comes half a beat later: clear at 93.287 s, was 93.019, as the last note of the final phrase moved from 6.75 to 7.25. Perfects 103, was 75: more presses.
- `validate_pool.mjs` changed honestly: the rule "limb load peaks at the middle tier", from the old draft, is replaced by the twelfth round's rich moves rising to the top tier. The block about a per-tier rhythm "the chart format cannot hold yet" is gone, since it now can. Plain-pattern checks stay.

**Not verified:** anything on a phone or by ear, and any on-screen look: the cords and rings have only been exercised by tests, not seen.

## What went wrong along the way

- The worktree at `wt/doubles` was caught half-written by the full disk. I removed it to free space and made one in the cache, which briefly collided with the coordinator's own repair. It's now back at `wt/doubles`, sparse. No work was lost.
- My first edit to `choreography.json` spliced inside a string and broke the file, and that was pushed in the first commit on this branch. The next commit fixes it. Don't cherry-pick the first one alone.
- A first set of charts passed the fairness limits but failed cue separation, so the lawn and bar were laid out again, using a small search for the tightest patterns.

## Superseded

`plan/storyboard.md` ("never a chord") and `plan/levels/pool-garden.md` ("no chords") predate this ruling. The ruling wins.
