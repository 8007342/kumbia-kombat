# Kumbia Kombat — world, people and movement

Canon remains in `openspec/specs/art-direction/spec.md`. This guide specifies how
reusable people and props belong to the same photographed/painted space.

## Perspective and relative size

- Author world composition at nominal180px logical width. Source paintings are
  mapped with one centered cover transform; actors and props use that exact mapping.
  The HUD and thumb zones stay in screen space.
- Each room has an inspected source-image horizon and a standing-adult height at
  a reference floor point (`party_layout.dart`). Projected standing height grows
  with distance below that horizon. Relative-distance scale is never hand-tuned
  independently for each guest or each animation frame.
- Use standing reference height to scale a whole character atlas. Seated clips
  remain at that same scale: people do not grow when sitting. Keep floor roots,
  supporting feet, chair bases, table bases, occlusion order and ground shadows
  consistent. Sort actors/props by their floor anchors.
- Mācron is .35 of a standing adult's physical height, evaluated at Mācron's own
  floor distance. A nearby toy can appear taller than a very distant person; this
  follows the floor projection rather than arbitrary screen ratios.
- Furniture dimensions are fixed per prop design and perspective-scaled on the
  same floor. Current stylized high-back chair calibrates to .80 adult height,
  .53 width and .37 seat height from its measured source. These ratios describe
  the current art, not a recovered metric camera or universal furniture dimensions.
- Only garden and bar are calibrated against current paintings. Future-room plane
  entries remain unverified until their backgrounds exist. Check multiple viewport
  aspect ratios, floor contacts and human/door/counter scale together.

## Reusable audience and palettes

Three silhouettes × four outfit variants supply twelve distinguishable guests.
Keep skin, hair, face, anatomy and furniture stable; only the reserved plum/pink
cloth ramp changes. Do not globally tint the whole sprite. Source bounds, ground
anchors, palette eligibility and frame groups are asset metadata.

Guests begin occupied and seated. Animate idle breathing/hand shifts, noticing,
looking, seated foot tapping, leaning forward, standing, stepping, clapping,
cheering and returning to seats. Stand-up/sit-down clips are mandatory transitions;
do not pop between seated and upright loops or squash a standing person.

Crowd enthusiasm uses stage budgets per twelve people:

| Stage | Interested | Following | Standing | Cheering |
| --- | ---: | ---: | ---: | ---: |
| Garden |3|2|1|0|
| Bar |5|4|2|1|
| Cool crowd |8|7|5|3|
| Restroom |9|8|6|4|
| VIP |12|12|12|12|

These are cumulative ceilings, not instant targets. Good gameplay recruits guests
slowly with individual thresholds, fractional-beat delays and neighbor notices.
A successful phrase or approval never overrides the budget or changes the whole
room on the same beat. Full support means completing this room's social arc; it
does not mean all garden guests stand. Flourishes create local excitement within
that arc. The whole-room standing ovation belongs to VIP. Departures finish each
guest's gesture, then sit and return to activity, with a few lingering clappers.

## Dance battle and ambient life

Challengers perform the actual limb motif and exact note timing shown to the
player. Show anticipation, clear accents, foot support, follow-through and settle.
Increasing coordination comes from the authored chart, never random gestures.
Use the last musical rest for finish → cede → open-palm invite. The opponent then
watches rather than dancing competing cues. Mācron similarly finishes and yields
back at the end of the response. Required inputs always outrank cinematic poses.

Original dance animation borrows strong silhouette, weight and recovery techniques
from expressive action animation while remaining warm, musical and nonviolent.
Authored view changes replace squeezing/rotating a flat character.

Plants, umbrellas, candle flames, drinks and waiters have independent slow phases.
Ambient motion is gentle life, not every prop bouncing on every beat. Freeze the
foreground clock on pause/background; honor reduced motion with held expressive
poses and steady lights. No strobing or full-screen flashes. Props cannot cover
upcoming cue paths or change input/judgment geometry.

Research and validation limits: `plan/crowd-animation-system.md`,
`plan/dance-battle-choreography.md`, `plan/party-perspective-and-life.md`.
