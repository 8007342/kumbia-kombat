# Design

## Context

The game is one Flutter web app with no router: `lib/main.dart` picks a home
page from the URL's query (`?capture=gestures`), and the game reads review
parameters (`?level=`, `?autoplay=flawless`, `?mixer=1`) itself. Production is
Cloudflare Workers static assets (`wrangler.toml`: `./build/web`,
`not_found_handling = "single-page-application"`). The local preview serves the
same `build/web` with a static runtime whose fallback behaviour isn't pinned.
The build uses Flutter's default hash URL strategy, so the path is never
rewritten by the app. `index.html` gets `<base href="/">` at build time.

All content is already data: the level files, the sprite manifests, the
choreography, the music manifest and the close-up json. A new level (the salon)
is being built in parallel and must appear in the console untouched.

## Goals / Non-Goals

**Goals:**
- `/console` and `/qr` load on production, on the preview and on any static
  server, without depending on one serving behaviour.
- Everything listed comes from data; references are derived, not hand-written.
- Music, clips, rooms and close-ups play with the game's own timing code where
  the game has it.
- Works on a phone; nothing heavy loads until opened.

**Non-Goals:**
- Editing data from the console. Notes go to the team as text.
- Shared or server-side notes. They stay in the browser.
- Starting the game mid-level, mid-outro or mid-close-up inside the game. The
  console previews close-ups itself; the game's outro is reached by tier 4 on
  flawless autoplay (two phrases).
- Crowd and band state at a tier start: they start cold.

## Decisions

**Routing: real entry pages, plus the app reading its URL.**
`web/console/index.html` and `web/qr/index.html` are copies of `web/index.html`
with `<base href="/">` fixed (the build only substitutes the root page). The
build copies them to `build/web/console/index.html` and `build/web/qr/index.html`,
so any static server answers `/console/`; Cloudflare's default
`auto-trailing-slash` redirects `/console` there. The app picks its page from
the first path segment, then `?page=`, then the hash. Three independent ways in;
the SPA fallback alone would leave the preview to chance. A test keeps the two
copies in step with `web/index.html`. Considered: `package:go_router` with a path
URL strategy (a new dependency and a router for two pages, and it would change
how existing links resolve); SPA fallback only (works on Cloudflare, untested on
the preview's static runtime). Off the web, `Uri.base` is the working directory,
so path routing is only read on the web.

**A pure catalog over raw JSON.** `ConsoleCatalog.build` takes file texts and
returns lists of items with references. It reads raw JSON, not the game's
validated `LevelRegistry`, so a level in progress that the game would refuse is
still listed, with any unreadable file reported as a problem. Clips are found
generically: any object in a level file with a `frames` list of strings is a
clip, offered for every atlas that has all of those drawings. Shared and dancer
clips come from the choreography file with the dancer's frame aliases applied.

**Code-timed clips sampled from the game's functions.** Mācron's frames and the
shared guests' crowd clips are chosen in code (`heroSpriteFrame`,
`ensembleClipFrame`). The catalog samples those functions every 1/16 beat and
merges runs, so the console shows exactly what the game draws.

**Close-ups through `ExitShot.sample`.** The console loads `LevelRegistry` for
the close-ups only and paints placements as `GardenSceneGame._drawCloseup` does,
in a 180-unit-wide 9:16 view. A duet's mirrored win isn't reproduced.

**Room layers at full swing.** The game's layer frame depends on the crowd's
swing and the tier; the console shows the liveliest case (full swing) on the
beat, since curation wants to see the whole range.

**Audio through an `<audio>` element.** Simpler than Web Audio for one track
with seeking and a duration; Opus where `canPlayType` says so, else AAC. The
game's mixer and transport are untouched.

**`?tier=`.** `GardenSession.start(tier:)` sets the fight's tier and starts the
transport on that tier's take; the page reads it once, for the first start.

**QR with the `qr` package**, error correction Q, a four-module quiet zone,
whole-pixel modules, dark ink `#101F29` on cream `#FFF8E7` inside a gold frame.
Characters dance below the code, never over it.

## Risks / Trade-offs

- [Entry pages drift from `web/index.html`] → a test compares them.
- [Cloudflare serving `/console/index.html` changes the URL to `/console/`] →
  the route reads the first segment either way.
- [Atlases are large pictures; a phone could run short of memory] → atlases
  load only when a card is open or scrolled into view, and rooms and close-ups
  only on SHOW/PLAY.
- [A clip that matches several atlases by drawing names is listed on each] →
  harmless; the reference names the atlas.
- [Tier start leaves crowd and band cold] → stated on the page and in the plan
  note.
