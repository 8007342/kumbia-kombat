# Proposal

## Why

The owner curates new content (levels, takes, rooms, dancers, close-ups) on a
phone and sends feedback in words. Today they can only reach content by playing
through the game, and their notes can't name what they mean precisely. They
asked for a `/console` page "to start the game at other stages, and to play the
soundtrack, see the backgrounds, the background animations, etc" with "names and
references, so I could give you meaningful feedback", and a `/qr` page "with a
pretty graphic thematic to our game and our characters, displaying proudly a
pretty QR code to https://kumbias.tlatoani.net".

## What Changes

- New page at `/console`: a phone-friendly curation console generated from the
  shipping data files. It lists every level with buttons that start the game
  there (alone, on flawless autoplay, at a chosen tier, or straight to the
  outro), plays every rendered take with tempo, length and progress, shows each
  room plate with its animated layers and a floor overlay, plays every atlas
  clip at its data timing with the frame index shown, plays each level's
  close-up, and keeps a note per item in the browser with a "copy all notes"
  button. Every item shows a stable reference and the data path it comes from.
- New review link `?tier=0..4`: the first phrase of a review run starts at that
  tier. Unknown or out-of-range values play as an ordinary start.
- New page at `/qr`: the share page, with a large scannable QR code for
  https://kumbias.tlatoani.net framed by the game's characters.
- Both paths work on the Cloudflare static-assets deploy and on any static
  server, by real entry pages plus the app reading its own URL.
- New dependency: the `qr` package (pure Dart encoder, the one `qr_flutter`
  builds on).

## Capabilities

### New Capabilities

- `curation-console`: the `/console` page: what it lists, the references it
  shows, how it starts the game for review, plays music and art, and keeps notes.
- `share-page`: the `/qr` page: what the code encodes, how it must scan, and
  how it is framed.

### Modified Capabilities

(none)

## Impact

- New code: `lib/console/`, `lib/qr/`, `lib/review_links.dart`; routing in
  `lib/main.dart`; `?tier=` read in `lib/gameplay/garden_page.dart` and
  `GardenSession.start`.
- New static files: `web/console/index.html`, `web/qr/index.html`.
- `pubspec.yaml`: `qr: ^3.0.2`.
- Tests: `test/console_catalog_test.dart`, `test/app_route_test.dart`,
  `test/qr_page_test.dart`; an outside decoder check,
  `tool/console/decode_qr.py`.
- No change to gameplay, music or art data. The game's own routes are unchanged.
