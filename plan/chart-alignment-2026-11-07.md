# Chart alignment with the rendered music, 2026-11-07

Branch `work/1880-algn`. The owner, verbatim: "the game combos are awesome, but they're not always well aligned with the music ... We would like the game taps and combinations to match the music theme and the dancing theme, they should all feel harmonious and being one and the same".

**Nobody has heard or played any of this.** The audit measures where the rendered takes have attacks, not whether a tap feels right. Tests prove the moved charts stay inside the fairness limits and the on-screen cue checks, not that they play well.

## For the owner: what to check

**Ears and thumbs, on autoplay first, then playing:**
- [ ] **Bar, every tier.** This level changed most (score 68 to 87). Does tapping now feel locked to the güira and the bass? Tier 0 now taps 0.5, 1, 2, 3, 4.5, 5.5, 6, 6.5, where it used to tap 2.25, 5.25 and 6.75. Is it still the bar's lazy swagger, or has it gone square?
- [ ] **Indoor party (cool-crowd), tiers 0 to 3.** Smaller changes (63 to 68). The tier-0 phrase now ends 6, 6.75, not 6.5, 7.25.
- [ ] **Billiards, tiers 1 to 3.** Some sixteenth "ricochet" notes now sit on the eighth or the beat. Is the cue-stroke character still there?
- [ ] **Lawn, top tier (136).** Two pairs of hands moved from 5.75 to 6 and from 1.75 to 2.
- [ ] **The Garden** is unchanged.
- [ ] Billiards tier 3 to 4 and party tier 4 still have notes on near-silence (see "Not fixed"). Do those feel like guessing?
- [ ] **One thing I can't settle by measuring:** in most rooms a call starts on the second bar of the music's four-bar group, because of the one-bar or three-bar intro. Does the call and response feel like it starts "in the middle" of the music's phrase? See "Phrase structure".

## What was measured, and how

**The tool.** `mixrs salience` (Rust, in `tool/music/mixrs/src/align.rs`) decodes a take and runs one STFT pass, keeping 5 numbers a frame. Those are the onset strength (half-wave rectified log spectral flux, slow trend removed) in four bands:

| Band | Range | Mostly |
|---|---|---|
| low | 30 to 200 Hz | kick, bass, tambora |
| mid | 200 to 2000 Hz | congas, keys, the body of brass and accordion |
| high | 2 to 10 kHz | güira and güiro, clave, shaker, brass attacks |
| pitch | chroma flux, 250 to 2000 Hz | a new note in the melody or harmony, even a soft one |

The brief asked for low (kick and bass), mid (clave, güiro, congas) and high (melody). By frequency, melody fundamentals sit in "mid" and the scrapers and clave in "high", so the bands follow frequency, and "pitch" catches melody notes. For every point of a 1/12-beat grid it reports the strongest onset within ±60 ms and its lag. Strength is in units of that band's average sixteenth in the same take.

- **Memory:** about 10 MB and 0.13 s a take (MIXRS_LOG), one take at a time, cached in `~/.cache/tillandsias-project/kumbia-audio/align/`. No NumPy.
- **Timing calibration:** spectral flux peaks before the attack. A Rust test with noise clicks at known times measured 19 ms early, and that is added back. Parabolic interpolation gives finer than the 5.8 ms step. The test holds the lag within ±5 ms.

**Where each note sits in the take.** This copies the game: `transport.dart` starts a level's take at its `entryBar` (the previous room's bridge), the layered tiers keep that origin, and the lawn's cuts re-anchor at their entry bars. A call starts at `introBeats + 16k`. So each chart note plays at a fixed set of places in the loop, for example 6 places in a 24-bar take. The audit scores every one, call and response both, weighted by how likely each entry is.

**A note's score** is the best band's strength times a lag weight: full within 25 ms, falling to zero at 60 ms. RESEARCH's pass mark was 20 ms and "silent" past 40 ms, with Perfect at ±75. Scores are capped at 2 for the average, and a tier's score is that average out of 100.
- "On accent": score at least 1.0, as strong as a typical sixteenth.
- "Weak": under 0.6. "Silent": under 0.35.
- The tool also lists the take's strong accents (1.6 or more) with no note within an eighth.

**The tier-to-pattern map** follows `FightChart.patternIndex`. With FEEL's 3 final challenges, tier 4's third peak replays `variants[0]` at the top tier's tempo, so pattern 1 is scored, and held to the limits, at both tempos.

## Scores, before and after

Same tool and same takes on both sides (`node tool/music/align_charts.mjs`).

| Level | Before | After | Tiers 0 to 4, before -> after | On accent | Silent |
|---|---|---|---|---|---|
| Garden | 94 | 94 | 96 96 91 91 95 (unchanged) | 97% | 0% |
| Lawn (pool-garden) | 80 | 83 | 93 94 81 82 **72->80** | 76 -> 80% | 10 -> 7% |
| Bar | 68 | **87** | **68->97 57->81 61->95** 86->91 **68->83** | 64 -> 87% | 19 -> 5% |
| Indoor party (cool-crowd) | 63 | 68 | 61->70 60->70 65->70 54->64 66->68 | 56 -> 63% | 9 -> 8% |
| Billiards | 56 | 64 | 92 **45->65 50->59 42->54** 58->64 | 42 -> 52% | 29 -> 24% |
| Salon (draft, not shipped) | 96 | - | 96 95 98 98 94 | 97% | 0% |

**What the takes do, in short:**
- **Garden** cumbia: dense, with strong güira on every eighth, so almost any eighth lands. Nothing to fix.
- **Bar, party and billiards:** whole beats and eighth "&"s are strong. Sixteenths (x.25, x.75), where many charted syncopations sat, are close to silent. That was most of the "silent" notes.
- **Lawn's low take (136, tier 4):** the &s are strong (2.0 to 2.9), and the x.75 positions of the old chart were weak.
- **Salon draft:** every beat and the &s of 1, 2 and 4 are strong.

## What changed in the charts, and why

Every change moves a step's `at` and keeps its limbs, its move (pair, split, double), its gap and its offer. The step count and press count are unchanged, so clear rules and rich-move counts don't move. A note on an eighth was never moved to a sixteenth. The search (`tool/music/align_suggest.mjs`) only touched steps with a note under 1.0, and it charges for distance moved, so the nearest good spot wins. It keeps:
- `FightChart._validateRich` and `fairnessProblems` at every tempo the pattern plays: same spot 285 ms, same limb 400, thumb hop 330, cross thumb 170, the phrase end, and room for an offered move (2×180+400+40), using FEEL's guaranteed window of 180.
- Same-limb notes at least 1.25 beats apart, or as close as the original was if it was closer, also across the join from a call into the next half.
- The two chart checks in `test/cue_path_test.dart`, ported to `tool/music/cue_geometry.mjs`. The port reproduced the Dart failure exactly (billiards, beats 33 and 34, ratio 0.326) before it was trusted.
- The offbeat share rising through the campaign (`test/level_registry_test.dart`), with the party and billiards limited to one off-to-on move per pattern. See "Fact versus choice".

A pattern changes only if its mean note score rises by 0.1 or more.

Tier 0 of the bar and the party used the plain `offsets`. They now have a `rich` pattern `"0"` with the same limbs. The plain `offsets` and `limbs` stay as they were.

| Level | Pattern (tiers) | Change | Why |
|---|---|---|---|
| Bar | 0 (tier 0) | RH 2.25→2, RH 5.25→5.5, RF 6.75→6.5 | sixteenths on silence; beat 3 and the &s are strong |
| Bar | 1 (tiers 1, 4) | hands pair 3.25→3.5, LH 6.25→6.5 | onto the & |
| Bar | 2 (tier 2) | pair 1.25→1.5, LF 2.25→2.5, RF 3.25→3, LF 3.75→4 | the whole sixteenth run sat between accents |
| Bar | 3 (tier 3) | RH 1.75→2 | onto beat 3 |
| Bar | 4 (tier 4) | LF 5.25→5.5, LH 6.25→6.5 | onto the & |
| Bar | 5 (tier 4) | split RF→LH 5.25→5.5, LF 7.25→7 | onto the & and beat 4 |
| Lawn | 4 (tier 4) | hands pair 5.75→6 | onto beat 3 of bar 2 |
| Lawn | 5 (tier 4) | hands pair 1.75→2 | onto beat 3 |
| Party | 0 (tier 0) | RF 6.5→6, RH 7.25→6.75 | 7.25 was the level's weakest note (0.34) |
| Party | 1 (tiers 1, 4) | hands pair 1.5→1 | onto beat 2 |
| Party | 2 (tier 2) | LH 2.75→3 | onto beat 4 |
| Party | 3 (tier 3) | hands pair 4.75→5 | onto beat 2 of bar 2 |
| Billiards | 1 (tiers 1, 4) | RH (flick offer) 0.25→0.5, hands pair 1.75→2 | sixteenths on silence |
| Billiards | 2 (tier 2) | LF 4.25→4, RH (flick) 4.75→4.5 | the same |
| Billiards | 3 (tier 3) | hands pair 4.25→4 | the same |

**Kept recognisable:** the bar's off-beat lean (69.7% of notes off the beat, was 78.8%), each pattern's limb order, every pair, split and double, and billiards' flick offers. **Hardest combos weren't touched.** They're parsed but no session code plays them yet, and they weren't audited.

## Not fixed, and why

- **Billiards tiers 3 and 4, and the party's tier 4.** These patterns are packed: four pairs, a double, a split and an offer in 8 beats at 100 to 136 BPM. Snapping their sixteenths to eighths breaks the thumb-hop limit (330 ms, more than half a beat). Even a full re-layout search (`--relayout`) found only a handful of fair layouts, and every better one failed the cue-separation check. Left: billiards p4 at 0.25 (pair, score 0.2), billiards p3 at 7.25 and 0.25, and party p4 and p5 at 4.25 and 7.25. **Proposal:** thin these patterns by one step, or let a pair become a single, and re-chart them on the eighth grid. That's a design change to the steps, which I didn't make on my own.
- **Bar pattern 1 at 4.25 (LF) and pattern 4 at 2.25 (pair)** stay on near-silence. Every fair move broke a limit or a cue check.
- **The party** fails the ported cue check as written (rightHand at 51 and 52, ratio 0.308; rightFoot 27.25 and 28, 0.336). The Dart cue test doesn't cover cool-crowd, so its proposals were checked without it, and they keep each pattern's own same-limb spacing.

## Fact versus choice

- **Fact:** the offbeat-share test (`level_registry_test.dart`) and the music pull apart in the party and billiards, whose takes have almost nothing on the sixteenths. Unconstrained, alignment reached 74 (party) and 69 to 86 (billiards), but then their off-beat share fell below the bar's and the test failed.
- **My choice, reversible:** I kept the test's order. Off-beat share is now bar 0.697 < party 0.708 < billiards 0.726, a thin margin, by allowing one off-to-on move per pattern there. If the owner would rather have "more on the music" than "more off-beat", drop `--max-to-beat 1` and replace that test's proxy with rich moves and density, which still rise.

## Phrase structure, a weak finding

With a one-bar intro (garden, lawn, bar) or a three-bar intro (party, billiards) and the bridges' entry bars, calls start on bar 1 mod 4 of the take in every room but the lawn. The lawn's are mostly 3 mod 4. A guess at where each take's four-bar groups start, from harmony change, loudness change and downbeat hits, gives margins of only 1.0 to 1.2. So I can't say the calls straddle the music's phrases, only that nothing lines them up on purpose. `validate_pool.mjs` already notes "Tier changes land 4 beats into the next call". **Proposal for the music side:** choose bridge `entryBar`s so `entryBar + introBeats/4` is the take's phrase start. No chart change needed. Not done.

## Research used (RESEARCH, a44df91acea3ab017; cheatsheet at `plan/research/rhythm-music-engagement-2026-11-07.md` on `work/1879-rsch`)

- osu! ranking criteria, "every element of a map should represent the song", and Rigopulos on "disconnected" charts. This is why the score demands an audible onset under the note, not a grid tick.
- The audit test design: nearest onset, pass within about 20 ms, "silent" past 40 ms. Mine fades from 25 to 60 ms, a little looser, because flux timing is coarser than a click.
- Witek et al. 2014 (PLOS ONE 9:e94446), medium syncopation grooves most. This is why moves keep off-beats off the beat where they can, and why a note on an eighth never moves to a sixteenth.
- Burger et al. and Toiviainen et al., feet take the pulse and hands the subdivisions. A small credit for a foot on a whole beat in the search.
- The cha-cha-chá "2, 3, 4-&-1": used in the salon advice below.

## Salon (BOLERO's takes, LEVEL's draft chart, both uncommitted)

Audited from wt/bolero's takes and wt/wire's `levels/salon.json`, and sent to LEVEL. It scores 96: no silent notes, and the weakest are the triple's & at 2.5 and 6.5. The takes accent 0.5, 1.5 and 7.5, the last being "4&" of the second bar, and 3.5 only weakly. Their attacks come 14 to 22 ms before the grid. I suggested moving the triple toward the ballroom "4-&-1", where the music supports it, as LEVEL's call.

## Verification

- `cargo test --release`: 13 pass, including `clicks_land_on_their_grid`.
- `flutter test`: all pass after merging `game` at 234ca5d (FEEL), with the level golden regenerated after the merge. Only the bar's clear time and its frames from the win on moved, as in the doubles note. The run used a symlinked copy at `wt/align-run`, because flutter only runs under `/home/forge/src`.
- `flutter analyze lib test`: the same 4 notes in `battle_staging.dart`.
- `node tool/music/validate.mjs` and `validate_pool.mjs`: pass. **`validate_pool.mjs` failed on `game` itself after FEEL's merge** ("rich moves never fall as tiers rise"): with 3 final challenges, tier 4's third peak replays `variants[0]`, tier 1's pattern, and the validator counted that replay as tier 4's own step. Fixed on this branch: a replay is still held to every limit at the top tier's tempo, but isn't counted as that tier's rise in rich moves or presses. Confirmed failing on an export of `origin/game` before the fix.

## How to use the tools

    node tool/music/align_charts.mjs                       # scores per level and tier, worst notes, unanswered accents
    node tool/music/align_charts.mjs --level salon --root DIR --json out.json
    node tool/music/align_charts.mjs --min 60              # exit 1 if any tier scores under 60
    node tool/music/align_suggest.mjs --level bar          # proposals only
    node tool/music/align_suggest.mjs --level bar --write  # apply (rewrites only chart.rich.patterns)
      options: --below 1.0  --max-shift 0.5  --relayout 3,4  --max-to-beat 1  --keep-offbeat 0.15  --min-gain 0.1

mixrs builds in `~/.cache/tillandsias-project/mixrs-work/target-align` (`ALIGN_CARGO_TARGET_DIR`). mix.py's shared target is rebuilt from whichever worktree ran last.

## What went wrong along the way

- My first proposals passed my fairness mirror but failed `cue_path_test`. A pair at 7.5 ran 0.5 beats into the next half's pair at 0, and a half-beat double put one cue over its twin. My heuristics were guessing at the screen, so I ported the Dart geometry instead. Gap changes are now off.
- A tighter heuristic for the join (1.0 beat and the 400 ms rule) made the original charts "unfair", and blocked every proposal for a run. Fixed.
- The first offer-room check measured from a double's first tap, and the game measures from its last press. `rich_moves_test` caught it.
- My first `--write` reformatted two level files, a 600-line diff. The writer now keeps each file's style.
- A cargo build into the shared `cargo/target` replaced mix.py's binary with mine. Mine is a superset (one added subcommand), so mix.py still works, but the tool now has its own target.
- The first "before" scores didn't count the third final challenge. Both columns above use the same tool.
