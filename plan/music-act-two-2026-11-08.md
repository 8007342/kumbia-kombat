# Music for mansion act two, 2026-11-08

Three new rooms: the comedor's polka "Sobremesa", the gallery's reel "Trébol" and the terrace's samba "Purpurina", with their tags and the four bridges that join billiards, comedor, salon, galeria and terraza. Branch `work/1882-polk`. **Nobody has heard any of it.** Every number below measures timing, harmony, spectrum or level. None says a take sounds good or sounds like its genre. Choices are proposals the owner can reverse.

## Campaign and keys

| # | Level | Score | Key | Rendered BPM (low, mid, high) | Loop | Tag | Bridge out |
|---|---|---|---|---|---|---|---|
| 5 | billiards | (unchanged) | G minor | 96, 100, 104 | 28 | 4 bars, not final | `billiards_to_comedor`, 2 bars at 120 |
| 6 | **comedor** | `comedor_polka` | F major | 120, 128, 136 | 32 | 4 bars at 136, not final | `comedor_to_salon`, 2 bars at 108 |
| 7 | salon | (unchanged) | D minor | 108, 116, 124 | 24 | 4 bars, now not final | `salon_to_galeria` |
| 8 | **galeria** | `galeria_reel` | A Dorian | 112, 120, 128 | | | `galeria_to_terraza` |
| 9 | **terraza** | `terraza_samba` | C major | 96, 104, 112 | | 4 bars, final | none |

The keys are chosen so every bridge is a short step (proposal):

- G minor into F major: G minor is ii of F.
- F major into D minor: relative keys.
- D minor into A Dorian: D minor is iv of A; G, the Dorian flat seven, leads home.
- A Dorian into C major: relative keys.

`billiards_to_salon` is retired, in the synth and the rendered manifest.

## Synth fallback (`tool/music/generate.mjs`, commit 5876e86)

Three original 32-bar forms, each with five tiers whose 0, 2 and 4 match the rendered tempos, a four-bar tag and the bridges. `composeRoom`, `composeRoomSuccess` and `composeActTwoBridge` are shared by the three; each room has its own groove function.

- **`comedor_polka`, F major, 120 to 136.** A1 A2 B A3: the B section is a trio in B-flat, the subdominant, as polkas do. Tololoche on every beat (root, fifth), bajo sexto and snare on every "and". Tier 1 adds the kick and a bass run into each phrase, 2 the full accordion line, 3 the accordion's thirds and a ride, 4 trumpets on the pah and a crash every eight bars.
- **`galeria_reel`, A Dorian, 112 to 128.** AABB, written as Dorian degrees, eight eighths a bar, with the D major chord (Dorian's raised sixth) in the tune. Bodhrán on the beats, a bouzouki chop and a cello drone. Tier 1 adds hard shoes on every eighth, 2 the full fiddle and the bodhrán's tipper triplet, 3 double stops and the whistle an octave up, 4 the pipes' drone and a stamped treble every second bar.
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
