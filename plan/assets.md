# Assets and animation production plan

Status: specifications complete; SVG input icons created; eight-pose raster concept starter generated and visually inspected. Garden/bar backgrounds and single challenger poses are generated and integrated as starters. Final sprite cleanup, remaining three room backgrounds, full animations and genuine parallax remain scheduled work. Do not mark those complete from concept art.

## References and provenance
- Canon: https://raw.githubusercontent.com/8007342/macron.dev/refs/heads/main/assets/Tlato%C4%81ni%20%2B%20M%C4%81cron%20cannon%20guidelines.md (read 2026-10-18).
- Curated directory: https://github.com/8007342/macron.dev/tree/main/assets (enumerated using GitHub contents API).
- Inspected reference: `Chess Tlatoāni vs Mācron.png`, retained locally at `assets/art/references/character-scale.png` for reference only. Source: https://github.com/8007342/macron.dev/blob/main/assets/Chess%20Tlato%C4%81ni%20vs%20M%C4%81cron.png . It establishes relative scale, warm material language, robot face and axolotl silhouette. Upstream license/redistribution permission must be recorded before shipping the reference; exclude reference files from runtime bundles.
- New raster concepts use built-in imagegen. Prompts and resulting status live in `assets/art/README.md`. New SVG controls are project-authored path silhouettes.

## Session A: usable vertical slice
- [ ] Inspect generated Mācron concept; select consistent rear/front/side designs and rectify to native pixel grid.
- [ ] Produce clean 32×40 Mācron cells: rear walk 4, rear idle 2, front idle 2, LH/RH dance 2 each, LF/RF step 2 each, recovery 2, spin 4, side walk 4. Total 28 frames; split view tags explicitly.
- [ ] Create garden layers at 180×320 (sky/mansion, gate/plants, converging floor, foreground plants) with 24px overscan where panning occurs.
- [ ] Gatekeeper 48×64: idle 2, demonstrate 4, approving 2, deny/reset 2, step aside 2. Total 12 frames.
- [ ] Hook animation tags to exact beat markers; show opening, one repeat, recovery, acceptance and traversal.
- [ ] Device review: Mācron remains recognizable at tiny scale, quadrant contrast over plants, compact thumb reach, beat-dependent destinations, reduced motion.

## Session B: five-stage environments and cast
Each level needs independent back/middle/floor/front layers and an emissive mask; 5 layers × 5 levels = 25 source layers. Each environment also needs a side-on dance backdrop (5) and a transition doorway/rope/threshold strip (5). Native backgrounds 180×320 plus overscan; side-view strips 360×320. Export lossless PNG; no baked UI text.

| Stage | Palette focus | Required props and motion | Challenger frames |
|---|---|---|---|
| Garden | deep blue, warm windows, leaf teal | gate open/closed, rope, two hanging plant sway frames | 12 at 48×64 |
| Bar | amber, plum, teal | counter, shaker 4, drink slide 4, backlight pulse mask | 12 at 48×64 |
| Cool crowd | violet, cyan, cream | 3 reusable crowd silhouettes × 4 dance frames, circle open/closed | 12 at 48×64 |
| Restroom | coral, pale tile, muted navy | icon sign, door 3, key 3, tiny relief sparkle 4 | 12 at 48×64 |
| VIP | midnight teal, gold, pink | velvet rope 3, couch, reserved small seat, lounge lights | 12 at 48×64 |

Crowd characters must never resemble an unverified Covi. Use 3 silhouettes with palette swaps; avoid dense detail at cue origins. Add environmental bounces on beats, not full-screen flashing.

## Session C: final animation and story
- [ ] Extend Mācron with flourish set: arm sweep 4, foot slide 4, full spin 6, flourish settle 2. Reuse safe frames only when silhouettes remain coherent.
- [ ] Tlatoāni 64×72: seated idle 2, attentive nod 2, high-five reach 4, contact 2, invite 4; one visible tail, no facial hair.
- [ ] Ending closeup 180×160 composition with separate hands/characters: reach → contact → settle → invitation; 4–6 seconds maximum, beat synchronized. Robot scale must not magically grow to axolotl size.
- [ ] Obtain Covi reference; create 48×64 seated idle 2 and greet 2. This is the only identity-dependent art blocker, not a blocker to the first playable slice.
- [ ] Acceptance gestures for all challengers and level-local reset gestures. Denial remains playful, never cruel.
- [ ] Reusable effects: required hit spark 4, great hit 4, soft miss puff 3, optional flourish trail 6, respect meter pulse 3, gate unlock glint 4. Optional effects must never obscure future notes.
- [ ] Arcade initial entry: three glyph cells, selected-cell cursor, up/down prompts, confirm; original bitmap typeface supporting A–Z, digits, punctuation and ā/ó for game captions.

## Session D: atlas and integration review
- [ ] Pack runtime atlases by scene, with 2px transparent gutters; retain editable source, frame JSON, pivot and loop tags. Keep concept/reference art outside runtime registration.
- [ ] Add lossless backgrounds and sprite atlases to Flutter bundle. Check load time and memory on a lower-end phone before expanding art resolution.
- [ ] Review every frame against canon, all quadrants against backgrounds, cutscene skip/reload and missing asset fallback.
- [ ] Record upstream license status, generator provenance and final asset approval in art manifest.

## Animation contract
Metadata entry: `id`, `file`, `cellWidth`, `cellHeight`, `frames` (rectangles or grid indices), `pivot` (normalized bottom center), `facing` (rear/front/side), `loop`, `durationBeats`, `events` (beat offsets), `status` (concept/clean/runtime), `provenance`. Walk cycles loop every two beats; idle breath every four; required gestures peak at judgment beat, recover before next required gesture. Pause freezes music-linked animation; resume reconstructs from beat, not wall-clock drift.

## Delivered stage-2 art starter (2026-10-18)

- `assets/art/bar/bar-interior.png`: actual generated and inspected 1024×1536 portrait RGB background, no characters or HUD. Parent can integrate as flattened starter.
- `assets/art/bar/bartender.png`: actual generated and inspected 1024×1536 transparent single pose; not a completed animation set.
- Prompt provenance and production status: `assets/art/bar/README.md`. Bar parallax separation, side-view strip, shaker/drink animations and acceptance/recovery poses remain unfinished in Session B.
