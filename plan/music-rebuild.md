# Rebuilding the music for the existing levels

**Plan, 2026-11-06. Stage 2 passed the same day: the owner preferred generated takes to the synth in both rooms, see `plan/music-pilot-2026-11-06.md`. Stages 3 to 6 have not started.** The owner accepted about 3.3 to 6.4 MB of music per level and asked for this plan. Models get free rein over each level's music ("reimplement the concept"), so the current scores don't constrain them. Evidence: `plan/research/local-music-models-2026-11-06.md`, `plan/research/runtime-music-assembly-2026-11-06.md`.

## The idea

Each level gets a ladder of five whole takes, one per tier, each at its own tempo. They switch at phrase boundaries, and the same MusicTransport clock keeps driving charts, judging, autoplay and the dancers. A per-level timing manifest replaces the score's notes. The synth stays only for count-ins, hit cues and fallback, and the current levels stay playable until a rendered level earns its place.

ACE-Step 1.5 XL generates. Exact loops come from a repo-owned post step, since no model promises exact tempo or bar counts: measure beats, reject half-time takes, stretch slightly to the grid, gate, cut, wrap the seam, set loudness, encode.

For the pilot, corrections stay small (under about 1.5%) and use ffmpeg, either `atempo` or plain resampling. `rubberband` is GPL, so whether it can be used is the owner's call; pedalboard is GPL as well and waits for the same decision.

Stems locked across separate generations are out for now: the only measurement found was 20 to 80 ms off.

## What each level needs

| Level | Concept brief for the model | Tempo today | Deliverables |
|---|---|---|---|
| Garden | Warm night cumbia at the mansion gates, inviting, grows from a small band to a full party | 92 to 104 | 5 takes, success stinger, bridge to the bar |
| Bar | Its own identity: cooler, swaggering, indoor, under lanterns. Today it shares the garden's style, and this is the chance to separate them | 100 to 112 | 5 takes, success stinger, bridge to the lawn |
| Pool lawn | Fast, joyful swing for two dancers showing off | 128 to 160 | 5 takes, success stinger |

The briefs are starting points for the owner to change. Prompts use genre and instrument words only, with no artist or song names and no reference recordings. Models under non-commercial licences (YuE2, MusicGen, MuLaCover) stay out, even though YuE2's nodes are in the studio.

## Stages, each with a gate

1. **Host setup (after the restart).** Pin ACE-Step XL weights, install the forge tools.
2. **Style pilot. Done 2026-11-06:** Garden 6 of 12 and lawn 7 of 12 passed timing; the owner ranked generated takes above the synth in both rooms. Results in `plan/music-pilot-2026-11-06.md`. Gate: at least 3 of 12 pass timing, then the owner listens blind against the synth. ACE-Step had been reported weak in jazz, and the lawn winner still won clearly. Stable Audio 3 is not needed for these two styles.
3. **Device truth.** A bare test page with wrapped loops in MP3, AAC and Opus, on a real iPhone, an Android phone and the host browser. The two reports disagree on MP3: one says it works with wrapped loops and a measured offset, the other says to avoid it for loop points. This test settles it.
4. **Ladder test.** Garden only, tiers 0, 2 and 4. Gate: the owner hears one song growing, not three songs. If not, that level uses one tempo with layers cut from a single take.
5. **Runtime prototype.** `MusicScore.fromManifest`, a transport listener, a minimal stem deck and lazy per-level loading, behind a hidden added level. Gate: autoplay runs through it, audio stays within 5 ms of the clock on a phone by loopback, pause and resume land on the right beat, and the handoff has no gap. Check decoded memory (47 to 93 MB).
6. **Rebuild the three levels.** Add stingers and bridges, review charts against the new music, measure keys for any pitched cues, and rewrite `assets/music/LICENSE.md`. Each level ships when the owner approves it.

Stage 5 waits for stage 2, so the runtime isn't built for music that fails the ear test.

## Connected notes

- **Cinematics over the cool-down:** the owner wants transitions playing while the previous level's music fades, so the success stinger and bridge should be written with room for them.
- **Party-up:** the music signal also drives the room waking up, per `plan/owner-rulings-2026-11-05.md`. Keep the tier and intensity signal explicit in the manifest.
- **Adornments:** the progression report may ask for extra layers. Whole takes can't add a layer on their own, so this could need stems cut from one take.

## Storage

- **Candidates and working masters:** `~/.cache/tillandsias-project/kumbia-audio/`, never in the tree.
- **Durable masters:** private R2, with checksums in git. Not LFS. It needs a credential path, which isn't set up.
- **In git:** only approved compressed deliverables and manifests. WAV, FLAC and AIFF are already ignored. Add a size check, because a stray MP3 isn't blocked.
- **Later:** each committed take counts twice on the forge's 1.5 GB tmpfs, once in the tree and once in history, so past about 20 levels the deliverables should move to a public bucket.

## Open decisions for the owner

1. Speed-up per tier, or one tempo per level? The default is per tier, since Level 3's ruling names tempo as part of its challenge.
2. Are the concept briefs above right, especially a distinct style for the bar?
3. Copyright: raw generated audio may not be protected, and others could reuse it. Is human selection and arrangement of takes enough?
4. If the pilot ends up needing Stable Audio 3: it requires registration, and it's capped at $1M yearly revenue. MiniMax Music 3 requires an on-screen credit.
