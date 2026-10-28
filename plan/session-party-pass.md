# Party behavior pass — 2026-10-28

Branch: `work/1829-danc`, based on `origin/game` at `6c32f3c`.
Three Astra agents researched and implemented input, crowd/progression and
music/departure components; the primary agent integrated rendering, conductor
presentation timing, specs and planning. This work was subsequently committed and pushed as `fb02490` on the work
branch at the owner's request. No production deployment or integration-branch
update was performed. Follow-up sprites and AutoPlay are recorded in
`session-sprites-autoplay.md`.

## What changed

- Preserved the four stable thumb zones, two-beat flowing cues and press-down
  scoring. Marked successful taps accept a local 24-logical-pixel/400-ms flick;
  direction chooses one of four musical ornaments. Arrow keys supply an optional
  keyboard equivalent. These settings require physical-phone tuning.
- Garden build-up accepts six of eight notes; bar and full-tier proof accept
  seven. Timing windows remain unchanged. Demonstrated limb motifs vary across
  tiers and final proof phrases. Reaching tier four still requires two successful
  final phrases in each currently playable room.
- Individual crowd recognition is phrase-earned and staggered; transient style
  chains excite nearby guests. Failed phrases cause localized interest loss and
  a short recovery-step placeholder. Logical audio timestamps, occurrence IDs,
  crowd checkpoints and score deduplication protect pause/replay behavior.
- Rendered guests now point, mark time and step in different states, with floor
  shadows. The approval/coda/bridge presentation follows continuing conductor
  beats; guests settle at different moments and selected guests clap the exit.
  The garden bridge samples its authored departure route. Other route entries
  remain storyboard data for rooms that are not yet playable.
- Every score starts with recognizable melody, harmony, bass and percussion.
  Higher tiers add orchestration; approval second bars thin and soften. Catalog
  remains five room scores, five success tags and four bridges, now 7,544 events
  and 34 MIDI exports. Existing tempo ranges and bridge lengths remain unchanged.

## Verification

- `flutter analyze --no-pub`: passed with no issues, including the final approval-clock fix.
- `flutter test --no-pub`: 42 passed. After the final approval-clock fix, the
  affected session and campaign-transition suites passed again (17 tests).
- `node tool/music/validate.mjs`: passed, 7,544 valid events and 34 balanced MIDI files.
- Transport/conductor harnesses: passed in the music agent's verification.
- Music regeneration: 49 generated files reproduced byte-for-byte.
- `openspec validate living-party --strict --no-interactive`: passed.
- `git diff --check`: passed.
- Release web build: passed; rebuilt after the final input/crowd/approval-clock changes.
- Local static preview launched at https://www.kumbia-kombat.localhost:18443 .
  Headless Chromium Galaxy S24 smoke check: 360×780 viewport, no horizontal
  overflow, start action enters live call/response rendering, no console errors.
  Browser screenshot tool exceeded its output cap; compressed CDP capture was
  inspected instead. This browser has no speakers and is not a physical phone.

## What remains

This is a behavioral prototype using procedural sprites and existing flattened
backgrounds. It does not deliver cleaned multi-frame atlases, seated/standing
transitions, real contact with bystanders, doors/ropes or genuine layered parallax.
Only garden and bar are playable. The whole-crowd VIP standing ovation and other
room-specific exits are storyboarded, not complete runtime scenes. The art,
resource and physical-device gates in `party-overhaul.md` remain open.

Live style-driven tempo boosts are designed but deferred pending comfort and
cue-deadline validation. Required progression retains its existing +3 BPM/tier.
There is no claim of human listening approval, mix/headroom acceptance, measured
physical input latency, durable reload-safe crowd saves or final game balance.

Next smallest review: play the local garden on a real phone, first taps-only,
then short flicks, observing wrong-zone versus timing errors, discoverability,
false gestures and phrase difficulty. Approve one native-size dance/guest motion
study before replacing procedural bodies with production atlas artwork.
