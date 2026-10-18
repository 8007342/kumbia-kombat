# Music foundation and remaining integration

Implemented 2026-10-18: five original instrumental event scores, five tier MIDI
previews per piece (25 files, 6,136 authored/arranged events total), four optional
ornaments per piece, deterministic JS authoring and independent MIDI/data validator,
immutable Dart score parser, audio-clock transport, and oscillator/noise Web Audio
backend. `tool/music/preview.dart` and its HTML shell build a standalone score room.
This is a reviewable music foundation; the main application remains independently
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
of unavailable audio, parsing all generated scores, and finite score completion.
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
2. Add phrase vamp/cadence navigation so the 16/32-bar written forms continue until
   approval, or finish an approved room gracefully. A completed transport means
   written form EOF only. The `gameplayReference` metadata is descriptive and must
   never become a second approval engine.
3. Implement the gameplay count-in, interruption notification bridge, gesture
   ownership, ornament rate limit and Pizazz-only award. The score room offers
   direct ornament buttons for audition, not a production gesture recognizer.
4. Extend pause snapshots to preserve/reconcile pending tier intent, not just the
   active tier. Use conditional imports so native app builds never import the web
   JS interop library. Add native sample-clock render callbacks after selecting an
   audio integration; no native latency results exist yet.
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
its audible/visible count-in and looping adapter before shipping scored play.
