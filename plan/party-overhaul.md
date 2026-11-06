# Dancing the party awake

Status: overhaul design, 2026-10-28. A first input/crowd/music behavior pass is
implemented alongside this plan; production sprite atlases and layered room art
remain undelivered. See `play-and-transition-overhaul.md` and
`session-party-pass.md` for the expanded scope and verification.
Baseline and source ledger: [research audit](party-overhaul-research.md).
Existing canon and controls remain in the art-direction and rhythm specs.

## Experience target

Mācron enters a party that barely notices him. A guest pauses mid-sip; another
looks over, catches the rhythm, and nudges a friend. Shoulders loosen, feet
start marking time, and a small circle joins the dance. By acceptance, the
space has made room for him. Every room tells a different version of that arc.

Success is readable through posture, shared attention and changing space.
The crowd has something to do before and after noticing Mācron. Apathetic
means occupied or reserved, never cruel. Required taps can earn the complete
welcome; optional flourishes add personality and localized excitement.

## Art and motion direction

Retain the nominal 180×320 portrait art viewport and independent safe-area HUD.
Compose the world on that logical grid, then scale it with nearest-neighbor
sampling. Snap rendered positions to the world pixel grid without quantizing
audio, input or simulation time. Use authored depth bands and deliberate
scale variants where needed; arbitrary fractional body scaling must pass a
pixel-consistency review. The current broad '80s' description is refined by
the owner's Symphony of the Night motion inspiration, while keeping our warm
Kumbia party and existing robot/axolotl canon.

Lock a model sheet before animation: front/rear/three-quarter/profile, height,
ground pivot, right-arm cuff, material ramps and key silhouettes. Start with
32×40 hero cells and 48×64 challenger cells from the existing inventory; prove
these can express the motions before multiplying production. Guest cells may
start at 24×40 with authored smaller distant variants. These are production
candidates, not a reason to sacrifice Mācron's tiny relative scale.

Use dark chromatic outlines, restrained cream/teal/cyan hero ramps, warmer
party accents and quieter background values. Keep controlled pixel clusters,
square pixels and clear negative space around moving limbs. Avoid painterly
microtexture, smooth rotated limbs and broad baked glows in runtime sprites.
Color swaps supplement distinct silhouettes and behavior; they cannot supply
all the guest variety. Concept paintings remain references until cleaned.

Dance needs planted feet, weight transfer, counter-rotation, a readable accent,
overshoot and a short settle. Animate the hips/torso/head as a coordinated
body; delay the antenna and loose clothing after the main movement. Shadows
stay on the floor under the root, with lift represented separately. A spin
uses authored facing frames, including the cuff changing sides appropriately,
rather than squeezing a front sprite. No combat recoil or aggressive posing.

### First production clip inventory

| Actor | Clips to prove | Initial distinct drawings |
| --- | --- | --- |
| Mācron | groove loop; LH/RH accents; LF/RF steps; turn/spin; recover; rear walk/idle | Groove 6–8; each limb action 4–6; turn/spin 6–8; recover 3–4; rear walk 6 and idle 2 |
| Garden challenger | occupied idle; actual phrase demonstration; glance/approve; step aside | Idle 4; four demonstrated limb actions 4 each; approve 4; step aside 6 |
| Three guest archetypes | chat/sip/folded-arm idle; glance/turn; nod/tap; step-touch; clap/cheer; settle | Per archetype: 4 + 3 + 4 + 6 + 4 + 2 = 23; 69 total before optional props/extra facings |

Counts are roughing budgets, not acceptance criteria. They supersede the
two-frame action and three-silhouette/four-frame crowd minimum in the older
asset plan for this proof. Use whole-body keyed frames first; modular heads,
hands/drinks and accessories may add variety with per-frame attachment points
and occlusion order. Do not require every facing for every clip: the shot list
defines needed views. Preserve editable layered sources, not just exports.

### Timing and transitions

Author nonuniform frame holds in beat fractions. A 60/90/120 Hz display selects
the same pose at the same musical position; it never advances 'one art frame
per rendered frame'. Provide clip markers for anticipation, accent, foot plant,
release and settle, plus safe interruption/continuation points.

Predictable pre-beat groove prepares the body without awarding a hit. A judged
tap starts a visible accent immediately; an early/late accepted tap must not
wait for another beat. Demonstrations can align their full anticipation and
accent exactly to the known note. Actual player movement records the accepted
event beat and branches from the current groove. Do not delay input, rewind
the whole character, or move a note's timestamp to fit animation. At dense
notes, join compatible accents or interrupt at authored transfer poses so
every accepted action remains legible. A flourish yields to the next required
action. Reduced motion uses compact authored gestures and stable framing.

Pass note ID, limb, scheduled timestamp, accepted timestamp and signed timing
error into the animator; `dance(limb)` currently loses that information. Early
accepted taps can start preparation immediately and reach the main accent on
the note if time remains; late taps enter the accent immediately and shorten
recovery. No player pose is required to peak in the past. Do not flip front/rear
on each successful tap: schedule authored turns at phrase boundaries.

## Crowd system

Implement individual guests with stable IDs, authored floor slots, archetypes,
attention direction, interest memory, current activity, reaction cooldown and
seeded variation. Separate lasting welcome from momentary excitement. Guests
progress through occupied → curious → watching → grooving → participating;
cheering is a temporary reaction, not a permanent loop for the whole room.

Use successful phrase outcomes as the main source of lasting interest.
Individual hits produce small glances/accents; six taps cannot unlock a roomful
of fans. Only guests with an authored view of the floor or an attentive neighbor
can respond. Neighbor influence spreads attention gradually, with a cap that
prevents passive time or self-sustaining contagion from winning the crowd.
Archetypes differ: the curious guest notices first, the sociable guest nudges
a friend, and the reserved guest takes several solid phrases to join.

Starting hypotheses: 8–12 visible garden guests, three archetypes, one or two
new focal reactions per bar, delayed neighbor glances over the following bar,
and a multi-phrase path to participation. Tune thresholds to the authored
60-second clean garden route. A first successful phrase should earn a visible
glance; the midpoint should show some grooving; full required mastery should
produce a clear welcome even without perfects or flourishes. No fixed timer
must prevent a legitimately fast clear from receiving its payoff.

One miss lowers brief excitement, not all earned welcome. Repeated failed
phrases may gently soften activity; there is no mass rejection snap. A level
entrance reset restores a documented checkpoint, while previously earned
milestone reactions do not become repeatable score rewards. Crowd presentation
does not replace `FightProgress` or add an extra gate to progression.

Use a pure `CrowdModel` driven by immutable, deduplicated events and musical
position. Add explicit phrase-resolution events rather than polling sticky
`lastOutcome` or deriving social history from the current combo. Event IDs
must distinguish logical scored phrases from replay attempts. Save the seed,
committed interest and event cursor with future versioned room checkpoints.
On pause/count-in, freeze music-linked guests; on replay, restore the phrase
snapshot and replay cosmetics without granting social or score credit twice.
Define this before coupling it to durable saves.

Specifically, `_phraseIdentity` currently encodes progression state and can
repeat after failures at tier zero. Add a monotonic response-occurrence ID:
replaying an interrupted occurrence retains its ID; a subsequent completed
retry uses a new one. Snapshot/rollback uncommitted crowd reactions separately
from already committed phrase results. Good and Perfect taps earn equal lasting
social credit. Starting tuning can normalize a passed response to roughly
`100 / minimumCleanResponses` interest, with small fixed guest receptiveness
differences, staggered thresholds and downward hysteresis. Cap earned states
by completed phrases so early taps cannot shortcut the arc. These hypotheses
must pass clean and struggling run scripts before becoming balance constants.

Use `transport.currentTier` for the energy of the arrangement actually audible,
not an immediately requested `progress.tier`. Recognition remains separate from
energy. Clearance gives the final welcoming reaction even to reserved guests.

## Living environments

Use genuine independent layers: distant architecture, midground decor,
floor/contact shadows, actors and props with occlusion, foreground plants,
and restrained emissive accents. Animated bits must not be baked into the
flattened painting. Parallax has a physical scene anchor and overscan; never
slide the whole screen and call it layered depth.

| Room | Life before interest | Response to dance | Mastery payoff |
| --- | --- | --- | --- |
| Garden | Separate conversations, hanging Tillandsias, moths by a lamp, window silhouettes | A sip stops, heads turn in sequence, nearby plant tassels sway with the passing group | Queue steps aside, doorkeeper lifts rope, warm entrance opens |
| Bar | Stirring/drink idle, bottle highlights, distracted pair at counter | Bartender actually mirrors the call; ice/shaker accent; a glass lifts after a phrase | Drink slides to an authored stop and side passage opens |
| Cool crowd | Closed social clusters, private step patterns, moving disco reflections | Glances spread across clusters; small groups mirror Mācron with varied steps | Dance circle opens and a signature step is echoed |
| Restroom | Foot tapping, sign flicker substitute using slow value change, shifting door shadow | Attendant's impatience becomes a playful matching foot pattern | Key spins, door opens, brief relieved bounce |
| VIP | Quiet conversation, couch postures, restrained pendant light | Host turns, nearby seated guests mark time; Tlatoāni notices | Rope opens, high five and invitation retain the authored ending |

Separate three event classes: ambient life, musical accents and gameplay
responses. A plant reacts to wind or a passing guest; a guest reacts to a
successful phrase; an aperture opens on actual acceptance. Avoid making
every object bounce to every beat. Ambient activity continues without player
success but cannot increase earned crowd interest. Start with reactive details
triggered by dance, not new prop-tapping demands over the thumb controls.

> **Superseded in part by the owner, 2026-11-06.** Backgrounds, the party and other cosmetic assets SHALL be affected by the music score, by design. Plants, umbrellas, waiters, flames and other background items join in, and the whole scene slowly parties up as the music grows. This replaces "Avoid making every object bounce to every beat" above. See `plan/owner-rulings-2026-11-05.md`.

A small presentation director schedules focal reactions at safe musical gaps,
limits concurrent gestures, and allows settling between peaks. Call phases
prioritize the challenger's readable demonstration; dense responses suppress
competing visual events near cue paths. No environmental event moves the fixed
HUD, immutable cue destinations or judgment time. Existing camera limits,
reduced-motion behavior and no-strobe rule continue to apply.

## Runtime boundaries and budgets

Keep `GardenSession`/`FightProgress` authoritative. Introduce `PerformanceEvent`
output, a pure `CrowdModel`, a `DanceAnimator` selecting clips/transfer poses,
a `PartyDirector` scheduling presentation and a `RoomSceneDefinition` containing
layers, floor slots, attachment anchors and prop event bindings. Replace the
large draw methods incrementally with atlas-backed renderers in Flame; keep
Flutter controls separate. Reuse the music transport rather than adding a
second BPM timer. Cosmetic effects never request progression/music tiers.

Acceptance and traversal must use the conductor's continuing musical timeline
across room bridges; a cleared session's clock may stop. Replace music-linked
uses of `_ambient`, including acceptance timing, rather than freezing exit
animation accidentally when migrating to transport-driven clips.

Preload the active room and a bounded transition set, share guest atlases,
cache frame metadata, and release unused room resources. No full navmesh or
general-purpose social AI is needed: use authored slots and short routes.
Cap actors, reaction queues, particles and prop activities. Initially target
60 fps (16.7 ms frame budget), recording median/p95/p99 frame times, input/audio
latency and decoded texture bytes on actual Android Chrome and iOS Safari.
These are measurement targets, not claimed results. If needed, reduce distant
guest count and decorative updates before touching judgment/audio or omitting
core dance frames. Quality changes occur at stable boundaries.

## Delivery order and review gates

1. **Art/motion proof.** Model sheet, native garden composition and a short
   animated Mācron groove→step→accent→turn→settle study, alongside one guest
   occupied→curious→grooving study. Review native-size moving loops before
   producing the rest of the sheets. Gate: recognizable robot, planted feet,
   real facing changes, consistent pixels and readable weight transfer.
2. **Deterministic behavior proof.** Replay a fixed event script with slow
   improvement, clean taps, misses, flourish variants and entrance reset.
   Implement typed events and crowd state before filling the scene. Gate:
   gradual individual interest; no passive win, combo jump or duplicate gains;
   identical state across update rates and pause/replay.
3. **Complete garden proof.** Integrate cleaned clips, 8–12 guests, layered
   garden and roughly six causal details. Record the same clean and struggling
   runs with reduced motion on/off. Gate: a viewer can identify who noticed
   first and why, the party visibly warms up, taps alone earn acceptance,
   one miss does not erase it, and thumb cues remain clear on a real phone.
4. **Bar and continuous transition.** Apply the system through data, with
   distinct guest activities, genuine call demonstration, drink/shaker action
   and preserved continuous music. Gate: two rooms feel socially distinct;
   no guest/state leak or load hitch at the bridge.
5. **Campaign expansion.** Add cool-crowd choreography, restroom rhythm and VIP
   social payoff in that order. Only now expand guest variants and secondary
   details. Gate: five-stage identity, original ending canon, asset provenance,
   phone performance and accessibility evidence. Covi still needs a reference.

Start the integration proof with the five existing placed guests, then increase
to the proposed 8–12 after readability and profiling pass. Initial resource
hypotheses: one focal social reaction at a time, at most eight decorative
particles, and 16 MiB decoded art for active plus transition assets. Track raw
`width × height × 4` separately from measured process/GPU memory. During a
ten-minute retry capture, target p95 frame time ≤16.7 ms and p99 ≤33.3 ms on a
named lower-end phone. Decode/upload art before response phrases. These are
provisional budgets, not portability or performance guarantees.

Automated checks should cover event deduplication, crowd thresholds/hysteresis,
bounded propagation, taps-only path, timing/frame selection, interruption and
checkpoint replay. Atlas validation checks frame rectangles, pivots, markers,
tags, attachments and required asset status. Visual approval requires motion
capture at native size and physical-phone review; passing Dart tests is not
evidence that the animation feels like dance.

Production assets need editable source, lossless PNG, tagged frame metadata,
ground anchor, holds/markers, facing, palette and provenance. Concept→clean→runtime
status requires actual inspection. The first implementation should end at the
garden proof, with evidence attached, before authoring all five rooms.
