# Original score pack

The JSON files are the runtime source of composed note events. The MIDI files are
DAW/listening previews of the exact five arrangement tiers; the game does not play
them as recordings. Each tier retains the rhythmic foundation and adds written
parts. Tier 3 replaces the short invitation melody with the full melody; tier 4
adds counterlines, brass and fills. Notes with `maxTier: 2` are the invitation and
must disappear when the full melody enters.

| Room / stat | Original composition | Form | BPM, tiers 0 → 4 | Character |
| --- | --- | --- | --- | --- |
| Garden / Mojo | Lanterns in the Garden | 32 bars, A minor | 92, 95, 98, 101, 104 | Reed invitation and dry guiro |
| Bar / Swag | Copper Counter Shuffle | 32 bars, C minor | 100, 103, 106, 109, 112 | Syncopated keys and rounded bass |
| Crowd / Flow | Velvet Current | 32 bars, D Dorian | 108, 111, 114, 117, 120 | Marimba-style call and flute answer |
| Restroom / Nerve | The Last Cubicle Sprint | 16 bars, E minor | 132, 135, 138, 141, 144 | Short square plucks and urgent timbales |
| VIP / Presence | Gold at the Door | 32 bars, F major | 112, 115, 118, 121, 124 | Wide brass and final ensemble |

`crowd_duende` is a stable asset ID; the selected player-facing stat is **Flow**.
Every piece has two authored two-bar melodic phrases, arranged through eight-bar
sections, plus independent up/down/left/right adornments. The 16-bar restroom
piece deliberately uses only Invitation and Answer sections. Durations are
musical form lengths; they are not automatic level timers. The gameplay adapter
must repeat complete phrases or exit through a cadence according to its challenge
state. `gameplayReference` mirrors the campaign for review; gameplay owns approval.

Regenerate and validate from the repository root:

```sh
node tool/music/generate.mjs
node tool/music/validate.mjs
node tool/music/build_preview.mjs
dart --packages=build/music-preview/packages.json tool/music/transport_check.dart
```

Serve `build/music-preview/` over HTTP to open the standalone score room. On this
forge use the managed local publisher with `app_dir: build/music-preview`; do not
open the HTML via `file://`, because score loading uses fetch. The builder uses an
empty package configuration to keep the dependency-free preview compatible with
the locally installed Dart CLI as well as the newer Flutter toolchain. Build output
is disposable and ignored by git. The preview is separate from the landing page.

JSON schema v1 uses quarter-note beats, 4/4 meter, 480 PPQ MIDI export, MIDI pitches
0–127, velocity 1–127, and sorted absolute note positions. `minTier` / `maxTier`
select arrangements. `duration` is in beats, converted through the tempo map so
all voices and visual cues share the same musical time. Tracks carry a MIDI
program and synth voice hint. The Web Audio prototype uses inexpensive oscillator
approximations; MIDI players may sound different. No recording is the source of
truth, and no live random composition replaces the written score.

See `LICENSE.md` for provenance and license status; `plan/music.md` for integration
work and device/listening checks still required.
