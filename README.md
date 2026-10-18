# Kumbia Kombat

A portrait, one-thumb rhythm dance game built with Flutter and Flame. Mācron
mirrors challengers' moves to earn a way from the mansion garden to Tlatoāni's
VIP lounge. Required taps earn respect; optional swipes add musical flourishes
and Pizazz. A full clean campaign targets 5–8 minutes.

## Current prototype

The app now plays the garden and bar: original live synth music, four
SVG limb zones in a compact lower thumb pad, beat-varying destinations, curved incoming cues, call/response, Mojo progression, optional
swipes, repeated-failure retreats and in-memory pause recovery. A matching
success phrase and tonal bridge carry the garden into the bar without
resetting the shared audio clock. The bar has its own Swag chart and sign-off. Generated
pixel-art settings and challengers accompany an animated code-native Mācron.

The five-level [storyboard](plan/storyboard.md), [feature specs](openspec/specs/)
and [remaining plan](plan/roadmap.md) distinguish delivered work from future
animation, rooms, save/reload, ending and global leaderboard integration.
Current challenger assets are starter single poses; production animation is pending.
Native synth audio is not yet supported; play the prototype in a browser.

## Develop and review

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --hot
flutter analyze
flutter test
npm run build                  # release web, including local CanvasKit
node tool/prepare_preview.mjs  # also put standalone score room at /music/
```

For the forge's working local preview, publish the root project with the
managed Wrangler runtime. See [preview handoff](plan/session-garden.md) and
[forge diagnostics](FORGE_DIAGNOSTICS.md) for the current dev-route issue.
The score room lets you play all five songs and change tiers independently.

```bash
node tool/music/generate.mjs
node tool/music/validate.mjs
node tool/music/build_preview.mjs
dart --packages=build/music-preview/packages.json tool/music/transport_check.dart
```

All five room scores are original MIDI-style note data with five arrangement
and tempo tiers plus four adornments each. Five short success themes and
four connecting bridges are also authored and auditionable. MIDI files are review exports, while
runtime notes are synthesized live. Speaker/phone listening and timing
calibration remain essential; compilation alone does not establish quality.

## Branching and deployment

Use seed-valid `work/1234-abcd` refs. Integrate tested milestones into `game`;
reserve protected `main` for the complete release. The owner explicitly
authorized milestone integration in this session. The foundation has landed
on `game`; tested garden/bar milestones follow the same integration path.
`npm run build` builds static web files; `npx wrangler deploy` deploys the
Worker/static assets at https://kumbias.tlatoani.net . Local preview does not
deploy to production. The live public site may still show the earlier landing
until integration and release PRs are merged.

Music/art provenance lives beside the assets. The local UI font retains its
SIL Open Font License in assets/fonts/. No global leaderboard service is
currently deployed by this prototype.
