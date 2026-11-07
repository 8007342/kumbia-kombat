# The indoor party's band, 2026-11-07

Branch `work/1864-band`. The owner's ruling: "let's use that left platform to add a band playing the music, they'll also play while tapping a foot or swinging their instrument on rythm, and liven their rythm as the player game improves."

**Status:** the owner approved the front sheets and the choices below ("Excellent references... I approve your choices, keep going on with the plan"), then delegated completion for this level. Choices taken since are mine, and each is listed in section 8 so the owner can reverse it on the phone. Sections 1 to 7 are the pre-approval plan, kept as written apart from the notes here.

**Corrections to what follows:**
- The band is drawn at an angle, playing toward the crowd (owner), so section 2's front views are not what frames use. Each player has a `front_3q` view drawn from the approved front.
- The trumpet's feet moved to (.168, .385), since .368 is off the measured deck (INDOOR).
- Rung inputs are data, `"input": "form"|"tier"|"partySwing"` with `"from": n`, all `form` for now, pending the owner (INDOOR). That replaces `tapFromTier` and `swingFrom` below.
- Under reduced motion each energy rung holds its own drawing, so the meter still shows (INDOOR), not `relaxed_a` throughout.
- `ensemble_sprites.dart` no longer rejects new atlases, per the PARTY agent, so no `requireFrames` case is needed.
- Question 3 (players waiting for their instrument's entry) stays open: every player plays from tier 0.

## 1. What fits on the platform

**Facts, measured on plate A (`room-cool-crowd-v2-floor/987502-flat1.png`, 1024 by 1536):**

- The platform's top is a four-sided shape. Its corners are about (135, 560), (297, 580), (230, 675) and (0, 675), with the wall cutting the far left corner. Its front skirt drops to about y 765.
- A 390 by 844 phone shows plate x 157 to 867, so the crop starts inside the platform.
- The skirt is about 90 plate px tall and an adult at that spot is about 254 px, so the platform stands about .35 of an adult above the floor.
- Because it is raised, the room's floor formula is wrong here. A person standing on it is `(footY - 384) / 1.146` plate px tall, not `(footY - 384) / 1.5`: 31% bigger. That gives about 167 px at the back edge (y 575), 210 px at the middle (y 625) and 250 px at the front (y 670).
- Usable width is about 1.2 adult heights on the whole plate. On a phone it is about .85 adult at the back and .3 at the front. Depth is about 2.4 adult heights, so the platform is deep and narrow.

**So:** a side-by-side row can't fit. Four players on a diagonal, back right to front left, with the front ones spilling off the phone, can. A fifth would only show on wider screens, so I stopped at four.

| Instrument | Why | In the music's tags |
|---|---|---|
| Upright bass | Tallest silhouette in the room, and it stays on a phone | Yes |
| Congas | Two round drums, nothing else in the game looks like them | Yes |
| Trumpet | The bell makes a shape above head height, and it can swing | Brass |
| Marimba | A long bar shape, wide enough that showing just one end still reads | Yes |

Left out: flute (a thin line at this size), piano (a big dark block, and it hides the player), timbales and cowbell (small, and they read as a second drum).

**Placement, checked by pasting sheet cut-outs on plate A.** This is a proof image, not the game, and nobody has seen it moving. Marks are feet, as fractions of the plate. Height is the player's standing height as a fraction of plate height.

| Player | Feet (x, y) | Height | On a 390 by 844 phone |
|---|---|---|---|
| Trumpet, back | .168, .368 | .104 | Whole, with the bell clear of everyone's head |
| Upright bass | .244, .384 | .117 | Whole. The spike sits right on the platform's edge, so nudge left if it looks off |
| Congas, front | .146, .432 | .159 | His right-hand drum and half of him. The crop passes through his face |
| Marimba, front | .034, .438 | .163 | He's off screen, with at most the tip of the bars at the edge. Only wider screens see him |

**Proposal for the owner to judge:** the phone gets bass, trumpet and half the congas, and tablets and desktops get all four. If you want the conga player's whole face on a phone, he moves right and covers the trumpet. Marimba is the one to drop if four is too many, since a phone never shows him.

The band's cream jackets stand out against the blue windows and violet panels in the proof. The bass sits in front of a cream pilaster's base, and its amber still separates from it.

## 2. The look

One stage look for all four: cream dinner jacket with narrow midnight-violet satin lapels, violet bow tie, dark charcoal trousers, two-tone shoes. It's the reverse of the BlinBlin dancer's violet jacket over cream, and guests wear plum and pink cloth, so a matching cream group reads as staff of the room rather than guests. All four are invented people. I gave them no names.

| Player | Canon pronouns (my choice, change freely) | Silhouette |
|---|---|---|
| Upright bass | she/her | Very tall, rangy, about 65, deep brown skin, silver-white updo. Honey-amber bass as tall as she is |
| Congas | he/him | Stocky, about 55, tan skin, bald, grey moustache, wide grin. Two dark red drums with brass bands |
| Trumpet | they/them | Slight, about 30, light olive skin, flat-top with shaved sides. Brass bell up and to the picture's right |
| Marimba | he/him | Tall, narrow, about 40, brown skin, big round afro, gold round glasses, short greying beard. Rosewood bars, brass tubes |

## 3. Sheets: how they went

Review image: `art_runs/band-sheet-20261107/review.png`, with every take, my picks boxed, the faults named, a line-up beside the cast and the plate proof. Picks are also in `tool/art/references/band-*/front-candidate.png`, and all 40 raws are in `~/.cache/tillandsias-project/kumbia-art/band-sheet-20261107a/`. All used the 2511 LoRA (confirmed in job provenance). Prompts and job lists are in `art_runs/band-*-sheet-20261107*/`. Each take is a new person from words plus a posed skeleton, with Bartender's sheet as style only. The skeleton's arms are data, in `drawing.skeletonOverrides`.

What went wrong, and what I changed:

- **"Shawl lapels" drew shawls.** Pass one gave several players a violet cape. "Narrow lapels lying flat on the chest" cleared it in pass two.
- **The model added a bow to the bass,** on three of four takes in pass one and two of four in pass two, though the words say plucking. I picked a take with none, and the frames will need watching for it. Latin bass is plucked.
- **Conga hands went behind the drums** in pass one. Pass two's "hands lying flat on top of the drumheads, in plain sight" fixed it.
- **Two pass-one marimba players looked boyish.** A short greying beard and a lined face fixed the age.
- **Marimba mallets became one long stick held in both hands** in pass two. Pass three asked for two short mallets, one straight up by his ear, and got them, but all four takes stood him in front of his instrument. Pass four says the marimba stands between him and the viewer, which fixed it. So the marimba took four passes and the others two.
- **Conga drums came out big.** They're fine for reading at small size, but he's wide for the platform.

Worktree note: `studio_run_workflow` only takes paths inside the main checkout. Band sheets use the base graph plus `$node:10.prompt`, and the baked workflow in the run folder holds the same prompt. Checked by comparing the graphs: they differ only in the prompt.

## 4. Pose plan, once the owner approves sheets

Eight drawings a player: **32 jobs, 128 images, about 49 minutes** at the backend's 92 s a job. Today's sheet jobs measured about 95 s of GPU per 4 images, plus queueing.

| Clip | Energy | Drawings | Steps per beat | Beat by beat |
|---|---|---|---|---|
| `relaxed` | 0, relaxed playing | `a`, `b` | 1 | `a` on one beat, `b` on the next |
| `tap` | 1, foot on the beat | `up_a`, `up_b` (plus `relaxed` a and b) | 2 | `relaxed_a`, `tap_up_a`, `relaxed_b`, `tap_up_b`. Foot lands on the beat, lifts on the off-beat |
| `swing` | 2, instrument on the beat | `a`, `b`, `c`, `d` | 2 | `a` peak on one beat, `b` passing, `c` peak on the next, `d` passing |

Energy 1 reuses energy 0's drawings as its foot-down, so the arms stay continuous when the level changes. Only the free foot's heel lifts, and the other stays planted. Peaks land on beats, so all of this is sampled from the transport like everything else in the game.

| Player | `relaxed` a / b | `tap` up | `swing` |
|---|---|---|---|
| Bass | Plucking hand on the strings / pulled off them | Her heel on the picture's left lifts | The bass rocks on its spike, neck left then neck right, her hip going with it |
| Congas | Right palm down, left up / swapped | His heel lifts between the drums | **The drums can't swing.** Hands lift high above his shoulders in turn, shoulders rolling, head back |
| Trumpet | Bell level, small dip / small rise | Their heel lifts | The horn swings in an arc, bell high then bell low, knees bending with it |
| Marimba | Left mallet on a bar, right up / swapped | His heel lifts below the bars | **The marimba can't swing.** Mallets arc wide across the bars, his body sways, the afro bounces |

Fact versus proposal: the owner said "swinging their instrument". Only the bass and trumpet do that literally. Big motion in the hands for the other two is my proposal.

## 5. Can the pipeline carry an instrument?

Read from the code, not tried on a frame. Nothing here has been drawn.

**`props[].clips` as it stands: no.**

- `tool/art/rig/library.json` lists only `shaker`, `bottle`, `glass`, and `definitions.py` refuses any other kind.
- The schema requires one `hand`, `left` or `right`, and the rig places a prop at that wrist (`garments.py`, `build_character`). A bass stands on the floor and takes two hands.
- `plan_qwen_frames.py`, `props_text`, always writes "her other hand is empty", which would contradict every pose here. `drawing.poseOverrides` could blank it pose by pose, which is clumsy.

**What's missing, in order:**

1. **A motion set.** `opponent-64` has no hands on an instrument. The BlinBlin branch (`work/1860-blwv`) shows the route for a new one: a table in `poses.py`, `motion/<set>.json`. Add `band-loop` with `relaxed`, `tap`, `swing`, and reference pose `relaxed.a`. Legs and torso can be shared, with each player's arms in `motion.overrides`. The definitions now use `opponent-64` only to get a skeleton: when the set changes, `check_overrides` will refuse the old `groove.down_l` key until it moves to `relaxed.a`, which is the right reminder.
2. **The instrument as a mask-only garment.** This is my recommendation over extending props. BlinBlin's `gold-chains` on `work/1860-blwv` is the precedent: geometry only to give a region and a place, with Qwen drawing the detail from the sheet. One function in `garments.py` and one word in `library.json` per instrument. It answers the next three items at once.
3. **Colour.** `colour.py` builds ramps only from garments and props, so without a region the amber, red and brass have no ramp and the finisher would snap them to something else.
4. **Registration.** `register_frames.py` scales each frame so its bbox height equals the rig's. A bass scroll or raised bell above the head would shrink the player, and differently per frame. With the instrument in the rig's mask, the two heights agree. Unproven until a pilot runs.
5. **Scoring and packing.** `score_frames.py` counts anything outside the rig as an extra arm. `pack_atlas.py` takes `pixelsPerUnit` from the reference frame's bbox height, which would include the bass. Both are better with item 2, but check the packed height against the player and not the instrument.

**Risk nobody has tested:** whether Qwen keeps an instrument the same across 8 frames. Pilot `relaxed.a` and `swing.a` on the bass first, since the sheet's model-added bow suggests it wanders.

## 6. Data contract for the INDOOR agent (proposal)

**Atlases**, added to `assets/art/ensemble/manifest.json`: `band-bass`, `band-congas`, `band-trumpet`, `band-marimba`, from `assets/art/ensemble/band-<player>-v1.png`. Native 256 by 320, `pixelScale` 3, the same as the definitions' `targets`.

**Frame ids**, from the packer's `{clip}_{drawing}`, the same eight in each atlas: `relaxed_a`, `relaxed_b`, `tap_up_a`, `tap_up_b`, `swing_a`, `swing_b`, `swing_c`, `swing_d`. Reference frame: `relaxed_a`.

**Level data**, a `band` block in the indoor level file:

```json
"band": {
  "energy": [
    {"level": 0, "clip": "relaxed", "stepsPerBeat": 1, "steps": ["relaxed_a", "relaxed_b"]},
    {"level": 1, "clip": "tap", "stepsPerBeat": 2, "steps": ["relaxed_a", "tap_up_a", "relaxed_b", "tap_up_b"]},
    {"level": 2, "clip": "swing", "stepsPerBeat": 2, "steps": ["swing_a", "swing_b", "swing_c", "swing_d"]}
  ],
  "players": [
    {"id": "trumpet", "atlas": "band-trumpet", "feet": [0.168, 0.368], "height": 0.104, "tapFromTier": 3, "swingFrom": 0.75},
    {"id": "bass", "atlas": "band-bass", "feet": [0.244, 0.384], "height": 0.117, "tapFromTier": 2, "swingFrom": 0.25},
    {"id": "congas", "atlas": "band-congas", "feet": [0.146, 0.432], "height": 0.159, "tapFromTier": 2, "swingFrom": 0.5},
    {"id": "marimba", "atlas": "band-marimba", "feet": [0.034, 0.438], "height": 0.163, "tapFromTier": 3, "swingFrom": 0.5}
  ]
}
```

**Rules:**

- **Energy follows the player, through what exists.** Energy 1 follows the music's tier (`tapFromTier`), as `PartyUp` does. Energy 2 follows `crowd.partySwing(beat)` (`swingFrom`), since the rulings make full swing the reward for skill and "tier alone never starts it". A poor run that clears ends tapping, and a good one ends swinging. All thresholds are artistic starting values.
- **One player at a time.** The thresholds differ so the band livens one by one, like the guests.
- **Change clip only on a bar line** (every 4 beats), so a player never jumps mid-gesture. Going down uses `PartyUp`'s hold of two phrases.
- **Frame choice:** `steps[floor(beat * stepsPerBeat) % steps.length]`, from the transport beat. Nothing reads back, so the band can't touch music, notes or score.
- **Height is explicit, never from `PartyFloorPlane`,** because the platform is raised (section 1). Sort by feet y, behind everyone on the floor. They never cross the dance floor, so nothing covers a cue.
- **Reduced motion:** hold `relaxed_a` per the style guide, with the tier still showing elsewhere in the room.
- **Pause and background:** frozen by the transport, like the rest of the foreground.

**Game changes this needs, not done:**

- `lib/gameplay/ensemble_sprites.dart`, around line 116: `requireFrames` sends any unknown atlas id to the furniture frame list, so a `band-*` atlas would fail to load until it gets its own case.
- A renderer for the band, and the level file's `band` block. `levels/` has no indoor file on this branch.
- `party_layout.dart` has `cool-crowd` at horizon .24, and the plate's floor file says .25. Worth settling before marks are final.

## 7. Questions for the owner

1. Which takes? My picks: bass B3, congas B2, trumpet B0, marimba D1, boxed in the review image. These are front views only. No back view is needed, since the band never turns away.
2. Four players, with marimba off a phone's screen, or three?
3. Should a player whose instrument isn't in the music yet wait? The draft ladder has the marimba from tier 1 and brass from tier 3 (`plan/levels/next-level-plan.md`). Holding the horn down until then costs one or two more drawings. Nobody here can hear whether the rendered tiers match those words, so this one needs your ears.
4. Is big hand motion acceptable as "swinging" for the congas and marimba?

## 8. What was built, 2026-11-07

Everything here is a choice made under the owner's delegation, and any of it can be reversed. Nobody has seen the band moving on a phone yet. The PARTY agent has seen three players as stills in the real scene.

### The angle

Each player has a `front_3q` view drawn from the approved front, and frames draw from that view. They face toward picture right, and the plate's crowd is on that side.

| Player | Front (owner approved) | `front_3q` take |
|---|---|---|
| Upright bass | B3 | 989511, run `band-bass-3q-20261107b` |
| Congas | B2 | 989623, run `band-congas-3q-20261107c` |
| Trumpet | B0 | 989712, run `band-trumpet-3q-20261107b` |
| Marimba | D1 | 989813, run `band-marimba-3q-20261107b` |

### Did Qwen keep the instrument? Only with the right wording

This took five rounds, so it's worth recording:

1. **Skeleton much smaller than the sheet:** the instrument was perfect, because the model copied image 1 and ignored the pose.
2. **Skeleton the sheet's size, with "the bass tipped twenty degrees":** the bass went horizontal and was held like a guitar. A music stand and a second hand appeared.
3. **The same, with "leaning a little" and strong words about facing:** half the takes lost the bass, turned away, or held it like a guitar. The strong facing words were the cause.
4. **"Seen from exactly the same angle as image 1" and "the bass exactly where it is in image 1", skeleton at .92:** stable on all four players, and hands follow the skeleton.
5. **Left to Qwen:** a small foot lift doesn't show, and "tapping" draws motion lines. The bass doesn't rock.

So hands and arms are drawn, and the foot and the rock are done in code.

### What is drawn and what is code

| Frame | Source |
|---|---|
| `relaxed_a`, `relaxed_b`, `swing_a`, `swing_c` | Drawn. 2 candidates a pose, per the GPU budget |
| `swing_b` | Drawn, except congas: `relaxed_a` again, because both takes grew a third hand |
| `tap_up_a`, `tap_up_b`, `swing_d` | `relaxed_a`, `relaxed_b`, `swing_b` with the foot lifted by `band_tap.py` |
| Bass rock in `swing_a`, `swing_c` | Those drawings sheared by 7 native px at the top, about the floor, so she and the bass lean together |

Saving: 5 drawings a player rather than 8. On congas the shoe is mostly behind the drum, so the tap barely shows.

**Against the style guide's "authored key poses":** the lift and the shear aren't drawn poses. They're small, and the alternative was an instrument that wanders. Reverse this if it looks stiff on a phone.

**Marimba:** the accepted view ran to the picture's edge, so its frames draw from that view staged at .82 (`stageScale`), and the right end of the bars now shows, which is the part a phone might catch. Its bars' width still differs about 5% in `relaxed_a`, since I locked him by his height, not the bars.

**Picks** are in `tool/art/pipeline/band_finish.py`: bass seed 989511, congas 989620, trumpet 989710, marimba 989810. Review image: `art_runs/band-sheet-20261107/clips-review.png`.

### Finish

- `band_finish.py` locks each frame to its player's `relaxed.a` by what must not move: the instrument, or a trumpeter's leg length. `register_frames.py` scales by the whole figure, so a raised bell shrank the trumpeter.
- It finishes as `finish_local.py` does, with extra rules: blue counts triple, orange pixels can't take brass, and skin can't take drum red. Plain nearest colour painted brass patches on the trumpeter's face, as the PARTY agent spotted. **So these frames aren't the host finisher's bytes.** The conga player's shadows are still a bit rosy.
- `band_pack.py` gives all of an atlas's frames one anchor under the feet, sets `pixelsPerUnit` from the player's height, writes `playerHeightPx`, and grows a rect over empty atlas where the anchor would fall outside it.

The trumpeter's `tap_up` frames don't float, though the PARTY agent asked. With the near foot lifted, the lowest pixel is the far foot, which sits higher in the picture and hasn't moved. Those frames differ from `relaxed` only inside the foot's box, by construction.

### What the local vision model did

40 candidates, hands and instruments counted, about 2 questions each. 30 came back 2 and 1, 8 came back blank when the GPU was busy, and 2 said 4 hands. Its "4 hands" on conga `swing.b` led me to the third-hand fault's frame family, though the true count there is 3. Its "4 hands" on conga `relaxed.a` was wrong, since that frame has 2. It reported 2 hands on bass and trumpet frames, which matched by eye. It wasn't asked about bows, stands or a wandering instrument. Those came from eyes on contact sheets.

### Open for the owner

- Whether players wait for their instrument's entry in the music (question 3). Everyone plays from tier 0 for now.
- Trumpeter's and bassist's relative size: set by the level's `height`, and only moving looks can judge it.
- The people dancing around the band are the INDOOR and PARTY agents' work.
