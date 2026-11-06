# Party raster animation preview

These sources replace the procedural rectangle robot and crowd in both playable
rooms. Generated with built-in imagegen on 2026-10-28, inspected as individual
poses and assigned explicit measured frame rectangles in `manifest.json`.
Full generation prompts and cleanup intent are in `provenance.json`.

- `macron-dance-v1.png`: transparent 1243×1265 source, 16 robot poses. Rear walk,
  front groove, anticipation, limb accents and four spin views are selected by
  the music-clock animator. The original concept sheet supplied identity only.
- `macron-dance-v3.png`: the v2 sheet pixel for pixel, plus eight `held_*` frames below it, turning under a held hand. Puppeted from his own frames by `art_runs/duet-20261106/pair/scripts/puppet.py`. Each records `hold`, the hand, in the same pixels as `anchor`.
- `guests-v1.png`: transparent 1536×1024 source, three distinct adult party guests,
  six poses each: occupied, notice/point, step left, step right, clap, cheer.
  An imagegen edit removed a translucent gradient from the original generation.
- `manifest.json`: manually reviewed source rectangles with two-pixel margins,
  explicit foot anchors and source-pixels-per-logical-unit scale. Bounds were
  measured from connected alpha silhouettes and checked against the actual art;
  there is no automatic equal-grid slicing.

The generated robot duplicated its raised-right-arm pose. The `left_hand` tag
therefore uses the drawing that visibly raises the anatomical left arm, also
used for `groove_right`; `arm_sweep` retains the unused raised-arm drawing.
This avoids displaying the same wrong arm for both required hand actions.

These are integrated **preview sprites**, not final native-grid production art.
Rear-view cuff continuity, exact pixel-grid cleanup, more in-between drawings,
complete character turns and the challengers' animated sheets remain outstanding.
We preserve original alpha; low-alpha antialias fringes remain in a few source
pixels. Runtime uses nearest-neighbor sampling and explicit ground anchors.

The two decoded atlases alone occupy approximately 12.3 MiB RGBA; room paintings
and challenger images are additional. The earlier 16 MiB total-art hypothesis
has not been achieved. Mobile texture/memory and sustained frame-time acceptance
remain open and must not be inferred from a successful desktop build.
