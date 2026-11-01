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
VIRTUAL_ENV=~/.cache/kumbia-bpy uv pip install bpy==5.2.3 pillow numpy
```

## Render

```bash
~/.cache/kumbia-bpy/bin/python tool/art/rig/standin.py --character gatekeeper --out art_runs/inputs/gatekeeper-v3
~/.cache/kumbia-bpy/bin/python tool/art/rig/standin.py --character macron --out art_runs/inputs/macron-pilot
# --camera side-on   for side-on rooms (level 4); --only a.b,c.d   for quick tests
```

Per pose, at the 768×960 generation canvas: `.pose.png` (OpenPose COCO-18,
humans only), `.depth.png` (near = bright), `.regions.png` (flat region
colours, no antialiasing, checked against the declared set), `.lineart.png`
(region edges). `rig.json` records the 2D joints, the constant `groundY` and
the support-foot `pivotX`; `contact.png` and `<clip>.gif` are review previews.
Cycles CPU renders one centre sample per pixel with dithering off, so region
colours are exact. About 0.5 s per pose.

## Authoring poses

`poses.py` holds the vocabulary. Each segment angle is `(abd, flex)`, a swing
away from hanging down (outward, toward the viewer). The renderer plants the
named support foot on the ground line after forward kinematics, so a weight
shift lowers the body rather than sliding it. `mirror()` swaps left and right
in the rig, which is safe for Mācron because his cuff stays on the anatomical
right arm in the render. Never mirror his images.

Known stand-in limits: front-camera walks foreshorten (hence a 15° diagonal
for the entry and retreat walks); Mācron's raised-hand peaks pass behind his
large head and need per-character tuning at review; faces and hands are simple
volumes.
