# One-thumb rhythm input: research and first pass

Reviewed 2026-10-28. The immediate goal is a satisfying taps-only dance with an optional expressive layer that rewards short gestures without making later required taps harder.

## Primary evidence

- [Simogo: Beat Sneak Bandit development retrospective](https://simogo.com/work/beat-sneak-bandit/). The developers describe simplifying prototypes whose gestures and backbeat rules were difficult to anticipate. The shipped control uses taps, while the audio drives gameplay and animation. They also describe making actions immediate and expressing motion through follow-through after the action. Application here: preserve immediate pointer-down tap feedback and the audible transport; make optional gestures enrich an already accepted tap.
- [Apple: Game controls](https://developer.apple.com/design/human-interface-guidelines/game-controls). Apple recommends reachable thumb controls, frequently used buttons of at least 44×44 points, visible press feedback, and combining related actions where appropriate. Application here: retain full logical hit regions rather than requiring ring precision; explain that the whole zone works. A flourish starts wherever the thumb successfully landed, so it does not require reaching a second target.
- [Microsoft: Xbox Accessibility Guideline 107 — Input](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107). Input speed, complexity and duration create different burdens; remapping alone does not solve them. The guidance recommends alternatives to simultaneous inputs and path gestures. Application here: completion remains possible with single taps, keyboard arrows provide the optional flourish without a path gesture, and neither holds nor multitouch become mandatory. This is not a claim of full accessibility compliance.
- [Nintendo: Iwata Asks, Rhythm Heaven, page 3](https://iwataasks.nintendo.com/interviews/ds/rhythm-heaven/0/2/) and [page 6](https://iwataasks.nintendo.com/interviews/ds/rhythm-heaven/0/5/). The developers discuss experimenting with stylus flicking and enjoying its tactile release. These pages were available through indexed primary-source excerpts; direct retrieval timed out. This supports exploring an expressive flick, not importing stylus thresholds into thumb controls.

## Controller comparison

| Interaction | Value | Cost and decision |
|---|---|---|
| Tap in a stable limb zone | Immediate, repeatable, keeps four-limb identity | Required foundation. Whole region accepts the press; no exact ring targeting. |
| Short directional flick after an accepted tap | Expressive movement and four musical variations with the same thumb | Implement now on marked, safely spaced notes. Credit the tap before recognizing the flick. |
| Touch, hold, release on a beat | Sustained pose and a musical release | Candidate later for authored rests; occupying the only thumb and grading release add demands. Do not make required in this pass. |
| Double tap / extra beat combo | Rhythmic expression using taps only | Use authored repeated-note phrases for now. A hidden double-tap recognizer could consume the next required note or delay single-tap feedback. |
| Circle / long traced swipe | A conspicuous flourish | Defer: thumb travel, occlusion and path precision are substantial costs. |
| Any-location rhythm tap | Reduces spatial difficulty substantially | Possible explicit alternate control profile later; it changes the four-quadrant matching rule and needs its own cue presentation. |

## Implemented first-pass contract

- Required taps still judge on pointer down with ±75 ms perfect and ±180 ms accepted windows. Preserve flowing two-beat previews and each note's immutable destination.
- Optional flicks start from a successfully judged, marked note. Release the same pointer after at least 24 logical pixels, within 400 ms of that press. The dominant movement axis chooses up/right/down/left; release position need not enter another quadrant. A plain tap or invalid flick keeps its already-earned required-note credit.
- The four-arrow cue and local hint indicate that any direction works. The actual direction selects the musical adornment. Keyboard players use Q/W/A/S for limbs and an arrow key for the marked tap's flourish.
- Pause, cancellation and room handoff discard pending touches. One note can earn style once. A flourish never consumes the next required tap.
- Show successful imprecise taps as GOOD with a short early/late qualifier, without signed millisecond diagnostics. A stray tap gets KEEP THE PULSE rather than a red failure message.
- Session integration offers gestures only where enough time remains before the next required input, including the latest accepted tap, full gesture window and next note's early window. Style feeds localized crowd response through the session; tap-only performance still advances.

These numbers are **prototype tuning decisions**, not thresholds established by the sources. Moving from a cross-quadrant 36-pixel/300-ms swipe to a local 24-pixel/400-ms flick removes a reach requirement and gives more execution time. Physical-phone testing still needs to establish false-positive rates and comfortable travel.

## Next validation and expressive progression

Observe first-time players with both left and right thumbs. Separate wrong-zone errors, early/late taps, cue-reading mistakes and gesture failures before enlarging timing windows. Check low-end frame rates, audio output latency, safe-area placement and both narrow and large phones. Measure successful tap-only phrases and accidental style activation, not merely total score.

Keep advanced gestures optional in progression but conspicuous in performance: distinct authored dance flourishes, short directional musical fills, nearby guests mirroring, and a visible buildup toward a crowd response. Repeating the same style can give less spectacle than varied style combinations, without subtracting tap progress. Do not require a style threshold to unlock a gate.

Prefer extra percussion, arrangement density and richer crowd movement for immediate excitement. If a later design adds a small style-driven tempo lift, schedule it through the existing music transport on an unambiguous phrase boundary before new cues appear; cap it and preserve a stable option. Never change audible speed or existing note timestamps in response to the middle of a swipe.
