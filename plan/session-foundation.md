# Foundation session — 2026-10-18

## Scope and decisions

User confirmed portrait mobile-first one-handed controls, 5–8 minute clean
run, no game-over screen, progressively harsher current-level resets,
required limb taps and optional tap-then-swipe Pizazz, original dynamically
combined MIDI synth scores, pixel art/parallax, and Cloudflare Durable Object
Top 10. User requested Astra for composition/engine design and early remote
push. Remote was verified before substantial work on `work/1824-kumb`.

Chosen provisional respect ladder: Mojo → Swag → Flow → Nerve → Presence.
Clean fight budgets total 390 seconds, leaving transitions inside 8 minutes.
Server-ranked elapsed includes interruptions; local active play time does
not. This prevents pause-to-study from improving global speedrun standings.

## Delivered foundation

- Feature specs for rhythm combat, adaptive music, art/story/camera,
  run lifecycle and global arcade leaderboard.
- Pure Dart combat/progression models and behavior tests.
- Five original score datasets, five complexity tiers each, MIDI previews,
  score generator, music transport and reviewable browser synth preview.
- Four SVG limb controls, generated Mācron concept art, canon provenance and
  asset/animation inventory. Concept frames require cleanup before runtime.
- Dependency-ordered roadmap with physical-device and production gates.
- Forge binary PATH/hook wiring repair, recorded in FORGE_DIAGNOSTICS.md.

## Actual runtime status

Flutter's main application remains the bootstrap landing page. Combat, audio,
art, persistence and leaderboard are not integrated into a playable campaign.
Use the standalone music preview for score review. The production backend,
phone latency calibration, charts, final animation atlases, transitions and
complete campaign remain explicit roadmap work.

Covi needs a verified visual reference. Lakanoa source returned 404 via its
GitHub API; no code or implementation details were copied. Arcade entry is
specified from the user's described three-letter interaction.

## Next session

Start roadmap item 01: garden audiovisual slice. Connect the timestamped
RhythmJudge to MusicTransport and the browser synth, add a portrait cue HUD,
then test taps/swipes on a real phone before expanding charts or art.
Native synth support is a later adapter; browser audio is the first target.

## Verification

Final commands and results are recorded below after all agent files settle.

- `flutter analyze`: no issues; `flutter test`: all six tests passed.
- `flutter build web --release`: passed, existing landing application.
- `node tool/music/validate.mjs`: five scores, 6,136 notes, all 25 MIDI files
  parsed with balanced note attacks/releases, five increasing tiers, four
  adornments per score.
- `node tool/music/build_preview.mjs`: passed; standalone JS synth compiled.
- `dart --packages=build/music-preview/packages.json tool/music/transport_check.dart`:
  passed score parsing, deduplication, tempo-boundary continuity, coalescing,
  pause/resume, starvation, suspended backend and completion checks.
- Managed headless Chromium at Galaxy S24 360×780: all five scores entered
  playing state; tier change requested at beat 8, flourish executed without
  console errors; no horizontal overflow. Headless has no speakers: no claim
  of musical quality/listening approval or physical-phone latency validation.
- Four SVG controls parsed successfully; `git diff --check` passed.
- Latest browser bundle additionally verified tier 4 committed after requested
  beat 8 and pause/resume held beat 5.4 through the non-scoring count-in.

- `openspec validate --all --no-interactive`: all seven items pass; advisory
  warnings flag long requirement prose for future editorial splitting.

## Remote and live preview

Foundation commit `feab623` was pushed successfully and durably relayed to
GitHub on `work/1824-kumb`. A followup docs commit records this handoff.
Draft PR creation via connector returned 404; git CLI has no GitHub auth.
Open a PR from this work ref into `game` when repository API access is fixed.

Visible music review window: https://www.kumbia-kombat.localhost:18443 .
Managed preview serves build/music-preview; rebuild it after audio changes.
Flutter dev server is running with hot reload (`r` in its interactive session),
but host-browser rejects its advertised flutter subdomain; diagnostics records
the exact failure. Flutter UI remains the bootstrap landing.
