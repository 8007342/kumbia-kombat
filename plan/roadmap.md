# Remaining work

Read `openspec/project.md` and feature specs before each session. Work on a
new grammar-valid `work/<order>` branch based on `game`; push early, land via
PR. Foundation work lives on `work/1824-kumb` until reviewed. Check boxes only
when their acceptance gate has evidence, and leave a handoff below.

- [ ] **01 — Audible portrait garden slice.** Load original garden score,
  connect synth audio clock to combat model, display four SVG targets and
  tornado previews, pointer-down taps and optional after-tap swipes. Include
  start-to-unlock-audio and non-scoring count-in. Gate: full garden fight can
  clear on a physical portrait phone with one thumb; misses lower complexity,
  full-tier finish is required, optional swipes audibly decorate music.
- [ ] **02 — Timing and music quality.** Implement measured latency calibration,
  adaptive arrangement/tempo commits, scheduled note cancellation, voice caps,
  clipping protection and mute controls. Listen to all five songs at every
  tier and transition, tune hooks and percussion, test dropped frames and
  Bluetooth latency. Gate: no stuck notes, phase jumps or judgements based on
  frame rate; musicianship and catchy hooks reviewed by listening, not tests.
- [ ] **03 — Save/pause/resume.** Persist versioned checkpoints on phrase commits
  and lifecycle transitions, recover partial writes, cancel queued voices,
  count in on explicit resume, deduplicate style awards. Gate: hide, reload,
  audio interruption and process-kill recovery preserve progression without
  misses or Pizazz farming; incompatible saves fail gracefully.
- [ ] **04 — Garden art and story vertical slice.** Curate generated starter
  against canon references, export aligned frame strips and animation metadata,
  build parallax mansion/garden, over-shoulder walk, challenger call/response,
  approval and transition. Gate: readable at 320 px width; protagonist clearly
  Mācron; reduced-motion mode; camera never shifts touch targets.
- [ ] **05 — Campaign charts and second/third fights.** Author deterministic
  call/response charts against the score beat grid; implement bar and cool
  crowd challengers, poses, backgrounds and camera cues. Gate: clean timing
  budgets reconciled with phrase lengths; a tap-only run progresses; repeated
  failures reset only current level; no required simultaneous touches.
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
- [ ] **10 — Release.** Update README from landing to game only when slice is
  available; verify analyze/tests/release web build, review asset manifest,
  cost/abuse bounds and persistence migrations; PR work→game then game→main.
  Deploy through existing Cloudflare flow after release review.

## Handoff protocol

Each session records branch + pushed commit, files changed, commands/results,
what actually works, remaining limitations, and the next smallest action.
Do not infer that planned specs are already implemented. Keep
`plan/music.md` and `plan/assets.md` synchronized with this roadmap.
