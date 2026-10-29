# Sprite generation pipeline candidates

Images in `candidates/` are generated source material for pipeline experiments.
They are not runtime assets and are not registered by Flutter. Promote a
candidate only after frame-boundary cleanup, palette/grid processing, manifest
generation, gameplay review, and art approval.

## First cloud run: Gatekeeper dance poses

- Candidate: `candidates/gatekeeper-dance-cloud-20261029.png`
- Run record: `candidates/gatekeeper-dance-cloud-20261029.run.json`
- Result: 1215×1295 RGBA; real transparent alpha verified (alpha 0–255,
  759,063 fully transparent pixels; top-left pixel alpha 0).
- Visual review: the Gatekeeper's moustache, hat, blouse, trousers, and shoes
  remain recognizable; the sheet contains the requested twenty pose concepts.
  Pose order is readable, but cells are not proven uniform, registration and
  per-pose bounds are not measured, and bright edge fringes need cleanup. Keep
  this as a source candidate, not a runtime atlas.
- The original generated PNG is preserved unchanged. No image cleanup or
  manifest integration has been performed yet.
