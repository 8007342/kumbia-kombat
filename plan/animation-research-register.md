# Animation research register

This file keeps reusable references and records what they support for Kumbia
Kombat. The cited research informs our choices; it does not prescribe our
exact frame counts, beat durations, or crowd thresholds. Game canon remains in
`openspec/specs/art-direction/spec.md` and `assets/art/STYLEGUIDE.md`.

## Mācron animation progression and current gap

The Git history shows three useful steps, all on 2026-10-28:

1. `a5766a1` introduced the first generated Mācron dance sheet and prompt
   provenance. It gave the team a consistent identity source, but not a measured
   production atlas.
2. `47f7443` replaced rectangle-rendered people with raster sprite atlases,
   measured frame records, grounded anchors, and selected walk, turn, groove,
   limb, and spin poses. This made Mācron feel expressive because player
   actions had authored pose vocabulary and the flourish renderer sampled a
   sequence of turn views on the music beat.
3. `61f8611` added an opponent choreography model that reads the active chart,
   anticipating each note and selecting the correct limb accent, follow-through,
   settle, finish, invitation, and watch states at authored beats.

The opponent logic is chart-based rather than random. The visual gap is that
each opponent semantic tag currently maps to one source rectangle. The call
model switches among those sparse isolated drawings; the atlas does not yet
provide frame sequences within anticipation, accent, follow-through, or walk.
That discrete presentation explains the “random poses jumping” impression even
when limb IDs and event beats are correct. Mācron also has more frequent
beat-sampled pose changes for groove and spin, and his flourish is a dedicated
multi-view sequence. Opponents need the same phase vocabulary, authored
breakdowns, grounded support, and view-transition care. Research must guide
those new drawings; random interpolation cannot supply them.

`BattleStaging` contains room marks and beat-sampled route calculations, but
the current `GardenSceneGame` renderer does not consume those routes. It shifts
the challenger floor from a yield value and uses no matching opponent gait
frames, so visible floor travel can read as sliding. The new `opponent-performance`
change specifies the missing locomotion and mark-ownership contract.

## Core principles and project application

| Source | Finding used here | Kumbia Kombat application | Limit |
|---|---|---|---|
| [Disney Animation: Animation process](https://www.disneyanimation.com/process/animation/) | Performance is shaped by timing, staging, anticipation, follow-through, and secondary action. | Give opponent actions clear preparation, readable accents, follow-through, and delayed character-specific details; stage each dancer so the active move reads. | General production guidance; it does not set game-specific frame counts or musical timing. |
| [Mariel Cartwright, GDC 2014: Fluid and Powerful Animation within Frame Restrictions](https://media.gdcvault.com/GDC2014/Presentations/Cartwright_Muriel_Animation_Bootcamp_Fluid.pdf) | Strong silhouettes, favored key poses, anticipation, follow-through/overshoot, selective smears, and responsiveness support animation under frame limits. | Author the planted support, weight shift, peak pose, recovery and settle. Use smears only on fast arcs and never on the support foot or cue silhouette. Keep input response immediate. | The talk concerns action-game animation. Transfer its animation technique, not combat content or numeric durations. |
| [Thomas Vasseur, Dead Cells art pipeline](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-) | Validate strong pose keys and timing before investing in supporting frames; fast iteration matters in a 2D game-asset pipeline. | Review small pose sequences at actual game size and tempo before bulk frame generation; retain editable sources and PNG exports. | The source describes one studio's 3D-to-2D workflow, not a requirement to use 3D here. |
| [Clifford Roche and Carlos Torres-Cros, Ubisoft, GDC 2016: Fitting the World — A Biomechanical Approach to Foot IK](https://gdcvault.com/play/1023009/Fitting-the-World-A-Biomechanical) | Predictive foot placement can preserve fluid motion and ground contact better than purely reactive correction. | Treat support-foot continuity as an authored locomotion invariant; use explicit planted steps and root paths before considering procedural foot correction. | 3D foot-IK research; our 2D sprite pipeline should draw contact poses rather than claim to implement their solver. |

## Characterful game systems and crowd pacing

| Source | Finding used here | Kumbia Kombat application | Limit |
|---|---|---|---|
| [Michael Booth, Valve: The AI Systems of Left 4 Dead](https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf) | The AI Director uses build, sustain, and relax phases to pace group intensity. | Vary when and how many guests react; soften the room after repeated failed phrases and let earned excitement recover through successful play. | This is adaptive encounter pacing, not a sprite-animation guide or a model of real partygoer psychology. Do not transfer zombie AI or its thresholds. |
| [Craig Reynolds: Steering Behaviors for Autonomous Characters](https://www.red3d.com/cwr/steer/gdc99/) | Separates action selection from steering/locomotion. | Keep gameplay's earned interest, a guest's selected social action, the beat-sampled route, and sprite pose as distinct responsibilities. | Used by analogy for a small authored audience; no crowd pathfinding or physics is needed. |
| [Simogo: Beat Sneak Bandit retrospective](https://simogo.com/work/beat-sneak-bandit/) | Music and action timing are designed together. | The audio transport owns cue accents, choreography, stage handoffs, and transitions; follow-through never delays input. | Development account, not a universal timing prescription. |

## Production and asset references

- [Aseprite sprite sheet, tags, and export docs](https://www.aseprite.org/docs/sprite-sheet/): retain editable tagged animation sources and explicit exports.
- [Flame image/animation docs](https://docs.flame-engine.org/latest/flame/rendering/images.html): runtime sprite loading reference; check the resolved project version before API changes.
- [PBRT projective camera models](https://www.pbr-book.org/4ed/Cameras_and_Film/Projective_Camera_Models): conceptual grounding for one consistent projection; our measured painted floor planes remain art-directed approximations.
- Existing applied research: [party animation audit](party-overhaul-research.md), [dance-battle choreography](dance-battle-choreography.md), [dance fluidity](dance-fluidity-pass.md), [opponent depth staging](opponent-depth-staging-pass.md), and [crowd animation system](crowd-animation-system.md).

## Shared opponent clip vocabulary

Each authored action should identify its cue-in/attention state, preparation,
weight-bearing contact, accent, follow-through, return/recovery, and settle.
Travel clips additionally identify turn-in, start step, alternating gait,
arrival/deceleration, and turn-out. Watch, challenge, approval and reassurance
are separate social clips rather than accidental by-products of dance poses.

Every brief records character and costume identity, room and style, facing,
support/contact foot, ground anchor, cell bounds, event beats, loop semantics,
secondary-motion limit, and what must remain unobscured. Rhythm chart data owns
required limbs and accent times; art authors the movement connecting them.

## Research-to-art workflow

1. Read this register and current canon; write a chart-backed clip brief.
2. Draw or prepare a pose/control image for every required key. Keep source
   identity references and pose controls separate in provenance.
3. Generate a small set of key poses with the cloud image service or local
   ComfyUI when available. Preserve each raw output and its prompt/run record.
4. Clean, align, measure, grid-restore, palette-check, and pack frames without
   concealing failures through silent interpolation.
5. Review the timed sequence at native sprite size over its actual room and on
   a phone. Promote only after support, continuity, identity, cue readability,
   and beat markers pass review.

The current Gatekeeper cloud sheet in `assets/art/pipeline/candidates/` is a
pose exploration candidate, not a timed walk or production dance cycle.
