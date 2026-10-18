# Art, animation, camera and visual story

## Purpose

Define recognizable pixel characters, readable controls, beat-driven cameras and inferred visual storytelling.

## Requirements

### Requirement: readable retro identity
The game SHALL use 80s pixel art, portrait composition, nearest-neighbor sampling and a nominal 180×320 art viewport. UI SHALL respect safe areas independently of that viewport. Integer scaling is preferred; fractional letterboxing is allowed. Raster sheets SHALL have transparent gutters, consistent pivots and documented frame rectangles. Camera transforms SHALL never move input zones or judgment cues.

Mācron SHALL be a toy-sized ivory robot: compact rounded shell, dark screen, cyan facial indicators, two arms, short legs, one small antenna orb, subtle modular right-arm cuff. Mācron SHALL remain much smaller than Tlatoāni. Tlatoāni SHALL be a friendly warm-pink axolotl with coral external gills, one tail, cream clothing and teal accents, no facial hair. Costume changes SHALL preserve silhouettes. The reference art outranks approximate palette values. Pixel translation is authorized by the project's requested retro style.

Covi's identity is not established by the supplied canon. A reserved seat and non-identifying silhouette MAY appear in prototypes; final Covi art SHALL remain blocked until a verified reference exists. Do not invent Covi's species or appearance.

#### Scenario: silhouette check
Given character art at native size and a flat background, when face details are hidden, Mācron's antenna/compact robot outline and Tlatoāni's gills/tail SHALL remain recognizable and distinct.

### Requirement: five visually inferred social gates
| Stage | Respect | Challenger silhouette | Environmental story | Acceptance action |
|---|---|---|---|---|
| 1 Garden entrance | Mojo | Tall broad doorkeeper, rounded hat | Mansion gate, warm party windows, hanging Tillandsias; guest queue steps aside | Rope lifts and open palm ushers Mācron in |
| 2 Bar | Swag | Rolled-sleeve bartender, shaker | Bottle silhouettes, counter, dancing reflection | Bartender slides a festive drink and opens side passage |
| 3 Cool crowd | Flow | Angular dancer with dramatic jacket | Loosely closed circle of dancers, disco reflections | Circle opens; challenger mirrors Mācron's signature step |
| 4 Restroom dash | Nerve | Compact attendant with large key ring | Short corridor, restroom pictogram, impatient foot tapping | Attendant spins key; door opens, quick relief bounce |
| 5 VIP | Presence | Elegant host with sweeping sash | Velvet rope, elevated lounge, Tlatoāni visible beyond | Host bows slightly and draws rope aside |

The game SHALL render the five stages in the order above. Challengers are original provisional designs, not portrayals of canon characters. Fighting is dance, timing and social play: no damage, humiliation or weapons. The owner is Tlatoāni; the venue is Kumbia Koliseum. Acceptance requires gameplay mastery at full complexity, not merely a cinematic trigger.

#### Scenario: first run without explanatory text
Given a new player, when a gate is reached, the challenger blocks the obvious forward path, demonstrates a phrase and presents the matching cue icons. Successful mirroring visibly warms their expression and opens the path. A title card or lore paragraph SHALL NOT be required.

### Requirement: rhythm-safe portrait camera
The baseline SHALL be an over-the-shoulder rear view of Mācron centered low in frame, walking toward the party on a converging floor plane. Fake depth uses scale, occlusion and three or more parallax layers, not a mandatory 3D renderer. Background assets include skyline/back wall, mid-scene props, floor, foreground occluders and independent emissive accents. Floor travel advances with progress rather than unrestricted navigation.

Side-on 2D dance framing MAY appear on phrase boundaries. A turn is a 0.5–1 beat eased transition between authored views, not arbitrary rotation of flat sprites. Zoom range SHOULD stay 1.0–1.12 during active cues; background pan SHOULD remain within 6% of viewport width. Cut timing derives from the music transport. Silhouettes and cue contrast must survive every view. During cue judgment, avoid shake or abrupt scale changes. Reduced-motion mode disables orbit, shake, snap zoom and curved decorative particles while retaining readable musical pulses. No strobing; light pulses stay below three flashes per second.

#### Scenario: flourish camera
Given an optional successful swipe after a required tap, when the ornament is accepted, Mācron may spin and the scene may pan on the next beat. Cue positions, timing and required tap regions remain fixed.

### Requirement: four quadrants and a readable spiral
The screen SHALL be divided into four stable hit regions: LH upper left, RH upper right, LF lower left, RF lower right. Icons are body-relative symbols, not demands for the player's particular limb. Four supplied SVG silhouettes SHALL provide the shared visual vocabulary. The entire quadrant is a target; tiny corner icons are orientation markers only. The icon layer MAY be faint at rest but incoming required cues SHALL remain high contrast. Shape and fixed position, not color alone, identify targets.

Incoming notes SHALL originate near the center and move outward on authored curved paths toward their quadrant's fixed judgment ring. Every note also has a remaining-time ring so path curvature cannot conceal timing. Spawn lead is measured in beats and MUST remain readable at the fastest authored tempo; start at 2 beats and tune on real phones. Avoid overlapping paths between different quadrant identities. Final half-beat motion SHALL approach monotonically. Distinct repeated-note spacing communicates double taps. Optional swipe paths use dashed trails and a hollow destination, required taps use filled icons. Missing an optional swipe SHALL not show failure feedback or reduce progress.

#### Scenario: one-handed reach
Given a player holding a phone in one hand, when testing the shortest and tallest supported portrait sizes, each required input is possible through the reachable portion of its large quadrant. If upper quadrants are inaccessible, a thumb-reach option SHALL remap the same four logical targets into a lower-screen 2×2 pad without altering note identity or scoring. Incoming cues route to those new anchors. No mandatory simultaneous taps or multitouch chords.

### Requirement: minimal interruption and ending
Stage introductions and acceptance beats SHOULD take 1–2 bars each and remain skippable after first exposure. Progress comes from gate opening, crowd response, drink/door/rope props and music. Short approval text MAY be “OK, you cool”. Restroom humor is a pictogram and relieved movement, never explicit imagery.

The final ranked timer stops at completion of the final required challenge; the ending is not timed. A 4–6 second authored closeup shows Tlatoāni lowering his hand to tiny Mācron's height, their high five, the exact caption “Chingón”, and an invitation gesture to the adjacent seat. A wide view establishes Tlatoāni, Mācron, Covi's verified character and other partygoers in the VIP lounge. Arcade initials entry follows when the run qualifies. Skip/reload SHALL still commit the completed run once and preserve access to results.

#### Scenario: VIP invitation

- **WHEN** the final required challenge completes
- **THEN** the timer SHALL freeze and the high five, “Chingón” caption and invitation SHALL play once.

### Requirement: Asset acceptance
Art SHALL be inspected at native resolution, on a physical portrait phone, against all five palettes. Sheets require frame metadata, loop tags, anchor, facing, license/provenance and palette. A concept sheet is not a playable sprite atlas until frame cleanup and identity checks are complete. Animation markers SHALL be driven by musical beat or gameplay state; cosmetic animation cannot change judgment time.

#### Scenario: runtime atlas acceptance

- **WHEN** an atlas is registered for a level
- **THEN** its frame metadata, provenance and native-resolution character review SHALL pass before runtime use.
