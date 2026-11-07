# Rendered music in the game: runtime results, 2026-11-07

**The game now plays the rendered music in all three levels, on branch `work/1855-rend`. A flawless run reached the end screen in a real desktop browser, muted, with no errors. Nobody has heard it, and it hasn't been on a phone.** This covers `plan/music-rebuild.md` stages 5 and 6.

## What the owner should check by ear

These can't be judged from measurements:

- Whether the music and the transitions sound right.
- **The mix.** All levels start at 0 dB. Open the game with `?mixer=1`, set the sliders by ear, and press Copy JSON. The JSON matches the manifest's `mix` and each take's `gainDb`.
- **Accents over the music.** Output peaked at 0.997 of full scale (first channel) in both full runs that recorded it, so there's almost no headroom. The loudest file peaks at 0.95, so the rest probably comes from cues landing on top. Nothing passed 1.0, but a slightly lower master may be wanted. I didn't change it, because that's a mixing choice. The mixing agent proposes `masterDb` -1.5, which keeps the balance of music and cues, takes that peak to about 0.84, and needs no re-render. It can be tried live on the Master slider. This is the owner's decision.
- **Sound rewards.** The answers to moves are still synth notes written in the old scores' keys. They may clash with the takes: keys weren't measured.
- **Loop seams.** No live wrap has been heard. The mixing agent compared each wrap with the same music played straight through: in Opus the two largest steps I flagged measure as real attacks (`bar/high` 0.218 looped, 0.193 straight through), using ffmpeg's decoder, not a browser's. In AAC some wraps do add a step, such as `garden/low` at 0.074 against 0.016, so listen for this in quiet passages, in both formats if possible.
- **Which seams can be heard.** This is my estimate from the level rules, not a test. Low takes are easy: keep missing on the first two tiers. Middle takes are reachable by passing and missing in turn. Garden's top take wraps about 14 s after it starts, so it's reachable, though a flawless run leaves just as it arrives. The lawn's top take (about 21 s to its seam, about 18 s possible) and the bar's (about 47 s, about 21 s possible) look out of reach in normal play, so those two seams shouldn't normally play at all.

## What was measured

Desktop Chromium through the preview, audio routed through a zero gain, Opus unless stated.

| Check | Result |
|---|---|
| Flawless run, all three levels | Reached the `MUY SUAVE` / `OTRA VUELTA` end screen, 03/05. Two full runs, one with `?mixer=1`, one without. No errors and no failed clips |
| Audio against its schedule | Lag 0 in 38 of 40 windows, one 2.9 ms step off in the other 2, with no trend over 253 s. Resolution is 2.9 ms, so this can't show anything smaller |
| Beat clock against file position | Largest difference 0.08 ms, over 478 samples |
| Native looping, 3 takes, 5 loops each | 0 samples of lag (offline render at 44.1 kHz) |
| Transition landings | All offsets matched `entryBar` in the start log. Each started at the planned time |
| Frames in play | Median 17.4 ms, 99th percentile 18.8 ms, median 58 fps, lowest second 54 |
| Long frames in play | 101 ms and 85 ms, about 0.8 s after each new room's music starts. None at a contact. Music is on the audio clock, so these don't move it, but a dancer could visibly skip. Cause not investigated |
| Pause and resume, on AAC | Music restarted at the replay beat, within 0.02 ms of the clock |
| AAC path, Garden only | Decoded and played. Opus was refused to force this. AAC lag wasn't cross-correlated |
| Forced decode failure | 21 clips failed. Garden cleared on the synth at 92, 98, 104 BPM, and the run went on into the lawn at 144. It was stopped there, not run to the end |
| Without `?mixer=1` | No mixer on the cover or the end screen, seen in screenshots. A page test also finds none once a run has started |
| Tests | 535 pass. `flutter analyze` shows the 4 baseline notes |

**Decoded memory, measured by the game's own count at 44.1 kHz:** Garden 90.3 MB, lawn 82.6 MB, bar 67.1 MB. Each includes what's held for the next room's start. Add up to 10.7 MB of compressed audio. At 48 kHz, expect about 9% more. Total browser memory wasn't measured.

**Download:** 3.1 to 4.0 MB per level per format, under the 8 MB budget. Decodes took up to 0.5 s each on this desktop.

## Charts

Charts are unchanged: nothing showed them landing off the beat grid. At the takes' tempos the closest same-limb gaps stay at or above 326 ms, and the lawn's stay at or above 729 ms.

Weak spots, where the music usually has no clear attack on the note's position in the beat. These compare attack strength with that take's median sixteenth, and show how often the spot beats that median:

| Take | Chart notes | Strength, share |
|---|---|---|
| bar mid | 6.75 | 0.72, 18% |
| bar low | 0.5, 4.5 | 0.78, 27% |
| lawn low (peak tier) | 1.75, 5.75, 6.75 | 0.76, 30% |
| lawn high | 0, 1, 3, 4, 5 | 0.79, 31% |
| bar high | 2.25, 5.25 | 0.86, 31% |

This is only about attacks. It looks at a note's place within the beat, across the whole take. It can't say whether a note feels right. The mixing agent's `bar1Confidence` is low on garden low (0.21), bar mid (0.26) and bar high (0.0), so on those takes a chart's first beat may not be the bar's downbeat.

## How it works

- The lawn's order, 144, 160, 136, comes from `tierTakes` in the manifest, and nothing assumes tempo rises.
- A tier change starts on a phrase boundary. The clock takes the destination's tempo at the transition's first beat, and with 8-beat transitions the tempo doesn't change during a response.
- A take that isn't decoded holds the tier change until it's ready. If nothing is decoded, the synth plays at the takes' tempos, so chart times don't move.
- The old room's decoded audio is released when the next room takes over. Only the next room's first take and the exit are decoded early.

## What went wrong

- **My bug, found on the first browser run.** A decode future waited for itself. Decoding stalled after two clips, the first beat came 6 s late, and Garden could never exit. That broken build was on the preview for a short time, and the coordinator was told. It was fixed in `041ba62`. The logic now sits in plain Dart with a test, because the fake backends never ran that web code. Every decode now has a time limit, and exit audio decodes first.
- **Two of my drift measurements were wrong and were thrown away.** One mixed two audio taps in one array, the other mapped array position to time after dropping entries. The table has the corrected measurement.
- **A false alarm.** My ffmpeg mono downmix showed peaks above 1.0. In the browser, per channel, no file passes 0.95.
- `rsync` isn't installed, and a server inside the forge can't be reached from the browser. So a click-track fixture couldn't be measured in a browser, and the checks ran on the real music through the preview.

## Not checked

- **Real phones**, which is stage 3. Instructions are below.
- **The 5 ms gate from stage 5.** That needs a loopback cable on a phone.
- **Hidden tab and mute on screen.** Pausing goes through the same path as the pause tested above, and the lifecycle tests pass, but nobody hid a tab in this run.
- **The resume fade's actual gain curve.** Tests check that the fade is asked for at the right time. The browser's gain values weren't read.
- **A real loop seam during live play.** Flawless autoplay leaves each take before it loops. Looping was measured offline.
- **`assets/music/LICENSE.md`**, which stage 6 says to rewrite. Not touched.

## For the owner: testing on phones

The preview address only works on the host computer, so a phone needs a deployed copy. Ask the coordinator for that address. Do this on an iPhone and on an Android phone, with the sound on.

1. Open the address with `?mixer=1` on the end. A panel of sliders appears, with a line of small text under them.
2. Press `ENTRA AL RITMO` and play. Press Hide if the panel is in the way.
3. **Is it the real music?** The small text should say `clip=garden/low` and `failed=0`. If it says `clip=synth` or `failed` is above 0, write that down: the phone couldn't play the file.
4. **Does it stay in time?** Tap along for a few minutes. Say if the music and the rings slowly come apart. This is the most important question.
5. **Do the joins work?** Listen when the music changes as you do well, and when you miss enough to drop a tier. Note any gap, doubled beat or click.
6. **Does a loop hold?** The easiest test is the garden's first music: keep missing on purpose for over a minute, and listen for a click or jump about 63 s after it starts. The small text shows `clip=garden/low` while you're on it. Then try the middle music, `clip=garden/mid`, by passing and missing in turn. You can't test this on autoplay, because it moves on before the music loops. Do this on both phones if you can, since they may decode different formats.
7. **Pause.** Press pause, wait, resume. It should come back in time with the count-in.
8. **Leave and return.** Lock the phone or switch apps during play, then come back. The music should stop while you're away, and the run should still be there.
9. **Does it survive?** Play through all three levels. If the page reloads by itself or the sound dies, write down which level. That would point to memory.
10. Send me the model of each phone and what happened. A screenshot of the small text helps.
