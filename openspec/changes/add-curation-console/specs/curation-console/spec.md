## ADDED Requirements

### Requirement: Console route
The game SHALL serve a curation console at `/console` (with or without a
trailing slash) on the production deploy and on the local preview. The console
SHALL also open from `/?page=console` and `/#/console`, for a server that serves
only the root page. No other path SHALL open the console.

#### Scenario: Production path
- **WHEN** a browser opens `https://kumbias.tlatoani.net/console`
- **THEN** the console page loads, not the game

#### Scenario: Root-only server
- **WHEN** a browser opens `/?page=console` on a server that answers only `/`
- **THEN** the console page loads

#### Scenario: Game unaffected
- **WHEN** a browser opens `/`, `/?level=bar` or `/listen/console`
- **THEN** the game opens as before, not the console

### Requirement: Generated from the shipping data
The console SHALL list its content from the data files the game ships
(`levels/index.json`, `levels/*.json`, the ensemble and party sprite manifests,
the choreography file, the rendered music manifest and the close-up art folder),
so that a new level, take, atlas, clip, layer or close-up drawing appears
without a code change. A file that cannot be read SHALL be reported on the page
and SHALL NOT hide the rest.

#### Scenario: New level appears
- **WHEN** a new `levels/<id>.json` ships, listed in the index or not
- **THEN** the console lists that level, its room layers and every clip its data names, with references

#### Scenario: Every listed thing exists
- **WHEN** the console is built from the shipping files
- **THEN** every level id in the index, every take with files in the music manifest, every atlas in the sprite manifests and every close-up drawing is listed
- **AND** every listed picture and audio file exists in the bundle

#### Scenario: Broken file
- **WHEN** one level file is not valid JSON
- **THEN** the console shows that file as a problem and still lists every other level and take

### Requirement: Stable references
Every item SHALL show a short reference the owner can quote, and the data file
and JSON path it comes from. References SHALL be built only from data names:
`level / <id>`, `music / <level> / <take>`, `<level> / room`,
`<level> / layer / <id>`, `<level> / <atlas> / <clip>` for a clip a level names,
`<atlas> / <clip>` for a shared clip, `<level> / closeup` and
`closeup / <drawing>`. The same data SHALL always give the same reference.

#### Scenario: Clip reference
- **WHEN** a level `salon` names a clip at `stage.challengers[0].bow` drawn from atlas `terciopelo`
- **THEN** the console shows `salon / terciopelo / challengers[0].bow` and `levels/salon.json › stage.challengers[0].bow`

#### Scenario: Take reference
- **WHEN** the music manifest has `levels.garden.takes.low`
- **THEN** the console shows `music / garden / low` with its BPM, bar count and length

### Requirement: Start the game for review
For each level the console SHALL offer links that open the game: that level
alone (`?level=<id>`), on flawless autoplay (`&autoplay=flawless`), starting at
tier 0 to 4 (`&tier=<n>`), straight toward the outro (tier 4 on flawless
autoplay) and with the mixer (`&mixer=1`). It SHALL also link the whole campaign,
the campaign on flawless autoplay, the mixer, the listening page and `/qr`.

#### Scenario: Tier start
- **WHEN** the game opens with `?level=bar&tier=3`
- **THEN** the first phrase of the bar is judged and scored at tier 3 and its music starts on the tier-3 take

#### Scenario: Bad tier
- **WHEN** the game opens with `?tier=7` or `?tier=high`
- **THEN** it starts at tier 0, as without the parameter

#### Scenario: Link targets
- **WHEN** the owner taps FLAWLESS on the `salon` level
- **THEN** the browser opens `/?level=salon&autoplay=flawless`

### Requirement: Soundtrack player
The console SHALL play each rendered take, success phrase and bridge in the
music manifest, one at a time, choosing Opus where the browser plays it and AAC
otherwise. Each SHALL show its name, BPM and length, and while playing a
position bar the owner can drag to seek.

#### Scenario: Play a take
- **WHEN** the owner taps play on `music / cool-crowd / mid`
- **THEN** that file plays, any other track stops, and the position advances against its length

### Requirement: Rooms and layers
The console SHALL show each level's room plate with its cut-out layers in place,
animated on the beat at the level's mid-take tempo when asked, with toggles for
the layers, their outlines with ids, and a floor overlay drawn from the level's
`stage.floor` and marks (horizon, one adult's height, hero, challenger and guest
spots). Each layer SHALL be listed with its reference, kind, motion, period,
frame count and atlas position.

#### Scenario: Layer outlines
- **WHEN** the owner turns on layer boxes for the garden
- **THEN** each layer's box is outlined on the plate and labelled with its id

### Requirement: Clips at their real timing
The console SHALL play every clip the data names for an atlas at the clip's
beats from the data, at a tempo chosen from the rendered takes' tempos. That
covers shared choreography clips, a dancer's own clips, and any run of drawings
a level file names with `frames`.

#### Scenario: Level clip timing
- **WHEN** a level clip lists three drawings with `beats` 0.5, 1 and 0.5
- **THEN** at 120 BPM the console shows them for 0.25 s, 0.5 s and 0.25 s, then loops

### Requirement: Clips timed in code
Clips the game times in code (Mācron's groove, walk, turn and flourish; the
shared guests' crowd clips) SHALL be sampled from the game's own timing
functions. Drawings no clip names SHALL still be viewable, grouped by name and
marked "timing assumed".

#### Scenario: Code-timed clip
- **WHEN** the owner plays Mācron's `groove`
- **THEN** it shows `front_idle`, `groove_left`, `anticipate`, `groove_right` at a quarter beat each, as the game draws him

### Requirement: Clip player controls
The clip player SHALL show the frame index, frame count, drawing name and its
beats, and SHALL hold, step back, step forward and mirror.

#### Scenario: Frame index
- **WHEN** a clip of 8 drawings is held on its third drawing
- **THEN** the console shows `frame 3/8` and that drawing's name

### Requirement: Close-ups
For each level with an exit shot the console SHALL play the close-up from its
first to its last beat at the level's success-phrase tempo, using the game's own
placement of the actors, showing the beat and the drawings on screen. It SHALL
also list every close-up drawing with the data paths that use it.

#### Scenario: Close-up preview
- **WHEN** the owner opens the bar's close-up
- **THEN** the oil-gulp shot plays in a loop with the current beat and drawing names shown

### Requirement: Notes
Each item SHALL have a note box. Notes SHALL be kept in the browser across
reloads, keyed by reference. "Copy all notes" SHALL put every note on the
clipboard as plain text, each under its reference and data path. Clearing SHALL
ask first.

#### Scenario: Note survives reload
- **WHEN** the owner writes a note on `level / garden` and reloads
- **THEN** the note is still there

#### Scenario: Copy all
- **WHEN** the owner has notes on two items and taps copy all
- **THEN** the clipboard holds both notes, each preceded by its reference and data path

### Requirement: Phone first
The console SHALL be usable on a portrait phone: no horizontal overflow at 360
logical pixels wide, tap targets at least the size of a standard icon button,
and pictures load only for what the owner opens.

#### Scenario: Narrow screen
- **WHEN** the console renders 360 logical pixels wide
- **THEN** no layout overflows
