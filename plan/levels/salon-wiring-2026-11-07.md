# El Salón de Espejos: the wiring

**2026-11-07, branch `work/1877-wire`, the LEVEL agent.** The design is in `plan/levels/salon-2026-11-07.md`. This note says what is wired, what stands in, how it was checked, and what needs a look moving. Facts are [F], my proposals [P], which the owner can reverse. Nobody has seen this move, heard it or played it on a phone.

## What is wired

- **`levels/salon.json`**, last in the campaign, after billiards. Title EL SALÓN DE ESPEJOS, metric `Charm`, QUÉ / ELEGANCIA. `displayTotal` is now 6. [F]
- **Billiards leads here.** Its campaign entry has a bridge, and its success is no longer the 16-beat finale, because a dissolve now follows its chalk dab. [F]
- **A cha-cha chart.** [P] Below.
- **The outro, as the design note tells it.** [F for the data, P for the beats] Below.
- **Five new optional `exitShot` fields,** general for any later level. Existing levels don't use them, so nothing they draw changed. [F]

## Still stand-ins

Each swap is a data edit in `levels/salon.json`, plus its test run.

| Where | Today | Replace with | From |
|---|---|---|---|
| Don Terciopelo in play | The `gatekeeper` atlas, id and dance. His dancer entry (`dancers.terciopelo`, with the charisma idles: moustache, mirror glance, hand offer) is held out of `choreography.json` until his atlas ships with it, because the console's catalog test requires both together. EL GIRO's moves are the GateKeeper's `spin_flare`, `groove_double` and `clap`, and the win clips are his `watch_left`, `approval_*`, `reassurance_open_hand` and `invite` | Merge `work/1875-terc` whole (atlas and dancer entry), then set the challenger's `id` and `atlas` to `terciopelo`, the combo's moves to `giro`, `groove_double` and `line_hold`, and `exitShot.opponent` to `mirror_look`, `bow_a/b/hold` and `sweep_a/b` | TERCIOPELO, drawing |
| Mācron before the rose, in the close-up | `closeups/nod-mc-rest.png` (the party's nod rig, same canvas and floor) | a salon-mc drawing without the rose, if TERCIOPELO draws one | TERCIOPELO |

Already the real thing: SALONART's clean plate (`salon/salon-room.png`), the three chandeliers swaying as `hanging` layers, the close-up's plate (`closeups/salon-rose-plate.png`, the arched mirror), the camera, every mark, the six couples and the trio's places (SALONART's `art_runs/rooms/salon/marks.json`), all three trio players (piano, bongos and violin), the close-up's busts and Mācron's half and the wide-shot rose (TERCIOPELO's `salon-art.json`), his dancer entry with the charisma idles and EL GIRO's clips, and the rendered music and synth fallback (BOLERO).

## The chart

Cha-cha on 1: rock on 1, replace on 2, cha-cha-chá on 3 and 4. [P]

- **The triple** is a split (one foot, then the other foot on the "and", half a beat later) and then a single press on the first foot's side on the beat. That third press is a hand, not the foot again: the chá lands with an arm accent. Reason: cues of the same limb a beat apart sat on top of each other on small screens (`cue_path_test`'s .35 floor caught it at 0.21), and every level keeps one limb 1.5 beats apart or more. [F for the reason]
- **A rock step is a pair:** the foot with the opposite arm, the contra-body line of ballroom. The replace step gets its arm too, from tier 2. The last pattern closes the feet and opens both arms on a held line, and runs its triples from the right. [P]
- **Every phrase ends with an invitation to spin** (`offer: spin`, the sideways drag), the giro the room is named for. Tier 0 teaches it. Clearing never depends on it. [F]

| Pattern | Tier | Tempo | Presses | Richer steps | Presses a second |
|---|---|---|---|---|---|
| 0 | 0 | 108 | 8 | 0 | 1.80 |
| 1 | 1 | 108 | 12 | 4 | 2.70 |
| 2 | 2 | 116 | 13 | 5 | 3.14 |
| 3 | 3 | 116 | 13 | 5 | 3.14 |
| 4 | 4, first | 124 | 14 | 6 | 3.62 |
| 5 | 4, second | 124 | 14 | 6 | 3.62 |

- 26 richer steps against billiards' 25, and 3.62 presses a second at the top against its 3.03. [F]
- **One rule I changed on purpose.** `play complexity rises` also asked each level for a larger share of off-beat notes than the last. A cha-cha lands its chá on the beat, so the salon's share is about 15% against billiards' 79.5%. The test now asks the salon for more richer steps and more presses a second at its top tier instead. [P, reversible: the test names this note]
- **Fairness:** `fairnessProblems` is clean at 108, 108, 116, 116 and 124, with FEEL's guaranteed 180 ms window. The tightest gaps are a split's half beat across thumbs (242 ms at 124) and a thumb moving between its two spots in one beat (484 ms at 124). The last note is at beat 7, so the phrase-end margin is 304 ms at 124 against the 100 required. [F]
- **How it was written:** by hand to the cha-cha shape, then checked with a Python copy of `fairnessProblems`, then the real tests. Nobody has laid it against the bolero melody. A person should play it. [F]

## The outro, in beats

Beats count from the success score's first beat. The salon is the last level, so the shot fits its 16-beat success, and nothing dissolves: he walks out and the end screen follows. [F]

| Beat | What happens | Data |
|---|---|---|
| 0-1.75 | He stops mid-turn and looks at Mācron in the mirror | `opponent` clip 1 |
| 1.75-4 | He turns and gives a deep, slow bow, held | `opponent` clip 2, and a low `nod` on 3 |
| 2-3.75 | Mācron, done celebrating, walks to him | `walkFrom`, `walkTo` |
| 4 | Close-up | `closeupFrom` |
| 4.5-5.25 | He plucks the rose and offers it | actor frames |
| 6 | Mācron takes it, on the downbeat. His hand is empty. QUÉ / ELEGANCIA | `contactBeat`, a soft `peck` |
| 7.5 | He tucks it behind his antenna | actor frames, a softer `peck` |
| 9.5 | Back to wide. The rose is on his antenna | `closeupTo`, `keepsake` from 7.5 |
| 9.5-13.5 | The chandeliers swell once and settle | `flare` |
| 9.75 on | The couples turn in and applaud, a quarter beat apart | `applause` |
| 10-12 | He sweeps an arm toward the far doors | `opponent` clip 3 |
| 11-15.5 | Mācron walks out through them, fading over the last 1.25 beats | `walkOut`, along `departure` |
| 13 on | He dances his basic again | `opponent` clip 4, looping |
| 16 | The end screen | the success score ends |

### The new fields (all optional, in `exitShot`)

| Field | What it does | Code |
|---|---|---|
| `opponent` | A lone opponent's drawings by beat on the wide shot: `[{from, frames, beatsPerFrame, loop?}]`. A clip holds its last drawing unless it loops. Reduced motion holds the last drawing | `ExitShotClip`, `garden_scene.dart` `_addChallenger` |
| `flare` | `{from, beats, rise?, gain?}`: the lamps and the room's warmth swell once and settle, with no speed at either end. Brightness only, so reduced motion keeps it. Not cooled by the win's warm-down | `ExitShotFlare`, `_drawLampGlows` |
| `applause` | `{from, frames, beatsPerFrame, loop}`: guests already on their feet turn in and applaud, each a quarter beat after the last (all together under reduced motion). Seated guests aren't covered yet | `_applauseAt`, `_addFloorGuest` |
| `keepsake` | `{image, from, at, anchor, height}`: a small drawing worn by Mācron on the wide shot, from the close-up on. `at` is from his feet in his heights | `_drawKeepsake` |
| `walkOut` | `{from, to, fadeBeats?}`: for a last level, he leaves along the level's `departure` from his step and fades at the threshold. Reduced motion holds him and then cuts him away | `ExitShotWalkOut`, `_addHero` |

The loader refuses a walk out that starts inside the close-up, a flare inside it, opponent clips out of order, a keepsake that starts after the cut out, and misspelt fields. [F, tests]

**What these don't do:** the keepsake sits at one point from his feet in every drawing, so it can drift off the antenna on a drawing where his head moves (a hop moves both together). The walk route was written for this room. He passes to the right of Don Terciopelo so the two don't cross. [F]

## What was checked, and how

- `flutter test` and `flutter analyze lib test` (the 4 baseline notes), run in a copy under `/home/forge/src/kumbia-kombat/wt/wire-run`, since the host's Flutter only runs there. Counts are in the final report.
- `test/salon_level_test.dart`: the campaign place, title and metric; fairness at 108/108/116/116/124 and all three peak passes; the triple shape; same-limb notes 1.5 beats apart; a flawless autoplay run clears; every outro drawing exists in the atlas that draws it (the opponent's in his, the applause in each guest's); the story's order; the shot, title and walk fit the 16-beat success; his fade; the flare's ends; the loader's refusals. It writes `build/stills/salon-opening.png` and `salon-win.png` from a real cleared run through the real scene, which I read by eye.
- `test/rendered_page_test.dart`, new: the real page plays billiards into the salon on rendered music, through `billiards/bridge`, `salon/low` and `salon/success`, the accents land in order (chalk, then nod, peck, peck), the win's walk-out runs, and the end screen comes up.
- The level golden, regenerated with `--dart-define=UPDATE_LEVEL_GOLDEN=true`: byte for byte the same as committed. It samples garden and bar only, and the new fields are off there.
- `tool/music/validate_pool.mjs` and `validate.mjs` pass, with the six-level campaign.
- ALIGN's audit of this chart against BOLERO's takes (`tool/music/align_charts.mjs`): 96 of 100, no note on silence, the best of any level. Its weakest notes are the "and" of each triple (2.5 and 6.5). Its suggestion, triples on 4-and-1 at the end of the call, I left for a person who can hear it. [F, from ALIGN]
- **Seen on stills, not moving:** the bow, the close-up's four steps (one rose on screen at a time: I switch him to his empty hand on the downbeat), the rose on his antenna from the cut back through his walk, the couples clapping, the lamps' swell, and his walk out passing under Don Terciopelo's swept arm to the doors.
- **What went wrong:** the shared scratchpad held my sync script under a generic name, and another agent's script replaced it. For a stretch my test runs copied nothing new, so their results were stale. I caught it when a new test wasn't found, moved my tools to their own folder, and reran everything since. A first chart put the same foot a beat apart in each triple, and `cue_path_test` caught the cues overlapping on small screens. A test copied from the bar asked for a 1-beat `flare` move his clip doesn't have. The salon first had six guests, and the crowd model and its tests are fixed at twelve.

## What needs a look moving

- [ ] The bow: does it read as a deep, slow ballroom bow before the cut?
- [ ] The close-up: the rose's handoff on the downbeat, and the title on it.
- [ ] The rose on his antenna in the wide shot, through his celebration and his walk: does it stay on the antenna?
- [ ] The chandelier flare: soft, and not a flash?
- [ ] The applause: does it read as the couples turning to applaud?
- [ ] His walk out through the far doors: does it read as through them, or as fading on the floor?
- [ ] The gap from his fade (15.5) to the end screen (16).
- [ ] Charisma between phrases: moustache, mirror glance, hand offer.
- [ ] The chart on thumbs at 124: is 14 presses in a phrase fun, and does a hand on the chá feel like cha-cha?
- [ ] Do players find the spin, and does it feel like a giro?
