# Design

## Context

Motivation is in proposal.md. Inputs that exist: character, style, backend and motion
definitions and `art build` (`character-sprite-pipeline`); shot files
(`cinematic-shot-pipeline`, designed only); score briefs and arranger
(`score-composition-pipeline`, on `work/1834-scor`). Runtime wires two rooms in
`rooms.dart`, charts as `FightChart` constants in `garden_session.dart`, and
`garden_page.dart` hard-codes the `garden_to_bar` bridge. `RoomDeparture`, `fights`,
`CrowdStageProfile` and music already cover all five rooms.

**Owner decisions (2026-11-03).** Music is free but dominantly Latin, with hints of
other styles. Each level's music follows its character: Gatekeeper reads as salsa,
Bartender as electronic/synth. Opponent variants are palette-only for now, with hats,
gloves, chains and coats a later pass. Level 4 is reserved for chill country building to
heavy metal. Levels 1–2 are the current work.

## Goals / Non-Goals

**Goals:** one prompt can start a level; retrofit levels 1 and 2 as the proof; level 3
needs only a prompt plus known gaps; no pipeline logic is duplicated.

**Non-Goals:** authoring level 3; a parser for prompts in pipeline code; automated taste
judgment; replay mode; generic tools for Kumbia-specific data.

## Decisions

### D1. Prompt, then brief, then deterministic builds

Same split as character edits and score briefs: an agent expands the prompt once into
`tool/levels/<id>.json`, and the owner edits and approves it. Pipelines read only
the brief, so git shows every creative decision.

```jsonc
{ "id": "bar", "order": 2, "stat": "Swag", "prompt": "…the owner's words…",
  "status": "approved",
  "opponent": { "character": "bartender", "variantPolicy": "palette-only",
                "variants": { "replay-1": { "apron": "#1F4E7A" } } },
  "audience": { "silhouettes": ["guest-woman", "guest-man", "guest-host"],
                "wardrobes": ["teal", "blue", "coral", "gold"], "clips": "guest-23",
                "formation": "bar-counter", "budget": "bar" },
  "room": "bar",
  "music": { "base": "digital cumbia", "brief": "bar_swag",
             "characterInfluence": "Bartender's synth look: arpeggiated keys, drum-machine pulse over guacharaca",
             "hints": [{ "style": "synthwave", "enters": "tier 3", "weight": "light" }] },
  "chart": { "draft": "bar", "motifs": ["RH — LH RH", "RF — LF —"], "budgetSeconds": 80 },
  "sequences": { "outro": "bar.outro", "reset": "bar.reset" },
  "bridge": "bar_to_crowd" }
```

Alternative: a single generator that does all of it from the prompt at build time.
Rejected: nothing to review, nothing reproducible.

### D2. The level tool only compiles and coordinates

`level plan <id>` calls each pipeline's own planner and merges reports. `level build` runs
them in gate order. A level holds references and adds nothing to keys beyond what the
referenced definitions already contain, so shared characters are never rebuilt because of
a level edit.

### D3. Gates

`brief → proofs (opponent 12 drawings, score candidate) → full generation → in-game
review → promote`. Approvals are recorded by hash in `tool/levels/<id>.approvals.json`,
so an edit to a brief section invalidates only that section's approvals.

### D4. Rooms reuse the stage graph with their own stages

`layout mask → generate base → separate layers → fill behind → emissive → review →
calibrate → promote`. The base and its masks use the same workflow approach and backends.
Separation is by authored depth masks in the definition, not automated segmentation at
first. Background fill uses inpaint on the hidden regions. `image.generate`'s `layout` and
`mask` inputs may be sufficient for plates, tested on the bar.

Native size is 180×320 plus margins, per `plan/assets.md`. Text is forbidden in art, and
no person may appear; both need human review, as no detector is planned.

### D5. Audience and groups

Guests become character definitions with `role: audience`, sharing silhouettes, using the
existing `party_palette.frag` wardrobes. This matters: their cloth deliberately sits
*inside* the recolour gates, the opposite of opponents, so `recolor` is declared per
region and the gate check inverts for them.

A **formation** file places figures on floor marks with facing, clip and layer order:
`{ "id": "crowd-semicircle", "members": [{ "figure": "lead", "mark": [0.5, 0.43], "view": "front" }, …],
"states": { "closed": {…}, "open": {…} } }`. Figures keep separate atlases, since the game
draws each as a floor-anchored object. A new CPU check composes a formation at native size
for the group rules in the spec. See `plan/level-3-readiness.md` for what level 3 asks of it.

### D6. Chart drafting stays conservative

Charts move from Dart constants to data with the same fields as `FightChart` (limbs,
offsets, call beats, variants). Drafts come from the storyboard's motifs and the score's
accents, then pass rule checks and a scripted autoplay run. Only a person playing it can
approve. The tool may draft, but must never change judgment rules or window sizes, and
tuning values stay in combat config, per the storyboard.

### D7. Music influence is declared, not inferred

`music.characterInfluence` is required text plus a named base from a Latin list
(for example salsa, son, cumbia, digital cumbia, boogaloo, mambo). It maps to the
score brief's groove, voices and hints. The gates for this are structural only: a base
must exist and the base groove must stay present in every tier. Dominance is judged by ear.

Starting direction for review: Garden as salsa (montuno, clave, brass); Bar as digital
cumbia (synth keys and drum machine over guacharaca). These may replace the current
briefs' colours, and the existing `bar_swag` candidate fits closely.

### D8. Palette-only policy and later accessories

`variantPolicy` defaults to `palette-only`, and the character pipeline's garment-shaped
variants stay implemented but blocked at the level layer. Accessories later become garments
from the same shape library through masked mode, so nothing else changes.

### D9. Runtime as data, in small steps

Replace `partyRooms` constants with a level registry, look up bridges by room, and load
charts from data. Tests assert levels 1 and 2 play identically before and after. Formations
and layers follow once rooms use them.

### D10. What stays in this project

Level briefs, room and character definitions, and the music brief and arranger are Kumbia's
until a second project needs them. The generic facilities they rely on (stage cache, impact
analysis, studio job bindings, review surface) are catalogued in
`plan/forge-generic-services.md` for the host to own.

## Risks / Trade-offs

- [One prompt invites over-trust] → brief approval is mandatory, and costs are shown first.
- [Rooms are less proven than characters] → prove on the bar before declaring the pipeline ready.
- [Layer separation may look cut-out] → review at phone size; fall back to fewer layers per room.
- [Style hints can overwhelm the Latin base] → the base must stay in all tiers, and the owner listens.
- [Scope grows across four changes] → this one adds no generation of its own, and levels 1–2 ship first.
- [Character pipeline assumes a single figure on a canvas] → formations compose separately rendered figures.

## Migration Plan

1. Write briefs for garden and bar that reference existing and in-progress work; running
   them must plan to reuse it, not rebuild.
2. Move charts and room wiring to data behind tests with unchanged behaviour.
3. Prove rooms on the bar. Rollback is per-asset through git, and the flat backgrounds stay
   until accepted layers replace them.

## Open Questions

- The exact Latin base list grows with listening; start with those in D7.
- Whether `image.generate`'s `layout` is enough for plates: decided by task 4.2.
