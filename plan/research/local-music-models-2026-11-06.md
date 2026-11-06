# Local music models for composable, looping level music

Date: 2026-11-06. Desk research only: no model ran, nothing was installed, nobody has listened to
anything in this report.

Direction: the owner ruled mid-research that "our music scores were limited by the midi format, let's give
the new models free reign to reimplement the concept of the music in the levels"
(`plan/owner-rulings-2026-11-05.md`). So models compose each level from its place, mood and style. The
scores in `assets/music/` are no longer a constraint. "Our score as guide, model as performer" is now a
side route (section 7).

Evidence labels:

- **[checked]** I read the primary file or queried the running system.
- **[vendor]** the project's own claim, not independently checked.
- **[others]** someone outside the project reports having done it.
- **[secondary]** only blogs or search summaries; the primary page would not load or was not found.
- **[judgment]** my reasoning, not a fact.

## 1. Answer

**The owner's idea looks workable, with one change: don't build the tiers from stems locked across
separate generations, because nothing shows that holds. Build each tier as a whole take.**

- No open model I found promises an exact tempo, an exact bar count, a seamless loop, or layers that lock
  across separate generations. ACE-Step's own tutorial says `bpm=120` "might be 118 or 122" [checked].
  MiniMax says the same in its limitations [checked].
- Exact loops can be made in post. One browser game's merged PR did it with ACE-Step 1.5, at 0.05 to 0.65 ms per
  bar of drift [others, section 3].
- Tiers are best built as **a ladder of whole takes, one per tier, each rendered at its own tempo**,
  switched at phrase boundaries. Only stems cut from a single take are locked together, and the
  separators that cut them have a licence problem (section 6).
- **ACE-Step 1.5 XL** is the only candidate that combines a permissive licence, explicit BPM and key
  parameters, editing tasks, a fit on this GPU, and a third-party game loop pipeline.
- **The largest unknown is style.** I found no test of cumbia, salsa or fast swing on any of these models.
  One blog review calls ACE-Step weak in jazz [secondary]. Only the pilot in section 10 can answer this.

## 2. This host

| Fact | Value | Evidence |
|---|---|---|
| GPU | NVIDIA RTX A5000, 23.6 GB; 23.18 GB free with no holders | [checked] `system_stats`, `gpu.status` |
| Studio | ComfyUI 0.40.0, running | [checked] `system_stats`, `studio.status` |
| Native audio generation nodes | `TextEncodeAceStepAudio1.5`, `EmptyAceStep1.5LatentAudio`, `ReferenceTimbreAudio`, `MiniMaxMusic3TextEncode`, `EmptyMiniMaxMusic3LatentAudio`, `ConditioningStableAudio`, `EmptyYuE2LatentAudio`, `YuE2GenerateMusic` | [checked] `/object_info` |
| Native audio plumbing | `LoadAudio`, `SaveAudio`, `SaveAudioOpus`, `SaveAudioMP3`, `TrimAudioDuration`, `AudioConcat`, `AudioMerge`, `VAEEncodeAudio`, `VAEDecodeAudio` | [checked] `/object_info` |
| Separation or beat-tracking nodes | None installed | [checked] `/object_info` |
| Audio model weights on disk | None | [checked] `studio.models` lists no audio file |
| Forge | No torch, no `sox`, `rubberband` or `fluidsynth`. `ffmpeg` 9.0.2 has libopus, aac, libmp3lame, loudnorm, ebur128, atempo, but no `rubberband` filter | [checked] |

`TextEncodeAceStepAudio1.5` takes `tags`, `lyrics`, `seed`, `bpm` (integer, 10 to 300), `duration`,
`timesignature`, `keyscale`, `cfg_scale`, `temperature` [checked]. Text-to-music can therefore run in the
studio with no custom nodes once weights are pinned.

The studio refuses models outside its pinned table, so weights need a new row in the tray's `models.tsv`.
`plan/forge-generic-services.md` section 5 records that ACE-Step 1.5 XL is approved and waiting on an
engine, and that **Demucs is not approved**.

## 3. Candidates

### Can a commercial game ship the output?

| Model | Weights licence | Output in a commercial game | Training data | Verdict |
|---|---|---|---|---|
| **ACE-Step 1.5 / XL** | MIT [checked: HF tags on base and XL] | Card: "You can strictly use the generated music for commercial purposes" [checked] | "Legally compliant": licensed tracks, royalty-free recordings, synthetic MIDI-to-audio [vendor]. No list published that I found | **Ship.** Data cleanliness is the authors' word only |
| **Stable Audio 3 Small / Medium** | Stability Community License, gated; Gemma terms for the text encoder [checked: card] | Allowed under $1M yearly organisation revenue, with registration for commercial use [secondary: Stability's page reached only through search snippets] | 806,284 AudioSparx licensed, 472,618 Freesound CC-0, CC-BY, CC-Sampling+ [checked: card] | **Ship, with registration.** The best-documented data here. Revenue cap applies |
| **MiniMax Music 3** | MiniMax-Music3 Community License [checked: LICENSE] | Allowed, but you must "prominently display 'MiniMax-Music3'" in the product UI; written authorisation above $20M yearly revenue [checked]. Includes use restrictions and an indemnity clause [checked] | No data statement found in the card sections I searched | **Ship only if the owner accepts the on-screen credit** |
| **Magenta RealTime 2** | CC-BY-4.0 weights, Apache-2.0 code [checked: model card, HF tag] | Allowed with credit; terms forbid infringing outputs [checked] | About 71k hours of stock music, mostly instrumental [checked] | **Ship with credit.** Poor fit (below) |
| **DiffRhythm 2** | Apache-2.0 [checked: HF card] | No restriction found | Not checked | **Ship, poor fit:** instrumental generation is still an unticked TODO [checked] |
| **HeartMuLa 3B** | Apache-2.0 from 2026-01-20 [checked: repo README] | No restriction found | Not described | **Ship, poor fit:** tags and lyrics only, no documented instrumental mode, reference audio still TODO, about real-time speed [checked] |
| **YuE (v1)** | Apache-2.0, credit requested [secondary: HF card returned 401] | Not checked | Not checked | Superseded song model; not pursued |
| **YuE2** | **CC BY-NC 4.0: non-commercial** [checked] | The licence text does not address outputs [checked]. One blog says the restriction reaches them [secondary] | Not described | **Do not use.** Nodes are in the studio, which makes this easy to do by accident |
| **MuLaCover** | **CC BY-NC 4.0: non-commercial** [checked] | **Outputs explicitly non-commercial**, including audio and MIDI, without a written licence [checked: MODEL_LICENSE section 3] | Not checked | **Do not use** |
| **MusicGen / AudioCraft** (includes Melody, Style, MAGNeT) | **CC-BY-NC 4.0: non-commercial** [checked: `LICENSE_weights`, README] | Non-commercial weights | Licensed data, per secondary sources | **Do not use** |
| **MusicGen-Stem** | Paper promised release; I found no weights or licence. Inherits the MusicGen question [secondary] | Unknown | Unknown | **Do not use** |
| **Stable Audio Open 1.0** | Community License [secondary] | As Stable Audio 3 | Not checked here | Superseded by Stable Audio 3 |
| **Stable Audio 2.5, Stable Audio 3 Large** | API only, no local weights [secondary] | n/a | n/a | Out of scope |

Separately, whatever the model licence says: the US Copyright Office's 2025 report says copyright protects
AI output only where a human determined sufficient expressive elements [secondary, summaries of the report].
So the game may not own enforceable rights in raw generated tracks, and others could reuse them. This is
not legal advice. Nor does any model licence warrant that a generated melody avoids resembling an existing
song; `assets/music/LICENSE.md` already notes the melodies haven't been checked against any tune database.

### Hardware and control

| Model | VRAM and size | Speed | Tempo and key | Instrumental |
|---|---|---|---|---|
| **ACE-Step 1.5 XL** | This 23.6 GB card is in the docs' 20-24 GB tier: XL turbo or SFT with no offload, 1.7B LM recommended. The docs' table suggests xl-base for extract, lego and complete at 24 GB or more, while the tutorial says 12 GB or more, so test it. XL base about 20 GB on disk [checked: docs, HF file sizes] | Under 10 s per song on an RTX 3090 for the non-XL model [vendor]. **XL on this card unmeasured.** Issue #1350's title reports SFT passing a 600 s timeout, so measure SFT before planning around it | `bpm`, `keyscale`, `timesignature`, `duration` parameters, soft: "118 or 122" [checked]. 60-180 BPM "works well" [checked] | `[Instrumental]` [checked] |
| **Stable Audio 3 Medium** | Peak 5.07-6.52 GB on an H200 [checked: repo]. Main file 9.22 GB [checked] | 380 s in 1.31 s on an H200 [vendor]; not this card | BPM only in prompt text; no key parameter [checked] | Yes (music and SFX model) |
| **Stable Audio 3 Small** | Peak 1.69-2.40 GB [checked: repo] | 30 s in 0.46 s on an H200 [vendor] | Prompt text | Yes |
| **MiniMax Music 3** | Under 24 GB at full precision; about 22 GB with offload; 8 GB with streaming [checked: card] | Not found | BPM and key in caption; card warns they "may not always match" [checked] | `[Instrumental]` section tag [checked] |
| **Magenta RT 2** | No figures. Official real-time needs Apple Silicon; offline on NVIDIA is stated [checked: README] | Chunks of about 2 s; live model | No BPM or beat lock documented. Takes text, audio and MIDI steering [checked] | Mostly instrumental training [checked] |

Genre coverage for the game's styles:

- **ACE-Step:** nothing measured. One review places it strong in pop, rock and electronic, weak in jazz
  ("improvised solos lack the rhythmic looseness") [secondary]. A style-alignment figure of 6.47 for ACE-Step
  versus 46.8 for Suno circulates, but the review itself says the scales differ, so it proves nothing.
- **Stable Audio 3:** coverage depends on AudioSparx; no Latin figures published.
- **Magenta:** the v1 card, which the v2 card refers to, says data is primarily Western instrumental with
  "incomplete coverage" of world traditions [checked]. A real warning for cumbia.

### Composability, the real question

| Capability | ACE-Step 1.5 | Stable Audio 3 | MiniMax Music 3 |
|---|---|---|---|
| Seamless loop of exactly N bars | No. Paper's "short loops" phrase is not a loop feature [vendor]. Done in post [others] | No loop feature mentioned [checked] | Not offered [checked] |
| Stems at generation | No. `lego` adds one track in context; base and XL-base only [checked] | No | No |
| Layers locked across generations | **Reported failing.** #117: `lego` onsets off by 20-80 ms with drift, on a 135 BPM source [others]. Closed "fixed" by #810, but #810 repairs source latents being silenced; it doesn't claim a timing lock [checked]. No later measurement found | Vendor explainer says independent prompts won't reliably share key and tempo [secondary] | Not offered |
| Same-section variations | `cover` "retake lottery", `audio_cover_strength` 0 to 1 [checked: docs] | Audio-to-audio [checked: repo] | Not documented |
| Fix a region | `repaint` with start and end times [checked: docs] | Inpainting [checked: card, repo] | Not documented |
| Continuation | `complete` adds instruments (base only) [checked]; extend through third-party nodes [secondary] | Continuation [checked: card] | Not documented |
| Stem extraction | `extract`, 12 track names including brass, percussion, woodwinds; base only [checked]; quality unmeasured | No | No |

**Proven by others.** [atl-arcade PR #163](https://github.com/William-Hill/atl-arcade/pull/163), merged
2026-11-05: four instrumental loops from ACE-Step 1.5 Turbo, run on CPU, driving a browser game's beat
clock. Figures are that project's own, written by a coding agent; they measure timing, and no listening
verdict is stated:

| Track | BPM | Bars | Drift (ms/bar) | Jitter (ms) | Opus size |
|---|---|---|---|---|---|
| Funk bounce | 100 | 24 | -0.045 | 0.58 | 776 KB |
| Deep house | 124 | 31 | +0.129 | 3.70 | 865 KB |
| Trap-soul | 80 | 20 | -0.653 | 0.95 | 882 KB |
| Roller-rink disco | 120 | 28 | +0.461 | 1.63 | 814 KB |

Their prompt asked for 125 BPM and got a steady 124, so they gridded at the measured tempo. They reject
takes over 2 ms/bar drift or 6 ms jitter. They cut on a bar line and crossfade the first beat with the
audio past the loop end. They verified Opus and AAC decode sample-for-sample at bar lines in Chromium.

All four genres are grid-tight, machine-friendly styles. That's the closest evidence, not proof for live
Latin percussion or swing.

**Research only.** [LoopGen](https://arxiv.org/abs/2504.04466) (ISMIR 2025) makes loops by wrapping tokens,
for token models like MAGNeT [secondary]; MAGNeT is non-commercial, and it may not transfer to latent
diffusion. Nothing I found applies circular latents to these open audio models. Unexplored, not usable today.

**Half-time risk.** ACE-Step [issue #1325](https://github.com/ace-step/ACE-Step-1.5/issues/1325) reports a
120 BPM request grooving at about 60 for half-time genres [others]. Swing at 160 and two-feel cumbia are both
exposed. The grid gate has to test for this explicitly (section 5).

## 4. What the game needs, and what follows

Read from the code. Only the items below are real needs; note data, MIDI and tune-level gates aren't.

### Charts survive

`FightChart` holds limbs, beat offsets, `callBeats`, `introBeats` and tier variants
(`lib/gameplay/garden_session.dart`), defined per level. **Charts are in beats and don't read score notes**
[checked]. They need the beat grid only. Consequences:

- Charts still run unchanged, but were written alongside the old music. On a new take a required hit can
  land against the groove. A level's chart should be reviewed against its chosen take, using onset strength
  as a tool to suggest changes, with a person deciding [judgment].
- Beat clarity becomes a selection gate: reject a beautiful take whose pulse is not obvious enough to dance
  to [judgment].

### Timing budget

`RhythmJudge` allows 75 ms for perfect, 180 ms for good [checked]. atl-arcade's 2 ms/bar gate is too loose
if left uncorrected: 32 bars at 2 ms/bar is 64 ms, most of a perfect window. Two steps close that
[judgment]:

1. Remove linear drift by resampling or stretching the whole take to the exact target BPM.
2. Gate on what's left: no beat more than 15 ms from the grid, anywhere in the loop.

### Tempo tiers: an owner decision

`MusicTransport` binds tier to tempo through `score.tempos[tier]` and changes at phrase boundaries [checked].
Today's ladders step +3 BPM per tier; the pool lawn steps +8.

| Option | How | Garden 92-104 | Pool 128-160 | Cost |
|---|---|---|---|---|
| **A. Per-tier takes (recommended)** | Render each tier at its own BPM; correct by at most about 1.5% | No stretch | No stretch | 5 takes must pass the gate; the tiers may differ musically |
| B. Stretch one master | Stretch from the centre tempo | ±6.1% around 98 | **±11.1% around 144** | Rubber Band's authors say no stretcher is fully transparent [secondary]; audible risk on pool; swing ratio stays fixed where today's score changes it with tempo |
| C. One tempo per level | Tiers change density only; a change to today's design | None | None | Simplest and allows stems, but loses the sensation of speeding up, and the pool lawn's speed is a large part of its concept |

Option A keeps the design and needs no stretch beyond correction. Option C is the fallback if ladders can't
be made coherent.

### Growth with tiers

Tier growth is now measured, not authored. Check each ladder for rising onset density and low-to-high spread
across tiers and for a small loudness rise, then have a person confirm [judgment]. `score-gates-baseline` and
the note-level validators don't apply to audio.

### Things that need a known key

These are the hidden couplings, and they would clash with new music if left alone [checked]:

- **Adornments** are pitched synth notes per score, quantised to the beat. The owner wants more of them.
- **Exit-shot cues** add pitched notes through `_withCue`.

Fix: measure each take's key, since `keyscale` is only a request, store it in the manifest, and replace the
synth notes with rendered one-shots, or keep them unpitched [judgment].

### Audio backend

`web_audio_backend.dart` plays oscillators only and has no audio buffer playback [checked]. Needed:

- A backend that plays buffers on `MusicTransport`'s clock, with `start(when, offset)` so a tier switch lands
  on the same bar of the next take.
- A per-tier manifest (`bpm`, `firstDownbeatSeconds`, `bars`, `loopStart`, `loopEnd`, measured key).
- A short equal-power crossfade at each phrase boundary.
- Pause, seek, success, bridge and cooldown tested against buffers. Existing checks only cover notes.

### Size

Arithmetic from the current forms, one take per tier, at Opus 96 kbps:

| | Audio | Encoded | Decoded in memory (44.1 kHz stereo float) |
|---|---|---|---|
| Garden, 32 bars, 5 tiers | 392.5 s | 4.7 MB | **138 MB if all are held** |
| All six levels | 1,825.7 s | 21.9 MB per codec | Hold current and next tier only |

- **Decoded memory is the phone constraint, not download.** 138 MB per level is too much to hold at once;
  hold the current and next tier, or use shorter forms. An 8-bar or 16-bar loop cuts both figures. The price
  is more audible repetition, which the owner can judge.
- Two codecs is 44 MB against a `build/web` of 166 MB. Each alternate take multiplies this.
- "Several alternatives" are affordable for short pieces like stingers; for full tiers, choose deliberately.

## 5. Post-processing: forcing exact loops

Render a take several bars longer than the loop so a tail exists, then:

1. **Measure.** `beat_this` for beats and downbeats (no `--dbn`, which needs madmom). Cross-check with an
   onset-envelope fold, as atl-arcade does. Don't use one tracker alone: trackers can return half or double
   tempo, and so can the model.
2. **Check tempo octave.** Accept only if measured BPM is within about 1.5% of the target. A result near half
   or double is a rejected take.
3. **Correct.** Stretch or resample the whole take to the exact BPM. `rubberband` R3 for small ratios.
4. **Gate.** No beat over 15 ms from the grid. Downbeat stays stable for the whole form.
5. **Cut and wrap.** Cut N bars from a downbeat. Crossfade the bar's opening with the tail audio past the
   loop end, around one beat. Zero-crossing trims alone won't hide a change in groove; this overlap does the
   work. Use a bar line in the kick or low end where possible.
6. **Repair if needed.** ACE-Step `repaint` or Stable Audio inpainting across a bad seam, then run the gates
   again. Unproven for seams.
7. **Loudness.** One target per level, measured with `ebur128` and `loudnorm` in two passes or `pyloudnorm`,
   and leave deliberate rise between tiers. Keep a true-peak ceiling, since Web Audio will sum during
   crossfades.
8. **Encode.** Opus 96k plus AAC 96k, as atl-arcade verified. Keep real audio before and after the loop points
   so encoder padding falls outside them.

**MP3 isn't suitable for loop points.** It has no standard field for encoder delay, and removal depends on the
encoder and player tags [secondary]. The owner's rule allows compressed formats generally, and `.gitignore`
already blocks `*.wav`, `*.flac`, `*.aif`, `*.aiff`. Masters stay out of git.

Loop API: `AudioBufferSourceNode` `loopStart` and `loopEnd` are specified and widely available [secondary:
W3C, MDN]. **Safari's Opus decoding wasn't verified**, hence the AAC fallback. Every browser needs a
sample-match test before relying on it.

## 6. Separation and analysis tools

These don't ship in the game, but their output would, so weights still matter for separators.

| Tool | Code | Weights | Verdict |
|---|---|---|---|
| **Demucs** (`adefossez/demucs` 4.1.0; Meta's repo archived 2025-01-01) | MIT | **"The license of the weights is not clear"**, in the author's words; `htdemucs_6s` "likely means CC-NC-BY" [checked: README] | **Don't ship output** without a ruling. Also unapproved in our plan |
| **BS-RoFormer / Mel-Band** (`ZFTurbo`, `lucidrains`) | MIT [secondary] | No clear licence. MUSDB-trained weights carry research-data questions; 6-stem SW has an open licence issue, #248 [secondary] | Treat as unlicensed for shipped output |
| **python-audio-separator** 0.48.0 | MIT; asks for UVR credit [checked] | Wraps the above; inherits them | Convenient wrapper, solves nothing legally |
| **ACE-Step `extract`** | MIT [checked] | MIT, base and XL-base only [checked] | **The only clean separator here.** Quality unmeasured; test before relying on it |
| **beat_this** 1.1.0 | MIT | MIT; training files include copyrighted audio, the maintainer says data licences aren't inherited [checked: README; #21 via search] | **Use.** Analysis only; nothing ships |
| **madmom** 0.16.1 (2018) | BSD | **CC BY-NC-SA** models; PyPI: "Free for non-commercial use" [checked] | Avoid |
| **BeatNet** 1.1.3 (2023) | CC-BY-4.0 [checked] | Same; offline mode uses madmom's DBN [checked] | Not needed |

Instrumental-only takes remove the vocal use case, which is what separators do best. Demucs's standard
output leaves accordion, reeds and brass together in "other", and its README says piano and guitar stems are
weak [secondary, checked in part]. So cumbia horns or a reed lead wouldn't come out as a clean tier layer.
This is a second reason against stem-based tiers, besides the licence.

## 7. Routes, ranked

1. **Take ladder from one anchor (recommended).** ACE-Step XL composes an anchor take from the level's concept.
   For each tier, `cover` the anchor stretched to that tier's tempo, with a caption for that tier's density and
   `audio_cover_strength` tuned for how related tiers should sound. Each result goes through section 5. No
   separation; runtime plays one take and crossfades at phrase boundaries. Docs claim source audio preserves
   melody, rhythm, chords and arrangement [vendor]; **nobody I found has measured this as a tier ladder.**
2. **Independent takes.** Same, but with five separate text-to-music takes sharing a caption and key. Simplest and
   entirely native in ComfyUI. Risk: tiers sound like five songs. The owner's freedom makes this more acceptable
   than before, but tiers need to sound like one song growing.
3. **One tempo, stems from one take (option C).** Tiers add layers from a single take cut with `extract`. Layers
   are locked because they share a source. Requires giving up tempo tiers and a clean `extract`.
4. **Layers across generations (`lego`).** Not recommended until someone measures timing after #810.
5. **Grid-only guide, fallback.** If take timing fails, `cover` from a click or clave rendered at the exact tempo.
   It imposes no melody, so it respects the owner's ruling. Untested by anyone I found.
6. **Our MIDI as guide (demoted).** Available through `cover` from a render, but no longer wanted as the main
   route, and I found no one who has tested soundfont input. MuLaCover and YuE2's score editing, the most
   direct score tools, are non-commercial. Magenta RT 2 takes MIDI, but has no tempo control documented and a
   Western bias.

Model ranking:

1. **ACE-Step 1.5 XL.** Primary. Turbo for search, SFT if quality needs it and the speed is tolerable.
2. **Stable Audio 3 Medium / Small.** Second opinion, and first choice for stingers and short pieces: strongest
   data record, inpainting, low VRAM. Prompt-only tempo. Note the revenue cap and registration.
3. **MiniMax Music 3.** Only if the first two fail on style and the owner accepts the on-screen credit.
4. **Magenta RT 2.** Not for this. Live-steering tool with a stated style-coverage gap.

**Success stinger and bridge.** Generate them last, from the level's chosen take, so they sound related:
`complete` or `repaint` or Stable Audio continuation, then cut to two bars [judgment, unproven]. The owner's
ruling lets cinematics play over cooling music, which a held tail should handle [judgment].

## 8. The music equivalent of ComfyUI

**There isn't one product. Use ComfyUI for generation and a small repo-owned Python pipeline for everything
deterministic** [judgment]. ComfyUI already has queueing, provenance and the GPU lane, and it runs ACE-Step
natively, but has no beat, stretch, seam or loudness nodes installed, and those steps need no GPU and should
be plain testable code in the forge.

| Option | Decision | Why |
|---|---|---|
| ComfyUI audio nodes | **Use for generation** | Already running, native nodes [checked]. `extract`, `lego`, `complete` and `cover` aren't visible as obvious native nodes; a cover workflow is reported [secondary], else ACE-Step's own API |
| ffmpeg | **Use** | Already here; encode and loudness [checked] |
| rubberband CLI | **Install** | R3 stretch. ffmpeg's build lacks the filter [checked] |
| pedalboard | **Optional** | 5.0 MB wheel [checked]; useful for simple limiting and EQ. Could replace rubberband |
| beat_this, librosa, soundfile, pyloudnorm | **Install** | Measurement. No output depends on their licences |
| sox | Skip | ffmpeg covers it |
| DawDreamer | Skip | 40.2 MB wheel; GPL-3 [checked]; only earns its place with VST or Faust rendering |
| Audacity scripting, Ardour headless | Skip | GUI-oriented or session-oriented; poor for deterministic batch jobs [judgment; neither was tried] |
| FluidSynth | Skip for now | Only for route 6 |

GPL tools process assets but don't ship; I'd expect no effect on game output, though that's not legal advice.

### Exact components

| Where | Component | Size | Network | GPU |
|---|---|---|---|---|
| Forge | `rubberband` 4.0.0 (Fedora, GPL-2+) | 0.7 MB install [checked] | Install only | No |
| Forge | `uv` venv: `librosa` 1.0.0, `soundfile` 0.14.0, `pyloudnorm` 0.2.0 | Under about 150 MB with numpy and scipy [judgment, wheels checked 0.3, 1.3 and under 0.1 MB without deps] | Install only | No |
| Forge | `beat-this` 1.1.0 + CPU torch | Wheel under 0.1 MB; CPU torch several hundred MB [judgment, unmeasured] | Install, plus first checkpoint download | No; CPU supported [checked] |
| Forge | `ffmpeg` | Present | No | No |
| Host | ACE-Step 1.5 XL pins in `models.tsv`: DiT about 20 GB [checked], plus text encoder and VAE | About 25 GB total [judgment] | Operator-consented download | Yes |
| Host, later | Stable Audio 3 Medium | 9.22 GB + T5Gemma [checked]; gated, needs HF acceptance | Download | Yes |
| Later, routes 1 and 3 | ACE-Step 1.5 repo in its own container, if ComfyUI's cover won't do | Not measured | Install | Yes |

Forge disk has 206 GB free [checked]. Repo-side, about four scripts under `tool/music/` (`grid`, `loop`,
`encode`, `check`), each writing provenance per asset as `run_workflow` already does.

## 9. Licence and provenance actions before shipping

- Rewrite `assets/music/LICENSE.md`. It currently states no recording or generated audio is used. Record model,
  commit, weights revision, seed, prompt and gate results per asset.
- Pin the model licence check so YuE2 and MusicGen stay out of shipped workflows. Their nodes are one click away.
- Prompts use genre and instrument words only. No artist or song names, and no reference audio from recordings.
- Decide whether human selection and arrangement of takes is enough for the owner, given the copyright point in
  section 3.

## 10. Smallest pilot that proves or kills it

Do it after the host restart. It needs one operator step: pin ACE-Step XL weights. No game code changes.

**Test the two extremes:** Garden (cumbia, 98 BPM, the middle tier) and Pool lawn (fast swing, top tier 160 BPM,
where half-time risk and jazz weakness combine).

| Step | Work | Pass | If it fails |
|---|---|---|---|
| 1. Grid | 12 XL turbo instrumental takes per level, 36 bars, in ComfyUI. Record seconds per take | At least 3 of 12 pass section 5 steps 1-4 at each level | Under 3 at a level: try the grid-only guide (route 5) once; if still under, **that style is dead on ACE-Step**, try Stable Audio 3 |
| 2. Ear | Owner listens blind to the 3 best takes per level alongside the current synth, on his own speakers | Owner prefers the takes and recognises cumbia and swing | **Kill for that style.** This is the real test. Try Stable Audio 3, or SFT, once |
| 3. Loop | Best take: 8 bars and 32 bars, wrapped and encoded, in a bare Web Audio page in the owner's host browser | Sample match at the seam in Chromium, and no audible seam for the owner after 3 loops | Try `repaint`; if it still shows, whole-form loops only |
| 4. Ladder | Garden only: route 1 at tiers 0, 2 and 4. Fall back to route 2 | Passes the gates; one song growing, to the owner's ear, switching at phrase boundaries | Option C (one tempo) or a rethink of tiers. Nothing else in this report depends on it |

Throw-away local GPU batches are already approved as a standing rule. I'd expect under a day's work [judgment]; GPU
time depends on XL speed on this card, which step 1 measures first.

Pilot ends with a decision to fund section 4's backend work or not. Don't write that backend first.

## 11. Could not verify

- **Any test of cumbia, salsa or swing, on any model.** The largest gap.
- ACE-Step XL speed on an RTX A5000.
- Whether `lego` timing improved after #810; no measurement found.
- The Stability Community License text. stability.ai would not load, so its terms come through search summaries.
- arXiv pages (ACE-Step paper, LoopGen, [P-MUSE](https://arxiv.org/abs/2608.01920), the [auxiliary-conditioning
  paper](https://arxiv.org/abs/2605.21433)) kept resetting, so only search excerpts. P-MUSE and the
  auxiliary-conditioning paper look relevant to instrumental control, and I couldn't assess either.
- Stability's game-music explainer also would not load; its points come through a search summary.
- Muse, SongBloom, Levo: named in roundups, no primary source read. Roundups disagree on details, so these aren't
  ranked.
- MiniMax Music 3's training data. YuE2's scope over outputs under CC BY-NC.
- Safari Opus decoding; Firefox behaviour at loop points. atl-arcade tested Chromium only.
- Whether ACE-Step's claimed "legally compliant" data is actually so. Nothing outside the authors supports it.
- Stable Audio 3 parameter counts: sources conflict (433M vs 0.6B, 1.4B vs 2B). Use its repo's VRAM table.
- Time-stretch quality on our material; no figure exists, only a listening test.

## Sources

Models:
[ACE-Step 1.5 repo](https://github.com/ace-step/ACE-Step-1.5),
[tutorial](https://github.com/ace-step/ACE-Step-1.5/blob/main/docs/en/Tutorial.md),
[inference docs](https://github.com/ace-step/ACE-Step-1.5/blob/main/docs/en/INFERENCE.md),
[GPU tiers](https://github.com/ace-step/ACE-Step-1.5/blob/main/docs/en/GPU_COMPATIBILITY.md),
[model card](https://huggingface.co/ACE-Step/Ace-Step1.5),
[XL base](https://huggingface.co/ACE-Step/acestep-v15-xl-base),
[issue #117](https://github.com/ace-step/ACE-Step-1.5/issues/117),
[PR #810](https://github.com/ace-step/ACE-Step-1.5/pull/810),
[paper](https://arxiv.org/abs/2602.00744);
[Stable Audio 3 repo](https://github.com/Stability-AI/stable-audio-3),
[Medium card](https://huggingface.co/stabilityai/stable-audio-3-medium),
[Small Music card](https://huggingface.co/stabilityai/stable-audio-3-small-music),
[Stability licence](https://stability.ai/license),
[licence update](https://stability.ai/news-updates/license-update),
[game-music explainer](https://stability.ai/explainers/adaptive-procedural-game-soundtrack-ai-what-it-is-and-where-the-model-fits);
[MiniMax Music 3](https://huggingface.co/MiniMaxAI/MiniMax-Music3);
[Magenta RT 2](https://github.com/magenta/magenta-realtime),
[its model card](https://github.com/magenta/magenta-realtime/blob/main/MODEL.md),
[v1 card](https://huggingface.co/google/magenta-realtime);
[YuE2](https://huggingface.co/m-a-p/YuE2-3B),
[commercial-use blog](https://www.promptus.ai/blog/yue2-commercial-licence-explained);
[MuLaCover](https://github.com/HeartMuLa/MuLaCover),
[its card](https://huggingface.co/HeartMuLa/MuLaCover);
[HeartMuLa](https://github.com/HeartMuLa/heartlib);
[DiffRhythm 2](https://huggingface.co/ASLP-lab/DiffRhythm2);
[AudioCraft](https://github.com/facebookresearch/audiocraft);
[MusicGen-Stem paper](https://arxiv.org/abs/2501.01757);
[ACE-Step reviews](https://ace-step.co/ace-step-1-5-review), [z.tools](https://z.tools/blog/ace-step-v1-5-review).

Tools:
[Demucs](https://github.com/adefossez/demucs),
[python-audio-separator](https://github.com/nomadkaraoke/python-audio-separator),
[ZFTurbo training repo](https://github.com/ZFTurbo/Music-Source-Separation-Training),
[its issue #248](https://github.com/ZFTurbo/Music-Source-Separation-Training/issues/248),
[beat_this](https://github.com/CPJKU/beat_this),
[beat_this issue #21](https://github.com/CPJKU/beat_this/issues/21),
[madmom licence](https://github.com/CPJKU/madmom/blob/main/LICENSE),
[BeatNet](https://github.com/mjhydri/BeatNet),
[Rubber Band](https://github.com/breakfastquay/rubberband),
[ComfyUI ACE-Step 1.5 docs](https://docs.comfy.org/tutorials/audio/ace-step/ace-step-v1-5),
[ComfyUI MiniMax Music 3](https://comfy.org/minimax-music-3/),
[Web Audio 1.1](https://www.w3.org/TR/webaudio-1.1/),
[gapless playback](https://en.wikipedia.org/wiki/Gapless_playback).

Field evidence and law:
[atl-arcade PR #163](https://github.com/William-Hill/atl-arcade/pull/163),
[ACE-Step issue #1325](https://github.com/ace-step/ACE-Step-1.5/issues/1325),
[LoopGen](https://arxiv.org/abs/2504.04466),
[US Copyright Office Part 2](https://www.copyright.gov/ai/Copyright-and-Artificial-Intelligence-Part-2-Copyrightability-Report.pdf),
[Library of Congress summary](https://blogs.loc.gov/copyright/2025/02/inside-the-copyright-offices-report-copyright-and-artificial-intelligence-part-2-copyrightability/).
