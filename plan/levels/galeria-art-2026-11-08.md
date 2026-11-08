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
- **Hero and Siobhán:** heroHome (.5,.6). Siobhán's mark (.5,.5), yield (.5,.44), meetMark (.70,.49), beside the arch's right pair and in front of the right wall's guests. It was (.64,.43), then (.72,.44). WIRE2 found her hidden behind the right pair at the first and behind a guest at the second, and checked (.70,.49) on stills.
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

## Siobhán and Las Tréboles

**Who** [P]: Siobhán, she, about 25.
- Slim and very upright, with fair freckled skin and copper-red hair in a high bun with a silver clover pin. Her look is cool and composed.
- Original costume, not any show's: a long-sleeved dark green velvet dress with a high neck, a stiff flared skirt to the knee, and silver knotwork at the waist, cuffs and hem.
- Black opaque tights, and black hard shoes with thick heels and small buckles.
- Her silhouette, a slim vertical with a bun, sits between the narrow Don Terciopelo and the round Don Charolas.
- The hem stays at the knee for the style guide's "at or below the knee", even through the high kicks.

**Sheet** [F]: four fronts drawn from words, with Don Terciopelo's front as style only, on the `challenge.return` skeleton. I kept **994003**: its knotwork belt reads as Celtic, she has the freckles and a stern face, and it has the plainest skirt. 994000 had a lace-up waist, 994001 a buttoned bodice front, and 994002 almost no embroidery.

**Motion set `opponent-reel`** (`tool/art/rig/poses.py`, `tool/art/motion/opponent-reel.json`) [P]:
- It keeps the 64 shared drawing names, so every shared choreography table plays her. Her arms stay rigid at her sides except for a hand call.
- The groove is a reel's lead-round:
  - down: a hop with the knee lifted high, crossed in front;
  - pass: a treble, the toe striking crossed in front;
  - up: on both toes with the feet crossed tight;
  - the hold: a hop-back, the other heel kicked up behind.
- Foot calls are high kicks out to the side at waist height. A kick straight toward the viewer foreshortens to nothing, so it goes to the side.
- Hand calls are one straight arm snapped out to 45 degrees, then swung back down.
- Walks are skips on the balls of the feet.
- Her finish points a toe and gives a small bow. Her approval is one firm nod with the knees dipped.
- New drawings: `arch.rise`, `arch.hold` (arms raised, turned to the picture's right) and `freeze.hold`.
- `check_poses.py` gets one exemption, `KICK_OVER_ARM`: in 2D a high kick to the side passes in front of the same side's rigid arm.

**How it was made** [F]:
- The Qwen frame route, run from this worktree with `run_jobs.py` and the 2511 Lightning LoRA, 2 candidates a pose.
- First a pilot of 8 hard poses: hop, treble, hop-back, high kick, arm snap, challenge, nod and arch. All of them read on the first try, so no words changed before the wave.
- The wave drew the other 58 poses.
- Run b redrew the two arm follow-throughs. In wave a, three of the four candidates held the skirt out, and one crossed an arm over the waist.
- Picks are in `art_runs/siobhan-v1-20261108m/picks.json`, with a reason wherever the choice wasn't obvious.

**Atlas** [F]: `siobhan`, `assets/art/ensemble/siobhan-v1.png`, 1024x1809, 87 frames: 67 drawings and 20 runtime aliases. Promoted into the manifest with `promote.py --new`.
- `challenge.return` is the accepted sheet itself, drawn on that same skeleton.
- The two arm-snap preps reuse the return drawing. Both prep candidates raised fists to the chest, and the prep's skeleton is the return's.
- `finish_turn.turn_in` is its own drawing with `mirror: true`. Both candidates faced the picture's left, like turn_out.

**The line** [P]: Las Tréboles share her frames. WIRE2's line draws them up to half a beat late, so it dances as one. As a bonus, four colour-only variants change only the hair, giving raven, honey, chestnut and ash for the four beside her:
- `assets/art/ensemble/siobhan-v1-{raven,honey,chestnut,ash}.png`;
- made by `tool/art/pipeline/ramp_variants.py` with no GPU.

Qwen's skin shadows had snapped to the hair ramp too, so only connected masses of 40 px or more are recoloured. A few face-edge pixels still change colour: the raven variant has a dark fleck on one cheek at 3x. The variants have no manifest entries. Using them needs a per-dancer image option in the line, which is WIRE2's call.

**Choreography** [P]: `dancers.siobhan` in `assets/art/ensemble/choreography.json`.
- Clips: `trebles`, `high_kicks`, `hop_backs`, `arch`, `freeze`, `stamp`.
- Accents: a stamp on every phrase from tier 1, and high kicks every other phrase from tier 3.
- Hand-off: hop-backs from tier 1, and the stamp in a cold room.
- `EL MURO DE TACONES` stays as WIRE2 wrote it: groove_double, which is her reel round. `trebles` is offered as the wall of heels.

**Review** [F]:
- I looked at every candidate beside its skeleton on contact sheets, and at the packed atlas at about native size.
- The scorer was not run. Its picks for faces and hands weren't trusted on the last two families, and these poses differ mostly in the feet.
- Local vision (qwen2.5vl:7b) counted heads and hands on the 67 finished frames. Its results are in the next section.

**Weak picks, kept as the best of their two** [F]:
- `reassurance.open_hand`: both candidates also raise the other hand in a small wave. That breaks the rigid arms, but it's warm.
- `finish_turn.finish_b`: the small bow hardly shows.
- `left_hand.follow` and `right_hand.follow` (run b) hold the swinging arm a little away from the skirt.
- A few frames have a slightly lighter green bodice.
- `arch.hold` is a symmetric V rather than arms leaning toward the partner. The model kept the arms symmetric.

**Local vision on the finished frames** [F]:
- qwen2.5vl:7b, 134 calls, one head count and one hand count on each of the 67 frames.
- 56 frames came back "1 head, 2 hands", which is right.
- 10 calls returned nothing: the model timed out while it shared the GPU with the studio queue.
- One frame came back "1 hand": `yield_side.contact_r`. She is turned three quarters there, and her far hand shows small at her side. That's a miss by the model, not a fault in the drawing.
- It flagged nothing I hadn't already seen, and it missed both real faults. Those were the fists at the chest in both arm-snap preps, and the skirt held out in three of the four first arm follow-throughs. I found both on the contact sheets. As before, it's a pre-filter only.

## Compute

Lines are in `plan/compute-ledger.jsonl`, agent GALERIA. Studio seconds include waiting in the shared host queue, so they're an upper bound on GPU time.

| Batch | Images | Seconds |
|---|---|---|
| Room plates, run-a and run-b | 16 | 735 |
| Siobhán's sheet | 4 | 253 |
| Pilot, 8 poses | 16 | 2,083 |
| Wave, 58 poses | 116 | 8,435 |
| Run b, 2 poses | 4 | 337 |
| Layer edits (portrait full length, foot tap) | 4 | 363 |
| **GPU total** | **160** | **about 12,200, or 3.4 hours, queue included** |
| Local vision | 140 calls | 6 plate calls (about 100 s) plus the frame batch (about 25 min wall, slowed by sharing the GPU) |
| CPU (rig, finish, pack, layers, close-up, variants) | | about 10 minutes |

## What went wrong

- **The runner in words.** "The far half" didn't hold: pass 2 laid the runner through the tap band 6 times out of 6. Naming the image's own rug as the place it ends ("exactly where the rug ends in image 1") worked in 2 of 4.
- **The first close-up canvases.** At 400x440, like nod-mc-*, the feet shot cut his belly in the middle of the screen. I redrew them on canvases the shape of the view.
- **A tap drawn as a rotated toe read as a kick.** From the front, a tap is the boot lifted straight up.
- **`check_poses`.** It refused the still poses: a rigid dancer's nod and challenge moved under 16 px. They now dip the knees or rise onto the toes. It also refused the side kick crossing the rigid arm, which is now excused by name.
- **My first sheet job failed.** `run_jobs.py --jobs` takes a path relative to the run's folder.
- **The sheet's candidates were filed under `challenge.return`**, because the sheet is drawn on that skeleton. So the wave skipped that pose, and the accepted sheet became the frame. That's the right drawing, but it happened by accident.
- **The forge's tmpfs filled at about 02:13.** My commits and pushes from then on were checked afterwards and had all landed.

## Needs eyes, on a phone

- [ ] The reel at tempo, 114 to 130 BPM. Do the hop, treble, toes and hop-back read as step dancing with the arms still? Do the five read "as one" with WIRE2's lag?
- [ ] The high kicks out to the side, and the rigid arm snap.
- [ ] The arch: do the V arms of facing pairs read as an arch over Mācron? Is Siobhán in plain view at meetMark (.70,.49)?
- [ ] The hair variants' faces at play size. The raven one has a dark fleck on a cheek at 3x.
- [ ] Room life at full party: the portrait's foot tap, the bust's nod and the portrait's sway. Are they felt and not seen? Do the sway's ragged edges show?
- [ ] The moonlight patches on the floor, with cues moving over them.
- [ ] The close-up: does one huge boot read as "his tiny feet"? Does the cut from the boot to his face land?
- [ ] The right far portrait's gentleman, who looks a little like Lincoln when zoomed in.

## Not done

- No new guest families. guest3-6 are already in evening wear, by my call above.
- No drawn "nod" beyond the shared approval clip. Her approval nod is the 3-drawing approval clip, wired at 10.5.
- Flutter isn't run in this worktree. WIRE2 ran the suite with this art on `work/1883-lvls`: 789 pass at 5fefa7e.
