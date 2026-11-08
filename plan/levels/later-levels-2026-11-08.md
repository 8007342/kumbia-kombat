# The last three levels, the Sabre Dance question, and the credits roll

**Design, 2026-11-08, by the FINALE agent.** This follows the owner's direction in
`plan/levels/mansion-act-two-2026-11-08.md` ("Later levels", and the brief verbatim at its end).
Every name and choice here is a proposal the owner can reverse in `/console`. Facts and proposals are
kept apart: anything under "Facts" was looked up and is cited; everything else is design.

What's built in this batch: only the credits roll (section 5). `restroom`, `tango` and `vip` are design
only, for a later batch.

| # | id | Room | Music | Feel | Title |
|---|---|---|---|---|---|
| 10 | `restroom` | El Tocador, the restroom queue | slow country, into rock, into metal, into an original frenzy | the boss rush, semi-final tension | **QUÉ / ALIVIO** |
| 11 | `tango` | La Cava, the wine cellar | tango | the hardest, last fight | **QUÉ / CORTE** |
| 12 | `vip` | El Mirador VIP, the top-floor lounge | cumbia | the finale, release | **MUY / CHINGÓN** |

Then the credits.

## 1. The Sabre Dance: is it royalty free?

**Short answer: no.** The owner believes it is "likely royalty free now". Unless the facts below are wrong
in a way that a lawyer finds, it's protected in every market we ship to until at least 2038 (US) and
2049 (EU, Armenia), and in Mexico until the end of 2078. We should not use it, arrange it, or quote it.
This is research, not legal advice.

### Facts

- **The work.** *Sabre Dance* is a number from Aram Khachaturian's ballet *Gayane*, premiered 9 December
  1942 in Perm (then Molotov) by the Kirov Ballet in wartime evacuation. The score was revised in 1952
  and 1957. Khachaturian died on 1 May 1978. ([Wikipedia: Gayane](https://en.wikipedia.org/wiki/Gayane_(ballet)),
  [Wikipedia: Sabre Dance](https://en.wikipedia.org/wiki/Sabre_Dance), [Britannica](https://www.britannica.com/biography/Aram-Khachaturian))
- **It's actively licensed.** Boosey & Hawkes / Sikorski represent Khachaturian's works for the UK,
  Commonwealth (not Canada), Ireland, Germany and other territories, and Wise Music lists G. Schirmer
  as publisher of the Sabre Dance for the USA, Canada and Mexico.
  ([Boosey & Hawkes](https://www.boosey.com/composer/Aram+Khachaturian),
  [Wise Music Classical](https://www.wisemusicclassical.com/work/46919/Sabre-Dance-from-Gayaneh--Aram-Khachaturian))
  A publisher wouldn't list a work it couldn't license.
- **IMSLP** says his original works are generally still under copyright in Canada, and that in the US
  only works published in 1930 or earlier are clearly public domain.
  ([IMSLP: Khachaturian](https://cn.imslp.org/wiki/Category:Khachaturian,_Aram))

### Term, by territory

| Territory | Rule | Sabre Dance is protected until | Confidence |
|---|---|---|---|
| **Mexico** | Ley Federal del Derecho de Autor, art. 29: the author's life plus **100 years** ([mley.mx, art. 29](https://mley.mx/LFDA/articulo/29/)) | end of **2078** (public domain 1 Jan 2079) | The article's text was read in a law-reproduction site, not the DOF itself |
| **EU** | Directive 2006/116/EC, art. 1: life plus 70 years ([legislation.gov.uk copy](https://www.legislation.gov.uk/eudr/2006/116/body), [Wikipedia](https://en.wikipedia.org/wiki/Copyright_Term_Directive_2006)). The rule of the shorter term (Berne art. 7(8)) can't shorten it, because the source countries also give life plus 70 | end of **2048** (public domain 1 Jan 2049) | High |
| **Armenia** | Law on Copyright and Related Rights (2006), amended 30 Sep 2013: life plus 70 ([Wikimedia Commons summary](https://c.enwp.org/wiki/Commons:CRT/Armenia), [WIPO Lex](https://www.wipo.int/wipolex/es/text/192098)) | end of **2048** | Medium: from the Commons summary; whether the 2013 extension reached works of authors dead since 1978 wasn't checked in the statute (the old life plus 50 would still have run to 2028, so they were protected when it passed) |
| **Russia** (the ballet premiered there, in the USSR) | Life plus 70, and, from memory and **unverified**, plus 4 years for authors who worked during the Great Patriotic War (Civil Code art. 1281) | end of 2048, possibly 2052 | Low on the extra 4 years |
| **USA** | Soviet works were public domain in the US (no treaty relations, no formalities), until the Uruguay Round Agreements Act (17 U.S.C. §104A) restored foreign works still protected at home on 1 January 1996. The Supreme Court upheld it in *Golan v. Holder* (2012), a case brought by musicians over restored Shostakovich and Prokofiev scores ([Morgan Lewis](https://www.morganlewis.com/pubs/2012/01/copyright-restoration-upheld-supreme-court-says-foreign-works-can-be-removed-from-the-public-domain), [Brooklyn Law library](https://guides.brooklaw.edu/blogs/LibraryOverview/bls-library-blog/copyright-restoration-of-public-domain-works)). A restored work gets the rest of the term it would have had, which for a 1940s work is 95 years from publication | end of **2037** if first published in 1942; later if the score was first published later; the 1952 and 1957 revisions are later still | Medium. The 95-year term is from general knowledge, not a source read here, and **the first publication year wasn't found** |
| **Canada** | Life plus 70 since the 2022 amendment, which reached works not yet expired. IMSLP says his works are still protected there | end of 2048 | Medium |

We deploy worldwide from one build, so the binding date is the latest one: **Mexico, 2078.**

### Arrangements and recordings

- **Arrangements are their own works.** A new arrangement (jazz, rock, the 1960s pop covers, a
  piano reduction) is a derivative work with its own copyright on top of the composition's. A public
  domain composition wouldn't free anyone's arrangement, and this composition isn't public domain anyway.
- **Recordings are a separate right.** Every recording carries rights for the performers and the label,
  apart from the composition (EU: 70 years from publication of the recording; US: federal protection,
  pre-1972 recordings included since the Music Modernization Act). From general knowledge; not looked up
  in this batch. So even a public-domain melody played from someone's recording isn't free. "Royalty free"
  stock versions are licences, with terms; they don't make the work public domain.
- **A game is synchronisation.** Putting music to picture in a game needs a sync licence from the
  publisher (G. Schirmer for the Americas, Sikorski elsewhere) plus a master licence for any recording.
  That's a negotiation per territory, not something to build on.

### What's safe

What copyright protects in music is the melody and its specific expression, and sometimes a
distinctive combination of elements. Genre, tempo, instrumentation, a general mood and short
commonplace figures aren't protected. In *Gray v. Hudson* (9th Cir. 2022) a simple repeated ostinato was
held not protectable on its own. But *Williams v. Gaye* (9th Cir. 2018, "Blurred Lines") upheld a verdict
built on a combination of elements each unprotectable alone, over a dissent that said it protected a
"style". ([Fenwick on Gray v. Hudson](https://www.fenwick.com/insights/publications/katy-perrys-dark-horse-comes-out-in-front-ninth-circuit-affirms-no-infringement-in-copyright-lawsuit),
[WIPO Magazine on Blurred Lines](https://www.wipo.int/en/web/wipo-magazine/articles/blurred-lines-the-difference-between-inspiration-and-appropriation-39329))
The lesson: **an original piece in the same genre and energy is safe; an original piece that copies the
hook's shape, accompaniment and orchestration all at once is not.** Keep to the genre and change the
specifics.

### Recommendation

Compose an original frenzied piece in that spirit and call it ours: `restroom_frenzy` "Prisa" ("Hurry").
Generate it with ACE-Step from style words only, as every take so far was made. Never name, quote or feed
it the Sabre Dance. Don't describe the game's music as the Sabre Dance, or "like" it, in any player-facing
text, store page or trailer. Internally we can say what inspired it, as this note does.

### For the music agent: do's and don'ts for `restroom_frenzy`

**Do**
- Write the frenzy's own motif first, in a sheet under `tool/music/sheets/`, the way the other themes
  start. Give it a contour of its own: a hook built on leaps (fourths and fifths) or a rising broken chord,
  answered by a descending run. Lead with that.
- Use style words for the texture: `frenzied orchestral folk dance`, `presto`, `ostinato marimba`,
  `xylophone`, `driving snare`, `snare rolls`, `timpani`, `brass stabs`, `pizzicato strings`,
  `accented 3+3+2 grouping`, `minor key`, `urgent`, `comic chase`.
- Give the 3-beat accent its own place: the 3+3+2 grouping across a 4/4 bar (accents on 1, 2-and, 4) is a
  common folk and Latin figure and nobody's property. Put it in the snare and brass, under our motif.
- Pick a key and tempo by our own needs: the end of the ladder, around 168 to 176 BPM, so the queue's last
  fights are the fastest in the game. Use a minor key that suits our ladder's previous takes.
- Keep the metal guitars and double kick from the stage before it underneath the first frenzy bars, so it
  grows out of our own metal section instead of arriving as a quotation.
- Before shipping, have the owner listen blind beside the earlier restroom takes and ask: "does any
  passage sound like a famous classical piece?" A yes on any take means it's discarded, whatever its
  timing scores.
- Record seeds, words and workflow hashes in the take's provenance, as `assets/music/LICENSE.md` describes.

**Don't**
- Don't put `Sabre Dance`, `Khachaturian`, `Gayane`, `saber`, `sabre` or `sword dance` in any prompt,
  lyric field, tag, file name, sheet or seed note. Generative models can regurgitate famous pieces when
  named, and the name in our records would make any resemblance look intentional.
- Don't give the model a recording, a MIDI file, a transcription or a cover of it: no audio-to-audio,
  repaint, reference audio, "cover" mode or stem.
- Don't build the hook from fast repeated notes that step to the semitone neighbour and back. That figure,
  over a pounding ostinato with saxophone and xylophone colours, is the Sabre Dance's identity. One element
  alone is generic; all of them together is the combination *Williams v. Gaye* warns about.
- Don't use the saxophone as the lead over that texture. Our lead is marimba, then brass.
- Don't transcribe or "approximately" notate any part of it, even as a negative example in the repo.
- Don't trust timing scores or density numbers to say a take is original. Only listening can.

## 2. `restroom`: El Tocador, the boss rush (semi-final)

### The owner's direction

"the slow country theme shall slowly progress into metal themes, and turn into something like the Sabre
Dance ... Mācron's little feet start moving quickly alternating up and down, with his tiny hands holding his
crotch, as the music intensity goes up ... its cinematic exit shall be a rush stallroom open and toilet,
then a zoom into Mācron's little eyes in a sign of relief". And earlier: "defeat every previous opponent in
their hardest dance combo to switch places in the bathroom queue", "properly epic", "stress the pipelines
and specs to the maximum".

### The room

- **Id** `restroom`. **Title** EL TOCADOR (the powder room). After `terraza`, through the bridge
  `terraza_to_restroom`.
- **What it is:** the mansion's grand restroom antechamber, the most elegant room nobody wants to be
  queuing in. A long marble hall in pistachio green and cream, with gilded mirrors, a velvet bench, potted
  ferns, a brass umbrella stand, and at the far end **one** tall stall door in lacquered walnut with a
  gilded handle. Over it, a pictogram sign, and a latch indicator that shows red. No words on it: the
  colour says occupied.
- **The queue** runs along the right wall toward the door: every previous opponent, dressed as in their own
  room, all waiting. Mācron joins at the back.
- **An attendant** in a waistcoat, with a key on a ribbon, stands by the door (the storyboard's R01). He
  never fights; he nods each swap through.
- **Palette:** pistachio, cream marble, gilt, walnut, a single warm downlight on the door. The light
  narrows as the rush builds, so the door is the brightest thing on screen by the end.
- **Metric:** `Nerve` (from the storyboard).
- **Room life at full party:** the fern fronds tremble, the umbrella stand's umbrellas tap, the mirrors'
  gilded cherubs bob. The queue members who've been beaten cheer him on from the bench.

### The boss queue

The order runs from the back of the queue to the front, so it follows the campaign and its difficulty:

| Slot | Opponent | Hardest combo, already in their level data | Music section |
|---|---|---|---|
| 1 | The GateKeeper | The Velvet Rope (`garden`) | slow country |
| 2 | The Girls | Round Robin (`pool-garden`) | slow country |
| 3 | The Bartender | Last Call (`bar`) | country, livelier |
| 4 | The BlinBlin dancer | All That Glitters (`cool-crowd`) | country rock |
| 5 | The Pool Player | Tres Bandas (`billiards`) | country rock |
| 6 | Don Charolas | `LA TORRE DE CHAROLAS` (`comedor`, when it lands) | metal |
| 7 | Don Terciopelo | `EL GIRO DE TERCIOPELO` (`salon`) | metal |
| 8 | Siobhán and Las Tréboles | `EL MURO DE TACONES` (`galeria`) | metal into the frenzy |
| 9 | Tía Purpurina | `LA LLUVIA DE CONFETI` (`terraza`) | the frenzy |

- **One fight per slot:** the opponent steps out of the queue, calls their combo once as written (8 beats),
  Mācron answers. Pass, and they bow him past ("after you", a palm toward the door) and he swaps places.
  Fail, and he drops back one slot, the music drops back with him, and the one he'd passed gets another
  go. The level's own reset (R.reset) sends him to the back of the queue.
- **Between fights, a two-bar shuffle forward** with optional taps only. That's the breathing room, a
  small relaxation in each step of the tension.
- **The combos come from the data, never copied.** The level names each slot's level id, and the code reads
  that level's `hardestCombo`. A combo changed in its own level changes here. A level that doesn't exist
  yet leaves its slot out, so the queue grows as the campaign does.
- **Fairness at the new tempo:** each combo's notes are in beats, so they re-time to the restroom's tempo.
  Each slot must pass `fairnessProblems` at its section's tempo. Where one fails (the salon's half-beat
  triples go from 242 ms apart at 124 BPM to 188 ms at 160), that slot plays at the fastest tempo it passes,
  and the music section holds that tempo for that slot. The combo's shape is never changed to fit.
- **Each opponent needs their combo animation reused** from their atlas, and a "step aside, after you" clip.
  The second is new art for every opponent: nine clips. That's the pipeline stress the owner asked for.

### Music: the arc

One continuous piece in sections, each section a take in the ladder, chained by authored seams. The music
follows the queue position, not the crowd tiers: slot is tier here.

| Section | Slots | Style words | BPM |
|---|---|---|---|
| **A. Slow country** | 1–2 | `slow country two-step`, `pedal steel`, `acoustic guitar`, `upright bass`, `brushed snare`, `fiddle`, `relaxed`, `major key` | about 92 |
| **B. Country, livelier** | 3 | `country shuffle`, `telecaster twang`, `train beat`, `harmonica` | about 108 |
| **C. Country rock** | 4–5 | `southern rock`, `overdriven guitars`, `kick on four`, `organ` | about 126 |
| **D. Metal** | 6–7 | `heavy metal`, `palm-muted chugging`, `double kick`, `minor key`, `pinch harmonics`, no vocals | about 150 |
| **E. The frenzy** | 8–9 and the outro | `restroom_frenzy` "Prisa", section 1's do's and don'ts | about 168 to 176 |

- **Seams, the hard part** (`ground-rhythm-in-research`, "Seams sound continuous"): A to B on a pedal-steel
  bend into the train beat; B to C on a drum fill where the twang distorts; C to D on a held power chord
  that drops a fourth into the chug; D to E with the marimba ostinato entering *on top of* the metal for
  two bars, then the guitars thin out to the frenzy. Each seam is a bar-aligned bridge take, judged by
  listening, as the spec says.
- **Mācron's urgency is in the mix too:** a soft tick-tock layer (woodblock) grows across the sections and
  stops dead when the stall opens.
- **Fallback:** the synth score for the count-in and as a stand-in, as in every level.

### Chart character

- **The opponents' calls are their hardest combos, unchanged.** Mācron's answers are those same combos.
- **The shuffle bars** carry only optional taps: the "foot stomp" gesture, alternating, at the rate of
  his urgency.
- Density rises by itself, because the combos rise and the tempo rises. It's the most demanding chart
  in the game by notes per second, but not the most complex. The tango is.
- **Budget:** nine fights of 8 call beats and 8 answer beats plus 2 shuffle bars each is 216 beats. At the
  sections' tempos that's about 1 minute 45 seconds of a clean run (31 s of country, 13 s, 23 s of rock, 19 s of metal, 17 s of frenzy), the game's longest fight.

### Mācron's rising need

His urgency is a single value from 0 to 1, from the queue slot (and a little from the music section's
tempo). It drives his off-turn idle, never his dance moves, so play stays readable:

| Urgency | Off turn | Face |
|---|---|---|
| 0 to .25 | weight shifts from foot to foot | eyes flick to the door |
| .25 to .5 | knees together, small bounce | antenna starts to tremble |
| .5 to .8 | feet alternating up and down, quickly; hands clasped low in front of him | eyes wide, a single sweat drop |
| .8 to 1 | the same, faster, on the beat's subdivision; tiny hops | eyes wide and wobbling |

- **Tasteful, always:** hands are clasped together in front, at belt height, as a child does; never a
  grab, never a wet patch, no bodily sounds, no pain or distress faces, nobody laughs *at* him. It's comic
  urgency, and the queue sympathises: the ones he's beaten wave him forward. The style guide's rule holds:
  "Restroom humour is a pictogram and relieved movement".
- **New clips for Mācron** (front and back): `urgency_shift`, `urgency_knees`, `urgency_feet` (looping
  alternation, two speeds by frame hold), `door_glance`. Four clips.

### The cinematic outro

1. Tía Purpurina, the last in the queue, steps aside with a wink. The latch indicator over the door flips
   from red to green, with a bright *ding*.
2. **The rush:** a whip-pan into the stall: the door bursts open, light floods out, and the toilet
   gleams in it for a beat: white porcelain on a gilt dais, lit like a throne, a soft choir chord. The
   frenzy cuts to silence on the hit. Mācron dashes in and the door slams behind him (camera outside).
   Nothing inside is shown with him in it.
3. **Close-up:** silence, then the zoom into Mācron's little eyes: wide and wobbling, then slowly closing
   into contented arcs, with a long exhale puff and his antenna drooping, then giving one happy *ping*.
   The title **QUÉ / ALIVIO** sits under them.
4. Back to the wide shot: the latch shows red again, the queue applauds, and after a beat the door opens,
   Mācron steps out, dusts his hands at the gilded sink (a quick hand-wash), and walks off, light-footed,
   toward the cellar stairs. A bandoneón sigh starts the bridge `restroom_to_tango`.

**Supersedes:** the storyboard's R01 "no restroom interior imagery". The owner's newer direction asks
for the toilet; this keeps it tasteful by showing it empty and lit, and only Mācron's face for the relief.

## 3. `tango`: La Cava, the hardest and last fight

### The room

- **Id** `tango`. **Title** LA CAVA (the cellar). After `restroom`, through `restroom_to_tango`.
- **What it is:** the mansion's wine cellar beneath the house: brick vaults, oak barrels, racks of dusty
  bottles, a long tasting table pushed aside to clear a floor of worn stone flags. Candles in iron
  sconces, and one hanging lamp over the dance floor. A tango quartet (bandoneón, violin, piano, double
  bass) plays on a barrel-head stage in an alcove. The guests here are the night's last and keenest
  dancers: dark suits, fedoras, slit dresses, all elegant.
- **Palette:** deep oxblood and wine red, candle amber, brick, black. The darkest room in the game, and the
  one with the hardest light: a single pool on the floor.
- **Metric:** `Fuego` (fire).
- **Crowd as meter:** low tier, couples dance their own tango and ignore him. As the party rises they stop
  and form a ring (the ronda), and at the top the whole ring stamps the *marcato* with him.
- **Room life at full party:** the candle flames lean on the beat, bottles in the racks tremble, a portrait
  of a stern old vintner taps one foot.

### The opponent: Madame Boleo and El Ocho

- **Madame Boleo** (the *boleo* is tango's whipping leg flick). She. A tall, severe, magnificent
  older tango dancer: silver hair in a tight chignon with a red carnation, a black bias-cut dress with a
  high slit and a red lining, long black gloves, heels. Her expression is the opposite of Tía Purpurina's:
  utterly serious, until the very end.
- **El Ocho**, her partner (after the *ocho*, the figure-of-eight walk). He. Lean, slick black hair, a
  pinstripe double-breasted suit, a white silk scarf. He leads her on their turns and never speaks.
- **Like the Girls,** they dance as a pair on their turn, and on Mācron's turn **Madame Boleo dances
  with Mācron**: he leads, tiny and very serious, and she follows, so his taps visibly drive her ochos and
  ganchos. El Ocho watches from the edge with his arms folded, timing them.
- **Silhouette:** two long verticals in black, cutting diagonals; the carnation and the dress lining are
  the only red accents.
- **Hardest combo:** `EL CORTE FINAL`: a long walk into a sudden stop, two ganchos, a boleo and the final
  pose. For any later rematch.

### Music: tango

- **Score** `tango_cava` "Medianoche", with `tango_cava_success` and the bridge `tango_to_vip`.
- **Style words:** `tango`, `bandoneón`, `violin`, `piano`, `double bass`, `marcato in four`,
  `syncopated 3-3-2`, `arrastre`, `dramatic`, `minor key`, `staccato`, `rubato breaks`. Tango's classic
  rhythm feels are style, not anyone's song. As for every take, no song or composer name goes in.
- **Tempos:** about 116, 122 and 128 BPM in crotchets. Slower than the restroom, because difficulty here is
  precision, not speed (the owner's tenth round: "we can have fast simple levels, and slow complex levels").
- **Cortes:** the arrangement has written stops, whole beats of silence before an accent. The chart
  uses them.
- **Success:** 4 bars ending on the classic two-note close of a tango: a dominant chord, then a short tonic
  hit (*chan-chan*). That's a cadence, not a quotation.

### Chart character: the hardest

- **Syncopation on the edge.** The 3-3-2 *síncopa* puts notes on 1, 2-and and 4. Tiers 2 and 3 sit at the
  top of the 20–40% off-beat band the research change sets, and tier 4 goes above it, as the spec allows,
  ending every phrase on a strong beat.
- **Cortes are rests that must be held:** the chart's required silences. A tap during a corte doesn't fail
  the phrase (stray presses never do), but it breaks the combo glow and earns an ember mark. It's the one
  level where *not* tapping is the skill.
- **Hands on the bandoneón's staccato, feet on the marcato** (the research change's limb-to-metric-level
  mapping), with the ganchos as optional tap and drag hooks (the semi-circle, "wave") and boleos as the
  sideways "spin" gesture. Optional, as always, but the top tier is warmest only with them.
- **Longest phrases in the game:** 16-beat calls at tier 4, two bars of call and two of answer.
- **Pass-rate target** at its full-tier proof: the bottom of the spec's 70–80% band. It's the hardest,
  but a first clear in 1–3 attempts still holds.

### The cinematic outro

1. On the win, the music hits a corte: dead silence. Madame Boleo, mid-boleo, freezes in a deep dip in
   Mācron's tiny arms (he can't possibly hold her; it's a cheat of scale, as close-ups may).
2. **Close-up:** her stern face, upside down in the dip, slowly breaks into her first and only smile. She
   takes the carnation from her hair and puts it in Mācron's antenna clip, beside Don Terciopelo's rose,
   if the code can carry both. The title **QUÉ / CORTE** lands on the band's *chan-chan*.
3. Back to the wide shot: the ronda applauds; El Ocho unfolds his arms and gives one slow clap, then
   points up the cellar's spiral stair. Mācron climbs it toward the VIP lounge as the bridge's cumbia
   *güiro* begins to scratch from above.

## 4. `vip`: El Mirador VIP, with Tlatoāni and the tacos al pastor

### The room

- **Id** `vip`. **Title** EL MIRADOR (the lookout). After `tango`, through `tango_to_vip`. The last level.
- **What it is:** the mansion's top-floor VIP lounge: a glass-walled mirador with the city's lights all
  round, low velvet sofas in rose and gold, a velvet rope at the entrance with the host from the
  storyboard's V01, and papel picado strung across the ceiling. At its centre, raised, **Tlatoāni's
  seat**, and beside it a small empty seat, Mācron's (E04 and E05 in the storyboard).
- **Palette:** night blue glass, rose velvet, gold, and the warm orange of the taquero's grill.
- **Metric:** `Presence` (from the storyboard).

### Who's there

- **Tlatoāni,** seated, in pink, as the storyboard and the spec's canon fix. They don't fight. Their
  likeness follows the spec's canon; nothing about them is invented beyond what's committed. Covi stays the
  reserved silhouette until a verified reference exists.
- **Every opponent returns,** in the order Mācron met them, and the VIP's fight is a **rueda**, a circle:
  each opponent in turn steps in and calls one phrase of their *signature* (not hardest) figure, and Mācron
  answers. It's a victory lap through the whole night: the music modulates its accent to each one's style
  for that phrase (a polka accordion lick for Don Charolas, a bodhrán roll for Las Tréboles, a bandoneón
  sigh for Madame Boleo).
- **The last call** is Tlatoāni's: they rise from the seat for one simple, unhurried cumbia step, the only
  dance they do in the game. Mācron answers it, and the storyboard's high five follows.

### Music: cumbia, the game's namesake at last

- **Score** `vip_cumbia` "Kumbia Kombat", with `vip_cumbia_success`. The game is named after it, and the
  finale is the first cumbia in the campaign: it's the payoff.
- **Style words:** `cumbia`, `accordion`, `güiro`, `guacharaca`, `caja`, `tambora`, `bass`, `timbales`,
  `brass section`, `festive`, `major key`, `sonidera`.
- **Tempos:** about 96, 100 and 104 BPM: a relaxed, rolling cumbia after the tango's peak. Tension and
  relaxation: the finale is release.
- **Each opponent's phrase** gets a short stem-free accent layer in their instrument (rendered as a short
  take, crossfaded over the bar), so the medley is a cumbia that winks at each room.

### Chart character

- Each opponent's phrase is their signature figure from their own level's data, re-timed to the cumbia and
  checked for fairness, as the restroom does with hardest combos.
- **Forgiving:** this is a celebration. A failed phrase doesn't drop the tier; the opponent shrugs, laughs,
  and calls it again. The storyboard's V.reset ("all VIP progress lost") is replaced by this, a proposal:
  the hard part was the tango.
- Density sits at the campaign's middle; complexity comes from the variety of figures, not their speed.

### The finale and the outro

1. After Tlatoāni's step, the storyboard's E01 to E04 play as written: the high five on a musical accent,
   the caption, and the palm toward the small seat. The caption is the title: **MUY / CHINGÓN**, which
   keeps E04's "Chingón" and the two-word rule.
2. **The tacos:** the lounge doors swing open and Don Charolas, the head waiter, enters carrying a
   **massive silver tray of steaming tacos al pastor**, more than he can possibly hold, with a trompo of
   pastor turning on the tray and a pineapple on top. Steam curls up in pixel wisps.
3. **Wide shot, E05 extended:** every opponent gathers round the tray, each with their own touch: the
   GateKeeper takes two, the Girls share one, the Bartender pours salsa from a shaker, BlinBlin's chains
   glint as he leans in, the Pool Player chalks a lime, Don Terciopelo eats with impeccable posture,
   Las Tréboles take theirs in perfect unison, Tía Purpurina feeds one to Madame Boleo, who smiles a second
   time. Mācron sits beside Tlatoāni with a tiny taco and a tiny can of motor oil. Everyone eats.
4. The picture holds and dims, the cumbia's success tail rings out, and the credits begin (section 5).

## 5. The credits roll, built now

### What's built

- **The data:** `assets/credits.json`, generated by `tool/credits/build_credits.py` from the repository's
  real dependency data: `pubspec.yaml` and `pubspec.lock`, the Dart package graph in
  `.dart_tool/package_graph.json` (or, without it, the pubspecs in the pub cache), `tool/music/mixrs`'s
  `Cargo.lock`, the third-party imports of every Python tool and the packages and requirements in the
  forge's venvs, the node scripts' imports and `package.json`, the model and engine pins recorded in the
  committed provenance files, and a short hand-kept list of the base and the tools no lock file names
  (`tool/credits/base.json`: Tillandsias, Podman, Fedora 45, Flutter, Dart, Flame, CanvasKit, ComfyUI,
  Qwen-Image-Edit, ACE-Step, ollama and qwen2.5vl, ffmpeg, Blender, uv, Node.js, Python, Rust).
  Every item carries its degree: 0 for the base, 1 for what we use directly, 2 for what those use, 3 and
  more beyond. Run it again when dependencies change; a test fails when the lock files name a package
  the credits don't.
- **The page:** `lib/credits/credits_page.dart`. Credits music plays while the text scrolls up: "Built
  using / Tillandsias.org", then the base large, then direct dependencies large in one column, then second
  degree in more columns and smaller text, and third degree and deeper in more columns still, smaller
  again. A tap or drag scrolls it by hand; the close button leaves.
- **Where it plays:** after the last level's end screen, from a CRÉDITOS button there, and on its own
  after a few seconds. Later it moves to after the VIP's tacos. And from `/console`, which has a CREDITS
  link in the campaign card, and at `/credits/` and `?page=credits`.
- **Music: a stand-in.** It plays the garden's high take, the night's first theme, as a bookend. **Credits
  music is still to be made:** a slow, warm cumbia reprise of the VIP theme, made after the VIP's music
  exists, so it can quote our own melody.

### Choices made here, reversible

- The automatic start waits 8 seconds on the end screen, so the score and the title can be read first.
- Dev dependencies (flutter_test, flutter_lints) are credited, as degree 1 and marked "build": they built
  the game, even if they don't ship in it.
- Names are credited by their package name and version. Licences are kept in the data but not shown on
  screen, to keep the roll readable.

## What needs the owner

- The copyright verdict: to be confirmed by a lawyer before anything resembling the piece ships. The
  recommendation doesn't depend on it, because we don't use the piece at all.
- The names and titles: El Tocador, La Cava, El Mirador; Madame Boleo and El Ocho; QUÉ / ALIVIO,
  QUÉ / CORTE, MUY / CHINGÓN.
- The toilet on screen in the restroom outro (it replaces the storyboard's "no restroom interior").
- VIP's forgiving rueda in place of the storyboard's harsh VIP reset.
- Tlatoāni's one dance step, and whether they rise at all.
- The credits roll on a phone: speed, sizes, and the stand-in music.

## Verification, 2026-11-08

- `flutter test`: all 736 pass, in a symlinked run copy (`wt/finale-run`) through the heavy lock.
  New: `test/credits_test.dart` (the data covers every pubspec.lock and Cargo.lock package with a degree;
  sizes and columns shrink by degree; the roll rises; looping stand-in music; close; auto return; the
  shipping data on a 360 by 740 screen without overflow). Extended: the data-only campaign test now waits
  for the credits after the last end screen (they arrive 8 s later), the console test taps CREDITS, the
  route test covers `/credits/`, `?page=credits` and `#/credits`.
- `flutter analyze lib test`: no issues in the new code; 4 older infos in `lib/gameplay/battle_staging.dart`.
- `openspec validate`: `add-credits-roll` and `design-later-levels` are valid (one "long requirement"
  warning each).
- `build_credits.py --check` is idempotent: 142 items, 3 at degree 0, 42 direct, 46 second-degree, 51 deeper.
- **Not verified:** how the roll looks and reads on a phone, its speed, and whether the stand-in music
  starts on a real browser after the end screen. Nobody here has seen it run.
- **What went wrong:** the first generator run credited a node "package" that was a template string in a
  script, and duplicated two models under two names; both fixed. The Python walk first followed
  requirements that markers exclude (exceptiongroup); it now follows only installed ones.
- **Known limits:** Flutter's SDK packages (flutter, sky_engine, flutter_test) have no version in the lock,
  so they show without one. Windows-only crates appear because Cargo.lock lists them. Tool versions
  (FFmpeg, uv, Node, Rust) are read from whichever machine runs the script, so regenerating elsewhere may
  change them.
