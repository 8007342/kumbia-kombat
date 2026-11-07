# Party-up by tier, and hardest combos, 2026-11-07

Branch `work/1857-prty`. Rulings: fifth round ("everything should slowly party up"), sixth ("the room is the meter", full swing for skilful play), ninth and later on leniency, and the tenth-round note on party-up for every player.

## What was already there

- Guests climb by phrase, and full swing (`partySwing`) makes props dance on the beat for good runs. Neither changed.
- Before this, the music's tier moved no scenery. Below full swing, sprites ran their whole drift loop at the same size from the first second, garden layers sat still, and lamp glows stayed at one small size.
- Sibling project ranitas wasn't reachable from this lane (`sibling_projects` returned nothing). I worked from the fifth round's summary and the progression report, not from its documents.

## What's built

`lib/gameplay/party_up.dart` follows the music's tier number, for every player. It never sees a tempo, so the lawn's 144, 160, 136 order can't lower the room when the BPM falls. It reads the beat and tier and returns sizes, so it can't move music, notes or score.

| Tier step | What wakes, for everyone | How |
|---|---|---|
| 0 | Near still | Sprites show about a third of their drift. Garden layers stay as painted |
| 1 | Lamps and room warmth | Glows grow and breathe over a bar, and a warm wash builds from the top, ending above the tap band |
| 2 | Plants, umbrellas, lanterns | Plants and umbrellas drift further, not on the beat. Garden fronds and flowers move one drawing either way, at a quarter of their dancing speed. Lanterns swing a little in time |
| 3 | Flames and waiters | Candles and garden flames flicker in time. Waiters range further across the room |
| 4 | All of it at full size | Still a warm-ish party: no plant, umbrella or waiter on the beat |
| Full swing | As before, skill-gated | Plants, umbrellas and waiters dance on the beat. Tier alone never starts it |

Method, from the fifth round:

- Nothing appears or slides in. Only sizes grow, from zero speed, on quintic entrances counted in beats, so they freeze on pause.
- Each step's entrance is separate, so overlapping ones don't change speed suddenly.
- Props of one kind wake at different points.
- A dropped tier holds the room for two phrases, then fades over 48 beats. Climbing back cancels the fade.
- Clearing needs tier 4, so a poor run that clears ends with all of this life.
- As swing arrives on garden layers, tier movement fades down and the dance fades up.
- The room cools with the win through the existing `warmDown`.

Reduced motion: props hold still at every tier. **Proposal:** glow size and warmth still follow the tier without breathing, because they change slowly and the room is the meter.

### By room

| Room | Gets |
|---|---|
| Garden | All of the above, using its 8 layers, which now carry a `kind` in the level file. Waiter range widened |
| Lawn | Lamps and warmth, table candles, plus **additions**: 4 more lamp glows on the pavilion and posts, 2 umbrellas and a waiter, all existing art |
| Bar | Lamps and warmth, plus 4 more glows on its hanging lanterns. Waiter range widened, so he comes out from behind the Bartender as tiers rise |

### Gaps, not done

- **Cups with straws:** no art exists, and the guests' drinks are part of their poses. Another agent needs to draw them.
- **Lawn and bar layers:** no cut-out lanterns, water or string lights, so these rooms have much less movement than the garden. The lawn's pool has no shimmer.
- **Bar and garden potted plants** sit at x .14 and .86, which a phone's crop cuts off. I tried moving them into view in the bar and lawn. The sprite is a hanging plant with a long cord, it looked wrong rooted to the floor, and it covered people and Mācron, so I put the bar's back and left the lawn with none. They need a standing plant drawing.
- **The shared accent every 2 bars** from the progression report isn't built.

### Numbers

All are artistic starting values, not findings. Entrances last a tier and a half (24 beats in the garden, 48 in the lawn and bar). Ranitas's are 110 to 180 s, so ours are several times faster and more players may notice them.

## Hardest combos

All are **proposals**: `"status": "proposal"` in the data. Nobody has seen, heard or played them, and nothing plays them yet. Each is an 8-beat call with 10 notes. The level files' `chart` isn't touched; combos are a separate `hardestCombo` field.

| Opponent | Name | Where | Call |
|---|---|---|---|
| The GateKeeper | The Velvet Rope | `levels/garden.json` | show_off, clap, spin_flare, finish_turn. Last note: circle |
| The Girls | Round Robin | `levels/pool-garden.json` | A: show_off, step_touch, finish_turn. B: skirt_play, show_off, finish_turn. Last note: circle |
| The Bartender | Last Call | `levels/bar.json` | spin_flare, clap, groove_double. Last note: stomp |
| The BlinBlin dancer | All That Glitters | `levels/index.json`, `upcomingOpponents` | hip_pops, show_off, finish_turn. Last note: stomp |
| The PoolPlayer dancer | None yet | `levels/index.json`, `upcomingOpponents` | `"placeholder": true` |

The BlinBlin dancer has no atlas yet, so his clips are checked only against the shared table, on the assumption that his planned motion set (the same one the GateKeeper uses) covers it. Chains aren't part of it.

The loader refuses a level with no combo, a move past the end of the call, overlapping moves for one dancer, an unknown dancer, one of a pair with no moves, notes the chart check would reject, and a longer move on any note but the last. Tests check every clip against the dancer's real table and that neighbouring notes are at least 180 ms apart at the room's fastest tier. That is a data check. It says nothing about whether a combo is fun or fair.

## Verified, and how

- `flutter test`: 504 pass after merging `game` at `d1123fa` (457 at the start of this work, 501 before that merge). The merge had one conflict, at the end of `levels/pool-garden.json`; both sides are kept. `flutter analyze lib test`: the same 4 notes in `battle_staging.dart`.
- Stills of the real scene, nobody playing, at tiers 0, 2 and 4 in all three rooms. I looked at them, and measured the top quarter of the picture getting steadily warmer in each room. Top-of-picture red rose by about 10 in the garden, 7 in the lawn and 17 in the bar, on a 0 to 255 scale. That's on the phone-sized software render, not the browser's.
- Golden, `test/goldens/levels_before.json`, compared old against new for the garden and the bar:
  - **Held:** clear times and beats, perfects, required hits, last limbs, and beat, phase, tier and all crowd numbers in all 19 samples of each room.
  - **Moved on purpose:** drawings and shadows of props and waiters (`drawImageRect`, `drawOval`, `translate`), and 4 new lamp glows per sample in the bar (76 `drawCircle` calls).
  - The harness renders only at its samples, so it barely sees the wake. `test/party_up_test.dart` covers that, rendering every step.

**Not verified:** nobody has seen this moving, in a browser or anywhere else, and no test can say it feels good. Stills can't show whether the drift reads as life or whether the entrances pass unnoticed. Nobody can hear here either, so nothing about how it sits with the music is known.

## On-screen checklist for the coordinator

After merging, on the preview, with the rendered music if it's in:

1. **Garden, autoplay flawless.** Does the room look calmer at the start than it did, and clearly livelier by the last tier?
2. **Autoplay with errors.** At the top tier without full swing, do plants, umbrellas and the waiter hold back from the beat? Does this read as warm-ish, rather than dead?
3. **Flawless again.** Is the step up to full swing still clearly a reward?
4. **Fronds and flowers under tier life.** They drift one drawing either way, locked to a slow beat. Does that read as a breeze or as dancing? If dancing, it breaks the sixth round's rule, and `_lifeReach` in `room_layers.dart` is the setting.
5. **Lawn.** Do the two new umbrellas and the waiter sit right among the guests? Does the waiter crowd the Girls when they cross at the back?
6. **Lawn's order.** When the tier goes to the 136 BPM section, the room must keep rising, not dip.
7. **Bar.** Does the waiter coming out from behind the Bartender look intended? Are the new lantern glows on the lanterns, on phone and wide screens?
8. **Warm wash.** Is it visible but not a filter? Any banding on a dark sky? Its strength is `.4 * warmth` in `_drawLampGlows`.
9. **Lamp glows at the top tier.** Soft, with no flash, and nothing near the tap band?
10. **A failed phrase in mid-run.** The room shouldn't visibly sag.
11. **Reduced motion.** Props hold still. Glows and warmth still rise slowly. Is that acceptable?
12. **Frame rate.** The wake adds one rect and larger radial glows. The bar and lawn now have 8 and 6 lamps. Check fps on a phone.

## For the owner

- The combo names and shapes are proposals, yours to change.
- Whether the warm-ish tier life stays on the right side of "staff, umbrellas and plants don't dance" is your call once you've seen it.
