# Blender stand-in rig

Hand-keyed stand-ins that render the control images for the generative asset
pipeline (`plan/asset-pipeline-requirements.md`, contract `1935-k2ib/v0`).
They are not final art: they fix pose, support foot, limb identity, scale and
ground line so generated frames cannot drift.

## Setup (once per forge)

Blender is used as a Python module. The `bpy` wheel needs Python 3.13, and the
forge's TLS proxy requires the system certificate store:

```bash
export UV_NATIVE_TLS=1
uv python install 3.13
uv venv --python 3.13 ~/.cache/kumbia-bpy
VIRTUAL_ENV=~/.cache/kumbia-bpy uv pip install bpy==5.2.3 pillow numpy jsonschema
```

## What a render is made of

A character is data, not code. `--character <id>` loads `tool/art/characters/<id>.json`:

- `body.preset` and `body.overrides`: proportions and camera, from `bodies.json`.
- `garments[]`: each names a `shape` (`garments.py`, listed in `library.json`) and a
  `region`. Regions are dynamic per character, and each renders one flat mask colour.
- `props[]`: a `kind` held in one hand, optionally limited to some clips.
- `motion.set`: a shared pose table (`poses.py`, `MOTION_SETS`) with metadata in
  `tool/art/motion/<set>.json`. `motion.overrides` changes `pose` params or `intent`
  text per pose. Intent templates use `{he}`, `{him}` and `{his}`, filled from `pronouns`.

A new humanoid needs no code. A new garment kind needs one function in `garments.py`
and one word in `library.json`.

## Render

```bash
~/.cache/kumbia-bpy/bin/python tool/art/rig/standin.py --character gatekeeper --out art_runs/inputs/gatekeeper-v3
~/.cache/kumbia-bpy/bin/python tool/art/rig/standin.py --character macron --out art_runs/inputs/macron-pilot
# --camera side-on   for side-on rooms (level 4); --only a.b,c.d   for quick tests
```

Per pose, at the 768×960 generation canvas: `.pose.png` (OpenPose COCO-18,
humans only; wrists hidden behind the torso are omitted), `.depth.png`
(near = bright), `.regions.png` (flat region colours, no antialiasing, checked
against the declared set), `.lineart.png` (region edges). `rig.json` records
the 2D joints, the constant `groundY` and the support-foot `pivotX`, plus
(additive fields) `clip`, `pin`, `params` (the pose values), `openpose`
(18 × [x, y, visible]), `headWidthPx`, `bbox` and `regionPixels`.
`poses.intent.json` maps each pose id to its clip, phase, support foot and a
plain-English description of the body action for generation prompts.
`contact.png` and `<clip>.gif` are review previews. Cycles CPU renders one
centre sample per pixel with dithering off, so region colours are exact.
About 0.4 s per pose.

## Check

```bash
python3 tool/art/rig/check_poses.py art_runs/inputs/gatekeeper-v3   # exit 1 on any failure
```

Stdlib only; reads `rig.json`. It fails on: arm/leg segments crossing in the
2D OpenPose skeleton; a wrist closer than 1.2 head-widths to the head centre
(whitelisted: `finish_turn.finish_a/b` brim touch, `approval.nod` palm to
chest); a weighted ankle moving between consecutive drawings of a clip
(locomotion clips only check a foot pinned in both drawings; the Mācron
`turn` views are exempt); a free ankle below or a pinned ankle off the ground
line; 2D shoulder width changing more than 25% within a clip; body yaw over
35° outside turn clips; a frame inside the family's `margin.minClear`; fewer
than 600 shoe pixels; and consecutive drawings where no joint moves 16 px
(about 10° on a limb or 5° on the torso at ~110 px sprite height). Run it
after every render, on Mācron too (render him to a scratch dir).

## Authoring poses

`poses.py` holds the vocabulary and the docstring lists every field. Segment
angles are `(abd, flex)`, a swing away from hanging down (outward, toward the
viewer). Arms are in the torso frame, legs in the body frame.

- **Planting.** The pinned ankle (the support foot, or the midpoint for
  `"both"`, or `pin="l"/"r"/"mid"`) is moved to its rest-pose home in x, y and
  z, so a weight shift moves the body, never the support foot. In a
  `"both"` stance the rig IKs both ankles onto their homes (`both_home=True`);
  walk contacts set `both_home=False`.
- **Hip push.** `pelvis_x` / `pelvis_y` swing the weighted legs about their
  hips so the pelvis moves over the planted foot. They are metres for
  Gatekeeper's legs and scale with leg length for other characters.
- **Contrapposto.** `pelvis_roll` (positive raises the left hip) with
  `side_bend` of the same sign tilts the hips and shoulders in opposite
  directions.
- **Readable knees.** `knee_out` (default 35°, per-leg `l_/r_knee_out`)
  rotates each knee about its hip-ankle line, so a bend toward the camera
  opens outward and reads from the front. Body `yaw` up to ±35 also helps.
- **Feet.** `l_foot` / `r_foot` pitch the shoe (positive toe down, negative
  toe up for a heel dig). Left as `None`, a free foot near the floor rests on
  its ball.
- **Signs.** Positive `lean` tips the torso forward and positive `head_nod`
  tips the chin down (negative = chest proud / chin up).
- **Readability.** At about 110 px tall, a change under about 10° on a limb or
  5° on the torso disappears. Never twin left and right inside a drawing,
  except on the clap. `mirror()` and `mirror_clip()` swap sides in the rig,
  which is safe for Mācron because his cuff stays on the anatomical right arm
  in the render. Never mirror his images.
- **Constraints.** Claps stay at chest height, symmetric, never overhead or
  leaning. Call clips have no travelling steps. The hat stays on the head.

Gatekeeper proportions follow `assets/art/ensemble/gatekeeper-v2.png`: broad
chest, round belly, thick upper arms and thighs, short neck, head about 1/5.5
of total height, hat brim wider than the shoulders. The region mask is the
img2img init, so the silhouette carries into the generated frames.

Known stand-in limits: front-camera walks foreshorten (hence the diagonal yaw
on entrance, retreat and yield); Mācron's raised-hand peaks pass behind his
large head and need per-character tuning at review; faces and hands are
simple volumes; hands behind the back are mostly hidden by the torso.

## Secondary motion

`"secondaryMotion": "lag-1"` on a supported garment (`library.json`) makes its hem
trail the hips by one drawing. The previous drawing wraps in a looping clip; a
one-shot's first drawing has none. Any other value or shape is refused by name.
