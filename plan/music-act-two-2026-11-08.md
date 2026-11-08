# Music for mansion act two, 2026-11-08

Three new rooms: the comedor's polka "Sobremesa", the gallery's reel "Trébol" and the terrace's samba "Purpurina", with their tags and the four bridges that join billiards, comedor, salon, galeria and terraza. Branch `work/1882-polk`. **Nobody has heard any of it.** Every number below measures timing, harmony, spectrum or level. None says a take sounds good or sounds like its genre. Choices are proposals the owner can reverse.

## Campaign and keys

| # | Level | Score | Key | Rendered BPM (low, mid, high) | Loop | Tag | Bridge out |
|---|---|---|---|---|---|---|---|
| 5 | billiards | (unchanged) | G minor | 96, 100, 104 | 28 | 4 bars, not final | `billiards_to_comedor`, 2 bars at 120 |
| 6 | **comedor** | `comedor_polka` | F major | 120, 128, 136 | 32 | 4 bars at 136, not final | `comedor_to_salon`, 2 bars at 108 |
| 7 | salon | (unchanged) | D minor | 108, 116, 124 | 24 | 4 bars, now not final | `salon_to_galeria` |
| 8 | **galeria** | `galeria_reel` | A Dorian | 114, 122, 130 | 32 | 4 bars at 130, not final | `galeria_to_terraza`, 2 bars at 96 |
| 9 | **terraza** | `terraza_samba` | C major | 96, 104, 112 | 24 | 4 bars at 112, final, fades over 4 beats | none |

Rendered bridges and where they enter: billiards into comedor low at bar 27, comedor into salon low at bar 12, salon into galeria low at bar 2, galeria into terraza low at bar 22. Commits: synth 5876e86, interim manifest cf8ac44, comedor bc2e02e, galeria ladder 6c690a3, galeria ba012a1, entry phase b4285e4, terraza 8dd346b.

The keys are chosen so every bridge is a short step (proposal):

- G minor into F major: G minor is ii of F.
- F major into D minor: relative keys.
- D minor into A Dorian: D minor is iv of A; G, the Dorian flat seven, leads home.
- A Dorian into C major: relative keys.

`billiards_to_salon` is retired, in the synth and the rendered manifest.

## Synth fallback (`tool/music/generate.mjs`, commit 5876e86)

Three original 32-bar forms, each with five tiers whose 0, 2 and 4 match the rendered tempos, a four-bar tag and the bridges. `composeRoom`, `composeRoomSuccess` and `composeActTwoBridge` are shared by the three; each room has its own groove function.

- **`comedor_polka`, F major, 120 to 136.** A1 A2 B A3: the B section is a trio in B-flat, the subdominant, as polkas do. Tololoche on every beat (root, fifth), bajo sexto and snare on every "and". Tier 1 adds the kick and a bass run into each phrase, 2 the full accordion line, 3 the accordion's thirds and a ride, 4 trumpets on the pah and a crash every eight bars.
- **`galeria_reel`, A Dorian, 114 to 130** (first written at 112 to 128; moved with the chosen take, below). AABB, written as Dorian degrees, eight eighths a bar, with the D major chord (Dorian's raised sixth) in the tune. Bodhrán on the beats, a bouzouki chop and a cello drone. Tier 1 adds hard shoes on every eighth, 2 the full fiddle and the bodhrán's tipper triplet, 3 double stops and the whistle an octave up, 4 the pipes' drone and a stamped treble every second bar.
- **`terraza_samba`, C major, 96 to 112.** A A B A with a turn to F and F minor in B. Surdo on 2 and 4 with its answer on 1 and 3, caixa sixteenths, a seven-string bass line, cavaquinho strums on the syncopations. Tier 1 adds the tamborim's teleco-teco, 2 the agogô, 3 the apito calls into each eight, 4 the brass lift on the "and" of 4.
- Tags: the room's first phrase, then a cadence home (F Bb C7 F; Am G Em Am; C A7 G7 C) with the band thinning. Bridges: a bar of the destination's percussion alone, then two chords that turn the last room's key into the destination's, while the answer voice quotes the destination's call.
- `validate.mjs` now expects 10 scores, 11 tags, 11 bridges, 72 MIDI files and 32 score files, and knows the three four-bar tags. It passes.
- Drum pitches stay where the web synth can play them: its pitch formula goes negative under about MIDI 54, so surdos are 36 and 58, not GM's floor toms.

The melodies were written for this project. Nobody has compared them against any database of tunes.

## Comedor, "Sobremesa"

### Candidates (proposal, reversible)

20 takes, all at 128 BPM, F major, 74.5 s, in four tag sets (full tags and every measure: `tool/music/sheets/comedor.candidates.json`):

- A, "happy norteño polka…", seeds 59000 to 59003.
- B, "classic Mexican norteño polka…", 59100 to 59103.
- C, "conjunto norteño polka… accordion lead in thirds… tuba and tololoche…", 59200 to 59207.
- D, "joyful norteño polka… loud button accordion… up front", 59300 to 59303.

- **Timing filter:** 10 of 20 pass. Seven failures read as half time (0.64 to 3.5). In an oom-pah, one beat of each pair is much weaker, so the filter may be rejecting some of the most polka-like takes. That is a guess.
- **Major or minor:** the chord ear read many bars as F minor. A whole-take chroma check (A minus A-flat) found 59000 and 59205 really lean minor, so they're out. The rest lean major.
- **Lead salience is low everywhere,** 44 to 58, against 80 to 112 on the salon. That may be the accordion playing chords as much as melody. It may also mean no take carries a clear tune.

**Chosen: seed 59202, tag set C.**

- Timing: passes, clarity 14.3, wander 18.9 ms.
- Lead salience 54.9, and the highest hook repeat among passes (0.577).
- The chord ear hears a clean tonic-dominant polka throughout (F F F F C C … F F C C), with one F minor bar in 40.
- Major-third lean 0.30, second best.

**Runner-up: 59200, same tag set.** It has the steadiest beat (1.9 ms, clarity 28.7) and the most arrangement movement (0.607). Its chord ear reads 7 of 40 bars as F minor.

Whether 59202 is a happy norteño polka with an accordion tune on top is the owner's call. To swap, change `parent.seed` in `tool/music/sheets/comedor.chain.json`, rebuild the workflow with `build_workflow.py`, run it, then rebuild with mixrs.

### Tiers from one performance

The parent reproduces 59202 exactly (MD5 of the decoded audio).

- **Low:** `lowB`, one pass at 0.6 with small-trio tags, "quiet dinner… nothing else".
  - Every child came out brighter than the parent: lowB had a centroid of 915 Hz, against 659 on the parent, in `shared_grid`.
  - So low has a -6 dB high shelf at 1.2 kHz, not the usual -3 at 1.5k. The -3 dB shelf left it at 908 Hz in `ladder_measures`, still brighter than mid's 1054. With -6 at 1.2k it measures 680.
- **High:** `highE`, four passes at 0.6, with the parent's percussion under it at -6 dB.
  - Its tags add a full band: "bright trumpets join the melody, tuba oom-pah… hand claps, banquet hall on its feet".
  - The research cheatsheet puts new instruments at tier-ups, so the trumpets are the intended entry. **Whether trumpets appear is unknown.** The spectrum rises: centroid 1905 Hz against 1028 on mid.

Measured on the encoded Opus loops:

| Tier | BPM | Onsets/beat | Centroid Hz | Spread Hz | LUFS | True peak | Envelope vs mid | Bar harmony vs mid |
|---|---|---|---|---|---|---|---|---|
| low | 120 | 1.99 | 672 | 1074 | -16.5 | -5.5 | 0.99 | 0.95 |
| mid | 128 | 2.00 | 1028 | 1526 | -16.0 | -3.8 | | |
| high | 136 | 1.83 | 1905 | 1944 | -15.0 | -3.0 | 0.94 | 0.86 |

Onsets per beat don't rise into high, as on the party and the salon. The envelope and harmony columns come from `shared_grid` on the masters, before the stretch.

### Loop

32 bars, 60 s on mid: harmony 0.984, texture 0.631, with 6 candidate starts.

- 24 bars scored better on the seam (harmony 0.989, texture 0.901). But its mid AAC file showed a 4.4 dB top-end burst at the wrap in verify, a fail, and Safari plays the AAC. Moving the low tier's EQ or source didn't change that.
- 20 bars was clean, but it splits the polka's 8-bar phrases.
- 16 bars repeats every 30 s.

**Listen to the wrap at about 60 s on mid.**

### Exit music

- **Tag:** 4 bars of high at 136, from loop bar 6. The chord ear reads F C F F, so it lands on the tonic. It's not final: the percussion thins in the last beat, and the bridge carries on.
- **`comedor_to_salon`:** 2 bars at 108 into salon low at its bar 12, with a harmony match of 0.82. The chord ear reads F, then Dm: the relative minor, as planned.
- **`billiards_to_comedor`:** 2 bars at 120 into comedor low at its bar 30, with a harmony match of 0.83. The chord ear reads Am, then G. That's not the Gm-to-C7 the synth writes; it's what the billiards and comedor takes give at the best entry.
- The billiards tiers and tag were restored from git after the build. Only its bridge and manifest entry changed.

### Verified, and how

- `mix.py verify` with mixrs: one failure, `comedor/low: layer sits -11.6 ms off its parent`.
  - Low's attacks land one envelope frame (11.6 ms, the test's resolution) ahead of mid's, on the parent's clock.
  - Tried: lowC instead of lowB, no EQ, -3 dB EQ, and low at 116 or 122 BPM. The lag stays and grows as low gets slower: -5.8 ms at 120 on shorter loops, -11.6 at 116.
  - Tier changes crossfade over a beat (469 ms), so a 12 ms offset is unlikely to be heard there. It may matter to the chart's judging on the low tier: ALIGN's audit should say.
  - High: 0 ms.
- Drift is 0 ms on every tier. Wander is 12 to 18 ms on low and mid. On high it's 47 ms (Opus) and 92 ms (AAC), so high's quarter pulse is weaker. The drift test reads 0, so this is most likely a weak beat, not a drifting one. That is a guess.
- `bar1Confidence` is **0.07**: the polka's beats are nearly alike, so bar 1 may be a beat off. Sent to WIRE2.
- Builds: mixrs, one job at a time, peak 178 MB in a worker, 31 s for billiards and comedor.
- `node tool/music/validate.mjs`: PASS.

### Not verified: for the owner's ears

1. Is 59202 a happy norteño polka: accordion on top, bajo sexto, a tuba or tololoche oom and a snare pah?
2. Do trumpets enter on high?
3. Is the -6 dB low too dull?
4. The 32-bar wrap at 60 s.
5. Billiards' tag into its bridge into the comedor: G minor to F major.

## Galería, "Trébol"

### Candidates (proposal, reversible)

12 takes at 120 asked, key "A minor" with "dorian mode" in the words, 74.5 s. Every take, with its tags and measures, is in `tool/music/sheets/galeria.candidates.json`. The words name no show, troupe or tune.

| Set | Seeds | Words |
|---|---|---|
| A | 60000 to 60003 | "driving Celtic reel…" |
| B | 60100 to 60103 | "traditional Irish reel, two fiddles in unison… heavy hard shoe taps on every beat…" |
| C | 60200 to 60203 | "cinematic Celtic step-dance reel…" |

- **Timing filter: 2 of 12 pass.**
  - Set A reads half time or wanders.
  - Set B's three steady takes all play at 122.0, 1.67% over the 120 asked, against a 1.5% limit. Their beat is the steadiest of the whole batch: wander 3.8 to 12.9 ms, clarity 23 to 44.
- **Chosen: 60101, set B, used at its own tempo.**
  - Lead salience 82.9, the highest hook repeat (0.746), melodic motion 0.21, lead range 21 semitones.
  - Wander 3.8 ms, clarity 44.5.
  - In whole-take chroma, F-sharp sits just over F (0.21 against 0.17). That is a slight Dorian lean.
  - The chord ear hears A minor in almost every bar. A drone-centred reel would read that way. So would a tune that never moves.
- **Because of it, the ladder moved to 114, 122, 130,** a step of about 7%, as on the salon. The synth tiers moved to 114 to 130 with it (6c690a3). WIRE2 rechecked the chart's fairness.
- **Runner-up: 60200, set C.** It passes the filter, with wander 7.6 ms and arrangement movement 1.19. Its salience is 58, and in chroma F sits over F-sharp (an Aeolian lean).

### Tiers

The parent matches 60101 by MD5.

- **Low:** `lowC`, one pass at 0.7 with "a lone fiddle with bouzouki, soft bodhrán, light hard shoe taps… nothing else", and a -3 dB shelf at 1.5 kHz.
- **High:** `highE`, four passes at 0.6, with the parent's percussion under it at -6 dB. Its words add "tin whistle doubling the tune, uilleann pipes swelling with drones… thunderous hard shoes stamping in unison". The pipes and the whistle are the intended new entries at the top tier. **Whether they appear is unknown.**

| Tier | BPM | Onsets/beat | Centroid Hz | Spread Hz | LUFS | True peak | Envelope vs mid | Bar harmony vs mid |
|---|---|---|---|---|---|---|---|---|
| low | 114 | 2.32 | 441 | 444 | -16.5 | -1.5 | 0.96 | 0.94 |
| mid | 122 | 2.24 | 491 | 569 | -16.0 | -1.0 | | |
| high | 130 | 2.34 | 806 | 779 | -15.0 | -2.0 | 0.85 | 0.89 |

On Opus, low has slightly more onsets per beat than mid. The masters say otherwise: 2.58 for lowC against 2.74 for the parent, before the stretch. Low is darker than mid; high is brighter and a little denser.

### Loop and exits

- **Loop: 32 bars,** the reel's AABB, 63 s on mid. Seam harmony is 0.953 and texture 0.718.
  - 24 bars scored texture -0.85.
  - 16 bars was near perfect, at 0.999 and 0.98, but repeats every 31 s.
  - `bar1Confidence` is 0.88.
- **Tag:** 4 bars at 130, not final. The chord ear reads Am throughout, landing on A.
- **`salon_to_galeria`:** 2 bars at 114 into galeria low at bar 2, harmony match 0.80. The chord ear reads Am Am, not the Dm G the synth writes. The salon's rebuilt tag is no longer final: its percussion thins in the last beat instead of fading. Its loop files were restored from git.
- **Verify:** passes. Low and high sit 0 ms from mid. Wander is 3.4 to 9 ms. The opus file is 4.05 MB.

## Terraza, "Purpurina"

### Candidates (proposal, reversible)

12 takes at 104, C major, 74.5 s. Every take, with its tags and measures, is in `tool/music/sheets/terraza.candidates.json`.

| Set | Seeds | Words |
|---|---|---|
| A | 61000 to 61003 | "joyful samba batucada…" |
| B | 61100 to 61103 | "Brazilian samba enredo… full bateria…" |
| C | 61200 to 61203 | "happy samba, cavaquinho melody, seven-string guitar…" |

- **Timing filter: 9 of 12 pass.**
- **Harmony:** the chord ear read most batucada takes as F minor or A-flat. Whole-take chroma shows a strong band at A-flat and A on every take. That is most likely the tuned surdos, which is a guess.
- **Chosen: 61201, set C.**
  - With 61100, it is one of only two takes where the chord ear hears a plain C-major samba progression: C F G, Am, Dm.
  - Wander 18 ms, clarity 11.0, salience 65.9, melodic motion 0.19.
- **Runner-up: 61100.** It has the same clean harmony and salience 66.3, but wander 30.8 ms.
- 61200 had the most movement and salience 73.7, but its harmony wanders through F minor and E.

### Tiers

The parent matches 61201 by MD5.

- **Low:** `lowC`, one pass at 0.7 with "small roda de samba… pandeiro, soft surdo… nothing else", and a -3 dB shelf.
- **High:** `highE`, four passes at 0.6. Its words add "full carnival bateria… apito whistle calls, bright horn section lifts with trumpets and trombones". The parent's percussion goes under it at -4 dB, not -6, because highE's own onsets fell to 1.92 per beat on the master, against 2.99 on the parent.

| Tier | BPM | Onsets/beat | Centroid Hz | Spread Hz | LUFS | True peak | Envelope vs mid | Bar harmony vs mid |
|---|---|---|---|---|---|---|---|---|
| low | 96 | 2.64 | 361 | 523 | -16.5 | -2.0 | 0.89 | 0.91 |
| mid | 104 | 3.04 | 505 | 775 | -16.0 | -2.1 | | |
| high | 112 | 2.19 | 897 | 926 | -15.0 | -2.1 | 0.77 | 0.89 |

**High has fewer onsets per beat than mid, even with the percussion layer.** Its envelope match, 0.77, is the lowest of any high tier so far. It may sound like a different, smoother band rather than a bigger one. Listen to mid into high first on this level. If it's wrong, try `highC` (onsets 2.22, envelope 0.83) or a -2 dB layer in `levels.json`.

### Loop and exits

- **Loop: 24 bars,** 55 s on mid. Seam harmony 0.925, texture 0.772. 32 bars doesn't fit in the 74.5 s take at 104. 16 bars had texture 0.12. `bar1Confidence` is 0.55.
- **Tag:** 4 bars at 112, final. It fades over its last 4 beats: -19.9, -21.3, -27.4, -40.8 dB RMS. The chord ear reads Am D C C, landing on C.
- **`galeria_to_terraza`:** 2 bars at 96 into terraza low at bar 22, harmony match 0.76. The chord ear reads D, then C.
- **Verify:** passes. Low and high sit 0 ms from mid. Wander is 8 to 21 ms. The opus file is 3.36 MB.

## Bridges that land on the chart's phrase

ALIGN's audit found that the comedor chart's calls started on bar 1 mod 4, while the polka's 4-bar phrase starts on bar 2 mod 4. The margin was 1.26 to 1.44 on all three takes. ALIGN's earlier proposal was to fix this on the music side: choose the entry bar so that entryBar + introBeats/4 is the phrase start.

- **New, `bridgeEntry` in `levels.json`.** It's optional and set on the destination level as `{step, offset}`, and it limits the bridge's entry bar to `offset`, `offset + step`, and so on. The default is every even bar, as before.
  - mixrs: `bridge --entry-step N --entry-offset M`.
  - mix.py: the same choice in its Python path.
  - `cargo test` (13) and `mix.py --self-test` pass.
- **Comedor:** `{step 4, offset 3}`. The entry moved from bar 30 to 27. The bridge's harmony match fell from 0.83 to 0.71, which is the cost. Calls now start on bar 2 mod 4 on all three takes, where the audit puts the phrase. The audit score went from 96 to 95.
- **Terraza:** `{step 4, offset 2}`, entry at bar 22, match 0.76. Calls start on bar 1 mod 4, where the audit puts the phrase, but with weak margins (1.06 to 1.2).
- **Galería** needed nothing: calls already started on its phrase (bar 1 mod 4).
- **Salon:** comedor's bridge enters it at bar 12, so calls start on bar 3 mod 4. The audit's phrase guess for the salon disagrees across its tiers (0 or 2 mod 4, margins 1.03 to 1.08), so there's nothing reliable to align to. It's left alone.
- All charts use introBeats 12 (WIRE2). If that changes, the entries must be recomputed.

## Chart audits (`align_charts.mjs`, `mixrs salience`), against WIRE2's charts

| Level | Chart commit | Score | On accent | Weak | Notes |
|---|---|---|---|---|---|
| comedor | 10e1f42 | 96 | 96% | 1% | Weak: tier 4, p4 and p5, beat 0.5 (0.62 to 0.65). Low leads by 8 ms |
| comedor, after the entry change | 10e1f42 | 95 | 95% | 2% | Calls on the phrase |
| galeria, first chart (3+3+2 feet) | 4347dc1 | 68 | 64% | 27% | Notes on 1.5, 2.5, 3.5, 4.5 missed the reel's beats |
| galeria, reworked | ad633ad | 91 | 94% | 0% | Tier 4 at 85: accents on 3 and 7 without notes |
| galeria | f0d42f4 / 596b248 | 92 | 94% | 0% | Tier 4 at 86 |
| terraza | 596b248 | 95 | 98% | 1% | Low and mid attacks 12 to 13 ms early |

These measure attacks, not feel.

## Verified, and how (all three)

- `mix.py verify` with mixrs: one failure over all nine levels, comedor low's 11.6 ms lead, explained above.
- Every parent matches its candidate by MD5 of the decoded audio.
- `node tool/music/validate.mjs`: PASS.
- Builds ran with mixrs, one job at a time, through `heavy.sh`, peaking at 164 to 178 MB in a worker. No WAV was committed: trial EQ renders stayed in the scratchpad.

## What went wrong

- A first comedor build with 24-bar loops failed verify on a 4.4 dB top-end burst at the mid AAC wrap. Moving the low tier's EQ or source didn't touch it. 32 bars fixed it.
- I chased comedor low's layer lag through five trial builds (EQ, source, tempo) without finding its cause. It grows as the tier slows: -11.6 ms at 116 BPM, -5.8 at 122.
- The galeria ladder changed after I had told WIRE2 112 to 128, so the chart's fairness had to be rechecked at 130.
- My first bridge plan would have played billiards' old bridge, in the salon's key, into the comedor. WIRE2 caught it. An interim manifest (cf8ac44) removed it until the comedor rendered.
- My terraza loop trial at 32 bars failed, because the take is shorter than 32 bars at 104. I should have computed that first.
- The synth's first polka draft had two E-flats over C7. A scale check caught them before commit.

## Not verified: for the owner's ears

1. **Each style.** Is 59202 a happy norteño polka? Is 60101 a Celtic reel, driving and tense, with fiddle and pipes? Is 61201 a joyful samba batucada with cavaquinho and brass?
2. **New instruments at high.** Do trumpets (comedor), pipes and whistle (galeria) and the horn section (terraza) appear at the top tier? Only brightness was measured.
3. **Terraza mid into high,** the weakest tier match of the batch (envelope 0.77, fewer onsets on high).
4. **The comedor low**, darkened by -6 dB: too dull?
5. **The joins between rooms.** The four bridges: G minor to F (0.71), F to D minor (0.82), D minor to A (0.80), A to C (0.76). The two phrase-aligned entries traded harmony match for phrase position.
6. **Loop wraps:** comedor at 60 s on mid (texture 0.63), galeria at 63 s, terraza at 55 s.
7. **The finale.** Does the terraza's fading tag work as the end of the night, now that it's the last room?
8. **The galeria tempo**, 122 instead of 120: is the reel too fast for tension, or right?
