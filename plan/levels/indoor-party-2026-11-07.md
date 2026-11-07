# Indoor party: built as a hidden level

**2026-11-07, branch `work/1863-indr`. For the owner and whoever finishes the art.** Facts are marked [F], my proposals [P]. Nobody has seen this move or heard it, on a phone or anywhere else.

Open it with `?level=cool-crowd`, once a build carries it. Any campaign level opens the same way, alone, for example `?level=bar`.

## What's there

- **`levels/cool-crowd.json`**, off the campaign, listed in `levels/index.json` under `review`. The game checks it on load like any other level, so a bad edit stops the game at the door. [F]
- **A crowd already dancing.** 18 guests on their feet, 12 of them on the middle of the floor. They slow down and move aside, and the other 6 dance in place. [F]
- **A band on the left platform**, four players, whose liveliness follows the player's recent form rather than the tier. Stand-in art. [F]
- **The BlinBlin dancer's back to the room** until the first call, with the Bartender's atlas standing in. [F]
- **Soft moving light** on the side walls, waking with the tier. No mirror ball. [F]
- **Music:** the synth `crowd_duende`, until the rendered music lands. [F]

## The opening, in beats

The intro here is 12 beats, not 4, so the room can be seen before anything happens. 12 and 4 fall the same way against the score's 8-beat phrases, so a tier change lands as it does on the other levels. [F for the arithmetic, P for the length]

| Beat | What happens |
|---|---|
| 0-6 | The crowd dances in the middle, turned away, doing their own thing. BlinBlin dances in among them with his back to us. No Mācron |
| 6 | Mācron starts walking in, from off the left of a phone screen. The guests nearest BlinBlin start to slow and move aside |
| 6-12 | They go, nearest first, each over 4 beats, with no speed at either end. Their dance eases to half speed at the middle of each move and back |
| 10-12 | BlinBlin turns around, using four drawings |
| 12 | First call, on an open floor. A level is refused if its parting ends after the first call |

Why these numbers: the art reads the music's beat and nothing reads it back, so nothing here can move the music, a note or the score. A pause freezes it. Under reduced motion each guest holds and then cuts to their new place, and BlinBlin cuts from back to front.

## Proposal: what "uninterested" means for people already dancing

The crowd model is unchanged. It still says how interested each guest is, with every rule of how it fills, so "the room is the meter", "lenient" and "warm-ish" still hold. Only the picture for each state differs. [P for the picture, F for the model]

| Model's state | Seated room | This room |
|---|---|---|
| Occupied | Seated, chatting | **Turned away from the fight, small steps at half time, their own thing** |
| Curious | Notices, points | Turns toward the fight, slows to a sway |
| Following | Seated, moving to it | Steps in time, facing the fight |
| On their feet | Stands up, dances, claps | Same dance and clap, with no getting up |
| Celebrating | Cheers | Cheers |
| Run won | Most sit down during the wide shot | **Nobody sits. They dance until the room dissolves** |

Tests hold, on the real level file: a clean run ends with everyone celebrating; a run of nothing but scrapes that clears has everyone facing the fight and dancing, with nobody celebrating; a long losing streak turns people back to their own thing; and no seated, stand-up or sit-down drawing is ever chosen. [F]

"Turned away" is weak today. There are no back views, so a guest is only flipped to face away from the middle. That flip is also a sudden change, against the "view changes are drawn" rule. It needs the drawings below.

## The band

- **Where:** the plate's platform is data, `scenery.platform`, with its height and outline. People on it are sized by the room's floor and raised by its height. A guest can't stand on it, and a player can't stand off it (both refused on load). [F]
- **Energy:** a new number, `recentForm` in the crowd model, moves a quarter of the way to each phrase's credit. Nothing else reads it, so it can't touch the score. A clean run passes .9 by phrase 9. A run of scrapes sits below .55. Both reach the same tier, which is how a test shows it's separate. A player who improves shows it within three phrases. [F] The quarter is a starting value. [P]
- **How it shows:** each player has a ladder of clips, calm to lively. Energy picks the rung, once a bar, so a change lands on a downbeat. Energy itself changes over 24 beats with no speed at either end. Under reduced motion each rung holds one drawing, which still differs from the next. [F]
- **Bringing in the real art is a data change:** add the atlas to `assets/art/ensemble/manifest.json`, list the art folder if it's a new one, and point `ladders` and `players` at the new drawings. The manifest now accepts atlases beyond its fixed list, and the level says which drawings it needs. Set `standIn` to false. [F]
- **Only about two of the four players show on a 390 by 844 phone,** because a phone sees only the platform's right part. The other two spill off on purpose, and a wider screen shows them. The left of the crowd is kept thin so their heads and shoulders stay in sight, which a test holds. [F] That's why more of the crowd goes right than left. [P]

## Data for a later room

All of it is optional in a level file, and existing levels don't change:

| Field | What it does |
|---|---|
| `crowd.seat: "standing"`, or per guest | On their feet, with no seat drawn |
| Guest `partTo` | Where they move when the floor opens. Without it they dance in place |
| `crowd.floorDance` | `ownThing` and `glance` clips, and `parting`: `from`, `beats`, `stagger`, `slowTo` |
| `stage.heroEntersAt` | The beat Mācron starts walking in |
| Challenger `facingAway` | `back` clip, `turn` drawings, `turnBeats` |
| `scenery.platform` | `lift`, `outline` |
| `scenery.band` | `standIn`, `ladders`, `players` |
| `scenery.wallLight` | `periodBeats`, `zones`. Refused if a zone reaches the tap band or the quiet area |
| `review` in `levels/index.json` | Levels reachable only from `?level=` |

## Art: what exists and what must be drawn

**Honest inventory.** [F, from the manifests and by eye on the sheets]

- Guests have more than the plan thought: `standing_idle` (2), `step_touch` (4), `clap` (2), `cheer` (2), each with outfits. So the crowd here uses **their own drawings, not another dancer's**. "Standing poses needed" is true only of the poses below.
- `step_touch_b` is a pointing arm. Pointing is reserved for flourishes and the turn from uninterested to interested, and this room shows it far more than seated rooms do.
- Nothing is drawn with instruments. Nobody on the platform is really a musician yet.

**Stand-ins in the level today, each to be replaced:**

| Where | Stand-in | Replace with |
|---|---|---|
| BlinBlin | Atlas `bartender`, with `spin_back*` for his back and `spin_*` for his turn | Atlas `blinblin` from `work/1860-blwv`: `back_groove`, `reveal` |
| Band | `guest0`-`guest2` frames, no instruments | The BAND agent's clips, once the owner approves sheets (`plan/levels/indoor-band-2026-11-07.md`) |
| Own thing, glance | `step_touch` and `standing_idle` frames, flipped | Below |

**To draw, for each of the three guest silhouettes** [P for the list]. 14 drawings each, 42 in all:

| Clip | Drawings | What it is |
|---|---|---|
| `back_dance` | 4 | From behind, three-quarter: small steps, weight shifting, on their own. This is "uninterested" |
| `glance` | 2 | Standing, turned back over a shoulder toward the fight |
| `sidestep` | 4 | Moving aside mid-dance, in profile: what they do while the floor opens |
| `groove` | 4 | Facing front, arms low, no pointing. Replaces `step_touch` here |

**BlinBlin:** already planned in `work/1860-blwv`. His `crossed` clip and nod are what the win needs.

**The win, on hold.** The level has no `exitShot` yet, because the drawings don't exist, so on the hidden level he walks out through the arch and QUÉ FLOW shows on the end screen. The shot itself fits the existing data, with no new code. [F for the data, P for the beats]:

| Beat | What happens |
|---|---|
| 0-3 | Wide: dancing |
| 3-5 | Mācron walks to his mark, on the other side of BlinBlin |
| 5 | Cut in. Both arms crossed, facing each other |
| 6 | **Both nod, on the beat.** QUÉ FLOW slams in. A soft sound accent |
| 7.5 | Back to wide, everyone still dancing |

It needs a plate, a BlinBlin arms-crossed bust with nod (3 drawings), and a Mācron arms-crossed with nod (3 drawings), with his body and logo. Those six are not yet assigned or drawn. A last level's shot has to fit its success score (8 beats here), and this one does.

## Chart: a note for the DOUBLES agent

`chart` is the plan's proposal, unchanged: offsets `[0, 1, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5]`, four limbs in turn, with five variants I wrote by permuting limbs. Kept simple on purpose. Add your double and paired moves here. The level's parser is unchanged, so anything you add to the chart format should just work. Only a person playing it can approve it. The half-beat gap is the risk named in the plan: 278 ms at this synth score's 108 BPM, 250 ms at its top tier of 120, and 221 ms at the rendered ladder's proposed 136. [F for the arithmetic]

## Joining the campaign later

Data only, and a test does exactly this to the real files:

1. `levels/index.json`: remove `cool-crowd` from `review`, add it to `campaign`, and give `bar` `"bridgeToNext": "bar_to_crowd"`.
2. `levels/bar.json`: `successScore` back to `bar_swag_success`, per the note in `tool/music/generate.mjs`. Check the bar's close-up then, as the style guide says, since it ends at 11.5 of 16.
3. When the rendered music lands, point `music` at it. `lib/music` and audio in `garden_page.dart` weren't touched, apart from the single line that reads `?level=`.

## Depends on

**The plate.** `background` is `cool-crowd/cool-crowd-v2.png`, and it isn't committed, as instructed: I used a local copy of `room-cool-crowd-v2-floor/987502-flat1.png` for every test and still. **On a clean checkout of this branch, `flutter test` fails and a build won't start, because `pubspec.yaml` lists `assets/art/cool-crowd/`.** Merging `work/1859-room` fixes that. If it names the file differently, change `background`. Marks and floor numbers here were placed by hand against that plate and its floor overlay, with the approved camera, horizon .25 and eye 1.5 adults. The room's platform outline and height were measured by eye from the plate. Recheck them against whatever the room agent's data says.

## What was checked, and how

- `flutter test`, including the 31 tests in `test/cool_crowd_level_test.dart`, and `flutter analyze lib test` at the expected 4 notes.
- That file plays a real run through the real session: 11 phrases of perfect taps clear the level, with every guest celebrating. It also proves, on the real file, no overlap with the thumbs, Mācron's marks, BlinBlin's marks or the quiet area, using a body box half as wide as tall. Arms reach further than that box, so a raised arm can still cross.
- Stills of the real scene at 390 by 844, in `build/stills/cool-crowd.png`, `cool-crowd-reduced.png` and `cool-crowd-run.png`, looked at by me: crowd in the middle with BlinBlin's back visible among them, the floor opening, the turn, the first call, Mācron's answer and full swing. They look right as still pictures.
- Wall light by numbers: the right wall's mean brightness rises from about 82 at the start to about 104 at the top tier, including the room's warmth. **Its movement hasn't been seen.**

## On-screen checklist for the owner

Open `?level=cool-crowd`, or with `&autoplay=flawless`:

- [ ] Does the crowd read as already dancing, and as uninterested, before the fight? Their backs aren't drawn yet, so this is the weakest point.
- [ ] Does the opening take the right time? 6 beats of crowd, 6 of parting. The whole intro is about 6.7 seconds on this score.
- [ ] Does moving aside read as people making way, or as sliding? There's no drawn sidestep yet.
- [ ] Is 18 "a bunch", or should there be more? Past about this many on a phone, they cover the room.
- [ ] Does BlinBlin read in among them, with his back to us, and is the turn clean? It's the Bartender's spin for now.
- [ ] Does the band show enough on a phone, and does a better run look livelier? With guests as stand-ins, judge only the timing.
- [ ] Is the moving light soft, and is it there at all? On a phone it lands on the right wall, because the left windows are mostly cropped.
- [ ] Do the flips between turned away and facing in look bad? They need drawn turns if so.
- [ ] Does it perform on a phone with 18 guests, 4 players and clipped light?
- [ ] Play the chart. Only a person can approve it.

## Not done

- The win's close-up, and everything in the art lists above.
- Chains: part of BlinBlin's art, not this work.
- Any new sound, which belongs to the render agent.
