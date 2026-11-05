# Two dancers: what the swing duet needs

**Draft, 2026-11-05.** The owner ruled that the pool garden's two women are fast swing dancers who dance with each other:
combinations, switching places, tempo, complexity and adornments. They move toward and away from the viewer, and their
size must follow the background's perspective. Vocabulary research: `plan/research/swing-duet-research-2026-11-05.md`,
in progress.

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

## What's missing

| Gap | Evidence | Plan |
|---|---|---|
| Only one challenger draws | `garden_scene.dart`: "the scene draws the first for now" | Draw all, each with its own pose |
| No floor pattern | A challenger moves only along one line, `floorAt(yield)` | A per-move floor track for each dancer, in floor coordinates, in beats |
| Grammar has one body | `dance_grammar.dart` picks clips for a single dancer | A duet move has two roles, with clips, a floor track and a connection |
| Connected hands | Nothing records where a hand is | Wrist positions already exist in each pose's skeleton. Carry them through as anchors and fix the pair's spacing from them |
| Pixel crawl in depth | Sprites draw nearest-neighbour at any fractional scale, and these two would change scale constantly | **Test first, needs no new art.** If it crawls, snap scale to steps or render at fixed sizes |
| Blocky when near | The draft room showed mixed pixel sizes already | Draw at the nearest size used, and set the rule in the style guide |
| Rotation | Sprites have fixed views, and spinning needs views around the circle | Lean on front, rear, side and three-quarter views; research will flag moves to avoid |
| Tempo range | Five tiers per score are required, and existing ones step 3% (100 to 112). Tempo changes at tier boundaries | Higher values fit the format, but a much wider spread is untested. Half-time and double-time dance can vary apparent speed with the song held |
| Swing in the music | `tool/music/generate.mjs` makes straight cumbia and has no swing setting | Add swing feel, per score, varying with tempo as the research says |
| Chart rhythm | All charts share one offset list, and tiers change limbs not rhythm (`plan/foundations-2026-11-05.md`) | The chart grammar becomes urgent: this level is the case for it |
| Reading speed | At 180 BPM a beat is 333 ms, and a 2-beat cue lead falls to 667 ms from 1200 ms at 100 BPM. The ±180 ms "good" window is wider than half a beat | Set limits in chart rules, including same-limb spacing. Test on a phone |
| Atlas memory | About 137 MiB loads at startup now. Two detailed dancers add a lot | Load per level. Scope needed |

## Compute estimate

An example: 16 moves × 4 key poses × 2 dancers = 128 poses. At the measured 92 s per pose (4 candidates) that's about 3.3
hours of GPU, plus review. The GPU is the small part. Choosing frames by eye is the bigger cost, so scoring needs to
narrow the candidates.

## Proposed mechanic

The earlier draft had the two trade phrases, with the risk that players can't see whose turn it is. A duet is simpler to
read: **they dance a phrase together, and Mācron answers it**. They separate only at breaks, where each shows a solo
variation at the highest tiers. The owner decides, after seeing a moving test.

## Order of proof

1. Motion test: an existing sprite on a floor track between y 0.42 and 0.58, to check for pixel crawl. No GPU.
2. Two sprites with a held-hand anchor and a place swap, in the draft room. Existing art.
3. One real move, a pair of poses for each dancer, run through the character route.
4. Only then, the full vocabulary.
