# Close-ups and the Mācron pilot, 2026-11-05

Throw-away research batches on local GPU, approved by the owner. Nothing was promoted: `assets/`, `lib/` and `levels/` were
not touched, `accept-sheet` was not run, and no Mācron sheet view counts as approved. All keep rates are one reviewer's
eye (the agent), not the owner's. Labels: **proven** means it happened in this run and can be seen on a sheet, **measured**
means a number from a script, **unverified** means not tested.

Sheets: `art_runs/closeups-20261105/sheets/`. Raw and finished frames: `~/.cache/tillandsias-project/kumbia-art/{macron-v1-20261105a,closeups-20261105}/`.

## Cost, measured

| Part | Jobs | Images | Minutes on GPU |
|---|---|---|---|
| Mācron pilot, run `macron-v1-20261105a` | 19 | 76 | 18.8 (the dry run said 29.1) |
| Close-ups, run `closeups-20261105` | 22 | 86 | 27.5, plus 2.6 waiting on another session's GPU work |
| **Total** | **41** | **162** | **46.3** |

At 768x960 a job of 4 takes about 59 s, or 12 s an image after a 21 s first one. `art.py`'s 92 s a job is about 1.5 times too
high on this host now. 1168x1648 costs about 19 s an image, and a second reference image adds about 7 s an image.

## Part 1: the Mācron pilot

`signature_step` was not drawn. Six sheet views came first, then 13 frames for `fist_bump`, `gulp`, `rear34_walk` and `high_five`.

**Sheet views** (`macron-sheet-views.png`, source beside each row).

| View | Kept by eye | Finding |
|---|---|---|
| Front | 4 of 4 | On model. Cuffs appear on both forearms (0 of 4 on one arm only, which the prompt asks for) |
| Rear | 4 of 4 | On model, and the seam reads |
| Three-quarter right, left | 1 of 4 each is the least boxy | **Boxy head drift, as feared.** Flatter top, squarer corners |
| Side | 0 of 4 | Clearly a box. Don't use it as a reference |
| Rear three-quarter | 3 of 4 | Boxy, with one drawn arc on the head (980003) |

*Measured*, head corner fill (share of the head box's corners that are filled, higher is boxier): approved `front_idle` 0.038,
front 0.031, rear 0.034, three-quarter 0.356 and 0.363, rear three-quarter 0.247, side 0.536. So front and rear hold his
shape, and every turned view loses it by about ten times. Frames inherit the drift from their view. The metric reads a raised
arm as head, so don't read it for frames with an arm beside the head.

**Decision made here:** three-quarter is off model enough for the owner to care but not enough to stop a throw-away pilot,
so frames ran from the least boxy picks: front 980001, three-quarter right 980000, rear three-quarter 980002. These were
staged only on the lane, flattened onto light grey.

**Frames** (`macron-fist_bump.png`, `macron-gulp.png`, `macron-rear34_walk.png`, `macron-high_five.png`; 4 images a pose).

| Pose | Kept | Failure |
|---|---|---|
| `fist_bump.contact` | 4 of 4 | Boxy head inherited |
| `fist_bump.ready` | 3 of 4 | One lost its arm |
| `fist_bump.settle` | 2 of 4 | Arm hidden or hand on the chest |
| `gulp.lift` | 1 of 4 | Glass in the wrong hand 3 of 4 (picture side ignored), though all on model |
| `gulp.sip` | 1 of 4 | Wrong hand 3 of 4. All read as sipping, with no mouth |
| `gulp.after` | 2 of 4 | Extra hoop-shaped arms twice |
| `high_five.ready` | 0 of 4 | Fist held out in front, not an open hand low and back. A mouth once |
| `high_five.contact` | 4 of 4 | Hand reaches only head height, with fingers he doesn't have |
| `high_five.after` | 3 of 4 | A mouth once |
| `rear34_walk`, 4 poses | Single frames fine, **the cycle fails** | See below |

- **Invented mouth:** *proven* rare, 2 of 76 images, both in `high_five` with a smile under the arcs. 0 of 12 in `gulp`, where the
  prompt says what the screen does.
- **Size growth:** *measured*, `character_check.py` build 0.562 against the reference's 0.615 (8.6% narrower), so no growth. Height is forced
  by registration, 52 of 52 registered with no frame touched. Registration with an arm past the antenna stays *unverified*: no arm got that high.
- **Cuffs on one arm:** fails nearly everywhere, by eye. It isn't worth more prompt effort until the owner says whether he cares.
- **Walk:** *measured*, silhouette overlap of `step_r` and `step_l` picks is 0.966 (legs 0.948), so the model draws the same step twice and
  left and right don't alternate. `pass_r` does differ (0.61). This answers the README's open question: a walk cycle does not hold
  together from words alone. See `macron-walk-picks.gif`. Next try: mirror one step, or a key-and-chain approach as below. Not tried.
- **Possible pipeline bug:** matted sheet outputs have black under their alpha (pixel `[0,0,0,0]`), and `accept-sheet` copies them as they are.
  ComfyUI's `LoadImage` drops alpha, so an accepted view may reach Qwen on black. *Unverified*: I flattened mine rather than test it. Check before the first `accept-sheet`.

**Candidate:** `art_runs/macron-v1-20261105a/candidate/`, 13 frames, in the manifest's frame fields at `pixelsPerUnit` 6.4865. It was made by
`art_runs/closeups-20261105/scripts/macron_pack.py`, not by `art.py`, since `drawn` characters have no family spec or palette: 3x nearest, binary
alpha, no palette lock. Not loaded in the game. Its fist bump and gulp are overtaken by the owner's close-up ruling.

## Part 2: close-ups

**Result: the route works.** Separate drawings give a readable fist bump and gulp, with no kneeling, no clasping and no growth, at a controlled size
ratio (*measured* big fist about 1.6 times the small one, in art px, by placement). Best view: `phone-fist-contact-1170x2532.png`, `phone-gulp-tilt-1170x2532.png`.

### Native size

*Measured* from `party_layout.dart`'s formulas and an earlier probe (`plan/duet-foundations.md`): a 390x844 phone at 3x maps a plate's source pixel to
1.65 device px, and a sprite art pixel to 1.48 to 2.39 device px. A close-up of 390x500 logical is 1170x1500 device px, so that range means
488 to 780 art px wide.

**Chosen: 1 art pixel = 2 device pixels at 3x.** So 390x500 logical is 585x750 art px. The plate used here is 584x824, which fills the
whole top 65% (390x549 logical), and the whole phone is 585x1266. It's mid-range, and an integer at 3x, so edges stay even there. At 2x it's 1.33 device px and
uneven, so it wants the sharp bilinear filter already probed. Not tested on 2x.

**But the grid isn't the whole story.** Qwen draws its own larger "pixels" and the grid only samples them. *Measured proxy* (edge-comb period, noisy, the same tool on everything):

| Art | Drawn cell, device px at 3x |
|---|---|
| Gatekeeper v4 atlas frame (world) | 3.1 to 5.9 |
| Garden and bar plates (world) | about 10 by this comb, 12 to 13 by colour run |
| Finished fist, Gatekeeper | 6.4 to 7.2 |
| Finished fist, Mācron | 5.8 |
| Finished hand and glass | 4.2 to 5.7 |
| Finished plates | 10 to 13 |

So plates match the world and small actors roughly do, but **the big fist is measurably chunkier than world sprites**, by up to 2 times, and by eye it does read a little
chunky. A larger canvas (1536x1152) did not clearly help: the comb said 8 to 9 canvas px, by eye forms just got simpler, and its sleeve trim turned into a shirt placket
3 of 4 times. Drawing it smaller on the same grid would help but shrinks the fist. Owner's eye decides; not resolved here.

### What was drawn, and keep rates

Sheets: `gk-fist.png`, `mc-fist.png`, `gulp-hands.png`, `plates.png`, `finished-actors-native.png`.

| Drawing | Route | Kept | Failure |
|---|---|---|---|
| Gatekeeper impact | Sheet and words | 2 of 4 | Grey line artefact; bulging wrist |
| Gatekeeper approach | Sheet and words | 2 of 4 | Works alone but another fist each time |
| Gatekeeper approach | **Chained from the impact pick** | 3 of 4 | Sleeve thickened once |
| Gatekeeper recoil, first wording | Chained | 0 of 4 | The teal cuff moved to his wrist, 4 of 4 |
| Gatekeeper recoil, sleeve named | Chained | 2 of 4 | Invented motion lines twice ("bounced") |
| Gatekeeper impact, 1536x1152 | Sheet and words | 1 of 4 | Trim became a shirt placket |
| Mācron impact | Sheet and words | 3 of 4 | A floating ball |
| Mācron approach | Sheet and words | 4 of 4 | Forms vary |
| Mācron approach, recoil | Chained | 8 of 8 | Almost the same drawing as the key |
| Hand and glass, first wording | Sheet and words | 2 of 4 | Stemmed wine glass |
| Hand holds tumbler | Sheet and words | 4 of 4 | |
| Tilt | Chained | 4 of 4 | Tilts about 15 degrees, less than asked |
| Oil nearly gone, first wording | Chained | 0 of 4 | Spilled out under the glass ("pool") |
| Oil nearly gone, reworded | Chained | 3 of 4 | One level too high. Level falls to about a third, not near empty |
| Glass alone | Sheet and words | 0 of 4, then 0 of 4, then 4 of 4 | Target rings ("ripple"), then the whole glass leaned ("leans"), then fixed by saying upright and letting the engine slide it |
| Plate from a level plate as reference | Reference and words | 0 of 2 | Copied the mansion |
| Garden plate from a CPU guide | Guide and words | 4 of 4 for composition | Bokeh discs are hard-edged flat circles |
| Bar plate from a CPU guide | Guide and words | 4 of 4 | Best plate of the run |
| Garden plate, softer guide | Guide and words | 0 of 4 | Discs and foliage turned to blobs |

*Measured*, on the routes that worked, after wording fixes: 33 of 40 usable (first wordings and the 1536 test excluded, so this flatters the route). Counting everything drawn except plates: 42 of 72.

**Chaining** (*proven*, small sample): give the first pick as image 2 and ask for the moment before or after. Same fist each time, by eye, which is what separate drawings
otherwise lose. The cost: pose change shrinks. *Measured* silhouette overlap with the key: chained Mācron 0.79 to 0.93, Gatekeeper approach 0.83 to 0.91. Only a recoil
that names a big tip moves far (0.53). Since the engine carries the travel, that may be fine; Mācron's three drawings are close to one, though, and impact has no squash.

### Compositing test (PIL only)

`phone-fist-contact-1170x2532.png`, `phone-gulp-slide-1170x2532.png`, `phone-gulp-tilt-1170x2532.png`, `fist-three-beats.png`, `gulp-four-beats.png`.

- **Contact**: *measured* art (222, 561), logical (148, 374), 44% of phone height, clear of the band at 65%. 3 art px of overlap at impact, with nothing clasped.
- **Tap band** left empty in all, drawn dim for reference. Its circles are a mock, not the game's.
- **Arms off frame** by CPU: where a canvas ended short of the frame, I repeated its last clean row along the arm's slope. Reads fine at speed, and on stills Mācron's forearm shows
  straight streaks and a pointed end at the frame's corner. A prompt for a longer forearm may be better. *Unverified*.
- **Palette**: actors finished through `studio.finish_pixels` with research-only family files, plates with the level's own 48 colours. A mixed garden and bar palette turned copper to mustard, so a plate wants its own level's palette.

### GIFs (timed in beats, no sound)

`fist-bump-104bpm.gif` and `gulp-104bpm.gif`. **Neither has sound, neither is the game's renderer.** Both are nearest-pixel GIFs at 585x1266, to be viewed at phone size. Fist bump: 1 beat approach, impact on the
beat, 1 beat recoil, 1 beat hold to loop. *Measured*, GIF's 10 ms steps: impact at 580 ms (target 577), recoil ending at 1150 ms (target 1154). The gulp GIF was not asked for; it's there to judge the sequence.
Whether it feels right moving is *unverified*: nobody has watched it on a phone, and the plan requires that.

## What failed, in general terms

Words are taken very literally: "bounced" drew motion lines, "ripple" drew concentric rings, "pool" drew a puddle under the glass, a leaning surface leaned the glass. Say the visible thing and leave motion to the engine.
Naming where something stays works ("the sleeve stays at the right edge, far from the wrist"). A reference image's composition wins over "using only its colours".

## For the owner to rule

1. **Sleeve.** His reference has short sleeves with a plain hem, and no cuff. "Purple guayabera cuff" drew a teal embroidered band at the hem, which is invented but looks right.
2. **Mācron's fingers.** His sheet has mitten hands, and the close-ups draw jointed steel fingers. Reads well as "steel fist"; it's a change, though. His hand also looks large around the glass, which the rule allows.
3. **Gatekeeper's skin** comes out brighter and more orange than `front-stocky.png`, though close to his atlas ramp.
4. **Three-quarter head**: accept, or refine the sheet by hand before frames depend on it.
5. **Garden plate**: flat bokeh discs compete with the fists. Fine for a test; I'd try hand-placed glows without Qwen next.

## What the format should say (`plan/cinematics.md`)

- Contact points belong to a frame, in art px, not to an actor: each drawing's knuckle is somewhere else. The sketch's `[0.52, 0.48]` is well off the (0.38, 0.68) of the plate measured here.
- An actor needs an exit edge and offsets per frame in whole art px, plus a recorded native size.
- A shot lists a `band` check: art stays above 65%. Keep beats as the clock; the GIF showed that 10 ms rounding is no problem.
- Proposed plate entry: `{"art": 584x824, "artPixelDevicePx": 2, "palette": "garden"}`. Field names are a sketch.

## What the style guide should say (draft, not approved)

- Close-ups use a grid of 2 device px at 3x. The whole top 65% is a 584x824 plate.
- Each close-up actor is drawn separately. Draw the contact pose first, then chain the others from it.
- Name what remains in place, name a held prop's hand by picture side, and say what a held glass is ("short straight-sided tumbler").
- Every limb runs off the frame. Size ratios come from placement, so a robot can't grow.
- Plates come from a CPU guide, with each level's own colours; a level plate used as reference gets copied.
- Don't use side or turned views of Mācron as references without a check for boxiness.
