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
