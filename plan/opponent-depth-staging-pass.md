# Opponent dance and depth-staging pass

## Decision

Run one Gatekeeper-in-the-garden pilot. The active dancer advances on the painted
floor, the watcher yields diagonally back and aside, and two close crowd members
frame the action. Mācron remains `.35` adult stature at every floor sample.

Do not use fake scale curves. `PartyFloorPlane` already derives projected root,
height, shadow and draw depth from a normalized floor point. The missing system is
a beat-sampled stage route, separate from body pose and judgment.

```text
BattleStagingSample
  challengerFloor, macronFloor
  challengerFacing, macronFacing
  challengerWalkPhase, macronWalkPhase
  floorOwner: challenger | macron | neither
```

Body, locomotion and social/clap tracks sample the same absolute conductor beat.
Accepted input owns Mācron's body pose but does not restart grounded locomotion.
The performance zone is exclusive, with actor-specific marks because Mācron is
physically small and needs a closer root to remain readable.

## Candidate anchors

These are art-review candidates, not approved collision-free coordinates.

| Role | Garden `(x,y)` | Bar `(x,y)` |
| --- | ---: | ---: |
| Challenger demonstrating | `(.50,.59)` | `(.50,.49)` |
| Challenger handoff waypoint | `(.62,.55)` | `(.61,.45)` |
| Challenger watching | `(.67,.47)` | `(.67,.39)` |
| Mācron watching | `(.35,.49)` | `(.35,.43)` |
| Mācron handoff waypoint | `(.42,.55)` | `(.42,.51)` |
| Mācron answering | `(.50,.64)` | `(.50,.61)` |

For each intermediate root, use the existing formula:

```text
standingHeight = referenceHeight ×
  (groundY - horizonY) / (referenceFootY - horizonY)
```

Then project root, height, shadow and depth through the same viewport. At
360×640, the garden challenger grows about 114→139 px at these marks; the bar
challenger grows about 185→215 px. The bar needs separate silhouette/cue review:
its steep floor can carry a forward adult into header/cue space.

## Audience framing

Move existing guests and their chairs together; never duplicate interest IDs.

| Pair | Garden | Bar |
| --- | ---: | ---: |
| Closest, slots 0–1 | `(.20,.61)`, `(.80,.61)` | `(.20,.48)`, `(.80,.48)` |
| Middle, slots 2–3 | `(.24,.46)`, `(.76,.46)` | `(.23,.40)`, `(.77,.40)` |
| Other eight | Current anchors initially | Current anchors initially |

Closest guests face inward. Outside elbow/chair/clothing may crop; inboard face
and clapping hand must remain visible. The foreground does not alter crowd budgets:
garden remains one standing and no cheering; bar remains two standing and one
cheering. Existing sheets need rear/three-quarter watcher art before final use.

## Opponent production target

Build a 64-drawing native-grid target for Gatekeeper, then adapt it to Bartender.

| Group | Drawings | Intent |
| --- | ---: | --- |
| Rest/groove | 8 | Alternating supported down, pass and up positions |
| Required limbs | 16 | Each hand/foot gets prep, peak, follow and return |
| Forward entrance | 6 | Two grounded approach steps |
| Backward retreat | 6 | Separate gaze-facing-player retreat |
| Side yield | 6 | Two diagonal sideline steps |
| Watching | 4 | Low-amplitude support shift |
| Clap | 4 | Open, close, palm contact, release |
| Challenge | 4 | Load, proud, offer, return |
| Approval | 3 | Load, nod, release |
| Reassurance | 3 | Notice, open hand, settle |
| Finish/turn | 4 | Two finish, turn-in, turn-out |
| **Total** | **64** | Not every drawing plays every phrase |

Use actual support feet and directional limbs. Gatekeeper gets hat/shoulder
settling; Bartender gets apron/shirt settling. Claps remain chest-height and have
a musical contact frame, so they cannot resemble an input cue. Current full-body
art cannot automatically combine walking and clapping: use an authored combined
pose or select one track by explicit priority.

## Turn timing

- **Cinematic 24-beat pilot:** challenger demonstrates 0–6.5, finishes/offers
  6.5–9, yields 9–10, Mācron enters 10–11, response prepares 11–12, response
  plays 12–20, then outcome/return runs 20–24.
- **Compact 16-beat phrase:** only a small finish, sidestep and invitation. No
  full crossing or decorative return before protected player input ends.
- Current return at response beat 15.25 is unsafe. A final target at 14.5 plus
  late-tap/flourish allowance ends around 15.58 beats at 112 BPM and 15.89 at
  144 BPM. Sample the real transport protection boundary; never delay or truncate
  a valid player move to fit travel.
- Success earns a nod and selected brief clap. A phrase failure earns open-hand
  reassurance and a shared reset. A single miss gets at most a compact glance.
  Reserve playful boasting for protected phrase boundaries, never player mistakes.

## Constraints and acceptance

- Sort by moving ground root, not raised hands or frame bounds; shadows use that
  same root. Keep chairs before their owner and waiter crossings behind the active
  exchange.
- Keep HUD/touch zones screen-space. Protect full cue shapes, active faces,
  instructed limbs and Mācron's silhouette from foreground occlusion.
- Reduced motion switches at handoff boundaries, retaining clear role poses and
  essential accents/claps but no continuous travel, bob, particles or camera move.
- The same musical beat samples identical roots, size, facing and pose after
  dropped frames, pause/resume or presentation handoff.
- Only one actor owns the performance zone. Entrance completes before its first
  required cue; scoring stays identical with staging enabled or disabled.
- Inspect complete envelopes/cue shapes at 360×640, 390×844 and 412×915, then
  profile actual phones before expanding 64-frame assets and wardrobe variants.

## Research basis

- [PBRT projective cameras](https://www.pbr-book.org/4ed/Cameras_and_Film/Projective_Camera_Models)
  supports one perspective relationship instead of independent scale tweaks.
- [Disney animation process](https://www.disneyanimation.com/process/animation/),
  [Cartwright's GDC talk](https://media.gdcvault.com/GDC2014/Presentations/Cartwright_Muriel_Animation_Bootcamp_Fluid.pdf),
  [SLYNYRD Pixelblog 53](https://www.slynyrd.com/blog/2024/11/25/pixelblog-53-punches-and-kicks)
  and [55](https://www.slynyrd.com/blog/2025/3/24/pixelblog-55-top-down-character-animation)
  support readable supports, selective breakdowns, timing and follow-through.
- [Simogo's *Beat Sneak Bandit* account](https://simogo.com/work/beat-sneak-bandit/)
  supports audio-owned timing and immediate feedback before follow-through.

`ranitas`, `cannonball` and `demon_attack` were unavailable as local checkouts,
so their implementations are not asserted as evidence here.
