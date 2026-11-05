# Original score pack

The JSON files are the runtime source of composed note events. The MIDI files are
DAW/listening previews of the exact five arrangement tiers; the game does not play
them as recordings. Each tier retains the rhythmic foundation and adds written
parts. Tier 0 already has each room's restrained hook, sparse offbeat harmony,
bass and percussion. Tier 1 lifts percussion/bass; tier 2 adds fuller harmony and
alternating answers; tier 3 replaces the restrained hook with the full melody;
tier 4 completes the responses, brass and fills. Notes with `maxTier: 2` are the
restrained hook and disappear when the full melody enters. The harmonic dyads
with `maxTier: 1` give way to fuller accompaniment at tier 2.

| Room / stat | Original composition | Form | BPM, tiers 0 → 4 | Character |
| --- | --- | --- | --- | --- |
| Garden / Mojo | Lanterns in the Garden | 32 bars, A minor | 92, 95, 98, 101, 104 | Reed invitation and dry guiro |
| Bar / Swag | Copper Counter Shuffle | 32 bars, C minor | 100, 103, 106, 109, 112 | Syncopated keys and rounded bass |
| Crowd / Flow | Velvet Current | 32 bars, D Dorian | 108, 111, 114, 117, 120 | Marimba-style call and flute answer |
| Restroom / Nerve | The Last Cubicle Sprint | 16 bars, E minor | 132, 135, 138, 141, 144 | Short square plucks and urgent timbales |
| VIP / Presence | Gold at the Door | 32 bars, F major | 112, 115, 118, 121, 124 | Wide brass and final ensemble |
| Pool lawn / Grace (draft) | Long Way Across the Lawn | 32 bars AABA, E-flat major | 128, 136, 144, 152, 160 | Swung ride, walking bass, brass riffs |

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
is disposable and ignored by git. The preview is separate from the playable Flutter rooms.

JSON schema v1 uses quarter-note beats, 4/4 meter, 480 PPQ MIDI export, MIDI pitches
0–127, velocity 1–127, and sorted absolute note positions. `minTier` / `maxTier`
select arrangements. `duration` is in beats, converted through the tempo map so
all voices and visual cues share the same musical time. Tracks carry a MIDI
program and synth voice hint. The Web Audio prototype uses inexpensive oscillator
approximations; MIDI players may sound different. No recording is the source of
truth, and no live random composition replaces the written score.

See `LICENSE.md` for provenance and license status; `plan/music.md` for integration
work and device/listening checks still required.

The pack also contains six original two-bar success phrases and five two-bar
bridges (17 JSON scores and 41 MIDI files in total). `manifest.transitions.successes`
maps each success to its room; `manifest.transitions.bridges` names its source and
destination. Transition MIDI files export the success at its full-tier tempo and
the bridge at the destination's base tempo. Every transition note plays at every
tier; these are complete composed phrases, not progression arrangements.
Success phrases thin accompaniment and soften attacks in their second bar while
retaining the melodic answer and beat, giving the party an authored warm-down.

| Segment | Tonal and rhythmic purpose |
| --- | --- |
| `garden_mojo_success` | Garden reed call raised an octave; rising A-minor tonic answer |
| `bar_swag_success` | Syncopated bar call; clipped descending C-minor answer |
| `crowd_duende_success` | Flow call; D-Dorian sixth and gentle descending resolution |
| `restroom_nerve_success` | Urgent square-pluck call; short-note release into E minor |
| `vip_presence_success` | Broad brass call; F-major tonic tag closes the whole night |
| `pool_swing_success` | Lawn call raised an octave; E-flat tonic answer as the band thins |
| `garden_to_bar` | Dry guiro/clave pivot, then the C-minor bar motif |
| `bar_to_crowd` | Lighter clave pivot, then the D-Dorian crowd motif |
| `crowd_to_restroom` | Tightening timbales, then the urgent E-minor motif |
| `restroom_to_vip` | Spacious percussion pivot, then the opening F-major VIP motif |
| `bar_to_pool` | Straight drum break, then the bass walks C, F, B-flat into swung E-flat |

Every bridge begins with unpitched percussion, then introduces the destination key.
Its downbeat takes the destination base tempo intentionally; this is an authored
rhythmic change rather than a synthetic tempo ramp. No prerecorded audio or pitch
crossfade is used. The score room dropdown groups rooms, success phrases and bridges
for individual audition. The live `TransitionConductor` sequences them without
backend-wide silence; isolated score-room auditions still stop at form EOF.

Additional scheduler verification:

```sh
dart --packages=build/music-preview/packages.json tool/music/transition_check.dart
```

## Swing

A score can set `swing: {ratioAt100, ratioAt300}` in `tool/music/generate.mjs`. Its
notes are written on a straight grid and each offbeat is moved later. The ratio falls
in a straight line with tempo, from `plan/research/swing-duet-research-2026-11-05.md`.
A score holds one position per note but plays at five tempos, so a swung note is
written once per tier, gated by `minTier` and `maxTier`. That is why `pool_swing` has
about three times the events of a cumbia score. Scores without the setting are
unchanged. A transition plays at one tier, so it swings for that tier's tempo.

On the runtime synth the ride is pitch 73 and the hi-hat 75, its two high noise
voices. General MIDI's ride (51) and hat (42) would get a negative frequency there.
In a MIDI player those same numbers are a guiro and claves, so the `pool_swing`
exports will not sound like a drum kit. Audition it in the score room instead.

```sh
node tool/music/validate_pool.mjs
```

This checks notes, tiers, tempos, the pool lawn's chart and its marks. It cannot say
how the music sounds. Nobody has listened to these scores yet.
