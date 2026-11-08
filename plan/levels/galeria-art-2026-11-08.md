# La Galería: the room, its life, Siobhán and Las Tréboles

**2026-11-08, branch `work/1885-galr`, agent GALERIA.** For the owner, WIRE2 and whoever finishes the level.

- Facts are marked [F] and my proposals [P].
- Every choice is mine under the owner's delegation, and each can be reversed.
- The design I built to is `plan/levels/mansion-act-two-2026-11-08.md`, section 8.
- WIRE2 wired the room and the close-up on `work/1883-lvls` at 6f805c0.
- Nobody has seen any of this moving on a phone.

## What's on the branch

| What | Where | State |
|---|---|---|
| Room spec, forked from the salon, camera refit to the paint | `tool/art/rooms/galeria.json` | Done |
| Accepted plate (source) | `art_runs/rooms/galeria/picks/plate-993301.png` | Done |
| Plate the game draws | `assets/art/galeria/galeria-room.png` | See "Layers" |
| Marks for WIRE2 (plate fractions) | `art_runs/rooms/galeria/marks.json` | Done, sent, wired |
| Room-life layers | `tool/art/rooms/layers/galeria.json` | See "Layers" |
| Siobhán's definition and motion set | `tool/art/characters/siobhan.json`, `tool/art/motion/opponent-reel.json`, `tool/art/rig/poses.py` (opponent-reel) | Done |
| Siobhán's sheet | `tool/art/references/siobhan/front.png` | Done, seed 994003 |
| Siobhán's atlas | `assets/art/ensemble/siobhan-v1.png` | See "Siobhán" |
| Dancer entry | `assets/art/ensemble/choreography.json`, `dancers.siobhan` | Done |
| Close-up: Mācron's double tap and proud face | `assets/art/closeups/galeria-mc-*.png`, `art_runs/galeria-closeups-20261108/scripts/galeria_macron.py` | Done, wired |
| Close-up plate | `assets/art/closeups/galeria-floor-plate.png`, `tool/art/rooms/galeria_closeup.py` | Done, wired |

## The room

**Look** [P]: the mansion's long portrait gallery, seen straight down its length.
- The left wall has tall arched windows with the full moon in the nearest one. Cool silver moonlight falls across the floor.
- The right wall has gilt-framed portraits under brass picture lights.
- Two full-length portraits flank tall closed double doors at the far end. Those doors are the way out.
- Four white statues stand on plinths, two against each wall.
- A deep green runner with a thin gold border runs from the doors and stops in the middle of the hall.
- In front of it is open, polished grey marble, the dance floor for the feet.
- Midnight-blue silk walls with gilt mouldings, under a dark vault.
- The palette: cool silver and midnight blue, with the warm accents in the picture lights, the gilt and the doors. This sets it apart from the salon's gold and emerald and the comedor's wine red.

**How it was made** [F]: the `rooms.py` route, from a spec forked from the salon. 16 candidates in all.

| Run | Candidates | What happened |
|---|---|---|
| run-a, pass 1 | 6 | Bright white marble. The guide's red runner zone came back as a red runner to the bottom edge in 5 of 6. Only 993100 kept it short. |
| run-a, pass 2 from 993100 | 6 | Lovely walls, moon shafts and statues, but all 6 laid a green runner through the tap band, ignoring "the far half" |
| run-b, pass 2 from 993100 | 4 | Reworded: the runner "ends in the middle of the hall, exactly where the rug ends in image 1", and "the whole near half of the floor ... is bare polished marble". 993301 stops at y .655, the tap band's top. 993303 stops at .77, inside it. 993302 painted two men standing on the floor. |

**Picking** [F, P]:
- Local vision came first (`tool/metrics/vision.py`, qwen2.5vl:7b, 6 calls). It answered "no" to "does a carpet runner reach the bottom edge?" on all six run-a second passes. All six were wrong: every one does. It counted statues as 2 or 4 on plates that all have 4 or more. It caught nothing that mattered.
- Then my eyes, on the phone-crop sheets beside the garden, bar, party and billiard plates (`art_runs/rooms/galeria/run-*/sheets/`).
- I picked **993301**:
  - its runner stops at the tap band;
  - it shows the moon;
  - both far portraits sit under their lights;
  - the statues and doors are clean.

**Weak points** [F]:
- A dark floor joint crosses the runner near its end.
- The right wall's damask is a busy blue check.
- Moonlight patches lie across the floor at y .45-.6, where the line dances. They read as moonlight, not as cues, by my eye. Nobody has checked that with cues moving over them.
- The right far portrait's bearded gentleman looks a little like Abraham Lincoln at 3x zoom. At phone size he is about 10 px tall. If that matters, a Qwen edit of that portrait would fix it.

**Camera, refit to the paint** [F]:
- The far doors' leaves run y .214 to .361, 183 plate px. Taken as 1.75 adults at eye 1.0, that gives horizon .277.
- The runner's edges and the wall bases meet near x .515.
- So the level's floor is `{horizonY .277, referenceFootY .6, referenceHeight .323, vanishingX .515}`.
- The guide in `tool/art/rooms/galeria.json` follows the camera but not every painted line. Plate fractions in `art_runs/rooms/galeria/marks.json` are the contract.
- Cast proof: Mācron at heroHome is 45 logical px, against the garden's 38.

## Marks for WIRE2

All marks are in `art_runs/rooms/galeria/marks.json`. WIRE2 wired them on `work/1883-lvls` at 6f805c0.
- **Hero and Siobhán:** heroHome (.5,.6). Siobhán's mark (.5,.5), yield (.5,.44), meetMark (.64,.43), past the tunnel's far end on the right.
- **The line** [P]: dancers at ±.1 and ±.2 from her at y .5.
- **The arch** [P]: two facing pairs .2 apart across the runner, near pair at y .53 and far pair at .46. The right pair is mirrored. That's about 1.2 adults apart at that depth, so raised arms from both sides meet over Mācron. No paths cross.
- **Departure:** straight up the runner to the door threshold (.516,.37).
- **Guests** [P]: 12 from guest3-6, in pairs along both walls behind the line, alternating sides. Their evening wear fits the dress code (below).
  - The quiet box behind Siobhán and the route stay clear.
  - The right far statue is left uncovered, because it nods.
- **Glow points:** the two far picture lights at (.356,.192) and (.674,.192).

## Layers: the room joins in at full party

These follow the comedor's route (`tool/art/rooms/layers.py` and `inplace.py`, taken from `work/1881-cmdr`). The spec is `tool/art/rooms/layers/galeria.json`. All three props are `kind: artwork` with `minTier: 4`, so they stay still until the top tier.

| Prop | How | Motion |
|---|---|---|
| `portrait-tap` | The far-left portrait first repainted at full length into the layers' source (`tool/art/rooms/galeria_source.py`, Qwen edit 993400, 1 of 2 kept). Then one more edit lifts the toe of the shoe on the picture's right (993411; 993410 swung the other leg out instead). Cut to a polygon around his shoes | pulse, every beat |
| `bust-nod` | The right far statue's head, warped about its neck | pulse, 2 beats, 2 px |
| `portrait-sway` | The right far portrait's gentleman, warped about his feet | sway, 4 beats, 2 px |

- Rest frame against the source at phone size: mean difference .025, max 106. The max is at the portrait-tap polygon, where the rest frame is the source itself.
- The clean plate has harmonic fills under the bust and the right portrait, which the always-drawn layers cover.
- The full-length portrait is painted with finer detail than its surroundings, because Qwen worked at 3x. At phone size it reads as a portrait.
- GPU: 4 images, about 365 s.
- **Not seen moving.** The sway frames have ragged right edges over the blurred fill. Watch whether they show at the sway's extremes.

## Close-up: QUÉ / ZAPATEO

- **Canvases** [F]: all five Mācron drawings are drawn from parts by the close-up rig (`art_runs/galeria-closeups-20261108/scripts/galeria_macron.py`). There's no GPU, and nothing in them flickers.
  - Each canvas is 360x780, the close-up's own view at scale .5. Whatever runs off a canvas edge runs off the screen, so nothing ends mid-screen.
  - My first try was 400x440, like nod-mc-*. It cut his belly mid-screen.
- **Feet** [P]: `feet-rest`, `feet-up` and `feet-down` show the picture-right boot huge and centred on the marble. His belly runs off the top and left. Seen from the front, the tap is the boot lifted straight up off the floor; a rotated toe read as a kick. `feet-down` sinks the body 2 rig px for the impact.
- **Face** [P]: `proud` has chin up, smiling arcs and a blush. `proud-blink` squeezes the eyes. Ears and boots run off the sides and bottom.
- **Plate**: `assets/art/closeups/galeria-floor-plate.png`, cut from the room by `tool/art/rooms/galeria_closeup.py` at the billiards and salon proportions. It shows the doors, the runner's end and the marble.
- **Wired by WIRE2:**
  - feet-rest at 4, feet-up at 5.5, down at 6, up at 6.25, down at 6.5, rest at 6.75;
  - proud at 7.25, blink at 8, proud at 8.5;
  - clacks on 6 and 6.5, QUÉ / ZAPATEO on 6, `dust: false`.

## Dress code

[P] Everyone in the room is in evening dress:
- the guests are guest3-6: an amber-gold full-skirted dress, a lavender shirt with a bow tie, a plum wrap dress and an amber suit jacket;
- the five dancers wear long-sleeved velvet dresses to the knee.

No new guest families were drawn, which kept the GPU for Siobhán.
