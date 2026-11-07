# Adding a level

This measures how far we are from the owner's goal: "a few prompts and throwing some compute power at it". Keep it honest: when a code-bound item below goes away, delete it.

A level is one JSON file, `levels/<id>.json`, plus one entry in `levels/index.json`. The game checks both when it loads and refuses bad data: misspelt fields, unknown ids and limbs, marks above the horizon, broken charts and routes.

## Checklist

**Data only, no code:**

- [ ] `levels/<id>.json`. Copy `levels/bar.json` and change it:
  - `background`: an image under `assets/art/`
  - `music`: room score, success phrase, lead shape
  - `rules`: metric and difficulty
  - `chart`: limbs, offsets, variants, intro length
  - `stage`: floor plane, hero home, entrance, retreat and `challengers`, each with an atlas, mark and yield mark
  - `crowd`: budgets, guest marks and props. Each guest gets a chair
  - `scenery`: lamps and plants, and an optional waiter
  - `departure`: exit route. Waypoint y is relative to `originY`, so set `originY` to the hero's home y to write absolute marks
  - `copy`: the invitation for the title screen, and `clearedTitle`: two words, one to a line, the second from the party and music theme. It's the only text in a run, shown from an exit shot's contact. A level with no `exitShot` shows it only on the end screen, if it's the last level. An exit shot's fields, sounds and rules are in `assets/art/STYLEGUIDE.md`, section 8
- [ ] `levels/index.json`: add the level where it belongs. That entry and the one before it hold the bridge. Neighbouring level files don't change.
- [ ] `displayTotal`: the HUD's "/ 05". It's a stated number today, not the level count, because the HUD showed 05 with two levels. Remove the field to show the real count.

**Needs assets, from a pipeline and a person's review:**

- [ ] A background plate from a room spec, `tool/art/rooms/<id>.json` (see `tool/art/rooms/README.md`). The compiler refuses a layout that leaves the phone crop, puts story in the tap band, or sets a mark off walkable ground, and writes the level's floor and marks. A person still picks the plate by eye and checks the floor overlay. Lamps painted by the model differ from the spec's, so lamp glow marks need a look.
- [ ] A room score and a success phrase. Listen to them.
- [ ] Two bridges for an inserted level, or one for an appended level. Bridges go from one key to another, so each insertion orphans one.
- [ ] A challenger atlas: 64 poses, about 98 minutes of GPU per character (audit Q4).

**Still needs code or config:**

- [ ] A new challenger atlas: add its id to `EnsembleManifest.atlasIds` and its frame list to the switch in `ensemble_sprites.dart`. The level file can only name atlases on that list.
- [ ] A new art folder: list it in `pubspec.yaml`, because asset folders aren't recursive.

**Before calling it done:** run `flutter test`, which checks that everything a shipping level names exists on disk, then play the level. Only a person can approve the chart.

## What is still code-bound

| What | Where | Why it matters |
|---|---|---|
| Second and later challengers aren't drawn. The data is validated, but the scene draws the first | `garden_scene.dart` `_addChallenger` | Two dancers need scene work (audit item 5) |
| Guests are always seated, and always `guest0`–`guest2` by index | `crowd_interest.dart`, `party_layout.dart` `seatedGuestSlots` | No swimmers, standing tables or level-specific cast (audit item 6) |
| Crowd stays at 12 or fewer, and palettes come from the index | `crowd_interest.dart` | Same |
| Prop and ambient kinds are a switch: chair, table, umbrella, plant, candle | `garden_scene.dart`, `ensemble_sprites.dart` | A new prop kind needs code |
| Every atlas loads at startup and nothing is freed. The next background loads when its neighbour starts | `garden_scene.dart`, `garden_page.dart` | Separate job. Memory won't scale to many levels (audit pitfall 5) |
| Choreography frames and phase timing | `challenger_choreography.dart` | A level can't bring its own moves yet |
| Tier ladder (5 tiers) and the peak's one-dropped-note rule | `progression.dart` | Fine until a level wants a different shape |
| Hero's size, plant size, lamp radius, waiter speed | `garden_scene.dart` | Fine until a room needs other values |
| Generic screen text and the start screen's limb icons | `garden_page.dart` | Same for every level |
| No level tool: nothing yet turns a brief into `levels/<id>.json`, or runs the pipelines | `level-production-pipeline` | This is the "few prompts" part |

## Reference tables to retire

`fights`, `FightChart.garden` and `.bar`, `roomDepartures`, `partyRoomLayouts` and `CrowdStageProfile.stages` are still in `lib/`. The game doesn't read garden or bar from them. They remain as:

- the only record of the planned rooms (cool-crowd, restroom, vip), which stay planned
- what the existing tests build on, compared field by field with the JSON in `test/level_registry_test.dart`

So garden and bar exist twice until those tests move to the JSON. Do that after `work/1837-chor` merges, because it edits tests that use these names. `GardenSession` also still defaults to the garden when a caller omits its arguments. The game always passes a level, so only tests rely on this; remove it in the same pass.

**Don't add a new level to those tables.** A level in neither place fails loudly.

## Why JSON

The pipelines are Python and write JSON already, git shows each decision as a data diff, and a test can add a level from a string with no compile step. `levels/` sits outside `assets/` only because this work wasn't to touch that folder. Moving it there later is one `pubspec.yaml` line, one constant and the paths in the level tests.

## For the level brief

`level-production-pipeline` D1 should change before anyone writes briefs against it. A brief's `opponent` and flat `room` should compile to this file's `stage.challengers` (plural), `stage` marks and `scenery`. Its `bridge` belongs on the campaign entry, not the level. Camera and posture have no slot yet, because nothing in the game reads them.

## A pair of opponents

Add `stage.duet` to a level with two challengers: named `marks`, a list of `turns` that alternate leads, `offClip`, `partnerClip`, and an `exit`. Each dancer in `assets/art/ensemble/choreography.json` needs the two clips, reaching toward the picture's left in `partnerClip`. An example is the lawn, and the rules are in `test/duet_staging_test.dart`.
