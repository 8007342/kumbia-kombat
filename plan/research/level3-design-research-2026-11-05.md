# Pool garden level: design research

Researched 2026-11-05 for discussion with the owner, revised the same day after five owner rulings.
Options and recommendations only: no canon doc, code, chart or art has changed. Nothing here has been
played or heard. Companion: `plan/research/level3-engine-audit-2026-11-05.md` (engine cost).

## Summary

The pool garden is an **added** level, not a replacement. Recommend placing it straight after the Bar, with
Cool Crowd following it, which makes a sensible route through the house but pushes a clean run past the
8-minute target and clashes on tempo with Cool Crowd. A growing campaign therefore needs a length and ranking
decision first. Pending the teacher, recommended style is **cha-cha-chá in charanga colour (flute and strings)**,
with **Dominican-style bachata as runner-up**; the interview could reverse that order. Because the owner has
ruled that visuals are independent of the controls, the pair no longer has to spell out limbs. Recommend
**trading phrases**: two rhythmic personalities share one call, so the pair shapes the chart itself, while their
bodies are free to do any move that hits the beat. A confirmed choreography grammar follows from the same ruling.
The signature step comes from the teacher, so this file only specifies what to ask for and where it plugs in. The
Gatekeeper's fist bump fits the existing 16 beats, and no transition should add bars. Cast the two women as
clearly grown friends or sisters in full dance dresses, show swimmers only through distant glass, and ban
robot-height shots of them: Mācron's height makes that the main framing risk.

## How to read this

- **[S]** a source states it, numbered note at the end. **[O]** observed in this repo or the canon file.
  **[I]** my inference or judgement. **[T]** may change after the teacher interview.
- **Limits.** `WebFetch` and `curl` to the web failed (`ECONNRESET`, no response); only the canon file loaded.
  Every web [S] comes from search excerpts, not a full read. Dance sources are mostly studio guides, wikis and
  syllabi, and game sources largely fan wikis. Nothing is ethnography; check steps against real footage.

**Owner rulings applied (2026-11-05).** Add levels, don't replace. The Gatekeeper ("a better term" than gardener)
fist-bumps at Level 1 to 2; the full high five stays for the finale. Tap zones stay fixed and thumb-reachable,
the top area displays the dances, and visuals are independent of the controller scheme. The signature step comes
from the salsa master. The choreography grammar is wanted, and other missing foundations should be listed.

---

## 1. Fit with the story, in a growing campaign

### Where it goes

| Order | For | Against |
|---|---|---|
| **A. Garden, Bar, Pool, Crowd, Restroom, VIP** | The owner's wording (Bar, then this). Route works: terrace door, back garden, top-right door into the dance room, corridor, restroom, stairs. Opens outward, then indoors, then tighter | Pool and Crowd adjacent, both dance-led, so must differ strongly |
| B. Garden, Bar, Crowd, Pool, Restroom, VIP | Keeps Crowd's slot and tempo | Against the brief's order; a walk outdoors and back in just before the rush |
| C. Pool after Restroom | Relief after the rush, and a calm before VIP | Outdoors just before the climax; breaks "transition into a third level" |

**Recommend A.** [I] Use stable names, not numbers: "Level 4" for the restroom's country-to-metal brief ([O]
`level-3-readiness.md`) is already wrong under A. With many levels to come, numbers will keep moving.

### What collides

| Topic | Today | Issue and recommendation |
|---|---|---|
| Campaign length | Five budgets total 390 s; 5-8 minute target; "five" appears in specs and many plans ([O]) | Success plus bridge is 33 s now. Adding 80 s of pool and one more chain (about 8 s) gives about **8:37**, past target, and the bar already runs long ([O] code comment). A seventh level nears 10 minutes. See foundation 1 |
| Ranking | Ranked time spans the whole run ([O] `rhythm-combat`) | Each new level invalidates existing times. Needs versioned boards or per-act boards. [I] |
| Tempo | Crowd holds 108-120 ([O] manifest) | Cha-cha-chá wants about that range. Recommend pool 108-120 and **Crowd up to 112-124**: Crowd has no chart yet, and its score must be rebuilt anyway. VIP shares 112-124, but with the restroom between. [I] [T] |
| Respect word | One per stage: Mojo, Swag, Flow, Nerve, Presence ([O]) | Flow stays with Crowd. The pool needs its own. Candidates: **Grace**, Poise (near Presence), Sabor (ask the teacher). [I] [T] |
| Palette, motif | Crowd: violet, cyan, cream, disco ([O]) | Crowd keeps them. Pool needs another: dusk peach and lilac with aqua water light, say. Avoid Garden's deep blue and VIP's teal and gold. [I] |
| Style | Readiness draft gives Crowd boogaloo and salsa-disco ([O]) | Leave boogaloo with Crowd. So no clap-layer boogaloo tint on the pool, as an earlier draft of this file proposed. [I] |
| Bridges | `bar_to_crowd` and `RoomDeparture` go straight to Crowd ([O]) | Need `bar_to_pool` and `pool_to_crowd`; `success` and tiers for the new score. See the engine audit |
| Crowd's copy of the signature step | Crowd leader repeats it ([O] C01) | Keep it: the full copy stays there as the payoff. The pool pair can notice or try a piece of it. Exact form waits for the step. [T] |
| Restroom gag | Polite weight-shift at R01 ([O]) | The oil gulp can seed it, now over two levels: tell at the end of Crowd, not Pool. [I] |
| Pool crowd | No budget | New `CrowdStageProfile`. Swimmers can't stand; count as interested only, or a small "forearms on the edge" clip. Standing share must rise between Bar and Crowd ([O] room arc). [I] |
| Camera | Rear default, converging floor ([O]) | Diagonal is no violation. Audit: angle is cheap, but the top-right corner and pool sit where tall phones crop and the HUD covers. Compose the key story there inside the safe zone. |

### Settled, and what it changes

- **Fist bump, not high five, at Level 1 to 2.** Avoids spending the finale's gesture, and gives a ladder: peer respect
  first, full celebration last. G01's chest tap can stay; drop its point if the bump does that job. Beats in §5.
- **Gatekeeper** stays his name. No "gardener" exists in docs, code or tools ([O] grep).
- **Minor to reconcile:** `play-and-transition-overhaul.md` says "Approach host, high five", while E01 has the host step
  aside and Tlatoāni give it. Follow E01. [O]

### Docs that would have to change (none changed here)

- `openspec/specs/storyboard/spec.md`, `art-direction/spec.md`, `dynamic-music/spec.md`: "five" stages and palettes;
  new stage row; G01 fist bump; tone rules (§6). Art-direction's limb and pose language under ruling 3 (§3).
- `plan/storyboard.md`: new sequence row, reset, session list. Total run sentence.
- `plan/level-3-readiness.md`: now Crowd's sheet; rename. `plan/dance-battle-choreography.md`: the "exact limb" contract.
- `plan/play-and-transition-overhaul.md`, `plan/music-overhaul-research.md`, `plan/party-overhaul.md`, `plan/assets.md`,
  `plan/asset-inventory-contract.md`: room tables, departures, inventory.
- `score-composition-pipeline` D7; `cinematic-shot-pipeline` deltas; `lib/gameplay/room_departure.dart` data, later.

Separate flag: `gatekeeper.json` says "skilled cumbia dancer" and his drawings are keyed to cumbia, while the recorded owner
note and the `garden_mojo` brief make his music salsa-led at 92 BPM, which that brief admits is slow. Ask the teacher. [O] [T]

---

## 2. Music and dance identity

Constraints [O]: +3 BPM per tier; 16-beat cycle, 8.9 s at 108, 8.0 s at 120. Neighbours: Bar (Latin-electronic over cumbia,
100-112), Crowd (boogaloo, salsa-disco draft), then Restroom's rush at 132-144.

| Style | Tempo evidence | Readable rhythm | Contrast | Pair repertoire, hold | Arc fit |
|---|---|---|---|---|---|
| **Cha-cha-chá** | About 120, social 110-130 [S]¹ | High: audible triple | High with charanga timbres | Side-by-side, no-hold figures exist; many others held [S]² | Elegant, playful lift |
| **Bachata** | Disputed: 80-96, 120-140, 120-160 [S]³ | High: tap on 4; footwork in Dominican style | High: guitar | Dominican: open, light connection; moderna and sensual closer [S]⁴ | Dips the energy; suits dusk; romance signal needs care |
| **Boogaloo** | None found | Clap backbeat clear; steps poorly documented [S]⁵ | Medium-high | No agreed repertoire | Belongs to Crowd |
| **Samba** | Ballroom about 100; general 80-125 [S]⁶ | Low at sprite size | High | No pé solo; samba de roda women in turn [S]⁶ | Carnival imagery trap (§6) |
| **Mambo** | Ballroom about 188; lower social figures [S]⁷ | Good, but fast | Low: Garden's brass mambos | Partnered; modern "on 2" differs from Prado era [S]⁷ | Repeats Garden |
| **Reggaeton / dembow** | About 85-100 [S]⁸ | Clear beat | High | Perreo close, front-to-back, some explicit [S]⁸ | **Exclude** for this cast and audience. [I] |
| **Merengue** | 120-160, beginner 120-130 [S]⁹ | Very clear, little to shape | Medium | Pairs, flirtatious gestures per UNESCO [S]⁹ | Bright, thin across five tiers |
| **Bossa nova** | 81-156 on one album [S]¹⁰ | Dance never standardised [S]¹⁰ | High | Mostly listening music | Mood only; intro colour |

**Recommendation: cha-cha-chá. [T]**

1. Tempo lands on the dance's range with no tuning.
2. The name is the rhythm. The count **2-3-4&1** is a break, a replace and a three-step chassé [S]¹. A player can hear
   and tap it. Rule 3 makes rhythm matter more than limbs, which favours this.
3. Flute and violins [S]¹¹ are distinct from Garden's brass, the Bar's synths and Crowd's claps. [I]
4. Real history: Cuban, 1950s, associated with Enrique Jorrín and Orquesta América, its name often traced to dancers'
   feet at the Silver Star Club [S]¹¹. It suits a period mansion party. [I]

**Runner-up: Dominican-style bachata. [T]** The teacher teaches it, so it may be far better supported than any cha-cha
source I could reach. Its tap on 4 is a ready-made player moment, it suits dusk, and guitar contrasts with all neighbours.
Against: it dips energy before Crowd; tempo sources conflict; audiences read bachata as romantic, so a two-women
challenge needs care. An earlier draft of this file named boogaloo; that was before Crowd was retained.

**What would flip it:** the teacher says cha-cha-chá is the wrong call for two friends; has no feel for it but can fully
supervise bachata (real supervision outweighs my desk ranking, in my view); or says a bachata tempo fits this slot.

**Vocabulary if cha-cha-chá [S]² [T].** International-style syllabus names, not Cuban social terms. No names invented.

| Figure | Hold | Possible use [I] |
|---|---|---|
| Chassé (triple) | None needed | Groove, rhythmic fingerprint |
| Cuban Break | None if danced apart | Low, clear accent; keeps hem down |
| Time Step | Source: "no physical lead" | Groove, invitation |
| Spot Turn, Switch Turn | None | Finishes, flourish |
| New York, Three Cha Chas in side position | Usually one hand; can be apart | Side-by-side travel |
| Hand to Hand | Joined | Celebration |
| Fan, Alemana, Hockey Stick | **Led and held as standard** | Alemana to close the level only |
| Closed-hold basic | **Close-hold** | Not for calls. Hides bodies, needs lead and follow |

**Chart idea, draft, unplayed.** All shipped charts use offsets `0, 1, 2, 2.5, 4, 5, 6, 6.5` ([O]). A chart at `0, 1, 2, 3,
3.5, 4, 5, 6` has one true **4-&-1** at 3, 3.5, 4 and two free beats before the handoff. Half a beat is 278-250 ms here, so ±180
ms windows overlap, as they already do in shipped charts. I didn't audit the judge's tie rule.

**Pipeline catches** ([O] `work/1834-scor`). `latinIdentity` recognises clave, tumbao and cumbia only. Sources disagree whether
cha-cha-chá rests on clave [S]¹². Add a sourced pattern rather than graft a clave on. `voices.json` has `sineFlute` but no
violin; a small recipe is allowed (D6). Bachata would likely need a guitar-forward voice and pattern too (`nylonPluck` exists).

---

## 3. Two challengers

### Precedents (design ideas only; we copy no game)

| Game | Idea | Lesson |
|---|---|---|
| PaRappa the Rapper | One teacher per stage, call and response [S]¹³ | Base form; ours already |
| Space Channel 5 | Copy opponents on directions plus one action [S]¹⁴ | Small fixed input vocabulary is enough |
| Rhythm Heaven: The Clappy Trio | Player is third; two others clap first [S]¹⁵ | Two callers can act as one signal. Clear, no new information |
| Friday Night Funkin' | Opponent sings, player mirrors; later duets at once [S]¹⁶ | Simultaneity comes late |
| Just Dance 2 duets | Odd players follow left dancer, even the right [S]¹⁷ | Position as a plain assignment rule |
| Patapon | Four inputs, four-beat phrases, army answers [S]¹⁸ | Four inputs can carry long play |
| Rueda de casino (a dance) | Caller in the circle signals, often by hand, for the next eight-count [S]¹⁹ | A real social model of calling on a boundary; inspiration only |

### What ruling 3 changes

Previously a dancer's limb had to match the note. Now the cue icons and the pad carry *which zone*; the dancers carry *rhythm, turn
and joy*. So: mirror and unison no longer imply a chord or a wrong limb, and a dancer's left-right drawing problem (their left
is on screen right, pad LH on the left, [O] `poses.py`) stops mattering. No "screen side wins" fix is needed. The risk moves too: if
dance carries no input information, a player can ignore it and read only the pad, or the pad's cues can bury the dance. [I]

What must stay coupled, in my reading: **a visible hit on every call note**, so body and music agree; **who has the floor** at each
moment; an immediate visible response to an accepted tap ([O] `dance-battle-choreography.md`). Whether Mācron's reply must still show
the tapped limb is a decision below; I'd let him use limb accents at first, then widen.

### Options

| Option | Adds gameplay? | Pitfall |
|---|---|---|
| Unison | None, but thrilling visually | Art doubled for one signal |
| Mirror | None; attractive, and now safe | Same; twinning reads stiff ([O] research) |
| **Trading phrases: A then B** | **Yes, if written into the chart** | Without distinct rhythms it's just decoration |
| One calls, one answers | Yes: longer recall | Hard as a first encounter |
| Split by pad column | Some: position hints at zone | A hint that's sometimes unavailable teaches nothing; needs a consistent rule |

**First release: trading phrases with distinct rhythmic personalities. [I] [T]** Within each 8-beat call, one dancer takes the plain
on-beat notes, the other the syncopated ones. The pair then alters what the player hears and taps, independent of limbs. Each could have
a voice, flute and strings, and hits land with the owner of that note. Add the column hint (left dancer on left-column notes) only if a
quick test shows it helps: people respond faster when stimulus side matches response side [S]²⁰, but it would constrain charts.

**Later tiers or replay.** One calls, one answers, with the answer varying the call. Side swap during a rest. Shortened demonstration,
allowed already. Unison and mirror are free at any time, best on finishes and proof phrases. Never a chord in the input ([O] spec).

**Main pitfall: who has the floor.** With rich movement everywhere, a player can't tell whose turn it is. Make the holder larger in pose
and the other lower in energy, and make the call-to-response handoff unmistakable: they step apart and Mācron dances between them.
Occlusion matters more with two: in the bar the challenger ends up behind a guest, and "WATCH THE CALL" crosses her waist ([O]).
Silhouettes must differ by shape. The teacher's answer on circles and shines can change all of this.

**Cost.** Two characters at 64 poses and about 92 s each is about 3.3 hours of GPU plus eye review ([O] A3, arithmetic). The chart needs a
per-note owner; the scene draws one challenger today ([O]). Engine audit: per-room marks, memory about 137 MiB by estimate.

---

## 4. Richer dance

Free gain first: 44 of 64 drawings never show ([O] engine audit; B5). Wire them before drawing more. At this size a limb change under
about 10° can't be seen ([O] Gatekeeper research), so richness comes from pose contrast and phrase structure. Frames need preparation, contact,
accent and settle, and music owns them ([S] Cartwright GDC 2014 and Disney, in `animation-research-register.md`; [O] B1-B3).

**Ruling 3 widens the vocabulary.** All-body moves (hips, shoulders, turns, travel, hand styling) become usable, including the moves the
interview guide calls unmappable. Existing limb clips become ordinary dance moves. The groove need not keep arms low to avoid resembling a
call. The model tests that require a matching limb accent at each note would relax to "a hit on that beat" ([O] choreography doc). Top-area
space is finite: cue origin is "near the center" ([O] spec), so define where cues may fly. See foundation 2.

### Choreography grammar (owner confirmed the need; names provisional) [I] [T]

| Layer | What | Owned by | When | Rule |
|---|---|---|---|---|
| **Groove** | Dance loop, several variants | Section, tier | Always, under everything | Rich but steady; carries the style |
| **Hit** | Visible accent on a call note, any body part | Chart timing | Call notes | Exact on the beat; never changes notes |
| **Accent** | Clap, shoulder, head, hem | Score sections | Horn lines, breaks | Answers the music, at most one big one per beat |
| **Travel** | Drift, parting, re-forming, crossing | Marks, phrases | Phrase boundaries | On foot, with gait frames |
| **Flourish** | Spin, showpiece, styling | Tier, or player style | Free beats | Optional; a taps-only run still sees tier ones |
| **Celebration** | Unison, approval, crowd | Clearance | Success phrase | No judged input |

| Section, tier | Hits | Between calls | During response | Crowd |
|---|---|---|---|---|
| Invitation, tier 0 | Simple, spacious | Groove A | Quiet, watching | Occupied, a few glances |
| Tier 1-2 | Syncopation appears | Groove B, accents | Nod, small groove | Heads turn; swimmers drift to the edge |
| Tier 3 | Full phrases | One travel per phrase | Low groove, stays secondary | Most share a groove, varied |
| Tier 4, proof | Bigger shapes | Flourish in rests | Leans in, grins | Peak for this room's budget |
| Success | None | Unison, then separate | n/a | Thins, chats again; two keep clapping |

Crowd energy can choose groove variants, never notes. Test: identical input gives identical score with this layer off ([O] B3). "A dance's
form over a song" and "what happens between big moves" are direct teacher questions; expect this table to change.

### Adornments

- **Answer-back.** Mācron's flourish remains optional input with Pizazz only. When the player lands a style chain (`styleCombo`, [O]), a challenger
  answers at the next free beat. Tier-driven flourishes mean taps-only play still sees them. [I]
- **Spin.** Mācron's is an 8-step multi-view cycle ([O]). Challenger turns are capped near ±30° and flipping is banned ([O]), so a true spin needs
  4-6 new drawings with a rear view, where sides are most at risk. Start with a heel pivot; add one real spin per dancer.
- **Hair and hem.** One-drawing lag, hem below the knee, never over the face.
- **Shaker toss.** Owner's call pending. Recommend out of grooves and calls, one toss in a 3-4 drawing flourish; wrong-hand props are a known failure ([O] A5).
- **Crowd.** `crowd.adorn` with existing clap and toast clips, one prominent gesture per beat ([O]).
- **Reduced motion.** Hits kept; flourishes become a held finish pose.

### Signature step: what we need from the teacher

Eight files rely on it, none defines it ([O] grep). The guide's §1 and §8 cover most of this. **I propose no step.** Needed:

| Need | Why |
|---|---|
| Name, origin, and which style it belongs to | Credit, and it plays across every style in the game |
| Counts: each foot and hand per beat; start and end pose | Key poses; hooks in and out of a groove |
| Length: must fit a success phrase, ideally 2-4 beats | Fits 8 beats with the challenger's action |
| Works from about 92 to 144 BPM? A slow and a fast form? | Tempo differs per room |
| **Robot-possible:** short legs, compact shell, no hips or neck | His rig is non-human ([O]). What survives, what can be swapped? |
| Reads as a small silhouette, what looks wrong | Native-size acceptance |
| Beginner, confident and showing-off versions | Can map to run progress; showing-off to the optional flourish |
| Human version for dancers to copy | Crowd's payoff; authored by hand ([O] readiness) |
| A musical figure that goes with it | Motif tag in each success phrase |
| Does it leave the right arm free at its end? *Nice to have* | Could flow into fist bump and high five, if natural |
| Front and side clips counted aloud; reference consent; credit wording | Reference only, unpublished, per the guide |

**How it plugs in:** capture sheet → glossary entry and movement register (foundation 4) → key poses in `tool/art/rig/poses.py` with `check_poses.py` →
Mācron's route for new drawings (no OpenPose for him, [O]; none exists yet per the audit) → sprite tag used by `heroSpriteFrame`, shown on clearance so taps-only
players see it → motif in score briefs → teacher reviews a flipbook at tempo → canon update. Until then use `spin_front` as a marked placeholder ([O] used when finishing).
Its optional flourish link is settled by the teacher's versions; candidate pay-offs per level are for after the step is known.

**Suggested guide additions.** Section 3 predates ruling 3, so reword it: all-body moves are welcome, not a problem. Add: "Do you dance or teach cha-cha-chá; what would *you*
pick for two friends at dusk at about 110-120 BPM?" Add: "How do two women dance socially together: any etiquette?" Add: "Cumbia and salsa at 92 for the Gatekeeper, does it work?"

---

## 5. Cinematic transitions

**Budget.** Success plus bridge is 16 beats each: 9.4, 8.7, 7.6, 7.6 s today ([O] arithmetic from the manifest).

1. **Add no bars** (storyboard's no-padding rule; shot design D6). One extra bar at the pool reveal only after a playtest asks for it.
2. **Music keeps going.** No silence or black screen; the conductor gives gapless handoffs. [O]
3. **Music clocks every frame,** including pause. [O]
4. **Stay a dance.** Mācron moves throughout, one accent on a strong beat. The last input should visibly cause the first frame. [I]
5. **One idea, one feeling.** Stinger from the room motif, plus a signature figure once it exists.
6. **Restore stable framing before cues.** [O]

**Skip against the ranked timer: a real conflict.** The spec wants skippable after first exposure, and ranked time *includes* transitions ([O] `rhythm-combat`).
A skip that saves time becomes a required tap. **Recommendation:** skip swaps shots for a plain walk on the same bars, so ranked time is unchanged and music stays gapless.
Pausing cinematics is expected, and bypassing non-core elements has guideline support [S]²¹.

**Reduced motion** ([O] spec; [S]²¹): fixed cuts at phrase boundaries; no zoom, shake or orbit; one held contact frame; flashes under three per second.

### Fist bump: Garden to Bar (settled; sketch). Feeling: "he respects me, I'm in"

| Beats | Action | Assets |
|---|---|---|
| 0-2 | Gatekeeper finish, brim touch, eyebrow softens, slow nod | Existing `finish_turn`, `approval` |
| 2-3.5 | Knees bend, he lowers a fist to hip height, offering it | New: 2 drawings |
| 3.5-4 | Mācron hops, modular right arm forward | New |
| **4** | **Contact on the downbeat of bar two.** Small clink, doubled by a percussion hit | New contact; no glint, kept for the finale |
| 4-6 | He straightens, chuckling; rope lifts; palm toward door | Existing `offer`, rope |
| 6-8 | Music thins; queue parts; two guests clap | Existing |
| Bridge 0-8 | Right step, turn rear, recede to copper door; warm light | Existing route |

Scale: Mācron draws at 0.35 of adult height ([O] `garden_scene.dart`), and canon's typical scale is smaller ([O] §15); he must not grow. A heavy-set man stooping and a tiny robot
hopping is warm comedy and suits the stocky build still owed to him ([O] A8). The finale keeps closeup, glint, caption and calm, exact height-matching.

### Oil gulp: Bar to Pool. Feeling: comic delight, a reward

Keep 6.5-beat `bar.outro` (nod, pour, slide, gulp, exit) with 1.5 beats spare ([O] D6). Open: **how does the glass reach him?** B01 has him at floor level, peering round the counter, while the
shot slides along the top. The closeup hides it; `bar.exit` shows it. Options: he climbs the foot rail; a stool rung; she lowers it. Recommend the rail: canon physical comedy ([O] §24). The glass is
large for him: both arms, body tilting back. Oil's colour is already open; "fresh" suggests amber with a highlight. [I]

### Walk: Bar to Pool. Feeling: the party is bigger than I thought

| Beats | Action |
|---|---|
| Bridge 0-2 | Side walk along the counter end, in percussion |
| 2-4 | Terrace door passes as an occluder; dusk replaces amber |
| 4-6 | Reveal: diagonal path, glowing pool pavilion top left, tables. New style's pickup |
| 6-8 | Mācron goes up the diagonal, shrinking with floor scale |
| Intro 0-2 | Two figures step in from either side and close the path |
| 2-4 | One palm each: a smiling stop; a short shared step; they look at him. First call follows |

Pool to Crowd: 8 beats; they part, try the signature figure [T], one nod, walk to the top-right door. The dance room's sound is heard through the door before it opens.

---

## 6. Tone and respect

**Audience.** Likely includes teens: inferred from the cartoon cast, web delivery and one-thumb play. No document states it, and no rating is set. ESRB describes Partial Nudity as "brief and/or mild";
PEGI 12 allows innuendo, on fan-wiki text [S]²²; neither addresses swimwear in what I found. A rating call should also weigh "Chingón" and party alcohol, not researched here. [I]

**Designing against.** Camera lingering, costume and movement are the usual ways characters get sexualised [S]²³. There's a specific "spicy Latina" stereotype [S]²⁴, and in samba the exoticised dancer
has a documented, racialised history [S]²⁴, part of why samba isn't recommended here. Ask the teacher what would make them wince. [T]

**Rules proposed for the spec** [I]:

- **Clearly adults.** Recommend middle age or older: the "aunties who run the floor", matching the Gatekeeper's "uncle at the wedding". Grey streak or set hair, adult proportions. If younger, mid-30s and still adult-coded at 96×120.
- **Why they stop him.** It's their floor. He earns the floor, not their attention; approval isn't romantic. They laugh with each other: friends or sisters, not on show for him.
- **Wardrobe** [T]. As with the Bartender ("fully clothed adult professional", [O]): dance dresses or skirt and blouse, sleeves or wide straps, closed neckline, hem below the knee, low heels. Strong solid colours. No ruffle-sleeve costume, fruit headdress or feathers.
- **Framing.** Whole figure or waist-up. **No robot-height shots toward them:** closeups "at robot height" are this game's habit, so write this ban into the shot rules. No slow pans, shots from behind or body-part closeups.
- **Motion.** Rule 3 allows hips and all-body moves, so this matters more. Hips follow bent knees and weight, never pushed ([O] Gatekeeper rule). No body waves. Low kicks. Check hem height in every spin frame.
- **Swimmers.** Seen through the pavilion glass, far and small. Chest up in water, period caps, mixed ages and genders, all adult, some just chatting. Never a closeup or walk-past. Note the audit's crop warning for this corner.
- **Table guests.** Mixed ages and builds. Nobody leers or gestures at the women.
- **Generator.** State clothing and age in every prompt; treat drift as a review failure, since scorers can't see it ([O] A6). Check build against the sheet ([O] A8).

**Covi.** Final art is blocked and no appearance may be invented ([O] spec); "must never resemble" is in `assets.md`. Covi's look is unknown, so check against the placeholder only: distinct silhouette, not seated near the reserved seat, no VIP appearance. Recheck when a reference arrives.

**Naming and culture** [I], except where cited:

- Avoid Carmen, Chiquita, Lola, "Mami", "La Engañadora". That song's lyrics concern a woman at Prado and Neptuno [S]¹¹; I recall it mocking her figure, so verify before any reference.
- Keep them provisional until the owner names them. Ordinary names over ones picked to sound Latin. Consider asking the teacher.
- Don't blend Mexican charro, Brazilian Carnival or Spanish flamenco with Cuba. Keep "duende" off the screen.
- Quote no original tune. No shouted "¡ay!" or accent jokes. Rueda and casino are Cuban terms for another dance. Credit the teacher as agreed.

---

## 7. Planning at a larger scope, for many levels

### Two documents, not one

**Campaign sheet,** one row per level, read together: order, stable ID, respect word, style, BPM, palette, cast, new idea, budget, reward type, reuse versus new art. It's where adjacency problems show,
like the tempo clash in §1. **Level bible,** one per level, written and approved before art starts:

ID and slot · Premise · Emotional beat · Respect word · Teaches · New mechanic (at most one) · Music · Dance vocabulary, source and reviewer · Cast · Space, palette, crop safe zone · Transition in · Transition out · Motifs set up and paid off · Tone rules · Budget and reuse · Depends on · Status · Acceptance test.

### Pool garden bible: **DRAFT, not approved**

| Field | Draft |
|---|---|
| ID, slot | `pool-garden`, after Bar, before Crowd |
| Premise | Out of the bar into the dusk pool garden. Mid-path, two grown women who own the floor stop Mācron. He earns it |
| Emotional beat | Awe at scale, playful rivalry, then welcome |
| Respect word | Grace, pending |
| Teaches | Rhythmic phrasing: syncopation and rests with a recognisable shape |
| New mechanic | Trading phrases. Same four inputs, no chords, no new scoring |
| Music [T] | Cha-cha-chá in charanga colour, 108-120 BPM. Flute, strings, güiro, bell, piano-like comp. Original. Gates pass; ears approve |
| Dance vocabulary [T] | §2 table, reviewed by the teacher, or a substitute style's list |
| Cast | Two adult women, contrasting silhouettes. Table guests, distant swimmers |
| Space | Diagonal path to top right. Glass pavilion top left. Tables, top and left. Dusk palette, water light. Story items within the safe zone |
| In, out | Bar, terrace door, reveal, two palms up: 8 + 4 beats. They part, nod, top-right door: 8 + bridge |
| Reset | They step together, kindly walk him back: 2 beats |
| Motifs | Sets up: being noticed. Pays off: oil gulp's cheer. Crowd's copy still ahead |
| Tone | §6 in full |
| Budget, reuse | About 80 s, subject to foundation 1. New: 2 characters, room, score, bridges. Reused: guests, rig |
| Depends on | Interview; engine audit needs; campaign decision |
| Acceptance | Fresh players, no text, phone: can say whose turn it is by phrase 3; clear taps-only within budget. Same score with shots on or off. Native-size pair review. Teacher and owner review. No §6 failure. Full reduced-motion run |

### Mini versions

- **Garden, out.** Beat: "he respects me." Reward: fist bump. Assets: stoop, contact. Test: lands on the accent; fits 16 beats; Gatekeeper's build matches his source.
- **Bar, out.** Beat: comic reward; rooms remember you. Reward: oil. Assets: `bar.outro`, glass route. Test: within 8 beats; comic at native size; shaker per decision.
- Both: skip-to-walk and reduced-motion versions; signature tag slot held open for the teacher's step.

### Other missing foundations (like the grammar)

Each is referred to in places but undefined, or built for exactly five levels. [O] for the gap; order is my view.

1. **Campaign structure and length.** No rule for N levels. Options: raise the target; trim budgets; split into acts of 3-4 levels with their own boards and checkpoints. Recommend **acts**. Decides ranking, save and any replay offer.
2. **Screen contract under ruling 3.** Spec defines the pad but not the top area's safe zones, HUD, cue flight region or call labels. Audit found HUD and crop clashes.
3. **House map.** Rooms appear in tables, with no one map to keep routes, doors and time of day coherent.
4. **Movement register.** Named moves, source, style, drawings, reviewer, used-where. Today each character's research stands alone. Signature step lives here.
5. **Chart grammar.** Tiers change limbs, not rhythm, and all charts share one offset list ([O]). No doc says what difficulty means across many levels.
6. **Music arc map.** Tempo and style by level live in scattered briefs. Needed to catch clashes, and for bridges.
7. **Reward ladder.** Fist bump, oil, key, high five, standing ovation: what is each level's earned moment, and what's reserved for the end?
8. **Cultural review and credit.** No named process, reviewer or credit policy, though real traditions are in use. The teacher makes this urgent.
9. **Audience and rating policy.** Assumed, not stated.
10. **Playtest protocol.** "Fresh player" tests are invoked; none has been defined, and physical-phone checks remain open ([O] `plan/music.md`).

---

## Decisions for the owner

| # | Decision | Recommendation | Depends on teacher? |
|---|---|---|---|
| 1 | Level order | Garden, Bar, Pool, Crowd, Restroom, VIP | No |
| 2 | Run length and ranking with many levels | Acts with own boards; versioned boards otherwise | No |
| 3 | Style | Cha-cha-chá; runner-up Dominican bachata | **Yes** |
| 4 | Tempo | Pool 108-120; move Crowd to 112-124 | Partly |
| 5 | Respect word | Grace, or Sabor if the teacher likes it | Partly |
| 6 | Pair mechanic | Trading phrases with distinct rhythms; test a column hint | Partly |
| 7 | Must Mācron's reply show the tapped limb? | Yes at first, widen later | No |
| 8 | Adopt the grammar and rewrite "exact limb" rules | Yes, after the interview | Names, yes |
| 9 | Signature step brief | Use the need list; add guide questions | **Yes** |
| 10 | Who are the two women? | Friends or sisters, middle age or older, contrasting builds | Partly |
| 11 | Swimwear and rating | Distant, through glass; decide target rating deliberately | No |
| 12 | Skip and ranked time | Skip swaps visuals for a walk on the same bars | No |
| 13 | Transition budget | No added bars | No |
| 14 | Glass route | Climbs the foot rail | No |
| 15 | Shaker | Out of grooves and calls; one deliberate toss | No |
| 16 | Chart rhythm and `latinIdentity` for the chosen style | Allow new offsets; add a sourced pattern | **Yes** |
| 17 | Campaign sheet, level bibles, foundations | Adopt; do 1-4 before more level art | No |

## Sources

¹ https://www.ballroompages.com/dance-styles/cha-cha/ · https://dancewithmeusa.com/dance-cha-cha/ · https://en.wikibooks.org/wiki/International_Latin_Technique/Cha_Cha_Cha  
² https://www.dancecentral.info/ballroom/international-style/cha-cha-cha · https://www.dancecentral.info/ballroom/international-style/cha-cha-cha/time-step · https://www.dancecentral.info/ballroom/international-style/cha-cha-cha/alemana · https://www.dancecentral.info/ballroom/international-style/cha-cha-cha/hockey-stick · https://www.ballroomdancers.com/dances/info.asp?sid=15  
³ https://www.lodance.app/lineage/specialty-club-latin/bachata · https://rfdance.com/blog/salsa-vs-bachata-music/ · https://ritmomontreal.com/what-is-bachata-music-complete-guide-to-dominican-genre/ · https://en.wikipedia.org/wiki/Bachata_(dance) · https://bachataonlinecourse.com/basic-steps-of-bachata  
⁴ https://www.salsavida.com/articles/the-different-styles-of-bachata-dancing/ · https://danceseekers.com/blog/bachata-sensual-vs-dominican-vs-modern  
⁵ https://en.wikipedia.org/wiki/Boogaloo · https://daily.redbullmusicacademy.com/2013/05/bugalu-on-broadway/ · https://www.theparisreview.org/blog/2014/10/09/cha-cha-with-a-backbeat/ · https://getbailar.com/biblioteca/move/salsa-boogaloo  
⁶ https://www.ballroompages.com/ballroom-music/samba-music/ · https://udansa.com/en/dance-guide/samba-guide/samba-solo/learn-samba-no-pe · https://en.wikipedia.org/wiki/Samba_(Brazilian_dance) · https://ich.unesco.org/fr/RL/la-samba-de-roda-de-recncavo-de-bahia-00101  
⁷ https://www.ballroompages.com/dance-styles/mambo/ · https://en.wikipedia.org/wiki/Mambo_(dance) · https://hollywoodballroomdc.com/recommended-tempos-for-dance-music/  
⁸ https://bpmcalc.com/genres/reggaeton/ · https://www.melodigging.com/genre/perreo · https://www.lodance.app/lineage/specialty-club-latin/reggaeton-perreo · https://en.wikipedia.org/wiki/Sandungueo  
⁹ https://ich.unesco.org/en/RL/music-and-dance-of-the-merengue-in-the-dominican-republic-01162 · https://dancewithmeusa.com/types-of-dances/merengue/ · https://socialdance.stanford.edu/Syllabi/DJtips.htm  
¹⁰ https://www.libraryofdance.org/dances/bossa-nova/ · https://www.aventuradobrasil.com/blog/brazilian-music-styles-the-bossa-nova/ · https://getsongbpm.com/album/38-titres-bossa-nova/77oYO  
¹¹ https://en.wikipedia.org/wiki/Cha-cha-ch%C3%A1_(music) · https://en.wikipedia.org/wiki/Enrique_Jorr%C3%ADn · https://en.wikipedia.org/wiki/La_enga%C3%B1adora · https://www.soundbrenner.com/blogs/articles/cha-cha-cha-rhythm · https://www.melodigging.com/genre/charanga  
¹² https://en.wikipedia.org/wiki/Richard_Eg%C3%BCes · https://abc-latina.com/musique/cha_cha/ · https://www.melodigging.com/genre/chachacha  
¹³ https://www.digitalgamemuseum.org/rhythm/parappa/ · https://en.wikipedia.org/wiki/PaRappa  
¹⁴ https://en.wikipedia.org/wiki/Space_Channel_5 · https://gamecola.net/2006/02/space-channel-5-dc/  
¹⁵ https://rhythmheaven.fandom.com/wiki/The_Clappy_Trio · https://rhwiki.net/wiki/The_Clappy_Trio  
¹⁶ https://en.wikipedia.org/wiki/Friday_Night_Funkin' · https://studybreaks.com/tvfilm/friday-night-funkin/  
¹⁷ https://en.wikipedia.org/wiki/Just_Dance_2 · https://justdance.fandom.com/wiki/Duets  
¹⁸ https://en.wikipedia.org/wiki/Patapon · https://patapon.fandom.com/wiki/Patapon_Drums  
¹⁹ https://en.wikipedia.org/wiki/Rueda_de_Casino · https://www.salsavida.com/salsa-dance-terms/rueda-de-casino/  
²⁰ https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4137233/ · https://www.sciencedirect.com/topics/neuroscience/simon-effect  
²¹ https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/108 · https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/117 · https://gameaccessibilityguidelines.com/full-list/  
²² https://www.esrb.org/ratings-guide/ · https://rating-system.fandom.com/wiki/12_(PEGI)  
²³ https://feministfrequency.com/video/body-language-the-male-gaze/ · https://www.gamedeveloper.com/business/opinion-video-games-and-male-gaze---are-we-men-or-boys- · https://www.researchgate.net/publication/353553621_Masculine_Pleasures_as_Normalized_Practices_Character_Design_in_the_Video_Game_Industry  
²⁴ https://womensmediacenter.com/fbomb/too-hot-to-handle-the-dangers-of-the-spicy-latina-stereotype · https://www.refinery29.com/en-us/love-island-usa-season-6-spicy-latina-stereotype · https://www.researchgate.net/publication/258164998_Performing_Mulata-ness_The_Politics_of_Cultural_Authenticity_and_Sexuality_among_Carioca_Samba_Dancers  
Canon: https://raw.githubusercontent.com/8007342/macron.dev/refs/heads/main/assets/Tlato%C4%81ni%20%2B%20M%C4%81cron%20cannon%20guidelines.md (§15, §24).
