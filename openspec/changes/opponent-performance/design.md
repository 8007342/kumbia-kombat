# Design

## Context

`ChallengerChoreography` already samples the active chart's limb notes on musical beats, and `PartyFloorPlane` already derives projected stature from floor position. The pose atlas has one key drawing per semantic tag. `BattleStaging` has beat-sampled root routing, but `GardenSceneGame` does not use it; the current opponent renderer derives a static floor point from `floorYield`. `CrowdInterestModel` grants broad interest on passing phrases, while a failed phrase only lowers two nearby guests' interest.

See [proposal.md](proposal.md) for motivation and the spec deltas for required behavior.

## Goals / Non-Goals

**Goals:**

- Give challengers a reusable, character-specific vocabulary of motion phases around chart-authored accents.
- Make floor-root movement, footfall frames, facing and perspective one synchronized presentation track.
- Let repeated setbacks cool room-wide enthusiasm gradually while preserving local reactions, social ceilings and gameplay authority.
- Ensure cloud-generated or future ComfyUI assets are briefed, measured, reviewed and promoted against durable requirements.

**Non-Goals:**

- Change required chart events, tap windows, score, campaign clearance, or music duration to fit animation.
- Claim the current preview sheets are complete animation or start bulk generation across all opponents.
- Implement procedural IK, real-world crowd simulation, or a continuous 3D locomotion system.

## Decisions

### Separate performance, locomotion, and social pose tracks

The active chart remains the source for opponent accent limb and beat. Animation assets provide preparation, accent, follow-through, and settle drawings around that fixed event. A separate floor route provides movement, facing, stride phase, and arrival. Social actions (challenge, watch, clap, approve, reassure) have explicit priority and do not appear as incidental in-betweens.

This keeps cue accuracy when art changes and avoids trying to solve foot sliding with pose selection alone. A single blended/random pose list was rejected because it cannot guarantee support-foot logic or meaningful transitions.

### Treat the dance mark as an exclusive musical handoff

Use room-local ingress, performance, watch, and egress marks. Sample the route from the absolute presentation beat and project each root, shadow, stature and draw depth through the room floor plane. The departing dancer releases the mark after its final valid input window; the arriving dancer settles before cues begin. Compact phrases keep short authored handoffs; phrases intended to show full crossings allocate time in the chart/cinematic timeline rather than stealing response time.

Authored gait views are required for visible travel. Interpolating only floor coordinates was rejected because it is the source of the current slide impression. Reduced motion may snap at safe handoff boundaries while preserving roles and the same score.

### Make room-wide crowd cooling require repeated setbacks

Keep one failure's stronger local reaction. Track consecutive failed phrase results in the in-memory crowd checkpoint; after repeated failures apply a small bounded interest loss across the cast, then apply the existing extra local stumble. A passed phrase resets the streak and increases interest through the existing ramp. Hysteresis and scheduled sit-down clips continue to prevent state oscillation or teleporting.

This preserves the current readable local response to one mistake while allowing sustained poor play to reduce broad enthusiasm. The precise broad-loss amount is a playtest tuning value, not a Disney/Valve recommendation.

### Keep art research and generation provenance together

Use `plan/animation-research-register.md` as the compact research index and this change's requirements as the production contract. The cloud image service is acceptable for the pilot; local ComfyUI remains a later runner. Raw output and prompt record remain separate from promoted runtime atlases. Automated image checks can measure alpha and geometry, but cannot approve identity, dance quality, or phone-size readability.

## Risks / Trade-offs

- Sparse keys may still look abrupt even when beat logic is correct → add breakdowns only at captured discontinuities and prioritize the most visible clips.
- Gait and perspective may not match the painted room → tune marks and foot anchors against the source background at multiple phone aspects.
- Broad crowd loss can feel punitive → use a small repeat-failure decay, preserve quick recovery on success, and review taps-only play.
- Generated sheets can repeat pose silhouettes or drift identity → retain raw sources, measure real bounds, and keep promotion behind human review.

## Migration Plan

1. Land the spec and reference updates before further bulk art generation.
2. Apply the repeated-failure crowd decay without changing room budgets or progression.
3. Produce a small Gatekeeper movement/dance pilot with timed phase metadata.
4. Integrate gait and floor-stage handoff, then capture the garden on phone.
5. Extend the accepted clip contract to the Bartender and later opponents.

Rollback can disable new presentation scheduling or restore the old crowd tuning without migrating saved user data; run checkpoints are in-memory.
