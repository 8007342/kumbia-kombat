# Music layering, 2026-11-09: one recording per room, growing

Follows `plan/music-fix-2026-11-08.md`. Branch `work/2612-layr`. **Nobody has heard any of it yet.** Every number below measures the signal; none says it sounds good.

## Owner rulings (2026-11-09)

- **Tempo:** a small lift of about 3 % per tier, stretched with rubberband. Not one tempo per room, and not the old 6–7 % steps.
- **Pool lawn:** layered from its 136 take, the richest, which used to play last. Tempos rise about 3 % in play order.
- **Rollout:** all rooms, with no stop after a pilot. Each room is committed once it passes the automatic gates. The owner listens at the end.

## How a room is built now

`tool/music/layer/layer.py LEVEL`, from `tool/music/layer/tiers.json`:

1. **Base:** the approved mid take, the performance whose score was praised. **Mid plays that file untouched** (except the party, below). A copy trimmed by 1 dB moved the terraza's bar one by a beat and every room's beat bias by a few ms, because the mixer's beat analysis is level-sensitive. So tiers are written as float WAV and never rescaled.
2. **Parts:** the base is split with soft masks on one STFT into percussive, bass (under 160 Hz), upper centre and upper sides. The masks come from the mono magnitude, so both channels get the same mask and the image is kept. At unit gain the parts sum back to the base with a −133 dB residual, so **mid is the recording itself**.
3. **Low** takes parts away from that same recording: percussion −3 dB, centre −5, sides −12, and a −2 dB-per-octave tilt over 1.2 kHz on the upper parts.
4. **High** adds what one ACE pass (`highB`, one pass at 0.6 from the parent, never a chain) has *that the parent doesn't*: its energy over the parent's, cell by cell, with its own phase (`addNovel`). Doubled hits cancel out of it, so it holds new parts, not a second copy. Its sides are narrowed to 0.4.
5. **Tempo:** `mixrs room plan LEVEL` gives the tempos and stretch ratios; `mixrs room stage LEVEL` copies low and high to `/work/tmp/audio/layered/`, where they are stretched with rubberband (`audio.transform time_stretch`); `mixrs room wire LEVEL` copies them back and points `levels.json` at them. mixrs follows mid's grid scaled by the stretch (new tier field `followScale`, in mix.py and mixrs), so all three stay on one bar grid.

When Demucs lands (2055-d9sa), step 2 can take real stems and steps 3–4 keep their shape. Once ACE lego/repaint lands (2055-dihg), it can make the added layer.

Gate: `mixrs measure` (was `tool/music/layer/measure.py`) fails a file on stereo correlation under +0.2, more than 10 % of half-second windows anti-correlated, more than 4 clipped runs, or a dropout. Its click count is informational only: it counts thousands on clean takes. Real click finding is `audio.detect_glitches`.

## Bar (`bar`, C minor), done, detector gate pending

Tempos 103 / 106 / 109 (was 100 / 106 / 112). Loop 24 bars.

| File | Stereo corr | Neg. windows | Centroid Hz | Bass dB | LUFS |
|---|---|---|---|---|---|
| low, before | +0.17 | 21 % | 392 | −2.8 | −16.5 |
| **low, after** | **+0.72** | 3 % | 263 | −1.5 | −16.5 |
| mid, before = after | +0.38 | 4 % | 404 | −2.7 | −16.0 |
| high, before | −0.07 | 57 % | 1021 | −4.8 | −15.0 |
| **high, after** | **+0.38** | 6 % | 462 | −2.9 | −15.0 |
| success, before | −0.08 | 72 % | 1491 | −6.4 | −14.1 |
| **success, after** | **+0.40** | 0 % | 606 | −3.5 | −14.4 |
| bridge to the party, after | +0.59 | 0 % | 562 | −4.1 | −17.5 |

- No clipped runs in any file.
- **High is now only a little brighter than mid** (462 against 404 Hz), not 2.5× as before. The step up comes from added parts and +1 LU, not a change of sound. If the owner hears it as too small a lift, raise `high.add` in `tiers.json`: the added layer is about 8 LU under the base before mixing.
- The low loop's flagged 10 ms dips fall exactly on downbeats (beats 8 and 88 of the stretched take). They are band rests that low makes deeper by taking parts out, not faults in the file.
- `mix.py verify`: bar passes (it failed on drift before `followScale`). The one failure left is comedor low's known −11.6 ms.
- `align_charts`: 86 overall, against 87 before. On-accent 90 % against 87 %.
- `chart_check` at the new tempos: the same 7 join problems as at the old ones, none new. The Dart tests pass.
- `test/cool_crowd_level_test.dart` asserted bridge BPM = bar high BPM, which held only because both were 112. It now asserts the real rule: the bridge plays at the tempo of the take it lands in, the party's low.
- **The detector gate is pending:** `audio.detect_glitches` didn't return on 2026-11-09 (sent to yoga by macuahuitl-fedora). Bar goes to `game` only after it passes.

## Party (`cool-crowd`, D minor), done, detector gate pending

Tempos 120 / 124 / 128 (was 112 / 124 / 136). The party's parent is wide on its own: 14 % of its windows are anti-correlated, which fails the gate. So **every tier narrows the upper sides the same way** (−2.5 dB on mid and high, −12 on low). That is one mastering choice applied to one recording, not a change between tiers.

| File | Stereo corr | Neg. windows | Centroid Hz | LUFS |
|---|---|---|---|---|
| mid, before | +0.56 | | | −16.0 |
| high, before | −0.15 | | | −15.0 |
| **low, after** | **+0.89** | 0 % | 234 | −16.5 |
| **mid, after** | **+0.69** | 0 % | 371 | −16.0 |
| **high, after** | **+0.62** | 1 % | 418 | −15.0 |
| success, after | +0.70 | 0 % | 393 | −15.1 |
| bridge to billiards | +0.49 | **20 %** | 261 | −17.8 |

- **The bridge into billiards fails the gate.** It is cut partly from billiards' old low, and is rebuilt when billiards is.
- **One stop in the performance:** all three tiers fall to about −75 dB for 50–100 ms near beat 53 of the loop (around bar 14), inside a passage already at −39 dB. The approved mid had it before. It is in the take, not made here. **For the owner's listen:** is it a musical break or a hole?
- `align_charts`: 67 against 68 before. `chart_check`: the same 37 problems at the new tempos as at the old. They are older than this work; the Dart tests are the authority and pass.

## Galería (`galeria`, A Dorian), done, detector gate pending

Tempos 118 / 122 / 126 (was 114 / 122 / 130). Its parent was already narrow enough (+0.68), so it uses the bar's gains unchanged.

| File | Stereo corr | Neg. windows | Clipped runs | Centroid Hz | LUFS |
|---|---|---|---|---|---|
| low | +0.91 | 0 % | 0 | 274 | −16.5 |
| mid | +0.69 | 0 % | 0 | 419 | −16.0 |
| high | +0.67 | 0 % | 0 | 506 | −15.0 |
| success | +0.68 | 0 % | 0 | 478 | −14.5 |
| bridge to the terraza | +0.77 | 0 % | 0 | 533 | −15.9 |

- The audit's clipping growth (6 to 157 runs over the chain) is gone: high no longer comes from the chain.
- `align_charts`: **97 against 92**, with on-accent at 100 %. `chart_check`: no problems.
- Rebuilt as a side effect, with no change to their sources: the salón's bridge into galería (+0.85, −16.6 LUFS) and the bar's bridge into the party (+0.72, −16.9 LUFS, within 0.4 LU of the party's low).

## Comedor, salón and terraza, done, detector gate pending

| Room | Tempos (was) | Low corr | Mid corr | High corr | Tag corr | align_charts (before) |
|---|---|---|---|---|---|---|
| comedor | 124 / 128 / 132 (120 / 128 / 136) | +0.93 | +0.79 | +0.76 | +0.75 | 97 (95) |
| salón | 113 / 116 / 119 (108 / 116 / 124) | +0.87 | +0.58 | +0.57 | +0.51 | 99 (96) |
| terraza | 101 / 104 / 107 (96 / 104 / 112) | +0.93 | +0.80 | +0.79 | +0.77 | 93 (95) |

- No anti-correlated windows, clipped runs or dropouts in any of their files.
- **Comedor's −11.6 ms low lag is gone.** That was its one long-standing verify failure: low is now the same recording, not a separate pass. Its low centroid is half of mid's (469 against 934 Hz) without the old −6 dB shelf.
- **Terraza's high now has mid's density** (3.50 onsets a second against 3.42), where the old high had fewer than mid. The act-two note asked for exactly this.
- `mix.py verify` now interpolates the lag peak between envelope frames. Its 5 ms limit is under one frame (5.8 ms), so before this it could only tell 0 frames from 1. With mid untouched, **verify reports 0 failures on all nine levels** for the first time since act two.
- Bridges rebuilt into the new lows, LUFS against the destination's low (−16.5): billiards into comedor −16.8, comedor into salón −16.9, salón into galería −17.1, galería into terraza −16.9. All are within 1 LU.

## Billiards and garden, done, detector gate pending

| Room | Tempos (was) | Low corr | Mid corr | High corr | Tag corr | align_charts (before) |
|---|---|---|---|---|---|---|
| billiards | 97 / 100 / 103 (96 / 100 / 104) | +0.79 | +0.67 | +0.66 | +0.65 | 63 (64) |
| garden | 95 / 98 / 101 (92 / 98 / 104) | +0.94 | +0.78 | +0.80 | +0.73 | 90 (94) |

- **Billiards' parent fails the gate on its own:** +0.30, with 33 % of windows anti-correlated and 19 clipped runs. The audit called billiards clean, but by this gate it was the widest base of all. Every tier narrows its upper sides by **6 dB**; −4 left mid at exactly 10 %. **This narrows the approved take's image, so it's the owner's to reverse** (`tiers.json`, `billiards.tiers.mid.side`).
- Billiards' loops show 3–8 flagged dips, all just before beats 32 and 64, the ends of its 8-bar phrases. Mid has them too. They are phrase stops in the take.
- The garden's parent has 393 clipped runs baked into the ACE render. After the mixer's loudness and limiter, the rendered loops show none. It was declipped by level, not repaired; a true declip waits for the studio.
- `chart_check`: billiards 44 problems and garden 2, the same counts at the old tempos. `hardest_combo_test` and `billiards_level_test` (fairness at 104, now above its top tier) pass.
- The party's bridge into billiards now passes: +0.81, 0 %.

## Pool lawn (`pool-garden`, C major), done, detector gate pending

Was three separate takes cut together, at 144 / 160 / 136 in play order. Now it is **one recording, the 136 take**, which the owner called "still much richer". It plays untouched at its own tempo on the top tier, and the two tiers before it take parts out of it. Nothing is added.

- **Tempos 128 / 132 / 136.** The owner's example was 132 / 136 / 140. At 140 the top tier's chart fails fairness: one thumb hop, beats 6.0 to 6.75, comes out 321 ms apart against a 330 ms floor. That chart was written for 136 at the top. So the same 3 % steps end on the take's own tempo, with no stretch on the richest tier. **Reversible if the owner wants 140.**
- The level now joins like the others (`gridTier: high`, `layerFadeBeats: 1`) instead of `joinStyle: cuts`. The grid is the untouched take. With mid as the grid, verify had put high at −5.7 ms.
- Low: perc −3, centre −5, sides −12, tilt. Mid: perc −1, centre −1.5, sides −5, a lighter tilt.

| File | Stereo corr | Neg. windows | Centroid Hz | LUFS |
|---|---|---|---|---|
| low | +0.84 | 0 % | 261 | −16.5 |
| mid | +0.70 | 0 % | 381 | −16.0 |
| high | +0.50 | 4 % | 475 | −15.0 |
| success | +0.64 | 0 % | 546 | −14.9 |
| bridge to the bar | +0.65 | 0 % | 489 | −16.2 |

- The flagged dips (2–8 per loop) all fall just before whole beats, the same in every tier: stop-time hits in the swing take.
- **`align_charts` fell from 83 to 77.** The top tier is unchanged at 80, being the same take at the same tempo. **Tiers 0 and 1 fell from 93 to 70**, and tier 2 from 81 to 64: their charts were tuned to the old 144 and 160 takes, which are different recordings. **Re-aligned the same day** with `align_suggest.mjs --write` (macuahuitl-fedora assigned it here). It moved 10 steps in patterns 0–3, mostly off-beats from .75 onto straight .5 eighths, where the 136 take's accents are. Pattern 1 is also tier 4's replay. Result: **90 overall** (tiers 96, 96, 94, 93, 85), and `chart_check` problems fell from 13 to 6. The off-beat share drops a little; the campaign's off-beat test still passes. Whether the straighter eighths feel right under the thumb is for the owner's play. `chart_check`: the same 13 problems at the new tempos as at the old.
- `test/rendered_music_test.dart` and `test/rich_moves_test.dart` hold the new ladder. `mix.py --self-test` does too.

## Bridges match the room they land in

`mix.py` now gives each bridge the loudness of the take it lands in (new `bridge.maxMatchDb`, 4 dB, then the limiter again). The fade from one room's harmony to the next room's percussion had made bridges quieter: garden into the lawn was 2.4 LU under. Gains applied: garden +2.5, party +1.8, billiards +0.8, salón +0.8, comedor +0.6, bar and galería +0.5, the lawn 0. **Every bridge now sits at −16.2 to −16.9 LUFS, within 0.4 LU of its destination.**

## Tests that held the old ladders

`test/rich_moves_test.dart`, `test/cool_crowd_level_test.dart`, `test/rendered_page_test.dart`, `test/salon_level_test.dart` `test/level_registry_test.dart` (the salón's top rate against billiards', now at 119 against 103) and the garden's two first-take checks in `test/rendered_page_test.dart` (95) held the old tempos as the owner's ladders. They now hold the 3 % ladders. `mix.py --self-test` holds them too. The full `flutter test` passes, 792 tests.

## Next

**Next: run detection on `/work/tmp/audio/after/*.ogg`** (`audio.detect_glitches`, `loop: true` for `low`, `mid` and `high`, `loop: false` for `bridge`; 36 files, each room's tiers and bridge, copied from `assets/music/rendered/`). This forge's host tools were still served by the 56.11.9.1 launcher behind the terminal window, so the #1048 fix only reaches them after the operator relaunches the window. Report the findings to macuahuitl-fedora. If they're clean, the owner decides on `main`; if not, fix each flagged file on a new work ref. Two rooms at a time on the GPU.

- **All nine rooms are layered.** `mix.py verify`: 0 failures on all nine. The full `flutter test` passes (792).
- The synth fallback scores in `tool/music/generate.mjs` still carry the old ladders for every room. They play only for a room with no rendered takes, and all nine have them. On a decode failure the synth already runs on the take's clock (`rendered_page_test`). Not changed here.
- **Promoted to `game` on 2026-11-10** (8d3544e), on the owner's approval ahead of the detector. `main` waits for `audio.detect_glitches`: it hung on 2026-11-09 (three calls timed out after 30 minutes); its fix (#1048) is in tray v56.11.10.1, but on 2026-11-10 this forge's audio tools still answered from the 56.11.9.1 app. The 36 files to check are staged in `/work/tmp/audio/after/<room>--{low,mid,high,bridge}.ogg`.
- **The layer tools are Rust (2026-11-10, operator rule: Lua, then Rust, then Go).** `measure.py`, `lag.py` and `room.py` are now `mixrs measure`, `mixrs lag` and `mixrs room`, and the .py are deleted. `tool/music/mixrs/compare/layer_golden.sh` checks them against the Python's outputs on the bar and salón: every measure on decoded WAV to the last digit, every lag, both plans, and `wire` writing `levels.json` byte for byte. The one allowed difference is the click count on .ogg (ffmpeg against libsndfile decoding, 19685 against 19684 on the bar's high), which isn't a gate. `layer.py` stays Python: its STFT and median filters are the library exception.
