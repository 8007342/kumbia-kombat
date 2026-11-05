# Level 3 art pipeline: research and GPU probes

2026-11-05. Design research, not production: 49 throwaway images, each reviewed by eye, nothing in
`assets/`. Owner rulings applied: add levels and replace nothing, design for N levels, aim for "a few
prompts and throwing some compute power at it", and a fist bump with the Gatekeeper at the level 1 to 2
transition, keeping the full high five for the finale.

**Verdict.** The riskiest unknown has a working answer. An authored greybox, one Qwen edit pass with an
existing room as style reference, then a no-reference detail pass held the layout in 11 of 11 images:
8 of the diagonal path, covered pool and lawn, and 3 of a different angled ballroom. At phone size the
best sit credibly beside the garden and bar. Because we author the greybox, floor calibration comes from
data, and the runtime's scale formula needs no change. Qwen also drew Mācron from new angles and two new
non-resembling women with no new model. It is not production-ready: the owner hasn't seen it, plates
drift and need a refit, no sprite was finished or played in the game, and a third character wave should
wait until the Qwen route becomes data. A level isn't "a few prompts" yet, but what's missing is mostly
buildable tooling. Taste, charts and listening stay with people.

**Labels.** *Proven*: a probe made it and I looked, on a small sample; never "approved". *Measured*: a
number from the probe scripts. *Reasoned*: follows from code or geometry, not run. *Inferred*: my reading.

## Evidence

Sheets are in `art_runs/level3-probes-20261105/sheets/`, with workflows, prompts, guides and scripts
beside them. Full frames: `~/.cache/tillandsias-project/kumbia-art/level3-probes-20261105/`. Prompts I
checked at ComfyUI `/history` all carried the baked text. Times: 29 s for a first image, 12-19 s after;
389 s at 40 steps.

| Sheet | Shows |
|---|---|
| `rooms-consistency-phone-c3.png` | **Start here.** Garden, bar, two probes at phone crop |
| `rooms-consistency-phone.png` | Earlier saturated pass; a colour harmonise that didn't close the gap |
| `room-pass1.png`, `room-pass2.png` | First passes and alternatives; reference and no-reference detail passes |
| `room-final-pass.png`, `room-second-layout.png` | Best wording on both bases and the ballroom; a reference takeover |
| `c3-floor-overlay.png` | Authored floor grid over a generated plate |
| `proof-scene.png`, `proof-phone-390x844.png`, `proof-water-frames.png`, `proof-water.gif` | Cast placed from the calibration; water frames |
| `cast-fist-bump.png`, `fist-parts-registered.png` | Fist bump as one image and as parts |
| `cast-macron.png`, `cast-new-people.png`, `cast-pair.png`, `a8-build.png` | Mācron; dancers, guest, swimmer; pair; Gatekeeper's build |

## Recommended routes

### Room plate

1. **Author a greybox from data** with a shift-lens camera (no roll, verticals stay vertical). *Proven*
   with a small PIL projector: guide, id map and `floor.json`. Blender isn't needed.
2. **Pass 1, composition.** Qwen: `image1` greybox, `image2` an existing room as style only, 832x1248.
   *Proven*: geometry held on all 5 first passes. Alone it is too flat.
3. **Pass 2, richness.** Qwen on pass 1 with **no reference**. *Proven* 11 of 11 by eye, though one
   gateway changed shape (`970231`).
4. **Generate prompts from the room data**, per A5 (*reasoned*; these were hand-written).

What decided the match (*proven*, by comparison):

- **Wording beat step count.** "Crisp chunky square pixels" gave a saturated cartoon (`c2`). "Very fine
  small pixels, moody low-key lighting, muted, not saturated, not cartoon" joined the family (`c3`).
- **A 40-step base isn't needed.** It's clearly better as a pass 1, but after `c3` the 4-step base looks
  close, at 13 times less time. First written comparison for A3's question: rooms only, one 40-step seed.
- **A reference in pass 2 is a hazard.** On `b-hall` the bar replaced the layout. On `b-from-a4` the
  garden's mansion appeared. On `b-dusk` the joints and a gate post went.
- **Rejected:** SDXL with union line art and IP-Adapter (one image). Edges held, the wet stone was good,
  but tables became lanterns, lawn became paving and the gate a garage door: flat colour carries meaning
  that edges don't. Direct 1024x1536 was no better (one image).

Open: an upscale stage (probes used Lanczos), and people and text gates, which are by eye only. The two
existing rooms came from built-in imagegen prose prompts (their READMEs), which the studio can't reproduce.
Pinned and untested here: FLUX.2 klein, Wan VACE. Not on disk: Qwen-Image-Layered, a 2511 Lightning LoRA.

### Layers and floor

- **Scale needs no runtime change.** Under this camera, standing height is `(footY - horizon) / eyeHeight`
  at any yaw, which is the existing `PartyFloorPlane` formula. *Measured* zero error against the projector
  (this tests only the algebra); *proven* by eye in `proof-scene.png`.
- **Walking needs the homography** in `floor.json` (path coordinates to pixels). `vanishingX` exists in
  Dart, but nothing reads it and level files lack it. Generate waypoints from the homography, since equal
  screen speed looks wrong on a long diagonal (*reasoned*).
- **Refit on the accepted plate.** *Measured* median floor-line offset, 1024-wide px: greybox 2 (the
  metric's floor), pass 1 7-10, pass 2 16-21, or about 4-5 logical px on a tall phone. Horizon and vanishing
  point survive pass 1 within about 12 px. **My automatic fit is unreliable on reflective floors**: it
  said 70 px of horizon error on `c3`, while the overlay sits close. Calibrate from pass 1's clean joints,
  confirm with the overlay by eye, and fail closed on few inliers (A2).
- **Keep the walkway clear in words.** "Leave the paved path exactly as it is... with nothing standing on
  it" worked. "Keep the lower half dark" seems to paint a literal black band (three runs, *inferred*).
- **Bake only what nothing passes behind.** A guest behind a baked table sorts wrongly (*proven*), so
  tables must be floor-anchored prop sprites, like chairs, and leave the plate's greybox (*reasoned*).
- **Occlusion by id map.** *Proven*: pool columns return over swimmers from the greybox's `wall` mask, with
  no segmentation or hidden fill. The spec's four parallax layers stay unproven; inferred, skip them for
  fixed-camera rooms until someone misses them.
- **Swimmers.** Draw only what's above the water, pivot on the waterline, cut with a deterministic line.
  *Proven* need: the model drew legs under water, and BiRefNet removed the water and left them showing.
- **Water.** Mask = dilated id map intersected with pixels really painted cyan (*measured* 71-73% of id
  pixels). Four frames of bands on 4 px cells: *proven* as images only, not in motion, on a phone or under
  reduced motion (hold one frame). One small crop atlas (*reasoned*).

### Cast, guests and Mācron

**New people.** Qwen from text, an existing sheet as style only. *Proven*, two seeds each: two women unlike
the Bartender and each other. A rear view and a dance pose with swinging skirt held identity.

- Height needs its own control: one skeleton drew both at the same height despite "short". Scale per character.
- **Mirrored pair: separate drawings.** One image held both identities but did not mirror poses (0 of 2).
  *Reasoned*: one motion set, flip the skeleton, draw each from her own sheet, mirror floor marks. Flipping
  bitmaps reverses wraps and partings. The scene draws only the first challenger (`plan/adding-a-level.md`).

**Guests and swimmers.** *Proven* once: a new standing guest, true three-quarter, holding a glass, from text.
*Reasoned*: a small data-defined roster at 8-12 poses each, not 64. Guests are always seated in the runtime
(`seatedGuestSlots`), so standing and swimming need `lib/` work. *Measured*: far guests 100-130 source px,
swimmers about 25, barely readable on a phone.

**Mācron.** No rig is needed for new angles. *Proven*, two seeds each, prompt and a concept crop only: raised
fist in three-quarter, rear three-quarter walk to the top right, the gulp. All on model, bar a boxier head and
one sole showing. *Reasoned* next step: a real sheet (front, rear, both three-quarters, side) from
`assets/art/party/macron-dance-v1.png`, accepted by the owner, then cycles from it. **Hand work likely:** cycle
consistency and the canon asymmetric cuff need review and maybe touch-up. `DepartureFacing` has no three-quarter.

### Cinematics

| Fist bump route | Result |
|---|---|
| One image of both | *Proven* 2 of 2: identities held and Gatekeeper is properly stocky. But hands clasp more than bump, Mācron is about 0.5 adult by eye (canon 0.35), one screen face changed, one image drew a floor line |
| Parts, registered | *Proven* as a process, on one floor line at true scale. *Measured*: fists 58 px apart on a 620 px adult (Gatekeeper 0.276 adult, Mācron 0.182). The gap is computable, so a target height can set a skeleton override |

**Recommendation:** parts for anything at game scale, solving the wrist from the contact height. One image only
for a close-up at robot height, if the owner accepts a scale cheat. Even kneeling, his fist must drop to about
0.18 adult; a standing adult can't reach Mācron.

**Gulp.** *Proven* 2 of 2: no mouth invented, the glass at the screen's edge reads as sipping, the oil as dark
amber. `cinematic-shot-pipeline` D2's rig cameras assume the SDXL route and need rewriting for Qwen (*inferred*).

## How close to "a few prompts"

| Step | After planned tooling |
|---|---|
| Brief to room data, greybox, prompts | Agent. **A person reviews the layout** |
| Plates | Compute. **Choosing one is by eye** |
| Calibration, marks, masks, water | Compute, then an overlay check |
| New character sheet | Agent and compute. **Owner approves it** |
| 64 poses | About 98 min per character (`plan/adding-a-level.md`). **Frames need eye review** (A6) |
| Mācron cycles, contact shots | Mostly compute. **Touch-up likely** |
| Scene and chart | Data, once runtime gaps close. **Only a person approves a chart or song** |

A new room is about 30-60 lines of primitives at probe size; the format isn't built. Inferred: a level's art is
hours of compute plus a review session or two. Review is the limit, so build sheets and overlays first.

## Pitfalls, by cost if found late

1. **Phone crop eats corners.** *Measured*: on 390x844, cover shows the central 69% of width (x 157-867 of 1024).
   Our pool's left column and the gate's right post already fall outside. Put a safe area in every greybox.
2. **Camera height sets cast size.** *Measured* adult at foot y 0.62: garden 363 source px (eye 1.54 adults), bar
   752 (0.85), this probe 215 (3.0), where Mācron is about 19 logical px. Use eye 2.2-2.5 or stage lower, and
   settle it in the greybox with cue zones, before any art.
3. **Two-dancer staging and standing guests** are code, not art, and art made first can't be seen (B5).
4. **The scorer assumes trousers.** `score_frames.py` seeks trouser, shoe and skin colours, and a full skirt hides
   knees, so dancers will likely mis-score quietly (*inferred* from code; A2). `register_frames.py` has `--shirt`.
5. **Style drift across N rooms.** Pin one prompt block and a consistency sheet in the room spec. The sheet caught
   `c2`'s failure. Saturation hints at it (`c2` 0.90, `c3` 0.82-0.84, garden 0.69, bar 0.56), so `c3` is still high.
6. **Reference takeover** (above). Keep references out of pass 2, and gate on edge offset.
7. **Baked reflections** have no source and dancers get none. Bright patches may fight cues; check contrast.
8. **Three-quarter skeletons read as rear views.** Yaw 26 gave a clean rear three-quarter, 2 of 2, though the prompt
   asked for front. "45 degrees" from a front sheet barely turned her. Text alone worked for the guest. Pilot each view.
9. **Skeleton scale isn't fixed.** A kneeling figure overflowed at 1.0 and fit at 0.72. Add per-pose scale and a border check.
10. **Negation backfires, and CFG 1 ignores negatives.** "Glasses-free" drew glasses, 2 of 2. "No beard" still gave a
    goatee on 3 of 4 kneeling frames. Describe what is there.
11. **Style reference leaks.** "Gold disc earrings" became the Bartender's hoops, 2 of 2 (*inferred* cause). Use a
    neutral style sheet with no jewellery.
12. **Skirt swing varies per frame.** Inferred jitter; review as a clip. `secondaryMotion` doesn't reach Qwen prompts.
13. **Sprites look lit differently from moody plates** (`proof-phone-390x844.png`). Decide a per-room grade before palettes.
14. **Atlas memory.** All atlases load at startup (`plan/adding-a-level.md`), and a plate decodes to about 6 MiB.
15. **Swimmer legibility.** Bring the pool nearer, or accept it as texture.

## Answers on known problems

**A8, Gatekeeper's build: strong evidence for the prompt.** Same pose and skeleton (`a8-build.png`). *Measured* central
width over height: v3 final 0.335; prompt with "stocky, big round belly, thick arms and legs" 0.40, 0.42; skeleton 22%
wider with that prompt 0.38, 0.41. So the rig skeleton didn't stop him being stocky, widening added nothing, and the
sturdy dancer held her build on a slim skeleton. Limits: one pose, two seeds, unfinished frames; unchecked whether
registration narrows him. **Fix:** a real prompt, plus a measured build check against the sheet on every pilot.

**Shaker.** On purpose, not a model error: character data lists it for `groove` and `challenge`, 12 poses.
`plan/dance-richness-next.md` records the flips in play and one wrong-hand drawing. Redrawing is about 18 min of GPU
(*inferred* from 92 s a pose). Owner's call.

**A9, the two routes.** A new character should use **Qwen for pixels and the data route's front end.** `art.py` has
character data, dry run, keys and ingest, but only SDXL, with no accepted art since 2026-11-05. The Qwen route made both
accepted challengers, but keeps prompts in a `CAST` constant and family names in a two-entry dict. *Measured*:
`art.py build bartender --dry-run` plans 256 SDXL images, knowing nothing of the accepted frames. A real run wastes GPU.

**Fix before a third wave, in order:**

1. Move `CAST` text to `tool/art/characters/<id>.json`; generate per-pose prompts from pose data.
2. Add a `qwen-frame` backend and teach `art.py`, so dry runs, keys and ingest work.
3. Add a sheet stage: text, then accepted front, rear and three-quarter views, with provenance.
4. Add per-character skeleton scale and a border check that fails closed.
5. Add the build check, and generalise `score_frames.py` beyond trousers.
6. Update `.claude/skills/art-family/SKILL.md`, which still teaches SDXL.

## Style guide additions, draft

For `assets/art/STYLEGUIDE.md`; no owner approval yet.

**Rooms as a family.** One shared prompt block: "Richly detailed late 16-bit pixel art night painting with very fine
small pixels and high detail, moody low-key lighting, deep soft shadows, muted natural colours and warm amber lamp glow,
not saturated and not cartoon." Warm lamplight is every room's accent, with near-black shadows and no pure white.

| Room | Base | Accent | Mean saturation, value (measured) |
|---|---|---|---|
| Garden | Midnight navy, leaf teal | Amber, ivory, bougainvillea | 0.69, 0.26 |
| Bar | Plum, dark wood | Amber, teal veins | 0.56, 0.26 |
| Pool lawn, proposed | Navy, deep green | Amber; turquoise only for the pool | Aim at most 0.8, 0.22-0.28 |

**Time of day.** Garden and bar are both night, so dusk runs time backwards unless the story explains it. Default to
night. The dusk probe looked good above the horizon but lost its joints; pilot it separately if wanted.

**Geometry.** Declare per room: eye height in adults (1.5-2.5 unless staging proves otherwise), horizon, vanishing
point, phone-safe rectangle, cue zones. Verticals stay vertical.

**Native resolution.** Plates are 1024x1536, generated at 832x1248 and scaled, with no true grid, like the existing two.
Sprites stay 256x320, pixel scale 3. *Measured* cluster-size proxy (75th-percentile run length, upper scene): garden 2,
bar 3, `c2` 7, `c3` 9. It didn't track the look, since `c3` beat `c2` by eye, so don't gate on it.

**Wardrobe, mansion party.** Visibly grown adults of varied ages and builds. Classy and covered: wrap dresses, full
skirts, linen, guayaberas; hems at or below the knee, necklines closed or modest, and no pose or framing that sexualises
anyone. Swimmers wear modest wide-strapped suits or rash tops, shown from the shoulders up or arms on the pool edge, and
are never the shot's focus. No one may resemble Covi or a reference individual. Review by eye.

**Separation.** Named characters differ in silhouette, hair, colour blocking and height, checked side by side at native size.

**Consistency check per room.** The phone-crop sheet beside all accepted rooms; the floor overlay; a cast proof with an
adult, Mācron at 0.35 and a prop at near and far marks.

## Tooling gaps, project side

- `tool/art/rooms/<id>.json` compiler: primitives to guide, id map, `floor.json`, prompts. Update `room-art-pipeline`,
  whose D4 assumes authored masks, `image.generate` layouts and four parallax layers.
- Level files: add a homography, safe area and path. A route validator can use the id map's walkable pixels.
- Level brief should compile to `levels/<id>.json`. `plan/level-3-readiness.md` describes a different level 3, a
  semicircle in a dance room, and needs reconciling, since levels are added and not replaced.
- Three-quarter values in `DepartureFacing` and `BattleFacing`; standing and swimming activity kinds.
- A contact solver: from two sprites and a contact point, output skeleton overrides and offsets.

## Host and forge requests

Generic capabilities with Kumbia as the example, for demon_attack, cannonball and macron.dev too.

1. **Studio job handles.** A queue returning a ticket, with status and results surviving a lane restart. `run_workflow`
   blocks, so a 64-pose wave needs a babysitting agent.
2. **Durable outputs.** A `run_workflow` option writing results and provenance to the project's persistent cache.
3. **Engine truth as a tool.** A read-only `studio.history` with each node's real inputs; we `curl` a hard-coded enclave
   IP. Generate provenance from the queued graph. Beyond the known 2001-stpr fix, which still needs re-testing.
4. **Overrides by `$`-title for any node input,** numbers and sizes included, refusing unused overrides. This probe alone
   needed 30 baked workflow copies.
5. **Two model pins, subject to licence checks:** a Lightning LoRA built for the installed edit model, to settle A3, and
   a layered-image model such as Qwen-Image-Layered.
6. **`studio.finish_pixels` without a character family:** a plain palette and grid spec, for backgrounds, tiles and UI.
7. **Review surface.** Publish a folder as a side-by-side sheet at a chosen device size, with a recorded verdict. Reviews
   limit "a few prompts" in every project.

## Questions only the owner can answer

1. Does the look in `rooms-consistency-phone-c3.png` belong with the garden and bar? Everything rests on this.
2. Night or dusk, given the earlier rooms are night?
3. Where does this level go: after the bar and before the "cool crowd" semicircle, or does it become that level?
4. Gatekeeper on one knee for the fist bump: right for him? Is a scale cheat allowed in close-ups?
5. Do the `cast-macron.png` views count as Mācron?
6. Are the two women challengers playing one chart together, or a gate before one? The sample dancers are throwaway, not casting.
7. Swimmers as texture, or legible, which moves the pool nearer?
8. Is a cast smaller than the garden's acceptable, if the higher camera is what shows the lawn and pool?
9. Shaker: remove it or use it throughout? Is dark amber right for the oil?

## Not done or not known

- No sprite went through registration, `finish_pixels` or atlas packing, or into the game. No real-phone, motion, cue
  contrast or performance test. Samples are small; 40-step, SDXL and 1024x1536 were one seed each.
- My ballroom guide put chandelier discs on the floor, and the model kept them as floor glows: guide errors get drawn faithfully.
- The checkout changed branch during the work (`work/1839-intg`, a peer's merge in progress). I read it and didn't touch it,
  so `lib/` and `levels/` references reflect that tree and may move.
