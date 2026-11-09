# Music layering, 2026-11-09: one recording per room, growing

Follows `plan/music-fix-2026-11-08.md`. Branch `work/2612-layr`. **Nobody has heard any of it yet.** Every number below measures the signal; none says it sounds good.

## Owner rulings (2026-11-09)

- **Tempo:** a small lift of about 3 % per tier, stretched with rubberband. Not one tempo per room, and not the old 6–7 % steps.
- **Rollout:** all rooms, with no stop after a pilot. Each room is committed once it passes the automatic gates. The owner listens at the end.

## How a room is built now

`tool/music/layer/layer.py LEVEL`, from `tool/music/layer/tiers.json`:

1. **Base:** the approved mid take, the performance whose score was praised.
2. **Parts:** the base is split with soft masks on one STFT into percussive, bass (under 160 Hz), upper centre and upper sides. The masks come from the mono magnitude, so both channels get the same mask and the image is kept. At unit gain the parts sum back to the base with a −133 dB residual, so **mid is the recording itself**.
3. **Low** takes parts away from that same recording: percussion −3 dB, centre −5, sides −12, and a −2 dB-per-octave tilt over 1.2 kHz on the upper parts.
4. **High** adds what one ACE pass (`highB`, one pass at 0.6 from the parent, never a chain) has *that the parent doesn't*: its energy over the parent's, cell by cell, with its own phase (`addNovel`). Doubled hits cancel out of it, so it holds new parts, not a second copy. Its sides are narrowed to 0.4.
5. **Tempo:** low and high are stretched with rubberband (`audio.transform time_stretch`) to their tempos. mixrs follows mid's grid scaled by the stretch (new tier field `followScale`, in mix.py and mixrs), so all three stay on one bar grid.

When Demucs lands (2055-d9sa), step 2 can take real stems and steps 3–4 keep their shape. Once ACE lego/repaint lands (2055-dihg), it can make the added layer.

Gate: `tool/music/layer/measure.py` fails a file on stereo correlation under +0.2, more than 10 % of half-second windows anti-correlated, more than 4 clipped runs, or a dropout. Its click count is informational only: it counts thousands on clean takes. Real click finding is `audio.detect_glitches`.

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
- The low loop's one flagged 10 ms dip, at 35.16 s, falls exactly on a downbeat (beats 8 and 88 of the stretched take). It is a band rest that low makes deeper by taking parts out, not a fault in the file.
- `mix.py verify`: bar passes (it failed on drift before `followScale`). The one failure left is comedor low's known −11.6 ms.
- `align_charts`: 86 overall, against 87 before. On-accent 90 % against 87 %.
- `chart_check` at the new tempos: the same 7 join problems as at the old ones, none new. The Dart tests pass.
- `test/cool_crowd_level_test.dart` asserted bridge BPM = bar high BPM, which held only because both were 112. It now asserts the real rule: the bridge plays at the tempo of the take it lands in, the party's low.
- **The detector gate is pending:** `audio.detect_glitches` didn't return on 2026-11-09 (sent to yoga by macuahuitl-fedora). Bar goes to `game` only after it passes.

## Next

Party (`cool-crowd`), galería, comedor, salón, terraza, garden, billiards, then the pool lawn. After the last room, the bridges are recut against the new lows, and each bridge's loudness is checked against its destination. The bar's bridge into the party is rebuilt when the party is.
