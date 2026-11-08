# Mansion act two: the wiring of the comedor, the galería and the terraza

**2026-11-08, branch `work/1883-lvls`, WIRE2.** The design is in `plan/levels/mansion-act-two-2026-11-08.md`. This note says what is wired, what stands in, how it was checked, and what needs a look moving. [F] marks facts and [P] marks my proposals, which the owner can reverse. Nobody has seen these levels move, heard them or played them on a phone.

## The campaign

garden, pool-garden, bar, cool-crowd, billiards, **comedor**, salon, **galeria**, **terraza**. `displayTotal` is 9. [F]

| From | Bridge | To |
|---|---|---|
| billiards | `billiards_to_comedor` | comedor |
| comedor | `comedor_to_salon` | salon |
| salon | `salon_to_galeria` | galeria |
| galeria | `galeria_to_terraza` | terraza, the last level |

The bridges, synth scores and renders are MUSIC2's (`work/1882-polk`). `billiards_to_salon` is gone. [F]

**Merge order.** Each level landed as its own green commit on this branch, so the coordinator can merge level by level: comedor at `10e1f42`, galería at `4347dc1`, terraza after them (see the final report). Each commit includes MUSIC2's commits up to that point. [F]

## Each level

| | Comedor | Galería | Terraza |
|---|---|---|---|
| Title | EL GRAN COMEDOR | LA GALERÍA | LA TERRAZA |
| Metric | Gusto | Drive | Joy |
| Cleared title | QUÉ / BANQUETE | QUÉ / ZAPATEO | QUÉ / CHISPA |
| Invitation [P] | ¿Un bailecito antes del postre? | ¿Puedes seguirnos el paso? | ¡Ay, mi amor, a bailar! |
| Synth tiers, BPM | 120 124 128 132 136 | 114 118 122 126 130 | 96 100 104 108 112 |
| Rendered takes | 120 / 128 / 136 | 114 / 122 / 130 | 96 / 104 / 112 |
| Hardest combo [P] | LA TORRE DE CHAROLAS | EL MURO DE TACONES | LA LLUVIA DE CONFETI |
| Rules | FEEL's: 6 of 8 before the peak, 3 peak passes | same | same |

**Fairness** is checked at the synth tempo of each tier, which is never slower than the rendered take for that tier. The checks are the game's `fairnessProblems` limits, at least 1.5 beats between two presses of one limb, and both screen checks of `test/cue_path_test.dart` (all three levels are now in its list). My tool `tool/music/chart_check.mjs` also checks every pattern's answer running into every other pattern's call, because a failed phrase can drop to any tier. [F]

### Comedor: a polka [P]

The feet take the oom (the beat) and the hands the pah (the "and"). The basic cell is a split: a foot on the beat, then the other side's hand on its "and". The thumb limits rule out a foot on every beat with a pah between them: the hand on the "and" sits on the same thumb as the next foot, half a beat earlier, which breaks the 330 ms thumb-hop limit at 120 and above. So every other beat carries a single clap on the same side, the "2" of each polka bar. From tier 3, a right-foot hop lands on the "and".

| Pattern | Tier | BPM | Presses | Richer steps | Presses a second |
|---|---|---|---|---|---|
| 0 | 0 | 120 | 8 | 0 | 2.00 |
| 1 | 1 | 124 | 10 | 2 | 2.58 |
| 2 | 2 | 128 | 12 | 4 | 3.20 |
| 3 | 3 | 132 | 13 | 5 | 3.57 |
| 4, 5, 6 | the peak | 136 | 14 | 6 | 3.97 |

Pattern 5 mirrors pattern 4. Pattern 6 opens on a two-foot stamp. In all, 29 richer steps against billiards' 25. **MUSIC2's alignment audit** (`align_charts`, comedor render): 96 out of 100, 96% of notes on an accent, none on silence. The weakest notes are the "and" of beat 1 in peak patterns 4 and 5 (score .62). The audit also found that the music's four-bar phrase seems to start a bar after the calls do. I suggested fixing that with the bridge's `entryBar` on the music side. Not done yet.

### Galería: a reel [P]

Foot-heavy and relentless, and on the music. The feet stamp the beats the take accents. Both feet land together on the one from tier 1. The rigid arms slap only where a foot can't follow its own stamp. Every note is on a beat.

| Pattern | Tier | BPM | Presses | Richer steps | Feet |
|---|---|---|---|---|---|
| 0 | 0 | 114 | 8 | 0 | 7 |
| 1 | 1 | 118 | 9 | 1 | 7 |
| 2 | 2 | 122 | 10 | 2 | 7 |
| 3 | 3 | 126 | 11 | 3 | 7 |
| 4, 5 | the peak | 130 | 12 | 4 | 7 |
| 6 | the peak | 130 | 13 | 5 | 7 |

**MUSIC2's re-audit** of the beat-stamping version: 91, up from 68. 94% of notes on an accent, none weak, none on silence. By tier: 96, 97, 98, 98, 85. The peak scored lowest because its pickups at 3.25 and 7.25 sat just after the take's strong hits on 3 and 7. I moved them onto 3 and 7, which also keeps two cue paths apart. That last move hasn't been re-audited.

**How it got here.** My first draft ran the feet in the treble's 3+3+2 eighths. MUSIC2's audit of the rendered reel scored it 68: 15% of its notes sat on silence, because this take accents the beats and its "and"s are weak. The worst note was the 1.5 at the peak, at .21. This rework follows the audit's suggestion: feet on the beats, both feet on the one. Two drafts before that put sixteenth hands next to feet, which breaks the 170 ms cross-thumb limit (a quarter beat is 115 ms at 130). In two peak drafts a pickup at 3.25 before a stamp on the same side crossed cue paths on a 320x454 screen. MUSIC2 moved the ladder from 112–128 to 114–130 for the steadiest take, and the chart is checked at 130.

EL MURO DE TACONES: eight straight eighths of heels, 231 ms apart at 130 BPM, just over the 230 ms a combo note must keep. Then three more heels and a stamp. Nothing plays the combos yet, and nobody has audited them.

### Terraza: a samba [P]

One tresillo every two beats: a foot on the beat, the hip-hand on its last sixteenth (where the tamborim plays), and the other foot on the "and" of two. Every hand is off the beat. The peak's call ends with both hands thrown up on the "a" of four, the confetti. A single left hand there made two cue paths cross into the next call's left foot.

| Pattern | Tier | BPM | Presses | Richer steps | Off the beat |
|---|---|---|---|---|---|
| 0 | 0 | 96 | 8 | 0 | 50% |
| 1 | 1 | 100 | 10 | 2 | 60% |
| 2 | 2 | 104 | 11 | 3 | 64% |
| 3, 4 | 3 and the peak | 108, 112 | 12 | 4 | 67% |
| 5, 6 | the peak | 112 | 12 | 4 | 67%, 58% |

It is the slowest level and the most syncopated. **MUSIC2's audit** of the rendered samba: 95. 98% of notes are on an accent, none are weak, and the worst note scores 1.40. By tier: 99, 97, 93, 94, 95. The take's attacks run 12–13 ms early on the low and mid takes.

## New general behaviour, in code where data couldn't say it

| What | Data | Code |
|---|---|---|
| **Room life at full party.** Paintings, a sculpture or chandeliers that join in only at the top tier. A new layer kind wakes on the last tier step and shows its whole drawn range, so the drawings carry the subtlety. `minTier` holds any layer at rest below a tier, even at full crowd swing. `phaseBeats` shifts the beat, for example a snap on 2 and 4 | `layers.props[].kind: "artwork"`, `minTier`, `phaseBeats` | `PartyLifeKind.artwork`, `RoomLayerProp`, `_drawRoomLayers` |
| **The diners' meter.** A guest cast with their own atlas names a clip set: one drawing list for each of the crowd model's nine clips. Loops change on the beat, each guest a whole drawing off the others. A change of pose such as rising plays once. An optional `applause` clip runs from the win's applause cue in its quarter-beat stagger: the rise, then the toast on the beat. Standing guests with a clip set need no `floorDance`. The model still decides who is where on the meter | `crowd.clipSets`, a guest's `clips` | `GuestClipSet` (`dance_floor.dart`), `_addCastGuest` |
| **A line who dance as one.** A challenger's `line`: more dancers, each placed relative to the lead's feet, drawing the lead's own frames up to half a beat late (two quarter-beat drawings), so one set of frames reads as five people and a ripple runs down the line. Their own win frames are just as late. `arch` moves them into new places at the win, turns one side to face the other, and plays the arch drawings once it is half formed, holding the last | `stage.challengers[].line` | `DanceLine` (`dance_line.dart`), `_addChallenger` |
| **The close-ups** (cloche, feet double tap, kiss mark and spark) | the existing `exitShot.actors[].frames`, `cue`, `keepsake` | none |

The loader refuses: `minTier` above 4, a clip set missing any of the nine clips, a guest naming no such set or naming clips without an atlas, a misspelt clip field, a line dancer more than half a beat late, and a line dancer placed off the floor or on the thumbs. Tests: `test/act_two_levels_test.dart`. [F]

## The outros, in beats

All three follow the design note. Galería and terraza each walk Mācron out with the salon's `walkOut`. A non-last level's walk ends before its bridge does, so the dissolve still clears the room.

| Level | Beats |
|---|---|
| Comedor | 0–2 Don Charolas spins to a stop. 2–4 he presents the cloche while Mācron walks over. Close-up 4–10: the lid comes off on 6 (`clink`), the sips on 6.5, 7 and 7.5 (`glug`), QUÉ / BANQUETE. From 10, the diners rise and toast (their applause clip) and the lamps swell. 12–19 Mācron walks out past the waiters to the service door. The bridge ends at 24 |
| Galería | 0 the line freezes. 1–3 it splits into the arch, arms up. 2–3.75 Mācron walks to his mark. Close-up 4–9: the double tap on 6 and 6.5 (`clack`, `clack`), QUÉ / ZAPATEO, then his proud face. 9.5–16 he walks out between the arch's two sides. Siobhán nods at 10.5 and dances from 13 |
| Terraza | 0–2 Tía Purpurina throws confetti. Close-up 3.5–10: the kiss on 5 (`peck`), the antenna spark on 5.75 and 6.25 (soft high `clink`s), QUÉ / CHISPA. From 10 the sky lights up (the flare), the guests applaud, and 11–15.5 Mācron dances off to the stairs. The last level: everything fits its 16-beat success |

## Still stand-ins

**Swapped in, 2026-11-08:** COMEDOR's room (`work/1881-cmdr` 97a61c9), taken as its two files:
- the clean plate `comedor/comedor-room.png`;
- its layers `comedor-layers.png`: two chandeliers (hanging, `minTier` 3), plus a statue's nod, a statue's foot tap, a portrait lady's head tilt and a portrait's finger snap on 2 and 4 (artwork, `minTier` 4);
- their marks: floor camera, hero marks, Don Charolas' marks, the banquet table as an occluder (its front edge at y .37, so the diners' hands stay in view), and the route round the table's right end to the service door;
- the cast's places: 8 diner seats, 3 waiters and 1 late guest (12). Diner atlases carry `playerHeightPx` (168 plate px at y .405), which the scale reads ahead of any frame's height, so any of their drawings can be a clip set's `reference`.

**Swapped in, 2026-11-08:** GALERIA's room (`work/1885-galr` 95bdd19, 56ecd52), taken as files:
- the plate `galeria/galeria-room.png` and its floor, refit to the painted doors;
- the hero marks, and Siobhán's mark with her meet mark past the tunnel's far end;
- the line's arch, two facing pairs .2 apart across the runner. Arch offsets now count from the lead's *mark*, not from where she stands, so the arch stays put while she steps over to meet him;
- the route up the runner to the far doors, the 12 guests in pairs along both walls, and the two picture lights;
- the close-up: a floor plate, and Mācron's feet and proud face on full-screen canvases (360x780 at scale .5), so no cut edge shows.

Siobhán herself and the gallery's room-life layers are still to come.

**Swapped in, 2026-11-08:** waiter-a (`work/1881-cmdr` be4e516), on a `waiter` clip set that hops the polka (`groove_*` at half a beat a drawing). He faces right, so he isn't mirrored and the tray stays on his picture-right.

**Swapped in, 2026-11-08:** TERRAZA's room (`work/1886-terr` cbac883):
- the plate, with its floor at horizon .36;
- the marks: she meets him on his left, so she stays on the picture's left in the close-up;
- the route to the stair head;
- 12 guests: couples from guest3–6 on `pair_dance`, and guest0–2 dancing alone on a `solo` clip set of their step-touch drawings;
- the lamps;
- the layers: five firework bursts (light, growing with every tier), palms and festoon bulbs (artwork, tier 4);
- the close-up plate, and Mācron's rest, kissed and sparking drawings;
- the lipstick kiss mark as his keepsake from beat 6.

**Swapped in, 2026-11-08:** her side of the kiss (`work/1886-terr` 41ce628):
- `terraza-tp-rest` and `terraza-tp-kiss` take the lawn's place. His head stays anchored where the lawn's was, at (200, 165). Her contact (323, 90) puts her kiss-frame lips on his kiss mark at (124, 221).
- The balustrade strip `terraza-rail` stands in front of her where the lawn had its hedge. It sits 198 px below the contact, not the hedge's 97, so that it ends where her canvas does, which is 350 px below her lips. With the hedge's offset, her dress and its cut edge showed under the rail. [F, seen on stills]

**Code, at TERRAZA's request:** layers of kind `light` now also bloom with the win's `exitShot.flare`, which the warm-down doesn't cool, so the fireworks fill the sky as the lamps swell (`_drawRoomLayers`). Seen on the terraza's win stills, not in a unit test. [F]

**Swapped in, 2026-11-08:** COMEDOR's eight diners (`work/1881-cmdr` 451fd0b), `diner-a` to `diner-h`, on the `diner` clip set:
- the meter: eat, watch, clap, then rise and raise the glass; at the win they rise and toast;
- drawn in place 1:1 with the plate, never mirrored, and scaled from `playerHeightPx` 168.

Their first atlases put the anchor (the floor under the chair) below the frames, which stop at the table top. The loader refuses an anchor outside its frame, so COMEDOR padded every frame down to it, and nothing moved on screen. [F]

`pubspec.yaml` now lists `assets/art/comedor/` and `galeria/`, plus `assets/music/rendered/comedor/` and `galeria/`, which were missing: the web build wouldn't have bundled those takes. A test now holds every folder a level or a rendered take names. [F]

Each swap is a data edit in the level's file and re-running the generator (`make_<level>.py` in my scratch folder, to be folded in by hand when the art lands), plus a test run.

| Level | What | Stand-in today | Real piece from |
|---|---|---|---|
| Comedor | Don Charolas | terciopelo's atlas, `id: terciopelo` so his combo finds a choreography | `charolas`, plus a dancer entry in `choreography.json` |
| Comedor | waiters b and c, late guest | guest5 and 6 on the `waiterStandIn` set; guest4 on the `guest` set | `waiter-b`, `waiter-c` on the `waiter` set |
| Comedor | the cloche close-up | the bar's oil gulp | `comedor-dc-*`, `comedor-can.png`, `comedor-mc-*` |
| Galería | Siobhán and Las Tréboles | swing-a's atlas, five times | GALERIA art (later wave) |
| Terraza | Tía Purpurina | blinblin's atlas | TERRAZA art (later wave) |

## What was checked, and how

- `flutter test` and `flutter analyze lib test` (the 4 baseline notes), run in a symlinked copy at `/home/forge/src/kumbia-kombat/wt/levels-run` through the heavy-step lock. Counts are in the final report. [F]
- `test/act_two_levels_test.dart`, for each level:
  - its place, title, metric, words and combo, and FEEL's rules;
  - fairness at every tier's synth tempo, with the peak's three passes;
  - same-limb spacing;
  - the dance's own shape: polka feet on beats; reel at most two hands a pattern and four in five presses on the feet; samba hands always off the beat;
  - richer steps rising with the tiers;
  - the combo hittable at the top tempo;
  - a flawless autoplay run clears it;
  - every clip set's drawings exist in each guest's atlas;
  - room life waits for its tier;
  - the shot fits its music and every drawing ships.
  
  It also writes `build/stills/<level>-opening.png` and `<level>-win.png` from a real cleared run through the real scene. I read those by eye. [F]
- `test/rendered_page_test.dart` now plays the real page from the comedor into the salon over `comedor_to_salon`: the comedor's walk out, then the salon's, the accents in order (`clink`, three `glug`s, `nod`, two `peck`s), and the end screen. The old billiards-into-salon run had lost its bridge. [F]
- The level golden was regenerated with `--dart-define=UPDATE_LEVEL_GOLDEN=true` and came out byte for byte the same. It samples the garden and the bar, and none of the new fields are on there. [F]
- `tool/music/validate.mjs` and `validate_pool.mjs` pass. The campaign list in `validate_pool.mjs` and in the tests was updated at each insertion. [F]
- `/console`: its catalogue reads `levels/` and the index, so the three levels list with their references. `console_catalog_test` passes. [F]
- **Seen on stills, not moving:**
  - Comedor: the room, the waiters, and the diners' cheer at the win (on stand-in art).
  - Galería: the line of five, the ripple between them, the arch, and Mācron passing through it.
  - Terraza: see the final report.
- **What went wrong:**
  - My first two layout searches enumerated every layout and never finished. A DP over the last 1.5 beats replaced them.
  - The galería's sixteenth-note hands broke the cross-thumb limit.
  - Its 3+3+2 feet then missed the rendered take's accents: 68 on MUSIC2's audit. Fixed in its own commit after terraza.
  - The arch's first offsets bunched the four dancers into a clump. I widened it.
  - The campaign-complexity test still called index 5 "the salon" after the comedor moved in. It passed by accident until I rewrote it by level id.
  - `point` refuses negative numbers, so line offsets got their own reader.

## What needs a look moving

- [ ] The polka on thumbs at 136: 14 presses a call. Is the oom-pah readable as a polka?
- [ ] The reel at 130: do stamps on the beat feel relentless, or square? Do the arm slaps between them read as the rigid arms of step dance?
- [ ] The samba's hip-hand on the last sixteenth: fun, or a guess? It's the most syncopated chart in the game.
- [ ] The diners' meter with COMEDOR's real drawings: eat, watch, clap, rise and toast. Does the rise read at the win?
- [ ] Room life at tier 4: felt more than seen?
- [ ] The line of five: does a half-beat lag read as "as one" with a ripple, or as sloppy? Try `lagBeats` .25 at the ends.
- [ ] The arch, once real arms-up drawings exist.
- [ ] Each walk out: comedor through the service door, galería under the arch, terraza to the stairs. On the comedor's stills he first vanished behind waiter-b near the door. COMEDOR moved waiter-b to (.66, .455), and he is now seen heading for the door at beat 15 and is gone by 18.
