# Cinematics: the shot book

**Draft, 2026-11-05. Nothing here is built.** The game has one kind of transition today: a sprite walking a
route (`DepartureRoute`). It has no close-ups, no cuts and no shot layer. The owner ruled that the fist bump is an
extreme close-up, which makes this a foundation rather than a one-off. Every level's exit and the ending will use it.

## What Cannonball teaches

Source: `github.com/8007342/cannonball` at `238d7de`, mainly `docs/garage-continuity.md`, `docs/garage-radio-proof.md`,
`lib/ui/departure_timeline.dart` and `docs/driving-milestone-review.md`. What it has built is one 7.6-second
departure, from key box to live driving. `docs/validation.md` still lists "full storyboards/cutscenes" as not done, and
`docs/research/design.md` calls its wider sequence "candidate beats, not approved scenes". We read the documents and
code. We have not watched it play.

| Their finding | Our rule |
|---|---|
| A fade isn't continuity. Keep subject direction, proportions and screen position through short motivated cuts (their reading of Cianciolo's NetherRealm GDC 2011 talk) | Whoever is on the right in the wide shot stays on the right in the close-up. Cuts need a reason, and the fist's travel carries the eye across |
| No black frame at the end: the overlay clears to the live scene, already loaded behind it | A shot sits over the running scene and reveals it. No fade to black between levels |
| One timeline names its shots (`reach`, `grasp`, `pickup`...) and sound hangs off those names, with duplicates within 250 ms ignored | Same, but our clock is the transport beat, so contact lands on a downbeat. Their clock is milliseconds, because they have no music to land on |
| Starter and rev sounds begin before the driving picture | Let sound lead the cut: the clink or the first bar of the next room arrives before its picture |
| Cinematic sounds have their own bounded set of nodes, so a song change can't cut them off | Same. Mute and hidden-tab still stop them |
| Skip completes at once, completion fires once, and a hidden tab leads to an explicit resume | Same. Beats clear the level before the shot starts, so a skip can't lose progress |
| Reduced motion keeps the same story beats in 1.8 s instead of 7.6 s, with no camera moves | Same beats as held cuts, with no slide or shake |
| A detached wrist came from a badly scaled hand. The fix kept the hand modest and extended only the forearm offscreen | Every limb in a close-up runs off the frame edge, so no wrist end ever shows |
| Fingers and key share one computed anchor, recomputed after cover-fit cropping | Contact points are data, measured on the final drawing, not eyeballed per screen size |
| Wide art is painted wide and cropped by cover; never stretched. Panels preload before their first shot | Same. A hitch at the moment of contact would be the worst place for one |
| Widget tests cover beat order and handoff, yet they admit tests can't judge feel, so a moving review stays open | Review every shot moving, on a phone-sized screen, not from stills |

## Rules for Kumbia shots

1. **Time is in beats** and the music never stops. Shots live inside the existing success and bridge bars.
2. **Close-ups may cheat scale.** The ruling removes the kneeling Gatekeeper. It also settles the older question of
   how a robot on the floor gets a glass off a counter: he doesn't need to, because the frame shows only hands and glass.
3. **Limit each shot to one idea.** Roughly 2 beats for the close-up, because a phrase is what the player remembers.
4. **The tap band stays where it is**, dimmed and inactive. Shots use the top area. Nothing jumps when play resumes.
5. **Same pixel size as the world.** Mixed pixel sizes are the flaw that already made the draft pool room look blocky.
   Paint a close-up at the logical size it fills, divided by the room's pixel scale. Exact number to be measured.
6. **No text baked into art.** The level's two big words, `copy.clearedTitle`, are the only text in a run, drawn by the UI from the contact beat. See "Titles and accents" below.
7. **Glint is reserved** for the finale's high five (from `plan/storyboard.md`).

## Titles and accents, as built

The owner, 2026-11-06: "ONLY TEXT FOR THE CINEMATIC HIGHLIGHT, where we get our simple 2 word messages, where the second word is one of the semantic pop culture for the party and music theme."

**Title.** `copy.clearedTitle` holds two words, one to a line, and the level file is refused otherwise. `ExitShot.titleAt` puts it up from `contactBeat` for at least 3 beats, because the garden's close-up lasts only 1.25 beats after contact. It can outlast the close-up and sit over the wide shot. A level with no `exitShot` shows no title in its transition; if it's the last level, the end screen still shows the words.

**Accents.** A `cue` entry's `track` can name a one-shot patch from `lib/music/accent_voice.dart`: `bump`, `glug` or `clink`. `pitch` transposes it around 60, and `velocity` scales it. Any other track must be one of the score's voices, and the level file is refused otherwise.

What the wiring needed, and what went wrong when we traced it, for the next custom moment:

| Finding | What it did | Now |
|---|---|---|
| Cues did reach the backend, on time | Mixed into the success score or bridge, then queued by the transport like any note | Unchanged, and a test follows them through the real conductor to the device time |
| They were built from the song's own drum voices, at the song's level | The garden's hit was a kick and snare, on a beat where the bridge plays its own kick. The kick is a 110 Hz sine falling to 50 Hz, which a phone can't play. The gulps were 160 Hz sines falling to 72 Hz | Own patches on their own louder bus, each with energy a phone can play. Levels are computed, not yet heard |
| A last level's score never got its cue | `finish()` was handed the bare success score | Mixed in, as for a handoff |
| A cue within a quarter beat of a score's end would crash the win | `MusicScore` refuses a note that runs past its end | Clipped |
| A stalled frame over the contact drops the hit | The transport never plays a note late, and a browser without WebGL can stall for a second | The exit queues .6 s ahead instead of .3 s. A longer stall still drops it |
| On a last level, a close-up past the end of the success score never closes | The beat clock stops with the music. The score is 8 beats on the lawn | A test on shipped levels fails if `closeupTo`, `titleUntil` or a cue runs past the music. **A lawn shot must fit in 8 beats** |

## Proposed format

A shot list is data, like a room or a level, so a new transition is a file and some compute:

```json
{ "id": "fist-bump", "beats": 8, "bridgeFrom": "garden", "reducedMotionHold": true,
  "shots": [
    { "name": "wide-nod", "at": 0, "layer": "world" },
    { "name": "approach", "at": 3, "layer": "closeup", "plate": "closeup/garden-night",
      "actors": [
        { "art": "fist-gatekeeper", "enter": "right", "contact": [0.52, 0.48] },
        { "art": "fist-macron", "enter": "left", "contact": [0.48, 0.52] } ] },
    { "name": "contact", "at": 4, "cue": "percussion.bump", "frame": "impact" },
    { "name": "back-to-wide", "at": 5, "layer": "world" } ] }
```

Field names are a sketch. The test of the format is that the fist bump, the gulp and the finale's high five all fit it
with no new code.

## Storyboards

Beats are provisional. Each sits inside the existing 16 success-plus-bridge beats.

**Fist bump, garden to bar (owner's ruling: extreme close-up).**

| Beats | Shot | Sound |
|---|---|---|
| 0-3 | Wide: he nods, touches his brim, Mācron trots up to him | Success groove |
| 3-4 | Cut on a beat to close-up: his big fist in from the right, Mācron's small steel fist from the lower left. Forearms run offscreen | Short pickup |
| 4 | **Contact on the downbeat of bar two**, one impact frame, one or two small dust motes, no glint | Percussion hit |
| 4-5 | Fists hold, recoil a little | Hit decays |
| 5-8 | Back to wide, already live: rope lifts, guests part | Groove returns |
| Bridge 0-8 | Mācron walks to the copper door | Next room's sound leads the door |

Art needed: two fists times three drawings (approach, impact, recoil) and one plate. Earlier probes found that drawing
the two fists separately beats a single image, which clasped hands and grew Mācron.

**Oil gulp, bar to the next room.** Same treatment over the existing 6.5-beat outro. Probes showed 2 of 2 read as sipping
with no mouth invented, when the glass sits at the screen's edge.

| Beats | Shot | Sound |
|---|---|---|
| 0-2 | Wide: nod, the pour starts | Pour |
| 2-3 | Close-up on the counter: the glass slides in from the right and stops | Slide, clink on the beat |
| 3-5 | Close-up: Mācron's hand takes it, tilts it, the oil level drops, his eye lights flare | Gulp on beats 3 and 4 |
| 5-6.5 | Wide: he plants the glass, proud step, exit | Bar sting |

**Lawn reveal, into the pool garden.** No close-up. A terrace door opens and the camera shows the full lawn, with the
two dancers already mid-move and ignoring him. Mācron walks up the diagonal until they close the path. The reveal is the
first time the player sees the angled view, so it needs a held wide moment.

**High five, the finale.** `plan/storyboard.md` shots E01-E05 are already a shot list. Convert them last, as the format's
proof.

**Opening.** Not designed. The owner mentioned an intro, and the game goes from its start button straight to a walk.
It needs a story decision first: what Mācron wants, and whether the player learns it before the gate.

## What it needs

| Need | Status |
|---|---|
| Shot layer and player in the scene | Not built. About one small module, driven by transport beat |
| Close-up art route | Probes exist for fists and gulp at full-figure framing. Not yet tried as a large close-up |
| Close-up plates | One per room, from the room's palette. Not started |
| One-shot sound cues on their own bus | Not built. `lib/music/web_audio_backend.dart` to be extended |
| Style guide section for close-ups | Not written; depends on the first pilot |

## Oil gulp redraw: what the wiring taught, 2026-11-06

The owner asked for the gulp to leave a repeatable route for later moments.

- **Sub-second moments use `frames`.** An actor can list `{beat, image}` drawings, which replace approach and impact, with `impact` as the one still under calm camera. Put a frame on each sound accent.
- **Qwen can't drive a chain of moments here.** From a key frame plus a layout it kept the robot consistent, which is good, but clung to the key's glass: tilt and oil barely changed, and it left stray shapes.
- **So puppet it.** `art_runs/oil-gulp-v2-20261106/scripts/puppet.py` cuts head, torso and arm from one clean Qwen drawing, and draws the glass and oil by code, so nothing flickers and the oil's volume falls exactly. Snap to one pixel grid by majority colour, then tidy the edge teeth, or rotated parts look fuzzy. The arm goes behind the glass and only the mitten in front, or it hides what the shot is about.
- **A body needs somewhere to end.** A close-up with a torso shows a cut edge, so a foreground actor (the counter) covers it.
- **The close-up's view is 180 units wide,** not screen pixels. Check `scale` against that.
- **Pitfall:** the first guide drew almost no oil at the start, because the glass tilts before the oil reaches the rim. Set the fill by volume, not by a y value.
- **LoRA:** the 2511 Lightning LoRA drew crisper pixels than 2509 on the same seeds, in 2 seeds each, judged by eye.

`tool/art/closeups/pack_oil_gulp.py` describes the old pieces and no longer matches. Nothing has played this in a browser yet.

## Lawn kiss: what the wiring taught, 2026-11-06

The owner: "the two girls giving Mācron a kiss on each cheek at the same time, we see Mācrons big round eyes turn to smiling arcs and a small blush." The dancers are adults, and this stays warm: a friendly peck on a little robot's cheeks, with heads, collars and shoulders only in frame.

Beats, inside the 8-beat success score: to the sides by 1.5, Mācron dancing between the two until 3, a quick reach from 2.75, close-up from 3.5, contact and QUÉ FINO on 4.5, eyes to arcs by 5, blush growing to 5.5, back to wide at 7.75. Nothing names a next room, so a bridge can be added to the campaign without touching the shot.

- **Puppet again, with less cutting.** Mācron is one drawing with code-drawn eyes and blush, so only those change. A test holds every pixel outside the face and cheeks equal between his frames.
- **Qwen could hold this one.** From the kiss drawing as its only reference, it changed eye and mouth to a smile and left the head within a few pixels, measured by the outline, so the swap should barely show. Nobody has seen it moving. It held for one change, not for a chain. The 2511 LoRA and `$node:30.lora_name` worked as noted.
- **A whole close-up can mirror.** Each dancer keeps the side she won on, so nobody crosses to reach the shot. The art is drawn with swing-a on the left, and the scene flips the actors about the contact point when she won on the right. This only works because Mācron's face is near symmetrical and there is no text in the art.
- **A plate and a foreground from the room's own painting** cost no GPU and keep the palette: the pavilion crop behind, the hedge in front. The hedge hides where his body ends. A body that ran below it showed a stray cream block, so the drawing stops above the hedge's bottom edge.
- **New fields.** `heroWaitFrame`, what he shows between his dance and the cut, since `rear_idle` means facing a challenger; and `dust: false`, because a kiss doesn't throw dust.
- **`titleUntil` is the later of the close-up's end and contact + 3 beats.** Here that is the close-up's end.

Nothing here has played moving, or with sound, in a browser.
