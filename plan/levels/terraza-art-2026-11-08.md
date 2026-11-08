# La Terraza: the room, its fireworks and life, the guests and Tía Purpurina

**2026-11-08, branch `work/1886-terr`, agent TERRAZA.** This note is for the owner, for WIRE2 (who wires `levels/terraza.json`) and for whoever finishes the level. Facts are marked [F] and my proposals [P]. I made every choice under the owner's delegation ("agents accept their own art and design choices"), and each one can be reversed. Nobody has seen any of this moving or on a phone. I built to `plan/levels/mansion-act-two-2026-11-08.md`, section 9.

## What's on the branch

| What | Where | State |
|---|---|---|
| Room spec | `tool/art/rooms/terraza.json` | Done |
| Accepted plate (the source) | `art_runs/rooms/terraza/picks/plate-996100.png`, floor-graded copy `plate-996100-graded.png` | Done |
| Clean plate the game draws | `assets/art/terraza/terraza-room.png` | Done |
| Fireworks | `assets/art/terraza/terraza-fireworks.png`, `tool/art/rooms/fireworks.py`, `tool/art/rooms/fireworks/terraza.json`, level block `art_runs/rooms/terraza/fireworks-level.json` | Done |
| Room life: palms and festoon bulbs | `assets/art/terraza/terraza-layers.png`, `tool/art/rooms/layers/terraza.json`, level block `art_runs/rooms/terraza/layers-level.json` | Done |
| Marks for WIRE2 | `art_runs/rooms/terraza/marks.json` (plate fractions) | Done, sent, wired by WIRE2 |
| Guests | reused guest0-6, places in `marks.json` | Done (no new drawings) |
| Close-up | `assets/art/closeups/terraza-*`, `tool/art/closeups/terraza_kiss.py`, `purpurina_bust.py`, `purpurina_bust_finish.py`, `terraza_plate_closeup.py` | Done, wired by WIRE2 |
| Kiss-mark keepsake | `assets/art/closeups/terraza-kissmark.png` | Done, wired |
| Tía Purpurina | `tool/art/characters/purpurina.json`, body `curvy-older-adult`, motion set `opponent-samba` (`tool/art/rig/poses_samba.py`) | See "Tía Purpurina" |
| Her choreography and LA LLUVIA DE CONFETI | `dancers.purpurina` in `assets/art/ensemble/choreography.json` | See "Tía Purpurina" |

## The room

**Look** [P]: the mansion's rooftop terrace at midnight, seen from the top of the stairs toward the city. A wide floor of square stone tiles runs to a cream stone balustrade across the far side. Over the balustrade a city glitters far below to the horizon. Three strings of round festoon bulbs cross the terrace, potted palms in terracotta planters frame both sides, and at the right of the balustrade a small stone arch with two lanterns opens onto the stair head: the way out. The top third of the plate is open night sky, so the fireworks have somewhere to go.

**How it was made** [F]: the `rooms.py` route, one run (`run-a`) with 12 candidates, style reference: the garden.

| Pass | Candidates | Result |
|---|---|---|
| 1 | 6, seeds 996000-996005 | All six held the layout. The stair head read as stairs going down in 996000, 996004 and 996005, and as steps rising out of the terrace in 996002. All kept the guide's dusty-rose floor colour |
| 2 | 3 from 996000, 3 from 996004 | All six painted the floor as bright honey limestone (tap-band luma 101-129, against near-black floors in the other rooms). 996004's children had a plainer arch, and 996200 drew crack lines across the floor |

**Picked 996100** [P], by eye at phone crop beside the garden, bar and salon. It has the clearest stair head (a flight of steps with a rail inside the arch, lit by two lanterns), the city with a few towers, both palms framing the strings, and the calmest floor texture of the six. The stairs rise into the arch rather than visibly dropping away: it reads as "the stairs", not specifically "down". 996102 was the runner-up, with a smoother floor but a darker, less legible stair head.

**The floor, graded by code** [F, P]: no pass 2 gave a night floor, so `tool/art/rooms/terraza_plate.py` grades the painted floor (the guide's floor zone in `ids.png`) instead of spending another GPU round on words. It keeps the painted tiles, desaturates them a little, and darkens them from 62% of their value at the balustrade to 32% at the bottom edge, with a slight cool tint. Tap-band luma went from 108 to 46. Beside the other rooms on a phone it reads as a moonlit stone terrace, with the warmth kept near the lanterns.

**Local vision** [F]: qwen2.5vl:7b was asked six questions about each first pass (a staircase through a gap in the railing, palm count, people, text, light strings, stone floor). It said "no staircase" on all six, which was wrong for at least three. It counted two palms on each (there are four, two of them half off the plate). "No people, no text, strings, stone floor" was right on all six, but those were easy. It changed nothing about the pick. 6 calls, 97 s including model loads.

**Camera** [F]: horizon .36 and eye .85 adult. These are the guide's numbers, unchanged, because pass 2 kept the guide's floor: the balustrade's foot is at y .455, and the painted tile lines meet the guide's lanes near x .5 (`art_runs/rooms/terraza/run-a/sheets/plate-996100-graded-floor-overlay.png`). Mācron at heroHome is 45.6 logical px (garden 38.4, salon 45). `rooms.py compile terraza` passes.

## Fireworks

`tool/art/rooms/fireworks.py` [F]: a new tool, with no GPU. Each burst is drawn as pixels on the plate's 2-pixel grid. Frame 0 is empty (the painted sky), frame 1 is a rising streak with a flash, and frames 2-5 open into a ring of streaked sparks that droop a little as they spread and end with loose twinkles. The bursts are clipped to the painted sky (dark, blue over red, measured on the plate *with* its palms), so fronds, strings and the city always stay in front.

| Burst | Colours | Where (plate px) | Peaks on beat (of 8) |
|---|---|---|---|
| firework-gold | gold | upper left, r 84 | 0 |
| firework-red | red | top middle, r 64 | 6 |
| firework-turquoise | turquoise | upper right, r 78 | 3 |
| firework-green | green | left of middle, r 46 | 2 |
| firework-white | white | right of middle, r 50 | 5 |

The data [P] is kind `light`, motion `pulse`, periodBeats 8. The game's pulse plays a burst from nothing to its bloom and back on each period, and the bloom's size follows the crowd's swing and the tier. So the sky starts with small sparks and fills as the party rises. No burst repeats within 8 beats, and at most one peaks per beat, so it never strobes. All rects stay clear of the tap band and the quiet box behind her.

**Blooms in the outro:** layers fade with the win's cool-down, and only the lamp glows read `exitShot.flare`. At my request WIRE2 made kind-`light` layers take the larger of their swing and the flare (`work/1883-lvls`, `_drawRoomLayers`), so the sky fills from beat 10.

**Honest caveat:** the pulse is symmetric, so after each peak a burst plays backwards, shrinking to nothing. At this size and speed I expect it to read as a burst that blooms and fades, but **nobody has seen it moving**. If it reads as sparks being sucked back in, the fix is code: a one-way pulse for this kind.

## Room life at full party

`tool/art/rooms/layers/terraza.json`, the README's route [F]:
- **Palms:** both crowns are lifted out as `sway` props, kind `artwork`, minTier 4. Each pivots where its crown meets its trunk, reaches 6 px at the frond tips, and moves every 2 beats; the right palm is a beat behind the left. The fills are `harmonic`: plain night sky closes in from the edges, with no GPU. That's enough because a 6 px sway only shows a sliver behind the fronds, and the night sky there has no detail to lose. The polygons hug the crowns, so the stars above don't move with them. The strings' bulbs that hang in a crown sway with it, as they would if tied to the palm.
- **Festoon bulbs:** the bulbs between the palms are a `pulse` prop, kind `artwork`, minTier 4, once a beat. I added a new `glow` frame to `layers.py`: the same pixels, brighter and warmer, with a one-pixel halo at the peak. Nothing moves. There's also a new `bulb` colour rule: bright, with red above blue, so white stars stay out.
- Rest frame against the painted original at phone size: mean difference 0.019. The review sheet and GIF are in `~/.cache/tillandsias-project/kumbia-art/layers-terraza-20261108/`.
- `layers.py` here is COMEDOR's version (minTier, phaseBeats, drawn frames) plus my `glow` frame and `bulb` rule. That way the bake carries minTier, and merging both branches won't conflict.

## Guests

Reused, with no new drawings [P]:
- guest3-6 are couples in evening wear: the amber-gold dress, the lavender shirt with a bow tie, the plum wrap dress and the rust suit jacket.
- guest0-2 are the lawn's guests: a blouse with palazzo trousers, a linen waistcoat, and a guayabera with a panama hat. That is exactly the summer evening wear the design asks for.

There are twelve places in `marks.json`:
- four couples on pair_dance, two on each side;
- four guests dancing alone (guest0-2 have no pair dance, so WIRE2 gave them a "solo" step-touch set);
- all behind her mark, thinning toward the viewer;
- none in the exit route or in the middle behind her.

**What a real samba crowd would need** [P]: guest0-2's step-touch isn't samba. A drawn samba no pé for the guests would be the next spend if the owner wants it. I chose to spend this batch's GPU on Purpurina.

## The close-up: the lipstick kiss

Drawn to WIRE2's stand-in shape, the lawn's kiss [F]:
- **Mācron:** `terraza-mc-{rest,kissed,spark-a,spark-b}.png` are heads on the lawn's 400x440 canvases. `tool/art/closeups/terraza_kiss.py` draws them from parts with the close-up rig, so his head is the lawn's exactly, and the lawn's `duet-macron-body-*` and logo fit under them.
  - `kissed` adds big arc eyes, full blush, and the lipstick print on his picture-left cheek panel: an upper lip with a cupid's bow, a fuller lower lip, a parting and two creases, in her lipstick red.
  - `spark-a` and `spark-b` add a sparkler at his antenna: the orb turns white-hot, and rays and loose sparks fly up and out to the sides, never across his face. The two frames differ in angle and length.
- **Her:** `terraza-tp-rest.png` (three quarters, a huge laugh, a hand up) and `terraza-tp-kiss.png` (profile, eyes closed, lips puckered).
  - They are Qwen edits of a bust crop of her accepted front sheet (`purpurina_bust.py`), 2 candidates each. I picked rest 996600 and kiss 996611; 996610 was nearly the same, with smaller lips.
  - Each is placed by her gold earring so her head holds still between the cuts, then snapped to her palette on a 2-pixel grid.
- **Foreground:** `terraza-rail.png`, a strip of the terrace's own balustrade in front of her cut-off waist, as the lawn's hedge is.
- **Plate:** `terraza-plate.png`, a crop of the painted terrace (stair head, festoons, city) with the fireworks' full blooms drawn in, because the kiss happens under them.
- **Keepsake:** `terraza-kissmark.png`, 7 by 4 native pixels of lipstick, anchor [3,3], at about [-0.18, -0.50] in his heights. WIRE2 wears it on his cheek from beat 6.
- WIRE2 wired all of it (`work/1883-lvls` 16e6966): the kiss lands her lips on his mark on beat 5, and the spark plays on 5.75 and 6.25.

## Tía Purpurina

(Filled in as the frames land.)

## Compute

In `plan/compute-ledger.jsonl`, agent `terraza`. Studio `elapsed_s` and wall times include waiting in the shared host queue, so they are upper bounds.

## What needs eyes, on a phone

- [ ] Fireworks: do they bloom and fade, or read as sparks sucked back in (the symmetric pulse)? Does the sky fill at the win, after WIRE2's flare change?
- [ ] Palms at tier 4: felt more than seen, with no halo where the crowns were lifted?
- [ ] Bulbs pulsing on every beat: festive, or too busy beside the fireworks?
- [ ] The graded floor in the tap band: calm enough, and still a terrace?
- [ ] The kiss: does the lip print read as a kiss on his cheek at phone size? Do the sparkler frames read as a sparkler?
- [ ] The keepsake: 7 by 4 pixels; does it read at all on the walk-out?
