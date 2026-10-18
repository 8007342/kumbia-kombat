# Storyboard and first playable rooms — 2026-10-18

Branch: `work/1825-gard`, pushed before substantial work. The owner later
explicitly authorized integration of completed milestones into `game` and
main only when complete. Foundation `cf4fdb7` has now fast-forwarded `game`.
The current work branch is based on that foundation, with no forced updates.

## Story and assets

`plan/storyboard.md` now maps all five arrivals, calls, responses, escalations,
local resets, approvals and transitions, plus the final high-five invitation.
The storyboard is a production contract; its listed future clips are not
claims of delivered animation. Garden imagery and a single transparent
challenger pose are real generated assets with exact prompts/provenance.
Mācron uses a small original code-native pixel sprite with rear/front poses,
limb hits and beat-driven walk/spin. Generated concept art is not sliced as an
atlas. Other animation clips and layered parallax still require production.

## Runtime direction

The app now plays the garden and bar fights, with SVG body-part controls, tornado cues,
call/response, required tap judging, optional after-tap swipe, Pizazz, musical
tier requests, full-tier proof, local failure/reset feedback and a clear screen.
The music loops indefinitely across retries using an absolute audio clock.
A platform-safe facade keeps VM tests importable and explicitly rejects
unsupported native audio instead of silently scoring without sound.

Manual pause and lifecycle interruption replay the current call with count-in.
This is in-memory recovery; durable save/reload checkpointing remains planned.
Ranked timing and the backend are not yet wired. The garden success phrase, bridge and bar entry share one audio clock; the
bar ends with its own short success score. Three more rooms and the ending
remain. All five success themes and four bridges are authored, but only the
garden-to-bar visual/gameplay handoff is currently integrated.

## Preview workflow

1. `npm run build` (bundles the renderer locally).
2. `node tool/prepare_preview.mjs` (keeps the score room at /music/).
3. Publish root with managed `runtime=wrangler`; reload the service after a
   Flutter build if watching transiently removed files caused it to exit.

User-facing local root is the game; /music/ remains the independent score room.
The shared Flutter dev process supports r/R, but its advertised route is still
rejected by host-browser. The working preview uses the release output above.

## Gates still needed

Physical portrait-phone playtest; calibrated latency; save/reload; final
multi-frame character animation; remaining three rooms and ending; global
leaderboard. Do not mark the roadmap's physical-device gates complete from
an emulator or headless browser.

## New musical continuity request

The owner requested per-level success/exit mini-themes and smooth connecting
scores so the five rooms form one uninterrupted composition. Completion must
freeze required scoring while allowing the final optional swipe window;
full-mix music continues until its bar-aligned exit and bridge. Explicit
pause/background suspension remains supported. Native/reload persistence
still requires later integration.

## Verification and remaining tuning

Actual-score controller/conductor integration clears garden and bar with taps
alone, preserves each exact source/success/bridge/next downbeat, and never
calls shared silence during handoff or natural finish. It caught and fixed
two floating-point boundaries: response time classification now matches the
judge's millisecond precision, and source retirement rejects attacks at its
exclusive device-time endpoint (preventing zero-duration duplicate notes).

The bar's authored clean chart currently takes about 90–95 seconds against an
80 second tuning target. Full-run 5–8 minute timing is still a campaign playtest
gate. Durable reload recovery and global ranking remain unimplemented.

## Final checks for this milestone

- Flutter analysis: no issues; all 19 Flutter tests pass (judgment, recovery,
  authored garden/bar charts, late activation lifecycle race, real-score
  two-room music integration, thumb-zone bounds and start screen).
- Release web build with local renderer passes. Local UI font is bundled
  with its original SIL Open Font License.
- Music validator: 14 scores (5 rooms + 5 successes + 4 bridges), 34 MIDI files,
  6,674 valid notes, balanced attacks/releases.
- Transport and transition harnesses pass, including loop seams, queued
  successors during pause, shifted anchors and exact retirement endpoints.
- OpenSpec: 9 items pass; advisory long-prose warnings remain.
- Native audio, physical phone latency, full reload persistence, remaining
  rooms, ending animation and leaderboard are still gates for main/release.

## Thumb-only control refinement

User selected the lower thumb pad as the sole layout. Removed corner mode and
its menu toggle. Destinations sit closer together and vary deterministically
by each note's authored hit beat. Each visible note shows its own destination
ring; a flying cue never changes endpoint. Large fixed logical regions still
accept taps, so variation adds visual rhythm without precision penalties.

Real browser audio-clock input completed both rooms with 128 required taps,
126 Perfect judgments, zero optional Pizazz and no runtime console exceptions.
This verifies the two-room flow, not physical-device latency or listening quality.

The refreshed 360×780 browser preview shows the compact moving destinations
in the lower pad, with the corner toggle absent and no runtime exceptions.

## Mobile preview timing release

User requested a more forgiving early/late window and publication of the current
prototype for real-device testing. Good taps now accept ±180 ms (was ±110 ms),
Perfect accepts ±75 ms (was ±45 ms). Late cues remain visible through judgment.
Regression coverage checks inclusive early/late boundaries, just-outside misses,
nearest-note selection for overlapping double-tap windows and single consumption.
The user explicitly authorized publishing this incomplete prototype to main;
remaining campaign work stays in the roadmap.
