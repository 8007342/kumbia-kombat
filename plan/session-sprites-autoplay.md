# Visible sprite replacement and desktop AutoPlay — 2026-10-28

Branch: `work/1829-danc`.

The earlier behavior preview retained the rectangle bodies. This follow-up
replaces their renderer, rather than presenting a behavior-only build as an
art overhaul. The generated source and its remaining limitations are documented
in `assets/art/party/README.md` and `provenance.json`.

Pushed milestones so far:

- `fb02490`: input/crowd/music behavior and research from the prior session.
- `a5766a1`: new Mācron sprite source and exact prompt provenance.
- `47f7443`: transparent guest source, inspected frame manifest, atlas renderer,
  scene integration, asset registration and six atlas/animation checks.

Both procedural rectangle character methods have been removed. The 16-pose
robot sheet and 18-pose guest sheet use measured source rectangles and grounded
anchors. Actual image transparency is tested through Flutter decoding: the
image viewer displays hidden background RGB even where the alpha is zero, so
its colored contact-sheet preview alone is not a valid transparency check.

The renderer selects authored raster poses for limb accents, groove, walking,
turning, notice, clapping and cheering. The source still needs native pixel-grid
and anatomical continuity cleanup before production approval. Challengers and
room backgrounds remain the existing starter images. There is no claim of a
finished five-room visual overhaul.

The owner also requested and received a discreet AutoPlay control because the host has no
touchscreen. The demo controller must use the real judgment/session APIs,
occasionally fail complete phrases, recover and eventually clear both playable
rooms, while producing optional expressive flourishes. Pause, count-in, room
handoff and disabling AutoPlay must not leave scheduled inputs behind. Automatic
play must be visibly identified and must not be presented as a human ranked run.

AutoPlay uses the real session APIs, varying accepted timing and occasionally
omitting enough notes to fail a phrase. The third and seventh response windows
supply deliberate setbacks, followed by sustained recovery through peak proof.
The automatic-run label stays visible even if AutoPlay is later turned off.
Enabling the corner control from ready starts audio using that user gesture.
The demo continues into the bar through the existing conductor; it is a bounded
controller, not a trained machine-learning model or a ranked human performance.

Final integration results and the refreshed preview are recorded below. Physical-device art/input/performance acceptance
and human audio listening remain separate gates.

## Final integration evidence

- `7d50cc0` pushed: discreet AutoPlay, automatic-run marker, art-loading error UI,
  bounded demo controller and actual-score tests.
- `flutter analyze --no-pub`: passed without issues.
- `flutter test --no-pub`: all 50 tests passed, including actual PNG transparency,
  atlas bounds/frame selection, both-room imperfect AutoPlay, pause/off cancellation
  and duplicate-pump protection.
- `flutter build web --release --no-web-resources-cdn --no-pub`: passed.
- `openspec validate living-party --strict --no-interactive`: passed.
- Preview runtime explicitly reloaded at https://www.kumbia-kombat.localhost:18443/ .
- Fresh Chromium desktop smoke check retained service workers and used a mouse-only
  device (1280×720, `navigator.maxTouchPoints == 0`). Source requests loaded the new
  party manifest and both atlas PNGs. The screenshot visibly shows the raster robot
  and detailed adult guests; no rectangle-character fallback or gradient boxes.
- A mouse click on the top-right AUTO icon starts the game directly, shows
  AUTOMATIC RUN and enters live calls. Browser console contains no errors.

The desktop browser is headless and has no speakers; visual/runtime verification
is not a human listening verdict or physical-phone performance measurement.
- Continued mouse-only observation showed 400 Pizazz, increased tier indicators,
  and different guest noticing/stepping poses while AutoPlay ran. Thus the browser
  check exercised actual accepted inputs and crowd changes, not just a toggled icon.
