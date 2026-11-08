## MODIFIED Requirements

### Requirement: complete VIP conclusion
Upon the last required VIP success, the timer SHALL stop before the ending. The authored closeup SHALL depict Tlatoāni and tiny Mācron high-fiving, Tlatoāni saying exactly “Chingón”, and a gesture inviting Mācron to the adjacent seat. A wide view SHALL establish Covi and partygoers once verified art exists. Then every earlier opponent SHALL gather to share a massive tray of steaming tacos al pastor with Mācron and Tlatoāni, and the credits roll SHALL follow. Ending skip/reload SHALL preserve completion and produce at most one submitted result.

#### Scenario: skip the ending
- **WHEN** a completed run skips or reloads during the high-five sequence
- **THEN** completion persists and no duplicate result is submitted

#### Scenario: the tacos, then the credits
- **WHEN** the high five and the seat invitation have played
- **THEN** the opponents gather round the tray of tacos al pastor, and the credits roll after it

## ADDED Requirements

### Requirement: The restroom is a boss rush through the queue
The `restroom` level SHALL queue every earlier opponent, in campaign order from the back of the queue, and each SHALL call their own level's `hardestCombo`, read from that level's data, once for Mācron to answer. Passing SHALL swap Mācron's place with that opponent; failing SHALL drop him back one place. A slot whose level doesn't exist yet SHALL be left out. Each slot SHALL pass the fairness checks at the tempo it plays, slowing that slot rather than changing the combo's shape.

#### Scenario: a combo changes in its own level
- **WHEN** the salon's `hardestCombo` is edited
- **THEN** Don Terciopelo's restroom fight plays the edited combo, with no change to the restroom's data

#### Scenario: too fast for a combo
- **WHEN** a slot's combo fails the fairness check at its section's tempo
- **THEN** that slot plays at the fastest tempo it passes

### Requirement: The restroom's music and urgency rise with the queue
The restroom's music SHALL follow the queue position: slow country, livelier country, country rock, metal, then an original frenzy, joined by bar-aligned bridges. Mācron's off-turn idle SHALL show rising urgency with the position, up to his feet alternating quickly with his hands clasped low in front. It SHALL stay tasteful: no grabbing, no wet patch, no bodily sounds, no distress, and no one laughing at him.

#### Scenario: near the front of the queue
- **WHEN** Mācron reaches the last two slots
- **THEN** the frenzy plays and his idle is the fast alternating feet, hands clasped in front

### Requirement: The restroom's outro is the stall and the relief
The restroom's outro SHALL open the stall door in a rush onto the toilet, shown empty, and SHALL close it with Mācron inside, out of view. The close-up SHALL zoom into his eyes as they ease from wide to relieved, with the title QUÉ / ALIVIO.

#### Scenario: the last opponent steps aside
- **WHEN** the final queue fight is won
- **THEN** the latch turns green, the door bursts open on the empty, gleaming toilet, and the close-up on his relieved eyes follows

### Requirement: The tango is the hardest fight, by precision
The `tango` level SHALL be the campaign's hardest by complexity, not tempo: 3-3-2 syncopation at the top of the medium band and above it at tier 4, cortes as required silences, and the longest phrases in the game. Its full-tier pass rate target SHALL be the bottom of the spec's 70–80% band. On Mācron's turn the lead opponent SHALL dance with him.

#### Scenario: tapping in a corte
- **WHEN** the player taps during a corte
- **THEN** the phrase doesn't fail, but the combo glow breaks and a late mark shows

### Requirement: The VIP is a forgiving rueda of everyone
The `vip` level SHALL bring back every earlier opponent to call one phrase of their own signature figure, re-timed to the VIP's cumbia and checked for fairness, and Tlatoāni SHALL give the last call. A failed phrase SHALL be called again without a tier drop.

#### Scenario: a missed phrase in the rueda
- **WHEN** the player fails an opponent's phrase in the VIP
- **THEN** the same opponent calls it again and the tier holds
