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
