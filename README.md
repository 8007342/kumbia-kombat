# KumbiaKombat

A kumbia-themed fighting game — under construction. Today the repo serves a
Flame-rendered landing page announcing that.

Live at: https://kumbias.tlatoani.net (Cloudflare Worker, static assets)

## Stack

Flutter with the Flame engine (games and graphics), built to static web
assets and deployed to Cloudflare Workers.

## Develop

```bash
flutter run -d chrome   # local dev
flutter test            # widget tests
flutter analyze         # lints
```

## Build & deploy (Cloudflare defaults)

```bash
npm run build           # flutter build web --release into build/web
                        # (downloads a pinned Flutter SDK if none is installed)
npx wrangler deploy     # deploys build/web as a Worker + binds kumbias.tlatoani.net
```

## How this project is organised

- `openspec/`: what the app should do, written as short specs. Change the
  specs first, then the code.
- `plan/`: work that takes more than one session. Each line says what is left.
- `lib/landing/`: the Flame landing game (hazard stripes + title).
- `tool/build.sh`: the self-bootstrapping web build used by `npm run build`.

## Branching

`main` is protected — direct pushes are rejected. Do work on `work/<id>`
branches, land them on the `game` integration branch by pull request, then
pull-request `game` into `main`.

## Kumbia Kombat design work

The next version is a portrait, one-handed rhythm dance game: five original
adaptive synth songs carry Mācron from the mansion garden to Tlatoāni's VIP
section. Required taps earn respect; optional swipes earn Pizazz. A clean run
targets 5–8 minutes, with resumable progress and a global arcade Top 10.

See [product context](openspec/project.md), [feature specifications](openspec/specs/)
and [multi-session roadmap](plan/roadmap.md). The current app still displays
the landing page; foundation code and assets are not yet wired into a playable
campaign. Work branches follow the seed's `work/1234-abcd` grammar.

### Review the original music

```bash
node tool/music/generate.mjs       # regenerate five scores and 25 MIDI variants
node tool/music/validate.mjs       # validate scores and MIDI attack/release pairs
node tool/music/build_preview.mjs  # compile the standalone browser synth room
# Serve build/music-preview/ with a local static HTTP server.
dart --packages=build/music-preview/packages.json tool/music/transport_check.dart
```

The score room plays synthesized notes live and lets you change arrangement
tiers and trigger ornaments. It is separate from the Flutter landing page.
It stops at each written score's end; repeatable gameplay vamps and the
combat/audio adapter remain planned. Music quality requires listening review.
