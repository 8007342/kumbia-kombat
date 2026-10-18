# Remaining work

Read `openspec/project.md` and feature specs before each session. Work on a
new grammar-valid `work/<order>` branch based on `game`; push early and
integrate tested milestones into `game`, as explicitly authorized by the owner.
Foundation `cf4fdb7` has landed on `game`; main remains the release branch. Check boxes only
when their acceptance gate has evidence, and leave a handoff below.

- [ ] **01 — Physical garden/bar acceptance.** The code, scene starters,
  eight-move charts and musical handoff are implemented and tested. Verify
  both fights on a physical portrait phone, one thumb, taps only and then
  optional swipes. Gate: readable cue previews, reachable regions and no
  unacceptable input/audio latency. Emulator checks do not satisfy this gate.
- [ ] **02 — Timing and music quality.** Calibration, headroom measurement,
  voice priority and independent mute remain. Looping and shared-clock
  success/bridge scheduling are implemented. Listen to all 14 pieces, every
  tier change and all 4 room bridges; tune hooks and percussion on speakers,
  headphones and Bluetooth. Gate: no stuck notes/clipping; catchy musical
  joins and acceptable timing established by listening and device evidence.
- [ ] **03 — Durable save/resume.** In-memory pause, cancellation, phrase replay,
  one-bar count-in and style deduplication are implemented. Persist versioned
  committed checkpoints, recover partial writes and process-kill/reload.
  Gate: recover without missed unheard notes, progress loss or Pizazz farming.
- [ ] **04 — Production character animation/parallax.** Garden/bar source
  backgrounds and challenger single poses are integrated; Mācron has aligned
  code-native rear/front hit/walk/spin poses. Produce full challenger clips,
  genuine layered backgrounds, side-view combos and frame manifests. Gate:
  native-size canon/readability review, motion options and stable touch regions and immutable per-note destinations.
- [ ] **05 — Cool crowd plus bar tuning.** Bar has its distinct Swag chart,
  artwork, musical entry and sign-off. Build Flow art, chart and crowd-opening
  sequence, then connect authored bar→crowd bridge. Tune current bar chart
  (~90–95s) toward its 80s design budget without mandatory flourishes.
  Gate: three rooms flow continuously and each clears through taps alone.
- [ ] **06 — Restroom and VIP finale.** Author short faster restroom chart,
  hardest VIP sustain, remaining art and transitions, high-five closeup,
  “Chingón” and invitation to sit. Gate: complete clean run 5–8 minutes;
  final respect earned before timer freezes and ending begins; no game over.
- [ ] **07 — Durable global Top 10.** Add Worker API, SQLite Durable Object
  migration and binding, server-issued run tokens, milestones, atomic finish,
  bounded validation/rate limits and idempotent submission. Gate: concurrent
  submissions correctly retain fastest ten; malformed/replayed runs rejected;
  local development and migration tests pass before any production deploy.
- [ ] **08 — Arcade initials and results.** Inspect lakanoa reference, implement
  three-slot A–Z controls, optional keyboard, top-ten table with separate
  elapsed/Pizazz columns and pending-result retry. Gate: no keyboard needed on
  mobile; provisional qualification can change safely; network failure never
  blocks final celebration.
- [ ] **09 — Device and accessibility pass.** Physical Android Chrome and iOS
  Safari, narrow/tall screens, thumb reach, safe areas, audio interruptions,
  reduced motion and color-independent cues. Gate: one-handed casual runs and
  expert Pizazz play both viable; memory/audio scheduling stay bounded over
  long retry sessions; asset/synth licenses documented.
- [ ] **10 — Release.** Verify analyze/tests/release web build, review asset
  manifest, cost/abuse bounds and persistence migrations. Integrate completed
  work into game; merge to protected main only when the release is complete.
  Deploy through existing Cloudflare flow after release review.

## Handoff protocol

Each session records branch + pushed commit, files changed, commands/results,
what actually works, remaining limitations, and the next smallest action.
Do not infer that planned specs are already implemented. Keep
`plan/music.md` and `plan/assets.md` synchronized with this roadmap.
