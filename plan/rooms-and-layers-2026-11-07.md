# Rooms and layers, 2026-11-07

Branch `work/1859-room`. Fact and proposal are kept apart. "Seen" means I looked at still images, at phone size or larger. Nobody has played this, and nothing here has been seen moving in a browser.

## The indoor party room

**The owner accepted plate A**, including the panels on the right. The left platform stays, because a band will play on it. It's at `assets/art/cool-crowd/cool-crowd-room.png`.

**How it was made.** The walls are from the fourth plate round, seed 987502. The floor is apart from them:

- Qwen painted only a flat stone seen from above, seed 988001. It has no perspective to get wrong.
- Code warps the stone through the room's camera, draws the joints from that camera, and mirrors the room's walls and lamps into the polish.
- The floor's median luma is about 26. The neighbouring rooms are 15-34.

**Tried and dropped:**

| Try | Result |
|---|---|
| Coded stone with no painted texture | True and calm, but airbrushed beside the bar |
| Qwen repainting the coded floor, denoise .35 and .55 | Added no texture, and redrew the walls |
| A stone with loud gold veins, seed 988002 | The veins cross the tap band, and could read as cues |

**What changed in the room's numbers.** No plate had held the old guide, so the spec now follows the paint: horizon .25, eye height 1.5 adults, vanishing point x .36. At foot .43 an adult is .12 of the plate, the same as the `cool-crowd` entry in `party_layout.dart`, though that entry says horizon .24. I left that entry alone, because the game reads levels. Mācron is 35.4 logical pixels at his mark.

**The platform as data,** in `art_runs/rooms/cool-crowd/floor.json`, under `platforms`: `s` 3.24 to 5.61, `t` -2.05 to -0.9, height .36 adults. I drew it over the plate, and its top outline matches the painted edges. Only plate x 157-291 of its top is on a phone. The loader doesn't read this yet.

## Layers

| Room | Now moves | Plate and atlas |
|---|---|---|
| Lawn | Palm crown, 3 potted plants, the string of lights over the pavilion, the pool's water, 3 lamps | `pool-garden/pool-garden-clean.png`, `pool-garden-layers.png` |
| Bar | 5 hanging lanterns, 2 ferns, 3 counter candles | `bar/bar-interior-clean.png`, `bar-layers.png` |

Both are data in `levels/*.json`, with specs in `tool/art/rooms/layers/`. All 11 removals worked within two seeds: 22 images. The string of lights needed no GPU.

**Known flaw.** A prop at rest doesn't match the painting exactly along its edge: about 2,700 full-size pixels differ on the lawn and 6,500 on the bar. At phone size I saw only slightly softer edges. In the lawn's clean plate, what's left behind the left plant is a pale blob, which should show only a little as the plant moves. The lantern tops on the bar are also cut with a little wall in their polygon.

**Left out on purpose.** Two lawn lamps sit in the quiet area behind the opponent, and the loader refuses them there. The middle bar stools stay painted, because the back row of guests sits on them.

## Crowds

- **Bar:** already as ruled, and held by a test: the back row at the bar on painted stools, two rows in front on stools.
- **Garden:** already 24 guests at 9 tables with drinks. Unchanged.
- **Lawn:** had 17 guests and looked thin on the right. Now 20 guests at 10 tables, the additions on the right. The staging tests pass.

## Shared props

**New: a drink with a striped straw on every garden and lawn table.** It leans in five drawings on the beat as the crowd reaches full swing, and holds still with motion reduced. A table draws one if its room's prop set bakes it, so the bar, with no tables, has none.

This is the one code change: `tableCupFrame` in `ensemble_sprites.dart`, and about 20 lines in `garden_scene.dart`.

**Not done as new work:** umbrellas, candles and plants were already shared and animated, and party members are still the existing guests.

## The golden file

`test/goldens/levels_before.json` changed on purpose. I compared old and new: every older draw is still there in order, ignoring the prop atlas's new size. It gains 4 calls for each drink drawn, and everything except draw calls is equal, including scores and timing.

The golden covers the garden and bar only, and it leaves out layer draws, so it says nothing about the lawn's new guests.

## Drafts for the owner: not accepted

**PoolPlayer sheets.** Proposed: an elegant woman of about sixty with a silver bob, a billiard-green waistcoat, and the cue as her prop. Age and look are my proposals, and pronouns are they/them until the owner says. Review: `tool/art/references/pool-player/sheet-review.png`. My picks are `front-candidate.png` (seed 989001) and `back-candidate.png` (seed 989101).

- That back has a pale ball at the cue's foot, which isn't a real part of a cue.
- Some other candidates have stray objects by the feet, so they're worse.
- The frames stage refuses a `cue` prop today, so the cue is in the words only. It needs a prop kind before any frames.

**Billiards room.** Spec: `tool/art/rooms/billiards.json`. Two tables, low green lamps, bottle-green walls. No people are painted in, and the players are to be sprites later. The first pass held the layout on all 4 images, which the indoor room never did. Review: `art_runs/rooms/billiards/sheets/p2-review.png`. My pick is seed 989600, in the cache at `kumbia-art/room-billiards-v1-a/pick-989600.png`.

- It has amber floor glows inside the tap band. If they get in the way of cues, the separate floor route is there.
- It's in no level, and its marks are placeholders.

## What went wrong

- `flutter test` filled the shared disk for a few minutes, from all agents' `build/` folders. My files came through intact, and `build/` is now a symlink to the cache.
- I left a stray `cat` waiting on input, which held a commit for several minutes until I killed it by PID. No harm done.
- GPU waits ran up to about 10 minutes a job, sharing the queue with the BlinBlin wave.

## How it was checked

- `flutter test`: 509 pass. `flutter analyze lib test`: 4 notes, as before.
- `tool/art/tests/test_rooms.py`, including the platform's corners against the plate, within 16 pixels.
- By eye: plate sheets at phone size, cast proof on plate A, before-and-after sheets for both rooms, and `build/stills` full-swing frames from the real scene.
- **Not checked:** anything moving. `motion.gif` previews exist in the cache, but I can only read single frames.

## To look at on screen

**Lawn**
- [ ] Palm, plants and the string of lights move at full swing, and only drift or hold before it. Do they look attached?
- [ ] The water's ripple: does it read as water, or as a flicker?
- [ ] Any ghost behind the left plant.
- [ ] The three new guests on the right, and whether the dancers still read clearly.

**Bar**
- [ ] The five lanterns swing without showing a patch of wall moving with them, especially the big one at the top.
- [ ] Ferns at the phone's edges. They're mostly off screen by design.
- [ ] The candles change shape in time without flashing.

**Garden and lawn tables**
- [ ] The drinks read as drinks at phone size, and sit on the tables.
- [ ] Their lean at full swing is visible but small.

**Indoor party, once its level exists**
- [ ] The floor's reflections beside moving dancers, since they don't reflect in it.
- [ ] Cues over the floor's veins in the tap band.
