# The billiard room

**2026-11-07, branch `work/1871-bill`. For the owner and whoever finishes the art.** Facts are marked [F], my proposals [P]. Every choice here is the agent's, under the owner's "complete the party and pool room all by yourself", and can be reversed. Nobody has seen this move, heard it or played it on a phone.

It is wired as the last level, after the indoor party. `?level=billiards` opens it alone.

## Still stand-ins, and how to swap them

Each swap is a data edit.

| Where | Today | Replace with | From |
|---|---|---|---|
| Her dance | Atlas `bartender`, so The Bartender dances here | `stage.challengers[0].atlas: "pool-player"` once the atlas is packed. Her dancer block is already in `choreography.json` | POOLART |
| Music | `crowd_duende`, with `bar_swag_finale` as the 16-beat success | The rendered `billiards` key, about 100 BPM, 16-beat final success. Then drop the guard in `rendered_music_test.dart` | MUSIC |
| Bridge from the party | `crowd_to_restroom` in `index.json`, as the synth fallback | Rendered `cool-crowd.bridge`, 8 beats, read by the runtime | MUSIC |
| Guests | The old three guests | The new party people | GUESTS |

## Room

- **Plate:** the accepted 989601, untouched, floor included. The source stays in `art_runs/rooms/billiards/picks/`. The game draws `assets/art/billiards/billiards-room-clean.png`, with the lamps lifted out. [F]
- **Camera, refit to the paint:** cornice and wainscot lines meet at x .494, y .268. The table's height against its feet gives an eye height of 1.27 adults, and the door agrees to within the reading. Mācron is about 38 logical px at home, over the 34 floor. [F] The spec's `ids.png` isn't regenerated, because the guide never matched this paint. The level's test uses a floor outline traced by hand instead.
- **Reflections in the tap band:** left as painted. Median brightness there is 7 of 255, the top 1% is 118 and the brightest pixel is 177. On stills the rings stay clear over them. **Moving cues over them haven't been seen**, so that's the first thing to check. If they get lost, dim the plate's lower part. [F, P]
- **Standing behind things:** the plate is flat, so a person behind a table would draw over it. `scenery.occluders` leaves a table's or a lamp's outline out of anyone further away than `frontY`. Seen on stills: people cut cleanly at the rail, lamps in front of heads. The lamp outline doesn't sway with the lamp, so an edge may show a sliver when someone stands right behind one. [F]
- **Layers:** two lamp clusters that sway from the ceiling, kind `hanging`, plus 9 glow marks on the shades, sconces and door, waking with the tier. GPU: 4 images, 62 s. Both fills are clean by eye. Rods stay painted: they're nearly black on black. [F]

## Crowd

- **Four players at the tables**, two behind the far rails and two at the inner ends. They use `scenery.band` with no platform, on a `tier` ladder: absorbed, then watching, then clapping. `lateBy` staggers them, so two turn at tier 1 and two at tier 2; two clap at tier 3 and two at 4. Every clearing run passes through tier 4, so all of them are engaged by the win. A drop in tier turns them back to their game. [F for the data, P for the choice of `tier` over `form`]
- **Who they are:** POOLART's `pool-bg-a`, `-b`, `-c`. There are three drawings for four places, so the flat-cap man plays at both tables, on opposite sides of the room. B has `stature` .88, POOLART's unchecked suggestion. [F for the art, P for the casting]
- **Why `tier`:** the ruling is "start uninterested, engaged by the time a level clears", so a clearing run must always get there. `form` might not. One data edit changes it.
- **Twelve guests, standing, the crowd model unchanged.** Four show on a phone, behind the tables. The other eight are off a phone's edges, for wider screens. My first pass of ten on-screen figures read as a wall and hid the tables. [F]
- **She starts with her back to us**, absorbed like the rest, and turns at beats 10 to 12 as Mācron walks in from off the left: the "stops Mācron" beat, using the party's `facingAway`. [P]
- **Rule kept:** nobody stands nearer than she does. [F, test]

## Chart

| Pattern | Tier | Presses | Richer steps |
|---|---|---|---|
| 0 | 0 | 8 | 0 |
| 1 | 1 | 12 | 4 |
| 2 | 2 | 12 | 4 |
| 3 | 3 | 13 | 5 |
| 4 | 4, first | 14 | 6 |
| 5 | 4, second | 14 | 6 |

- 25 richer steps against the party's 24 and the bar's 18. Offbeat share 79.5% against the party's 79.2%, a hair over, and only because the test asks. Both are held by `play complexity rises`. [F]
- **Fairness:** held at 104 BPM, the top of what MUSIC plans (96 to 104), with the same limits as the bar. Five of the six doubles use half a beat: 288 ms at 104 BPM, 3 ms over the guess of 285. **That margin is thin, and depends on the final tempo.** [F]
- **How it was written:** by a random search over the real `fairnessProblems` and cue-separation functions, with stroke steps and move kinds fixed by hand. It finds what is legal, not what is musical. It has never been laid against the billiards melody, because the music doesn't exist yet. **Re-check it when the take lands.** [F]
- **Rules:** 2 phrases a tier, 2 final challenges, metric "Finesse". [P]

## Cue stroke

Tap, then drag straight up the floor, as if shooting up the table. It's the existing optional move, `flick`, offered by a new `offer` on a chart step, in every pattern. Tier 0 offers it on its last note, to teach it. [F]

- Natural fit: every move is already an invitation, and the guide draws a line with a ball. Any other move on that note also counts. Clearing never depends on it.
- The next note leaves 1.5 beats on a mid-phrase stroke, which is at least the 800 ms the session needs at 104 BPM. A level is refused by `fairnessProblems` if not. [F]
- **Not done:** she doesn't sight down the cue in the call on that note, so the call doesn't teach it. Only the glyph does.

## Sound

- `clack`: ball on ball, 2.5 kHz and 1.1 kHz partials and a noise tick. Plays when a move or a richer step lands, from `music.moveAccent`. A page test proves a richer step sends it to audio. [F]
- `chalk`: a dry rasp at 3.4 kHz, on the dab and softly on the chalking.
- Peaks are computed. **Nobody has heard either one.** Whether the clack on every richer step is a reward or a nuisance needs ears. To limit it, leave the session's rich step out of `_moveAccent`.

## The win

QUÉ CARAMBOLA. [P]

| Beat | What happens |
|---|---|
| 0-3.5 | Mācron celebrates |
| 3.5-5.75 | He walks to her right |
| 6, 6.5 | Close-up. She chalks, with two soft rasps |
| 7 | She winks |
| 7.5 | She reaches |
| 8 | The dab on the downbeat, a blue dot, the title, his round eyes go wide |
| 8.25-8.75 | He squashes, and his eyes turn to smiling arcs |
| 9.5 | He blushes. She sways |
| 11.5 | Back to wide. The music fades over its last 4 beats, then the end screen |

It fits the 16-beat success, as a last level must. A table cut from the room is the foreground, covering where both bodies end. It's drawn over him as well, so he stands behind the table rather than on it. Her drawings and his are POOLART's. Her cue comes in level above his head line, and her forearm crosses his left ear. Seen on stills, not moving. [F]

**Her combo** is POOLART's Tres Bandas, moved into the level. I changed its last move from stomp to circle, since the test holds a hand to a hand's move. `upcomingOpponents` is now empty. [F]

## What was checked, and how

- `flutter test`: 648 pass. `flutter analyze lib test`: the same 4 notes.
- `test/billiards_level_test.dart`: marks on the painted floor, nobody in front of her, the players' arc, a flawless autoplay run that clears and lands strokes, the dab's beats. It writes stills to `build/stills/billiards.png` and `billiards-win.png`, which I read by eye, with guests and players as stand-ins.
- Local vision, 91 s on the room's sheet: it answered with a generic list of every fault I asked about, naming nothing specific. It missed the things I changed by eye: the wall of guests, the guest over the door, the cue across his face. No use as a first pass on a sheet this busy, with that prompt.

## What went wrong

- I left a stray `cat` waiting on input, and the same mistake cost a commit several minutes in another agent's note. Killed by PID.
- I pushed one commit (`e2276be`) with a failing complexity test. The next commit fixes it.
- My first charts passed fairness and failed cue separation, including at the seams between phrases, so I searched instead of writing by hand.
- The party's `a real run clears it` test failed once merged, because a last note late in a phrase settles the win after the phrase ends. I added one line to that test. Its chart is PARTY's.

## On screen, for the coordinator and owner

- [ ] Cues and the stroke's guide over the floor's reflections, moving.
- [ ] She turns from her back as he walks in: does it read as stopping him?
- [ ] Players turning to watch one by one, and whether the changes read as sudden until real drawings land.
- [ ] Lamps sway without showing a patch, and no sliver where a head sits behind one.
- [ ] The whole win, moving, with the sound. Then again with her real drawings.
- [ ] Play the chart on thumbs: is 14 presses in a phrase at 100 BPM fun? Only a person can approve it.
- [ ] Does anyone discover the cue stroke, and does it feel like a shot?
- [ ] 12 guests, 4 players and clipped outlines on a phone: frame rate.
