# Proposal: add the credits roll

## Why

The owner, 2026-11-08: "then we play some credits music, and show some text going up with
AAAAAALLL the software packages we've used :) likely in multiple columns and smaller text as
dependencies become seconnd, and third+ degree dependencies. how does that sound? "Built using
Tillandsias.org" then Podman, Fedora45, etc etc etc." The roll belongs after the VIP finale, which
isn't built yet, so it plays after the campaign's last end screen for now.

## What Changes

- A generated credits file, `assets/credits.json`, written by `tool/credits/build_credits.py`
  from the project's real dependency data, with every item's degree.
- A credits page: music, then text scrolling up, the header, the base, direct dependencies large,
  deeper ones in more columns and smaller text.
- It plays after the campaign's last end screen, and opens at `/credits/`, `?page=credits` and
  `#/credits`; the console links it.
- Music: a stand-in rendered take until credits music is made.

## Capabilities

### New Capabilities

- `credits-roll`: the data, the page, where it plays, and its music.

### Modified Capabilities

None. The console's new link is a button in its existing campaign card.

## Impact

`lib/credits/`, `lib/review_links.dart`, `lib/main.dart`, `lib/gameplay/garden_page.dart` (end of
campaign), `lib/console/` (the link and a looping `<audio>`), `web/credits/index.html`,
`pubspec.yaml` (the asset), `tool/credits/`. Later: the trigger moves to after the VIP's tacos
(`design-later-levels`).
