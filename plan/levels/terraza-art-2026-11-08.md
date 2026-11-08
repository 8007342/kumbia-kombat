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

**Who** [P]:
- She (stated in the brief), about seventy, short and full-figured, with wide round hips: a new body preset, `curvy-older-adult`. Next to the tall, narrow Don Terciopelo and the lean BlinBlin dancer she's the round one.
- Warm brown skin, a big mass of copper-red curls, big gold hoops, bright red lipstick, and a sequinned gold cocktail dress with short sleeves, a modest neckline and the hem just below the knee.
- The feather boa is **turquoise**. Every pink and plum is the audience's reserved ramp, and the definition is refused with one. Turquoise against gold reads as carnival.
- Defined in `tool/art/characters/purpurina.json`.

**Sheets** [F, P]:
- **Front, 996500 of 4.** It was the only candidate with the warm brown skin asked for, a modest neckline, and the boa as a stole with both ends down. 996501 drew her pale with a lower neckline, 996502 at the wrong scale, and 996503 tall and narrow.
- **Back, 996501 of 3**, drawn from the accepted front. It's the only back that keeps the front's sequin sparkle.

**Motion set `opponent-samba`** (`tool/art/rig/poses_samba.py`, registered at the end of `poses.py`) [P]:
- **The 64 shared names**, so every shared table plays her. The groove is redrawn as samba no pé, per side over a beat:
  - a flat step down with the hips dropped (1);
  - a ball change behind (e);
  - the same foot again (and);
  - the hip rolled out high over the straight leg with the free foot flicked out, one fist on the hip and the other arm up (a). This lands where WIRE2's chart puts the hip-hand.
- **New clips:** an eight-view `spin` with arms up and the boa flying; `boa.a/b`; `laugh.a/b` (the head thrown back, then both hands on her belly); `kiss.a/b` (fingertips at the lips, then the kiss flung to the picture's right); and `confetti.a/b`.
- **Pose check:** `check_poses.py` whitelists `kiss.a` and `laugh.a` for a hand near the face. Her shorter legs needed the shared side-step's trailing knee bent more, as Don Charolas's did.

**Frames** [F]:
- Run `purpurina-v1-20261108a`, with the 2511 LoRA through `run_jobs.py`.
- **Pilot:** 8 hard poses (the hip, the step, the confetti throw, the laugh, the kiss, the boa, the back and profile spin views). All 8 came back usable, so the wave went ahead unchanged.
- **Wave:** 50 poses at 2 candidates. The 22 locomotion and watch poses got 1 candidate each to save GPU, and all 22 matched their skeletons by eye.
- 138 candidates in all.

**Picking** [F, P]:
- I looked at every candidate beside its skeleton in contact sheets, clip by clip, then at the packed atlas at native size.
- The picks are in `art_runs/purpurina-v1-20261108a/picks.json`, with a `why` for each one I didn't take on sight.
- Faults caught by eye:
  - two spin views (`front`, `34_r`) whose boa ends fly out like a second pair of arms;
  - a back view drawn facing the viewer (`spin.back` 996501);
  - a blown kiss drawn as a smile (`kiss.b` 996501);
  - a pointing finger in `left_hand.return` (pointing is reserved for flourishes);
  - a confetti scoop with empty hands (`confetti.a` 996500);
  - boa ends hanging out like wings (`groove.down_r` 996500).
- **Weak picks, kept as the best of their candidates:**
  - `left_foot.prep` and `right_foot.prep` crouch instead of lifting the knee;
  - `spin.side_l` faces mostly front;
  - `finish_turn.finish_b` lifts a tuft of boa to her curls rather than fluffing them with her hand.
- **Thrown confetti:** `register_frames.py` dropped every piece but the figure, which would have thrown the confetti away. A new `--loose` keeps a pose's loose pieces in the matte while the figure alone sets height and floor. `confetti.b` touches the top of its cell, so a few flakes are clipped there.

**Local vision against my eyes** [F]:
- qwen2.5vl:7b counted heads and hands on all 138 registered candidates, in 145 s.
- It flagged 17. All 17 were wrong: the back views have "0 heads" because the face isn't visible, and "3-4 hands" where the boa's ends or an open hand were counted twice. I checked the four flagged picks at full size, and each has two hands.
- It caught none of the six real faults above. A pre-filter only, as every agent before me found.

**Atlas** [F]:
- `purpurina`: `assets/art/ensemble/purpurina-v1.png`, 1024x2887, 80 drawings and 20 aliases (100 frames).
- Promoted into `manifest.json` with `promote.py --new`; referenceFrame `occupied`.
- The motion file carried two stale aliases from the cha-cha set (`mirror_look`, `flare_open`); `pack_atlas.py` refused them, and they're removed.

**Choreography** [P]: `dancers.purpurina` in `assets/art/ensemble/choreography.json`.
- **Accents:**
  - `boa_twirl` every 16 beats at 4, from tier 1;
  - `laugh` every 16 at 12, from tier 2;
  - `blow_kiss` every 32 at 28, from tier 3.
- **Hand-off moves:** `spin_boa` from tier 1, `hip_roll` in a cold room.
- **The win:** `confetti`, one beat a drawing, on beats 0-2. Her approving pose is the shared approval clip.

**LA LLUVIA DE CONFETI** [P], `art_runs/rooms/terraza/hardest-combo.json`. WIRE2's notes are unchanged. My moves are three clips, each a whole number of loops:
- `lluvia_open` (1.75 beats) lands the right foot on 1.5;
- `confetti_rain` (0.75 beats: a scoop, then a throw) plays five times from 1.75, so every throw lands on a hand note at 2.25, 3, 3.75, 4.5 and 5.25;
- `lluvia_close` (2.5 beats) puts the right foot on 6 and the left stamp on 7.

WIRE2 checked it against the combo rules.

## What went wrong

- **Every pass 2 painted a bright floor.** I graded it by code (above) rather than spend another round on words.
- **Local vision missed the staircase** on every room plate, and every real fault on the frames (above).
- **The back sheet's first job was refused**, because a one-image sheet job didn't bind `$pose_proxy`. I bound the same image to both inputs, as Terciopelo's note says to. Its outputs also weren't filed under the run, so I found them by provenance.
- **My first wait loop matched its own command line** (`pgrep -f` inside `sh -c`) and would never have ended. I killed it by PID and waited on PIDs after that.
- **The disk-full incident at 02:13** didn't touch this worktree, which lives in the cache. Git's metadata is under /home/forge/src, though; I checked and everything had pushed.
- **The `--loose` change broke `register_fixed`** (an undefined name), caught by `tool/art/tests`. Fixed in 8f21e18.
- **`finish_run_picks.py` then waited 15 minutes** for the heavy lock, which other agents' GPU jobs were holding.
- **`tool/art/tests`:** 226 ran, with 4 failures and 11 errors. Every one is a file the sparse checkout doesn't have (`art_runs/inputs/gatekeeper-v3`, `art_runs/gatekeeper-v4-*`), the same count Terciopelo's note gives.

## Compute

In `plan/compute-ledger.jsonl`, agent `terraza`. Studio `elapsed_s` and wall times include waiting in the shared host queue, so they are upper bounds.

| Batch | Images | Seconds |
|---|---|---|
| Room plates, pass 1 and pass 2 | 12 | 821 |
| Purpurina sheets, front and back | 7 | 552 |
| Close-up busts | 4 | 400 |
| Frame pilot | 16 | 1,597 |
| Frame wave, 2 candidates | 100 | 7,078 |
| Locomotion and watch, 1 candidate | 22 | 1,677 |
| **GPU total** | **161** | **about 12,100, or 3.4 hours of wall time, queue included** |
| Local vision (qwen2.5vl:7b) | 144 calls | about 240 |
| CPU (grade, layers, fireworks, rig drawings, registration, finish, pack) | | about 13 minutes |

The fireworks, the palms' and bulbs' frames, Mācron's four heads, the keepsake, the close-up plate and the rail cost no GPU.

## What needs eyes, on a phone

- [ ] Fireworks: do they bloom and fade, or read as sparks sucked back in (the symmetric pulse)? Does the sky fill at the win, after WIRE2's flare change?
- [ ] Palms at tier 4: felt more than seen, with no halo where the crowns were lifted?
- [ ] Bulbs pulsing on every beat: festive, or too busy beside the fireworks?
- [ ] The graded floor in the tap band: calm enough, and still a terrace?
- [ ] The kiss: does the lip print read as a kiss on his cheek at phone size? Do the sparkler frames read as a sparkler?
- [ ] The keepsake: 7 by 4 pixels; does it read at all on the walk-out?
- [ ] Her samba no pé at 96-112 BPM: do the hip drawings on the beat's last sixteenth read as samba hips, or as a twitch?
- [ ] The boa twirl, the laugh and the blown kiss between phrases.
- [ ] The spin: two of its eight views face front, so it may read as a shimmy with a turn.
- [ ] The confetti throw on the win, with a few flakes clipped at the top of her cell.
- [ ] Her stature beside the guests (I suggested about .92 to WIRE2).

## Not done

- No samba drawn for the guests: guest0-2 step-touch, guest3-6 do their party pair dance.
- No `flutter test` here: the forge refuses flutter in this cache worktree. WIRE2 runs the suite when it wires the atlas.
- Nobody has seen any of it moving.
