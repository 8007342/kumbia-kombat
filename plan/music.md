# Music foundation and remaining integration

Implemented 2026-10-18: five original instrumental event scores, five tier MIDI
previews per piece (25 files, 6,136 authored/arranged events total), four optional
ornaments per piece, deterministic JS authoring and independent MIDI/data validator,
immutable Dart score parser, audio-clock transport, and oscillator/noise Web Audio
backend. `tool/music/preview.dart` and its HTML shell build a standalone score room.
The transport now supports complete-form looping on an absolute beat timeline,
arbitrary paused seeks and explicit phrase restarts. `createGameAudio()` conditionally
selects Web Audio or an unsupported native stub, so tests/native builds import safely
and unsupported platforms cannot start silent scoring. This is a reviewable music foundation; the main application remains independently
owned, and the score room is not the finished dance-game integration.

Commands and evidence:

```sh
node tool/music/generate.mjs
node tool/music/validate.mjs
node tool/music/build_preview.mjs
dart --packages=build/music-preview/packages.json tool/music/transport_check.dart
flutter analyze lib/music tool/music
```

All passed locally. The behavioral harness verifies exact tempo continuity at a
phrase boundary, request coalescing, scheduling deduplication, pause/resume with a
frozen count-in position, starvation recovery at the last scheduled beat, rejection
of unavailable audio, parsing all generated scores, finite score completion, three consecutive loop seams, boundary tempo changes across
EOF, absolute seek/cancel, count-in after seek, phrase restart, pending tier intent
through pause/resume, and explicit native-facade activation rejection.
The MIDI validator parses all 25 binary files and checks balanced note attacks and
releases, track end times and increasing arrangement density. The preview compiles
with the locally available Dart 3.12 CLI using a package-free config; Flutter's
Dart 3.13 analyzer is also clean.

The parent task browser-checked the managed preview on an emulated Galaxy S24:
five score choices loaded, no horizontal overflow or console errors, audio context
running after activation, musical beat advancement, all five scores playing, tier 4 committed at beat 8, pause/resume holding its
frozen beat through the count-in, and a flourish without console errors. The host browser is headless; no human
speaker/listening quality or physical device latency check is claimed.

Remaining work, in order:

1. Connect gameplay's audio transport contract to `MusicTransport` and
   `MusicAudioBackend`; drive visual cues, required input timestamps, confidence
   changes and opponent reactions from one audio timeline. Reconcile gameplay's
   phrase pass lengths with two-bar music boundaries and the clean fight budgets.
2. Complete-form repetition, all five approval phrases, and four connecting bridges
   are implemented. Connect each room as it becomes playable; preload all transition
   resources before committing a handoff. Default finite playback still serves the
   score-room preview. Neither looping nor EOF awards approval.
3. Implement or verify the gameplay count-in, interruption notification bridge, gesture
   ownership, ornament rate limit and Pizazz-only award. The score room offers
   direct ornament buttons for audition, not a production gesture recognizer.
4. Ordinary pause/resume now preserves pending tier intents. Explicit seek/restart
   discards them in favor of the gameplay checkpoint tier. Conditional imports now
   isolate JS interop from native builds. Implement actual native sample-clock
   render callbacks after selecting an audio integration; no native latency results
   exist yet. The native factory currently rejects activation explicitly.
5. Add output/input timestamp calibration, device focus and route-change handling,
   telemetry for underruns/voice drops, and priority-preserving voice stealing.
   Stress-test slow frame rendering and background/resume on actual phones.
6. Listen through each melody, every tier transition and ornament on speakers and
   headphones. Refine lead timbres/envelopes and gain staging from listening;
   current Web Audio voices are lightweight synth approximations of MIDI hints.
   Capture peak/clipping measurements and verify all five rooms' cultural/musical
   character with human listening. Complete a measured flawless 5–8 minute run.
7. Select a project publication license. The current provenance record introduces
   no third-party restrictions and does not grant a public open-source license.

Interface boundaries: `score.dart` owns immutable note data; `transport.dart` owns
beat/audio-time conversion, tier boundaries and scheduling; `web_audio_backend.dart`
owns the browser context and synth voices. Gameplay owns progression and judgment.
The preview resets a score to tier 0 on Play, schedules changes at the next safe
phrase, stops at form EOF and resumes after one silent bar. The game must provide
its audible/visible count-in and use looping mode before shipping scored play.

Garden integration API (2026-10-18):

```dart
final audio = createGameAudio(); // import lib/music/game_audio.dart
await audio.activate(); // initiated by a player gesture
final music = MusicTransport(score, audio, loop: true);
music.start();
// Poll music.pump(); visual/judgment state reads music.positionBeats.
// music.countingIn gates judgment; scorePositionBeats is modulo the written form.
music.seek(checkpointBeat, tier: checkpointTier); // cancels audio, leaves paused
music.resume(leadSeconds: oneBarSeconds);
// On disposal: music.stop(); await audio.dispose();
```

Loop seams never reset `positionBeats` or the tempo map. `requestTier()` returns an
absolute two-bar boundary even beyond the form's end; note objects retain local
score beats while backend scheduling timestamps remain authoritative.
`restartPhrase(tier: ..., leadSeconds: ...)` is an explicit rewind to the current
absolute music phrase; gameplay may instead call `seek()` for its offset checkpoint
grid. Seek is valid for any finite nonnegative absolute beat in loop mode and any
beat through EOF in finite mode. It always cancels old voices and pending intents.

Success phrases and uninterrupted composition (2026-10-18 continuation):

Implemented five two-bar success phrases that quote each room's original motif and
resolve with distinct tonic codas; VIP's success is the final tag. Four authored
bridges use a percussion pivot followed by the destination motif. The source keys
are A minor, C minor, D Dorian, E minor and F major. Each bridge adopts the destination
base tempo at its percussion downbeat; it does not claim a tempo ramp or pitched
crossfade. The catalog now has 14 JSON scores, 34 MIDI exports and 6,674 note events.
`node tool/music/validate.mjs` checks all notes, all MIDI attacks/releases, all nine
transition identities, percussion pivots and destination pickups. The standalone
score room now groups all 14 pieces for audition.

`TransitionConductor` schedules source retirement → success → bridge → next room on
one device clock. `MusicTransport.startAt()` joins that clock without silencing it;
`retireAt()` stops the old transport at an uncommitted boundary without cancelling
successor voices. Transition segments use `silenceOnCompletion: false`, and every
note already has its own device release time. Natural completion never calls shared
silence. Only explicit pause/recovery/stop does. Default finite previews retain their
existing completion behavior. Conductor lookahead is configurable (default 120 ms;
playable UI may use 300 ms) and propagates to every child transport.

```dart
final conductor = TransitionConductor(audio, lookaheadSeconds: .3);
final handoff = conductor.handoff(
  source: currentMusic,
  success: loadedSuccess,
  bridge: loadedBridge,
  nextScore: loadedNextRoom,
);
// One external timer pumps conductor.pump() during source exit, success and bridge.
// Device timestamps remain live if the entire chain pauses and resumes:
// handoff.exitAtSeconds / bridgeAtSeconds / nextAtSeconds.
// Once !handoff.nextTransport.countingIn, gameplay may adopt that running transport
// without calling start(). Drop the conductor and let gameplay own the same pump.
// The room's first four intro beats still provide input-free visual breathing room.
```

`conductor.pause()` flushes the common queue once, including attacks already queued
for future segments. `resume(leadSeconds: ...)` shifts unfinished segments together
and preserves the source retirement offset. `state` and convenience getters expose
playing, paused and completed; the conductor owns no internal timer. It can also be
reused for a handoff from its running destination. `finish(source: ..., success: ...)`
plays a room's success phrase and finishes naturally. Use the VIP success for the
complete campaign ending; a prototype's final implemented room is not a claim that
the remaining campaign is playable.

`tool/music/transition_check.dart` verifies boundary downbeats without gaps, no shared
silence during any handoff or finite completion, no old-source attacks after its
retirement, propagated lookahead, successive handoffs, final-tag completion, pause
cancellation across current/future queued decks, re-anchored bridge/destination times,
and preservation of the source retirement time through pause. Existing finite/loop
transport behavior remains covered by `tool/music/transport_check.dart`. Human
listening and physical-device mix/latency validation remain required; composition
and clock-boundary tests do not substitute for those checks.
