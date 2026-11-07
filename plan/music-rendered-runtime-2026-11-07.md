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

Desktop Chromium through the preview, audio routed through a zero gain, Opus unless stated. These runs used build `041ba62`, before the richer charts and the rule that a tier always runs at its own tempo. That rule only changes what happens when a take isn't ready, and it has fake-clock tests but no browser run of its own. The forced-failure row below predates it.

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

No chart was changed for the rendered music, because nothing showed one landing off the beat grid. The lawn and the bar now carry the doubles agent's richer patterns. A test checks them against their fairness limits at the tempos the manifest gives each tier, so a change to the tier mapping fails that test.

Garden's plain chart has no limits of its own. It has one same-limb gap of 326 ms at 92 BPM in its first tier, which would miss the 400 ms limit the lawn and bar use. That tempo and chart are unchanged from the synth, so this isn't new. It's noted for the owner in case it feels cramped.

Weak spots, measured per tier on the take that tier plays. These are positions where the music usually has no clear attack. The numbers compare attack strength with that take's median sixteenth, then how often the position beats that median. Garden has none at this threshold:

| Level, tier, take | Chart beats | Strength, share |
|---|---|---|
| Lawn 2, high | 0, 1, 3, 4, 5 | 0.79, 31% |
| Lawn 3, high | 1, 3, 4, 5, 6, 7 | 0.79, 31% |
| Lawn 4, low | 1.75, 3.75, 5.75 (first peak pattern only), 6.75 | 0.76, 30% |
| Bar 0, low | 0.5, 4.5 | 0.78, 27% |
| Bar 1, low | 0.5, 1.5, 2.5, 5.5 | 0.78, 27% |
| Bar 2, mid | 3.75 | 0.72, 18% |
| Bar 3, mid | 1.75, 3.75 | 0.72, 18% |
| Bar 4, high | 2.25, 5.25, 6.25 or 7.25, by peak pattern | 0.86, 31% |

This is only about attacks, and it looks at a note's place within the beat across the whole take, so it can't say whether a note feels right. On the lawn's high take the weak spots are the whole beats themselves. The mixing agent's `bar1Confidence` is low on garden low (0.21), bar mid (0.26) and bar high (0.0), so on those takes a chart's first beat may not be the bar's downbeat.

## How it works

- The lawn's order, 144, 160, 136, comes from `tierTakes` in the manifest, and nothing assumes tempo rises.
- A tier change starts on a phrase boundary. The clock takes the destination's tempo at the transition's first beat, and with 8-beat transitions the tempo doesn't change during a response.
- A tier always runs at its own tempo, because its chart is only fair there. The lawn's richest tier is safe at 136 and breaks its limits at 160 (281 ms against a 330 ms floor). So a take that isn't decoded means the synth at that tier's tempo, and the take joins at a later boundary if it arrives. If the manifest itself can't be read, the synth runs on its old tempos, which would put that tier at 160. That needs a damaged build, since the manifest ships with the game.
- The old room's decoded audio is released when the next room takes over. Only the next room's first take and the exit are decoded early.

## What went wrong

- **My bug, found on the first browser run.** A decode future waited for itself. Decoding stalled after two clips, the first beat came 6 s late, and Garden could never exit. That broken build was on the preview for a short time, and the coordinator was told. It was fixed in `041ba62`. The logic now sits in plain Dart with a test, because the fake backends never ran that web code. Every decode now has a time limit, and exit audio decodes first.
- **Two of my drift measurements were wrong and were thrown away.** One mixed two audio taps in one array, the other mapped array position to time after dropping entries. The table has the corrected measurement.
- **A false alarm.** My ffmpeg mono downmix showed peaks above 1.0. In the browser, per channel, no file passes 0.95.
- `rsync` isn't installed, and a server inside the forge can't be reached from the browser. So a click-track fixture couldn't be measured in a browser, and the checks ran on the real music through the preview.

- **I ran commands in the main checkout by accident.** My worktree had been removed after a merge, a `cd` failed, and the rest of the command ran there. That included a `flutter build web`, which replaced the preview's game with a build of `game` at `2847be5`. `listen` survived and nothing was committed. It also lost an uncommitted fix, which is now redone. Commands now stop if the `cd` fails.

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
