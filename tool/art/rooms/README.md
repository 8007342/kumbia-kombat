# Rooms

A room is one data file, `tool/art/rooms/<id>.json`: primitives, a camera, a phone-safe box, a tap band and marks. From it the compiler makes the greybox guide, id map, `floor.json`, prompts and the level's floor and marks, in `art_runs/rooms/<id>/`. Two Qwen passes turn the guide into a plate.

Python: `~/.cache/tillandsias-project/venvs/kumbia-art/bin/python`. All commands are `rooms.py <command>`.

## Add a room

1. **Write the spec.** Copy `pool-garden.json` (outdoors) or `ballroom.json` (indoors). `rooms.py where <room> x y` turns an image point into floor coordinates.
2. **Compile:** `rooms.py compile <room>`. A refused layout lists every fault and writes only `REFUSED-overlay.png`.
3. **Look at `overlay.png`.** Magenta is the phone crop, white the safe box, red the tap band, boxes are cast at true size.
4. **Pass 1:** `rooms.py plan <room> --run room-<id>-v1-a --pass 1 --count 8 --seed N`. Queue each entry of `jobs-p1.json` with `studio.run_workflow`, one at a time. Then `rooms.py collect --run R`, `rooms.py verify --run R` and `rooms.py sheet <room> --run R --glob 'p1-*'`.
5. **Pass 2:** pick the clean first passes, then `rooms.py plan <room> --run R --pass 2 --count 4 --seed N --from a.png b.png`, and the same steps with `--glob 'p2-*'`.
6. **Proof:** `rooms.py proof <room> --run R --plate P` writes the phone row beside the accepted rooms, floor overlay and cast proof.
7. **Level:** `rooms.py level <room> --out levels/<id>.json --background <path>`, then `rooms.py check <room> --level levels/<id>.json`. Music, rules and chart come from `--base` (default the bar) or the spec's `level` block, until a person writes them.

Outputs land in `~/.cache/tillandsias-project/kumbia-art/<run>/`, because `/work/tmp/imagegen` goes with the forge. Workflows and sheets stay in `art_runs/<run>/`. A prompt change means a new plan and new workflow, because prompts are baked into each one (host bug 2001-stpr). The override fix was proven on 2026-11-06, tray 56.11.6.2, so new work can use `$prompt` on a node with that title. Existing workflows stay baked until someone changes them.

## What the compiler refuses

Story elements outside the safe box, or a safe box outside the phone crop. Anything but the allowed floor in the tap band. Marks and routes off walkable or standable ground, or feet in the band. Mācron below `cast.minHeroLogical` at his mark. Pool water hidden by columns past `minOpen`. Unknown primitives, zones and fields. Roofs and gateway tops may rise under the HUD when marked `ignoreTop`, but may not leave the sides.

## What a person must still review

- The layout in `overlay.png`, before any GPU time.
- **Choosing a plate**, by eye, beside the garden and bar at phone size (A6). Sheet numbers help but accept nothing: `s` saturation, `v` value, `d` median floor-line offset, `w` water overlap with the guide. On reflective floors `d` is unreliable. `w` falling under about 0.4 usually means the pool moved.
- People, lettering and invented objects in the plate. No gate checks these. The model adds lanterns freely.
- The floor overlay on the chosen plate. Marks come from the guide, and nothing refits them yet.
- Lamp glow marks against the painted lamps.
- The owner's acceptance, before a plate moves to `assets/`.

## Lessons from the first plates

- Lifting the horizon under the HUD keeps cast size and still shows the lawn: at eye 1.9 and horizon 0.16, Mācron is 34.8 logical px against the garden's 38.4.
- Glow discs on the lawn in the guide came back as glowing saucers, so light goes in the words and tables stay sprites.
- Word the interior's detail, or it comes back as flat orange.
- Pass 2 often moves the pool and sometimes the whole building. Expect about a third of the candidates to hold.

## Layers: taking painted props out of a plate

The garden is the pilot, because its plate is flat, has no id map, and is the first room anyone sees. Its umbrellas and tables were never painted: they're already sprites, so this route is for what is painted in.

`layers.py <matte|plate|frames|sheet> <room>` reads `layers/<room>.json`. `frames` writes the atlas and the level's `layers` block; `sheet` writes `before-after.png` and `motion.gif` to the run's cache folder.

**What worked**

1. **Choose props a phone shows.** On a 390x844 phone only x 157-867 of a 1024 plate is in view. The garden's big potted plants and hanging baskets are almost entirely outside it, and guests cover much of the lower sides.
2. **Matte by hand polygon, plus a colour rule where the backdrop allows.** Fronds against sky use `not-sky`. Flowers and lanterns are polygon only.
3. **Fill with Qwen removal on a tight crop, one prop at a time,** then paste only under the matte. A crop about 130-140 px wide works, at 832x832. The prompt names what remains and forbids what the model wants to add: "Do not add any plant, bush or flowers."
4. **Match the seam with a Poisson solve, with each edge difference clamped** (`edgeClamp`). 24 by default; 70 for a prop that lights its surroundings.
5. **Bend the prop's own pixels into frames.** Frame "rest" is the painting, so at rest the room matches the original, and nothing appears: the layer is there from the first frame and only its range grows.
6. **Behind glass, skip the plate.** Flames (`keepInside`) bend what's behind a pane and clip to it, so they need no fill or GPU. They change shape, not brightness.

**What failed**

| Try | Result |
|---|---|
| BiRefNet on a 320 px crop | Keyed the house, not the fronds or flowers. It finds the salient object, and a plate has no single one |
| Qwen on a wide crop, 320 px | Sky was clean. On the pier it grew a new bush, with either wording |
| Magenta-blanked props | Same bush. No better than asking in words |
| A flat colour shift to match tone | Tinted the fill red beside a bright lantern |
| An unclamped Poisson solve | Smeared any frond left at the mask's edge across the sky |
| A colour rule for flowers | Took the lit wall and missed dark leaves |

**GPU, one job at a time** (queue wait excluded; each job's first image includes about 10 s of model load)

| Step | Images | Seconds |
|---|---|---|
| Wide crop removal, two wordings | 4 | 64 |
| BiRefNet probe | 1 | 8 |
| Tight pier crops, both sides | 6 | 87 |
| Tight lantern crops, both sides | 4 | 70 |
| Wide crop, right fronds | 2 | 34 |
| **Total** | 17 | **263, about 4.4 minutes** |

Mattes, seams, frames and sheets are CPU, seconds each.

**Pitfalls**

- A wide crop's fill is fine for sky, and no use where anything has an edge.
- Qwen redraws a ledge a little wider and higher than the real one. `cap` discards its ledge and rebuilds that strip from clean stone just below the prop. Check the strip's rows against the matte, or the rest frame stops matching.
- The dark part of a frond is close to the sky's colour. It left a ghost until near-black counted as frond.
- Keep polygons a little generous, then read the `rest` comparison's blobs: they name the exact edge that's leaking.
- **The clean plate is not meant to be seen alone.** The dance exposes 21-27% of the fill behind fronds and lanterns, and 3-4% behind flowers. Pier walls and caps behind the flowers are plain, and would need another pass if a level ever removed the flowers altogether.
- `level_golden_test` leaves out layer draws. Its recorded file didn't change when the garden moved to the clean plate, which is the proof that the marks didn't move.
- Workflow paths from a worktree need the `.claude/worktrees/<name>/` prefix, and a job fails at once if its input isn't staged yet.

**Reuse.** A level's `layers` block names each prop's atlas, position and motion; there's no kind switch, so a new prop needs no code. Levels can share an atlas. The loader refuses a prop that leaves the plate, reaches the tap band, or reaches the quiet area behind the opponent.

## Furniture: one set of drawings, baked per room

Stools, chairs and tables are sprites on the floor plane, sorted in depth with the guests. `props.py` keeps one drawing of each and bakes it to each room: `props.json` holds the room's pixel (`cell`, plate pixels, read off `props.py measure` and by eye), where its guests sit (`midY`) and its light (a gain, a warmer key from above, a colour count). `props.py masters`, then `bake`, writes `assets/art/props/<room>.png` and `manifest.json`; `sheet OUT` lays them on their plates. A level names its set and seat in `crowd.propSet` and `crowd.seat`, so a new room needs numbers, not drawings.

**Drawn with** `art_runs/rooms/crowd-props/workflows/prop-edit.api.json`: Qwen edit with the 2511 Lightning LoRA, `furniture-v2.png` on grey as the one reference, BiRefNet for the cut. The chairs are still the old sheet's. The seat height is the contract: a stool's seat meets the chair's .37 of an adult, so every seated pose fits both and none had to be redrawn.

**What it took:** 3 jobs, 6 images, about 40 s of GPU a job once it had the queue. `art_runs/rooms/crowd-props/picks/*.provenance.json` has each kept seed.

| Try | Result |
|---|---|
| Stool, from words and the sheet | Both seeds usable first time. Kept the plainer one |
| Table, the word "cafe" in the prompt | The model wrote CAFE across the table top, in both seeds |
| Table, "plain wood top", "no letters, no words" | Clean. A mirror of the second seed makes the room's second table |

**Laying out a crowd.** The first pass copied the rows further forward and made a wall: a guest's width grows with depth, so the front holds far fewer people than it looks. Keep every guest behind the opponent's mark, so the dancer is always the nearest adult. Thin out toward the viewer, and let the back carry the numbers. `test/crowd_staging_test.dart` holds guests and furniture off the tap band, the hero's marks and the dancers' floor, reading the level files, so moving a mark names any guest in the way. `test/room_stills_test.dart` writes phone-size pictures of each room to `build/stills/`.

**Order in the file matters.** The crowd wakes in columns, every fourth guest first, so a guest's index decides when they get up. Lay the ranks out to alternate sides and mix depths, or the warm floor is all on one side.
