# Loop-wrap evidence, 2026-11-10

Why `main` is still held after `audio.detect_glitches` ran on 56.11.10.1, and what the raw loops show. The detector doesn't hang any more, but its findings on this music are mostly its own artifacts. Every loop wrap was measured directly instead, and none is a fault. `main` waits for yoga's recalibrated detector (row 2072-tap8) to re-run the 35 files clean, then for the owner.

## The detector run

All 35 staged files (9 rooms × low/mid/high, plus 8 bridges; terraza has no bridge) were flagged except the bar, galería and garden bridges. Reports are in `/work/tmp/audio/out/detect/`. Calibration showed what each finding is:

- **The .ogg isn't the loop.** `mix.py` writes `loop[-pad:] + loop + loop[:pad]` with a pad of 0.25 s, and the game loops on `loopStartSeconds`/`loopEndSeconds`. `loop: true` on the .ogg tests a seam the game never plays. The game's loops were cut sample-exact (pad 12000, `loopSamples`) to `/work/tmp/audio/calib/loops/`.
- **`loop_seam` is miscalibrated for music.** It flags wraps that are continuous by construction. A rolled loop (second half + first half, so the wrap is two adjacent original samples) is flagged on garden low, bar low and billiards mid, with level steps of 14.3, 10.5 and 7.4 dB. A 20 ms crossfade loop built like mixrs's is flagged on garden (8.6 dB) and not on bar.
- **The beat-grid "clicks" are drum hits.** Split with `layer.split` (HPSS): bar low has 50 in the mix, 41 in the percussive part (same times), 1 in the harmonic part. Billiards mid has 65 / 59 / 1. Drum onsets score `peak_ratio` 12–45 against a floor of about 12, so no threshold separates them on a full mix.
- **The 2.5–5 kHz hole in garden mid** disappears when the same audio is cut 0.25 s later, so it depends on frame alignment. The 8–20 kHz holes show in the percussive part (bar low: 23) and not in the harmonic part (0).

## The raw loops

Every room was rebuilt with `mix.py build --root /work/tmp/audio/rebuild`, keeping mixrs's work directory. **All 27 rebuilt .ogg are byte-identical to the shipped ones**, so each `loop.f32` is exactly what was encoded. `tool/music/layer/wrap.lua` compares it with the decoded Opus loop:

    ffmpeg -i calib/loops/ROOM--TIER.wav -f f32le ROOM--TIER.dec.f32
    lua tool/music/layer/wrap.lua WORK/ROOM/TIER/loop.f32 ROOM--TIER.dec.f32

Columns:
- **Wrap**: max |x[0] − x[N−1]| over both channels.
- **pct**: its percentile among the loop's own sample-to-sample steps.
- **p99** and **max**: of those steps.
- **Dec. wrap**: the same step on the decoded Opus.
- **d2 tail**: the sharpest second difference in the last 50 ms, and where it falls.
- **d2 max**: the sharpest second difference over the whole loop.
- **Residual**: decoded − raw, relative to the signal, over the whole loop and over the last 40 ms.

| Loop | Wrap | pct | p99 | max | Dec. wrap | d2 tail | d2 max | Residual dB (whole / last 40 ms) |
|---|---|---|---|---|---|---|---|---|
| bar low | 0.04324 | 93.0 | 0.09243 | 0.38166 | 0.00806 | 0.08842 @ -17.8 ms | 0.60281 | -21.9 / -20.5 |
| bar mid | 0.02574 | 78.3 | 0.10528 | 0.52484 | 0.00650 | 0.10869 @ -3.0 ms | 0.74254 | -21.2 / -19.5 |
| bar high | 0.05041 | 87.6 | 0.12206 | 0.57548 | 0.04055 | 0.28300 @ -14.1 ms | 0.75840 | -20.1 / -17.8 |
| garden low | 0.02368 | 89.4 | 0.06244 | 0.24273 | 0.04306 | 0.09611 @ -2.6 ms | 0.34138 | -24.4 / -19.9 |
| garden mid | 0.01180 | 51.8 | 0.07168 | 0.25083 | 0.00756 | 0.09330 @ -0.8 ms | 0.34391 | -23.8 / -16.6 |
| garden high | 0.02700 | 72.7 | 0.10011 | 0.31094 | 0.05074 | 0.12005 @ -4.3 ms | 0.49603 | -22.7 / -16.7 |
| pool-garden low | 0.00387 | 44.1 | 0.06642 | 0.23590 | 0.01156 | 0.07673 @ -10.1 ms | 0.24827 | -24.5 / -22.3 |
| pool-garden mid | 0.06534 | 98.6 | 0.07327 | 0.24438 | 0.06484 | 0.10428 @ -3.8 ms | 0.27571 | -24.2 / -22.6 |
| pool-garden high | 0.04219 | 91.8 | 0.08331 | 0.26021 | 0.03847 | 0.12202 @ -1.1 ms | 0.28760 | -24.3 / -24.9 |
| cool-crowd low | 0.01744 | 80.2 | 0.07487 | 0.34407 | 0.03048 | 0.16963 @ -2.0 ms | 0.50684 | -22.6 / -24.1 |
| cool-crowd mid | 0.06086 | 96.5 | 0.08999 | 0.35496 | 0.06566 | 0.10231 @ -1.6 ms | 0.58366 | -21.9 / -21.5 |
| cool-crowd high | 0.05779 | 93.2 | 0.10874 | 0.44015 | 0.04812 | 0.13724 @ -0.8 ms | 0.74617 | -21.0 / -20.2 |
| billiards low | 0.01345 | 89.5 | 0.06592 | 0.38641 | 0.01476 | 0.04247 @ -10.7 ms | 0.36489 | -24.2 / -23.6 |
| billiards mid | 0.01923 | 90.4 | 0.08782 | 0.48244 | 0.01832 | 0.04699 @ -10.3 ms | 0.48326 | -24.2 / -25.8 |
| billiards high | 0.02808 | 91.4 | 0.11792 | 0.68503 | 0.02799 | 0.05828 @ -6.8 ms | 0.65915 | -22.6 / -25.1 |
| salon low | 0.01904 | 87.8 | 0.05885 | 0.21400 | 0.01489 | 0.17354 @ -23.2 ms | 0.24953 | -24.0 / -19.6 |
| salon mid | 0.03352 | 92.3 | 0.06541 | 0.23637 | 0.04722 | 0.20354 @ -17.8 ms | 0.24382 | -23.1 / -19.6 |
| salon high | 0.04759 | 94.7 | 0.07963 | 0.28830 | 0.03942 | 0.22827 @ -15.1 ms | 0.30829 | -22.6 / -19.5 |
| comedor low | 0.10677 | 96.5 | 0.16709 | 0.60112 | 0.09494 | 0.18898 @ -11.1 ms | 0.75556 | -20.0 / -18.8 |
| comedor mid | 0.01478 | 30.2 | 0.21338 | 0.69234 | 0.04028 | 0.22945 @ -9.6 ms | 0.83768 | -17.5 / -18.9 |
| comedor high | 0.04325 | 59.1 | 0.27042 | 0.82542 | 0.07355 | 0.24452 @ -7.7 ms | 1.10584 | -16.2 / -17.8 |
| galeria low | 0.02227 | 90.3 | 0.08933 | 0.35395 | 0.01841 | 0.29930 @ -0.2 ms | 0.39628 | -24.0 / -23.0 |
| galeria mid | 0.05213 | 96.3 | 0.09980 | 0.37520 | 0.03170 | 0.36190 @ -3.2 ms | 0.44390 | -24.0 / -18.6 |
| galeria high | 0.19439 | 99.6 | 0.14756 | 0.70602 | 0.18484 | 0.60318 @ -2.0 ms | 0.76618 | -23.1 / -17.0 |
| terraza low | 0.01171 | 58.9 | 0.09760 | 0.44170 | 0.03439 | 0.11507 @ -1.1 ms | 0.65299 | -23.1 / -23.4 |
| terraza mid | 0.02510 | 68.0 | 0.11768 | 0.45356 | 0.01258 | 0.13522 @ -8.1 ms | 0.68343 | -21.8 / -22.7 |
| terraza high | 0.02215 | 52.2 | 0.16774 | 0.65971 | 0.00906 | 0.27538 @ -2.6 ms | 0.91057 | -20.7 / -21.5 |

- **26 of 27 wraps are under the loop's own p99.** The sharpest feature near a wrap is never the loop's largest.
- **Galería high** (p99.6) is the source's own waveform. `tool/music/layer/locate.lua` finds the loop in its grid at sample 274290 (correlation 1.0000). The grid steps 0.1757 across the same point, the loop 0.1944, a ratio of 1.11, and the loop's tail runs 1.00 dB over the grid (the makeup gain). A drum attack starts on the loop point, because the room's beat bias is 0.07 ms.
- **Encoding does nothing special at the wrap.** Decoded and raw align at shift 0 (searched ±8 samples). The Opus residual is −16 to −25 dB everywhere. The tail is sometimes a few dB worse because it holds the next downbeat's attack, and the largest errors are mid-loop.
- **Bar's click 18 ms before the wrap is its downbeat.** It is in `loop.f32` at −17.8 ms, and `report.json` gives bar `beatBiasMs` 17.99: the onsets lead the bar grid. The 0.229 s clicks in the padded files are the same onset.
- Mastering can't put a step at the wrap: `master_loop` limits with `circular: true`.
- `mix.py build` refused once with "6.4 GB in use, over the 6 GB limit". `memory_in_use` reads the cgroup's `memory.current`, which counts reclaimable page cache: 5.9 GB of it was cache, 0.3 GB anon. Dropping the scratch files from cache (`dd iflag=nocache count=0`) cleared it. Not changed here.
