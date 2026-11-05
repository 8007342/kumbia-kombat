# Pool garden level, N levels and transitions: engine audit

2026-11-05, read at `34f6f3a` (`c00e640` changes only plan docs). Design research only; nothing was implemented. This covers the pool garden as an **added** level: Cool Crowd stays, so `plan/level-3-readiness.md` remains valid for that level.

**Owner rulings folded in (2026-11-05).** Many more levels will be added, with none replaced. Adding levels and assets should become a few prompts plus compute. The Gatekeeper fist-bumps Mācron at Level 1→2, and the full high five stays for the finale. Tap zones stay fixed and thumb-reachable, the top is for the dances, and any coupling between scene and input is a finding. Mācron's signature step will come from a salsa teacher, so it gets a slot.

**Evidence labels.** Unlabelled claims are read from the cited code. *Measured* means I ran it: a throwaway Dart script drove the real `GardenSession`, `MusicTransport`, `TransitionConductor` and score files on a fake clock with perfect taps at 240 Hz, and arithmetic covered crop and sizes. *Inferred* means my reading, not tested. No phone, browser or listening test was run. All memory figures are estimates from image dimensions.

## Verdict

The engine can carry this level without a rewrite, and the angled corridor is the cheapest big item, not the hardest: with a level horizon, depth sort and scale-by-depth stay correct for a path to the top right, so the angle is mostly data plus marks that are hard-coded today. Scene and input are already separate in logic: no input code reads a world coordinate, so no camera can move a zone. The couplings left are visual (see the ruling 4 table in Q1). The goal of many levels from a few prompts is further off than the single level. The runtime knows exactly two rooms, silently treats any other as the garden, loads every atlas at startup and never frees one, which can't scale to N levels. Charts, marks, crowd behaviour and copy are all still in Dart. Mācron is in every transition but has no route for new drawings, and no sequencing, contact-point or prop system exists. Most of this can be proved cheaply with existing art before any GPU run.

## Needs, ranked by effort

Effort is rough and relative. "Blocks" means what cannot start or be judged until this exists.

| # | Need | Effort | Kind | Blocks |
|---|---|---|---|---|
| 1 | Wire per-limb and groove clips already drawn (44 of 64 drawings never show) | S | Data plus small code | Richer dance; walk frames for challengers |
| 2 | Per-room stage marks: hero home, entrance, challenger marks, yield marks. Replaces `x = .5` and `isBar` Y values | S | Data, small structural | Angled corridor, two dancers |
| 3 | Level registry for any N: replace `isBar`, positional `fights[i]`, bridge and chart lookups, copy, `/ 05` | M | Structural, then all data | Every added level (`level-production-pipeline` 2.1, 2.3) |
| 4 | Per-room lamp, plant and waiter data, currently fixed to two rooms | S | Data | Any new room looks wrong without it |
| 5 | Two dancers: two sampled poses, atlas per dancer, chart-side note ownership | S-M code; L art | Structural in scene; data in chart | "Two women" |
| 6 | Crowd posture: standing or swimming base instead of always seated | M | Structural in `CrowdInterestModel` | Table guests, swimmers |
| 7 | Waterline or cut-line clip per actor | S | Small structural | Swimmers; Bartender behind the counter |
| 8 | Ambient water as flip-frames on the foreground clock | S code; S-M art | Data plus a new kind | Living pool |
| 9 | Scenery cut-outs in the depth sort (pool columns, front foliage) | S-M | Small structural | Pool enclosure, mixed depth |
| 10 | Longer arrival: set `introBeats` per room and derive `entrance` from it | S | Data | "Stopped by two women" |
| 11 | Beat-locked sequence player over the exit, including source tail | M | Structural | Fist bump, gulp, new walk |
| 12 | Hand and prop anchors per frame | S-M | Data plus parser | Contact without visible gaps |
| 13 | Mācron drawing route: fist bump, gulp, rear 3/4, signature step, finale high five | L, unproven | Pipeline | All his new moments |
| 14 | Two new challengers at 64 poses each, or one plus a costume route | L | Art pipeline | Final pool garden |
| 15 | Room plate with a specified vanishing point, then calibration | L, unproven | Pipeline | Final pool garden (`level-production-pipeline` 4.x) |
| 16 | Per-room load and release, plus guest repack and plate resolution. Optional for 3 rooms, **required for N** | M-L | Structural plus asset | Many levels on a phone |
| 17 | New pool garden score, success phrase and both neighbouring bridges. Pairwise: inserting a level replaces one bridge with two | M | Data, ears | Final pool garden |
| 19 | Durable run progress, and a run-length decision | M | Structural | Campaigns past about 8 minutes |
| 20 | Move cue origin below the dance area; move HUD labels off it | S | Small HUD change | Ruling 4 |
| 21 | Signature step slot: reserved clip id, level-brief field, reference route | S slot; art with item 13 | Data | Teacher's step when it arrives |
| 18 | Closeup camera and plates | S transform; L art | Structural plus pipeline | Only if closeups are chosen (owner question 4) |

## Pitfalls, most costly first if found late

1. **Mācron has no way to get new drawings.** `tool/art/characters/macron.json` is `status: rig-only`, and its comment says a full definition "comes with the cinematic shots". `macron-pilot.json` has no clips. His atlas came from a generated sheet, while the challengers come from the Qwen route, so new frames may not match him. Reach, gulp and any 3/4 walk all depend on this, and he is the character players look at most. Prove one drawing before designing shots around him.
2. **Shot pipeline design is stale.** `cinematic-shot-pipeline` D2 and D4 assume the SDXL-era stage graph and a 96×120 atlas with per-shot sizes. `LESSONS_LEARNED.md` A9 and its corrections table say the accepted frames came from Qwen and the frame size is 256×320. Building tasks 2.x as written risks a pipeline for the wrong route. Revise it first. D6's 6.5-beat budget still fits (see Q5).
3. **Tall phones crop the "top right corner".** *Measured:* with the cover transform on a 1024×1536 plate, a 390×844 phone sees source x .153–.847, and 412×915 sees .162–.838. A 9:16 screen sees .078–.922. So corners painted at source edges vanish on the most common phones. The top-left pool also runs under the header and Respect bar, which reach about y .17 (inferred from `garden_page.dart:690` with a 47 pt safe area). Author the plate to a safe box of about x .17–.83, y .17–.65, or give this room a taller plate, since `sourceWidth` and `sourceHeight` come from the image (`garden_scene.dart:197-202`). That choice has to precede plate generation.
4. **New rooms silently become the garden.** `isBar` is `_currentBackground.contains('bar')` and `_roomId` falls back to `garden` (`garden_scene.dart:59-60`), so a pool plate gets the garden's floor plane, marks, lamp glows, challenger and exit route with no error. A plate path that merely contains "bar" becomes the bar. `CrowdStageProfile.forRoom` also falls back to `garden` (`crowd_interest.dart:48-51`), so a new id gets 3 interested guests rather than its budget, silently. Only playtest would reveal it. Make both fail closed.
5. **Load-everything can't scale, and memory has no measured limit.** About 137 MiB decoded today, about 160–230 MiB with this room (Q7). Nothing is ever released: no `images.clear` exists, and every atlas loads at startup. Ten levels would be about 260–380 MiB by the same method (estimate). `FORGE_DIAGNOSTICS.md` 2001-bwgl also means visible forge windows can't produce a valid number. Finding a phone tab crash after the art is made would force a repack of everything. Per-room load has to be designed before the level count grows.
6. **Crowd data silently ignored.** `maxVariants = 12` (`outfit_palette.dart:16,60`) leaves any further guest atlas in source colours with no error, and each variant costs two atlas readbacks and a per-pixel Dart loop (`:160-175`), the design that froze software mode in D1. Layout `archetype` and `paletteIndex` lose to the live snapshot (`garden_scene.dart:304,313`), which derives both from guest index (`crowd_interest.dart:250-251`), so authoring "these are swimmers" on a slot does nothing during play.
7. **Live shaders for water would repeat D2.** They passed native tests and lost sprites in hosted CanvasKit (`outfit_palette.dart:5-7`). Use flip-frames unless a new hosted proof says otherwise.
8. **The rear walk may slide.** `heroSpriteFrame` shows a static `profile` for side walking (`party_sprites.dart:246`), and x changes smoothly under it. Portrait geometry helps: heading from hero to top right is only about 23–29° from vertical (*measured*, 390×844), so the rear cycle may be good enough. Test before drawing anything.
9. **Mirrored dancers can contradict the cue.** With `flipX`, a `left_hand` frame shows the other side of the screen. Chart limbs are cue identities, so a dancer visibly using the wrong side teaches the wrong zone.
10. **The bar's exit doesn't lead outdoors.** The painted arch shows an interior hall, and the route ends at x .88 (`room_departure.dart:98-100`), off screen on a 390×844 phone (*measured*: logical 188.8 of 180). Inferred: the arch suits Cool Crowd next, and jars if the pool garden follows directly, so level order matters (owner question 1).
11. **Arrival has only two calm beats.** Demonstration cues appear two beats before the target (`garden_session.dart:344`), and the first call starts at beat 4 (`:33`), so stable framing lasts 1.11 s at 108 BPM (*measured*). A "stopped by two women" moment won't fit without a longer intro.
12. **The fist bump still has a height gap.** At one floor line Mācron is 35% of adult height (`garden_scene.dart:563`). By eye his raised fist reaches about 30% and the Gatekeeper's lowest side reach is above 50%. A fist forgives alignment better than open palms, but the Gatekeeper needs a new low-reach drawing, and canvas bobbing is against the project's rule (`crowd_interest.dart:11-12`). His build is also still open (A8): decide whether to refine him first, since a contact moment makes "too skinny" more visible.
13. **Bridges are pairwise.** Each bridge is written from one key to another (`bar_to_crowd`: C minor to D Dorian), so every insertion orphans one bridge and needs two. Generate them from the two neighbouring briefs, or adding a level stops being a few prompts.
14. **Run length and progress.** Clean budgets total 390 s against a 5–8 minute target (`plan/storyboard.md:3`). One added level gives about 485 s of play plus about 72 s of transitions, or 9.3 min (arithmetic, not measured). `CrowdCheckpoint` is in-memory only (`crowd_interest.dart:144`), and a replay restarts at room 0 (`garden_page.dart:374`).
15. **The planned level brief assumes one opponent.** `level-production-pipeline` D1 has a singular `opponent`, a flat `room` and no camera, marks or postures. Fix the schema before writing briefs for garden and bar.
16. **Dead fields invite false confidence.** `vanishingX` (`party_layout.dart:76`), `DeparturePose.scale` (`room_departure.dart:5`, not read by `_addHero`), `PartyActivity`, `windRadians` and `BattleStaging` (tests only, `LESSONS_LEARNED.md` B5) all look live. None affect the screen.

## Suggested order: smallest playable proof per risk

Each is a throwaway branch or a flag, reviewed by the owner where it says so. None of 1–7 needs a GPU.

1. **Registry and fail-closed room lookup.** Register six fake levels using the bar plate, with task 2.3's test and no per-room code. Proves nothing else is hard-coded. Do it first, since everything sits on it.
2. **Frame richness.** Wire per-limb prep, peak, follow and return, groove on the watch half, and yield-walk frames. Re-run the frame tally. Needed anyway, it's next in `plan/dance-richness-next.md`, and it changes what two dancers look like.
3. **Angled graybox.** A procedurally drawn plate with perspective lines to a vanishing point near (.80, .15), hero home left of centre, existing atlases. Play at 390×844 and 9:16. Answers crop, HUD collision, rear-walk slide and cue origin. Owner plays it.
4. **Two dancers with stand-ins.** Gatekeeper and Bartender as the two women, alternating by side, both parting on the response. Answers whether players can read it, before paying for 128 poses. Owner plays it.
5. **Swimmers and table guests with existing art.** Guests clipped at the chest over a flat water area, standing guests from `standing_idle` and `clap`. Answers whether reuse is enough at 32–64 dp.
6. **Sequence player on the garden exit.** The fist bump with existing frames only (`arm_sweep`, Gatekeeper's side reach), contact on success beat 0. A visible hand gap is acceptable here. Judges timing, then pause, resume and reduced motion.
7. **Memory test.** Load stand-in atlases to the ten-level estimate. Read frame time and tab memory on a real phone and in a host browser, after checking `chrome://gpu`. This sets the budget and how soon per-room load is needed.
8. **One Mācron drawing, one Gatekeeper low fist** through the Qwen route, with prompts confirmed at ComfyUI `/history` (A1). 3-pose pilot rule (G1). Kills or confirms pitfall 1. First GPU use.
9. **One pool plate, three candidates.** Overlay the calibration grid. Answers whether the generator can honour a chosen vanishing point and safe box, and whether `image.generate` `layout` helps (task 4.2).
10. **`bar.outro` pilot** after revising the shot design, then full character waves and the score brief.
11. **One level from prompts, timed.** Write the pool garden's brief with the revised schema and record which steps still needed hand edits. That list is the honest measure of the pipeline goal.

## Questions only the owner can answer

1. **Level order.** Your brief calls the pool the third level, Cool Crowd stays, and `plan/owner-rulings-2026-11-05.md` leaves the position open. Pool third means `bar_to_crowd` gives way to two new bridges, and the bar's indoor arch has to lead outside. Cool Crowd third then pool fourth keeps that bridge and the arch. Which do you want, and how many levels are you picturing?
2. **Run shape with many levels.** Does the 5–8 minute run stay, with shorter levels? Or do you want saved progress, chapters or level select? This decides item 19.
3. **Fist bump staging:** Mācron is 35% of adult height. Does the Gatekeeper bend down, or does Mācron hop? Does a rope or gate move too?
4. **Wide or closeup?** The storyboard and shot pipeline assume closeups for the gulp. Wide shots use the world art and need no plates, but the glass and gulp are small (Mācron is 83–145 dp). This is the largest cost swing.
5. **Bar staging:** does Mācron walk to the counter, or does the glass come to him? The counter is about 30% of the screen above his mark, and the Bartender stands in front of it today.
6. **How long may transitions run?** About 12 s per room today. Longer on first play, skippable on replay?
7. **Two women:** two distinct characters (about 128 poses) or one design with a costume change? Which dance reading do you want: alternating, unison, or trading bars?
8. **Swimmers:** party clothes or swimwear? How visible is the pool: open arches or glass? Glass reflections cost more.
9. **The pool level's identity:** its metric name, its music style, and its place on the crowd-enthusiasm curve.
10. **Cue start and target wander (ruling 4).** Should flying cues start below the dance area, and should the targets stop shifting between notes (Q1)?
11. **Signature step format:** beyond the interview (`plan/research/salsa-bachata-interview-2026-11-05.md`), what will the teacher deliver (video, counts, live session), and when? Which levels must it appear in? Mācron isn't human-shaped, so someone also has to decide how it maps to his body.
12. **Crowd size.** The interest model is 12 guests. Should extra background guests react, or just stay occupied?
13. **The Gatekeeper's build:** fix before or after the fist-bump drawings?

## Evidence by question

### Q1. Angled corridor

**What assumes a straight centred path:**

| Assumption | Where | What it needs |
|---|---|---|
| Projection, scale by foot Y, depth sort by floor Y | `party_layout.dart:49-55,81-86`, `ensemble_sprites.dart:247-255` | Nothing, if the horizon is level |
| Hero X is `.5` unless exiting; home Y by `isBar` | `garden_scene.dart:555-561` | Room data |
| Entrance and retreat move only in Y | `garden_scene.dart:544-550,560` | Entrance vector per room |
| Challenger at `.5 + .2 * yield`, Y by `isBar` | `garden_scene.dart:519` | Room marks. `battleStageMarks` (`battle_staging.dart:25-45`) has the shape but isn't wired |
| Exit route is straight waypoints in image space | `room_departure.dart:50-58` | Data. New route for this room; the current one targets an "opened dance circle" |
| Guests face centre by `x < .5` | `party_layout.dart:217` | Face the dance mark instead |
| Waiter walks along the middle; two plants; lamp glows | `garden_scene.dart:432-492` | Room data, or the waiter crosses the new path |

**Data or structural?** Mostly data. For a flat floor and a camera with no roll, a person's image height is proportional to foot Y minus horizon Y wherever they stand on that line, so `scaleAt` stays right when the camera yaws. This is geometry, not tested in-game. A homography is needed only if the horizon tilts or the path rises, for example stairs. Recommendation: keep one level horizon, move the vanishing point right, and paint the path. Guests must be placed off the painted path by hand, or by a small validator. No validator exists.

**Scene and input (ruling 4).** The logic is already independent. `thumbLimbAt` (`thumb_layout.dart:4-12`), `thumbAnchor` (`:15-24`) and `_cuePosition` (`garden_page.dart:525-541`) use only screen fractions and read no world coordinate. The input layer is a Flutter overlay above `GameWidget` (`:619,636`), and the world transform lives inside the game canvas (`garden_scene.dart:206`), so a future camera can't move a zone. Scene state flows from input only through `_scene.dance` and `flourishBeat`, which are presentation. These couplings remain, all visual:

| Finding | Where | Suggested fix |
|---|---|---|
| Cue origin at y .47 sits in the dance area. *Measured:* a cue stays above the tap band (y .65) for 65% of its flight to the upper row and 36% to the lower | `garden_page.dart:536` | Move the origin down. One constant, no judgment change. Owner's call, since a shorter flight changes the read |
| Origin coincides with the challenger's torso in the garden (inferred from foot .53, 150 dp tall). Accidental art-to-HUD link. Keep it fixed; don't add a per-room origin | `garden_page.dart:536`, `garden_scene.dart:519` | Stop relying on it |
| Targets aren't quite fixed: drawn rings shift per note by up to ±.036 of width (14 dp at 390) and ±.012 of height (10 dp). Tap zones themselves don't move | `thumb_layout.dart:18-23` | Owner question 10 |
| Hero's feet stand inside the tap band: home y .69, entering from .76 | `garden_scene.dart:555,560` | Per-room marks with a validator: world action above about y .65 |
| HUD text over the dances: "WATCH THE CALL" at y .29, combo and feedback at .53 and .57 | `garden_page.dart:976,997,1033` | Move toward the lower band |
| Zones are fractions of height with no safe-area inset, so taps at y up to .97 meet the home indicator, and the upper row rises on tall phones | `thumb_layout.dart:5` | Check on real phones |

**Facing.** `DepartureFacing` is rear, side-right or front (`room_departure.dart:2`). `heroSpriteFrame` selects rear, front or a static profile (`party_sprites.dart:202-266`). No frame is declared 3/4. By eye on `macron-dance-v1.png`, `rear_turn` reads as a rear 3/4 heading right, `spin_rear` as rear 3/4 heading left, `spin_front` and `profile` as front turns. So one usable frame exists for this heading, with no walk cycle. Flipping `spin_rear` would break his asymmetric cuff (`assets/art/ensemble/README.md`). Start with the rear cycle, using `rear_turn` for the first and last step. Draw `rear34_idle` and two walk frames only if the graybox slides.

### Q2. Two challengers

**What assumes one:** `_challengerAt` and its cached `_choreography` (`garden_scene.dart:145-180`), `_addChallenger`'s id `'challenger'` and `isBar` atlas (`:513-534`), `_addHero` reading one `ChallengerPose` (`:580-585`), `atlasIds` and required frames (`ensemble_sprites.dart:92-100,114-119`). The session and judge don't know about challengers at all: charts are limbs and offsets (`garden_session.dart:28-46`), so identical judgment with one or two dancers is easy to test (B3).

| Version | Who owns the call | What the player reads | Cost |
|---|---|---|---|
| Smallest: unison | Both dance every note, same sampler | One phrase, doubled. Cues unchanged | Two atlases, two marks. Identical twins if the atlas is reused, since opponents don't recolour (`level-production-pipeline` D5) |
| Mirrored | Both on every note, one flipped | Same, but one shows the wrong side (pitfall 9) | Same, plus a read test |
| **Better: alternating by side** | Dancer on the left owns left-limb notes, on the right owns right-limb notes | Who moves says which side to tap. Reinforces zones | Add a note filter. `ChallengerChoreography` accepts any increasing subset of offsets (`challenger_choreography.dart:97-121`). One fix: a subset's `last` note starts the handoff early (`:252-274`), so yield must key on the full phrase |
| Trading bars | A calls bar 1, B calls bar 2 | Call and answer inside the call. More musical | Same filter by offset. Less zone teaching |

Recommendation (inferred, to be played): unison at tier 0 to teach, alternating from tier 1 or 2. Keep both on one horizontal line, or depth scaling makes them visibly different sizes (*measured*: 112 dp at y .45 against 64 dp at y .36 on the draft plane). On the response both part, opening the gap for him; when cleared, both invite him through.

### Q3. Mixed crowd

- **Seated is the base.** `_loop` maps `occupied` to `seatedIdle` (`crowd_interest.dart:331`), and every layout helper is `_seatedGuests` (`party_layout.dart:204`). Standing is only ever reached by earning it (`:475-476`). `PartyActivity.standingChat`, `sipping` and `waiting` exist, but the scene never reads `.activity`.
- **Clips:** 9 groups, 24 frames, for each of 3 guests (`ensemble_sprites.dart:8-33`). Usable for table guests: `standing_idle`, `step_touch`, `clap`, `cheer`. Missing: chatting, or a standing drink. `drink` props are skipped on purpose (`garden_scene.dart:387-388`).
- **Tables:** `table` is a low cafe table at .43 adult (`garden_scene.dart:357`, `party_layout.dart:282`). A cocktail table is new art and needs a new `furniture` frame or kind.
- **Guests outside the model:** a slot with no `interestIndex` draws a static `seated_idle_a` (`garden_scene.dart:305-306`). Extras need looping ambient clips.
- **Occlusion and masks: none.** One flat background, then a Y-sorted list. No layer system, no clipping, shadows always drawn (`:317`). Swimmers need `canvas.clipRect` at a waterline, no shadow, and a posture limit so they never play sit-down. A horizontal cut also solves "Bartender behind the counter" (inferred), so it pays twice. Guests are small at that depth: *measured* 32 dp at y .30 and 64 dp at y .36.
- **Water and animated backgrounds: none.** The only shader is `party_palette.frag`, one-shot for recolour. Lamp glows are 2-unit gradient circles (`garden_scene.dart:500-509`). The usable mechanism is `ensembleAmbientFrame`, a foreground clock with reduced-motion fallback (`ensemble_sprites.dart:198-216`): kinds are a hard-coded switch, so adding `water` is small. `plan/assets.md:25`'s layers and emissive masks don't exist.
- **Budgets mean different things outdoors.** `standing` in the profile means "stands up from a seat" (`crowd_interest.dart:53-60`). A base posture is a model change.

### Q4. Room registry: what stops added levels

| Blocker | Where |
|---|---|
| Two entries in `partyRooms` | `rooms.dart:21` |
| Binary room identity, used by layout, plants, waiter, lamps, marks, atlas, departure | `garden_scene.dart:59-60,203,433,456,480,519,522,551,555` |
| Chart by index, and always `bar` on adoption | `garden_page.dart:231,311` |
| Bridge hard-coded; success looked up with `!` | `garden_page.dart:275-276,284` |
| Exit scores listed by name; `bar_to_crowd` and `crowd_duende_success` absent | `garden_page.dart:241-245` |
| Only `partyRooms[1]` preloaded, once | `garden_page.dart:252`. Room 3 would decode at the bridge's end, as the music starts |
| Fixed atlas ids | `ensemble_sprites.dart:92-100` |
| Copy is `_roomIndex == 0 ? a : b` | `garden_page.dart:1089,1116,1157,1177,1297`; also "BACK TO THE GATE" `:175` |
| Empty layout marked unverified; asset folders listed by hand; `vip` has no departure, and `_addHero` uses `!` | `party_layout.dart:320-328`, `test/party_layout_test.dart:87`, `pubspec.yaml`, `garden_scene.dart:551` |

**Already ready, for Cool Crowd:** `fights[2]` and its scores (all 14 score files ship). For everyone: `TransitionConductor` is generic (`transition_conductor.dart:58-90`).

**Beyond the third room, for any N:**

| Assumes about five levels, or a fixed list | Where | Needed |
|---|---|---|
| Rules are matched to rooms by list position | `garden_page.dart:230,310`, `progression.dart:24-30` | Rules live on the level |
| Exactly five crowd stages, each a Dart constant | `crowd_interest.dart:41-46` | Budget per level, or a curve |
| Header says `/ 05` | `garden_page.dart:750` | Level count |
| Next room is both list order and `nextRoomId`, which can disagree | `rooms.dart:21`, `room_departure.dart` | One source of order |
| Fixed atlas list; a missing frame fails the whole scene (D4) | `ensemble_sprites.dart:92-100,114-119` | Load only this level's manifest; one bad level can't break the rest |
| Guests are always `guest${index % 3}` | `crowd_interest.dart:250` | Cast per level |
| Pose vocabulary fits only `opponent-64` | `challenger_choreography.dart:5-26` | Fine until a level needs its own moves; then clip data |

**Adding the pool garden.** `progression.dart` holds no location, only the id string (`:27`) and the garden's forgiveness check (`:19`), so a new entry suffices. *Measured:* Cool Crowd's rules with the bar chart as stand-in take 94.7 s for a clean clear against a 95 s budget. Needed for a new id such as `pool-garden`: a `FightDefinition`, crowd profile, layout, departure, score, success, bridges and copy. Cool Crowd keeps its id, rules, music and story. If the pool sits between it and the bar, `bar_to_crowd` and the `bar` departure change. Formations (`level-production-pipeline` D5) are still useful, but need table groups and a pool.

**Still code-bound against "a few prompts plus compute" (ruling 2):**

| Bound in | What | Data form |
|---|---|---|
| `garden_session.dart:47-177` | Charts | Task 2.1, already planned |
| `garden_scene.dart`, `party_layout.dart`, `room_departure.dart` | Marks, floor planes, guest and prop slots, routes, lamps, plants, waiter | Room file, calibrated from the plate |
| `progression.dart`, `crowd_interest.dart`, `rooms.dart` | Rules, budgets, music and metric links | Level brief |
| `garden_page.dart` copy | Room lines, reset line | Level brief |
| `garden_scene.dart:347-389`, `ensemble_sprites.dart:205-212` | Prop kinds and ambient kinds as switches | Atlas plus clip metadata in the manifest. New kinds stop needing code |
| `challenger_choreography.dart` | Frame names and hard-coded phase fractions (`asset-inventory-contract.md:181`) | Clip tables; manifests already carry `events` and `durationBeats` |
| `pubspec.yaml` | Asset folders, not recursive | One `assets/levels/` scheme generated by the build |
| `tool/art/pipeline/plan_qwen_frames.py` | Per-character prompt text (A9); `art.py` still targets SDXL | Character definitions |
| Not yet anywhere | Sequences, contact anchors, camera, postures, water | New schemas |

The human gates stay by project rule (A6, C2, G2): eyes and ears approve, so "a few prompts" means prompts, compute and review. Compute estimate per new challenger: 64 poses at about 92 s, about 98 minutes (A3's first-hand figure, one job at a time).

### Q5. Cinematics

**The garden exit today, moment by moment** (*measured*, tier 4 is guaranteed since only tier 4 clears, `progression.dart:62-68`):

| Moment | Beat | Time from last note | What happens |
|---|---|---|---|
| Last required note | 98.5 | 0 s | Player finishes |
| Resolved, then cleared | 99.5 | +0.58 s | After good plus flourish windows (`garden_session.dart:399-406`). Input layer removed (`garden_page.dart:573,635`), autoplay suspended |
| Source tail | 99.5–104 | 2.59 s | Full tier-4 music. `_beginExit` picks the next phrase boundary (`transition_conductor.dart:69`). Gatekeeper reaches `invite` in 1 beat and **holds that single frame until adoption** (`challenger_choreography.dart:152-172`). Hero grooves in place. Text "MUCHO MOJO" and "FOLLOW THE GROOVE TO THE BAR" (`garden_page.dart:1077-1129`) |
| Success, 2 bars | +8 beats | 4.62 s | Bar 1 quotes the room call at velocity 84, bar 2 thins to 68. Guests settle from success beat 4 on (`garden_page.dart:287`, `crowd_interest.dart:207-222`). Hero still in place |
| Bridge, 2 bars | +8 beats | 4.80 s at 100 BPM | `exitTravel` 0→1 drives hero: static `profile` for 2 beats, then rear walk to the door (`garden_page.dart:127-131`) |
| Adoption | 0 of next | **12.59 s total** | Hard cut: `showRoom` then a new session (`garden_page.dart:291-323`). Hero teleports to the new entrance |
| Arrival | 0–4 | 2.40 s | Walk in. Demo cues start at beat 2, 1.20 s |

The 5.5-beat tail is constant while cycles start at beat 4 and the last offset is 6.5.

| Exit | Tail after cleared | Success | Bridge | Last note to next room |
|---|---|---|---|---|
| Garden → Bar | 2.59 s | 4.62 s (104) | 4.80 s (100) | 12.59 s |
| Bar → Level 3 | 2.36 s | 4.29 s (112) | 4.44 s (108) | 11.68 s |
| Level 3 → next (bar chart stand-in) | 2.17 s | 4.00 s (120) | 3.64 s (132) | 10.39 s |

**What can run beat-locked today.** Only hero route sampling, guest settling and the challenger's held frames, all pure functions of a beat (B1), which a sequence player can copy. There is no script, no camera (one `canvas.scale`, `garden_scene.dart:206`) and no shot player (`cinematic-shot-pipeline` 4.1 not started). Walking waits for the bridge.

**What each moment needs:**

| Need | Fist bump (Gatekeeper) | Gulp (Bartender) | Walk to new room |
|---|---|---|---|
| Timing proposal (inferred) | Walk in the tail (about 4 beats), contact on success beat 0, the loudest point, then settle. Bridge for the walk through | D6's 6.5 beats fit in 8 (3.48 of 4.29 s). Walk starts on the bridge | Bridge 4.44 s, then longer intro for being stopped |
| Marks | Today's route already passes Gatekeeper: at bridge beat 5, hero (.625, .535) and Gatekeeper (.70, .53), about 42 dp apart (*measured*). Move this earlier | Hero at y .62, counter at about .22–.31 by eye | New route; `bar_to_crowd` ends off screen on tall phones |
| Depth | Same floor Y: the tie-break by id puts `macron` over `challenger`. Deterministic, but make it explicit | Bartender behind counter needs a cut line (Q3) | Hard cut today. A threshold strip or wipe is new |
| Frames | Hero `arm_sweep` (unused) or `right_hand` raises a fist, screen-left only. Gatekeeper side reach exists, too high (pitfall 12) | New for all: pour, slide, gulp. Shaker question open (`plan/dance-richness-next.md`) | `enter_forward` frames exist for challengers. Hero has `rear_*` |
| Anchors | None: the parser reads rect, anchor and ppu only (`party_sprites.dart:83-85`); attachments are recorded missing (`plan/asset-inventory-contract.md:182`) | Glass needs a hand anchor, or authored in frames | None |

**Input.** Already off from cleared until the next intro: no `Listener` while `active` is false (`garden_page.dart:573,635`), and the overlay is `IgnorePointer` (`:1077-1079`). So gameplay can't be disturbed, and the B3 test still applies. **Pause** works by conductor and freezes presentation (`:108-112,409-411`); a beat-pure sequence inherits this, with a one-bar count-in (`:358-364`). **Reduced motion:** `sample` returns the first waypoint (`room_departure.dart:44`), so the hero stands, then cuts. Each sequence needs its own held-pose form. **Skip:** none exists, and the conductor has no way to shorten a scheduled chain. Spec requires it (`cinematic-shot-pipeline` spec: skip leaves progress identical). Simplest form (inferred): skip visuals to the end pose, music continues. A true time skip needs a conductor change.

**Extending time.** `bars` is data and `handoff` is generic, so a 4-bar bridge needs a new score and no engine change (`score.dart:46`; bars must divide by `phraseBars`). `introBeats` is already data (`garden_session.dart:33`), but `entrance` assumes 4 (`garden_scene.dart:545`). Keep it 4 plus a multiple of 16 or 8 to keep phrase alignment (inferred).

### Q6. What actually shows

*Measured* from `challengerFrameIds` and every `frameId` the sampler can return:

- Both atlases: **84 ids, 64 distinct drawings. 20 ids reachable, 20 drawings. 44 drawings (69%) never show.** The 20 legacy ids are aliases, for example `occupied` is `groove_down_l`.
- Clean run time share (garden; bar within about 1 point): `watch_left`/`right` 40.6%, `settle` 14.2%, `follow` 10.3%, `anticipate` 9.3%, **four limb accents 8.7%**, others under 5% each. `recover` needs a failed phrase.
- The tally stops at cleared, so it leaves out the long `invite` hold in Q5.
- Same frames serve different moves: `follow_*` and `anticipate_*` are hand frames even for feet, and `settle` is always `left_hand_return`.

**No new art needed for:** `left_foot_*`/`right_foot_*` prep, follow and return; `right_hand_return`; `groove_*` (10), `clap_*` (4), `challenge_*` (4), `approval_*`, `reassurance_*`, `finish_turn_*`; `yield_side_*` (6) in place of today's slide on `floorYield`; `enter_forward_*`, `retreat_backward_*` for walks and for the entrance reset. Each frame also carries `durationBeats`, `events`, `supportFoot` and `facing`, all ignored by the parser. Rule to keep: the sampler has no tier so art can't invent notes (`challenger_choreography.dart:93-95`). Richness belongs in rests, the response half, and score sections.

### Q7. Performance budget (estimates; nothing measured on a device)

Decoded at 4 bytes per pixel from manifest dimensions. Network sizes are real.

| Item | Decoded MiB | File MB | Loaded when |
|---|---|---|---|
| 3 guest atlases | 18.0 | 6.4 | Startup, all at once (`garden_scene.dart:82-86`) |
| Gatekeeper v3 / Bartender v3 | 9.6 / 7.7 | 0.69 / 0.74 | Startup |
| Life, furniture | 12.0 | 3.0 | Startup |
| Hero | 6.0 | 1.4 | Startup |
| 2 backgrounds | 12.0 | 4.7 | Startup, then `_prepareExits` |
| **Subtotal** | **65** | **17** | |
| 12 wardrobe variants (3 × 4 × 6 MiB) | 72 | n/a | Lazily on draw. All 12 combinations are used (`crowd_interest.dart:250-251`) |
| **Total today** | **about 137** | | Matches `LESSONS_LEARNED.md` D4's range. Inferred: CanvasKit may also hold CPU copies |

| Level 3 adds | Low | High |
|---|---|---|
| Plate | 6 | 7 |
| Dancers (one atlas, or two) | 9 | 19 |
| Water frames, cut-outs, cocktail table | 3 | 6 |
| New guest atlases plus 4 wardrobes each | 0 | 2 × 30 = 60 (past the 12 cap) |
| Fist bump, gulp frames | 2 | 5 |
| **New total** | **about 157** | **about 234** |

D1: software rendering runs 120–170 ms a frame, and draws grow with this room (35 world draws in the garden today, inferred from layout). Hardware rendering is what matters for players, but only a host browser or phone can measure it. Nothing loads per room, and nothing is released, so each added level adds about 15–30 MiB for good (plate plus challengers, estimate): ten levels would be about 260–380 MiB. `cinematic-shot-pipeline` assumes "load per sequence, release after", but Flame's image cache has no eviction in this code.

**Cheap reductions (inferred, untested):** v3 atlases cost 0.11 MiB per drawing against 0.25 for v2 guests, and compress far better. Repacking guests saves perhaps 2 MiB each, which is 8 more per wardrobe set. Fewer wardrobes (2 instead of 4) saves 36 MiB. Plates at the planned 180×320 native would be 0.22 MiB against 6 (`plan/assets.md:25`), if the owner accepts the look. Per-room release is the larger structural option; it must keep the music rule of preloading before handoff (`transition_conductor.dart:29`), so decode during the prior room, and test for a mid-phrase stall.

### Slots to leave open

- **Signature step (ruling 5).** Nothing defines it today (`plan/level-3-readiness.md:59`), and the owner says it will come from a salsa teacher. Reserve the clip id `signature_step` for Mācron and a `signatureStep` reference in the level brief, keep a record of the teacher's source, and don't draft a placeholder step. Reachable uses: Cool Crowd's outro (storyboard C01) and any flourish. It needs the Mācron route (item 13), and hand-keying follows B4 (inferred: `macron-pilot.json` has no clips, and `studio.key_footage` may help with video, untested here).
- **Finale high five (ruling 3).** Stays on storyboard E02–E03 with Tlatoāni, inventory `ending.highfive.*` (`asset-inventory-contract.md:419-422`), all missing. The anchors and sequence player built for the fist bump should serve it, so keep them generic.
