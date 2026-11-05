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
6. **No text baked into art.** Captions stay in the UI.
7. **Glint is reserved** for the finale's high five (from `plan/storyboard.md`).

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
