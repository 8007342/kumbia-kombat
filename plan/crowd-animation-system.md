# Reusable crowd animation system — 2026-10-28

The crowd should look occupied before it looks interested. A guest sits, talks,
rests or takes a drink; notices Mācron; looks longer; begins keeping time; leans
forward; stands; dances or applauds; then sits and resumes their activity. Each
change has an animated physical transition. A cleared garden is a small social
success, while the final VIP peak earns the entire room's standing ovation.

## Primary research and applicable sibling work

[Walt Disney Animation's production overview](https://www.disneyanimation.com/process/animation/)
identifies timing, staging, anticipation, follow-through and secondary action
as principles for creating believable character performances. Application
here: standing needs a forward weight shift and leg extension, while sitting
needs a controlled lowering and settle. Looking, tapping and drinking should
remain smaller than the player's dance. These particular timings and budgets
are project decisions, not numeric recommendations from Disney.

[Craig Reynolds' original steering paper](https://www.red3d.com/cwr/steer/gdc99/)
separates action selection from steering and locomotion. Application by
analogy: gameplay determines earned interest, the crowd model chooses an
individual action and timing, and the renderer plays authored clips. We do
not need a physics simulation or pathfinding system for seated spectators.
Neighbor noticing is an authored social effect, not evidence about real human
crowd psychology.

The sibling [Ranitas animation guide](https://github.com/8007342/ranitas/blob/main/art/ANIMATION_STYLEGUIDE.md)
grounds shadows on the receiving surface and separates subtle idle expression
from larger action states. Its [art README](https://github.com/8007342/ranitas/blob/main/art/README.md)
keeps original generated sources, exported assets and validation separate.
Those are useful production practices: preserve the chair/floor anchor through
every pose, record exact frame geometry, retain sources and validate exports.

Crucially, Ranitas' [current visual guide](https://github.com/8007342/ranitas/blob/main/art/STYLEGUIDE.md)
explicitly gives [Quiet Awakening](https://github.com/8007342/ranitas/blob/main/docs/quiet-awakening.md)
precedence over older animation examples. That newer document favors
independently phased, source-aligned details, stable environmental anchors,
and gradual decoration without delaying direct input. We borrow that
separation, not its three-minute pond timeline or older procedural face
overlays. Kumbia's animation time comes from its audio transport and its actor
frames must remain the reviewed art, not improvised facial pixels.

## Stage budgets

Use twelve visible guests as the reusable reference cast. These are cumulative
upper bounds: a cheering guest also counts as standing, following and interested.
They remain in force after approval and during optional style effects.

| Stage | Interested | Following rhythm | Standing | Cheering |
| --- | ---: | ---: | ---: | ---: |
| Garden | 3 | 2 | 1 | 0 |
| Bar | 5 | 4 | 2 | 1 |
| Cool crowd | 8 | 7 | 5 | 3 |
| Restroom | 9 | 8 | 6 | 4 |
| VIP | 12 | 12 | 12 | 12 |

The garden therefore retains nine occupied spectators even after clearance.
Most bar patrons remain seated. Later rooms progressively earn a larger share
of the room; VIP alone can turn everyone into an enthusiastic standing guest.
Current playable garden/bar sessions use their profiles. Defining the other
profiles does not mean those three rooms have been implemented.

`earnedSupport` tracks musical readiness separately from the population's
visible participation. Existing phrase thresholds, audible tier-four checks,
sustain challenges and clearance authority stay in `GardenSession` and
`FightProgress`. Crowd animation never creates another victory requirement.
The former unconditional `cleared => everyone celebrates` rule is removed.

## Individual behavior and transitions

The model assigns each guest a stable attention rank, archetype, palette and
phase offset. Attention rank interleaves scene slots, so early interest does
not form one uniform row. Completed passing responses grow interest; individual
thresholds and the room's caps determine the destination behavior. Failed
phrases affect the nearest guest and one neighbor, with hysteresis around
state boundaries. Idle time, render calls and social reaction chains cannot
manufacture earned progress.

Reaction starts use nonidentical fractional offsets distributed over roughly
four bars for the full cast, with at most four initial notices per bar. A
guest's existing look or stand-up movement completes before a newer result
adds the next action. A setback can change the destination but cannot cut a
half-completed stand into an instant seated pose. Completed transition records
are discarded as new plans replace them; there is no unbounded event history.

The path through behavior is physically readable:

1. Seated idle alternates occupied poses slowly, with individual phase offsets.
2. Notice turns attention toward the floor, then settles into looking.
3. Seated following introduces nods and foot tapping.
4. Stand-up begins with leaning forward and transferring weight to the feet.
5. Standing idle, step-touch and clapping vary within sustained participation.
6. Cheering becomes available only to the stage's allotted supporters.
7. Withdrawal or exit plays sit-down before returning to seated activity.

Optional directional flourishes produce brief local reactions. The nearest
guest reacts first and neighbors follow with small delays. A busy seated guest
can glance up; a seated follower can nod more enthusiastically; an already
standing guest can clap. An adornment never makes a seated holdout suddenly
stand or lets the garden acquire a VIP-sized ovation.

Exit is sampled from the conductor's continuous presentation beat. Guests
settle at different times. The first two existing supporters keep responding
for another four beats, while others begin their seated return; after the
coda everyone resumes their occupied loop. This is presentation only and does
not erase earned results. A paused clock freezes the same pose. In-memory
checkpoints copy the crowd's plans and interest; durable reload remains a
separate save-system task.

## Reusable actor asset contract

The first production set uses three distinct archetype silhouettes and four
wardrobe palettes, creating twelve reusable cast identities. A palette swap
changes designated clothing colors while preserving outlines, skin, chair,
shading and highlights. Do not apply a whole-sprite tint that recolors skin or
turns the chair into a different prop. Facing, relative depth, loop phase and
activity further distinguish people sharing a silhouette. Extra archetypes
can be added later through the same clip contract.

Each archetype needs this full **24-pose sheet**:

| Runtime clip | Authored poses | Typical duration | Purpose |
| --- | --- | ---: | --- |
| `seatedIdle` | `seated_idle_a,b` | 8 beats / loop | Busy or apathetic seated baseline |
| `notice` | `notice_a,b` | 2 transition / 4 loop | Glance, look and return attention |
| `seatedFollow` | `seated_follow_a,b` | 2 beats | Nod and foot tap while seated |
| `standUp` | `stand_up_a,b,c,d` | 2 beats / once | Lean, shift weight, extend, settle |
| `standingIdle` | `standing_idle_a,b` | 2 beats / loop | Relaxed supported standing |
| `stepTouch` | `step_touch_a,b,c,d` | 2 beats / loop | Distinct weight-bearing dance steps |
| `clap` | `clap_a,b` | 2 beats / loop | Hands apart/contact with visible arms |
| `cheer` | `cheer_a,b` | 2 beats / loop | Raised-arm excited response |
| `sitDown` | `sit_down_a,b,c,d` | 2 beats / once | Bend, lower, contact chair, settle |

Each actor has one persistent separately rendered chair. Actor sheets contain
no chair: early generated sheets lost the chair in dancing poses, which exposed
why the prop must be independent. Chair feet and the floor pivot remain
stationary; the person changes height and silhouette. Standing does not move
the chair or its shadow. No baked UI or other people.
Three sheets supply 72 actual authored poses before wardrobe variants.

Every frame requires an explicit source rectangle, floor/chair pivot,
pixels-per-unit value and transparent gutters. Sheet manifests record clip
order, looping/one-shot semantics, provenance, palette regions and review
status. Do not assume a generated sheet has mathematically perfect grid cells.
Inspect and measure actual artwork; malformed or missing art must fail visibly
rather than silently substitute generic rectangles. Generated concepts are
not completed animation until this registration and visual inspection pass.

## Renderer interface

`CrowdInterestModel(rampPhrases:, profile:, guestCount: 12)` exposes
`guestCount`, `earnedSupport` and read-only `guest(index, beat, exitBeat: ...)`.
The optional exit beat marks the beginning of the musical coda on the same
continuous beat coordinate system.

Each `CrowdGuestSnapshot` supplies `state`, `interest`, `styleEnergy`,
`reactionBeat`, `noticedBy`, `clip`, `clipBeat`, `clipDurationBeats`,
`transitioning`, `standing`, `archetypeIndex`, `paletteIndex` and `phaseOffset`.
The renderer selects a clip frame from local beat divided by duration, wrapping
loops and clamping one-shot transitions to their last frame. Snapshot selection
is pure; drawing a frame never advances behavior or credits input.

Reduced motion retains meaningful seated/standing and interested/occupied
poses, with fewer pose changes and no decorative bounce. It must not freeze
everyone into the same attention state. Rooted chairs, floor shadows, layering
and safe cue space are mandatory at the nominal 180×320 composition.

## Verification and remaining review

Model tests check all five population caps before/after approval, twelve unique
archetype/palette pairs, seated-to-standing anticipation, gradual multi-bar
reactions, VIP full enthusiasm before approval, sit-down/coda behavior,
flourish ceiling protection, local losses, duplicate result handling,
checkpoint reconstruction and sampling without side effects. Real-score
AutoPlay still produces successes and setbacks and clears garden and bar
through actual judged input.

Asset import, actual frame identity, wardrobe masks, twelve-person composition,
chair grounding, reduced motion and native-size/physical-phone readability
still need separate evidence. A pure-model test does not certify animation art.
