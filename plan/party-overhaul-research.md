# Party animation research and audit — 2026-10-28

This records inspected evidence and proposed applications, not completed work.

## Local baseline

Reviewed `origin/work/1828-anim` (`662ab84`), merged into `game` at
`6c32f3c`, and today's reachable history after fetching origin. That work
changes six code/test files; it adds no raster assets or planning documents.
It adds procedural character/crowd drawing, combo feedback and timing markers.
The older foundation already contains art guidelines and animation plans.

`GardenSceneGame._drawSpectators` selects shared states from `tier >= 1`,
`combo >= 3`, `tier >= 3`, `combo >= 6` and cleared status. Five positioned
guests per room have colors/archetypes but no individual attention memory.
Their bodies use rectangles and sine offsets. `_drawMacron` switches limb
positions and compresses the body horizontally for a spin. Challenger art
is a single image with bounce; its call demonstration adds an aura.
The scene loads a flattened background and uses screen-relative geometry.
These are useful placeholders, not completed multi-frame animation/parallax.

Visually inspected `macron-dance-concepts.png` and `garden-mansion.png`.
The concept has appealing canon cues but inconsistent pose bounds and pixel
density; it is correctly labeled non-runtime. The background has elaborate
high-resolution detail that competes with a tiny native sprite vocabulary.
Final art needs deliberate reconstruction on one logical grid, not automatic
even slicing or simply shrinking a painting. No physical-device visual review
was performed in this planning session.

## Sibling lessons actually inspected

Sibling checkouts are absent from this environment; read their public GitHub
`main` documents on 2026-10-28. These observations concern those documents,
not an audit of their latest unmerged branches or a claim their plans shipped.

| Project and source | Transfer to Kumbia Kombat |
| --- | --- |
| [Ranitas animation guide](https://github.com/8007342/ranitas/blob/main/art/ANIMATION_STYLEGUIDE.md) | Anchor shadows to the ground plane; separate body elevation from contact position; give small expressions distinct states. Its frog-specific equations and dimensions do not become robot rules. |
| [Cannonball motion/art research](https://github.com/8007342/cannonball/blob/main/docs/research/motion-art.md) | Keep coherent pivots and frame bounds, use hysteresis, separate animation cadence from display refresh, inspect moving footage and profile phones. Its diffused filtering direction does not override our nearest-neighbor pixel art. |
| [Cannonball reference register](https://github.com/8007342/cannonball/blob/main/docs/research/reference-register.md) | Record primary sources, interpretation and actual validation separately; numerical settings remain hypotheses. |
| [Demon Attack atlas contract](https://github.com/8007342/demon_attack/blob/main/plan/sprite-atlas.md) | Use documented cells and genuinely different articulated poses, independent clips and explicit cadences; keep instructional paintings separate from gameplay sprites. |

## Primary external sources

1. [Mariel Cartwright, Lab Zero: Fluid and Powerful Animation within Frame Restrictions, GDC 2014](https://media.gdcvault.com/GDC2014/Presentations/Cartwright_Muriel_Animation_Bootcamp_Fluid.pdf).
   Inspected slide text: silhouette, anticipation, favoring keys, follow-through,
   smears, overshoot, variable holds and rough→implement→finish→implement.
   Apply these to weight transfer, arm accents, turns and settling. This is
   general 2D animation evidence, not a source for our precise frame counts.
   Combat hitstop is not a reason to freeze our music or judgment clock.
2. [Thomas Vasseur, Motion Twin: Dead Cells art pipeline, 2018](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-).
   The artist describes using a simple 3D model/rig to produce 2D animation
   efficiently. Our recommendation is authored 2D first for the small cast;
   a 3D-to-pixel bake is an optional production experiment if revisions become
   expensive. This source does not establish that more frames alone improve dance.
3. [Michael Booth, Valve: The AI Systems of Left 4 Dead, 2009](https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf).
   Its adaptive pacing discussion distinguishes intensity pacing from difficulty
   and uses build/sustain/relax periods. Our inference is a presentation director
   that paces guest reactions while charts and judgment stay fixed. Zombie
   population algorithms and their numerical thresholds are not crowd psychology.
4. [Aseprite sprite sheets](https://www.aseprite.org/docs/sprite-sheet/),
   [tags](https://www.aseprite.org/docs/tags/) and
   [source/export workflow](https://www.aseprite.org/docs/exporting).
   Use editable sources and tagged exports with explicit frame metadata.
5. [Flame image/animation documentation](https://docs.flame-engine.org/latest/flame/rendering/images.html).
   Supports sprite/animation loading and Aseprite data. Verify APIs against the
   project's resolved Flame version before implementation; documentation URLs
   may redirect between versions. A generic elapsed-time ticker alone does not
   satisfy our music-transport timing and pause reconstruction contract.

Symphony of the Night is the owner's motion/style inspiration. We have not
verified its internal animation implementation and make no technical attribution
to it. Study readable silhouettes, rich keyed motion and secondary settling;
retain Kumbia's warm original party, characters and palette.

## Evidence still needed

Art proof at 180×320 on a real phone; short motion comparisons with the same
chart; whether players notice the first guest's glance; taps-only crowd payoff;
input/audio latency under full crowd; pause/retry determinism; sustained browser
frame times and decoded texture memory. Research does not substitute for these.
