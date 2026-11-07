# Runtime assembly of pre-rendered level music

2026-11-06. Desk research plus one ffmpeg measurement. No game code changed, no GPU used, and nothing was
played in a browser.

Companion: `plan/research/local-music-models-2026-11-06.md` covers which models can make this music. This note
covers how the game plays it. Where the two touch, they agree except where section 2.5 says otherwise.

**Owner direction this note assumes** (`plan/owner-rulings-2026-11-05.md`): new music need not come from
`assets/music/scores/`; "give the new models free reign". No WAV on the remote.

Evidence labels:

- **[measured]** I ran it here, on this host, with ffmpeg. ffmpeg is not a browser.
- **[code]** I read it in this repository.
- **[primary]** A specification, or a vendor's own docs, that I read.
- **[others]** Another project's own report. A real measurement, but unreviewed, and often by a coding agent.
- **[excerpt]** I saw only a search excerpt, because the page itself would not load.
- **[judgment]** My reasoning.

## 1. Recommendation

| Question | Answer |
|---|---|
| Codec | One format: **MP3, LAME VBR about V4**, with a 4096-sample wrap around the loop, played by loop points. Opus is a later saving, only if a device test earns it |
| Runtime | Decoded `AudioBuffer`s, played by `AudioBufferSourceNode` loops on the existing transport clock. No streaming |
| Tiers | **A ladder of whole takes**, one per tier, switched at phrase boundaries. The runtime also accepts several stems per take, for when a single-take source allows it |
| Clock | `MusicTransport` on the device clock, as now. A per-level **timing manifest** replaces score notes as its source of tempo and form |
| Synth | Keep it, demoted to count-in, unpitched hits, and the fallback when audio fails. It no longer plays the music |
| Size | **About 3.3 MB per level at 16 bars, 6.4 MB at 32 bars**. Budget ceiling 8 MB |
| Phone memory | Hold the current tier and its neighbours: about 47 MB at 16 bars, 93 MB at 32 |
| Masters | Private R2 bucket as the durable copy, the forge's persistent cache as the working copy. Git holds checksums only |

Nothing here is proven on a phone. Section 8 is the smallest test that would prove or kill it.

## 2. Codecs for sample-accurate loops

### 2.1 What I measured

[measured] A 16-bar, 38.4 s loop at 100 BPM and 48 kHz (exactly 1,843,200 samples), rendered in Node from
`bar_swag` at tier 4 with a throwaway additive synth. ffmpeg 9.0.2, with `libmp3lame`, native `aac` and `libopus`.
`lag` is where the music's first sample really lands in the decode.

| Encoding | Metadata in the file | Decoded, metadata honoured | Decoded, metadata ignored | KB | MB/min |
|---|---|---|---|---|---|
| MP3 CBR 160 | Info tag, delay 576, padding 576, written as `Lavc63.1.` | Exact, lag 0 | +1152 samples, **lag 1105 (23.0 ms)** | 751 | 1.15 |
| MP3 V2 | Same | Exact, lag 0 | +1152, **lag 1105** | 633 | 0.97 |
| AAC 128, m4a | Edit list, start 1024; no `iTunSMPB` | Exact, lag 0 | +1024, **lag 1024 (21.3 ms)** | 622 | 0.95 |
| Opus 96, Ogg | Pre-skip 312 | Exact, lag 0 | Not tested | 540 | 0.82 |
| Opus 96, WebM | Pre-skip 312 | Exact, lag 0 | Not tested | 550 | 0.84 |
| Opus 96, MP4 | Pre-skip 312 | **+648 samples**, lag 0 | Not tested | 544 | 0.83 |

The worst seam I could build: the loop rotated to put a downbeat attack at the seam, and a periodic pad added
so sound runs through it. I compared the error against the source at the seam with the same downbeat mid-file.

| Encoding | Bare file: extra error at the seam | Wrapped, 4096 samples each side |
|---|---|---|
| MP3 CBR 160 | +0.2 dB | -0.5 dB |
| MP3 CBR 128 | +0.7 dB | -0.8 dB |
| AAC 128 | +0.9 dB | +1.6 dB |
| AAC 96 | +1.4 dB | -0.6 dB |
| Opus 96 | +0.2 dB | +0.7 dB |
| Opus 64 | -0.2 dB | -0.6 dB |

What this shows:

- **Once the metadata is honoured, all three codecs seam as cleanly as mid-file**, within about 1.6 dB of noise,
  on a decoder that does it right. So MP3 is not unusable for gapless loops. The risk lies in whether a given
  browser trims correctly.
- **I expected wrapping to improve the seam, and it did not measurably.** Its value is different: it survives a
  browser that trims too much or too little, because the loop points sit inside valid audio. It cost 0.4% in size.
- **An untrimmed head costs 21 to 23 ms** [measured], or about 44 ms for Apple's 2112-sample AAC priming [others].
  The perfect window is 75 ms [code: `RhythmJudge`], so that would be a real scoring bias, not just a click.

Limits: the signal is a clean additive render, not model output. Waveform error says nothing about how it sounds.
Real sizes will be higher.

### 2.2 What browsers do, as far as I could read

I could not reach current Safari behaviour from a primary source. The WebKit bug pages, the WebKit 18.4 post and
caniuse all refused connections here.

| Browser | MP3 | AAC m4a | Opus |
|---|---|---|---|
| Chromium | Exact frame count with a LAME/Xing tag, v153 [others: [agent-beeps #19](https://github.com/ehartye/agent-beeps/pull/19)] | -21 frames, v153 [same]; exact [others: [zpkt #46](https://github.com/becker929/zpkt/pull/46)]. They disagree, and encoders may differ | Opus in MP4 -234 [agent-beeps]. Sample-accurate at bar lines for Opus and AAC [others: atl-arcade, via the companion note] |
| Firefox | Exact with a proper tag, v155 [agent-beeps]. Reported 576 samples late on a tag without delay data [excerpt: chipvoice #135, which now returns 404] | 0 frames [agent-beeps] | Opus in MP4 -213 [agent-beeps] |
| WebKit, desktop | V0 with LAME tag exact [zpkt #46, version not given] | **208 extra samples, "a gap on every loop"** [zpkt #46]. A 2016 test found Safari exact ([Archibald](https://jakearchibald.com/2016/sounds-fun/)) | "WebKit 26.6 reports canPlayType no" for Ogg Opus [agent-beeps]; probably not the iOS build [judgment] |
| iOS Safari | **No current measurement found** | Fallback used by others; effect not confirmed on a device ([road-machiners #520](https://github.com/ROAM-game-org/road-machiners/issues/520)) | Ogg Opus: 104 of 104 failed on iOS 16.7 [same]. WebM Opus decoded through `decodeAudioData` on iOS 15.4 though `canPlayType` denied it [excerpt: WebKit 238546]. Stereo in WebM works on iOS 26.6 by one person's notes [excerpt: ambisonic-box]. WebKit's maintainer said in 2023 that shipping iOS has no WebM ([interop #484](https://github.com/web-platform-tests/interop/issues/484)). caniuse lists Safari 18.4 to 26.6 as partial [excerpt] |

Three firmer points:

- `canPlayType` does not predict `decodeAudioData` on Safari, in either direction [others, excerpt]. **Feature
  detection has to be an actual decode.**
- A Web Audio editor calls these gaps browser bugs, and notes that gaplessness depends on whether the browser
  "skips the encoder delay and the padding appropriately" ([W3C discussion 2505](https://github.com/WebAudio/web-audio-api/discussions/2505),
  Paul Adenot, 2023). No general API exposes that delay.
- `<audio loop>` is not gapless in Chromium (Won't Fix) or WebKit ([selftend #2437](https://github.com/Selftend/selftend/issues/2437)) [others]. That issue reports MSE appends as gapless too, but MSE offers no per-source scheduling on a shared sample clock, so Web Audio is the route here [judgment].

### 2.3 Recommendation

**MP3, LAME VBR about V4, 48 kHz, one file for every browser.** Planning rate 128 kbps, or 0.96 MB per minute.
Mono where a stem is mono.

- It is the only format with an exact report on all three desktop engines, and no report of failing to decode
  on any iPhone. That is weak evidence, but no other format has as much.
- One file per take means one set of offsets to verify, and no fallback logic.
- It costs about 33% over Opus 96 for the same take at planning rates. Measured on the sparse stand-ins, VBR
  nearly closed that: six stems came to 1,440 KB at V4 against 1,536 KB at Opus 96, though CBR 128 took 3,600 KB.
  **So don't use CBR for sparse material.** Real model output will be denser.
- **Fallback:** none is needed if the probe in section 8 passes. If it fails on iOS for MP3, try AAC with a measured
  per-browser offset. If Opus is added later for size, choose it per browser by test decode, never by `canPlayType`.

Three rules make it sample-accurate regardless of how the browser trims:

1. **Wrap.** Encode `tail + loop + head`, with 4096 samples each side, and set `loopStart` and `loopEnd` inside.
2. **Check the length.** Compare `buffer.length` with `N + 8192` after decoding.
3. **Probe the offset.** Ship one tiny file from the same encoder, with an impulse at a known sample. Find the
   impulse after decoding. That gives this browser's offset for this encoder, added to every loop point. This
   turns 21 to 44 ms of unknown into a measured constant. [judgment; untested in a browser]

ffmpeg wrote its tag as `Lavc63.1.`, not `LAME` [measured]. Whether WebKit's parser reads it is unknown. Test both
ffmpeg's encoder and the `lame` CLI, which is not installed here.

### 2.4 How to test it for real

No headless check can replace these. Playwright's WebKit is not iOS Safari.

1. **Probe page**, static, loaded on each real device. For each encoding it reports `canPlayType`, decode success,
   decode milliseconds, `buffer.length`, `sampleRate` and impulse position.
2. **`OfflineAudioContext` render** in that same browser of three loops through the real node graph, comparing
   the seam with mid-file as in 2.1. This removes speakers and timers, and it needs no audio unlock.
3. **Loopback recording on a phone**: a synth click scheduled at `secondsAt(beat)` on the left, stem impulses on
   the right, over ten loops. It shows offset and drift on the actual output path.
4. **Memory**: Safari Web Inspector's timeline on a real iPhone, with all takes decoded.
5. **Interruptions**: phone call, lock, mute switch, Bluetooth route change.

Devices: an iPhone on current iOS and an older one if available, one mid-range Android, and the owner's host browser.

### 2.5 Where this differs from the companion note

That note sizes at Opus 96 and two codecs. I recommend one MP3 until a device test justifies more. Its per-tier
table therefore reads 25% smaller per file, and mine has half the files of its two-codec total.

## 3. Runtime design

### 3.1 Decode, don't stream

`decodeAudioData` into `AudioBuffer` with `AudioBufferSourceNode`. Loop endpoints have sub-sample accuracy, and
`decodeAudioData` resamples to the context rate ([Web Audio spec](https://webaudio.github.io/web-audio-api/)) [primary].
Media elements have no sample-accurate start or loop [others, above], so they cannot carry this.

**Decoded memory** [measured arithmetic, 48 kHz stereo 32-bit float]:

| Material | Seconds | One take or stem |
|---|---|---|
| 16 bars, 100 BPM | 38.4 | 14.7 MB |
| 16 bars, 128 BPM | 30.0 | 11.5 MB |
| 8 bars, 128 BPM | 15.0 | 5.8 MB |
| 32 bars, 100 BPM | 76.8 | 29.5 MB |

A 16-bar stem set of six stereo stems at 100 BPM is **88 MB**. At three sections, 265 MB. I found no authoritative
figure for how much an iPhone tab may hold, so section 8 measures it. Mono halves any line.

The garden's tier ladder is 196 s at 16 bars: 75 MB decoded if all are held, up to 47 MB for three neighbours.

### 3.2 Layering or resequencing

| | Vertical, stems by tier | Horizontal, whole takes by phrase |
|---|---|---|
| Needs | Stems locked together | Only a shared beat grid |
| Model support | Only stems cut from one take; layers across generations reported 20 to 80 ms off, separators have a licence problem (companion note) | Works today with post-processing |
| Tempo tiers | Needs one set per tempo | Natural: each take has its tempo |
| Risk | Thin or smeared stems | **Tiers may not sound like one song**: only the owner's ears can settle it |
| Transition | Fade, no restart | Short crossfade at the boundary |

**Use horizontal as the default**, and let a take hold one file or several. A one-file take is simply the degenerate
case, so stems stay possible without another design. Keep the sequence of sections fixed by the form: the transport
already derives everything from absolute beats, so seek, resume and `sectionAt` stay pure functions. A runtime-chosen
order would make those stateful, for little gain before there is music to choose between. [judgment]

### 3.3 Crossfades that keep the beat clock

The clock never hears about a crossfade. Audio follows the clock, never the reverse.

- **Switching takes:** at the boundary beat, start the new take at `when = secondsAt(boundary)`, with
  `offset = pad + probe + (boundary % formBeats) * 60 / bpm`. Fade the old one out and stop it.
- **Equal-power** for different takes, which are uncorrelated. Linear for stems of one take. [judgment; standard practice]
- **Length:** with different tempos, the outgoing take slips against the grid during the fade. A 250 ms fade at +3 BPM
  on 100 slips about 7.5 ms; at the pool's +8 on 128, about 16 ms [measured arithmetic]. So stay under about 250 ms,
  and start with 60 to 120 ms. Listening decides.
- **Commit late.** `requestTier` may cancel a pending boundary (`_sections.removeWhere`) [code]. So fire the audio
  switch only once a boundary falls inside the lookahead, in `pump()`, not at request time.
- **Decode ahead.** A boundary can be as little as one phrase away. Keep neighbouring tiers decoded so the switch is
  never waiting. The conductor already requires preload before a handoff [code].

### 3.4 One clock

Already true: "Audio device/context time is the sole transport authority... pre-rendered stems are not runtime clocks"
(`transport.dart`, line 4) [code]. Files never report position. Nothing reads back from them.

- `beatAt` and `secondsAt` are computed from the tempo map and `AudioContext.currentTime`, as now.
- Sources are started from those numbers, and all of a take's stems share one `when`.
- A looping source and the clock both count device samples, so they stay locked if the loop length matches the beat
  math exactly. Only 6 of 30 current tier tempos give a whole-sample 16-bar loop at 48 kHz, and 11 of 30 at 44.1 kHz
  [measured]. The error is tiny: 0.26 samples per loop at 92 BPM, about 2 hours to reach 1 ms [measured arithmetic].
  **Have the manifest state `loopSamples`, and derive BPM from it**, so tests can assert exact equality.
- Request `new AudioContext({sampleRate: 48000})` [primary: the option exists]. Today's code passes no options [code].
  Whether iOS honours it is unverified. If the rate differs, the spec resamples, and loop points in seconds still work.

### 3.5 What stays authoritative: the timing manifest

Once notes are gone, **the manifest plus the device clock define time**. Charts need nothing else: `FightChart` is
beats and offsets [code], and `party_autoplay.dart` reads only session state and `secondsAt` [code].

```jsonc
// web/audio/<level>/manifest.json, written by the conform tool, never by hand
{
  "schemaVersion": 1, "id": "bar",
  "sampleRate": 48000, "pad": 4096,
  "beatsPerBar": 4, "phraseBars": 2, "bars": 32,
  "sectionBars": [0, 8, 16, 24],
  "takes": [            // exactly 5, one per tier; the same file may repeat
    { "tier": 0, "bpm": 100.0, "loopSamples": 3686400, "key": "C minor",
      "stems": [{ "id": "mix", "file": "t0-3fa9c1.mp3", "gain": 1 }] }
  ],
  "success": { "bars": 2, "bpm": 100.0, "file": "success-b81e22.mp3" },
  "bridges": { "pool-garden": { "bars": 2, "bpm": 128.0, "file": "to-pool-77a0de.mp3" } },
  "grid": { "maxBeatErrorMs": 11.2, "tool": "beat_this", "gate": 15 },
  "master": { "sha256": "...", "key": "r2://kumbia-audio-masters/bar/t0.flac" },
  "provenance": { "model": "...", "prompt": "...", "seed": 1 }
}
```

- `MusicScore`'s constructor already allows `notes: []`, requires exactly five tempos, and requires `bars` divisible
  by `phraseBars` [code]. Equal tempos are already legal: every bridge score has five identical ones [code].
- So `MusicScore.fromManifest` can give the transport what it needs **with no transport timing change**. `pump()` still
  advances `_scheduledUntilSeconds` with no notes, so starvation logic keeps working [code].
- A longer-term rename to `MusicTiming` plus an optional note list would be cleaner, but it isn't needed to start.
- A gate replaces the note validators: measured beats within 15 ms of the grid (companion note section 5), loop length
  exact, sum of files checked against `sha256`. `tool/music/validate.mjs` still governs scores while any level uses one.

### 3.6 Tier tempos

Today `requestTier` selects `score.tempos[tier]`: +3 BPM a tier, or +8 on the pool lawn [code]. Span: 1.09 to 1.13,
pool 1.25 [measured arithmetic]. The owner's Level 3 ruling names "tempo" as part of what the two dancers change [code].

| Option | Bytes | Clock change | Sound | Verdict |
|---|---|---|---|---|
| **One take per tier at its own tempo** | 5 takes | None: this is what the transport does | Musically different takes | **Default**, agreeing with the companion note |
| One tempo per level | Fewest; stems become possible | None: five equal tempos | Loses the speed-up; pool lawn loses part of its concept | Fallback, or a level's choice |
| Runtime stretching | 0 extra, plus WASM | None | Rubber Band WASM builds found are GPL ([jsDelivr](https://www.jsdelivr.com/package/npm/rubberband-wasm)), a licence decision for this project. No mobile CPU figures found | Reject |
| Offline stretch into several takes | As per-tier | None | Audible risk at pool's ±11% (companion) | Tool, for small corrections only |
| Varispeed, `playbackRate` at the boundary | 0 | Tempo map holds | Pitch rises with speed: +51 cents per 3%, **+196 cents over the bar's ladder, +386 over the pool's** [measured arithmetic]. A k-rate parameter, so it applies at render-quantum edges [primary], at worst 2.7 ms at 48 kHz | Worth one listening test for a small lift; synth cues would need matching |

This changes difficulty feel, so the owner decides between the first two rows per level.

### 3.7 Latency compensation

**There is none today.** `rhythm.dart` documents times as "after input/output calibration", but `garden_session.dart`
computes `_nowMs` straight from `nowSeconds`, and `lib/` has no `outputLatency`, `baseLatency` or calibration for timing
[code]. Pre-rendered music doesn't cause this, but the hit you hear is now also the music's, so fix it in the same pass:

- `heardSeconds = nowSeconds - outputLatency - userOffset`, used for judging and for what the scene draws.
- `outputLatency` is Baseline since March 2025; `getOutputTimestamp()` is Baseline since April 2021
  ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/AudioContext/outputLatency), [MDN](https://developer.mozilla.org/en-US/docs/Web/API/AudioContext/getOutputTimestamp)) [primary].
  The spec says the value may change while running, so re-read it. How accurate it is on iOS or Bluetooth is unverified.
- A tap-along calibration screen as the fallback. Prior art agrees: see NecroDancer in section 4.

### 3.8 iOS audio unlock

- Today's flow already creates and resumes the context inside a gesture, with a 7 s timeout (`garden_page.dart`) [code].
- Compressed bytes can be fetched before the gesture, and decoding can follow it. Start a level only after its takes
  are decoded. [judgment; verify decode on a suspended context]
- `ready` is `state == 'running'`, so an iOS interruption reaches `pump()` and pauses already [code]. Today
  `silence()` only cuts synth voices, so **it must also stop the takes** for that path to keep working.
- The mute switch: `navigator.audioSession.type = "playback"` is experimental with limited availability
  ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/AudioSession/type)) [primary]. The doc doesn't mention the
  switch, and one project says the type also affects background interruption [others: selftend #2437]. Test on a device.

### 3.9 What changes, by file

| File | Change |
|---|---|
| `lib/music/score.dart` | `MusicScore.fromManifest`: timing, tempos, sections, and notes empty or cue-only |
| `lib/music/transport.dart` | Optional listener, default null: `onAnchor(beat, atSeconds, tier)` from `_anchorAt`, `onTierCommitted(beat, atSeconds, tier)` from `pump()` inside lookahead, `onRetire`, and silence on pause/seek/stop. **Timing maths doesn't change.** Update the line 4 comment |
| `lib/music/game_audio_contract.dart` | New separate interface, `StemPlayer`, plus `outputLatencySeconds`. **Do not add to `MusicAudioBackend`**: 17 classes in 15 files implement it or `GameAudio`, nearly all test fakes [measured by grep] |
| `lib/music/web_audio_backend.dart` | `decodeAudioData`, `start(when, offset)` (today `_Source.start` takes one argument), `loopStart`, `loopEnd`, `playbackRate`, `AudioContext` options. Separate music and cue buses under `_master`. `silence()` also stops takes. Rewrite the "no recorded stems" comment |
| `lib/music/stem_deck.dart` (new) | Listens to one transport; maps beat to take and offset; crossfades; applies the probe offset. Pure logic behind a small interface, so it can be tested with a fake |
| `lib/music/audio_loader.dart` (new) | Fetch, content-type check, cache, decode, keep neighbours, release the rest |
| `lib/music/game_audio_stub.dart` | Implement the new interface as unsupported |
| `lib/music/transition_conductor.dart` | Handoff logic stays: each segment is a transport already, with `startAt` and `retireAt` on one clock. Each segment gains a deck. Pause and resume already coordinate at a safe time. Tails for "still cooling down" can overlap past `retireAt`, since audio no longer ends at note release |
| `lib/gameplay/level_definition.dart` | `music.manifest` as an alternative to `score` and `successScore`. `leadShape` optional. `roomScoreIds` handles both |
| `lib/gameplay/garden_page.dart` | Loads manifest or score (`_scoreData`, `_roomScores`, `_prepareExits`). `_ornament` reads score adornments, and `_withCue` adds notes (see 3.10). If the next level's music isn't decoded, keep looping and hand off at a later phrase. Loading state |
| `lib/gameplay/garden_session.dart` | `_nowMs` uses heard time. `requestTier` unchanged |
| `lib/gameplay/garden_scene.dart` | `transport.score.sectionAt` works as is if the manifest fills `sectionBars`. Draw from heard time |
| `lib/gameplay/party_autoplay.dart` | None [code] |
| `levels/*.json` | One level at a time gains `music.manifest`; others keep playing their scores |
| `web/audio/<level>/` | New. Use `web/`, so files reach `build/web` unbundled. **Not `/music/`: `tool/prepare_preview.mjs` already uses it** for the score room (README) |
| `web/_headers` | `/audio/*` immutable (section 5) |
| `tool/music/conform*` (new) | Measure, correct, gate, cut, wrap, encode, hash, write manifest (companion note section 5) |
| `test/` | Below |

**Tests.** Thirteen test files mention scores, and nine name `assets/music/scores` directly [measured]; they run on fake clocks.
They keep working, because scores stay valid as data for timing. When a level moves to a manifest, its tests use the
manifest with no notes, and chart tests stay as they are. New, with a `FakeStemPlayer`:

- Every source starts at exactly `secondsAt(beat)`, with the expected offset.
- Tier changes never restart the current take before the boundary, and coalesced requests never fire.
- Pause, resume and seek restart at the right offset; `silence()` reaches every source.
- Handoff timing across source, success, bridge and next, with tempo changes across a loop seam.
- Loader: a wrong content type or length is rejected, and tiers stay ready before their boundary.

`tool/music/transport_check.dart` and `transition_check.dart` stay with timing-only input. The score-only checks retire
when the last score does.

### 3.10 Couplings the notes used to hide

- **Adornments** (`_ornament`) are pitched notes from the score JSON. On new music they may clash. Replace with rendered
  one-shots keyed to the take's measured key, or unpitched sounds. The owner wants more of these, so this matters.
- **`_withCue` exit hits** use track `pulse` [code: `levels/*.json`], so they are probably safe unpitched. Check by ear.
- **`_playCountIn`** is an unpitched pulse. Safe.
- **Charts** were written beside the old music; review each against its take (companion note).
- **`openspec/changes/score-composition-pipeline`** assumes "keeping tiny MIDI-style assets on the web synth". The owner's
  new direction overtakes much of it. It needs a decision; I did not edit it.

## 4. Prior art

For this section I read search excerpts of the linked pages, apart from the project's own notes. Treat it as leads, not close reading.

| Source | What it did | What applies here |
|---|---|---|
| **iMUSE** (LucasArts, US patent 5,315,057) [secondary: [Wikipedia](https://en.wikipedia.org/wiki/IMUSE); patent text not read] | Composers place branch and loop markers; music moves at those points, like a pit orchestra stretching a passage | Exactly `requestTier`: intent now, change at a marked boundary |
| **Wwise, FMOD** [project's own [earlier notes](../music-overhaul-research.md), citing primary docs; this search found secondary only] | Segments, entry and exit cues, transition segments, quantised changes, layering by parameter | Our success, bridge and next chain already is this. Don't adopt the middleware: both need a host runtime, and we own a clock already [judgment] |
| **Hi-Fi Rush** [Wwise: [PCGamingWiki](https://www.pcgamingwiki.com/wiki/Hi-Fi_Rush). 120 BPM animation, retimed: [Game Anim](https://www.gameanim.com/2023/09/08/hi-fi-rush-music-synced-animation/), excerpt. Arcade mode raises BPM between waves: [Steam](https://store.steampowered.com/app/1817230/HiFi_RUSH/)] | Animate to a beat grid and retime. Discrete tempo steps. Actions land on the beat despite slightly off input | Our dance already samples beats, so it survives any tempo. Tempo steps between waves are a precedent for tiers. **I found no primary account of its audio clock, and I won't claim one** |
| **Crypt of the NecroDancer** [[official FAQ](https://braceyourselfgames.com/crypt-of-the-necrodancer/faq/); [Steam thread](https://steamcommunity.com/app/247080/discussions/2/3211505894108044642/), developer reply; [OST list](https://dbsoundworks.bandcamp.com/album/crypt-of-the-necrodancer-ost)] | Beats live in a data file separate from the audio; custom songs get a detector, with a manual fallback. Calibration exists, skipped on iOS, then Bluetooth broke that assumption. Tracks come "with Shopkeeper" variants | **Closest match**: a timing file beside audio is our manifest. Plan for Bluetooth from the start. I found nothing on how the shopkeeper version syncs |
| **Sayonara Wild Hearts** [[GamesBeat](https://gamesbeat.com/sayonara-wild-hearts-hands-on-preview-playing-a-pop-music-game-at-200-miles-per-hour/); [Simogo](https://simogo.com/work/sayonara-wild-hearts/daniel-about-sayonara-wild-hearts/); [Design Room](https://www.designroom.site/how-simogo-built-sayonara-wild-hearts-best-stage/)] | Scenario, then music, then gameplay timed to it, with many iterations. One heavily cut stage took about a year | Fix the music before the chart, then review the chart against it. Linear authored songs are costly to build; our looping form is cheaper |
| **Tone.js** [[repo](https://github.com/Tonejs/Tone.js), [Player docs](https://tonejs.github.io/docs/r11/Player), [issue #606](https://github.com/Tonejs/Tone.js/issues/606)] | A transport, players, loop points. Reported issues with players starting together, and with loop wrap | A second clock to keep in step with ours. Not needed |
| **Howler** [[repo](https://github.com/goldfire/howler.js)] | Loading and playback; `html5` for long files, and no real-stream or beat clock | Solves unlock and fallback we already have. Not needed |
| **atl-arcade PR 163** [others; via companion note] | ACE-Step loops, a measured grid and a beat clock in a browser game | The closest working precedent |

The common lesson: **time lives in data beside the audio, changes wait for marked boundaries, and calibration is a
feature, not a polish item.** That's also the architecture here.

## 5. Budget, deployment and masters

### 5.1 Download and memory per level

Planning rate 128 kbps VBR. The rendered-loop stand-ins came in well below this, and real music will sit nearer it.
Figures are 48 kHz stereo, with arithmetic from the current forms. "Held" is the memory a phone needs for that option.

| Option | Files | Download | Held decoded |
|---|---|---|---|
| **Ladder, 16 bars, 5 tempos (garden)** | 5 + 2 | **3.3 MB** | 75 MB all; **47 MB neighbours** |
| **Ladder, 32 bars, 5 tempos (garden)** | 5 + 2 | **6.4 MB** | 151 MB all; **93 MB neighbours** |
| Fixed tempo, 4 stems × 1 section, 16 bars (110 BPM) | 4 + 2 | 2.4 MB | 54 MB |
| Fixed tempo, 4 stems × 2 sections | 8 + 2 | 4.6 MB | 107 MB, or 80 with 2 mono |
| Fixed tempo, 6 stems × 3 sections | 18 + 2 | 10 MB | 241 MB. Too much |
| 4 stems × 2 sections × 2 tempos | 16 + 2 | 9 MB | 214 MB. Too much |
| 4 stems × 2 sections × 5 tempos | 40 + 2 | 22 MB | 536 MB. Rejected |

The "+ 2" are a success phrase and a bridge, about 70 KB each. A second codec adds its own files to deployment, while
each user still downloads one.

**Campaign total** at 3.3 / 6.4 MB per level:

| Levels | 16 bars | 32 bars |
|---|---|---|
| 5 | 17 MB | 32 MB |
| 20 | 66 MB | 128 MB |
| 50 | 165 MB | 320 MB |
| 100 | 330 MB | 640 MB |

For scale, today's production-relevant `build/web` holds 35 MB of assets, 37 MB of CanvasKit and 2.2 MB of `main.dart.js`
[measured]. `gallery` (28 MB) and `probe` (66 MB) sit in the local build only: `tool/build_local_site.sh` says production
never includes the gallery [code].

### 5.2 Lazy loading and caching

- **Fetch by level.** The first level before play; the next one while the current level runs, ahead of the exit. No
  level's music is needed until that level.
- **Keep `web/audio/` out of `pubspec.yaml`**, so it stays out of Flutter's asset bundle, and JS fetches it by URL.
- **Immutable names and headers.** Workers assets default to `public, max-age=0, must-revalidate` with an ETag, so each
  use costs a round trip ([docs](https://developers.cloudflare.com/workers/static-assets/headers/)) [primary]. Hash names and add to `web/_headers`:
  `/audio/*` → `Cache-Control: public, max-age=31536000, immutable`. Exclude `manifest.json`, or hash it too. Limit is
  100 rules [primary].
- **Check content type.** `wrangler.toml` sets `not_found_handling = "single-page-application"` [code], so a missing MP3
  can return `index.html` with 200. Reject anything not `audio/*` before decoding, and you get a clean error rather than a
  confusing `EncodingError`.
- **No service worker for this.** `build/web/flutter_service_worker.js` is a 784-byte self-unregistering stub [measured],
  and Flutter is removing its caching worker ([#156910](https://github.com/flutter/flutter/issues/156910)) [excerpt]. A
  custom root-scope worker would have to fight that registration in `flutter_bootstrap.js`. **HTTP cache plus the Cache
  API from the page** gives the same offline replay without a worker. Safari may evict script-writable storage after
  seven days of no use [from memory, unverified], which only costs a re-download.

### 5.3 Cloudflare Workers limits

[primary: [limits](https://developers.cloudflare.com/workers/platform/limits/), updated 2026-10-29]

- 25 MiB per file: no issue; a 32-bar take is about 1.2 MB.
- **20,000 files per version on Free, 100,000 on Paid** (Paid needs Wrangler 4.34 or later;
  [changelog](https://developers.cloudflare.com/changelog/post/2025-09-02-increased-static-asset-limits/)). At about 8 files a
  level, 100 levels is 800 files. Today's production count is under 200, given 902 with `gallery` and `probe` (782 of those)
  [measured]. Not a constraint.
- Asset requests are free and unlimited, with no extra storage charge ([docs](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/)) [primary].
  I found no total-size limit on that page, and did not check the account, as asked.

`npm run build` runs `tool/build.sh`, and `wrangler deploy` serves `build/web` [code: `README.md`, `wrangler.toml`], so a
file in `web/audio/` deploys with no new infrastructure.

### 5.4 Where files live

`.gitignore` blocks `*.wav`, `*.flac`, `*.aif`, `*.aiff` [code]. MP3, Ogg and M4A are not ignored [measured], and that's
correct for deliverables, but **a stray candidate MP3 can be committed by accident**. So keep candidates out of the tree.

`/home/forge/src` is a 1.5 GB tmpfs, 782 MB used, with `.git` at 200 MB [measured]. Each committed MP3 counts twice there:
working tree and history. Fifty levels at 6.4 MB would take about 640 MB of the 755 MB free, and that's before any
re-render.

| Place | For | Verdict |
|---|---|---|
| Git LFS | Masters | **No.** GitHub Free gets 10 GiB storage and 10 GiB bandwidth, and overage disables LFS until next month ([docs](https://docs.github.com/billing/managing-billing-for-git-large-file-storage/about-billing-for-git-large-file-storage)) [excerpt]. A smudge would also pull masters into the tmpfs. Also adds a tool to every agent checkout |
| Forge persistent cache, `~/.cache/tillandsias-project/kumbia-audio/` | **Working masters and all candidates** | **Yes.** 206 GB free on `/dev/md127`, not in git, survives sessions [measured]. One host, so not a backup |
| R2 private bucket | **Durable masters** (FLAC, 24-bit) | **Yes.** 10 GB-month free, egress free ([pricing](https://developers.cloudflare.com/r2/pricing/), updated 2026-10-30) [primary]. At FLAC's typical 50 to 60% [from memory], a 32-bar 5-tier ladder (392 s, 48 kHz, 24-bit) is about 60 to 70 MB: roughly 150 levels on the free tier. Needs a credential the forge may not have, and the host CA fault must clear first; I did not touch Cloudflare |
| Git | **Manifest with `sha256`, and approved deliverables** | Yes, on promotion only, once per approved take |
| R2, public, behind a domain | Deliverables, later | **When `.git` or tmpfs headroom says so**: past about 20 levels, or on re-render churn. Needs CORS and a base URL in the manifest loader. History rewrites aren't an option on a shared repo, so prefer moving early over moving late |

Also add a pre-commit size check: reject audio in the tree that isn't named in a manifest, and anything over about 3 MB.
Hooks exist in `.git/hooks` [measured]; adding one is a separate change.

## 6. Hybrid: keep the synth?

**Keep it, for a small job.** Its direct callers are `pump()`, `_playCountIn` and `_ornament` [code].

| Keep | Why |
|---|---|
| Count-in, unpitched exit hits | Unpitched, cheap, no download, and scheduled on the same clock |
| Fallback | When a decode fails or a phone runs out of memory: levels with a score play it; new ones run a click and bass on the grid, so the run can continue |
| Test and tool backend | All the fakes target this interface, and it costs nothing to keep |

| Drop | Why |
|---|---|
| Music from notes, on any level with a manifest | The owner's direction |
| **Synth percussion under rendered music** | Tempting as a "gameplay-critical layer", but: a second percussion timbre on top of one baked into the take; flams if the take's grid has up to 15 ms of error, which the gate allows; and no cue function, since **today's cues are visual plus the music** [code]. Listening could reverse this for a quiet click option |
| Pitched adornments on new music | They would clash; use rendered one-shots |

Does a hybrid preserve what we have?

- **Autoplay: yes.** It uses session state and `secondsAt` only [code].
- **Tests: yes.** The clock, chart and judge tests touch only fakes and timing [code]. Files move as levels move.
- **Determinism: yes for logic.** Nothing reads audio back. What's lost is the guarantee that audio equals the notes, which
  moves to the conform gate.
- **Not preserved automatically:** the tiny music download, instant start (there is now a loading step), and `silence()`
  stopping everything, which the deck must honour. Native builds remain unsupported as before.
- **Existing levels:** they keep their scores until the owner approves replacement music, per the standing rule to add,
  not replace.

## 7. Could not verify

- **All browser behaviour first-hand.** No browser ran. Everything in 2.2 is others' reports or excerpts.
- **iOS Safari, current version:** MP3, AAC or Opus trim; whether `Lavc`-tagged Info headers are honoured; decode time;
  memory ceiling; `sampleRate: 48000`; `outputLatency` accuracy; mute-switch behaviour.
- **Primary Safari sources.** WebKit bugs 238546 and 226922, the WebKit 18.4 post, caniuse and the Apple forum thread all
  reset the connection, on repeated tries. The 18.4 Ogg claim is from secondary sources only.
- **How it sounds.** Everything here is timing and size. Crossfade lengths, tier coherence, VBR quality and varispeed all
  need ears on real music. My test signal was a toy.
- **Hi-Fi Rush's audio clock and NecroDancer's shopkeeper sync:** no primary source found. Wwise and FMOD specifics in this
  round came from secondary sources.
- **R2 credentials, current Cloudflare account state:** not checked, as asked.
- **Real model output sizes**, and whether conformed takes pass the 15 ms gate for cumbia or swing.

## 8. Recommended architecture and the smallest proof

```
levels/bar.json ──music.manifest──▶ web/audio/bar/manifest.json
                                         │ MusicScore.fromManifest (timing, no notes)
                                         ▼
 AudioContext.currentTime ─────▶ MusicTransport ──▶ FightChart, RhythmJudge, scene, autoplay
                                   │ listener (anchor, tier inside lookahead, retire, silence)
                                   ▼
                     StemDeck ──▶ AudioBufferSource loops ──▶ music bus ─┐
                        ▲                                                ├─▶ master
             AudioLoader (fetch, decode,   synth: count-in, hits ─▶ cue bus ┘
             neighbours, probe offset)
```

### Step 1: device truth (about a day, no game code)

A static page with: MP3 from ffmpeg and from `lame`, AAC, Opus in WebM and Ogg, each a wrapped loop plus an impulse probe.
It reports per 2.4 steps 1 and 2. Serve it beside the preview and open it on a real iPhone, an Android phone and the host browser.

**Pass:** MP3 decodes everywhere, offset stable across five reloads, seam excess under 3 dB, four takes decode in under 2 s
on the phone. **Kill or change:** if MP3 fails on iOS, try AAC with a probe offset. If neither holds, the wrap or the codec
needs rethinking before anything else.

### Step 2: one level, two tiers (about two days)

- Stand-in audio, so it doesn't depend on the model pilot: two 16-bar takes at 100 and 103 BPM, rendered offline like the
  test here. Real takes replace them later without code changes.
- Build a hidden `bar-rendered` level (added, not replacing `bar`), with `MusicScore.fromManifest`, the transport listener,
  a minimal `StemDeck`, and a `FakeStemPlayer` test set.
- Run the campaign's autoplay through it.

**Pass, all of:**

1. `flutter test` is unchanged except for additions.
2. Loopback recording on an iPhone: stem impulses within 5 ms of synth clicks scheduled at `secondsAt`, no drift over 10
   loops, including across the tier switch.
3. Pause, resume and a phone call land back on the right beat.
4. Handoff into the next level with no gap.
5. Decoded memory recorded in Web Inspector. Check that 47 MB is comfortable, and extrapolate to 93.

If those pass, conform real takes from the companion note's pilot into the same manifest, and the owner listens. **That
listening is the real decision**: whether a ladder of takes sounds like one song growing. If not, the same runtime carries
fixed tempo with stems from one take.

## Reproducing the measurement

Scripts lived in this session's scratchpad and are not committed. To repeat: render an exactly periodic loop, encode with the
settings above, decode with `ffmpeg -i x -c:a pcm_s16le`, and find lag by least-squares search against the source. For raw
decodes use `-flags2 +skip_manual` on MP3 and `-ignore_editlist 1` on M4A.

## Sources

Linked in place above. Also read: [Hydrogenaudio on gapless playback](https://wiki.hydrogenaudio.org/index.php?title=Gapless_playback),
[Compuphase on MP3 loops](https://www.compuphase.com/mp3/mp3loops.htm), [ACE-Step tutorial](https://github.com/ace-step/ACE-Step-1.5/blob/main/docs/en/Tutorial.md).
