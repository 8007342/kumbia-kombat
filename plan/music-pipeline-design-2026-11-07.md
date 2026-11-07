# Music pipeline design, 2026-11-07

What the music equivalent of model sheets and wireframes is, what exists, and what we built today. **Nobody has heard any of this.** Every number measures timing, harmony, spectrum or level. None says the music is good. The owner tests on a phone at the end, without a listening round before it.

## The short version

- **Tiers sounded like separate songs because they were.** Each was its own performance: own tempo, own harmony at any moment, own timbre. The join also had a second fault: a transition always began with the loop's last bar, so leaving at any other bar jumped once on the way in and again on the way out.
- **Audio input turned out not to be needed for the main step.** Inside one workflow, a second sampler can start from the first sampler's latent. That is audio-to-audio without `LoadAudio`. The first take reproduces the owner's winner exactly, by MD5, and the tiers are re-sampled from it.
- **Those tiers are one performance.** Attacks line up at 0 ms lag, at the 11.6 ms resolution of the test, and bar harmony matches at 0.86 to 0.97 on the bar. Between the approved separate takes the same test gave 0.06 to 0.10 envelope correlation and 0.70 to 0.82 harmony.
- **Garden, bar, indoor party and billiards now change tier on the same bar of one performance**, with a short crossfade and no transition clip. Tempo still rises, by stretching each tier from that performance. The stretch showed no measurable cost.
- **The lawn keeps its approved takes and tempos**, as ruled. Its joins use a table of entry bars instead of a clip. It's better than it was, but it's still three performances, and **it's the join most likely to remain obvious.**
- **The risk to say out loud:** on garden, bar and party, only the mid tier is a take the owner approved. Low and high are new, and have not been heard. Their old masters are untouched, and going back is a change to `tool/music/mix/levels.json` plus a rebuild.

## The analogy

| Dancers | Music | Status |
|---|---|---|
| Model sheet: who this is | Style tags plus the owner-approved parent take | Today |
| Wireframe or Blender animation: where the body goes | A guide rendered from a sheet: chords, form, bars, key, tempo | Built, waiting for audio input |
| Video guide, re-sampled at a given strength | Audio-to-audio at a given denoise | Today from a parent latent; from a guide once audio input is live |
| Same character across poses | Same performance across tiers | Today |
| Layers in a room | Per-layer renders of our own score, each re-sampled | Needs audio input |

## What exists

Fact, from sources read today unless marked otherwise. Several fetches failed with connection resets, so some of this comes through search summaries.

| Route | What it does | Licence | Verdict |
|---|---|---|---|
| **ACE-Step 1.5 task types** | The upstream table lists text2music, cover and repaint on base, sft and turbo; extract, lego and complete on base only | Upstream MIT; studio pin table Apache-2.0 for the Comfy-Org repackaging | The model is cleared. ComfyUI core exposes no task switch that we found: only the encoder, samplers and latents. Third-party packs (`ComfyUI-AceMusic`, `ACE-Step-ComfyUI`) expose the rest. They aren't pinned, and this note doesn't ask for them |
| **Audio-to-audio by denoise** | Encode audio, sample at denoise under 1 | Core nodes | **Works today from a latent in the same graph.** Measured below. From a file: needs `LoadAudio` |
| **Repaint by mask** | `SetLatentNoiseMask`, with `LatentCut` and `LatentConcat` to build a seam | Core nodes | Allowed but **not tried.** One source says the node pack repaints with its own controls; none confirms a mask works on ACE latents. It stays the next experiment for lawn seams |
| **`ReferenceTimbreAudio`** | Attaches a reference latent to the conditioning; a Comfy note says to turn off `generate_audio_codes` with references | Core node | Not tried. A community note says this route carries tempo and structure and that starting from the latent carries more. That matches what we found |
| **Structure tags in `lyrics`** | `[intro]`, `[verse]`, `[chorus]` | Model feature; docs name verse and chorus | **Tested and rejected.** See option a |
| **MusicGen melody** | Chroma-conditioned generation | **Weights CC-BY-NC 4.0** | Out |
| **YuE2, MuLaCover** | Song generation, cover | **CC BY-NC 4.0** | Out, though YuE2's nodes are in the studio |
| **SheetSage2 (`SheetSage2AudioToABC`)** | Audio to ABC notation, as a local ear | **Weights CC BY-NC 4.0**; code licence unnamed | **Not usable.** The class is in `/object_info`, but its loader, `AudioEncoderLoader`, is refused as `node_not_pinned`, and it lists no weights. We shouldn't ask for it: the weights are non-commercial. It feeds YuE2 anyway |
| **Stem separators** | Demucs, Spleeter, Open-Unmix, and the rest | Demucs code MIT, but its fork says "The license of the weights is not clear"; MUSDB18 tracks "can only be used for academic purposes"; umxl is CC BY-NC-SA 4.0; others state none. From macuahuitl-fedora's research, not legal advice | **Don't use or plan on them.** No separator with clearly permissive weights was found. Stems come from rendering our own scores per layer |
| **MIDI to audio** | Rendering a score through instruments | Our synth is ours | We render guides ourselves. No neural MIDI-to-audio model with clear permissive weights was found; the search was shallow |
| **Stable Audio 3, MiniMax Music 3** | Other generators | Revenue cap with registration; on-screen credit | From `plan/research/local-music-models-2026-11-06.md`. Not needed today |
| **XL base** | Pinned, untried until today | Apache-2.0 per the pin table | Two takes ran. See below. Too few to judge |

**A local ear we can use:** `tool/music/sheet.py ear` matches chord templates against chroma, one guess per bar, using no model. On the billiards guide it read 23 of 24 known bars. It mistook Eb for Gm, which share two notes. It also read the bar's winner as C minor on every bar, where `mix.py`'s key finder says C major. So **the "F minor, C major, G major against C minor" warning in the mixing note may partly be a weak key finder.** Neither tool has been tested on real recordings with known keys.

## "Do we need to up our game?"

**Yes, in method; no new model is needed yet.** Our generator was fine for themes. What was missing was a way to make parts agree. In-graph latent chaining gives that today. Audio input adds what chaining can't: music written by us instead of found by seed.

## The pipeline

```
sheet (key, tempo, form, chords)        tool/music/sheets/<level>.json
   |
   |  today: seed search and owner ear    after 2018-auin: rendered guide per layer
   v                                      tool/music/sheet.py guide
parent take                             workflow from tool/music/mix/build_workflow.py
   |
   |  latent re-sampled at denoise 0.6, repeatedly for high tiers
   v
layers on one grid                      tool/music/sheets/<level>.chain.json
   |
   |  one beat map, one loop, per-tier tempo, EQ, aligned percussion
   v
runtime layers                          tool/music/mix/mix.py, manifest `layerFadeBeats`
```

Every take can be remade from `tool/music/sheets/<level>.chain.json`, and each parent has been checked against its winner by MD5. Only on this host and tray build; another GPU or ComfyUI may not reproduce a take.

### What needs 2018-auin

The coordinator expects audio input only after a relaunch, held until the GPU waves finish. **This is the first thing to run afterwards.**

| Step | Needs audio input? |
|---|---|
| Parent, chained tiers, shared grid, runtime layers | No, done |
| Guide from a sheet (`sheet.py guide`) | No, done. It renders today; nothing can read it |
| Audio-to-audio from a guide | **Yes** |
| Re-sampling an existing master, without regenerating its parent | **Yes.** This would finally let the lawn's joins be re-sampled from the real audio |
| Bridges from the real join (`ace-xl-bridge.api.json`) | **Yes** |

Ready: `tool/music/workflows/ace-xl-guided.api.json`, with `LoadAudio` titled `guide`, its `audio` set to `$guide`, denoise 0.7 and `generate_audio_codes` off.

Exact requests, all under 2018-auin, which macuahuitl-fedora already has:

1. Pin the class `LoadAudio`.
2. Let `inputs` bind `$name` on `LoadAudio`, as it does on `LoadImage`, from a file under `/work/tmp/imagegen/`.
3. Check `VAEEncodeAudio` is pinned. It was not exercised today.

First run afterwards, in order: render `tool/music/sheets/billiards.json`, run denoise 0.5 to 0.9 on the sum, and test with `tool/music/sheet.py ear` and `shared_grid.py` whether the chords and bars survive.

Not requested: `AudioEncoderLoader`, because of SheetSage2's weights.

### Workflow location

`studio_run_workflow` only reads paths inside the main checkout, so generated workflows ran from `wt/musicwf/`, which git ignores. Provenance files name that path. `build_workflow.py` regenerates each workflow from its spec.

## Measurements: choosing a way to join

Takes re-sampled from bar mid, seed 55005. "Lag" and "envelope" compare attacks in 8-beat windows, at 11.6 ms resolution. "Harmony" is chroma per bar, 1 being the same. Onsets, centroid and spread describe the whole take.

| Take | Lag median, P90 ms | Envelope | Harmony | Onsets/beat | Centroid Hz | Spread Hz |
|---|---|---|---|---|---|---|
| **Mid, the parent** | | | | 2.95 | 348 | 495 |
| Old approved low | -23, 70 | **0.06** | 0.70 | 3.09 | 216 | 496 |
| Old approved high | 12, 70 | **0.10** | 0.82 | 3.42 | 827 | 1191 |
| Same seed, structure tags | 35, 46 | 0.28 | 0.87 | 3.13 | 399 | 654 |
| Child, 0.5, tags only | 0, 0 | 0.96 | 0.98 | 3.00 | 333 | 441 |
| Child, 0.6, codes off | 0, 0 | 0.96 | 0.96 | 2.86 | 355 | 475 |
| Child, 0.7, codes off | 0, 0 | 0.94 | 0.95 | 2.82 | 359 | 453 |
| Three passes at 0.6 | 0, 0 | 0.84 | 0.89 | 3.24 | 517 | 570 |
| Four passes at 0.6 | 0, 0 | 0.71 | 0.86 | 3.38 | 490 | 596 |
| One pass at 0.95, codes on | 0, 0 | 0.66 | 0.78 | 3.42 | 566 | 865 |

What this shows:

- **Reproduction is exact.** Parents of garden, bar and party match their winners by MD5 of decoded audio.
- **One pass under about 0.75 barely changes anything,** whatever the tags. Repeating passes moves further while holding the beat, which is the useful discovery. A single pass at 0.95 moves as far on spectrum but loses more of the beat and harmony.
- **Sparser tags don't reduce density much.** Low only falls about 3% on onsets. Darkening it with a gentle EQ is what moves it below mid. The approved lows, which the owner asked to have fuller, were also darker than mid: 216 Hz against 348.

### Option a: one long take with structure tags. Rejected.

Two takes with `[Intro] [Verse] [Build] [Chorus] [Outro]` in `lyrics`. Level by 6-bar block (dB): seed 55005, -13.7, -11.2, -11.3, -11.1, -11.6, -11.1; seed 55006, -11.2, -11.4, -11.4, -11.3, -14.5, -13.9. **Neither grows from sparse to full**, and centroid doesn't climb either. The same seed also stopped being the winner: envelope 0.28. Two takes is a small sample, but with the winner's identity gone there's little reason to pursue this.

### Option b: tiers from one take. Chosen, in a stronger form.

The brief imagined filtering or carving low tiers. Re-sampling the latent gives real re-performed arrangement on the same grid, with EQ doing the last step on low.

### Option c: separate takes, better joins. Chosen for the lawn only.

See "The lawn".

### Tempo: rise kept

The coordinator asked to keep the rise if joins stay clean, citing "Let's try to keep the speed up", softened by "Speed isn't the only factor". The runtime keeps the bar across tempos, as beats are the file's beats.

Bar low and high built both ways, from the same masters:

| Measure | Stretched to 100 / 106 / 112 | Held at 106 |
|---|---|---|
| Typical attack error, ms, low / mid / high | 17.7 / 7.5 / 18.8 | 16.2 / 7.5 / 19.6 |
| Worst block, ms | 23 / 21 / 27 | 22 / 21 / 32 |
| Attack sharpness, low / mid / high | 0.48 / 0.55 / 0.39 | 0.47 / 0.55 / 0.38 |

**The stretch costs nothing measurable, so tempo stays as approved, and charts stay fair.** Nothing here tells whether a roughly 6% step is itself audible as a step, and an audible step in tempo might be what the owner calls obvious. That can't be measured here. Holding a level at one tempo is one line per tier in `levels.json`, with charts to recheck.

The attack error is the children's own, not the stretch's: children sit about 17 ms from the parent's grid, against 7.5 for the parent. That prompted the next step.

Attacks in re-sampled tiers also came out softer: 0.39 on high against 0.55. So high tiers carry the parent's percussive part mixed underneath (`layer` in `levels.json`), which is possible only because they're sample-aligned. It isn't a separator's output: it's a median-filter split of our own take, written in `mix.py`.

## What shipped per level

Proposals the owner can reverse. Masters: `~/.cache/tillandsias-project/kumbia-audio/pipeline-20261107/chains/<level>/`. Config: `tool/music/mix/levels.json`. Specs with every tag and seed: `tool/music/sheets/<level>.chain.json`.

The recipe, the same everywhere except the lawn:

- **Mid:** the parent. On garden, bar and party it's the owner's approved take, unchanged in performance.
- **Low:** one pass at 0.6, `generate_audio_codes` off, tags for a small band, then a 3 dB high shelf at 1.5 kHz.
- **High:** four passes at 0.6 (three on the party, where a fourth took out the low end), codes off, tags for a full band, with the parent's percussion mixed under it at -6 dB (-4 on the party).
- **Join:** same bar, crossfade over 1 beat (0.5 on the party, whose tempo steps are larger). No clip.
- **Loudness:** -16.5, -16, -15 LUFS. Low went up by half a unit after the first build showed its plain level was 1.8 dB under mid; the owner has said low tiers are too quiet.

| Level | Tempos | Bars | Opus / AAC MB |
|---|---|---|---|
| garden | 92, 98, 104 | 20 | 2.99 / 2.6 |
| pool-garden | 144, 160, 136 | 32 | 3.07 / 2.76 |
| bar | 100, 106, 112 | 24 | 3.48 / 3.02 |
| cool-crowd | 112, 124, 136 | 28 | 3.43 / 2.89 |
| billiards | 96, 100, 104 | 28 | 3.94 / 3.52 |

### Ladder, measured on the encoded files

| Level, tier | BPM | Onsets/beat | Centroid Hz | Spread Hz | LUFS | True peak dB | Join in: harmony, below take | Tempo step |
|---|---|---|---|---|---|---|---|---|
| garden low | 92 | 3.47 | 420 | 582 | -16.5 | -3.4 |  |  |
| garden mid | 98 | 3.54 | 417 | 690 | -16.0 | -2.9 | 0.969, -0.008 | +6.5% |
| garden high | 104 | 3.58 | 591 | 964 | -15.0 | -0.9 | 0.732, 0.235 | +6.1% |
| bar low | 100 | 3.02 | 322 | 383 | -16.5 | -3.9 |  |  |
| bar mid | 106 | 2.97 | 346 | 525 | -16.0 | -3.3 | 0.964, -0.011 | +6.0% |
| bar high | 112 | 3.06 | 643 | 642 | -15.0 | -4.4 | 0.931, 0.034 | +5.7% |
| cool-crowd low | 112 | 3.18 | 335 | 455 | -16.5 | -5.2 |  |  |
| cool-crowd mid | 124 | 3.43 | 327 | 588 | -16.0 | -4.1 | 0.956, 0.024 | +10.7% |
| cool-crowd high | 136 | 3.21 | 519 | 613 | -15.0 | -2.5 | 0.877, 0.082 | +9.7% |
| billiards low | 96 | 2.61 | 299 | 222 | -16.5 | -4.5 |  |  |
| billiards mid | 100 | 2.48 | 312 | 241 | -16.0 | -3.6 | 0.545, -0.022 | +4.2% |
| billiards high | 104 | 2.43 | 368 | 391 | -15.0 | -1.6 | 0.699, -0.128 | +4.0% |

- **"Below take" is what a seam loses against the take's own bar lines.** Near 0 means the seam changes harmony no more than the music does anyway. On the old bar ladder it was 0.24 for low into mid at the same bar, against 0.01 now.
- **The steps are small and unequal.** This follows the owner's "small steps". Spectrum rises on all levels. Onsets per beat don't reliably rise: the party's high still falls below mid, as it did with the approved takes.
- **The worst seam is garden mid into high**, 0.235 below its take, so harmony moves further there than elsewhere.
- **Level across a seam is larger than within a take** on low into mid, at 3.9 dB against 1.2 on the bar before low was raised. The crossfade softens it. Listen for a jump there.
- **Attacks on re-sampled tiers sit 3 to 17 ms from the grid**, against 3 to 10 on the parents. Bar and billiards lows are the worst, at about 16 ms. They haven't been tested in play.

### Loops

Loop length was chosen by seam, measured on the parents. A loop of 28 bars replaced 32 on the party: harmony 0.98 and texture 0.74, against 0.84 and 0.01, which was the weakest seam in the old build. Garden went from 24 bars to 20: 0.996 and 0.96, against 0.92 and 0.33. The garden loop now repeats sooner, after about 52 s rather than 63 s on low. Billiards uses 28: 0.79 and 0.85. Its harmony across the wrap is the weakest of the set, so listen there.

### The lawn

Takes, tempos and order unchanged: 144, 160, 136, as ruled, because its growth comes from those particular takes, including a low tier the owner called sharper and richer.

- **No clip any more.** The old clip started with the loop's last bar, so leaving at any other bar jumped, at a median harmony of 0.79 and a worst of 0.57 on mid into high, and the clip also dipped 3 dB on purpose.
- **Now:** the outgoing take plays through to the boundary. The incoming take starts at the bar written for that exit, from a table in the manifest (`cuts`), its downbeat clean and the old take fading over 1 beat.
- **Seam harmony from the table:** 0.85 to 0.92 median, worst 0.72.
- **Still there, and can't be fixed without audio input:** tempo steps of +11%, -15%, +18%, -10% and +6%, and a change of timbre. Keys measure C major, A minor and E minor, which are related, but see the warning on the key finder. **This is the join most likely to stay obvious.** Tell us after the phone test. Next: re-sample lawn tails from real audio with 2018-auin.

## Billiards

Level id `billiards`. A proposal: **a dark elegant tango with a mambo pulse**, in G minor, around 100 BPM. The tags, in full, are in `tool/music/sheets/billiards.chain.json`: bandoneon lead, staccato pizzicato strings, piano stabs, upright bass, claves, dry woodblock clicks for the pool hall. No cumbia, swing or boogaloo words, and no accordion or big-band brass in mid.

24 takes in four styles, six seeds each, seeds 57000 to 57305. **14 of 24 pass the timing filter.**

To shortlist, I compared the owner's blind winners with the takes they beat on the same page (bar 55005, party 53010; 3 others each). In both, the winner had the **highest lead salience**, how far the strongest pitch stands above the rest in the lead register: 80 against 64 to 69, and 59 against 52 to 58. Arrangement movement was high in both, and highest in the bar's group. Two winners isn't evidence of much, and the measure was picked after looking. So this can shortlist, not choose.

| Take | Style | Timing | Salience | Movement | Melodic motion | Measured key |
|---|---|---|---|---|---|---|
| **57100, chosen** | Tango | Pass, wander 9.6 ms | 93 | 0.96 | 0.163 | G minor, as asked |
| 57304 | Velvet bolero to mambo | Pass, 6.1 ms | 85 | 0.62 | 0.065 | |
| 57200 | Noir cha-cha-cha | Pass, 4.1 ms | 71 | 1.18 | 0.057 | |
| 57102 | Tango | Pass, 22.6 ms | 152 | 0.76 | 0.084 | Narrow range, 10 semitones: possibly one held note |

57100 leads on melodic motion among passes and has the most distinct style from the other rooms. Its weak point: 12.9 semitones of lead range against 23 to 27 on the two winners, so its line may be narrow. **Whether it's "rich, charismatic and identifiable" is what the owner must judge.** To swap, change the parent's seed in the chain spec and rebuild.

Tempos 96, 100, 104: the chart is meant to be slow and rich, and small steps suit a small room. The success tag is 4 bars at 104, 9.2 s, fading out in the last 4 beats, the same shape as the bar's finale. `tool/music/sheets/billiards.json` is a written sheet for the guided run, not what today's takes came from.

**XL base:** two takes at 40 steps, cfg 4, with the mambo-bolero tags, about 30 s each against 11 for turbo. Seed 57401 passes timing, salience 69. Seed 57400 fails as half-time (0.98), with salience 119 but a 5-semitone range. **Too few to say it beats turbo.** A proper round is worth doing with guides.

## Wiring

Keys in `assets/music/rendered/manifest.json`, for the party and billiards agents:

| Level | Keys |
|---|---|
| `bar` | `success` (4 bars, final), `successShort` (2 bars), `bridge` to `cool-crowd`. In the campaign with a next room, use `successShort` then `bridge` |
| `cool-crowd` | `success` (2 bars at 136, not final), `bridge` to `billiards`, `toTake: low` |
| `billiards` | `success` (4 bars at 104, `final: true`), no bridge. Ends the campaign |
| Any layered level | `layerFadeBeats`, `gridTier`, an empty `transitions` |
| `pool-garden` | `cuts`, an empty `transitions` |

Tempos are unchanged on the four existing levels, so charts are unchanged. Billiards is new.

`pubspec.yaml` lists `rendered/cool-crowd/` and `rendered/billiards/`.

## Mix

`masterDb` is -1.5 in the manifest's `mix`, from the mixing note's proposal: output peaked at 0.997, and this takes that to about 0.84 by arithmetic, not measured in a browser. A tier's `gainDb` in `levels.json` now reaches the manifest, so the owner's mixer JSON can go straight in; none has been supplied yet, so all are 0.

## What went wrong

- **I froze the forge, twice.** A 12-worker build, with my new full-take separation, took about 11 of 12 GB and stalled for 20 minutes until the host's agent killed it. Then I restarted it, because I read the first failure as my shell's backgrounding and didn't look at memory. It cost everyone on the machine that time. `mix.py` now defaults to 1 worker, caps at 2, errors at 4 GB per process, won't start above 6 GB in use, separates in 10 s blocks, holds one level at a time, and writes files and manifests atomically. Measured peak in a worker: 1.5 GB.
- **A wrong first guess at denoise.** 0.5 kept everything and changed nothing useful. Single passes up to 0.75 barely move density, and it took a second sweep to find repeated passes.
- **`overrides.seed` fails on a workflow with no `$seed` title,** which cost one round of queueing. A studio result's `seed` field is random for those workflows; the seeds in the graph are what's used, and the MD5 checks confirm it.
- GPU queues ran 5 to 12 minutes per job, shared with other agents.

## Not verified

- **Nobody has heard any of it:** the new tiers, the crossfades, the lawn's cuts, the tempo steps, or the billiards theme.
- Not run in a browser or on a phone. Tests use fakes for the deck. Crossfades over 1 beat haven't been measured in Web Audio.
- Whether stretched tiers sound stretched. Attack measures say no difference, but those aren't ears.
- Whether a 6% or 10% tempo step at a boundary reads as obvious. If it does, hold one tempo: per-tier `bpm` in `levels.json`, then a rebuild and chart tests.
- Whether the re-sampled tiers keep the identity the owner loved. Their beat and harmony match the parent; melody wasn't measured directly.
- Keys: two tools disagree. Everything on the layered levels shares one performance, so it doesn't matter within a level. It still matters at bridges and on the lawn.
- Bridges between levels were remade the old way: bar into party 0.69 harmony, party into billiards 0.69. Those are what a cinematic plays over.
- **Phase wander is high on billiards high (135 ms) and garden low (63 ms)** in verify, while the drift test, which compares the loop's ends, reads 2 ms. Most likely the quarter-note pulse is weak in some windows, not a drifting beat, but that is a guess.
- `bar1Confidence` remains low on bar (0.26) and party (0.02), so a chart's first beat may not be the bar's downbeat there. Billiards reads 1.0.

## For the owner to judge, in order

1. Does a change of tier now sound like one band getting bigger? Garden and bar first.
2. Are the new lows and highs still your music? If not, `levels.json` can go back to the old takes.
3. Is the tempo step noticeable? If it's what bothers you, tell us: one tempo per level is a small change.
4. The lawn's joins.
5. Billiards: is it charismatic, or background?

Sources:
[ACE-Step 1.5 README mirror](https://huggingface.co/TTS-AGI/ACE-Step-1.5-Backup/blob/main/code/README.md),
[Diffusers ACE-Step docs](https://huggingface.co/docs/diffusers/v0.39.0/api/pipelines/ace_step),
[ComfyUI ACE-Step 1.5 tutorial](https://docs.comfy.org/tutorials/audio/ace-step/ace-step-v1-5),
[ReferenceTimbreAudio](https://docs.comfy.org/built-in-nodes/ReferenceTimbreAudio.md),
[SheetSage2AudioToABC](https://docs.comfy.org/built-in-nodes/SheetSage2AudioToABC.md),
[SheetSage2 licence discussion](https://huggingface.co/m-a-p/SheetSage2/discussions/2),
[ACE-Step-ComfyUI](https://github.com/ace-step/ACE-Step-ComfyUI),
[MusicGen model card](https://huggingface.co/spaces/CryptoThaler/melody/blob/main/model_cards/MUSICGEN_MODEL_CARD.md),
`plan/research/local-music-models-2026-11-06.md`.
