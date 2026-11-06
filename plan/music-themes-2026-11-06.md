# Music themes round, 2026-11-06

The next round after the pilot in `plan/music-pilot-2026-11-06.md`: first takes for the bar and the indoor party, the ladder test (stage 4 of `plan/music-rebuild.md`) for the Garden and the lawn, and a look at delivery formats. Nothing here is in the game or its assets. **Nobody has heard any of this yet.** No passing or measured number below says whether the music is good.

Level order is now garden, pool lawn, bar, indoor party.

## Results

| Batch | Takes | Full timing filter | Note |
|---|---|---|---|
| Bar, 106 BPM | 12 | **7 of 12** | |
| Indoor party, 124 BPM | 12 | **8 of 12** | |
| Ladder, Garden | 3 | **2 of 3**; tempo alone 3 of 3 | The mid take fails as half-time (0.86) |
| Ladder, lawn | 3 | **2 of 3**; tempo alone 2 of 3 | The high take fails on tempo, -4.07% |

No limit in `tool/music/measure_takes.py` was changed, and its self-test passes. For a ladder take, only tempo error needs to pass; the full result is reported as well.

### Ladder timing

| Ladder | Tier | Asked | Measured | Error | Half-time | Wander | Full filter |
|---|---|---|---|---|---|---|---|
| Garden | low | 92 | 92.50 | +0.55% | 0.12 | 25.1 ms | Pass |
| Garden | mid | 98 | 98.04 | +0.05% | **0.86** | 20.1 ms | Fail: half-time |
| Garden | high | 104 | 104.06 | +0.06% | 0.26 | 22.4 ms | Pass |
| Lawn | low | 128 | 128.01 | +0.01% | 0.32 | 13.1 ms | Pass |
| Lawn | mid | 144 | 143.92 | -0.05% | 0.32 | 14.4 ms | Pass |
| Lawn | high | 160 | **153.49** | **-4.07%** | 0.08 | 8.6 ms | Fail: tempo |

The lawn's high take missed by more than the 1.5% the pilot allows itself to correct, so it can't be stretched to 160 under the current rule. It stays on the page because the ladder question is about whether the takes sound like one song, and the page shows the measured tempo.

Per-take numbers are in `tool/music/themes-20261106/*.timing.json`.

## Settings to regenerate

Workflow: `tool/music/workflows/ace-xl-turbo.api.json`, ACE-Step 1.5 XL turbo, unchanged. Everything not listed keeps the workflow's value. `seed` reaches nodes 3 and 94. `$node:94.duration` and `$node:98.seconds` are always equal. All overrides were read back from ComfyUI `/history` for the first takes of the bar batch, the end of the party batch and all six ladder takes.

| Batch | Seeds | BPM | Key | Bars | Seconds | `$node:94.tags` |
|---|---|---|---|---|---|---|
| Bar | 55000-55011 | 106 | C minor | 38 | 86.04 | cool swaggering indoor cumbia under lanterns, instrumental, electric keys, twangy electric guitar, rounded bass, tight congas, guira, muted trumpet |
| Indoor party | 53000-53011 | 124 | D minor | 44 | 85.16 | cool midnight Latin boogaloo with a salsa-disco lift for a circle of dancers, instrumental, walking upright bass, piano montuno, congas, timbales, cowbell, handclaps on the backbeat, marimba call and flute answer, muted brass |
| Garden low | 51002 | 92 | A minor | 34 | 88.7 | warm night cumbia at the mansion gates, inviting, instrumental, small band, accordion, guira, soft congas, bass |
| Garden mid | 51002 | 98 | A minor | 36 | 88.16 | warm night cumbia at the mansion gates, inviting, instrumental, accordion, guira, congas, bass, gentle brass, grows from a small band to a full party |
| Garden high | 51002 | 104 | A minor | 38 | 87.69 | warm night cumbia at the mansion gates, inviting, instrumental, full party, accordion, guira, congas, bass, full brass, timbales, handclaps |
| Lawn low | 52011 | 128 | C major | 44 | 82.5 | fast joyful swing for two dancers showing off, instrumental, small combo, upright bass, brushed drums, clarinet, piano |
| Lawn mid | 52011 | 144 | C major | 48 | 80 | fast joyful swing for two dancers showing off, instrumental, big band, upright bass, brushed drums, trumpet, clarinet, piano |
| Lawn high | 52011 | 160 | C major | 54 | 81 | fast joyful swing for two dancers showing off, instrumental, full big band, upright bass, full drums, trumpets, trombones, saxophones, clarinet, piano, handclaps |

Choices made here:

- **Bar key and tags.** C minor is the root and mode of today's `bar_swag` score. The tags keep the word cumbia and try to separate the bar from the Garden by instruments alone: electric keys, electric guitar and muted trumpet, no accordion. They name no separate genre, so the separation is an untested hope. "Cool, swaggering, indoor, under lanterns" are the plan's mood and scene words, not genre or instrument words, and the model may or may not respond to them. The Garden's pilot tags do the same.
- **Indoor party.** Seeds, tags and key come from section 3.6 of `plan/levels/next-level-plan.md`, tier 2. The plan says 40 bars (77.42 s); this round used 44 bars to reach the 80-90 s asked for.
- **Ladder durations.** Even bar counts, chosen to keep the seconds close within a ladder.
- **Ladder mid tiers** use the winners' tags word for word, including the Garden phrase "grows from a small band to a full party".

## Caveats for the ladder test

- **The lawn's mid take is the pilot winner.** Its decoded audio matches seed 52011 exactly (MD5 `44c107ed8aab1a962ca2cd0ebc47f02a`), a second reproduction on this host after 51002.
- **The Garden's mid take is not the pilot winner.** The winner ran 88.2 s, which is not quite 36 bars; 88.16 s is. That 0.04 s changed the audio (MD5 `9e626f6675ccce4ac63e7aac37de78fe` against `75c2d60b907bc15edc5eca0a85cb078e`), with a sample correlation of 0.15. Correlation can't say how different it sounds, but the owner has not ranked this take, and it fails as half-time where the winner passed.
- **So a shared seed may hold little across rungs.** Tempo, duration and tags all change the result, and the Garden shows even a tiny duration change does. Only ears can say whether the three takes share a song.
- **Excerpts are loudness matched,** so any growth in level between tiers has been removed on purpose. Bar counts in an excerpt differ with tempo, and each tier starts at 15 s, which isn't a musically matched point.

## Other caveats

- Takes on the page were picked by timing alone: bar seeds 55004, 55005, 55008, 55011 and party seeds 53001, 53002, 53009, 53010. The pilot showed timing rank doesn't predict the owner's choice, so 3 passing bar takes and 4 passing party takes are unheard.
- Only 30-second excerpts from 15 s in are offered, so intros, endings and whole-take builds remain unjudged.
- Takes bunch above the target: 8 of 12 party takes measure 124.8 to 125.1, and 4 of 12 bar takes about 107. Whether this is the model or the filter isn't known, and a correction step would handle either.
- Keys are requests, and none has been measured.
- Same host and tray build only. Another GPU or ComfyUI may not reproduce a take.

## Listening page

`python3 -I tool/music/build_listening.py --page themes <run dir> build/web/listen`, then https://www.kumbia-kombat.localhost:18443/listen/index.html. Bar and indoor party have four shuffled letters each, 30 s, with no synth. The ladders are not blind, 40 s from 15 s in, with a "Play in order" button. All excerpts are FLAC, equal length, within 0.2 dB of each other in mean level.

Tested in a headless browser, which has no speakers: all 14 files load, the answer key returns 404, and "Play in order" steps low, mid, high and resets. No one has checked what comes out of a speaker.

**Restoring it after another session rebuilds `build/web`:**

```bash
mkdir -p build/web/listen && cp -a ~/.cache/tillandsias-project/kumbia-audio/themes-20261106/listen-built/. build/web/listen/
```

Don't rerun the builder to restore: it reshuffles the letters and overwrites the key. The key is at `~/.cache/tillandsias-project/kumbia-audio/themes-20261106/listening-key.json`, and only there.

## Delivery formats

Encoded from the pilot's top two per room (Garden 51002, 51003; lawn 52011, 52007), which is how "the four winners" was read. Results are in `tool/music/themes-20261106/format-results.json`. The encoder was ffmpeg 9.0.2, with `libopus` VBR, the native `aac` in m4a, and `libmp3lame -q:a 4`. MP3 is included because the research report recommends it.

| Format | Average rate, Garden / lawn | Per take, Garden / lawn | Top of spectrum, kHz |
|---|---|---|---|
| Opus 128 | 147 / 141 kb/s | 1.62 / 1.41 MB | 19.1-20.5 |
| Opus 160 | 182 / 175 kb/s | 2.01 / 1.75 MB | 19.4-20.5 |
| AAC 128 | 133 / 131 kb/s | 1.47 / 1.31 MB | 16.7-18.1 |
| AAC 160 | 166 / 164 kb/s | 1.83 / 1.64 MB | 16.7-18.1 |
| MP3 V4 | 175 / 158 kb/s | 1.93 / 1.58 MB | 15.9-17.5 |

Masters measure 19.4 to 24 kHz by the same crude test: the highest frequency within 70 dB of the loudest in the long-term spectrum. That says nothing about how a codec sounds.

Projected MB per level for five tiers plus two 70 KB extras. The tempos are 92-104 and 128-160, evenly spaced, at the measured rates. **Budget 3.3 to 6.4 MB; the research's ceiling is 8 MB.**

| Format | Garden 16 bars | 24 | 32 | 5 whole takes | Lawn 16 bars | 24 | 32 | 5 whole takes |
|---|---|---|---|---|---|---|---|---|
| Opus 128 | 3.7 | 5.5 | 7.3 | 8.2 | 2.5 | 3.7 | 4.9 | 7.2 |
| Opus 160 | 4.6 | 6.8 | 9.1 | 10.2 | 3.1 | 4.6 | 6.0 | 8.9 |
| AAC 128 | 3.4 | 5.0 | 6.7 | 7.5 | 2.3 | 3.4 | 4.5 | 6.7 |
| AAC 160 | 4.2 | 6.2 | 8.3 | 9.3 | 2.9 | 4.3 | 5.6 | 8.3 |
| MP3 V4 | 4.4 | 6.6 | 8.7 | 9.8 | 2.8 | 4.1 | 5.4 | 8.0 |

What this shows:

- **Whole takes of about 85 s do not fit the budget in any format.** The budget assumes loops of 16 to 32 bars.
- **Real music runs above the research's 128 kb/s planning rate,** at 131 to 182 kb/s. MP3 V4 came to 158 to 175 kb/s here, against the near-equal size to Opus 96 the research saw on sparse stand-ins.
- **A slow level pays more for the same bars.** Garden 32 bars exceeds 6.4 MB in every format, while the lawn at 32 bars fits in all of them.

**Recommendation, pending stage 3 and the owner's ears:** plan on Opus 128 where it plays, with AAC 128 as the other candidate, and loops of about 24 bars on slow levels and up to 32 on fast ones. Opus 128 keeps the most top end per byte of these, by the crude test. Opus 160 and AAC 160 cost about 25% more and leave slow levels with 16-24 bars at most. Whether 128 is "high definition" enough needs a listening comparison on good speakers against the FLAC; these numbers can't answer it. The encodes are in `~/.cache/tillandsias-project/kumbia-audio/themes-20261106/formats/`.

### What stage 3 must settle

Nothing has been decided, and this needs phones nobody has yet:

1. Whether Opus plays at all on a current iPhone, and in which container (Ogg, WebM, MP4). The research found failures and contradictions, none current. If it doesn't, the choice falls to AAC, MP3 or two formats.
2. Whether AAC m4a loops without a gap on WebKit. The research has one report of 208 extra samples, and ffmpeg's decoder reporting 0 extra samples here says nothing about a browser.
3. Whether MP3 works with wrapped loops, the disagreement the plan already names.
4. Decode time and held memory on a real phone at 24 and 32 bars.
5. Whether a phone speaker or earphones reveal any difference between 128 and 160 at all.

## Storage

`~/.cache/tillandsias-project/kumbia-audio/themes-20261106/`, on this machine only, 374 MB: `bar/`, `party/`, `ladder-garden/`, `ladder-lawn/` (FLAC, provenance and timing), `formats/`, `listen-built/`, `listening-key.json`, `SHA256SUMS`. A copy of the checksums is in `tool/music/themes-20261106/`. No FLAC is in the tree except the page's excerpts under the ignored `build/web/listen/`.

## What the owner needs to judge

1. Bar and indoor party: rank the letters. Is either good enough to carry on with, and does the bar sound like its own room rather than the Garden?
2. Each ladder: one song growing, or three songs? The gate in stage 4 applies. If the answer is three songs, that level moves to one tempo with layers cut from a single take.
3. Is the lawn's high tier usable as it is, given it runs at 153.5 rather than 160?
4. The Garden's mid tier isn't the winner. If it weakens the ladder, the winner itself could stand in at 88.2 s, slightly off a whole bar count.

## Lawn ladder, second try

The owner's verdict on the first ladders. Garden: "great, transitions are not clean but the music increases progressively in complexity, it feels like a livelier version." Lawn: "does not follow this pattern, the low section is livelier than mid at some points", and "the high section is higher but barely, the low composition is still much richer". The Garden stays as it is. The lawn's mid take, seed 52011, is the fixed centre: "nice and simple but properly elegant".

**Chosen for the owner's ears: low seed 52015, high seed 52012.** Neither has been heard. The first lawn ladder stays on the page for comparison.

### Settings

Same workflow, key C major. Mid is unchanged (see above). Overrides were read back from ComfyUI `/history`.

| Tier | Seeds | BPM | Bars | Seconds | `$node:94.tags` |
|---|---|---|---|---|---|
| Low | 52011-52016 | 128 | 44 | 82.5 | fast joyful swing for two dancers showing off, instrumental, sparse small trio, upright bass, brushed snare, solo clarinet, lots of space, few notes |
| High | 52011-52016 | 160 | 54 | 81 | fast joyful swing for two dancers showing off, instrumental, full big band, brass section shouts, busy drums, walking upright bass, trumpets, trombones, saxophones, clarinet, piano |

### Timing

| Tier | Full filter | Within the 1.5% tempo limit |
|---|---|---|
| Low | 5 of 6 (52013 wanders 47 ms) | 6 of 6 |
| High | **0 of 6** | **1 of 6** |

High measured 163.02, 161.55, 154.08, 169.24, 150.23 and 148.95 BPM for seeds 52011 to 52016. Only 52012 is within the limit, at +0.97%. It still fails the full filter: its beat wanders 61 ms against a 35 ms limit. That is enough for this ear test but **not for play**, where charts need a steady beat. No limit was changed. The model drifted further at 160 with these tags than at the other tempos, and more seeds may be needed for a usable high tier.

### Measures

From `tool/music/ladder_measures.py`, which has a self-test. "Heard" is the 40 s from 15 s in. Onsets per beat is the fair comparison across tempos, since onsets per second rise with tempo alone.

| Take | Onsets/beat heard (whole) | Onsets/s heard | Spread Hz heard (whole) | Centroid Hz heard | Level dB heard | Level range dB heard (whole) |
|---|---|---|---|---|---|---|
| Old low, 52011 at 128 | 1.83 (1.76) | 3.90 | 577 (619) | 380 | -16.0 | 9.3 (11.4) |
| **New low, 52015** | **1.20 (1.13)** | 2.55 | **432 (392)** | 342 | -17.1 | 13.8 (16.4) |
| Mid, 52011 at 144 | 1.43 (1.37) | 3.42 | 746 (721) | 605 | -14.3 | 6.6 (10.1) |
| **New high, 52012** | **1.57 (1.47)** | 4.17 | **1067 (1009)** | 792 | -14.7 | 14.2 (15.7) |
| Old high, 52011 at 160 | 1.81 (1.76) | 4.83 | 746 (768) | 652 | -14.5 | 6.9 (8.9) |

Against mid, heard window: new low is -16% in onsets per beat and -42% in spread. New high is +10% and +43%. Over the whole take, new low is -17% and -46%, and new high is +7% and +40%.

- **The old ladder fits the owner's words on some of this.** Old low has more onsets per beat than mid, and old high has the same heard spread as mid. That is one comparison after the fact, not validation. It also runs the other way in places: old high has more onsets per beat than mid and the owner still called it barely higher, and old low has less spread than mid and was still called richer.
- **The high pair is thin on onsets.** +10% and +7% is a small margin, and new high has fewer onsets per beat than the old high, which the owner found barely higher. Its gain is in spread and centroid. New high also isn't louder than mid.
- **Level range doesn't rank these.** Both new takes show more range than mid. It may mean gaps, dynamics or something else, so it wasn't used to choose.

### How they were picked

A low had to be below mid on onsets per beat and spread, in both windows, and pass the full timing filter. Seeds 52012, 52014, 52015 and 52016 qualified. 52015 has the steadiest beat (2.8 ms) and sits below mid on level as well. 52014 goes furthest (1.10 onsets per beat, 267 Hz) and is the alternate if 52015 isn't sparse enough. Same-seed low 52011 was disqualified: it measures 1.86 onsets per beat even with the sparse tags.

A high had to be within the tempo limit and above mid on onsets per beat and spread. Only 52012 qualified. The margins were judged by eye after seeing the numbers, not set in advance.

### Caveats

- **The tiers no longer share a seed** (52015, 52011, 52012). The Garden ladder the owner liked did. The same-seed options failed here, low on density and high on tempo (+1.89%). Whether these three read as one song is exactly what the owner needs to judge, and the numbers can't say.
- These measures count events and energy. They can't hear musical richness, which is the word the owner used.
- Only keys requested, none measured. Six seeds per tier is a small sample.
- The owner's "transitions are not clean" on the Garden hasn't been addressed. These excerpts are separate takes played in sequence, and the handoff belongs to runtime stage 5.

### Page

The section was added with `python3 -I tool/music/build_listening.py --add-ladder ladder-lawn-2 <run dir> <served dir>`, which changes nothing else. Checked by hash: the bar and party files and the answer key are unchanged, and the only difference in `index.html` is the added section. `build/web/listen/` and `listen-built/` in the cache are identical, so the restore command above still applies. An open page needs a reload to show it; the letters stay the same.

Takes are in `~/.cache/tillandsias-project/kumbia-audio/themes-20261106/ladder-lawn-2/`. Timing and measures are in `tool/music/themes-20261106/`.

## Ladders for the bar and party winners

The owner's blind winners are fixed as the mid tiers: bar seed 55005, party seed 53010. Their reasons: "B is lively and identifiable", while the rest were "awesome but too simple, they're plain background scores"; "A is richer and full of charisma and personality". The Garden ladder's verdict stands as the pattern to match: "the music increases progressively in complexity". **Nobody has heard these outer tiers.**

**Chosen for the owner's ears: bar low 55005, high 55007; party low 53014, high 53010.** The party's high tier **does not meet the filter**: see below.

### Settings

Same workflow. Mids are copies of the winners, not new runs, so decoded audio is the same by construction (MD5 `51795bc1f7485fd36016d40defa97eb7` bar, `0bdbdca0ba63d901aea19b980484b4ef` party, each checked against the winner). Their settings are in the first table above. Tags, BPM, key, duration, seconds and both seed nodes were read back from ComfyUI `/history` for all 30 new takes. Words are genre and instrument terms, with no artist or song names. "Lively, identifiable" went in the high tags only, and low got "characterful", since the lawn's low tier failed by being too lively.

| Ladder, tier | Seeds | BPM | Key | Bars | Seconds | `$node:94.tags` |
|---|---|---|---|---|---|---|
| Bar low | 55005-55010 | 100 | C minor | 36 | 86.4 | cool swaggering indoor cumbia under lanterns, instrumental, sparse small trio, characterful lead melody on twangy electric guitar, rounded bass, soft congas, guira, lots of space, few notes |
| Bar high | 55005-55010 | 112 | C minor | 40 | 85.71 | cool swaggering indoor cumbia under lanterns, instrumental, full band, lively identifiable lead melody on twangy electric guitar and muted trumpet, brass section answers, electric keys, walking rounded bass, busy congas, timbales, guira, handclaps |
| Party low | 53010-53015 | 112 | D minor | 40 | 85.71 | cool midnight Latin boogaloo for a circle of dancers, instrumental, sparse small combo, characterful flute lead melody, upright bass, soft congas, lots of space, few notes |
| Party high | 53010-53015 | 136 | D minor | 48 | 84.71 | cool midnight Latin boogaloo with a salsa-disco lift for a circle of dancers, instrumental, full salsa orchestra, lively identifiable lead melody on marimba and flute, brass section shouts, trumpets, trombones, saxophones, walking upright bass, piano montuno, congas, timbales, cowbell, handclaps on the backbeat |
| Lawn high, third try | 52017-52022 | 160 | C major | 54 | 81 | second-try high tags, word for word |

### Results

| Batch | Full filter | Within tempo limit | Full filter and on the right side of mid |
|---|---|---|---|
| Bar low | 3 of 6 | 6 of 6 | 1: 55005 |
| Bar high | 4 of 6 | 5 of 6 | 2: 55007, 55009 |
| Party low | 3 of 6 | 5 of 6 | 3: 53012, 53014, 53015 |
| Party high | 5 of 6 | 6 of 6 | **0** |
| Lawn high, third try | **2 of 6** | 2 of 6 | 2 (see below) |

"Right side" means below or above mid on onsets per beat and spread, heard and whole, the same test as the lawn's second try. No limit was changed, and both self-tests pass.

| Take | Measured BPM | Error | Half-time | Wander | Onsets/beat heard (whole) | Spread Hz heard (whole) | Centroid Hz heard | Level dB heard |
|---|---|---|---|---|---|---|---|---|
| Bar low, 55005 | 100.02 | +0.02% | 0.21 | 6.8 ms | 1.80 (1.97) | 406 (452) | 388 | -15.0 |
| **Bar mid, 55005** | 106.03 | +0.03% | 0.10 | 23.7 ms | 2.59 (2.49) | 643 (568) | 553 | -15.2 |
| Bar high, 55007 | 110.97 | -0.92% | 0.12 | 12.3 ms | 2.96 (2.77) | 995 (952) | 883 | -19.2 |
| Party low, 53014 | 110.75 | -1.11% | 0.12 | 13.8 ms | 1.97 (1.85) | 336 (363) | 308 | -16.8 |
| **Party mid, 53010** | 124.99 | +0.80% | 0.23 | 7.2 ms | 3.06 (2.88) | 552 (637) | 417 | -14.5 |
| Party high, 53010 | 135.99 | -0.01% | 0.48 | 23.4 ms | **2.66 (2.56)** | 821 (768) | 778 | -15.5 |

Against mid, heard (whole): bar low -31% (-21%) onsets, -37% (-20%) spread. Bar high +14% (+11%), +55% (+68%). Party low -36% (-36%), -39% (-43%). Party high **-13% (-11%)** onsets, +49% (+21%) spread.

- **The party winner is already dense, and no high take beat it on onsets.** The best of six was 2.68 per beat against 3.06, and the same holds per second (53015 at 6.08, mid at 6.33). 53010 was put on the page as the closest take with a clear lift in spread and centroid, and because it shares the winner's seed. That is a failed filter and a judgment call. More seeds or fuller tags may not help, since the mid may simply be near what this model does at this density.
- **Bar high is quiet before matching:** -19.2 dB against mid's -15.2, and the page matches level anyway. It also runs 1 BPM under what was asked, like much of the bar. 55009 is the alternate: +5% onsets, +43% spread, -17.1 dB.
- **Party low alternates:** 53015 has the steadiest beat (5.6 ms) but a smaller spread drop (-7% heard, -17% whole). 53012 sits at -21.5 dB. Same-seed 53010 failed, half-time at 0.83 and wandering 55 ms.
- **Only some tiers share a seed.** Bar low and mid do, and party mid and high do. Bar high (55007) and party low (53014) don't. Same-seed bar high failed on tempo at -1.73%.
- **The sparse words don't reliably reduce the count.** Three of the six bar lows have more onsets per beat than mid, with "few notes" in their tags. Seed still decides a lot.
- **The measures can't test what won.** They count events and energy. They don't say whether a take is lively, identifiable or one song with its mid, and those are the words that won the blind round.

### Lawn high, third try

**Two takes pass the full filter, the first at this tier.** Neither is on the page yet, and the second-try section is unchanged.

| Seed | Measured BPM | Error | Wander | Onsets/beat heard (whole) | Spread Hz heard (whole) |
|---|---|---|---|---|---|
| **52019** | 162.02 | +1.26% | 9.5 ms | 1.67 (1.48) | 979 (1036) |
| 52022 | 161.10 | +0.69% | 11.3 ms | 1.69 (1.59) | 753 (748) |
| Mid, 52011 at 144 | 143.92 | -0.05% | 14.4 ms | 1.43 (1.37) | 746 (721) |

52019 is +17% (+8%) on onsets and +31% (+44%) on spread against mid, and it clears both tests in a way second-try 52012 didn't: 52012 wanders 61 ms. 52022 is +18% (+16%) on onsets, with spread only +1% (+4%). The other four missed tempo: +2.62%, +2.50%, +3.69% and -6.25%, and 52020 also has no clear pulse. With the second try, that is 2 full passes in 12 at this tempo and these tags.

### Page and storage

`python3 -I tool/music/build_listening.py --add-ladder ladder-bar <run dir> <served dir>`, and the same with `ladder-party`, into the cached `listen-built/`, then copied to `build/web/listen/` with the restore command above. Both new entries are in `LADDERS`. Checked by hash: all earlier excerpts and the answer key are unchanged, and `index.html` differs only by the added sections. Both copies match. An open page needs a reload. Each excerpt measures within 0.1 dB of the others, -18.1 to -18.2.

Takes: `ladder-bar/`, `ladder-party/`, `ladder-lawn-3/` in the cache folder, which now holds 849 MB. Tier files are `low.flac`, `mid.flac`, `high.flac` beside `low/` and `high/`. Timing and measures are in `tool/music/themes-20261106/ladder-{bar,party,lawn-3}-*`. Checksums added to `SHA256SUMS` in both places.

Each batch of six took about 75 s of GPU, plus queue waits of up to 4.4 minutes behind other jobs.

## New lows, for the owner's ears

The owner, on the ladders: low tiers too quiet and thin, and the lawn's low too slow. The earlier lows asked for "sparse", "lots of space" and "few notes", so this batch asks for a lively band and a full sound instead. Nobody has heard these. Timing and measures: `tool/music/lows-20261106/`. Takes: `~/.cache/tillandsias-project/kumbia-audio/lows-20261106/`, 6 per batch. Same workflow, `ace-xl-turbo`.

| Ladder | Seeds | BPM | `$node:94.tags` |
|---|---|---|---|
| Garden | 51002-51007 | 92 | warm night cumbia at the mansion gates, inviting, instrumental, lively small band, accordion melody, guira, steady congas, driving bass, full warm sound |
| Lawn, fuller words | 52011-52016 | 136 | fast joyful swing for two dancers showing off, instrumental, lively swinging combo, driving upright bass, snappy drums, bright clarinet melody, rolling piano, full warm sound |
| Lawn, plain words | 52021-52026 | 136 | the old low's words: fast joyful swing for two dancers showing off, instrumental, small combo, upright bass, brushed drums, clarinet, piano |
| Bar | 55005-55010 | 100 | cool swaggering indoor cumbia under lanterns, instrumental, lively tight band, characterful lead melody on twangy electric guitar, rounded driving bass, steady congas, guira, electric keys, full warm sound |
| Party | 53010-53015 | 112 | cool midnight Latin boogaloo for a circle of dancers, instrumental, lively tight combo, characterful flute lead melody, walking upright bass, steady congas, piano montuno, handclaps on the backbeat, full warm sound |

Picked by the full timing filter, then by closeness to mid. Heard window, onsets per beat and spread in Hz:

| Ladder | New low | Old low | Mid | Concern |
|---|---|---|---|---|
| Bar | 55006: 2.67, 479 | 1.80, 406 | 2.59, 643 | The cleanest result: onsets reach mid, spread stays under it |
| Garden | 51005: 3.07, 1321 | not measured here | 3.40, 648 | Spread is twice mid's. The only one of six to pass timing |
| Party | 53015: 3.01, 775 | 1.97, 336 | 3.06, 552 | Spread is above mid's. The only one of six to pass timing |
| Lawn | 52024: 1.97, 586 | 1.83, 577 | 1.43, 746 | The lawn's mid has fewer onsets per beat than every low measured, so the fix may belong in mid |

The fuller lawn words overshot, up to 2.25 onsets and 1271 Hz, which is what the owner disliked in the first place, so the page carries plain words at the faster tempo. The lawn's section uses high seed 52019, which passes the filter, in place of the second try's 52012. These numbers count events. They can't say whether a take is lively or still sounds like its mid.

Page: `--add-ladder lows-garden`, `lows-lawn`, `lows-bar`, `lows-party`, at the bottom of the listening page. Earlier sections are unchanged.
