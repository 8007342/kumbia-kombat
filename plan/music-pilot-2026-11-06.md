# Music pilot results, 2026-11-06

Stage 2 of `plan/music-rebuild.md`. The owner listened blind, and generated takes beat the synth in both rooms, the two style extremes. The bar has not been tried. Nothing here is wired into the game.

## The owner's ranking

Letters are as heard on the blind page. The key is in `tool/music/pilot-20261106/listening-key.json`.

**Garden: C, then B closely, then D, with A out.**

| Heard as | Is | Seed | Rank | Owner's words |
|---|---|---|---|---|
| C | take `0002` | 51002 | 1 | "the best", "the clear better" |
| B | take `0003` | 51003 | 2 | "followed closely by B" |
| D | take `0000` | 51000 | 3 | "some slow interesting progressions but it's too slow and not up to par" |
| A | synth | none | 4 | "clearly the old horrible version" |

**Pool lawn: A >> C > D > B.**

| Heard as | Is | Seed | Rank | Owner's words |
|---|---|---|---|---|
| A | take `0011` | 52011 | 1 | "nice and simple but properly elegant" |
| C | take `0007` | 52007 | 2 | "more adournments but its melody seems simpler most of the time" |
| D | take `0001` | 52001 | 3 | "even simpler" |
| B | synth | none | 4 | "the oldest simplest" |

The owner identified the synth without being told in both rooms, so the test was blind between takes but not really between takes and synth. The verdict against it was clear anyway.

D's "too slow" is a feel. It measures 98.04 BPM, the same as the others, so it is not a tempo error the filter could catch. A musical density check may be worth adding.

## What was heard

- 30-second excerpts, cut from 15 s into each take, at a mean of -18 dB, so nobody has judged intros, endings or how a whole take builds.
- One tempo per room: 98 BPM for the Garden and 144 BPM for the lawn. Tier 2 of the synth matches both. The ladder is stage 4.
- The Garden's synth excerpt is a browser capture that ran about 2% fast, corrected with `atempo`. It may sound slightly worse than the synth in play, though the owner's verdict was not close. The lawn's capture was clean at 144.05 BPM.
- Takes were picked for listening by timing alone, so the other passing takes (3 in the Garden, 4 on the lawn) are unheard.

## How to get the takes back

Workflow: `tool/music/workflows/ace-xl-turbo.api.json`, ACE-Step 1.5 XL turbo, Comfy-Org/ACE-Step-1.5 rev `371bb168`.

| Room | Seeds | Overrides |
|---|---|---|
| Garden | 51000-51011 | `$node:94.tags`: "warm night cumbia at the mansion gates, inviting, instrumental, accordion, guira, congas, bass, gentle brass, grows from a small band to a full party" |
| Pool lawn | 52000-52011 | `$node:94.tags`: "fast joyful swing for two dancers showing off, instrumental, big band, upright bass, brushed drums, trumpet, clarinet, piano"; `$node:94.bpm`: 144; `$node:94.keyscale`: "C major"; `$node:94.duration`: 80; `$node:98.seconds`: 80 |

Copies, most to least durable:

1. **In git:** the top two per room as 128 kb/s Opus, listening copies only, in `tool/music/pilot-20261106/`. Timing and the key are there too.
2. **By regenerating:** seed 51002 was run again and its decoded audio matched exactly (MD5 `75c2d60b907bc15edc5eca0a85cb078e`). The FLAC files differed in 8 bytes, and the audio did not, so compare decoded audio and not file hashes. That is one take on this host and tray build. Another GPU or a changed ComfyUI may not reproduce it.
3. **FLAC masters:** `~/.cache/tillandsias-project/kumbia-audio/pilot-20261106/`, on this machine only. The private R2 bucket in `plan/music-rebuild.md` has no credential path yet.

Master SHA-256:

| Take | SHA-256 |
|---|---|
| Garden seed 51002 | `bd5711a5bc0f81eb4832c69af693fcf1c5b517337c24b9e84cc86ee7e4fe8703` |
| Garden seed 51003 | `4c42aa3dc5cdf93e233aa2fe0689793a2ec565e3bf44c60d7900e4ce3da6bccb` |
| Lawn seed 52011 | `5eea649bdfd9a09a48d715d9beaa092ce1d39820cac4485e65decc40f9640df4` |
| Lawn seed 52007 | `77aedce11fdfd27aa4648ff7a4762b272a89083f52599082cc5de7c6d125a471` |

## Timing filter

`tool/music/measure_takes.py`, with a self-test on synthetic click tracks. 6 of 12 Garden and 7 of 12 lawn takes passed, against a gate of 3. Its limits are starting values, and every take the owner ranked had already passed, so listening has not tested them. The owner's favourite on the lawn, 52011, was only second on timing, so timing shouldn't be used to choose between takes that pass.

`tool/music/build_listening.py` rebuilds the blind page into `build/web/listen/` and reshuffles the letters. Three things gave the synth away on the first builds, and the script now prevents them: a different length, the player's `0:29` readout, and the buffered bar, which shows a smaller file.

## How the synth was captured

The score room has no offline render. The capture page, a temporary copy of `tool/music/preview.html` that wasn't kept, routed every connection to the audio destination into a `MediaStreamDestination` and `MediaRecorder`, so nothing reached the speakers, then used `kumbiaMusic.tier(2)` and started recording after the tier changed. An AudioWorklet tap was also tried, to rule out the encoder.

## Open question: Garden audio shortfall

In a visible window, Web Audio rendered 44.26 s of `garden_mojo` in 45 s of wall clock, and `MediaRecorder` gave 44.16 s of 45.07 s. The transport itself kept time, at 73.5 beats in 45 s. `pool_swing` didn't show it. The cause isn't traced, and whether it happens in the game isn't known. It matters less if the rendered music replaces the synth, but the synth stays for count-ins, hit cues and fallback.

Measured in the game the same day: the AudioContext clock tracked wall time over 122 s of Garden on autoplay into the bar, ratio 1.0001, worst one-second gap 13 ms, muted through a zero gain. So the game shows no drift by that measure on this host. That doesn't rule out dropped audio, and it doesn't explain the capture shortfall, which may come from the capture itself. Phones are untested.

## Next

Stage 3 in `plan/music-rebuild.md`: wrapped loops in MP3, AAC and Opus on a real iPhone, an Android phone and the host browser. That needs the owner's devices. The owner hasn't yet said whether these winners are the final takes or only prove the style.
