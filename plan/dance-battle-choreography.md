# Dance-battle choreography

Research and executable model prepared 2026-10-28. The opponent should visibly teach the phrase, enjoy finishing it, give Mācron room to answer, and react as a fellow dancer. The model changes presentation without changing required-note timing, judgment or song duration.

## Primary research and application

- [Mariel Cartwright, GDC 2014: Fluid and Powerful Animation within Frame Restrictions](https://media.gdcvault.com/GDC2014/Presentations/Cartwright_Muriel_Animation_Bootcamp_Fluid.pdf). The animator emphasizes clear key-pose silhouettes, anticipation, follow-through and overshoot with limited frames; she distinguishes responsive player actions from actions that can telegraph in advance. Application: the opponent prepares before each known call note, while an accepted player tap receives an immediate visible response. Draw the important weight shifts instead of replacing them with a whole-image bounce. These are animation principles transferred to dance; no fighting imagery or damage reactions are implied.
- [Thomas Vasseur: Art Design Deep Dive — Using a 3D pipeline for 2D animation in Dead Cells](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-). Vasseur describes validating strong poses and their timing before adding supporting frames, with exported PNG frames and quick timing revisions. Application: approve a small sequence at its actual in-game size and musical tempo before expanding the sheet. Keep contact accents fixed while adjusting preparation and settling. A 3D production pipeline is not required for this project.
- [Simogo: Beat Sneak Bandit development retrospective](https://simogo.com/work/beat-sneak-bandit/). The developers describe deriving gameplay and animation time from sound and using follow-through after immediate actions to maintain responsiveness. Application: source beats remain authoritative through demonstrations, player replies and transitions. Additional artistic holds never delay accepted input or extend the phrase.
- [Rhythm Doctor developers: Using medical stories and heart conditions to create musical challenges](https://www.gamedeveloper.com/design/using-medical-stories-and-heart-conditions-to-create-musical-challenges-in-rhythm-doctor). The creators explain giving different rhythmic ideas distinct visual behavior and developing musical mechanics together with the song's intensity. Application: demonstrate the actual active chart, distinguish accents from preparatory movements, and teach new coordination patterns through an audible and visible call before requiring the response. More frantic animation is not, by itself, more musical complexity.

The following timings and composition are project design choices informed by those sources, not externally established dance rules or measured comfort thresholds.

## First opponent atlas

The first Garden and Bar sheets share twenty semantic pose tags. A nominal five-column/four-row prompt is only an art-production aid. Runtime rectangles, ground anchors and scale must be measured after inspection; never infer them from equal slices.

| Purpose | Required tags | Readability requirement |
|---|---|---|
| Personality and preparation | `occupied`, `ready`, `turn_in`, `turn_out` | A recognizable task/relaxed stance, then attention toward Mācron and the dance space. |
| Anticipation | `anticipate_left`, `anticipate_right` | Hips settle over a planted support foot; arms prepare without looking like the final accent. |
| Required accents | `left_hand`, `right_hand`, `left_foot`, `right_foot` | Anatomical left/right remain correct; hand gestures and foot steps are unmistakable at small size. |
| Momentum and recovery | `follow_left`, `follow_right`, `settle` | A small purposeful overshoot, then return to a balanced stance. Head, shirt and arms need not settle simultaneously. |
| Finish and invitation | `finish`, `cede`, `invite` | A proud final pose, a short sidestep, then an open palm that visibly offers the floor. |
| Attentive response | `watch_left`, `watch_right` | Quiet supportive groove; no competing demonstration while Mācron answers. |
| Feedback | `approve`, `recover` | Warm approval or a playful invitation to try again; no aggression or humiliation. |

Reuse the existing character reference for face, costume, materials and proportions. Preserve foot ground lines, hat shape and hand identity across cells. Avoid baked shadows, ground, text, aura or UI. The twenty keys are a first playable set, not a claim of a polished animation production: add short supporting frames where actual playback exposes a discontinuity.

## Musical staging

`ChallengerChoreography` consumes a snapshot of `activeLimbs`, `activeOffsets` and `callBeats`; it has no tier-based animation-speed multiplier. Its `sample` method reads an absolute music beat and the stable absolute start of the current call. Repeated samples do not mutate anything, so frame skips cannot lose an animation event and a frozen transport freezes the sampled pose.

| Moment | Opponent | Mācron |
|---|---|---|
| Before the call | Occupied → turn toward floor → ready | Arrive, look at the opponent and listen. |
| Each authored call note | Short directional preparation → exact limb accent → follow-through → settle | Watch; cue identity and remaining-time display remain stable. |
| Final call note at beat 6.5 | Accent and recovery occupy the next half beat | Begin facing the offered dance space. |
| Call beats 7–8 | Finish, cede, invite; invitation begins at 7.5 | Prepare to answer; an accepted early first tap remains immediately responsive. |
| Response beats 8–16 | Watch quietly from the sideline | Required accepted moves and optional flourishes control the performance. |
| Phrase result | Brief approve or recover gesture | Finish the successful phrase or regain balance. |
| Clearance | Approve → turn out → cede → invite onward | Celebrate, then take the existing musical exit. |

The current chart's 1.5-beat rest after its final note contains the entire finish and invitation. No extra cinematic delay, new mandatory gesture or paused song is needed. The model retains a similar proportional handoff if a future chart changes its final rest.

Preparation is at most a quarter beat and shrinks for tightly spaced notes. The exact call-note beat selects the accent, followed by unequal holds for follow-through and settle. Supporting root motion is bounded to 1.1 logical art pixels for foot steps. Larger movement comes only from the separate floor-yield parameter between room-local dance and watch positions; neither controls nor cue destinations participate in that transform.

Reduced motion keeps essential limb accents and preparation while removing decorative root displacement and changing the floor position at a discrete handoff. It does not hide the demonstrated pattern.

## Player response contract

`playerMovePose` samples a successful tap using `acceptedBeat`, `targetBeat` and the current beat. An early tap immediately shows preparation and reaches its accent on the target beat. An on-time or late tap accents immediately; a late event never rewinds the song. Follow-through and settling fit before the next known required beat when possible. A newer accepted tap replaces the previous event rather than waiting for its clip to finish.

The player renderer should use this result only for actually accepted input. It must not automatically play the demonstrated limb pattern during the response. Optional style may interrupt an older move's recovery, but a newer required input takes priority. At the floor invitation, use the existing authored rear-turn/profile/front views; do not rotate or squash a flat image to fake the turn.

`outcomeBeat` must be captured once at phrase resolution. The completion event already has `completedAtBeat`; ordinary success needs an equivalent stable timestamp. Recomputing the timestamp during rendering would make approval play forever. Historical device seconds must not be reconverted after a pause reanchors the transport.

## Complexity: what this pass does and does not change

The existing five tiers change eight limb motifs, so the choreography now demonstrates those real coordination-pattern changes rather than an unrelated loop. Their timing offsets remain `[0, 1, 2, 2.5, 4, 5, 6, 6.5]` in this pass. The music's arrangement and BPM also change through the existing conductor. **This does not yet introduce increasing rhythmic density or new syncopation.**

A future authored chart pass can teach four spacious accents, then six, then eight; introduce a clearly demonstrated syncopated pattern only after the basic patterns are comfortable. More demanding final motifs should vary rhythm intentionally, preserve one-thumb reach, avoid mandatory simultaneous inputs, and leave time for the invitation and optional style. Call animation, cues and response judgment must all consume the same new offsets. Do not create fake extra limb accents merely to make a higher-tier animation look busier.

## Acceptance and next production work

The model tests verify every active Garden/Bar motif's limb accent at its exact authored beat, anticipation and recovery at half-beat spacing, an invitation before the earliest accepted response tap, frozen sampling across pause, identical note identity at different audible tempos, early/late player behavior and bounded motion. Runtime integration must additionally verify the generated atlas tags against the model and inspect actual crops for swapped hands, missing limbs and changing proportions.

Review a complete call-and-response on a portrait phone at the slowest and fastest room tempos. The opponent should read as a dancer with weight and personality, and its final invitation should make the next turn clear without requiring a text explanation. Add supporting frames to specific visible discontinuities rather than smoothing every interval equally. More ambitious hero/opponent partner routines, complete rotations and genuinely denser musical charts remain separate authored work.
