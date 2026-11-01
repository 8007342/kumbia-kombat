# Asset inventory and runtime contract (for the image pipeline)

Status: reference document compiled 2026-11-01 from the `game` branch at
`e045f16`. Audience: the sibling team building the ComfyUI generation pipeline
and review studio. Everything here is grounded in code, manifests, plans or
measured PNG data. Statements marked **(inferred)** are the compiler's reading,
not something the codebase states. No code was changed to produce this.

Unmerged context: `origin/work/2610-pipe` (not on `game`) adds
`plan/sprite-generation-pipeline.md`, `assets/art/pipeline/` (two Gatekeeper
cloud candidates with `run.json` records) and an `opponent-performance`
OpenSpec change. These are cited below as "2610-pipe" where they matter.

Status legend used in tables: **exists** = registered runtime art drawn by
the scene today; **preview** = generated art exists (runtime or candidate) but
the plans flag it as not production-clean; **missing** = no art in the repo;
**lost** = generated once, not recoverable, must be regenerated; **blocked** =
must not be produced yet.

---

## 1. Runtime manifest contract (as actually parsed)

### 1.1 What the game loads

`GardenScene.onLoad` (`lib/gameplay/garden_scene.dart:68-98`) sets the image
prefix to `assets/art/` and loads, all-or-nothing:

| Source | Parsed by | Images decoded |
|---|---|---|
| `assets/art/party/manifest.json` → **only** `atlases.hero` | `PartyAtlasDefinition.fromJson` + `requireFrames(heroFrameIds)` (`garden_scene.dart:71-76`) | `party/macron-dance-v1.png` |
| `assets/art/ensemble/manifest.json` | `EnsembleManifest.fromJson` (`ensemble_sprites.dart:102-124`) | 7 atlases: `guest-woman-v2`, `guest-man-v2`, `guest-host-v2`, `gatekeeper-v2`, `bartender-v2`, `party-life-v2`, `furniture-v2` |
| Room background | `showRoom()` (`garden_scene.dart:103-118`) | `garden/garden-mansion.png` or `bar/bar-interior.png` (paths from `lib/gameplay/rooms.dart:26,35`) |

Any parse error, missing frame or size mismatch throws, and the scene shows
"Party character art could not load" (`garden_scene.dart:95-97`). There is no
partial fallback: **a generated manifest must satisfy every required frame ID**.

Bundled but not used by the scene: `party/guests-v1.png` (the old `crowd`
atlas, still validated by `test/party_sprites_test.dart`), `garden/gatekeeper.png`
and `bar/bartender.png`. These are passed to `showRoom` as a second argument
that the code ignores (`garden_scene.dart:101-103`). Also unused: frame
`arm_sweep` (hero) and `umbrella_closed` (furniture). `umbrella_closed` is
nevertheless *required* (`ensemble_sprites.dart:56`). The `pubspec.yaml:67-73`
asset folders are `ui/`, `art/garden/`, `art/bar/`, `art/party/`,
`art/ensemble/` and `music/scores/`. `assets/art/macron-dance-concepts.png` and
`assets/art/references/` are deliberately not bundled.

`assets/art/garden/manifest.json` and `assets/art/bar/manifest.json` use an
older, different schema (`assets[]` with `id`, `file`, `width`, `height`,
`format`, `status`, `sampling`, a normalised `anchor`, `provenance`, `notes`).
**No code parses them.** They are documentation only.

### 1.2 Atlas JSON schema

Top level (ensemble; the party file has the same shape):

| Field | Type | Enforced | Ref |
|---|---|---|---|
| `version` | int, must equal `1` | Ensemble: yes. Party: only in `PartySpriteManifest` (tests). The scene's hero path skips the check. | `ensemble_sprites.dart:104`, `party_sprites.dart:146` |
| `status` | string | Ignored by code | — |
| `atlases` | map of atlasId → atlas | Ensemble needs all 7 IDs `guest0, guest1, guest2, gatekeeper, bartender, life, furniture` | `ensemble_sprites.dart:92-100,108-110` |

Atlas object (`PartyAtlasDefinition.fromJson`, `party_sprites.dart:59-128`):

| Field | Type / units | Rules |
|---|---|---|
| `image` | string, bare filename | Non-empty, may not contain `/` or `..` (`:64-67`). Resolved relative to the manifest's folder (`garden_scene.dart:83,85`). |
| `imageWidth`, `imageHeight` | int, source pixels | > 0, and must equal the decoded PNG size, or `PartySpriteAtlas` throws "size mismatch" (`party_sprites.dart:167-170`). |
| `frames` | map frameId → frame | Non-empty. |
| `referenceFrame` | string | **Present in the ensemble JSON but never read.** Scale references are hard-coded; see 1.4. |

Frame object:

| Field | Type / units | Rules |
|---|---|---|
| `rect` | `[x, y, w, h]`, source px, top-left origin | 4 finite numbers, each an **integer value** (`:113`). w,h > 0. Must lie wholly inside the image (`:107-112`). |
| `anchor` | `[ax, ay]`, source px **relative to rect's top-left** | Finite, `0 ≤ ax ≤ w`, `0 ≤ ay ≤ h` (`:114-117`). Fractions are allowed. |
| `pixelsPerUnit` | number > 0 | Finite (`:90-95`). See 1.4 for what it really does. |
| `mirror` | bool, optional, ensemble only | Non-bool → FormatException (`ensemble_sprites.dart:68-71`). |

Any extra keys are ignored. That includes the planned keys in 1.6.

### 1.3 Anchor and draw semantics

`PartySpriteFrame.destination` (`party_sprites.dart:41-49`) places the
frame so that its anchor pixel lands on the projected **floor root**:

```
factor = scale / pixelsPerUnit
dest   = (ground.x - ax*factor, ground.y - ay*factor, w*factor, h*factor)
```

- **People, Mācron, challengers, waiter, chairs, tables and umbrella+table:**
  the anchor is the floor contact (between or under the supporting feet or
  legs). Existing anchors use `ay = h` (bottom edge) for ensemble people. Hero
  anchors sit 2 px above the rect bottom because of the 2 px crop margin
  (`assets/art/party/README.md`).
- **Seated guests keep the floor anchor,** not the seat. Chair-free person
  frames keep their original full-cell floor pivot (`plan/party-perspective-and-life.md`,
  `party_layout.dart:164-166`).
- **Hanging plant:** the anchor is at the **cord top**. The scene places that
  point at `floor − adult×heightInAdults` but depth-sorts by the floor
  (`garden_scene.dart:390-394,432-449`).
- Sampling is nearest-neighbour (`FilterQuality.none`, `party_sprites.dart:174`,
  `garden_scene.dart:228`). The ground point is rounded to whole logical units
  before drawing (`party_sprites.dart:186`).
- Horizontal flip is about the anchor x (`canvas.scale(-1,1)` after translate,
  `party_sprites.dart:185-188`). **The anchor x must therefore be the visual
  centre of support,** or flipped poses jump sideways **(inferred)**.
- Depth sort is by floor y, then layer, then id (`ensemble_sprites.dart:247-255`).
  Raised hands and frame bounds never affect sort order.
- Shadows are procedural ovals at the root, `0.34 × 0.065` of standing height
  (`garden_scene.dart:273-281`). **Generated art must contain no baked shadows
  or floor.**

### 1.4 `pixelsPerUnit` and reference frames: how scale actually works

Each actor's on-screen size comes from the **room floor projection**, not
from its pixel size. The scene computes
`scale = projectedHeight / nativeHeight(reference)`, where
`nativeHeight = reference.rect.h / reference.pixelsPerUnit`
(`ensemble_sprites.dart:80-86`). Substituting into the destination formula
gives `destHeight = projectedHeight × frame.h / reference.h × (refPPU / framePPU)`.

Consequences for the generator:

1. **Absolute pixel resolution and absolute `pixelsPerUnit` cancel out.** Only
   the ratio of each frame to its reference matters. All current sheets use
   `8.0` (the old `guests-v1` used `8.5`).
2. **Keep `pixelsPerUnit` uniform within an atlas.** A different value on one
   frame silently rescales that pose.
3. **The whole sheet must be drawn at one scale.** A seated or crouched pose
   must be genuinely shorter in pixels than the standing reference. Never
   fit each pose to the cell.
4. Hard-coded reference frames (the manifest's `referenceFrame` is ignored):

| Atlas | Reference frame used by code | Manifest `referenceFrame` | Ref |
|---|---|---|---|
| hero (Mācron) | `front_idle` | (none) | `garden_scene.dart:563-564` |
| guest0-2 | `standing_idle_a` | `standing_idle_a` | `garden_scene.dart:307-309` |
| gatekeeper / bartender | **`ready`** | **`occupied` (mismatch)** | `garden_scene.dart:522` |
| furniture chair | `chair_right` / `chair_left` (each its own) | `chair_right` | `garden_scene.dart:353-354` |
| furniture table | `table` | — | `:356-358` |
| life | `umbrella_a`, `plant_a`, `candle_a`, `waiter_a` per kind | `umbrella_a` | `:359-389,417,447,471` |

Reference frames should be a neutral, full-height, upright standing pose for
characters. Furniture and props are scaled to `adult × heightInAdults`
(`garden_scene.dart:389`). The values are chair .80 adult height and .53
width (`party_layout.dart:259-262`), table .43/.90, umbrella 1.35/1.50
(`:278-305`), table candle .16 adult (`garden_scene.dart:417`), wall plant .62
adult (`:428`), and the waiter at full adult height (`:471`).

### 1.5 `mirror`

`flipFor(id, facingFlip) = facingFlip XOR mirror[id]` (`ensemble_sprites.dart:77-78`).
It exists only to correct anatomy: both challengers' generated `right_foot`
repeated the left leg, so `right_foot` has `mirror: true`. This is allowed
only for **symmetric costumes**. Mācron's cuff is asymmetric and is never
mirrored (`assets/art/ensemble/README.md`). The hero draw passes no flip at all
(`garden_scene.dart:624`). Guests are flipped by `!slot.facingRight`
(`:321`). Challengers are never facing-flipped today.

### 1.6 Planned contract fields: not yet implemented

`plan/assets.md` ("Animation contract") specifies: `id`, `file`, `cellWidth`,
`cellHeight`, `frames` (rects or grid indices), `pivot` (normalised bottom
centre), `facing` (rear/front/side), `loop`, `durationBeats`, `events` (beat
offsets), `status` (concept/clean/runtime) and `provenance`. Further planned
fields come from `plan/party-overhaul.md`, `plan/dance-fluidity-pass.md`,
`plan/crowd-animation-system.md` and `openspec/specs/art-direction/spec.md` §Asset
acceptance.

| Planned field | Implemented? | Today's substitute |
|---|---|---|
| `id` / `file` | Partly | Atlas key and `image` |
| `cellWidth/cellHeight`, grid indices | **No** | Explicit measured `rect` per frame; equal-grid slicing is forbidden (`party_sprites.dart:33-34`) |
| `pivot` normalised | **No** | `anchor` in absolute source px, rect-relative |
| `facing` (rear/front/side) | **No** | Encoded in frame names (`rear_*`, `profile`, `spin_*`) |
| `loop`, `durationBeats` | **No** | Hard-coded in Dart (see §3 timing column) |
| `events` / beat markers (anticipation, accent, foot plant, release, settle, contact) | **No** | Hard-coded phase fractions in `challenger_choreography.dart:280-309` and `playerMovePose` |
| `supportFoot`, attachment points, reduced-motion pose | **No** | — |
| `status` | Only top-level free text | — |
| `provenance` | Separate `provenance.json`, not parsed | `assets/art/{party,ensemble}/provenance.json` |
| palette / recolor regions | **No** | Implicit colour key (§2) |
| license | **No** | Upstream reference license is still unrecorded (`plan/assets.md`) |

The 2610-pipe run record (`run.json`) adds `runId`, input reference hash,
output sha256/size/alpha stats, prompt, seed and a validation checklist. It is
a good template for the pipeline's provenance. No code reads it.

**Recommendation (inferred):** emit the planned fields alongside the parsed
ones. Unknown keys are ignored today, so they are forward-compatible. Keep
`rect`/`anchor`/`pixelsPerUnit` exactly as specified above.

### 1.7 Test-enforced asset properties

Replacing a PNG can break these tests. Update the fixtures as part of a pipeline
promotion.

- `test/party_sprites_test.dart:17-60`: every party atlas must decode at the
  manifest size. The top-left pixel must have alpha 0, more than 35% of pixels
  must be fully transparent, `left_hand`≠`right_hand` and `left_foot`≠`right_foot`
  rects, and there must be 18 distinct crowd rects.
- `test/ensemble_sprites_test.dart:72-107`: exactly **132** frames across the 7
  atlases, and more than 30% fully transparent pixels in each atlas.
- `test/outfit_palette_test.dart:~150-250`: hard-coded **pixel regions** of
  skin, hair and clothing inside `guest-{woman,man,host}-v2.png`. Skin and hair
  must change by ≤2 per channel. More than 35% of each garment region must
  change. Garment alpha must be unchanged.

---

## 2. Outfit recolor contract

Source: `shaders/party_palette.frag` and `lib/gameplay/outfit_palette.dart`.
Design notes are in `plan/party-perspective-and-life.md` §Clothing palette and
`plan/wardrobe-rendering-stability.md`.

**Scope:** recolor applies **only to guest atlases `guest0-2`**
(`garden_scene.dart:310-323`). Challengers, Mācron, life and furniture are
drawn as-is. The cache is capped at 12 variants (3 guest atlases × 4 outfits;
`outfit_palette.dart:16`). Each variant is a whole-atlas raster made once.
Until it is ready, or if the shader fails, the **plum source is drawn**
(`:71-97`).

**Mask.** The shader works on un-premultiplied RGB (rgb/alpha) in the 0–1
range, with channels r, g, b. A pixel is recolored if it passes any one gate:

| Gate | Conditions (all must hold) |
|---|---|
| cool (original purple) | b ≥ 0.12; r ≥ 0.70·b; b ≥ 0.99·r; g ≥ 0.20·b; g ≤ 0.66·b |
| plum (saturated wine/plum) | r ≥ 100/255; r ≥ 0.70·b; b ≥ 0.32·r; g ≤ 0.55·b; b − g ≥ 12/255 |
| pink (bright pink) | r ≥ 180/255; r ≥ 0.70·b; b ≥ 0.32·r; g ≤ 0.86·b; b − g ≥ 12/255 |

These are hard `step()` thresholds with no softness. Pixels with alpha ≤ 0.0001
pass through unchanged.

**Transform.** `V = max(r,g,b)` and `S = (V − min)/V`. The hue vector is the
outfit triple normalised by its max channel. Output = `mix(V, hue·V, S)`, then
re-premultiplied. Source value and saturation are kept and only the hue is
replaced. The outfit triples (`outfit_palette.dart:104-109`) are:

| `OutfitColor` | (r, g, b) |
|---|---|
| teal | (0.18, 0.72, 0.60) |
| blue | (0.23, 0.47, 0.92) |
| coral | (0.94, 0.34, 0.25) |
| gold | (0.95, 0.69, 0.19) |

**Validation.** Output alpha must match source alpha within **±2/255 at every
pixel**, or the variant is discarded (`outfit_palette.dart:152-155`).

**Reference colours.** Measured source cloth colours are plum (146,31,87),
wine (154,11,66) and bright pink (254,83,107). The original cool ramp was
#4B245E, #874197 and #C878D6. Coverage on current sheets: woman 32.05%,
man 32.74%, host 23.75% of opaque pixels.

**Constraints for generated guest art:**

1. Every recolorable garment pixel, **including its shadows and highlights**,
   must fall inside a gate. Deep warm shadows with r < 100/255 that miss the
   cool gate stay plum on purpose. That keeps darker folds unrecoloured, so
   avoid relying on them for large cloth areas **(inferred)**.
2. Every non-garment pixel must fail all gates: skin, lips, blush, hair
   (watch plum-tinted hair), eyes, jewellery, shoes, hats, cream or neutral
   cloth, drinks, flowers and outlines. Magenta or pink may appear **only on
   recolorable clothing** (prompt rule in `ensemble/provenance.json`).
3. Neutral items stay out of the ramp, for example the host's cream hat and
   trousers and the man's cream sleeves.
4. Use hard (binary) alpha on garments. The shader divides by alpha, so
   low-alpha fringes recolor noisily **(inferred)**.
5. Challenger and furniture art may use plum freely today, because they are
   never recolored. If the pipeline ever routes them through the palette, the
   same rules apply.
6. `wardrobe-rendering-stability.md` lists an explicit per-pixel clothing
   mask layer and pre-baked PNG variants as later alternatives. A pipeline that
   emits a separate mask would enable this, but **no code consumes a mask
   today**.

---

## 3. Clip and pose inventory

Timing is in transport beats unless it says "s". Frame selection is always
sampled from the music clock (or the foreground seconds clock for ambient
props), never from render frames.

### 3.1 Frames the code requests today

**Mācron.** Atlas `hero`, `party/macron-dance-v1.png`, 1243×1265, 17 frames,
ppu 8. Required set: `heroFrameIds` (`party_sprites.dart:6-23`). Selection:
`heroSpriteFrame` (`:202-266`), `playerMovePose`
(`challenger_choreography.dart:323-363`) and `ensembleHeroHandoverFrame`
(`ensemble_sprites.dart:220-244`).

| Frame | Facing | Used for (timing) | Status |
|---|---|---|---|
| `rear_idle` | rear | Idle facing away; walk cycle; handover end | preview |
| `rear_walk_left`, `rear_walk_right` | rear | Walk cycle `[walk_L, rear_idle, walk_R, rear_idle]`, 0.25 beat each (1-beat loop; `plan/assets.md` asks for 2) | preview |
| `rear_turn` | rear ¾ | First 0.25 beat of a response; challenger "ready"; handover 0.5–0.75 | preview |
| `profile` | side (one side only) | Side-on departure; spin; turn; handover 0.25–0.5 | preview |
| `front_idle` | front | Groove; settle; scale reference | preview |
| `groove_left`, `groove_right` | front | Groove cycle `[front_idle, groove_L, anticipate, groove_R]` at 0.25 beat; also the player follow-through | preview |
| `anticipate` | front | Groove, early-tap preparation, stumble | preview |
| `left_hand`, `right_hand`, `left_foot`, `right_foot` | front | Accent: first 32% of move duration (≤0.65 beat) | preview. **Defect:** `left_hand` reuses the `groove_right` rect because the generated LH peak raised the wrong arm |
| `spin_front`, `spin_rear`, `rear_finish` | front¾ / rear¾ / rear | Flourish: 8 steps × 0.125 beat `[spin_front, profile, spin_rear, rear_finish, spin_rear, profile, spin_front, front_idle]`. This reverses the same views, so it reads as a swivel (`dance-fluidity-pass.md`) | preview |
| `arm_sweep` | front | Not requested | preview, unused |

**Gatekeeper and Bartender.** Atlases `gatekeeper`
(`ensemble/gatekeeper-v2.png`, 1214×1295) and `bartender` (`bartender-v2.png`,
1145×1374). 20 frames each, ppu 8. Required set: `challengerFrameIds`
(`challenger_choreography.dart:5-26`). Selection: `ChallengerChoreography.sample`
(`:129-310`). Draw: `garden_scene.dart:511-533`, floor x = `.5 + .2·floorYield`,
y = .53 garden / .45 bar.

| Frame | Used for |
|---|---|
| `occupied` | Before the call (t < −2 beats) |
| `turn_in` | −2…−1 beats; return during the final 0.75 beat of the response |
| `ready` | Pre-call; scale reference |
| `anticipate_left`, `anticipate_right` | ≤0.25 beat before each note (shorter when notes are dense) |
| `left_hand`, `right_hand`, `left_foot`, `right_foot` | Accent: 0–32% of the note's move window. Foot accents add root x ±0.8 logical px. `right_foot` is `mirror: true` |
| `follow_left`, `follow_right` | 32–70% |
| `settle` | 70–100% |
| `finish` → `cede` → `invite` | Final rest after the last note (handoff quarters) |
| `watch_left`, `watch_right` | Alternating every 0.5 beat while Mācron responds |
| `approve`, `recover` | 0.75 beat after a pass or fail |
| `turn_out` | Clearance: approve 0–0.5, turn_out 0.5–0.75, cede, invite |

Status: **preview** (generated 2026-10-28; anatomy and continuity cleanup open).

**Guests.** Atlases `guest0` (woman, 1536×1024), `guest1` (man, 1254×1254)
and `guest2` (host, 1536×1024). 24 frames each, ppu 8, recolored, flipped by
facing. Required set: `ensembleGuestFrameIds` (`ensemble_sprites.dart:8-33`).
Selection: `ensembleGuestFrame` (`:168-195`). Durations come from
`crowd_interest.dart:342-346,445-479`. Loops wrap; transitions clamp to their
last frame.

| Clip | Frames | Duration | Loop |
|---|---|---|---|
| seatedIdle | `seated_idle_a,b` | 8 | loop |
| notice | `notice_a,b` | 4 loop / 2 transition | both |
| seatedFollow | `seated_follow_a,b` | 2 | loop / transition |
| standUp | `stand_up_a..d` | 2 | once |
| standingIdle | `standing_idle_a,b` | 2 | loop |
| stepTouch | `step_touch_a..d` | 2 | loop |
| clap | `clap_a,b` | 2 loop / 1 in celebration | loop |
| cheer | `cheer_a,b` | 2 loop / 1 | loop |
| sitDown | `sit_down_a..d` | 2 | once |

Status: **preview**. The sheets are chair-free; chairs are drawn separately.

**Ambient life.** Atlas `life`, `party-life-v2.png`, 1246×1263, 16 frames.
`ensembleAmbientFrame` (`ensemble_sprites.dart:198-216`) runs on the
foreground seconds clock. Each kind plays a 6-step ping-pong `a,b,c,d,c,b`.
Reduced motion holds `_a`.

| Kind | Frames | Period | Note |
|---|---|---|---|
| umbrella | `umbrella_a..d` | 9.4 s | The art includes the table and drinks |
| plant | `plant_a..d` | 7.6 s | Anchor at the cord top |
| candle | `candle_a..d` | 5.8 s | No painted glow outside the flame |
| waiter | `waiter_a..d` (walk L, walk R, offer, return) | 3.2 s | Sine path x = .51 ± .055 |

Status: **preview**.

**Furniture.** Atlas `furniture`, `furniture-v2.png`, 1536×1024. Frames:
`chair_right`, `chair_left` (chosen by guest facing), `table`, and
`umbrella_closed` (required but unused). Status: **preview**.

**Backgrounds.** `garden/garden-mansion.png` and `bar/bar-interior.png`,
1024×1536 RGB, flattened. Status: **preview** ("runtime-starter-flat"). No
real layers.

### 3.2 Needed but missing: master table

| Character / area | Clip | Frames (planned) | Facing / views | Loop | Status | Source plan |
|---|---|---|---|---|---|---|
| Mācron | Grounded groove | 6–8 | front | loop | preview (4 generic) | dance-fluidity-pass §Mācron 1; party-overhaul |
| Mācron | LH limb chain: prep → peak → overshoot → return | 4–6 | front | once | missing (**dedicated LH peak missing**) | dance-fluidity-pass §2–3 |
| Mācron | RH limb chain | 4–6 | front | once | preview (peak only) | same |
| Mācron | LF limb chain | 4–6 | front | once | preview (peak only) | same |
| Mācron | RF limb chain | 4–6 | front | once | preview (peak only) | same |
| Mācron | Recovery + balanced settles | 4 + 2 | front | once | missing | dance-fluidity-pass §3 |
| Mācron | 8-view turn: F, F¾, profile, R¾, R, opposite R¾, opposite profile, opposite F¾ | 8 | all 8 (cuff swaps sides; no mirroring) | loop/once | missing (only 4 views; one profile) | dance-fluidity-pass §4 |
| Mācron | Watch | 2+ | front¾ / rear¾ | loop | missing | dance-fluidity-pass §5 |
| Mācron | Small clap with visible contact | 2–4 | front | loop | missing | same |
| Mācron | Proud finish | 1–2 | front | once | missing | same |
| Mācron | Reassuring catch-step (failed phrase) | 3–4 | front | once | missing | same; party-overhaul "recover 3–4" |
| Mācron | Ingress walk / egress walk (forward entry, yield, retreat) | 4–6 each | front¾, rear¾, side | loop | **lost** (`macron-travel-v2.png`, 4×4 = 16 poses) | opponent-depth-staging-pass §Recovery |
| Mācron | Rear walk + rear idle | 6 + 2 | rear | loop | preview (2 + 1) | party-overhaul table |
| Mācron | Side walk | 4 | side (L and R) | loop | missing | assets.md Session A |
| Mācron | Flourish set: arm sweep 4, foot slide 4, full spin 6, settle 2 | 16 | mixed | once | missing (`arm_sweep` single frame) | assets.md Session C |
| Mācron | Hand-drawn smear frames (17–33 ms) for fast sweep or spin | 1 per use | — | — | missing | dance-fluidity-pass §Smears |
| Mācron | High-five reach (`macron.highfive.reach`), seated (`macron.seated`) | ~4 + 1–2 | front / side | once | missing | storyboard E02, E05 |
| Gatekeeper | **v3 64-drawing target**: rest/groove 8, limbs 16 (4 each), forward entrance 6, backward retreat 6, side yield 6, watching 4, clap 4, challenge 4, approval 3, reassurance 3, finish/turn 4 | 64 | front, front¾, rear¾ (yield/retreat rows) | mixed | **lost** (8×7 sheet, 56 drawn, 50 safe crops) | opponent-depth-staging-pass §Opponent target, §Recovery |
| Gatekeeper | Travel sheet (start, walk 4, sidestep yield 4, retreat, watch settle) | 16 | front¾, diagonal | loop/once | preview candidate on 2610-pipe (`gatekeeper-travel-cloud-20261029.png`) | 2610-pipe pipeline README |
| Gatekeeper | 20-pose dance re-run | 20 | front | — | preview candidate on 2610-pipe | same |
| Gatekeeper | Acceptance: rope lift / open-palm usher; G.reset encouraging back-shuffle | ~4 + 2 | front | once | missing | art-direction spec table; storyboard |
| Bartender | Adapt the 64-drawing target (apron/shirt secondary motion) | 64 | as Gatekeeper | mixed | missing (20 preview) | opponent-depth-staging-pass |
| Bartender | Shaker 4, drink slide 4 (props); nod + slide drink + open passage; B.reset | 8 + ~4 | front | once | missing | assets.md Session B; storyboard B01 |
| Guests ×3 | Rear / three-quarter **watcher** art for the foreground pair (slots 0–1 face inward) | ~2–4 each | rear¾ | loop | missing | opponent-depth-staging-pass §Audience |
| Guests ×3 | Richer archetype set: chat/sip/folded-arm idle 4, glance/turn 3, nod/tap 4, step-touch 6, clap/cheer 4, settle 2 | 23 each | front¾ | mixed | preview (24-pose set covers the core) | party-overhaul table |
| Guests ×3 | Pointing, toasting, return-to-activity | — | front¾ | once | missing | play-and-transition-overhaul §Social arc |
| Guests | Smaller authored distant variants (24×40) | — | — | — | missing | party-overhaul |
| Crowd (cool crowd) | 3 reusable silhouettes × 4 dance frames; circle open/closed | 12 + 2 | front¾ | loop | missing | assets.md Session B |
| Challenger: cool crowd | Angular dancer, dramatic jacket | ≥12 (assets.md); 20-tag / 64 contract **(inferred)** | front + travel | — | missing | art-direction spec; assets.md |
| Challenger: restroom | Compact attendant with key ring; key spin | ≥12 | same | — | missing | same |
| Challenger: VIP | Elegant host with sash; bow, rope draw | ≥12 | same | — | missing | same |
| Rooms ×5 | Layers: back / middle / floor / front / emissive mask | 25 | rear camera | — | missing (garden and bar are flat) | assets.md Session B |
| Rooms ×5 | Side-on dance backdrop strip 360×320 | 5 | side | — | missing | assets.md Session B |
| Rooms ×5 | Transition threshold strip (door / rope) | 5 | — | — | missing | assets.md Session B |
| Rooms | Cool crowd, restroom, VIP backgrounds | 3 | rear | — | missing (floor planes are placeholders) | party_layout.dart:319-346 |
| Garden props | Gate open/closed, rope, hanging-plant sway 2 | ~5 | — | — | missing | assets.md Session B |
| Restroom props | Icon sign, door 3, key 3, relief sparkle 4 | 11 | — | — | missing | same |
| VIP props | Velvet rope 3, couch, reserved small seat, lounge lights | ~6 | — | — | missing | same |
| Garden/bar life | Clean plates and masks for baked lamps and foliage | — | — | — | missing | party-perspective-and-life §Local life |
| Tlatoāni | Seated idle 2, attentive nod 2, high-five reach 4, contact 2, invite 4 (64×72 cells) | 14 | front / side | mixed | missing | assets.md Session C; storyboard E01–E05 |
| Covi | Seated idle 2, greet 2 (48×64) | 4 | — | — | **blocked** (no verified reference) | art-direction spec |
| Effects | Hit spark 4, great hit 4, soft miss puff 3, flourish trail 6 (optional), respect pulse 3, gate unlock glint 4, `fx.accept.glint` | 24+ | — | once | missing | assets.md Session C; storyboard E03 |
| Ending | 180×160 closeup comps: reach → contact → settle → invite (`ending.highfive.*`), `vip.rope.open`, `vip.lounge.back`, `crowd.lounge.loop` | — | — | — | missing | storyboard Ending; assets.md |
| UI | Bitmap typeface (A–Z, digits, punctuation, ā/ó), initials cursor | — | — | — | missing (out of scope for the image pipeline **(inferred)**) | assets.md Session C |

---

## 4. Size, scale and memory constraints

**World and viewport** (`party_layout.dart:16-67`):

- The world is 180 logical units wide. `logicalHeight = screenH / (screenW/180)`.
- One centred **cover** transform maps the background: `sourceScale =
  max(180/srcW, logicalH/srcH)`.
- The background's actual pixel size is read at runtime (`garden_scene.dart:196-201`).
  However, the floor-plane fractions are calibrated to the current
  1024×1536 paintings. **A new or re-framed background requires new plane
  values.**
- The nominal art viewport is 180×320 (art-direction spec). Review viewports
  are 360×640, 390×844 and 412×915 (`opponent-depth-staging-pass.md`).

**Perspective** (`party_layout.dart:71-94`):

```
standingHeight(footY) = referenceHeight × (footY − horizonY) / (referenceFootY − horizonY)
```

All values are fractions of source image height.

| Room | horizonY | referenceFootY | referenceHeight | Calibrated? |
|---|---|---|---|---|
| garden | .255 | .40 | .094 | inspected starter |
| bar | .205 | .40 | .23 | inspected starter |
| cool-crowd | .24 | .43 | .12 | unverified placeholder |
| restroom | .23 | .42 | .13 | unverified placeholder |
| vip | .25 | .42 | .11 | unverified placeholder |

**Mācron is 0.35 × adult standing height at his own floor y**
(`garden_scene.dart:562`). This is never pose-dependent and never fitted to a
box.

Rendered sizes at 360×640 are worked out from the formula **(inferred)**.
Logical units equal screen px ÷ 2 at this size.

| Actor @ floor y | Garden | Bar |
|---|---|---|
| Mācron home (.69 garden / .62 bar) | ≈ 31.6 units (≈63 px) | ≈ 54.8 units (≈110 px) |
| Challenger (.53 / .45) | ≈ 57 units (≈114 px) | ≈ 92.5 units (≈185 px) |
| Closest guest (.61 / .48) | ≈ 74 units standing | ≈ 98 units standing |

The plan records the challenger growing about 114→139 px (garden) and
185→215 px (bar) across the staging marks.

**Planned native cells:**

| Asset | Native cell | Source |
|---|---|---|
| Mācron | 32×40 | assets.md, party-overhaul |
| Challengers | 48×64 | assets.md, party-overhaul |
| Guests | 24×40, with smaller distant variants | party-overhaul |
| Tlatoāni | 64×72 | assets.md |
| Covi | 48×64 | assets.md |
| Room layers | 180×320 + 24 px overscan | assets.md |
| Side-view strips | 360×320 | assets.md |
| Ending closeup | 180×160 | assets.md |

These are "production candidates, not acceptance criteria".

**Tension (inferred).** Because size comes from floor projection, one native
grid cannot render at an integer scale in both rooms. For example, Mācron is
about 32 units in the garden but about 55 in the bar. Current sources are
about 9× oversampled relative to world units: Mācron's `front_idle` is 296 src
px tall and draws about 32 units. `party-overhaul.md` allows "deliberate scale
variants" that must pass a pixel-consistency review. The pipeline team should
settle the native grid with the owner (2610-pipe question 6).

**Staging marks.** Candidate floor roots, source-normalised (x, y), in
`battle_staging.dart:25-46`. The file exists on `game` but is **not wired
into the scene**.

| Mark | Garden | Bar |
|---|---|---|
| Challenger demonstrating | .50, .59 | .50, .49 |
| Challenger waypoint | .62, .55 | .61, .45 |
| Challenger watching | .67, .47 | .67, .39 |
| Mācron watching | .35, .49 | .35, .43 |
| Mācron waypoint | .42, .55 | .42, .51 |
| Mācron answering | .50, .64 | .50, .61 |

Facing enum: front / left / right / back. Walk phase = `(beat×2) mod 1`
(`battle_staging.dart:163-167`). Travel art therefore needs gait frames for
diagonal approach and retreat at changing depth.

**Memory.** Decoded RGBA measured from the PNG headers:

- Every current runtime image is about 6.0 MiB (about 1.5–1.6 MP).
- Loaded set = hero + 7 ensemble atlases + 1 background ≈ **54 MiB**.
- Wardrobe variants add 12 × 6 MiB ≈ **72 MiB**. That can double with CPU+GPU
  copies (`wardrobe-rendering-stability.md`).
- The 16 MiB active+transition art hypothesis (`party-overhaul.md`) is already
  far exceeded.
- Adding Gatekeeper v3 and Mācron travel v2 at today's resolution adds about
  12 MiB more **(inferred)**.

Plans require phone profiling before expanding 64-frame assets and wardrobe
variants. **Implication for the pipeline (inferred):** deliver tightly packed
atlases at the approved native grid, not 1.5 MP contact sheets with large
gutters.

**Measured alpha quality of current sheets.** These are pipeline cleanup targets:

- Bodies sit at alpha 251–253, not 255.
- 9–12% of all pixels have alpha 1–127. This is fringe and haze; yellow/red
  edge fringes are visible on the Gatekeeper and life sheets.
- The woman and host sheets keep a gradient in RGB under alpha 0.
- Furniture has a glow halo.

Target: binary alpha, no hidden RGB, no halos. Keep ≥2 px transparent crop
margins and well-separated frames. The man's sheet needed a repack after
frames touched.

---

## 5. Canon constraints for generation

From `openspec/specs/art-direction/spec.md`, the upstream canon linked in
`plan/assets.md`, and the provenance prompts:

- **Mācron:** a toy-sized ivory robot with a compact rounded shell, a dark
  teal face screen with cyan eyes, **exactly one** small cyan antenna orb, two
  arms and two short legs. A subtle modular cuff sits on the **anatomical right**
  arm. No ears, tail, animal parts or weapons. Always much smaller than
  Tlatoāni, and his scale never grows, including in the ending closeup. The
  cuff changes sides correctly through turns, so **never mirror Mācron
  frames**. The antenna may lag the head by one drawing. The face screen and
  head volume must not slide.
- **Tlatoāni:** a friendly warm-pink axolotl with coral external gills, **one
  tail**, cream clothing, teal accents and **no facial hair**. Costume changes
  keep the silhouette. In a silhouette check, the gills and tail must read with
  face details hidden.
- **Covi:** identity is not established. Do **not** invent species or
  appearance. Only a reserved seat or a non-identifying silhouette is allowed
  until a verified reference exists. Crowd characters must never resemble an
  unverified Covi.
- **Challengers** are original provisional designs, not canon characters.
  - Gatekeeper: broad, smiling, cream straw hat with a teal band, neat black
    moustache, purple guayabera with teal embroidered bands, cream trousers,
    teal shoes, hands empty.
  - Bartender: brown skin, curly dark hair in a high bun, gold hoops, cream
    rolled-sleeve shirt, teal waistcoat, plum apron and trousers, gold shoes.
    The shaker is set aside for dance poses.
- **Guests** are three original adults (see `ensemble/provenance.json`). They
  must keep skin, face, hair and accessories stable across poses and outfit
  variants.
- **Left/right** always means the character's own anatomy, so a front-facing
  character's LEFT is on the viewer's right. Hand and foot identity must be
  unambiguous at game size.
- **Tone:** dance, not combat. No punches, kicks at opponents, weapons,
  damage, humiliation or aggressive posing. Denial and reset gestures are
  playful. Restroom humour is a pictogram and relief only.
- **Style:** 80s/16-bit pixel art with crisp square clusters, dark chromatic
  outlines and restrained shading. No painterly blur, Gaussian smears, baked
  glows, shadows, floors, text, labels or UI. Authored views replace squashing
  or rotating flat sprites. No strobing: fewer than 3 flashes per second.
- **Process:** a concept sheet is not a runtime atlas until frame bounds,
  pivots, identity and continuity have been measured and reviewed (spec
  §Asset acceptance). `references/character-scale.png` is reference-only and
  its upstream license is unrecorded. Keep it out of runtime bundles.

---

## 6. Prioritised production order

Ordering follows `opponent-depth-staging-pass.md` (recovery notes and
upcoming-pipeline steps), `dance-fluidity-pass.md` (pilot first) and
`party-overhaul.md` (garden proof before other rooms).

1. **Gatekeeper v3 → `assets/art/ensemble/gatekeeper-v3.png`.** Target the
   full 64-drawing set (§3.2), including the separate yield row and rear views
   that the lost run lacked. Re-measure rects and anchors from the actual
   output, and exclude any overlapping pairs until they are repacked. This is a
   separate job from step 2. Retain prompts, inputs, hashes and observed
   dimensions. The 2610-pipe travel and dance candidates are usable motion
   briefs or identity references.
2. **Mācron travel v2 → `assets/art/party/macron-travel-v2.png`.** 16 poses:
   forward entry, watcher/clap, finish, yield, retreat. It needs its own
   measured travel reference frame, keeps the 0.35 stature, and needs a review
   of the cuff and hand contact. `macron-dance-v1.png` stays the action source.

   *These two unblock restoring the staging integration* (scene wiring of
   `battle_staging.dart`, choreography limb chains, travel atlases). That is
   the playtest the owner is waiting on.
3. **Mācron pilot inventory:**
   - First, the dedicated **left-hand peak**, which fixes a live identity defect.
   - Then the four limb chains with returns, recovery and settles.
   - Then the **8-view turn** (replaces the reversed swivel), then the grounded
     groove 6–8.
4. **Gatekeeper secondary items:** acceptance (rope lift or usher) and reset
   gestures. Then the native-size review of the garden pilot at 360×640,
   390×844 and 412×915, and on a phone.
5. **Bartender:** adapt the 64-drawing target, plus shaker and drink-slide props.
6. **Guests:** rear/three-quarter watcher art for the foreground pair, then a
   native-grid and continuity cleanup of the 72 existing poses. Any new guest
   sheet must honour §2 and requires updating the palette test fixtures.
7. **Garden and bar layered backgrounds** (5 layers + emissive mask),
   foliage/light clean plates, garden gate/rope props, and the side strips if
   `cam.side` is adopted.
8. **Campaign rooms in order:** cool crowd (background, challenger, crowd
   silhouettes, circle), then restroom (background, attendant, door and key),
   then VIP (background, host, rope, lounge). Recalibrate each floor plane
   from the real painting.
9. **Effects, Tlatoāni and the ending closeup.** Then **Covi, only after a
   verified reference.**

---

## 7. Deliverable checklist per promoted atlas (derived from the above)

- A PNG whose size exactly equals `imageWidth/imageHeight`. Top-left pixel
  alpha is 0, and more than 35% of pixels are fully transparent.
- Integer `rect`s inside the image. Anchors are rect-relative at the floor
  root (cord top for hanging props). One `pixelsPerUnit` per atlas, and the
  whole sheet at one scale.
- Every frame ID required by the consuming Dart list, using the exact names in
  §3.1. Unused extras are tolerated.
- A neutral upright reference frame named as the code expects (`front_idle`,
  `ready`, `standing_idle_a`, …).
- `mirror: true` only for anatomy correction on symmetric costumes. Never on
  Mācron.
- Guest atlases: cloth inside the gates, everything else outside them, and
  hard alpha.
- A provenance record (prompt, inputs and hashes, generator, date, cleanup
  steps, limitations), plus the planned fields from §1.6 as forward-compatible
  extra keys.
- Human review at native size and in-scene before runtime registration.
