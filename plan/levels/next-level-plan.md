# Next level plan: `cool-crowd`, and a heavier pipeline test

**Draft, 2026-11-06, for the owner. Nothing here is approved yet.**

**Owner's answer, the same day:** old level numbers are dropped and levels go by "next level". This room is the next level, the indoor party, after the garden, pool party and bar. Section 1's question is settled. The bathroom rush moves late, with more levels before it, possibly as a boss battle: "defeat every previous opponent in their hardest dance combo to switch places in the bathroom queue". So every opponent built from here on should have a named hardest combo in its data, ready for that level. `plan/owner-rulings-2026-11-05.md`, ninth round.

Labels: **[F]** fact, checked in the repo or a tool. **[P]** my proposal. **[E]** my estimate, built from the measured number it names.

## 1. Which level is next

**Recommendation: build `cool-crowd` (Dance room, Flow) next. Keep the restroom's country-into-metal brief for the level after it, and spend 2 minutes of GPU now to hear whether that brief can work.**

"Level 4" names two different levels, because the numbers moved:

| Source | What it says | When | Reading |
|---|---|---|---|
| `plan/level-3-readiness.md:121` | "Level 4, Restroom / Nerve (owner, 2026-11-03): the rush level. A chill country backdrop beat builds into a heavy metal score, over a Latin rhythmic base" | Before the pool | That file's Level 3 is `cool-crowd`, so its Level 4 is the level *after the crowd* |
| `plan/asset-pipeline-requirements.md:253-255` | "Level 4 (restroom dash, storyboard R01) is the candidate for a **side-on** level" | 2026-11-01 | Same old numbering |
| `plan/owner-rulings-2026-11-05.md:8` | "Cool Crowd stays, and the pool garden is a new level" | 2026-11-05 | Added a level; dropped none |
| `plan/campaign-sheet.md:10-11` | Order 4 `cool-crowd`, order 5 `restroom`, with the pool as "3, proposed" | 2026-11-05, draft "for the owner to approve" | Numbers shift by one |
| `levels/index.json` | Plays garden, bar, `pool-garden`. The lawn's exit line is "THE MANSION IS NEXT" | Today | The lawn already leads indoors |
| `plan/research/level3-design-research-2026-11-05.md:47` | "Use stable names, not numbers" | 2026-11-05 | This plan uses ids from here on |

Why `cool-crowd`:

1. **The restroom has always followed the crowd.** That holds in both numberings. The story needs it too: C01 ends with a "rear walk toward restroom pictogram", and `room_departure.dart` sends `cool-crowd` to `restroom`. [F]
2. **It tests backgrounds harder, which is what the owner asked for.** The restroom's proposed role is "a nearly still corridor", wake step 2. `cool-crowd` is step 5 (`plan/research/progression-and-adornments-2026-11-06.md`). [F, proposed there]
3. **The restroom's camera is the pipeline's weakest spot.** Side-on needs profile views of Mācron, and his side view kept 0 of 4 and his walk cycle failed (`plan/research/closeups-and-macron-pilot-2026-11-05.md`). The room compiler's camera has no side-on mode. [F] That is new tooling, not a heavier run of the pipeline we have.
4. **It has a head start.** `tool/art/rooms/ballroom.json` and 6 trial plates exist. They are weak (see 3.2), which makes them a useful baseline. [F]

**The one question for the owner:** when you say Level 4, do you mean the next level in play order (`cool-crowd`), or the country-into-metal rush (`restroom`), even if it's built first?

**If the owner says restroom** (Corridor, Nerve, 45 s, 132-144 BPM today):

- Add a side-on camera to the compiler, and draw profile sheets for Mācron and the attendant first. Budget a pilot: this route has already failed once.
- Backgrounds become a strip plus parallax. The party-up and prop stages shrink, since the room is meant to stay near still.
- Music becomes the main test, starting from the probe in 3.6.
- The room can be built out of order, but the lawn would need a bridge to it and the crowd's slot stays empty. The level would also lack its setup, Mācron's polite weight shift at the end of the crowd.
- Title idea: QUÉ AGUANTE ("what staying power"). [P]

## 2. The design

**In short:** a cool circle of dancers shuts Mācron out. He wins them by landing the off-beat, until the whole room answers him.

| Field | Design | Status |
|---|---|---|
| Id, order | `cool-crowd`, after `pool-garden`, before `restroom` | [F] sheet draft |
| Place | The mansion's dance room at night: dark polished floor, violet panelling, cream pilasters, a low empty bandstand, a corridor arch at the far end. Angled to the top left, mirroring the lawn's top-right diagonal | [F] sheet; layout [P] |
| Respect word | Flow | [F] `progression.dart` |
| Cinematic title | **QUÉ FLOW** ("what flow"). It matches MUCHO MOJO and PURO SWAG, whose second word is the respect word. Alternatives from the party and music theme: PURA CANDELA, MUY SABROSO | [P] |
| Music style | Latin boogaloo with a salsa-disco lift. Sly and cool at first, the whole circle in unison at the end | [F] draft style |
| Budget | 95 s by the sheet. This ladder computes to about 87 s clean: 11 phrases of 16 beats plus a 4-beat intro | [F] budget; [E] arithmetic |
| Palette | Violet, cyan, cream, with amber lamps from the shared style block. Cyan only as light on glass and walls, the way turquoise is kept to the pool | [F] colours; rule [P] |
| New idea, only one | **The off-beat push:** the phrase starts on the beat and then slips off it, while the circle's claps hold the beat so the player can feel the gap. At the top tiers the circle copies Mācron back, unjudged | [F] sheet's idea; form [P] |
| In | From the lawn's gateway, a bridge into a closed semicircle with their backs half turned | [P] |
| Reset | "Crowd closes and robot shuffles to outside", 2 beats | [F] `C.reset` |
| Out | Earned moment, then a cut to the corridor. Just before it, Mācron politely shifts his weight to set up the restroom | [P], per design research |

**Text.** The only words on screen are the two-word title, in the earned moment. Other copy fields stay as hidden labels or get dropped. [F] line 88 of the rulings removes text "everywhere", and line 93 keeps the big word; see section 6 on the wording.

### Music brief (genre and instrument words only)

Tags for all tiers: `cool midnight Latin boogaloo with a salsa-disco lift for a circle of dancers, instrumental`, plus the tier's own words below. Key request `D minor`, closest to today's D dorian score. [F] The model treats key as a request, so measure it per take.

| Tier | BPM [P] | Added words | Phrase | Call |
|---|---|---|---|---|
| 0 | 112 | walking upright bass, handclaps on the backbeat, soft congas, sparse and sly | 8.57 s | Hands |
| 1 | 118 | adds piano montuno, marimba call | 8.14 s | Hands, then feet |
| 2 | 124 | adds flute answer, timbales, cowbell | 7.74 s | All four |
| 3 | 130 | adds muted brass, strings | 7.38 s | All four, shifting |
| 4 | 136 | full arrangement, brass and strings, disco four-on-the-floor kick under the clave | 7.06 s | Everything, 3 proof phrases |

The sheet proposed 112-124. I raised the top because the sixth round says "Let's try to keep the speed up", and the sheet predates it. It still starts below the lawn's 128, so the arrival is a breath after 160. If a person's thumb says otherwise, 124 is the fallback (see below). [P]

### Chart [P], only a person can approve it

- **Offsets `[0, 1, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5]`, limbs `LF LH RF RH` repeating**, C01's opening pattern. Two notes land on the beat, then everything after the pair sits off the beat. That is the recognisable shape.
- Eight notes, because the peak's 87.5% rule only forgives a miss at eight or more. [F]
- **The one risk:** LH to RF is half a beat, 221 ms at 136 BPM. The bar's tightest gap is 268 ms and the lawn's is 281 ms. [F] Play this first on a phone. At 124 it is 242 ms.
- **Optional play:** a flick on the last note, and one optional clap at 7.25, the only quarter-beat position that clears the report's 285 ms rule here. A level's optional taps and drags need `lib/` work, and ignoring them costs nothing. [F] rule; [P] placement

### Cast

Describe what is there, name the build outright, and state age and clothing in every prompt. Negation backfires. [F] Placeholder pronouns are they/them until the brief says otherwise.

| Who | Drawing notes [P] | Scope |
|---|---|---|
| Lead dancer | Tall, lean, angular adult of about forty-five. Cream cotton guayabera, long open midnight-violet jacket, slim dark trousers, polished two-tone cream and dark shoes, because the close-up shows them. Slow, unimpressed half smile | Full 64 poses, plus a jacket-sweep invite |
| Left flank | Short, round, cheerful woman of about sixty. Cyan-teal wrap dress below the knee, silver hair up, cream shoes | 14 poses (the inventory's 12 + 2) |
| Right flank | Broad, stocky man of about thirty-five. Plum guayabera, cream trousers, dark shoes, big hands that clap | 14 poses |
| Ring guests | Existing `guest0`-`guest2` | Standing poses needed |
| Mācron | Existing, plus a foot close-up. `signature_step` stays reserved | No turned views as references |

Check them together at native size: they must read apart, Mācron must stand out, and nobody may resemble Covi. [F] from the readiness plan

### Earned moment [P]

| Beat | Shot | Sound |
|---|---|---|
| 0-3.5 | Wide: the circle opens, and the lead steps aside facing Mācron | Cooling groove, claps thin out |
| 3.5-6 | Mācron steps in. Slot for the lead repeating the **signature step** once the teacher's video exists | Clave alone |
| 6-8 | Extreme close-up at floor level: the lead's polished shoe from the right, Mācron's steel foot from the left. Legs run off frame | Pickup |
| **8** | **Both feet stamp on the downbeat.** One impact frame, no glint. Title **QUÉ FLOW** | **Heel stamp plus rim click, then a two-clap answer from the whole circle** |
| 9-11 | Back to wide: the lead gives one slow nod, and Mācron shifts his weight | Bridge leads the cut |

This fits the `exitShot` data that the garden and bar already use, with `closeupFrom`, `contactBeat`, `actors` and `cue`. [F] The shot doesn't define the signature step, so nothing is invented, as ruled. The rewards ladder goes fist bump, oil, nod, feet, key, high five. [F, feet P]

### Party-up and full swing in this room

Ruling: "average players should get just a warm-ish party", staff, umbrellas and plants don't dance for them, and "skillful play should be clearly rewarded". The room replaces the progress bar. [F] The table's content is [P].

| Tier | Everyone who clears | Heat 2-3 only |
|---|---|---|
| 0 | Circle closed, arms folded, side-eyes. Lamps still | |
| 1 | One flank notices: "oh! look!" and points, the one permitted use. Lamps breathe | |
| 2 | Circle claps the backbeat, ring guests turn in. Soft wall light starts | Ring guests clap too |
| 3 | Flanks step in time, candle shapes wake. Budget: 8 interested, 7 following, 5 standing | Palms sway, waiter steps in time |
| 4 | The circle mirrors Mācron, 3 cheering. **Warm-ish:** a good party, with the furniture holding still | **Full swing:** straws dance in the cups, lanterns swing, and everything hits a shared accent every 2 bars |

Limits:

- **Moving light must stay out of the way.** Nothing moves in the tap band (y 0.65-0.97), the area behind the opponent (x 0.35-0.65, y 0.3-0.6) stays quiet, and light never flashes. [F] So disco light goes on the side walls and windows. It can't sweep across the floor as the old brief implies. [P]
- **Glint is reserved for the finale.** [F] So this is soft moving light, not sparkle. [P]
- Everything follows the fifth round: fade in at the final position, grow movement separately from zero, quintic entrances. Reduced motion keeps the room still. [F]

### Shared layered props

Existing, in `assets/art/ensemble/`: umbrella, plant, candle and waiter (4 frames each), chair, table. [F] New props to draw once and reuse in later levels, as the owner approved spending compute on them: [P]

| Prop | Frames | Used here | Later |
|---|---|---|---|
| Cup with straw | Rest + 3 dance | Ring tables, Heat only | Bar, lawn, VIP |
| Hanging lantern | Rest + engine swing | Ceiling | Garden, bar, VIP |
| Candle, new flame set | 4 shapes, same brightness | Tables | Everywhere |
| Potted palm, new | Rest + 3 sway | Side columns, Heat only | Lawn, VIP |
| Mirror ball, if Q2 is yes | 2 | Ceiling, off the quiet column | Possibly VIP |
| Cocktail table, standing height | 1 | Ring | Lawn |

A new prop kind still needs code, because kinds are a switch. [F] `plan/adding-a-level.md`

## 3. The pipeline test

Every stage is one GPU job at a time. Finish a stage's review before the next stage's spend.

### 3.1 Measured numbers these estimates rest on

| Measure | Value | Source |
|---|---|---|
| Qwen job of 4 at 768x960 | **About 59 s**, or 12 s an image after a 21 s first | `closeups-and-macron-pilot` |
| Qwen at 1168x1648 | About 19 s an image; a second reference adds about 7 s an image | Same |
| Qwen plates at 832x1248 | 12-19 s an image, 29 s for the first, across the probes. 40 steps took 389 s | `level3-art-pipeline` |
| `art.py` dry-run figure | 92 s a job, about 1.5x too high on this host | Same pilot; backend file still says 92 |
| A pilot run, real against planned | 19 jobs: 18.8 min real, 29.1 planned | Same |
| Close-up run | 86 images, 27.5 min | Same |
| Images to reach one draft plate | 56 for the lawn (runs a-d) | Counted on disk |
| ACE-Step take | 10-11 s for 88 s, on this RTX A5000 | `relaunch-report` |

### 3.2 Stages

| # | Stage | Workflow | Work | GPU [E] | Gate |
|---|---|---|---|---|---|
| 0 | Room spec | None | Write the spec in 3.3, compile, read `overlay.png` | 0 | Compiler passes; a person accepts the layout. Trial compile passed in a scratch folder |
| **1** | **Plate proof** | `rooms.py` over `tool/art/workflows/qwen-frame.api.json`, 832x1248 | **8 pass 1, then 2 picks x 4 pass 2 = 16** | **About 5 min** | See 3.3 |
| 2 | Music pilot | `tool/music/workflows/ace-xl-turbo.api.json` | 12 takes at tier 2 | About 2 min | At least 3 of 12 pass `measure_takes.py --bpm 124`, then the owner listens against the synth |
| 3 | Restroom music probe | Same | 12 takes, 3 tiers | About 2 min | Owner's ear only |
| 4 | Plate finish | As stage 1 | Up to 40 more, matching the lawn's 56. Scale to 1024x1536 Lanczos | About 13 min | Owner accepts beside garden, bar and lawn at phone size; floor overlay checked |
| 5 | Layers | Masks from `ids.png` on CPU; 8 Qwen images to try a lamps-off pass | Occluders, emissive maps, wall light | About 3 min | Lamps sit on painted lamps; tap band unchanged; nothing moves in the quiet column |
| 6 | Shared props | Qwen with BiRefNet nodes, 768x960, chained frames | About 24 jobs of 4 | About 24 min | Same object across frames, by eye; reads at native size on two rooms |
| 7 | Sheets and lead pilot | `art.py`, then `qwen-frame` | 3 characters x 2 views, 6 hard lead poses | About 12 min | **Owner approves sheets**; build check passes |
| 8 | Lead wave | Same | 64 jobs | About 63 min (dry run will say about 100) | Look at every candidate; stop and look at any build advisory |
| 9 | Flanks | Same | 28 jobs | About 28 min | Group check at native size |
| 10 | Close-up | Qwen 1168x1648, chained; plate from a CPU guide | 2 actors x 3 frames x 4 = 24, plus a wording round | About 16 min | Viewed moving on a phone-sized screen |
| 11 | Ladder and stingers | ACE workflow | 8 takes x 5 tiers, then 12 x 3 pieces (success, 2 bridges) | About 14 min | **Owner hears one song growing, not five songs** |
| | **Total** | | | **About 3 h, plus about 25% for redraws** | Review time will exceed compute |

All GPU figures are estimates from 3.1, with no queue waiting. Stage 1 is 16 images at 19 s, the slow end of the measured range; another 2 minutes wouldn't be a surprise. Stage 2, 3 and 11 times assume a shorter take costs no more than an 88 s one.

**Which stages teach the most, in order:**

1. **Stage 11's ladder.** Nobody has heard one, and music rebuild stage 4 hasn't started. A failure changes every level's music, for about 14 minutes of GPU. [F] Independent takes are the only route in the current workflow, and the research names their risk as five songs.
2. **Stages 1 and 4, an interior in a colour family no room has.** The ballroom's first plates came back with flat pink floors, with chandeliers reappearing on the floor. If the wording fixes that, "a room is data" holds indoors.
3. **Stage 5, real layers.** The report calls these the biggest missing foundation, and the route is unproven beyond a pool's columns and water.
4. **Stages 7-9, a group.** Three dancers plus a ring, composed at native size. This is the first test of more than a pair.

### 3.3 Run this first: the plate proof, about 5 GPU minutes

Stage 0 and stage 1 together. No later stage depends on music or characters, and it answers the owner's "start rendering backgrounds" directly.

**Spec.** Copy `tool/art/rooms/ballroom.json` to `tool/art/rooms/cool-crowd.json`. Keep its `camera`, `phone`, `safe`, `tapBand`, `cast`, `walkable`, `standable`, `styleRef` (`bar`) and `paint`, except for the stage line below. No new zone ids are needed, since `colourNames` already has them all. The compile gave Mācron 34.5 logical px at his mark, against the lawn's 34.8. [F]

```json
{ "id": "cool-crowd", "title": "THE DANCE ROOM",
  "paint-change": { "kind": "box", "id": "stage", "s": [8.4, 10.9], "t": [-2.5, -1.05], "z": [0, 0.7] },
  "story": [ { "name": "corridor-door", "ids": ["door"], "ignoreTop": true },
             { "name": "bandstand", "ids": ["stage"], "ignoreTop": true } ],
  "marks": { "heroHome": [1.04, 0], "heroEntrance": [0.4, 0.05], "heroRetreat": [0.7, 0],
    "challengers": [ { "id": "gatekeeper", "atlas": "gatekeeper", "mark": [3.0, 0], "yieldMark": [3.2, -0.8] } ],
    "pathEnd": [10.6, 0],
    "route": [[1.04, 0], [1.3, -0.3], [3.5, -0.2], [6.5, 0], [10.6, 0]],
    "guests": [[2.7, -1.05], [3.4, -0.95], [3.4, 0.95], [2.7, 1.05], [4.3, -1.5], [5.2, -1.6], [4.3, 1.7], [5.2, 1.8]],
    "plants": [] } }
```

`paint-change` is a note, not a field: edit the existing stage entry. Moving the bandstand aside clears the corridor arch as the real exit. `gatekeeper` stands in until the lead's atlas exists.

**Words.** Set `keep` to `every wall edge, window, pilaster, the far bandstand and doorway, every floor joint and the horizon`, and set `scene` and `zones` so the compiler generates exactly the two prompts below. Those texts are the brief. Each zone's `layout` is a sentence of pass 1, and its `paint` a sentence of pass 2.

**Pass 1 prompt** (image 1 the greybox, image 2 the bar as style only):

> Image 1 is a flat colour layout that fixes the exact composition. Image 2 shows the art style only: its painting technique and its palette, while every building and every shape comes from image 1. Repaint image 1 as one finished game background, a richly detailed late 16-bit pixel art night painting with very fine small pixels and high detail, moody low-key lighting, deep soft shadows, restrained muted natural colours and warm amber lamp glow, painterly and grown-up in tone, close to near-black in the shadows. Keep every shape of image 1 in the same place and at the same size, including all perspective lines. It is the mansion's dance room at night, seen at an angle: a grown-up, intimate hall of deep violet shadow, warm cream plaster and low amber lamps. The dusty rose area is a dark polished stone dance floor running diagonally from the bottom right to the top left, with the same grid as image 1. The plum area is dark carved wood panelling. The bright orange area is a tall doorway at the far end. The steel blue area is tall arched windows on the left wall. The cream area is carved pilasters on the right wall. The red area is a low bandstand at the far left. The bright yellow area is glowing chandeliers hanging from the ceiling. The whole place is an empty, quiet set just before the party arrives: bare ground, still water and clear air, and every surface is plain stone, wood, foliage, water or sky.

**Pass 2 prompt** (no reference image, on purpose; a reference in pass 2 has taken over the layout before):

> Image 1 is an unfinished game background. Keep the composition of image 1 exactly: every wall edge, window, pilaster, the far bandstand and doorway, every floor joint and the horizon stay at the same place and size. Repaint image 1 as a richly detailed late 16-bit pixel art night painting with very fine small pixels and high detail, moody low-key lighting, deep soft shadows, restrained muted natural colours and warm amber lamp glow, painterly and grown-up in tone, close to near-black in the shadows. The floor is plain dark polished stone, nearly black with a violet cast, in large square slabs with thin straight joints: the joints stay exactly where they are, with fine mottled texture and long soft blurred streaks of warm lamplight near the far end, and it lies open, calm and clear from end to end down to the bottom edge of the picture. The walls are deep violet-plum lacquered wood panels with finely carved ornament, in soft shadow, with small warm wall sconces and thin cream mouldings. A tall cream stone archway at the far end opens onto a dim warm corridor, seen only as soft amber depth. Tall arched windows with fine leaded glass show deep blue night, with a thin cool cyan edge of moonlight lying on the glass only. Carved cream pilasters run along the right wall, lit warm from below. A low dark wooden bandstand with deep violet velvet curtains in fine pleats stands empty at the far left. Small amber lantern chandeliers with fine metalwork hang high in the air. The whole place is an empty, quiet set just before the party arrives: bare ground, still water and clear air, and every surface is plain stone, wood, foliage, water or sky.

The last sentence comes from the shared `emptySet` in `style.json`, and it mentions water and foliage indoors. A spec can't override it today. Leave it for the proof, and fix it if foliage appears. [F]

**Queue it**, with `PY=~/.cache/tillandsias-project/venvs/kumbia-art/bin/python`, from `tool/art/rooms/`:

```bash
$PY rooms.py compile cool-crowd     # then look at art_runs/rooms/cool-crowd/overlay.png
$PY rooms.py plan cool-crowd --run room-cool-crowd-v1-a --pass 1 --count 8 --seed 987000
# studio.run_workflow for each entry of jobs-p1.json, one at a time
$PY rooms.py collect --run room-cool-crowd-v1-a
$PY rooms.py verify --run room-cool-crowd-v1-a
$PY rooms.py sheet cool-crowd --run room-cool-crowd-v1-a --glob 'p1-*'
# pick the 2 cleanest first passes from the cache, then:
$PY rooms.py plan cool-crowd --run room-cool-crowd-v1-a --pass 2 --count 4 --seed 987100 --from A.png B.png
# queue jobs-p2.json, collect, verify, then sheet with --glob 'p2-*'
```

Seed 987000 is unused by earlier room runs. [F]

**Go on to stage 4 if**, at phone size beside the garden, bar and lawn:

- At least 2 of the 8 pass 2 plates hold the door, bandstand and floor joints. The lessons expect about a third to hold.
- The floor is dark and calm through the tap band, with no flat pink, no floor discs and no moon patches. These were all failures in the ballroom's first run.
- It reads as violet without leaving the family. Guide: saturation at most 0.8, value 0.22-0.28. The sheet numbers only help: `d` is unreliable on reflective floors, and no gate sees people or lettering.

**If it fails**, change the words or the guide and run again. The price of a retry is about 5 minutes. Only a repeated failure on the floor should raise the question of 40-step or another route.

**Optional, about 1.5 min:** the 2511 Lightning LoRA is on disk now, while `qwen-frame.api.json` still loads the 2509 one, which was built for an older model. [F] Four images at the same seeds would settle this long-open question, but `plates.py` needs a way to name the LoRA first. Don't hand-edit a character workflow for it.

### 3.4 Layers, stage 5 [P]

`Qwen-Image-Layered` isn't on this host, and `studio.models` doesn't list it. [F] Its template works at 640 px, too small for a plate, so I wouldn't wait for it. The earlier lesson also applies: skip four parallax layers for a fixed camera until someone misses them.

| Layer | From | Evidence |
|---|---|---|
| Plate | Stage 4 | Proven |
| Occluders: pilasters and bandstand in front of guests | `ids.png` masks | Proven on the pool's columns |
| Emissive: lamps, door, windows | Id mask intersected with really bright pixels | Same method as the water mask, which measured 71-73% coverage |
| Lamps-off variant, to subtract for true light | A third Qwen pass | **Untried; may shift the room** |
| Wall light | Runtime overlay, clipped to `panel`, `window` and `pilaster` | Untried, cheap |
| Props | Floor-anchored sprites | Proven for chairs |

### 3.5 Characters and close-up

- **The rig runs in the forge now.** I imported `bpy` 5.2.3 from `venvs/kumbia-bpy`. So new skeletons needn't be borrowed, unlike the swing pair's. [F] The gap is in the library, which has only `stocky-adult`, `slim-adult` and `macron`, and no jacket garment. [F] Add a tall body preset and a jacket, then render the rig before the pilot.
- **Pilot poses for the lead:** `clap.contact`, a groove down, a turn, a hard hand peak, and the two jacket-sweep poses.
- **Close-up:** draw the contact frame first and chain the others from it, one actor at a time. Say the visible thing and leave motion to the engine ("bounced" drew motion lines). The plate is a 584x824 CPU guide with this level's own palette.
- **Foot shots have never been drawn.** One probe already showed a sole on Mācron that he isn't meant to show, so pilot his foot before the lead's shoe.

### 3.6 Music runs

**Stage 2, pilot.** Seeds 53000-53011. Overrides:

- `$node:94.tags`: `cool midnight Latin boogaloo with a salsa-disco lift for a circle of dancers, instrumental, walking upright bass, piano montuno, congas, timbales, cowbell, handclaps on the backbeat, marimba call and flute answer, muted brass`
- `$node:94.bpm`: 124; `$node:94.keyscale`: `D minor`; `$node:94.duration` and `$node:98.seconds`: 77.42 (40 bars)

**Stage 3, restroom probe.** Seeds 54000-54011, 4 takes per row. The point is to learn whether the model holds a Latin base under this style change.

| Tier | BPM | Tags |
|---|---|---|
| 0 | 132 | `relaxed country shuffle over a soft Latin rhythm, instrumental, pedal steel, acoustic guitar, brushed snare, congas, tumbao bass` |
| 2 | 138 | `driving country rock over a Latin clave, instrumental, overdriven electric guitar, pedal steel, full drums, congas, tumbao bass` |
| 4 | 144 | `heavy metal over a driving Latin clave, instrumental, palm-muted distorted guitars, double kick drum, timbales, congas, tumbao bass` |

**Stage 11, ladder.** The words and tempos from section 2, with 8 seeds each and whole-bar durations. Keep the same caption stem and key request throughout.

Masters go to `~/.cache/tillandsias-project/kumbia-audio/`, never in the tree. Only MP3 or other compressed formats reach git, once approved. [F]

### 3.7 Known limits

| Area | Limit | Handling |
|---|---|---|
| Qwen, words | Taken literally. Negation backfires, and CFG 1 ignores negatives | Describe what is there |
| Qwen, plates | Adds lanterns freely. Pass 2 moves things. Glow discs turn into objects. Draws its own larger "pixels", so there's no true grid | Light goes in the words; a person picks by eye |
| Qwen, frames | Height isn't controlled by skeleton. Skirts jitter, and the rig has no skirt | Scale per character; review as clips |
| Qwen, Mācron | Turned views go boxy, side kept 0 of 4, and a walk cycle fails from words alone | Keep him to front and rear here |
| Scorer | Assumes trousers, sees no extra arms | Look at every candidate |
| ACE tempo and key | Both only requests. Half-time grooves are reported | Filter rejects anything over 1.5% off or half-time |
| ACE layers | No lock across takes. `extract` needs a base model, and XL base isn't pinned | Whole takes per tier; party sounds as samples |
| ACE listening | Only 30 s excerpts have been judged, at one tempo per room | Judge whole takes in stage 11 |
| Durability | `/work/tmp/imagegen` goes with the forge | Collect during a wave |

## 4. What must be built for it to play

None of this needs GPU, and all of it is outside this plan's stages. [F] unless marked.

- **Rendered music isn't in the game yet.** Rebuild stages 3-6 are open, and stage 3 needs the owner's phones. Until then the level would run `crowd_duende`, which fails the score gates and which the owner's rulings have moved past.
- **Three challengers.** `garden_scene.dart` loops over challengers with a `duet` flag; only a pair has run. Three is untested. [I read the code, didn't run it]
- **Standing guests,** a ring formation, and a group phase offset.
- **A new `cool-crowd` entry** in `levels/index.json`, `bridgeToNext` on the lawn, new atlas ids in `EnsembleManifest.atlasIds`, and the art folder in `pubspec.yaml`.
- **The room as meter:** Heat, wake steps, and removing the top bar. These cross all levels, so they're better built on the lawn or bar first.
- **New prop kinds,** and the wake rule that holds plants and staff back from average players.

## 5. Owner questions

Only those that change the work. Each has a default, so stage 1 doesn't wait for any of them.

| # | Question | Default | What changes |
|---|---|---|---|
| 1 | **"Level 4": next in play order (`cool-crowd`), or the country-into-metal rush (`restroom`)?** | `cool-crowd` | The whole plan; see section 1 |
| 2 | Does disco light stay as this room's motif? It can only live on walls and windows | Soft moving light, no mirror ball until you see it | One prop, one layer, and prompts |
| 3 | Is the lead's jacket worn over a guayabera? | Yes | A new rig garment and sweep poses, or none |
| 4 | Can the ladder top out at 136, if the 221 ms pair survives your thumb? | Yes, with 124 as the fallback | Five tempos and one chart |
| 5 | Will this level ship with the step slot empty if the teacher's video is late? | Yes: stamp and nod now, step added later | Whether the level waits on the footage |

Not asked here, though still open: the campaign's length and acts (`plan/campaign-sheet.md`, about 8:37). This level's cost doesn't depend on it.

## 6. What I couldn't find or confirm

- **The title ruling's wording.** "Text only in the cinematic highlight, a two-word title" isn't in `plan/owner-rulings-2026-11-05.md` or any branch I searched. Nearest are line 88 ("get rid of text messages everywhere") and line 93 (the big end-of-level word stays). MUY SUAVE and QUÉ FINO appear nowhere in the repo; I took them from the request. The owner should confirm. MUCHO MOJO and PURO SWAG are shipped.
- **Whether the owner has seen the ballroom plates, or approved the campaign sheet.** No record of either.
- **Per-frame timings for the swing, Gatekeeper v4, spin and oil-gulp waves.** Sidecars carry no timing and cached file times were reset. The only per-job numbers are in 3.1, and 832x1248 has a range rather than one measurement.
- **Stage 6's route.** I found no prop definition route in `art.py`, so props would use run scripts, as the spin and oil gulp did. `studio.finish_pixels` wanted a family spec; close-ups got by with research-only family files.
- **`cover` from a ComfyUI node.** The research's preferred anchor ladder needs it, and the current workflow doesn't use it. I didn't test whether the studio exposes it.
- **Stale notes I left alone**, as asked: `plan/adding-a-level.md:42` says later challengers aren't drawn; `plan/comfyui-cheatsheet.md:262` says the 2511 LoRA isn't on disk; the runtime section of `plan/level-3-readiness.md` predates the level registry.
- **No phone evidence.** None of this has been played, heard or seen on a real phone.

## Plate proof result, 2026-11-06

Not passed, after 40 images and 761 s of GPU over three rounds. `tool/art/rooms/cool-crowd.json` now holds the last round's words, stage block and guest marks, so section 3.3 no longer matches it. Prompts for each round are in `art_runs/room-cool-crowd-v1-a/workflows/`.

- **Fixed:** the hard diagonal wedge fell from 8 of 8 first passes to 0 of 8 after pass 2, after dropping "running diagonally". The guide and colour words changed in the same run, so that isn't proof. Dropping "curtains" and "moonlight" removed the canopies and moon patches. Naming the left wall kept the windows there.
- **Not fixed:** colour swung from too dark (floor luma 5-12) to pale and flat (59-69), against 15-34 for the neighbours. The bandstand paints past its guide on all 40. Extra lanterns and plain yellow lamp balls keep appearing.
- **Next try, about 5 minutes:** keep the last pass 1 floor wording and the arch, pull the pass 2 floor and wall words about halfway back, and move two guest marks clear of the platform.

Sheet: `~/.cache/tillandsias-project/kumbia-art/room-cool-crowd-v1-a/sheets/review-phone-final.png`. A person has not accepted a layout or a plate yet.
