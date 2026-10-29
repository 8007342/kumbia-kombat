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

## Gatekeeper travel-sheet cloud run

- Candidate: `candidates/gatekeeper-travel-cloud-20261029.png`
- Run record: `candidates/gatekeeper-travel-cloud-20261029.run.json`
- Result: 1215×1295 RGBA; real transparent alpha verified (alpha 0–255,
  866,266 fully transparent pixels).
- Visual review: the source identity and four-by-four pose order are readable,
  including forward gait, yielding poses and a watch settle. Cell bounds and
  baselines are visibly not yet certified; the walk poses do not establish a
  perfectly alternating cycle, and colored edge fringes need cleanup. Treat it
  as a motion-brief candidate, not runtime gait.
- The original generated PNG is preserved unchanged. The scene does not yet use
  this sheet, and the route still needs art review before integration.
