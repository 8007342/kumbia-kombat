# Two dancers: what the swing duet needs

**Draft, 2026-11-05.** The owner ruled that the pool garden's two women are fast swing dancers who dance with each other:
combinations, switching places, tempo, complexity and adornments. They move toward and away from the viewer, and their
size must follow the background's perspective. Vocabulary research: `plan/research/swing-duet-research-2026-11-05.md`.

## What already works

| Capability | Evidence |
|---|---|
| Size follows depth, on any path angle | Height comes from foot position alone: `PartyFloorPlane.standingHeightAt`, used by `_adultHeight` in `garden_scene.dart` |
| Nearer figures draw in front | World draws sort by projected foot y, so swapping places orders itself. Tied feet need a rule |
| Beat-driven clips and adornments for one dancer | `lib/gameplay/dance_grammar.dart` |
| Any note time | Notes are in milliseconds and score files at 480 ticks per beat, so swung timing fits both formats |

Scale from `levels/pool-garden.json`, in pixels of an 844-tall screen before viewport fit, as an estimate:

| Foot y | 0.40 | 0.45 | 0.50 | 0.55 | 0.60 |
|---|---|---|---|---|---|
| Adult height | 107 | 129 | 151 | 173 | 195 |

Their current mark is y 0.50. Mācron's home is y 0.645 and the tap band starts at 0.65, so a dance moving between about
0.42 and 0.58 changes size by about 60%. That range is striking, and the room allows it.

## As built, 2026-11-06

The owner's ninth round settled the mechanic: one dancer has each turn, and the other steps slowly at the side. `stage.duet` in the level file holds it, and `lib/gameplay/duet_staging.dart` reads it. The table below and "Proposed mechanic" are the earlier thinking, and where they disagree this section wins.

- A turn names its lead, where the call is shown, where the lead dances with Mācron during the answer, and where the lead ends. The next turn starts from there, so nobody jumps and a loop closes by itself. The parser refuses a repeated lead, a repeated end mark, a mark on the tap band or past a phone's edge.
- The other dancer's slow steps are data too. Two turns in six cross to the other side, upstage of everyone, while the lead is on the way to the side that dancer is leaving.
- The sampler's yield still drives the move from call to partner mark, so a spin that overflows the call finishes mid-floor before anyone steps away. Floor positions come from the music beat and the turn. The session never reads them.
- Turns count calls on the beat grid, so a retry moves on to the next dancer too. The owner may prefer the same dancer showing it again.
- `floorTrack` still works in the parser, but the lawn no longer uses it.
- Art route: `art_runs/duet-20261106/`, words only, on the 2511 LoRA. "Hand on the back" first came out as a hand on the hip. It took naming the arm's side as the model draws it and saying the forearm and hand are hidden behind the waist. The other hand's folds are two drawings and their flips, four frames each, and walking uses the existing clips.

## What's missing

| Gap | Evidence | Plan |
|---|---|---|
| Only one challenger draws | `garden_scene.dart`: "the scene draws the first for now" | Draw all, each with its own pose |
| No floor pattern | A challenger moves only along one line, `floorAt(yield)` | A per-move floor track for each dancer, in floor coordinates, in beats |
| Grammar has one body | `dance_grammar.dart` picks clips for a single dancer | A duet move has two roles, with clips, a floor track and a connection |
| Connected hands | Nothing records where a hand is | Wrist positions already exist in each pose's skeleton. Carry them through as anchors and fix the pair's spacing from them |
| Pixel crawl in depth | Confirmed in simulation, see below | Sharp bilinear scaling, for sprites that move in depth |
| Blocky when near | The draft room showed mixed pixel sizes already | Draw at the nearest size used, and set the rule in the style guide |
| Rotation | Sprites have fixed views, and spinning needs views around the circle | Lean on front, rear, side and three-quarter views; research will flag moves to avoid |
| Tempo range | Five tiers per score are required, and existing ones step 3% (100 to 112). Tempo changes at tier boundaries | Higher values fit the format, but a much wider spread is untested. Half-time and double-time dance can vary apparent speed with the song held |
| Swing in the music | `tool/music/generate.mjs` makes straight cumbia and has no swing setting | Add swing feel, per score, varying with tempo as the research says |
| Chart rhythm | All charts share one offset list, and tiers change limbs not rhythm (`plan/foundations-2026-11-05.md`) | The chart grammar becomes urgent: this level is the case for it |
| Reading speed | At 180 BPM a beat is 333 ms, and a 2-beat cue lead falls to 667 ms from 1200 ms at 100 BPM. The ±180 ms "good" window is wider than half a beat | Set limits in chart rules, including same-limb spacing. Test on a phone |
| Atlas memory | About 137 MiB loads at startup now. Two detailed dancers add a lot | Load per level. Scope needed |

## Pixel crawl test

Simulation in PIL with one still Bartender frame, foot y 0.42 to 0.58, on a 3x phone: `tool/art/rooms/depth_scale_probe.py`,
strip in `art_runs/level3-probes-20261105/sheets/depth-scale-filters.png`. This isn't the game's renderer or a real
phone, and there is no pose change or sideways motion yet.

The frame is 234 art pixels tall, so one art pixel covers only 1.48 to 2.39 device pixels at 3x, and 0.49 to 0.80 at 1x.
Nearest-neighbour therefore gives uneven pixel widths that change every frame.

| Filter | Change between frames, 3x | Look |
|---|---|---|
| Nearest, as the game draws now | 0.070 | Mouth and eyes change shape frame to frame |
| Scale in steps | Not measured the same way | Holds, then visibly jumps |
| Bilinear | 0.077 | Steady to the eye, but soft |
| **Sharp bilinear: 4x nearest, then bilinear down** | **0.029** | Steady and crisp |

**Real renderer, same day.** `tool/probes/depth_probe_main.dart` draws the three filters in Flutter's CanvasKit, in a
headless window emulating a Galaxy S24 at 3x (software WebGL). Four consecutive 60 fps positions are in
`art_runs/level3-probes-20261105/sheets/depth-scale-real-renderer.png`, top to bottom nearest, bilinear, sharp. It agrees by eye:
nearest's mouth and eyes change shape, bilinear is steady and soft, sharp is steady and crisp. The probe prescales one frame
at runtime. Still untested: a real phone, changing poses, sideways motion, and the shader version.

The number is the frame-to-frame change in error against a stable reference, a proxy for crawl. At 1x all filters
score about the same, though nearest drops detail. Prescaling a whole atlas 4x costs 16x the memory, so the real
version should be a small shader or a prescale of the depth dancers only. Next proof: a real phone, with a dance clip.

## Findings from the swing research

Source: `plan/research/swing-duet-research-2026-11-05.md`. **Weakly sourced**: most page fetches failed, so it rests on search
excerpts and memory, and no footage was watched. Floor patterns and poses need review by a swing teacher.

- **Style:** Savoy-style Lindy Hop, with its Charleston family as the main vocabulary and solo jazz for breaks.
- **First moves:** swing out, side pass, She Goes He Goes, hand-to-hand Charleston, tandem Charleston, side-by-side
  Charleston, sugar push, send out into a breakaway.
- **Avoid:** aerials, waist wraps, cuddles, dips, sustained spins and high kicks seen from the low camera.
- **Two-person sprites:** the swing out's closed middle counts probably need one joined drawing. Earlier probes found
  that one-image pairs distort people, so this needs a probe of its own.
- **Tempo:** proposed ladder 150, 160, 170, 185, 200 BPM, untested on a phone.
- **Density:** dancers simplify footwork as tempo rises, so tap density should peak at tier 3, with tier 4 fastest and sparser.
- **6-count moves don't fit 8-beat calls.** In 32 beats, 6s and 8s only fill as four 8s, or four 6s plus one 8.
- **Don't grade swing feel:** at 200 BPM swung and straight offbeats differ by about 50 ms, inside the ±180 ms window.
- **Naming:** `dance_grammar.dart` has accents, while `adornments` in score files are the player's flourishes, and one
  is called `shine`. Dancers need their own word, and their big kicks mustn't read as foot calls.
- **Don't state as history:** women partnering at the Savoy in the 1930s. Nothing was found for it.
- **For the owner:** who the women are to each other, their casting given the dance's Black origins, and a swing reviewer,
  ideally a Black swing dancer.

## Compute estimate

An example: 16 moves × 4 key poses × 2 dancers = 128 poses. At the measured 92 s per pose (4 candidates) that's about 3.3
hours of GPU, plus review. The GPU is the small part. Choosing frames by eye is the bigger cost, so scoring needs to
narrow the candidates.

## Proposed mechanic

The earlier draft had the two trade phrases, with the risk that players can't see whose turn it is. A duet is simpler to
read: **they dance a phrase together, and Mācron answers it**. They separate only at breaks, where each shows a solo
variation at the highest tiers. The owner decides, after seeing a moving test.

## Order of proof

1. Motion test: done for one still frame, in simulation and in the real renderer. Repeat on a phone with a clip.
2. Two sprites with a held-hand anchor and a place swap, in the draft room. Existing art.
3. One real move, a pair of poses for each dancer, run through the character route.
4. Only then, the full vocabulary.
