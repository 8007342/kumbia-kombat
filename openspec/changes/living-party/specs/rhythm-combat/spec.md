## MODIFIED Requirements

### Requirement: Audio-clock timing and phrase success

Judgment SHALL use monotonic audible-song time, corrected for measured output
and player input latency, never frame count. Perfect is absolute error ≤75 ms;
Good is ≤180 ms; later notes expire only after their late Good boundary.
A press SHALL consume at most one nearest unresolved matching-limb note.
Wrong-zone presses SHALL not consume another limb's note. Build-up garden responses SHALL pass with at least six of eight required notes
judged Good or Perfect; bar responses and garden/bar full-tier proof SHALL
require seven of eight. These thresholds are initial playtest settings; unplayed
responses SHALL never pass. Stray presses MAY
show feedback but SHALL not themselves fail an otherwise complete phrase.
There SHALL be a 250 ms chart minimum interval between required presses,
including across different limbs; the restroom MAY use 220 ms after playtests.
No narrower mandatory window SHALL be used for enthusiast difficulty.

#### Scenario: display stalls

- WHEN a render frame arrives late
- THEN judgments still compare event timestamps to audible song time
- AND missed notes are expired once, independently of the visual frame rate.

### Requirement: Optional after-tap flourishes

An authored required tap MAY offer a short relative-direction flick. Press-down
SHALL resolve its required note immediately. A subsequent movement from the same
pointer of at least 24 logical pixels, released within 400 ms, SHALL choose an
original ornament by its cardinal direction and earn 100 Pizazz once per logical
scored note. The gesture SHALL NOT require landing in another thumb region.
These distance/time settings are provisional playtest values. Cancellation or
omission SHALL NOT penalize required accuracy or progression. Offers SHALL leave
room for the full late-tap and flick window before the next required input's
early window. Release SHALL NOT generate another required tap. Already credited
replays MAY repeat cosmetics but SHALL NOT grant additional score or cumulative
crowd excitement. Flourishes SHALL produce localized transient crowd reactions
and musical responses without being required for full crowd support.

#### Scenario: flourish without a successful tap

- WHEN a player swipes a missed or unresolved note
- THEN no Pizazz is awarded and the required note remains unresolved.

#### Scenario: local expressive gesture

- WHEN a player presses a marked note successfully and flicks in a cardinal direction
- THEN the required note remains credited, that direction selects its musical ornament, and nearby guests react
- AND no other required note is consumed by the release.

#### Scenario: varied adornment chain

- WHEN newly credited flicks alternate directions within 24 musical beats
- THEN the expressive chain MAY build up to four stages and spread or extend transient neighbor excitement
- AND demonstrations do not prevent a chain spanning successive responses
- AND duplicate replay credit cannot grow the chain or award extra Pizazz.

### Requirement: Five progressively consequential fights

| Fight | Respect | Clean budget | Passes per tier | Full-tier passes | Consecutive failures before entrance reset |
| --- | --- | --- | --- | --- | --- |
| Garden / mansion gate | Mojo | 60 s | 1 | 2 | 5 |
| Bar | Swag | 80 s | 2 | 2 | 5 |
| Cool crowd | Flow | 95 s | 2 | 3 | 4 |
| Restroom rush | Nerve | 45 s | 1 | 3 | 4 |
| VIP | Presence | 110 s | 3 | 4 | 3 |

Each fight SHALL start at complexity tier 0 and progress through tiers 1–4.
The counts above apply per completed response phrase. A failed phrase SHALL
reduce complexity by one tier (floor 0), clear tier progress and full-tier
streak, and replay a learnable equivalent phrase. Success SHALL clear the
consecutive-failure count. Reaching tier 4 SHALL not clear a fight: the player
must pass its listed full-tier phrases while the complete arrangement plays.
Full-tier phrases SHALL vary through authored motifs demonstrated before each
response. Reaching peak crowd support SHALL NOT bypass these phrases.
Music changes SHALL be requested immediately but applied by the conductor at
its safe authored boundary. Entrance reset SHALL reset current-fight respect
and tier progress only, preserving completed fights, elapsed time, and earned
Pizazz. More lost progress and stricter failure thresholds make later resets
costlier; no lives, currency penalty, or game-over screen SHALL exist.

#### Scenario: failure at full complexity

- WHEN a player fails a VIP phrase at tier 4
- THEN tier 3 is requested, full-tier successes clear, and a retry follows
- AND VIP remains locked until tier 4 is rebuilt and four final phrases pass.
