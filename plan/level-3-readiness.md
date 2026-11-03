# Level 3 readiness: Cool crowd / Flow

Status 2026-11-03: inventory only. **Level 3 is not being authored yet.** Levels 1 and 2
come first; this records what the pipelines must offer when the owner writes the prompt.
Sources: `plan/storyboard.md` C01 and C.reset, `plan/assets.md` Session B,
`plan/asset-inventory-contract.md`, `lib/gameplay/rooms.dart`,
`assets/music/manifest.json`, `plan/play-and-transition-overhaul.md`.

## What exists

| Item | State |
|---|---|
| Fight rules | `FightDefinition('cool-crowd', 'Flow', 95, 2, 3, 4)` in `progression.dart` |
| Crowd budget | `CrowdStageProfile('cool-crowd', 8, 7, 5, 3)`: 8 interested, 7 following, 5 standing, 3 cheering of 12 |
| Exit route | `RoomDeparture`: front acknowledgment, turn rear, walk through "opened dance circle and corridor" to `crowd_to_restroom` |
| Bar exit route | `RoomDeparture` for `bar` targets `cool-crowd` via `bar_to_crowd`, threshold "counter-end passage" |
| Floor plane | `party_layout.dart`: marked "future art contracts, not calibrated", with `guests: []` |
| Music | `crowd_duende` "Velvet Current" (32 bars, 108→120 BPM, Dorian), `crowd_duende_success`, `bar_to_crowd` (2 bars, 108 BPM), `crowd_to_restroom` |
| Music quality | Fails the new gates: 91.4% repeating pitched bars and 83.3% melody bars, tier 3 density step just short (`plan/research/score-gates-baseline-2026-11-03.md` on `work/1834-scor`) |
| Story | C01 storyboard row and `C.reset`; art-direction spec row 3 |

## What is missing, per pipeline

### Runtime

- `partyRooms` has two entries, so a third room cannot load.
- `_beginExit` in `garden_page.dart` hard-codes the `garden_to_bar` bridge.
- `FightChart` has only `garden` and `bar`.
- No formation concept; guests are placed individually.
- `cam.side` strips and alternating full-phrase side camera are not implemented.
- Tasks 2.1–2.3 of `level-production-pipeline` cover the first three.

### Character pipeline

- **Lead dancer:** no definition. Needs a new tall, lean body preset (the library has
  `stocky-adult`, `slim-adult`, `macron`) and an open `dramatic-jacket` garment with hem lag
  (`secondaryMotion` now exists). A jacket sweep is a new pose.
- **Motion:** `opponent-64` works as a base. Needs a jacket-sweep invite, a "mirrors
  Mācron's signature step" clip and accented alternation of arm and foot.
- **Art direction tension:** the spec says "dramatic jacket" and "disco reflections",
  while the owner's ambience is cotton guayaberas. Needs an owner call (see below).

### The multi-dancer semicircle: what it asks of the rig

C01 has three dancer silhouettes in a closed semicircle, which opens into a corridor, plus
a crowd mirroring the robot at full tier. Today the rig renders one figure on a 768×960 canvas.

| Need | Today | Required |
|---|---|---|
| Several figures on stage | One per canvas; the game places each by floor anchor | Keep separate atlases, and add formation files with floor marks and depth order |
| Views around an arc | `VIEW_YAW` has 8 views, but `check_poses` caps body yaw at 35° outside turn clips | Per-figure base yaw up to ±35°, through a motion-set view parameter; review whether arcs need more |
| Reuse | 3 silhouettes × 4 wardrobes in the plan | Audience characters with shared motion; 4 dance frames per silhouette, 12 + 2 per the inventory |
| Group rhythm | Crowd bounces on beats | Phase offsets per member, so they share a groove with variations, not unison |
| Open and closed | Not represented | Two formation states plus short side-step clips between them, on a musical boundary |
| Mirroring | No cross-character motion | A lead clip of Mācron's signature step, authored by hand in `opponent-64` terms, because his rig is non-human and auto-retargeting would not carry over |
| Readability | Single-figure silhouette check | Composed group check at native size: challenger stands out, cue origin stays clear, nobody resembles Covi |
| Reduced motion | Per-sequence rule | Fixed open and closed formations with no bounce |

Mācron's "signature step" is mentioned repeatedly (storyboard C01, art-direction row 3, music
overhaul) but I found **no definition of it**. It must exist before level 3's outro.

### Room art pipeline

Background, 4 layers plus emissive mask (violet, cyan, cream), disco reflection motion,
side strip, circle threshold strip, and floor calibration. Nothing exists. A bar proof comes first.

### Score pipeline

A new brief for `crowd_duende`, with its success phrase and both bridges rebuilt. Character
influence and hints come from the prompt. Any new voices go through the existing recipe path.

### Shot pipeline

| Sequence | Beats (draft) | Needs |
|---|---|---|
| `bar.outro`, then the `bar_to_crowd` walk | 6.5, then 8 | In design already. The 2-bar bridge is about 4.4 s at 108 BPM. Needs Mācron's side-right walk and the counter-end threshold strip |
| Arrival at crowd | Up to 2 | Rear establishing view of the closed semicircle; restores stable framing before cues |
| Jacket-sweep invitation | 2 | Medium shot of the lead dancer |
| `crowd.outro` | 8 | Circle opens, lead repeats the signature step, closeup nod for 2 beats, rear walk to the restroom pictogram |
| `C.reset` | 2 | Crowd closes and robot shuffles outside, welcoming |

### Chart

The `LF LH RF RH` opening, with rests and syncopation at higher tiers and an optional
`LF→RH` slide. Needs data form, validator and playtesting. The storyboard's budget is 95 s.

## Gaps ranked by effort (rough and relative, no measurements yet)

1. **Small:** score brief rebuild; chart data; `C.reset`, arrival and invitation shots.
2. **Medium:** lead dancer definition, body preset, jacket garment and new poses; `crowd.outro`.
3. **Medium:** runtime level registry (needed for levels 1–2 cleanliness anyway).
4. **Large:** room layers and calibration, since the pipeline is new and must be proven on the bar first.
5. **Large:** formations, open/closed movement, group rhythm and composed checks.

## Decisions the owner will need to make for level 3

1. Is the lead dancer's jacket worn over a guayabera, or does the ambience replace it?
2. What is Mācron's signature step? It should be established by levels 1–2, so it is due sooner than level 3.
3. Should "disco reflections" stay as the room's motif?
4. How many dancers are visible: three as in the storyboard, or more using the 12-guest budget?

## Draft prompt template (for the owner to rewrite)

> **DRAFT, not approved. Written only to show the shape of a prompt.**
>
> Level 3, Cool Crowd, Flow. Inside the mansion's dance room, midnight violet with cyan
> disco glints and warm cream light. A loose circle of very cool dancers in cotton
> guayaberas shuts Mācron out with a semicircle of side-eyes, until their leader, a tall
> angular dancer with a dramatic jacket, sweeps it open as an invitation.
> Music: Latin boogaloo and salsa-disco, walking bass and handclaps over clave, marimba
> call and flute answer, strings and a hint of disco four-on-the-floor arriving only at
> the top tier. Starts sly and cool, ends with the whole circle in unison. Chart stays
> `LF LH RF RH`, with syncopation and rests that become recognisable. When beaten, the
> circle opens, the leader copies Mācron's signature step and gives one slow nod. Replay
> variant: same dancers, moonlit blue and silver palette.

Expected expansion: `tool/levels/cool-crowd.json`, as in `level-production-pipeline`'s design D1.

## Future briefs, recorded only

**Level 4, Restroom / Nerve (owner, 2026-11-03):** the rush level. A chill country backdrop
beat builds into a heavy metal score, over a Latin rhythmic base so the game's identity
holds. Replaces today's `restroom_nerve` character when its time comes. Not designed further.
