# Kumbia Kombat

A portrait, one-handed, music-first rhythm dance game built with Flutter and
Flame. Mācron āi earns respect through five Kumbia Fights in Tlatoāni's
Kumbia Koliseum mansion party. The clean route to VIP takes 5–8 minutes.

Required taps advance; optional tap-then-swipe flourishes earn Pizazz and
musical responses. Five original precomposed MIDI-style synth scores build
and relax with performance. No game-over screen; repeated sequence failures
push the player to the entrance of the current level.

## Product decisions

- Mobile web first, portrait, lower-screen four-zone thumb controls, one finger.
- Pixel art, parallax, sprite animation and simulated camera depth; minimal text.
- Narrative: garden/entrance → bar → cool crowd → short urgent restroom → VIP.
- Final high five, “Chingón”, and a seat beside Tlatoāni, Covi and party guests.
- Automatic local checkpointing; manual pause and interruption recovery.
- Global fastest-run Top 10, exactly three uppercase arcade initials;
  Pizazz breaks equal recorded times. Cloudflare SQLite Durable Object.
- Specs are the intended behavior. Existing landing page remains until the
  first audiovisual vertical slice is ready; foundations are not a finished game.
- Work on `work/[0-9]{3,4}-[a-z0-9]{4}`; the owner explicitly authorized
  integrating completed milestones into `game` (2026-10-18). Reserve `main`
  for the complete release and respect its protection hooks.

## Architecture boundaries

Music transport owns musical time; frame updates only render its state.
Combat consumes timestamped inputs and emits progression/style events.
The conductor applies those events at documented musical boundaries.
Story director consumes level events and schedules beat-based sprite/camera
cues. Persistence captures committed state and recreates audio on resume.
See feature specs and plan/roadmap.md for acceptance gates and next sessions.
