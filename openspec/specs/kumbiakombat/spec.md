# KumbiaKombat

A kumbia-themed fighting game, landing now with an under-construction page.

## Purpose

KumbiaKombat will be a fighting game with kumbia music and culture as its
theme. Until the game exists, the project hosts a public landing page that
announces it is under construction.

## Requirements

### Requirement: The app runs as a Flutter web app on the Flame engine

The project SHALL be a Flutter web application using the Flame game engine,
buildable to static web assets with `flutter build web`.

#### Scenario: building for web

- **WHEN** an agent runs `npm run build` (which runs `flutter build web --release`)
- **THEN** static web assets are produced in `build/web/` ready for deployment

### Requirement: Portrait start screen introduces the current fight

The first screen SHALL introduce Kumbia Kombat and the current room, with an
explicit audio-start action, one-thumb controls and reduced-motion options.
The game SHALL never begin scoring before successful user-activated audio.

#### Scenario: opening the prototype

- **WHEN** a player opens the local game
- **THEN** they see Kumbia Kombat, the Garden, and a clear start action
- **AND** they can use the default thumb controls and opt into a calm camera before play

### Requirement: Deployable to Cloudflare with default actions

The repository SHALL be deployable to Cloudflare Workers with static assets
using the platform's default commands: build via `npm run build`, deploy via
`npx wrangler deploy`. The production custom domain SHALL be
`kumbias.tlatoani.net`.

#### Scenario: deploying

- **WHEN** an operator or CI runs `npm run build` followed by `npx wrangler deploy`
- **THEN** the site is deployed as a Worker with static assets and served
  at `kumbias.tlatoani.net`

### Requirement: main is protected; completed work integrates through game

Direct pushes to `main` SHALL be rejected by git hooks with a clear
affordance. Work happens on `work/<id>` branches, lands on the `game`
integration branch through pull requests or owner-authorized milestone integration.
`main` remains protected and advances only for a completed release.

#### Scenario: pushing directly to main

- **WHEN** an agent runs `git push origin main`
- **THEN** the push is rejected with a message telling them to use
  `work/` branches, pull-request into the `game/` integration branch,
  then pull-request into `main`

## Next product phase

The public production site may retain its earlier bootstrap landing until work and release PRs land.
The campaign behavior is defined in `../rhythm-combat/spec.md`,
`../dynamic-music/spec.md`, `../art-direction/spec.md`,
`../run-lifecycle/spec.md`, and `../leaderboard/spec.md`. The current branch introduces the playable audiovisual slice for review; physical-device acceptance remains a release gate.
The integration branch is named `game` (without a trailing slash), and the
work-ref grammar in `.tillandsias/branch-discipline.yaml` is authoritative.
