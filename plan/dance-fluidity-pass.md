# Dance fluidity and floor-exchange pass

## Decision

Make the dance battle feel fluid with **authored key poses, purposeful
breakdowns, unequal holds and music-sampled floor ownership**. Do not attempt to
hide sparse art behind global interpolation, Gaussian blur, crossfades, screen
shake or a constantly moving camera. Those treatments blur Kumbia's pixel-styled
raster art, compete with rhythm cues and cannot supply believable anatomy or
weight.

The first production slice is one Gatekeeper ↔ Mācron cinematic exchange in the
garden. It supplies a repeatable contract for later opponents, not a one-off
cutscene.

## What is true today

- `ChallengerChoreography` already samples anticipation, demonstrated accents,
  follow-through, settle, cede, invite, watching and outcome reactions from
  absolute transport beats. Accepted player moves retain priority.
- The opponent can yield laterally, but Mācron remains principally at centre and
  changes facing. There is no shared performance mark, sideline marks or actor
  route director, so the characters do not visibly exchange the dance floor.
- Mācron's 16-frame sheet and the ensemble sheets are explicitly preview art.
  The spin reverses its views, reading as a swivel rather than a continuous turn;
  limb recovery falls back to generic groove poses. The manifest already prevents
  the sheet's duplicate raised-arm drawing from swapping anatomical input identity,
  but a dedicated opposite-hand peak remains needed.
- Existing late-tap and optional-flourish allowances leave too little time at
  higher tempos for a full exit and entry inside the present 16-beat phrase. A
  performance exchange must be authored in the chart rather than squeezed into
  the response's final input window.

## Choreography contract

Use two formats, selected by the music/chart rather than renderer state.

| Format | Use | Timing |
| --- | --- | --- |
| Compact 16-beat exchange | Repeated ordinary phrases | The existing short turn/sidestep/invite only; no complete crossing or long taunt. |
| Cinematic 24-beat exchange | Introduction, motif change, selected peak phrase, room clear | 8-beat call, 4-beat handoff, 8-beat response, 4-beat outcome/return. |

The pilot uses the cinematic form. Required response cues begin only after the
incoming dancer has acquired the performance mark. The last accepted note and
its full flourish window finish before the next dancer starts a new call.

### Pilot timeline

| Beats | Gatekeeper | Mācron | Crowd / staging |
| --- | --- | --- | --- |
| 0–6.5 | Demonstrates the actual chart | Watches from the player watch mark | Quiet attention toward Gatekeeper |
| 6.5–8 | Last accent, follow-through, proud finish | Turns toward the floor | One nearby nod, no broad reaction |
| 8–9 | Playful open-hand challenge | Acknowledges | Both remain readable in one frame |
| 9–10 | Leaves on an authored side route | Prepares at ingress | Eye-lines follow the exit |
| 10–11 | Watches from opponent watch mark | Enters performance mark | Focus passes to Mācron |
| 11–12 | Quiet support pose | Ready pose | First cue has not begun |
| 12–18.5 | Watches / small encouraging nod | Accepted inputs drive the actual response | Reactions stay subordinate |
| 18.5–20 | Watches | Last note and optional flourish | Preserve full input allowance |
| 20–24 | Approves or reassures, then re-enters | Finish, recover, leave | Crowd opens/settles route |

Each room defines `performanceMark`, `playerWatchMark`, `opponentWatchMark` and
separate ingress/egress routes. The mark is exclusive: the outgoing actor releases
it only after its clearance marker; the incoming actor acquires it only afterward.
Routes are sampled from absolute musical beats with planted-foot anchors and room
projection. They are never renderer timers.

## Art direction: what to draw

At native authoring resolution, first clean body volume, feet, anchors, costume
landmarks and pixel clusters. Do not mechanically upscale/downscale preview art
and call it a final pixel grid.

### Mācron pilot inventory

1. **Six-to-eight-pose grounded groove**: alternating planted-foot extremes,
   bent-knee downs, passing positions and lifted recoveries. Hold side extremes
   longer than passing positions; preserve the face screen.
2. **Four limb-specific action chains**: preparation → clear peak → one-frame
   overshoot/follow-through → supported hand/foot return. A raised arm comes down;
   a raised foot visibly returns to contact. The opposite foot carries the body.
3. **Dedicated left-hand peak**, four recovery drawings and two balanced settles.
   The antenna may lag the head by one drawing; the torso/head volume may not slide.
4. **Eight real turn views**: front → front three-quarter → profile → rear
   three-quarter → rear → opposite rear three-quarter → opposite profile →
   opposite front three-quarter. Do not reverse the same side views to fake 360°.
5. **Social clips**: watch, small clap with visible contact, proud finish,
   reassuring catch-step after a failed phrase, ingress walk and egress walk.

### Opponent pilot inventory

Keep the demonstrated limb and support foot unmistakable. Add a four-to-six-pose
entry/exit walk, watch loop, gentle approval clap, playful challenge, mistake
reaction and recovery. Gatekeeper secondary motion is hat/shoulder settling;
Bartender uses apron/shirt settling. These details lag the main pose; they never
become cue-like competing arm/foot actions.

### Smears and overlays

Use a hand-drawn 17–33 ms smear only for a rapid hand sweep, spin crossing or
flourish. It simplifies the moving limb along its actual arc, keeps the supporting
foot and face clean, and precedes a readable clean accent. It is not Gaussian
blur, alpha ghosting, a crossfade or a permanent motion-trail effect.

Part overlays come after the pilot art proves its attachments: antenna, cuff,
hat brim, apron edge or small facial screen change can add overlap. Every overlay
needs per-pose anchor, depth order and occlusion review; sliding arms or detached
clothes are worse than a fewer-frame whole-body drawing.

## Timing rules

Sample every clip from conductor beats, never from render-frame count or an
independent animation ticker. Preserve the exact accent on the demonstrated or
accepted note. At 60 Hz, 17–33 ms is only 1–2 refreshes; it does not require 60
unique drawings per second.

Recommended starting timing for **notes that permit the space**:

| Note spacing | Preparation | Peak after note | Follow-through | Settle |
| --- | ---: | ---: | ---: | ---: |
| At least 1 beat | .25 beat | .20 beat | .25 beat | .20 beat |
| .5 beat | .125 beat | .12 beat | .14 beat | .115 beat |

The dense version ends when the next preparation begins. On an early accepted tap,
use available time toward the target; on an on-time or late accepted tap, show the
clean accent immediately and animate follow-through afterward. A new required move
always interrupts a flourish, taunt or decorative recovery.

Body-pose priority: lifecycle restore → accepted required move → accepted flourish
→ short consequence → outcome recovery → invitation/taunt → watching/idle.
Locomotion is independent: an accepted pose may change the body without cancelling
a grounded route. A large clumsy trip is phrase-level, anchored to the single
resolved outcome; a single missed note earns only a compact catch or glance.

## Implementation sequence

1. **Baseline review.** Record deterministic garden/bar call-response captures at
   native phone size and nearest-neighbour enlarged size, at every shipped tempo,
   including pause/resume, early/late taps and reduced motion. Flag foot sliding,
   anatomy swaps, mismatched anchors and cue obstruction.
2. **Add `BattleStageDirector`.** It owns musical markers, exclusive floor marks,
   actor routes, facing, gaze and interaction clips. Session/scoring retains chart
   authority; the renderer only samples the director. Start with the pilot's
   24-beat exchange behind a sequence ID; leave compact existing phrases intact.
3. **Produce the Mācron/Gatekeeper pilot art.** Update explicit manifest metadata
   with beat-relative clips, accent marker, support foot, ground pivot, optional
   attachment points and reduced-motion pose. Human-review each silhouette.
4. **Integrate bounded root/secondary offsets.** Use stage coordinates and
   authored pixel offsets. Avoid arbitrary rotation, squash, smoothing, camera
   zoom and per-frame offscreen rendering. Keep ordinary/recolored draws on the
   same placement policy.
5. **Evaluate and expand.** Only after the pilot reads at phone size, repeat for
   Bartender, then crowd stand/sit weight-bearing transitions. Add a few local
   flourish particles last, if they survive profiling and never cover cue paths.

## Acceptance gates

- A first-time viewer can name whose turn it is with HUD text hidden.
- No two actors own the performance mark; no character crosses the other or a cue
  destination.
- Identical input produces identical score/judgment with cinematics enabled or
  disabled. Earliest first taps, latest final taps and latest flourishes retain
  their current authority.
- Pausing, dropped render frames and a new accepted move cannot lose/duplicate a
  handoff or replay an expired taunt.
- Native-size review finds no foot sliding, crop-resizing, pixel shimmer, detached
  overlay or unreadable limb identity. Reduced motion retains turn ownership and
  gameplay state while removing smears, root bounce, particles and camera motion.
- Profile cold load, wardrobe preparation, repeated room transitions and the
  pilot on physical phones. The current art/wardrobe inventory is already a
  material memory load; atlas expansion needs measured budgets before multiplying
  every palette/pose.

## Research basis

- [Disney Animation process](https://www.disneyanimation.com/process/animation/):
  timing, staging, anticipation, follow-through and secondary action establish
  readable character performance.
- [Mariel Cartwright, *Fluid and Powerful Animation* (GDC)](https://media.gdcvault.com/GDC2014/Presentations/Cartwright_Muriel_Animation_Bootcamp_Fluid.pdf):
  strong keys, overshoot/follow-through, game responsiveness and selective smears.
- [SLYNYRD Pixelblog 53](https://www.slynyrd.com/blog/2024/11/25/pixelblog-53-punches-and-kicks)
  and [55](https://www.slynyrd.com/blog/2025/3/24/pixelblog-55-top-down-character-animation):
  planted pivots, limited smears, variable holds and pixel-cluster clarity.
- [Simogo on *Beat Sneak Bandit*](https://simogo.com/work/beat-sneak-bandit/):
  sound drives action timing; animate follow-through after immediate feedback.
- [Flame sprite animation](https://docs.flame-engine.org/latest/flame/rendering/images.html)
  and [Flutter filtering](https://api.flutter.dev/flutter/dart-ui/FilterQuality.html):
  retain beat sampling and nearest-neighbour art rather than smoothing texture
  samples to imitate missing drawings.

`ranitas`, `cannonball` and `demon_attack` were not available as local checkouts
in this workspace, so their runtime implementations were not claimed as evidence.
