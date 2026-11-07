# Kumbia Kombat style guide

This is the one place to look for how the game should look and move: world, people, props, rooms and layers, sprites, and cinematics. It says what to do and points to the file that holds the detail. Written 2026-11-07, from everything listed under "Where this came from".

**When sources disagree:** the owner's newest ruling wins (`plan/owner-rulings-2026-11-05.md`, newest round first), then this guide, then `openspec/specs/art-direction/spec.md`, then older plans. The spec stays the contract for character canon, the tap area and the camera during play, so this guide points to it instead of repeating it. Section 10 lists each conflict and how it was settled. Section 11 lists where the game itself disagrees with these rules.

**What "accepted" means:** a test can't approve art. Tests check that files exist and that beats line up. Only someone looking at a moving picture on a phone-sized screen can accept it, and the owner has the last word (lesson A6).

## 1. Adding a level in a few prompts

The owner's goal: "adding and generating levels and assets should become a few prompts and throwing some compute power at it". Most of it is data today. `plan/adding-a-level.md` is the honest checklist of what is still code-bound.

| You need | Route | Style rules | A person must |
|---|---|---|---|
| Room plate | `tool/art/rooms/README.md`: spec, compile, two Qwen passes, proof | Section 5 | Pick the plate by eye beside the other rooms, check the floor overlay |
| Layers | `layers.py`, same README | Section 5 | Compare before and after, moving |
| Seats and tables | `props.py`: same drawings baked to the room's pixel and light | Section 4 | Check on the plate |
| Opponent | `art-family` skill: definition, sheet, frames, finish, atlas | Sections 3 and 6 | Approve the sheet, review every frame |
| Way out | An `exitShot` in the level file, copied from a shipped level | Section 8 | Watch it moving |
| Two words | `copy.clearedTitle` | Section 8.4 | Owner's taste |
| Music | `plan/music-rebuild.md` | Not covered here | Listen |

Before spending GPU time, write these down for the level: the opponent's silhouette, what the room's lamp light is, the shot's one idea, and its two words. Then run the dry runs, which cost nothing: `art.py build <c> --dry-run --prompts` and `rooms.py compile <room>`.

## 2. World

- **Portrait, 80s to late 16-bit pixel art.** The world is composed at 180 logical units wide. The tap area and HUD stay in screen space, and nothing visual moves them (spec, "readable retro identity").
- **Top shows the dance, bottom is for thumbs.** "The visuals should be independent of the controller scheme."
- **Night, with warm lamplight as every room's accent,** near-black shadows and no pure white. Dusk would run time backwards unless the story explains it.
- **One floor per room.** Each painting maps to the screen with one centred cover transform, and actors and props use the same mapping. Each room has a horizon and a standing-adult height at a reference point (`party_layout.dart`). Height grows with distance below the horizon. Don't tune scale per guest or per frame.
- **Things may spill off screen on purpose.** "Some of our assets will be placed intentionally at spilling over locations, we only need to see some of them."
- **The room is the meter.** No progress bar, no finish lamps. "The party engagement and music are indicators enough."
- **Text appears only in the cinematic highlight** (section 8.4). Feedback uses icons, colour, highlights and sparks.
- **Warm and nonviolent.** Fighting is dance, timing and social play: no damage, humiliation or weapons. Restroom humour is a pictogram and relieved movement.
- **Levels go by "next level".** Old level numbers are dropped. Campaign order lives in `levels/index.json` (garden, pool party, bar, then the indoor party). Add levels, never replace them.

## 3. People

**Canon.** Mācron, Tlatoāni and the rule against inventing Covi are in the spec. Keep them there.

**Names.** The GateKeeper, The Bartender, The Girls, the BlinBlin dancer, the PoolPlayer dancer. "The Girls" is respectful, for women of any age, and a mix of ages is welcome. Use they/them for anyone whose pronouns aren't stated.

**Mācron's own step** comes from the salsa teacher. Don't invent one (`plan/signature-moves-footage.md`).

**Scale.**
- Mācron is .35 of a standing adult's height at his own floor distance, so a nearby toy can look taller than a far-off person. That is the floor projection, not an error.
- Scale a whole atlas from its standing height. People don't grow when they sit. Keep feet, chair bases, occlusion and shadows consistent, and sort everything by floor anchor.
- Opponents stand out by `stature` in the level file (1.02 to 1.14 today) and by stepping forward. It's one number per character, not a per-frame fix.

**Telling people apart.** Named characters differ in silhouette, hair, colour blocking and height. Check them side by side at native size. Check build against the source art on every wave: skeletons pull people toward the rig's proportions, and scorers reward that (lesson A8). "The gatekeeper is chubby again" is the bar.

**Wardrobe at the party.** Visibly grown adults of varied ages and builds. Classy and covered: wrap dresses, full skirts, linen, guayaberas, hems at or below the knee, closed or modest necklines. No pose or framing sexualises anyone. Swimmers wear modest wide-strapped suits or rash tops, are shown from the shoulders up or with arms on the pool edge, and are never the focus of a shot. Framing is whole figure or waist-up, never from robot height toward women characters. Nobody may resemble Covi or a reference person.

**Audience.** Three silhouettes times four outfits give twelve distinguishable guests. Skin, hair, face, anatomy and furniture stay stable, and only the reserved plum and pink cloth ramp changes. Never tint a whole sprite. Stand-up and sit-down clips are mandatory: don't pop between seated and upright, or squash a standing person.

**Crowd arc.** A room starts uninterested and ends engaged. A clean run ends fully engaged, and even a poor run that clears feels warm. Unskilful play costs interest, and flawless play gets the full party. Every room can reach full swing, and reaching it should be easy. Guests join one by one, with their own thresholds and delays, never the whole room on one beat. Pointing is reserved for flourishes and for the change from uninterested to interested. How many stand is in each level's `crowd.budgets` (all 12 today).

**A room that's already dancing.** The indoor party starts with people on their feet in the middle of the floor. The same crowd model runs, so all of the above holds, but uninterested means turned away, in small steps, on their own. Those in the middle slow down and move aside before the first call, and everyone stays on their feet through the win (`plan/levels/indoor-party-2026-11-07.md`).

**How much crowd.** Bar: the large layer at the back with two layers of people in front, on stools. Garden and lawn: many more people sprinkled around, with chairs and tables with drinks. Non-dancers stay outside the dance floor.

## 4. Props

- **Furniture has fixed dimensions per design** and scales on the same floor. The current high-back chair measures .80 adult height, .53 width and .37 seat height. Those describe this drawing, not a universal chair.
- **One drawing, baked per room.** Stools, chairs and tables are sprites on the floor, sorted with the guests. `props.py` bakes each to the room's pixel size and light (`tool/art/rooms/README.md`). A new room needs numbers, not drawings. A level picks its set with `crowd.propSet` and `crowd.seat`.
- **Props can't cover upcoming cue paths** or change anything about input or judging.
- **Held props** carry a hand and clips in the character file. Name the hand by picture side in prompts ("the hand on the left side of the picture"), because "her right hand" gave wrong-hand props.
- **Shared party props are worth the compute:** umbrellas, cups with straws, plants, candles and lights. "It's fine to spend some compute on them."

## 5. Rooms and layers

**Every plate shares one block of words:** `tool/art/rooms/style.json`, `styleBlock`. Don't reword it per room. Change it there, or the rooms stop looking like a family.

**Every room declares** eye height, horizon, vanishing point, phone-safe box and cue zones. Verticals stay vertical. Story elements stay in the central 69% of the plate's width, which is what a 390 by 844 phone shows. The compiler refuses a layout that breaks this (`tool/art/rooms/README.md`, "What the compiler refuses").

**Check per room:** a phone-crop sheet beside the accepted rooms, a floor overlay, and a cast proof with an adult, Mācron at .35 and a prop at near and far marks. Check several screen shapes.

**Layers** are approved: "Yes I approve to separating the rooms in layers, even some of the props might need their own layers". The garden is the pilot, and its route is in that README. Choose props a phone actually shows. Matte by polygon, fill on a tight crop, one prop at a time. This route is for props painted into a plate, since seats and tables are already sprites.

**Words that failed:** the indoor plate's separate floor failed twice in words alone. Glow discs in a guide came back as glowing saucers, so light goes in the words. Plates pass through a person's eye, with lamp marks checked against the painted lamps.

## 6. Sprites

Full route: `tool/art/pipeline/README.md` and the `art-family` skill. The rules that shape the look:

- **The model draws; code makes it pixel art.** A locked palette, binary alpha and a fixed grid come from the finisher, which gives the same bytes every time (lesson A7).
- **Frames:** Qwen-Image-Edit with a model sheet front view and a bare skeleton, 768 by 960, BiRefNet matte, four candidates a pose. Then register, score, review by eye, finish to 256 by 320 (`pixelScale` 3), pack. Style values are in `tool/art/styles/party-pixel.json`: outline `#1A1018`, four-shade ramps, no floor shadow in frames. Mācron has no skeleton, because he isn't human: a sheet view plus words.
- **Use the 2511 Lightning LoRA:** pass `$node:30.lora_name` = `Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors`. Workflows still load 2509 by default. 2511 drew crisper pixels on the same seeds, in two seeds each, judged by eye.
- **Prompts:** describe what you want, because negation backfires ("glasses-free" drew glasses). Prompt and skeleton must agree, or the model draws both. State clothing and age in every prompt.
- **Don't use a mannequin as a reference.** It gets copied (lesson A4).
- **Eyes are mandatory.** Scorers can't see extra arms, lost hands, wrong-hand props or winks. Run the scorer before picking, because it rewrites `selection.json`.
- **Build is not shown.** After integrating, measure which frames a full run really uses before drawing more (lesson B5).

**Sprite sizes in older plans are history.** 32 by 40 and 48 by 64 cells in `plan/assets.md` predate this route.

## 7. Movement and life

- **The music clock owns all motion.** Sample everything from transport beats, never frame counts or timers, so a stall can't drift the dance from the song (lesson B1).
- **Authored key poses, not interpolation.** Planted support feet, unequal holds, follow-through. View changes are drawn, never a flat figure squeezed or rotated.
- **Moves match the music.** Opponents perform the actual limb motif and timing shown to the player. Complexity comes from the chart and grows with the player's skill, never from random gestures. Required inputs outrank every pose. Same input, same score, with cinematics on or off.
- **Handoff.** The opponent stays on the main dance area on Mācron's turn. A spin that overflows its turn finishes mid-floor, and then they step away. Mācron goes back and then to the side, and claps or taps along by the music and the party's heat.
- **The Girls** always dance as a pair on their turn, then one dances with Mācron, alternating. They spin him on flourishes, holding hands. Off turn they step slowly, playing with their skirts, even switching sides.
- **Everything parties up, slowly.** As music and party heat up, plants, umbrellas, waiters, flames and other items come to dance too. Use the quiet-awakening method from sibling project ranitas: new layers fade in at their final anchors, amplitude grows separately, entrances use quintic smootherstep, and nothing starts at full speed. Average players get a warm-ish party, where staff, umbrellas and plants don't dance; the full room is the reward for skill.
- **Calm and safe.** Reduced motion gets held expressive poses, steady lights and the same story. No strobing or full-screen flashes (spec: under three flashes a second). Pause and background freeze the foreground clock.

Research behind this: `plan/crowd-animation-system.md`, `plan/dance-battle-choreography.md`, `plan/party-perspective-and-life.md`.

## 8. Cinematic

The owner: cinematic transitions get their own guide "to stay consistent, and gently flow to the next room".

**What a win looks like.** The music never stops. Mācron celebrates, walks to his mark, the close-up cuts in, contact lands on a beat with its sound and two words, the close-up holds, the wide shot returns with everyone still dancing, and the room dissolves into the next one as its music starts. There's no walk out: "that walking through is no longer needed if we use the cinematic transitions".

### 8.1 Close-up rules

1. **Time is in beats,** counted from the first beat of the success score and running on into the bridge. Nothing in a shot can move music. A shot may depend on a score's length, never on its tempo.
2. **One idea per shot.** A fist bump, a gulp, a kiss. The moment of contact is short; how long the picture holds depends on what keeps moving (rule 7).
3. **Keep sides.** Whoever is on the right in the wide shot stays on the right in the close-up. If a dancer can win on either side, the whole close-up mirrors (`LevelDuet.closeupMirrored`), and lettering such as the āi logo uses `keepsReading`.
4. **Close-ups may cheat scale.** The frame shows only what the idea needs, which spares us a kneeling Gatekeeper or a robot reaching a counter. Mācron shows as his adorable sprite grown large, with a body and the āi logo on his belly, honouring the sprites: "the artwork ... doesn't honor the adorable little sprites" was the complaint about the first gulp.
5. **Limbs and bodies need somewhere to end.** A limb runs off the frame, or a foreground actor (counter, hedge) covers the cut edge.
6. **Reduced motion keeps the same story as held cuts,** with nothing sliding, swaying or thrown.
7. **No dead air.** Every moment of a win has something keeping time. A close-up that holds past its idea needs a reason to hold: frames on the beat, or a `sway`. Once the wide shot is back, every dancer dances until the dissolve. Don't let a pose left over from the close-up hold on the wide shot (this was the lawn's stillness, 2026-11-07).
8. **Return in time for the dissolve.** A close-up ends at least 4 beats before the bridge does, so the dissolve clears the room rather than a close-up (test: "every shipped shot fits").
9. **Glint is reserved** for the finale's high five. Dust is for fists: `dust: false` on anything tender.
10. **No text in the art.** Titles are drawn by the UI.

### 8.2 Art route

- **Puppet chains of moments.** Qwen won't hold a chain of moments, but can hold one change from one reference. Draw one clean key, cut parts or draw eyes and glass by code, and snap to one pixel grid (`art_runs/oil-gulp-v2-20261106/scripts/puppet.py`, `art_runs/closeups-v3-20261106/scripts/rig.py`).
- **Test the flicker away.** Only what should change may change. The lawn's test holds every pixel outside the face and cheeks equal between Mācron's frames.
- **Plates and foregrounds from the room's own painting** cost no GPU and keep the palette.
- **The close-up's view is 180 units wide,** not screen pixels. Check `scale` against that. The scene dims the plate so the actors are the brightest thing on screen.
- **Set fill by volume, not by a y value,** for anything poured.

### 8.3 Shot data

An `exitShot` in the level file is the whole shot, read by `lib/gameplay/exit_shot.dart`. The parser refuses a misspelt field or beats out of order.

| Field | What it does |
|---|---|
| `plate` | Picture behind the close-up, dimmed |
| `celebrateUntil` | Mācron's celebration runs until this beat |
| `walkFrom`, `walkTo`, `heroStep` | His walk to his mark, in floor coordinates |
| `heroWaitFrame` | His drawing between dance and cut. `rear_idle` means facing a challenger |
| `closeupFrom`, `contactBeat`, `closeupTo` | The cut in, the hit and the cut out. Must run in that order |
| `contactPoint` | Where actors meet, as a fraction of the screen |
| `impactBeats` | How long they hold impact drawings |
| `recoilBeats` | How long after contact they finish easing apart. Unset, the whole close-up: set it on a long hold, or the hit drifts too slowly |
| `dust` | `false` for no dust at contact |
| `cue` | One-shot sounds by beat (section 8.4) |
| `actors[]` | Drawn in order, later ones in front |

Per actor: `approach`, `impact`, `contact` (the art pixel that meets the other actor), `scale` (world units per art pixel), `entry`, `recoil`, and optionally:

- `frames`: `{beat, image}` for sub-second moments, replacing approach and impact. `impact` is the still drawing under reduced motion. Put a frame on each sound accent.
- `sway`: `{from, beats, by: [x, y]}`, keeping time through a long hold. It starts and ends at rest. Give a mirrored pair mirrored `by` values.
- `keepsReading`: lettering that stays readable when the shot mirrors.

A duet also has `stage.duet.exit`: `left`, `right`, `leftReach`, `rightReach`, `sideBeats`, `reachFrom`, `reachTo`, `reachFrame`, and `backBeats` and `danceClip` for keeping on dancing at the sides, before the reach and after the close-up.

On a solo level the opponent's dance on the wide shot comes from the shared rules in `assets/art/ensemble/choreography.json`: `celebrationIntro`, then `celebrationLoop`. Their floor mark is `meetMark`. Mācron dances `Celebration` after `closeupTo`. All of this works in beats, so it follows whatever tempo the music has.

### 8.4 Titles and accents

**Title.** "ONLY TEXT FOR THE CINEMATIC HIGHLIGHT, where we get our simple 2 word messages." `copy.clearedTitle` holds two words, one to a line, and the file is refused otherwise. The second word comes from the party and music theme, a synonym or near meaning of cool, swag, mojo or suave: MUCHO MOJO, MUY SUAVE, QUÉ FINO. It slams in on `contactBeat` and stays for at least 3 beats, because a word takes longer to read than a fist takes to land. It fades over the last half beat, either at the end of a long close-up or at contact + 3, whichever is later. A level with no `exitShot` shows the words only on the end screen, if it's the last level.

**Accents.** A `cue` entry's `track` names a one-shot patch from `lib/music/accent_voice.dart` (`bump`, `glug`, `clink`, `peck`), or one of the score's voices. `pitch` transposes around 60, and `velocity` scales it. Patches have energy a phone can play, on their own louder bus. Levels were computed, not heard. Tender moments are softer: `peck` is quieter than `bump`.

**Sound on a stall.** The exit queues .6 s ahead, because the transport never plays a note late. A stall longer than that drops the hit.

### 8.5 The gentle flow into the next room

Built in `lib/gameplay/room_dissolve.dart`, started from `GardenSceneGame.showLevel(dissolve: true)` when the next room's music is really playing, past any count-in.

- **What it does:** the last frame of the old room stays on top of the live new room and clears away. **Never through black.**
- **How long:** 1.2 s, using quintic smootherstep, so there's no speed at either end. Short enough for the new room to be clear before its first call: the shortest intro is four beats at the base tempo (a test holds this).
- **The drift:** the old room grows by 6% as it clears, as if Mācron walks through it. Reduced motion keeps the fade and drops the growth.
- **Safety:** it only draws, so it can't reach the music or the score. It runs on the foreground clock, so it waits through a pause.
- **Sound leads the picture:** the bridge ends and the new room's first bar starts as the dissolve begins.

**Flowing gently means:**

- The room cools under the shot, while the music is cooling down too. The party's swing eases from beat 4 of the success score, and the rest goes when the wide shot returns (`routeAt`), finishing with the bridge.
- Nobody walks out, and no door has to open. A level names no neighbour: the bridge lives in `levels/index.json`, and inserting a level touches only that entry and the one before.
- Bridges carry key and tempo into the next room, so the dissolve doesn't have to hide a jump. Each insertion orphans one bridge.

### 8.6 The pattern: the bar's oil gulp

The owner called the gulp "just a proof of concept for our wiring". Copy it, along with `test/oil_gulp_shot_test.dart`.

1. **Write beats on paper first.** Bar: close-up from 6, the glass changes hands on 8, gulps on 8.5, 9 and 9.5, relief and a hop to 11.5.
2. **Pick a downbeat for contact,** and a sound on it.
3. **Draw with the puppet route** (section 8.2). The counter is a foreground actor so the body has somewhere to end. The bartender slides in by `entry` and leaves by `recoil`, and Mācron has 13 `frames`.
4. **Add data only.** `levels/bar.json` holds it all, with no new code for a new moment.
5. **Test the facts:** the drawings exist, the hit lands on its beat, the sound rises above the music, and the shot fits the music. The shared check is in `test/cinematic_title_test.dart`.
6. **Watch it moving, with sound,** on a phone-sized screen.

**Pitfalls from the wiring** (full table: `plan/cinematics.md`):

| Pitfall | Rule |
|---|---|
| A cue built from the song's own drums was a sine a phone can't play | Use an accent patch |
| On a last level, a close-up past the end of the score never closes, because the beat clock stops with the music | A last level's shot must fit its success score. The bar uses `bar_swag_finale` (16 beats) for this |
| A cue within a quarter beat of a score's end would crash the win | Cues clip now, but keep them clear |
| A win's lone score could lose its cue | `mixCue` runs for both a handoff and a finish |
| Art past the frame shows a cut edge | Foreground actor, or stop the drawing above its edge |

**When the indoor party ships:** point `bar.json` back at `bar_swag_success`, use `bar_to_crowd`, and the bar's shot gets a bridge and a dissolve. Check its close-up then, because it ends at 11.5 of 16.

### 8.7 Shots as built

Beats 0 to 8 are the success score, except the bar's 16; 8 to 16 are the bridge.

| Level | Contact | Close-up | Back to wide | What keeps it alive |
|---|---|---|---|---|
| Garden, fist bump | 8 | 7 to 10 | 10 to 16 | The GateKeeper claps and grooves, Mācron dances |
| Lawn, kiss | 4.5 | 3.5 to 12 | 12 to 16 | In the hold: Mācron's arms and the pair's sway. On the wide shot: the pair step out and dance, Mācron between them |
| Bar, oil gulp | 8 | 6 to 11.5 | 11.5 to 16 | Last level for now, no bridge |

### 8.8 Not built yet

- **Indoor party:** on defeat the BlinBlin dancer takes an arms-crossed stance with an approving nod. Mācron takes a similar stance on the other side of the shot, nods just as coolly and gets approval.
- **Fist bump sugar, later:** better timing and a lightning face-off with a winking eye.
- **Finale:** `plan/storyboard.md` shots E01 to E05, the high five. Should fit the same data, unproven.
- **Opening:** undecided. Needs a story decision first.

## 9. Where this came from

Each of these keeps its own history. This guide replaces them only as guidance: `assets/art/README.md`, `plan/assets.md`, `plan/cinematics.md`, `plan/storyboard.md`, `tool/art/pipeline/README.md`, `tool/art/rooms/README.md`, `tool/art/styles/party-pixel.json`, `plan/research/level3-art-pipeline-2026-11-05.md`, `LESSONS_LEARNED.md`, `plan/owner-rulings-2026-11-05.md`.

## 10. Conflicts settled

| Topic | Older source said | Newer source said | Settled as |
|---|---|---|---|
| Crowd ceilings | This guide's budget table: Garden 3 of 12 standing at most; only VIP gets a whole-room ovation | Sixth and ninth rounds: every room can reach full swing, clean runs end fully engaged, be lenient | Rulings win; table removed. Levels ship 12 of 12 |
| Everything on the beat | This guide: ambient motion is "not every prop bouncing on every beat" | Fifth round: everything parties up, plants and flames too | Rulings win, by slow introduction. "Slow, no strobe" survives |
| Music and cosmetics | Older specs kept cosmetics apart from the score | Fifth round: backgrounds and party follow the score, older specs obsolete | Follow the score. Judging stays untouched by art |
| Opponent on Mācron's turn | This guide and storyboard: yields and watches, may leave the floor | Third round: stays on the main dance area | Stays on the floor |
| Text | Spec and storyboard: "OK, you cool", captions, approvals; HUD words | Sixth and ninth rounds: text only in the cinematic highlight | Two words only. "Chingón" is still open (section 11) |
| Title length | Spec: short approval text | Sixth round: the big word stays, a synonym of cool | Two words, second from the theme |
| Stage order and numbers | Spec and storyboard: five stages in fixed order | Ninth and tenth rounds: garden, pool party, bar, indoor party, "next level" naming | `levels/index.json` is the order |
| Late stages | Storyboard's restroom dash | Ninth round: a late boss, switching places in the bathroom queue by defeating every opponent's hardest combo | Ruling. Each opponent needs a named hardest combo |
| Third level's lead | Next-level plan: lead dancer, foot-stamp | Eleventh round: BlinBlin dancer, arms crossed and a nod | Ruling |
| Walk out | Cinematics storyboards, storyboard, `DepartureRoute`: he walks through the door | Fourth round: remove the walk after a cinematic | No walk when a shot exists |
| Transition | Cinematics draft "no fade to black", storyboard "dissolve" | Queue item and eleventh round: gentle flow | Dissolve as built, never via black |
| Close-up length | Cinematics draft: about 2 beats | Fourth round wanted "a few sub-second transitions"; the lawn's stillness on review | Contact is short, the hold is as long as something moves |
| Bridge beats in the kiss | `lawn_kiss_shot_test`: the whole shot fits 8 beats, as the lawn was last | Campaign order: the lawn now has a bridge | Fit the music that plays it; only a last level must fit its success score |
| Pixel size in close-ups | Cinematics draft: same pixel size as the world | Tenth round: Mācron drawn large, with body and logo; the owner liked the composition | Not fully settled, flagged in section 11 |
| Draft room rules | This guide's "not yet approved" additions | `tool/art/rooms/style.json` and the compiler use them. I found no explicit approval, but the owner has played these rooms without objecting to them | Treated as working rules, not a ruling. Words live in `style.json` |
| Sprite route | `plan/assets.md` and cheatsheet cells; SDXL route; `art.py` targets SDXL | Lessons and `party-pixel.json`: Qwen, `backend: qwen-frame` | Qwen. SDXL only for masked repairs |
| LoRA | Lesson A3: 2509, "unproven on 2511" | Handoff: 2511 via `$node:30.lora_name`, judged crisper | 2511. Still only 2 seeds each, by eye |
| Prompt override | Pipeline README and lesson A1: `$prompt` doesn't reach the node | 2001-stpr fixed, proven on tray 56.11.6.2 | New work may use `$prompt`. Old workflows stay baked |
| Art Python | Pipeline README and skill: `~/.cache/kumbia-art` | Handoff: `~/.cache/tillandsias-project/venvs/kumbia-art` | Newer path. Both docs corrected |
| Chairs | `plan/adding-a-level.md`: each guest gets a chair | Tenth round: stools at the bar | `crowd.seat` chooses |

## 11. Where the game disagrees with this guide

Flags for the owner or the next person. Nothing here is changed yet.

1. **The crowd sits down during the wide shot.** Guests start settling at about shot beat 6 (`exitCodaBeat`, four beats after the music's handover, then two more, spread by guest). In rendered frames most are seated by about beat 11, on both the garden and the lawn. `warmDown` also holds the party's swing under half from beat 8. So the dancers now dance in front of a seated room. It follows an older rule ("departures finish each guest's gesture, then sit"), but it's the largest still thing left on a wide shot. Proposed, not done: count the coda from `closeupTo`. That's crowd and `garden_page.dart` work, which other agents hold today.
2. **Close-ups have three pixel sizes.** World units per art pixel on a phone: garden fists 1.1 and 1.3, lawn .36, bar .31, against plates of about .95 (garden) and .55 to .6 (lawn, bar). That breaks "same pixel size" from the draft, and the garden's fists are much chunkier than the other two. The owner liked the fist bump, so it's a question, not a fix.
3. **Not all sprites use nearest-neighbour.** The spec requires it. Mācron draws with medium filtering, and the Girls with low, so scaling doesn't crawl (`garden_scene.dart`). The code comments say it keeps them steady. It's a choice to make explicit, in the spec or in the art.
4. **The HUD still shows "01 / 05".** `displayTotal` is 5 in a three-level campaign. Rulings said text only in the cinematic and drop numbering. The end screen, too, has text, though the owner said to leave it for now.
5. **The finale's "Chingón" is one word, as a caption.** The spec requires it, and the ninth round says two-word messages only. Needs a ruling when the finale is built.
6. **`departure` is required on every level, but unused when a shot exists.** `exitTravel` stays 0, so `waypoints` and `threshold` are dead data on all three. A new level author must still write them. Doors in plates and old storyboards suggest walks that no longer happen.
7. **The spec is behind.** `art-direction/spec.md` still requires five stages in a fixed order, approval text and a 1 to 2 bar acceptance, against the rulings. Update it through an OpenSpec change; it's a contract, so this guide didn't.
8. **Mācron crowds the GateKeeper after the bump.** He stands under their feet, without overlapping, on the wide shot (`meetMark`, `heroStep`), and he stays there. Seen in frames and already noted on 2026-11-06.
9. **The lawn's Girls are close to the crowd behind.** At the sides they overlap seated guests' heads in the phone view. It reads fine in still frames, but needs a moving look.
10. **Rendered music and cues.** Cues mix into synth scores today. Whoever moves the game to rendered audio has to keep the accents on their own bus, on the beat. Shots need only the beat clock and each score's length in beats.
