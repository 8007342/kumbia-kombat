# Grounded people in a living party

2026-10-28. This contract addresses the mismatch between independently scaled
sprites and the painted rooms. It also defines reusable seated/standing guests,
furniture and local environmental life. The first implementation is
`lib/gameplay/party_layout.dart`, its tests, and the clothing palette shader.
Production artwork, scene integration and phone review are separate acceptance
steps. The current backgrounds remain flattened starters.

## Sources and what transfers

- [Physically Based Rendering: Projective Camera Models](https://www.pbr-book.org/4ed/Cameras_and_Film/Projective_Camera_Models)
  describes perspective foreshortening and the projection through camera depth.
  This supports one consistent size/depth relationship. Our painted 2.5D room
  does not provide a known focal length, camera tilt or exact reconstructed floor.
- [Flame: Camera and World](https://docs.flame-engine.org/latest/flame/camera.html)
  separates world/viewfinder transformations from viewport HUD components. Here
  the world is 180 logical units wide with aspect-adaptive height; the existing
  Flutter cue/input overlay remains outside world transforms.
- Ranitas public source inspected at commit
  [`03f3901ba0022746ea1920564bd2df3b90d7e98f`](https://github.com/8007342/ranitas/tree/03f3901ba0022746ea1920564bd2df3b90d7e98f):
  [visual guide](https://github.com/8007342/ranitas/blob/03f3901ba0022746ea1920564bd2df3b90d7e98f/art/STYLEGUIDE.md),
  [animation guide](https://github.com/8007342/ranitas/blob/03f3901ba0022746ea1920564bd2df3b90d7e98f/art/ANIMATION_STYLEGUIDE.md),
  [current Quiet Awakening guidance](https://github.com/8007342/ranitas/blob/03f3901ba0022746ea1920564bd2df3b90d7e98f/docs/quiet-awakening.md),
  and [scene-layer implementation](https://github.com/8007342/ranitas/blob/03f3901ba0022746ea1920564bd2df3b90d7e98f/lib/game/scene_layers.dart).
  The useful ideas are shared actor/support scaling, ground-anchored shadows,
  stationary painted stones and shores, independent leaf motion, source-aligned
  light masks, bounded side framing and deterministic local phases. Its current
  guidance supersedes older bright leaf flips and coarse rotation snapping.
  Kumbia needs its own portrait composition, floor and musical story; it does not
  inherit Ranitas's landscape dimensions, frog anatomy or three-minute reveal.
  No Ranitas code or image assets were copied into this project.
- [Flutter: Writing and using fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)
  documents shader assets, `FragmentProgram`, float/sampler uniforms, local
  `FlutterFragCoord`, premultiplied output and program/shader reuse. The clothing
  helper uses a Canvas shader on an explicit destination rectangle; it does not
  use an Impeller-only image filter or recolor the entire scene.

## Inspected landmarks versus chosen calibration

Both current room rasters are 1024×1536. Coordinates below are approximate visual
readings of those source images, before any display crop. They are not physical
measurements of a real room or a solved camera calibration.

| Room | Visible source landmarks | Chosen single-plane approximation |
|---|---|---|
| Garden | Rear entrance/step around y=475–500; gate/patio contacts around y=525–550. Strong path edges suggest a convergence near x=512, y≈392, but generated tile lines are not perfectly consistent. | Horizon fraction .255; reference feet .40; standing human height .094 of source height at that reference. The 144 px human reference is an artistic choice, not an observed person in the empty image. |
| Bar | Countertop around y=340; stool seats around y=380–395; stool bases around y=485–495. Floor grid is stylized and not a unique calibration solution. | Horizon fraction .205; reference feet .40; reference standing human height .23. This yields about 208 px for an adult at foot y=.32, compared with about 103 px for the painted high stool. This relative stature is chosen, not proof of camera geometry. |
| Crowd, restroom, VIP | No reviewed production backgrounds yet. | Authored plane placeholders are explicitly `unverifiedStoryboard`; remeasure when those source images exist. |

The bar's apparent people are larger than the garden's because its furniture
establishes a much nearer interior. Do not “fix” this with independent arbitrary
guest scale multipliers. If the resulting composition is too crowded, move seats
on the shared floor or revise the background/camera contract. Validate actor and
furniture proportions together before accepting new art. Future art must publish
its actual source dimensions and plane parameters; do not silently apply this
1024×1536 starter calibration to a differently framed image.

## One floor, one transform

For a source-normalized ground y, the presentation rule is:

`height = referenceHeight × (footY − horizonY) / (referenceFootY − horizonY)`

This is a deliberate flat-floor perspective approximation. Apply an explicit
physical stature ratio for a shorter character or tiny Mācron; do not make that
ratio depend on viewport size, performance or pose. A standing reference frame
sets one scale for every pose in the actor's sheet. A seated person's shorter
silhouette must remain shorter at that scale: never resize each frame to the
same displayed height.

`PartyViewport` computes one centered cover fit. Its `backgroundRect`,
`project(sourcePoint)` and `sourceHeightToLogical(height)` must all be used
together. The world width is 180 units; `logicalHeight = screenHeight / (screenWidth
/ 180)`. Scale that world canvas once by `pixelsPerUnit`. If overscan is used,
supply it once in logical units and use the resulting transform for every layer.
Never fit the background with one crop while placing feet by unrelated screen
percentages. Keep HUD destinations and touch regions in their existing overlay.

Sort actors and floor props by their fixed ground y. Shadows stay on the ground
when a person nods, claps or jumps. For a table grouping, draw rear furniture/guests,
table top and front guests with explicit sublayers; a simple center-point sort
cannot describe every overlap. Umbrella poles, tables and chair legs do not sway
with foliage. Pan all attached world layers consistently. If a doorway separates
floor heights, author a second support plane rather than stretch a walking sprite.

## Twelve reusable guests and persistent furniture

Garden and bar each have twelve authored slots, three archetypes × four outfit
palettes, with unique `interestIndex` values 0–11. All begin seated, occupied with
conversation or a drink. Depth rows and silhouette overlap establish a population
without twelve equally prominent dance performances. The closest reaction is the
focus; neighboring interest develops through the existing crowd model. Merely
drawing an occupant never generates respect.

Each guest has a persistent chair prop at the same `floor` anchor. The chair does
not disappear when the person rises or dances. Root-generated chair-free person
frames retain their original full-cell floor pivot and scale; removing a chair
must not crop or realign the actor. Render the separate chair behind the person.
The reviewed `furniture-v2.png` high-back chair is about 476 source px tall and
317 px wide, with its seat about 219 px above the floor. Its contract therefore
uses height .80 adult standing heights and width .53. This puts the seat at
about .368 adult heights, close to the new guest sheets' seated hip height
(about 100 px over the floor against a 260 px standing reference). The metadata
support level is .37. This calibrates the proportions of a stylized high-back
chair; it does not alter the room's depth scale or shrink seated people.
The support point is art-review metadata, not a replacement runtime pivot for
the actor's floor-anchored sheet. Combined seat contact still needs browser review.

Tables, umbrellas, drinks and candles can reuse the same floor scale. Tabletop
items additionally need a measured support anchor on their table. A drink follows
the hand only during an authored pickup/sip; otherwise it rests on its table.
Waiters use predetermined source-ground routes behind the active dance area,
carrying a stable tray and stopping at a table. Do not let a waiter cross the
cue origin or automatically join every approval animation.

Clip requirements: seated idle/chat/sip, notice, lean forward, rise, standing idle,
left/right steps, clap, cheer, turn back, sit, and return to conversation. Each
clip shares the standing sheet's pixels-per-unit and original ground reference.
Seated frames are not scaled-down standing frames. The three people retain their
own body shape; palette variants should not alter skin, face, hair or accessories.

## Clothing palette contract

`OutfitPalette.load()` caches the compiled program and returns an owned shader
instance. `paint(image:, source:, destination:, palette:)` configures its explicit
atlas crop and target rectangle. Draw with `canvas.drawRect(destination, paint)`;
`drawImageRect` does not apply a Paint shader as a recoloring operation. Dispose
the helper with the owning scene. Four `OutfitColor` values are teal, blue, coral
and gold. There is no CPU image rewriting or atlas duplication for palette swaps.

The original cool ramp (`#4B245E`, `#874197`, `#C878D6`) barely matched the actual
generated ensemble: only 1 woman, 0 man and 7 host pixels with alpha≥128.
Reviewed source clothing includes warm plum `(146,31,87)`, wine `(154,11,66)` and
bright pink `(254,83,107)`. The shader retains its original cool gate and adds
two bounded gates: saturated plum requires red≥100, blue≥.32×red, green≤.55×blue
and blue−green≥12; bright pink requires red≥180 and permits green≤.86×blue.
Both also require red≥.70×blue. Thresholds in this paragraph use 0–255 channels.
Separating bright pink from darker saturated plum avoids recoloring the woman's
less saturated, plum-tinted hair. Dark warm shadows remain unchanged.

Read-only classification of all alpha≥128 source pixels selects 162,930/508,321
woman pixels (32.05%), 163,098/498,203 man pixels (32.74%), and 131,851/555,166
host pixels (23.75%). These percentages describe selection over the whole actor,
not a semantic clothing segmentation score. Ten manually inspected first-pose
hair/skin regions (2,383 opaque pixels) remain untouched in the compiled shader
test; sampled clothing regions visibly recolor. The man was re-reviewed after its
source was replaced with a 1254×1254 sheet; woman/host remain 1536×1024. The full-sheet review is still
needed for every future replacement. This remains a reviewed semantic color-key
convention, not automatic clothing recognition. A future asset with overlapping
skin/hair hues needs an explicit separate mask rather than a global hue filter.

The shader retains alpha, source HSV value and saturation while changing the
reserved hue. This preserves shade ordering; it does not claim identical measured
perceptual luminance across hues. Non-matching pixels pass through. Sampling uses
explicit texel centers clamped inside the selected frame, so adjacent cells cannot
bleed in. Program-load failure is explicit: ordinary drawing shows the original
source plum and must be reported as that fallback, not labeled a working variant.

## Local life and attention budget

| Layer | Behavior | Ownership and constraint |
|---|---|---|
| Hanging Tillandsias / loose leaves | Small independent bending about attachment points, lagging slow local wind | Foreground-only ambient clock; static pots/branches remain fixed |
| Candle / lantern cores | Small continuous intensity variation inside source-aligned masks | Local light gain .88–1.00; no on/off flashing or broad exposure pulses |
| Glass and wet floor | Restrained reflection changes linked to the nearby light | Never animate an entire floor or mirror as an unrelated shiny patch |
| Occupied groups | Slow sips, short conversation gestures, occasional posture changes | Independently phased; most guests stay low amplitude while one reacts |
| Waiter | One bounded service route and a table stop | Background route only; postpone a pass while a major focal event owns that area |
| Approval / exit | A few claps, then staggered return to chairs and activities | Musical story timeline; stateful and distinct from ambient wind/light |

`partyAmbientAt(foregroundSeconds, instance:, reducedMotion:)` is a pure sampler.
Its wind remains within ±.026 radians, and light changes continuously. The caller
freezes this foreground clock while paused/backgrounded; wall time away from the
game must not jump phases. Beat-driven gestures continue to use transport beats.
Reduced motion returns zero wind and constant light. Baked light and foliage
pixels need separate source-aligned masks/clean plates before being moved: sliding
a duplicated crop over the original creates ghosts, not living foliage.

Keep all large props, low branches and moving service routes clear of cue paths
and the lower thumb surface. The entire envelope of an animation counts, not only
its resting pose. A busy world can have many quiet loops and one readable reaction;
it does not require simultaneous large gestures or whole-screen flashes.

## Acceptance and evidence

Six layout tests cover shared crop/projection on 360×640, 390×844 and 412×915
surfaces; inverse mapping; monotonic depth/stature; twelve unique seated slots;
persistent chair anchors; continuous bounded ambient motion; and invalid inputs.
The shader raster test renders a synthetic atlas through the actual compiled
fragment program: four outfit colors, unchanged skin/wood, preserved partial
alpha/shade values, nearest cell boundaries and no adjacent-cell bleed. It also
checks reuse across multiple differently configured draws in the same frame.

Before acceptance, compare screen captures over a temporary floor/horizon guide:
feet and chair bases meet the same tile, rising does not grow a person, nearby
equal-stature people share scale, and Mācron remains consistently toy-sized.
Inspect all new sheets at native size and in both rooms. Review occlusion/cropping
on narrow/tall phones; moving an isolated sprite to dodge clipping breaks its
relationship to the scenery, so adjust the authored group or whole-camera framing.

Measure phone frame time, shader compilation/load time, texture memory and audio
underruns with all twelve guests, chairs and local loops visible. Structural tests
do not establish a measured device budget, artistic coherence, a recovered 3D
camera, or completed five-room art. Those reviews remain open.
