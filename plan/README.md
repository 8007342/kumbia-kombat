# Multi-session work

`roadmap.md` lists remaining implementation in dependency order, with gates.
`music.md` covers composition, scheduling and synth integration.
`storyboard.md` defines the five-level beat sheet and ending.
`assets.md` covers character canon, animation inventory and art production.
`party-overhaul.md` proposes the authored dance, gradual crowd-interest and
living-environment overhaul; `party-overhaul-research.md` records its branch
audit, sibling lessons and primary sources. Production art is not yet delivered; the first behavior pass is recorded in
`session-party-pass.md`.
`session-foundation.md` and `session-garden.md` record actual delivered work and verification.

Feature contracts live in `../openspec/specs/`; proposed foundation scope is
in `../openspec/changes/kumbia-foundation/`. Update specs when a decision
changes, and record unresolved choices as such rather than inventing canon.

Use work branches matching `work/[0-9]{3,4}-[a-z0-9]{4}` → pull request to
`game` → pull request to `main`. Never implement directly on integration.

`play-and-transition-overhaul.md` adds the expressive input, playable peak, richer
score and staggered departure arc requested after the first design review.

Primary input/music/crowd research: `input-research.md`,
`music-overhaul-research.md` and `input-crowd-research.md`.

`session-sprites-autoplay.md` records the actual rectangle-renderer replacement,
reviewed sprite sources and the desktop AutoPlay follow-up.

`session-ensemble.md` records reusable seated audiences, perspective, wardrobe
variants, challenger choreography and ambient life. Authoring rules now live in
`../assets/art/STYLEGUIDE.md`; the three supporting research documents are
`crowd-animation-system.md`, `dance-battle-choreography.md` and
`party-perspective-and-life.md`.

`wardrobe-rendering-stability.md` records the hosted crowd-sprite investigation
and the normal-image fallback used to keep every guest visible on web renderers.

`dance-fluidity-pass.md` turns the post-crowd animation research into the next
production slice: authored dancer breakdowns and a music-owned floor exchange.

`opponent-depth-staging-pass.md` scopes the follow-up: richer opponent dances,
floor-derived approach/yield routes and close-but-safe audience framing.

Generative asset pipeline (2026-11-01): `asset-pipeline-requirements.md` is
the forge-facing requirements for the shared ComfyUI pipeline (row
`1935-k2ib`); `asset-inventory-contract.md` records the manifest schema the
runtime parses, the recolor gates and every needed clip;
`generative-animation-research.md` covers rig-driven pose control, identity
lock, pixel finishing, mocap and model licences.
- [session-handoff-2026-11-03.md](session-handoff-2026-11-03.md): read first; asset pipeline state before the tray restart.
`session-asset-pipeline.md` is the resume record for the pipeline coordination (peers, blockers, test steps).
