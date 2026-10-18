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

### Requirement: Landing page announces the project under construction

The first screen SHALL display the title "KumbiaKombat" with an unmistakable
"under construction" motif (hazard-stripe styling), rendered through the
Flame engine.

#### Scenario: opening the landing page

- **WHEN** a visitor opens the deployed site
- **THEN** they see "KumbiaKombat" styled with construction-hazard stripes
  and an under-construction message

### Requirement: Deployable to Cloudflare with default actions

The repository SHALL be deployable to Cloudflare Workers with static assets
using the platform's default commands: build via `npm run build`, deploy via
`npx wrangler deploy`. The production custom domain SHALL be
`kumbias.tlatoani.net`.

#### Scenario: deploying

- **WHEN** an operator or CI runs `npm run build` followed by `npx wrangler deploy`
- **THEN** the site is deployed as a Worker with static assets and served
  at `kumbias.tlatoani.net`

### Requirement: main is protected; work flows through game/ then PRs

Direct pushes to `main` SHALL be rejected by git hooks with a clear
affordance. Work happens on `work/<id>` branches, lands on the `game`
integration branch, and `main` advances only through pull requests.

#### Scenario: pushing directly to main

- **WHEN** an agent runs `git push origin main`
- **THEN** the push is rejected with a message telling them to use
  `work/` branches, pull-request into the `game/` integration branch,
  then pull-request into `main`
