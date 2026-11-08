# Music for the salon, 2026-11-07

`salon_bolero`, "Terciopelo", a bolero-cha for El Salón de Espejos, plus its tag and the bridge in from billiards. **Nobody has heard any of it.** Every number below measures timing, harmony, spectrum or level. None of them says it sounds good or sounds like a bolero-cha.

## What shipped (branch `work/1876-bolr`)

| Asset | What it is |
|---|---|
| `assets/music/rendered/salon/{low,mid,high}.{ogg,m4a}` | Three tiers from one performance at 108, 116 and 124 BPM. Each loops 24 bars |
| `assets/music/rendered/salon/success.*` | A 4-bar tag at 124 that lands on F major, the relative major. It fades over its last 4 beats (`final: true`) |
| `assets/music/rendered/billiards/success.*` | Rebuilt as `final: false`: the same 4 bars at 104, with the percussion thinning in the last beat instead of fading out |
| `assets/music/rendered/billiards/bridge.*` | 2 bars at 108 into salon low, `entryBar` 18 |
| `assets/music/scores/salon_bolero*.json`, `billiards_to_salon.json`, 7 MIDI files | The synth fallback, written in `tool/music/generate.mjs` |
| `tool/music/mix/levels.json`, `assets/music/rendered/manifest.json` | The salon entry, and billiards now pointing on to the salon |
| `tool/music/sheets/salon.candidates.json`, `salon.chain.json` | Every candidate's tags, seeds and measures, and the chain spec that rebuilds the tiers |
| `tool/music/mix/mix.py` | New optional `successKey`, so a tag can land on a chord other than the loop's key |

Masters (FLAC, not committed): `~/.cache/tillandsias-project/kumbia-audio/pipeline-20261107/chains/salon/`, and candidates under `~/.cache/tillandsias-project/kumbia-audio/salon-20261107/cands/`.

## How the mid was chosen (proposal, reversible)

There were 12 takes: three tag sets (A "elegant romantic bolero-cha…", B "classic Cuban charanga cha-cha-cha…", C "slow romantic ballroom cha-cha-cha…"), with four seeds each, all at 116 BPM in D minor, 74.5 s long.

- **Timing filter:** 8 of 12 pass (`measure_takes.py`). The failures: 58100 (wander 111 ms), 58200 (no clear pulse), and 58201 and 58203 (tempo 1.8% and 2.6% off).
- **Chord ear (`sheet.py ear`, a template matcher with no model):** every pass reads as D minor-centred.
- **Chosen: seed 58001, tag set A.** It has the tightest timing of the strong takes (wander 3.1 ms, clarity 18.2). Its lead salience is 94.6, second among the passes. Melodic motion is 0.103, lead range 22 semitones, and level range 7.9 dB with no dropouts. The chord ear hears one clean 8-bar progression repeated: **Dm Gm C F Dm Gm A Dm**, which is the classic circle-of-fifths bolero cadence. Of all the candidates, that is the strongest sign of a written song form.
- **Runner-up 58202 (set C):** the steadiest beat of all (wander 1.7 ms), salience 102.8, but a darker, narrower spectrum (centroid 317 Hz). Some bars read F minor, which doesn't fit the key.
- **58003** had the highest salience (112), but bars 1 to 4 read Fm and E, which looks like a stray intro, and its level range was 15.5 dB.

These measures were picked after looking at two earlier blind winners. They can shortlist takes. They can't choose one. **Whether 58001 is elegant, romantic and has a violin and flute carrying the tune is the owner's call.** The chord ear doesn't hear instruments. To swap it, change `parent.seed` (and its tag set) in `salon.chain.json`, rebuild the workflow with `build_workflow.py`, run it, and rebuild with mixrs.

## Tiers from one performance

Same recipe as billiards. The parent reproduces candidate 58001 exactly (MD5 of the decoded audio).

- **Low:** `lowC`, one pass at denoise 0.7 with intimate-trio tags, plus a -3 dB shelf at 1.5 kHz. `lowB` at 0.6 was brighter than mid (411 Hz against 371), so lowC (382 Hz) was used.
- **High:** `highE`, four passes at 0.6 with full-charanga tags ("lush string section swelling", flute, timbales), with the parent's percussion under it at -6 dB.

| Tier | BPM | Envelope vs mid | Bar harmony vs mid | Onsets/beat* | Centroid Hz* | Spread Hz* | LUFS | True peak |
|---|---|---|---|---|---|---|---|---|
| low | 108 | 0.97 | 0.951 | 1.91 | 364 | 415 | -16.5 | -4.8 |
| mid | 116 | | | 1.96 | 399 | 540 | -16.0 | -3.7 |
| high | 124 | 0.93 | 0.934 | 1.85 | 600 | 712 | -15.0 | -2.7 |

\* Measured on the encoded Opus loops. Attack lag between tiers is 0 ms in verify.

The spectrum rises clearly from low to high. Onsets per beat don't rise, the same as on the party. **Whether high's strings actually swell is unknown:** brightness rose, and that's all the numbers can show.

## Loop

24 bars, three times through the 8-bar progression. 32 bars was tried first: it allowed only one candidate start, and its seam measured harmony 0.49 and texture -0.38. 24 bars gives 0.945 and 0.205. Texture 0.205 is weak next to billiards (0.85), so **listen to the wrap**, at about 50 s on mid. 16 bars measured 0.936 and 0.083.

mix.py places bar 1 one bar after the take's harmonic start, so the loop's 8-bar unit reads **Gm C F Dm Gm A Dm Dm** and ends on two tonic bars (loop bars 6-7, 14-15, 22-23). It's still on the downbeat (`bar1Confidence` 1.0). Only the phrase grouping moves, and it puts the cadence at the end of each 8 bars.

## Exit music

- **Salon tag:** loop bars 15 to 18 of high. The ear reads **Dm Gm C F**, so it lands on F major as asked. Beats 13 to 16 fade (-20.9, -26.3 and -39.8 dB RMS on the last three beats).
- **Billiards:** tag bars 7 to 10 of billiards high, which reads G, Gm, D, G. The bridge reads Gm then C, and its harmony match into salon low's bar 18 is 0.82. Billiards is in G minor and the salon in D minor. G minor is iv of D minor, so the keys are close, but **the bridge is one of the joins to listen to.**

## Synth fallback

`salon_bolero`: an original 32-bar AABA-like form in D minor (B section in F major). It has a güiro long-long-long-short-short, a conga "cha-cha" on beats 4 and 4-and, a bass with the 4-and pickup, and a montuno figure. A bolero line on the lead (MIDI program 40, violin) is answered by flute. Strings (program 48) swell at tier 4. Its tiers run 108, 112, 116, 120 and 124 BPM, so tiers 0, 2 and 4 match the rendered tempos. `salon_bolero_success` is 4 bars, Dm Bb C7 F, ending on an F major triad. `billiards_to_salon` is 2 bars at 108: a bar of percussion alone, then Gm and A7 into D minor, with the flute quoting the call. `validate.mjs` was extended: it allows an explicit tempo ladder, allows a 4-bar success, and checks that the tag's last chord is the triad of its `resolvesTo` key, a relative major. It passes.

## For LEVEL (sent)

Tempos 108, 116 and 124; loops of 24 bars (53.33, 49.66 and 46.45 s); success 16 beats at 124, 7.742 s; billiards bridge 2 bars at 108, 4.444 s, into low at `entryBar` 18.

## Verified, and how

- `mix.py verify`: 0 failures over all six levels. Salon drift is at most 4 ms, wander 3.3 to 5.4 ms, there's no top-end burst at any wrap, and the decode offset is 0.
- `node tool/music/validate.mjs`: PASS.
- Parent MD5 matches the candidate.
- Built with mixrs, one job at a time, peak 164 to 177 MB in a worker. The first salon build (32-bar loop) reported 947 MB.

## What went wrong

- **I wrote the wrong tag set into the first chain run**, putting set B's tags on seed 58001, which is set A. Its parent didn't match the candidate by MD5, and that check caught it. It cost one chain run (60 s GPU) and two single-take checks. Those checks showed that a single run reproduces a batch item, which is useful to know.
- The billiards rebuild also re-encoded low and high: mixrs differs from the committed Python build by about -55 dB. Those four files were restored from git, so only `success` and the new `bridge` change. `report.json` holds the mixrs measurements for them; the decisions are the same.
- The grid error after warping is 17 to 25 ms typical on the salon, higher than the other levels (3 to 17 ms). ALIGN's audit puts attacks 14 to 22 ms ahead of the grid, within perfect. The slow cha-cha's soft attacks may be the reason. That is a guess.
- The key finder says A minor on every tier, against D minor asked. The chord ear says D minor (with Bb chords present). This is the same key-finder weakness noted before.

## Not verified: for the owner's ears

1. Is 58001 a bolero-cha, with violin and flute singing over a cha-cha-chá, elegant and unhurried? Or is it background?
2. Does high's string swell exist?
3. The loop wrap (texture 0.205).
4. Billiards tag into the bridge into the salon: G minor into D minor.
5. Is the ~7% tempo step between tiers noticeable?
6. Does the salon tag's fade sit well under the walk-out?
