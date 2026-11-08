# Rendered-music audit, branch `game`, 2026-11-08

Scope: the high tiers of bar, salon, comedor and galeria, with mid and garden/high as controls, plus every small rendered asset. Nothing tracked was edited. All scripts and intermediate data are in the scratchpad (paths at the end). **Nobody listened to anything.** Every statement below is a measurement, or is labelled as interpretation.

## 1. Short answer

- **The pipelines finished.** Every chain is complete and its provenance hashes match. Each parent is bit-identical (decoded MD5) to the candidate seed the notes name. Each high comes from the last of four chained passes. For salon, comedor and galería, a fresh `mixrs prepare` and `write-asset` run from the cached masters gives **bit-identical** `low/mid/high.{ogg,m4a}` (file MD5 equal). Bar and garden were built by the older Python engine (commit 5f39244). Their mixrs rebuild matches the shipped Opus to -48 dB (bar/high) and -35 dB (garden/high, the known -1.9 vs -1.5 dB ceiling difference). Every duration equals bars × 4 × 60 / bpm to the sample. No file is truncated, a placeholder, or silent.
- **No discrete defect is high-specific.** On clicks, clipping, dropouts, loop seams, spectral jumps and bar-by-bar structure, the high tiers measure like their mids.
- **What is high-specific: the stereo image breaks down.** It gets worse with each re-sampling pass, and the high tiers are the only tiers that get four passes. It comes with a brighter, thinner spectrum. Section 4 has the numbers.
- Interpretation, moderate confidence: this is the most likely measurable cause of "glitchy / unfinished". Stereo correlation near zero or negative sounds phasey and swirly on headphones and partly cancels on a mono phone speaker.

## 2. Method differences between tiers (measured from levels.json, chain specs, mixrs code and its rebuild)

| Tier | Source | Generative passes | Extra layer | Time-stretch (WSOLA) |
|---|---|---|---|---|
| mid | `parent.flac`, the chosen seed, untouched | 0 | none | ≈0 % (0–8 splices per take) |
| low | `lowB`/`lowC`, one pass at denoise 0.6/0.7 from the parent latent | 1 | -3 dB shelf (comedor -6 dB at 1.2 kHz) | −6 to −9 %, 710–983 splices |
| high | `highE` (act two, salon) / `highF` (bar, garden, billiards), **four chained passes at 0.6**, 8 turbo steps each, latent to latent | 4 | parent's HPSS percussive part at −6 dB (terraza, cool-crowd −4) | +6 to +7 %, 645–767 splices |

- No tier is spliced from several takes. Each is one continuous render of one performance. The only "splices" are WSOLA's own: 1920-sample frames, 960 hop, with a search of only ±192 samples (4 ms) on one side.
- The percussive layer is time-aligned. The per-2-beat onset lag of highE/highF against the parent is 0–2.7 ms median, and ≤3 % of windows exceed 20 ms. So the layer does **not** cause flams or double hits (`out/lags.json`).

## 3. Per-level results

Glitch metrics are taken on the shipped Opus file, inside the loop region. "Clicks" means 1-ms blocks whose 2nd-difference peak exceeds 8× the RMS of the surrounding 100 ms. "Seam z" is the spectral distance from the loop's last beat to its first beat, in robust z-units against all consecutive beats. "L/R corr" is the inter-channel correlation over the loop. Mono loss is the level of (L+R)/2 relative to the mean channel level.

### Bar (C minor, 100/106/112, 24 bars; high = highF)

| | low | mid | high |
|---|---|---|---|
| Duration / loop / expected | 58.10 / 57.600 / 57.600 s | 54.840 / 54.3396 / 54.3396 s | 51.929 / 51.4286 / 51.4286 s |
| Loop end inside file | yes (+0.25 s) | yes | yes |
| Rebuild vs shipped | −67 dB (Opus) | −78 dB; m4a identical | −48 dB (Opus), −33 dB (AAC) |
| Peak dBFS / flat tops | −3.9 / 0 | −3.4 / 0 | −4.4 / 0 |
| Clicks in loop | 17 | 101 | 13 |
| Seam z / seam level step | 1.3 / – | 0.6 | 0.4 |
| WSOLA splices (worst match corr) | 797 | 8 | 702; 19 % of splices with match corr < 0 |
| **L/R corr** (200–1k Hz band) | +0.17 (−0.28) | +0.38 (−0.09) | **−0.07 (−0.41)** |
| 0.5-s windows with corr < 0 | – | 6 % | **59 %** |
| Mono loss, whole loop / worst 100 ms | −2.3 dB | −1.6 dB | **−3.3 dB / −11.5 dB at 22.25 s** |
| HF > 5 kHz share | −21.2 dB | −19.7 dB | −16.3 dB |
| Bar-by-bar onset match with mid (min) | 0.83 | – | 0.82 |

- Timestamps to check by ear, bar/high.ogg:
  - The most decorrelated passages: 22.2 s (corr −0.65, mono −7.6 dB), 21.8 s, 3.8 s and 5.2 s.
  - The worst WSOLA splices (match corr −0.46 to −0.36): 12.07, 28.27, 48.57, 23.91 and 46.53 s.
- At splice positions, the local click and low-band dip measures don't differ from random positions (4.2 % vs 3.3 % above the click threshold). No single splice stands out as a click. Confidence: medium.

### El Salón de Espejos (D minor, 108/116/124, 24 bars; high = highE)

| | low | mid | high |
|---|---|---|---|
| Duration / loop / expected | 53.833 / 53.3333 / 53.3333 | 50.155 / 49.6552 / 49.6552 | 46.952 / 46.4516 / 46.4516 |
| Rebuild vs shipped | **identical** (both formats) | identical | identical |
| Peak / flat tops | −4.8 / 0 | −3.8 / 0 | −2.7 / 0 |
| Clicks | 19 | 41 | 7 |
| Seam z | 0.13 | −0.52 | 0.32 |
| Splices | 779 | 4 | 688 (4 % with corr < 0) |
| **L/R corr** | +0.47 | +0.58 | **+0.38** (4–16 kHz band −0.30) |
| HF > 5 kHz | −25.6 | −23.4 | −18.7 dB |
| Unrepeated HF bursts (>12 dB above the same bar position, ≥60 ms) | 7 | 1 | **16** (bars 2–3: 4.40, 5.37 and 7.31 s, +21 dB) |

- The salon high is the mildest of the four on stereo. Its high-only signs are the +4.7 dB HF lift and the HF bursts at 4.4–7.3 s.
- Worst splices: 16.23, 16.35, 8.65 and 40.81 s (corr −0.19 to −0.14).
- Confidence that "glitchy" here is measurable: low to medium.

### El Gran Comedor (F major, 120/128/136, 32 bars; high = highE)

| | low | mid | high |
|---|---|---|---|
| Duration / loop / expected | 64.50 / 64.000 / 64.000 | 60.50 / 60.000 / 60.000 | 56.971 / 56.4706 / 56.4706 |
| Rebuild vs shipped | identical | identical | identical |
| Peak / flat tops | −5.7 / 0 | −4.2 / 0 | −2.5 / 0 |
| Clicks | 4 | 7 | 10 |
| Seam z | −0.29 | −0.17 | 0.36 |
| Splices | 780 | 1 | 684 (6.7 % with corr < 0) |
| **L/R corr** | +0.80 | +0.79 | **+0.35** |
| **HF > 5 kHz / centroid** | −15.7 dB / 553 Hz | −12.3 dB / 940 Hz | **−7.0 dB / 2530 Hz** |
| Sub < 120 Hz share | −3.3 | −3.4 | −7.1 dB |
| Source clip runs (highE vs parent) | – | 0 | 15 |

- The comedor high has the largest brightness jump of any tier anywhere: 20 % of its energy sits above 5 kHz. The low end drops by 3.7 dB.
- Interpretation: a hissy, thin top tier.
- Worst splices: 10.00, 36.46, 44.82 and 52.34 s (corr −0.44 to −0.30).

### La Galería (A minor/Dorian, 114/122/130, 32 bars; high = highE)

| | low | mid | high |
|---|---|---|---|
| Duration / loop / expected | 67.868 / 67.3684 / 67.3684 | 63.451 / 62.9508 / 62.9508 | 59.577 / 59.0769 / 59.0769 |
| Rebuild vs shipped | identical | identical | identical |
| Peak / flat tops | −1.5 / 0 | −0.9 / 0 | −2.1 / 0 |
| Clicks | 214 | 270 | 199 (the hard-shoe taps trip the detector on every tier) |
| Seam z | −0.64 | −0.71 | −0.01 |
| Splices | 710 | 0 | 645 |
| **L/R corr** | +0.66 | +0.69 | **+0.20** |
| 0.5-s windows with corr < 0 | – | 0 % | **25 %** (38.2, 10.8, 40.2 and 1.2 s, corr down to −0.42) |
| Mono loss > 6 dB, share of 100-ms windows | 1 % | 0 % | 11 % |
| **Source clipping** (clip runs ≥ 2 samples), parent → highB → C → D → E | 2 | | 6 → 25 → 71 → **157** |
| LRA | 4.0 | 2.1 | **6.4 LU** |

- The clipping is baked into the master by the model and grows with every pass. It is attenuated by mastering (−4.6 dB makeup) but keeps its shape.
- Unrepeated HF noise beds at 24.67 s and 54.2 s, about 0.3 s each. HF stays at −33 dBFS where the same spot one bar earlier or later, and the mid tier, fall to −55 to −71 dBFS. Confidence that these are artifacts and not a stamp or ornament: low.

### Garden, as control (A minor, 92/98/104, 20 bars; high = highF)

| | low | mid | high |
|---|---|---|---|
| Duration / loop / expected | exact | exact | 46.654 / 46.1539 / 46.1538 |
| Rebuild vs shipped | −77 dB | −101 dB; m4a identical | −35 dB (known engine ceiling difference) |
| Clicks / seam z | 78 / 0.18 | 79 / 0.0 | 56 / −0.75 |
| L/R corr | +0.78 | +0.78 | +0.45 |
| HF > 5 kHz | −20.5 | −20.7 | −14.2 dB |

- The garden high shows the same direction of change: stereo 0.78 to 0.45, HF +6.5 dB.
- It is milder on stereo than bar and galería, and it was not reported.

### Ranking (worst first, by measured high-only change)

1. **Bar high.** L/R corr goes from +0.38 to −0.07, 59 % of half-second windows are anti-correlated, mono loss is down to −11.5 dB, and 19 % of its splices have negative match. Confidence that it is audibly degraded: medium-high.
2. **Galería high.** Corr +0.69 to +0.20, source clipping ×80 over the parent, LRA 6.4 LU, HF beds at 24.7 and 54.2 s. Medium.
3. **Comedor high.** Corr +0.79 to +0.35, centroid ×2.7, HF −12.3 to −7.0 dB, low end −3.7 dB. Medium.
4. **Salon high.** Corr +0.58 to +0.38, HF +4.7 dB, HF bursts at 4.4–7.3 s. Low-medium.

Unreported highs, for comparison:
- **cool-crowd high is the worst of all on stereo:** corr −0.15, 58 % of windows negative, −10 dB mono at 23.8 s.
- terraza high: corr 0.80 to 0.37, source clipping 33 to 682 runs.
- garden high: 0.78 to 0.45.
- billiards high shows no stereo loss (0.35 to 0.41).
- pool-garden uses old approved takes, not the chain.

### Pass-by-pass in the sources (`out/progress.json`), inter-channel correlation

| Level | parent | 1 pass (low used) | highB | 2nd | 3rd | 4th (used) |
|---|---|---|---|---|---|---|
| bar | 0.36 | 0.18 | 0.17 | 0.01 | −0.06 | −0.06 |
| salon | 0.57 | 0.47 | 0.48 | 0.47 | 0.43 | 0.37 |
| comedor | 0.79 | 0.67 | 0.66 | 0.51 | 0.39 | 0.32 |
| galeria | 0.68 | 0.63 | 0.57 | 0.45 | 0.31 | 0.15 |
| garden | 0.78 | 0.76 | 0.76 | 0.70 | 0.58 | 0.42 |
| cool-crowd | 0.51 | 0.18 | 0.17 | −0.17 | −0.35 | −0.44 (highE used: −0.35) |
| billiards | 0.30 | 0.30 | 0.32 | 0.33 | 0.31 | 0.30 |

- With each pass, the HF share rises 1–3 dB and onset agreement with the parent falls: bar 0.94, 0.89, 0.81, 0.73.
- Interpretation, medium confidence: the repeated latent re-sampling, not mixrs, produces the high-tier character. mixrs reproduces the files exactly and adds nothing high-specific beyond the aligned percussive layer.

## 4. Small assets (all levels)

All rendered files referenced by `assets/music/rendered/manifest.json` exist in both formats: 9 × 3 takes, 9 success tags, bar's successShort, and 8 bridges (terraza has none, being final). Every one has its loop or end points inside the file and an exact length. No rendered `transitions` exist (`[]` everywhere), and pool-garden uses `cuts` with no clip. There are no outro audio files. "OUTRO" in the console means tier 4 on autoplay, and the comedor's "cloche outro" is a visual. Accents are synthesized (`lib/music/accent_voice.dart`). All 32 synth score and MIDI paths in `assets/music/manifest.json` exist.

| Asset | Integrated LUFS (level's tiers −16.5/−16/−15) | L/R corr | Clicks | Notes |
|---|---|---|---|---|
| bar/success (final) | −14.1 | **−0.09** | 0 | Cut from high, so it inherits high's stereo collapse. Fades as designed |
| bar/success-short | −14.3 | **−0.18** | 0 | The one the game plays toward cool-crowd |
| bar/bridge | −17.2 | +0.55 | 7 | 112 → 112, no stretch |
| garden/success, bridge | −14.0, **−19.5** | +0.59, +0.62 | 6, 3 | Bridge stretches 104 → 144 (+38 %). 2.6 LU under its destination (pool-garden mid −16.9) |
| pool-garden/success, bridge | −14.9, −16.9 | +0.66, +0.23 | 2, 4 | Bridge stretches 136 → 100 |
| cool-crowd/success, bridge | −14.3, −16.2 | **−0.26**, +0.40 | 5, 14 | Bridge stretches 136 → 96 (−29 %) |
| billiards/success, bridge | −13.6, −16.7 | +0.44, +0.78 | 17, 0 | |
| salon/success, bridge | −14.2, −16.4 | +0.36, +0.59 | 0, 17 | Bridge 124 → 114 |
| comedor/success, bridge | −14.9, −17.8 | +0.31, +0.41 | 0, 2 | Bridge 136 → 108 (−21 %) |
| galeria/success, bridge | **−13.1**, −16.2 | **+0.10**, +0.78 | 24, 5 | Tag 1.9 LU above high. Bridge 130 → 96 (−26 %) |
| terraza/success (final) | −14.6 | +0.30 | 2 | Fades as designed |

- No asset is silent or a stub. None is more than about 3 LU from its level (worst: garden/bridge, 2.6 LU under its destination).
- Every tag is cut from the high grid (mix.py uses the last tier), so tags carry the high's stereo loss. This is worst on bar, cool-crowd and galería.
- Every bridge's first three beats are the high's harmonic part, WSOLA-stretched by up to ±38 % with the same 4-ms search. Interpretation: that is the riskiest place for stretch artifacts. Not verified by ear.
- Minor, code path: cool-crowd's synth fallback bridge in `levels/index.json` is `crowd_to_restroom` (into `restroom_nerve` at 132 bpm), while the next level is billiards. It plays only if the rendered bridge fails to load (`lib/gameplay/garden_page.dart:570-575`).

## 5. Why the tiers sound like three songs (measured)

- **Tempo jumps at every tier change.** Bar 100/106/112, salon 108/116/124, comedor 120/128/136, galería 114/122/130, garden 92/98/104: +6.0 to +7.4 % per step. `transport.dart` switches to the new take at the same bar, at its own tempo, with a 1-beat fade-in (`lib/music/transport.dart:373-386`). `tierTakes` is `[low, low, mid, mid, high]`, so the changes come at tiers 1→2 and 3→4.
- **Harmony is not the problem.** Bar-chroma cosine between tiers has a median of 0.97–0.99 and a minimum of 0.87 on all five levels checked. Onset-envelope match per bar is 0.78–0.96. The tiers are the same performance bar for bar.
- **Timbre and width jump.** Each step changes the sound noticeably:

  | Level | Centroid low/mid/high, Hz | HF > 5 kHz, dB | L/R corr | Sub < 120 Hz, dB |
  |---|---|---|---|---|
  | comedor | 553 / 940 / 2530 | −15.7 / −12.3 / −7.0 | 0.80 / 0.79 / 0.35 | −3.3 / −3.4 / −7.1 |
  | bar | 378 / 403 / 956 | −21.2 / −19.7 / −16.3 | 0.17 / 0.38 / −0.07 | −3.1 / −2.9 / −5.2 |
  | garden | 447 / 454 / 896 | −20.5 / −20.7 / −14.2 | 0.78 / 0.78 / 0.45 | −9.2 / −8.7 / −7.1 |
  | galeria | 549 / 564 / 1092 | −23.9 / −21.4 | 0.66 / 0.69 / 0.20 | −5.0 / −3.8 / – |

- Low and mid are close to each other. High jumps in brightness (×2 or more), loses bass, and goes wide and decorrelated.
- Onset density does not rise into high (comedor 9.05 to 8.15 onsets/s, galería 7.8 to 7.7), so the tier that should feel "bigger" sounds different rather than denser.
- Interpretation: the mid-to-high step combines a tempo jump with a sudden change of band. That reads as a new song.

## 6. Couldn't verify

- How anything sounds. I can't say whether the stereo decorrelation, the HF lift or the WSOLA texture is what the owner calls a glitch. The detectors found no discrete click, dropout or bad seam unique to high.
- The bar and garden shipped files can't be rebuilt bit-exact: the Python engine they were made with has been replaced. Their rebuild matches to −48 and −35 dB.
- Runtime playback (Web Audio scheduling, the tier crossfade, Safari's AAC decode) was not exercised. Only the files were measured.
- The splice timestamps come from an instrumented copy of mixrs in the scratchpad. Its output equals the shipped build sample for sample.
- The HF bursts in galería (24.67, 54.2 s) and salon (4.4–7.3 s) are flagged as unrepeated; whether they are artifacts or ornaments needs ears.

## Files

- Shipped audio: `/home/forge/src/kumbia-kombat/assets/music/rendered/<level>/*.{ogg,m4a}`; `/home/forge/src/kumbia-kombat/assets/music/rendered/manifest.json`.
- Mix config: `/home/forge/src/kumbia-kombat/tool/music/mix/levels.json`; `/home/forge/src/kumbia-kombat/tool/music/mix/report.json`; chain specs in `/home/forge/src/kumbia-kombat/tool/music/sheets/*.chain.json`.
- Masters: `/home/forge/.cache/tillandsias-project/kumbia-audio/act2-20261108/chains/{comedor,galeria,terraza}/`; `/home/forge/.cache/tillandsias-project/kumbia-audio/pipeline-20261107/chains/{bar,garden,salon,cool-crowd,billiards}/`.
- The analysis scripts and data were in that session's scratchpad, which doesn't survive a relaunch. The audit itself is also kept at `~/.cache/tillandsias-project/kumbia-audio/highfix-20261108/music-audit.md`, beside the candidate fixes.
