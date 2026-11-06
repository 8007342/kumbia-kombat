# Progression and optional adornments

**Draft, 2026-11-06. Desk research only: nothing was built, no GPU was used, no game was played.**

The owner asked that optional adornments appear more often, and pay better, for players doing well, through music, audience and dance moves, with the opponent adding challenges for skilled players. Later the same day the owner added three things: build on the pacing authorities the project already cites, with tension and relief at the centre; make the whole scene "slowly party up" with the music, using the method from sibling project ranitas; and plan a shared prop library. This file separates what's known from what I'm recommending.

**How far to trust this.** Every full-page fetch failed on the day (connection reset, from both the fetch tool and `curl`), **including Booth's paper, which the owner asked me to read**. The outside evidence therefore rests on **search-engine excerpts**, plus the summaries of Booth and of the change-blindness papers in ranitas's documents. No paper or interview was read in full, no footage was watched, and no game was played. Treat the numbers in Part 2 as leads to check. The code facts and the simulation are firmer.

| Mark | Meaning |
|---|---|
| **[O]** | Observed in this repository's code or data, read today. Not run unless stated |
| **[S]** | My throw-away simulation, on invented player types. Tests the rule's arithmetic, not how it feels |
| **[A]** | Excerpt of a paper, or a developer's or publisher's own statement |
| **[B]** | Review, press, encyclopedia or a guide from an established site |
| **[C]** | Fan wiki, forum or low-authority article |
| **[J]** | My judgement |

## The proposal in brief

- **Today, every player who clears a level gets the same party.** Tiers, crowd and opponent are all driven by required passes, so skill only shows in a Pizazz number and a brief glance from a guest. [O]
- **Tension and relief run the show, at three scales: phrase, level and campaign.** Adornments, music and scenery follow that cycle. Skill sets how high each peak goes, not whether the show stays at maximum.
- **Add one measure, the party's Heat, from 0 to 3.** It comes from how each response phrase went. It rises and falls slowly, and changes only between phrases.
- **Heat only changes what's offered.** It never touches notes, timing windows, tiers, clearing or the clock. Nothing gets easier or harder, so there's nothing to feel rubber-banded by.
- **The opponent's challenge is a "dare".** It's a showy move in the call, answered with the flick the player already has, on a note that's already safe to flick. The last note of every phrase works in all three levels at every tempo. [O]
- **Ignoring a dare costs nothing, and a failed attempt costs nothing.** A test can prove this: the same taps, with dares on and off, must produce identical progress.
- **Rewards add to a complete game.** Party sounds in the music, a small extra crowd budget, bigger moves and end-of-level stamps. The tier 4 arrangement and each level's earned moment stay unconditional.
- **Everything parties up for everyone, led by the music.** Lights, then leaves, then hanging things, then flames and water, then staff, then the whole room, waking slowly. Heat brings each step a little sooner and bigger.
- **The biggest missing foundation is separable room layers,** with a shared prop library. Today's backgrounds are flat paintings.

## Part 1: what the game does today

### Everyone who clears gets the same show [O]

| System | What drives it | Does it reward skill? |
|---|---|---|
| Music tier and tempo | `FightProgress`, required passes only | No. Every clear ends at tier 4, and a clear requires it |
| Crowd interest | `CrowdInterestModel.resolvePhrase`, pass or fail | Barely. `rampPhrases` is 4 × `successesPerTier`, and a clear takes at least 6 or 10 passes, so anyone clearing fills it up to the room's budget |
| Crowd reaction to a flick | `crowd.adorn`, up to 4 guests for up to 7 beats | Yes, but brief, and it can't breach the budget (`crowd_interest_test.dart`: "flourish waves cannot make seated holdouts stand") |
| Opponent's spin | `choreography.json` accents: every 16 beats at beat 13, from tier 1 (flare) and tier 2 (spin) | No. Fixed by the beat and tier |
| Pizazz | +100 per flick | Yes, a number shown beside the perfect count at the end |
| Style chain | Different flick direction within 24 beats, up to ×4 | Yes, shown as a short message and a slightly larger guest wave |

This is the real gap: the owner's "more popular if the player is doing well" has nothing to attach to.

### Constraints this design must fit [O]

- **A level is short.** A clean run is 6 responses in the garden and 10 in the bar and pool garden. A slow-moving measure would never rise.
- **Only some notes can be flicked.** A note qualifies if the gap to the next note is at least 800 ms (`_flourishDestination`), or if it's the phrase's last note:

| Level | BPM by tier | Flickable notes, by index | Rest in mid-phrase |
|---|---|---|---|
| `garden` | 92-104 | 3 and 7 at all tiers | 1.5 beats, 865-978 ms |
| `bar` | 100-112 | 3 and 7 at all tiers (804 ms at tier 4, barely) | 1.5 beats, 804-900 ms |
| `pool-garden` | 128-160 | 7 only at all tiers | 1.25 beats, 469-586 ms |

- **The opponent's spin doesn't fit in a rest.** `spin_flare` is 3 beats (2 of turn, 1 of held flare). The call's free gaps are 1.25-1.5 beats. The owner's fourth-round ruling already points the way: let it overflow the turn, then step away.
- **Accents only play during the opponent's `watch` state** (`dance_grammar.dart`), so a spin in the call can't be expressed in the data today.
- **The dance layer is deliberately cut off from scoring.** "The session never reads it." Heat has to keep that: the session computes Heat, and the art reads it. Never the reverse.
- **Stray taps are already mostly safe.** A wrong tap doesn't break the combo, but it does show "KEEP THE PULSE" and sets `lastGrade` to miss. An attempted dare mustn't trigger that.
- **Tiers also set tempo**, so Heat can't be expressed through tiers.

### A likely existing bug that punishes recovering players [O, not run]

`_phraseIdentity` is level, tier, successes at tier and full-tier successes. It leaves out `_responseSequence`. After a failed phrase, a player can land on an identity they've already played. Their flick is then accepted (the sound plays and "¡PIZAZZ!" shows), but `_credited` refuses the points and the crowd wave. The rule exists to stop pause-and-replay farming, which must stay protected. It also catches a player who failed and is honestly trying again. Worth a test and a fix: pause keeps `_responseSequence`, so adding it to the credit key should preserve the protection.

## Part 2: the evidence

### Flow, dynamic difficulty and rubber-banding

| Source | What the excerpt says | Grade | Lesson [J] |
|---|---|---|---|
| Csikszentmihalyi, via [Journal of Behavioral Addictions 2020](https://akjournals.com/view/journals/2006/9/3/article-p606.xml) | Flow comes when skills and challenge balance; clear goals and immediate feedback are listed as components. In this study hard mobile games produced flow comparable to regular ones | A | Balance isn't one exact point. A skilled player can be left with more to do without harm |
| Hunicke, [The Case for DDA](https://dl.acm.org/doi/pdf/10.1145/1178477.1178573) and [Hamlet](https://users.cs.northwestern.edu/~hunicke/pubs/Hamlet.pdf), 2005 | Adjustment must not degrade the core experience. Hamlet changed supply and enemy strength, aiming to stay predictable. Basic adjustments were close to imperceptible; some experts reported adjustments that weren't there | A | Players may invent a pattern anyway, so rules must look like cause and effect |
| Chen, [Flow in Games](https://www.jenovachen.com/flowingames/Flow_in_games_final.pdf) | Thesis on keeping players in the flow zone, and on player-oriented adjustment. The excerpt didn't give its definitions. From memory only: it favours choices embedded in play, over systems deciding for the player | Excerpt A, the rest unverified | Closest fit: the player chooses by flicking |
| Ang and Mitchell, [CHI PLAY 2017](https://dl.acm.org/doi/10.1145/3116595.3116623) | Compared no adjustment, ramping by performance, and adjustment by player choice. Their own comparison of the two wasn't visible | A, partial | Supports having both, in principle. Read it in full |
| Constant and Levieux, [CHI 2019](https://dl.acm.org/doi/10.1145/3290605.3300693) | Adapted difficulty can leave players overconfident, which may be part of its positive effect | A | A caution for any system hiding easier play. We make nothing easier |
| Denisova and Cairns, [CHI PLAY 2015](https://pure.york.ac.uk/portal/en/publications/the-placebo-effect-in-digital-games-phantom-perception-of-adaptiv/) | Told a game adapted when it didn't, players rated it more immersive (reported by later citing work) | A, second-hand | Expectation alone has value. A party visibly responding to you may do a lot |
| Baldwin, [QUT thesis](https://eprints.qut.edu.au/102669/1/Alexander_Baldwin_Thesis.pdf) | Fairness can become an issue after repeated play; hidden balancing gets discovered, and it recommends disclosure. Its multiplayer test results weren't clear in the excerpt | A, partial | Don't count on staying hidden. Choose a rule that's fine to discover |
| [Aalto thesis 2023](https://aaltodoc.aalto.fi/items/940fd4e0-96c6-491a-8613-e0983008f1cf) | Compares hidden with upfront adjustment; recommends managing expectations openly | A, partial | Same direction |
| Left 4 Dead's Director | See "The authorities the project already cites", below | | |
| [Game Developer on DDA](https://www.gamedeveloper.com/design/more-than-meets-the-eye-the-secrets-of-dynamic-difficulty-adjustment), [Rubber-Banding as a Design Requirement](https://www.gamedeveloper.com/design/rubber-banding-as-a-design-requirement), [Cheat Code Central](https://www.cheatcc.com/articles/why-mario-kart-s-rubber-band-ai-feels-rigged-not-just-hard/) | Rubber-banding is very obvious to players, because the AI isn't playing by the player's rules. Mario Kart weights items by position | B, C | What gets resented is being held back or having a lead taken. Never take away what was earned |
| Resident Evil 4's hidden difficulty: [forum](https://www.resetera.com/threads/i-just-found-out-re4-had-dynamic-difficulty-how-many-games-have-it-without-it-being-obvious.153006/) | Players report tougher encounters when doing well. Nothing authoritative found, and I couldn't confirm any scale | C | Don't rely on it |

### The authorities the project already cites

The owner remembered "Valve's GameFlow". **I found no such thing, and no "GameFlow" anywhere in this repository.** That memory probably joins two real sources, Booth's Valve talk on pacing and Sweetser and Wyeth's GameFlow on enjoyment. They do different jobs, so I use both.

| Source | What's known | Grade | How it's used here [J] |
|---|---|---|---|
| **Booth, Valve, [The AI Systems of Left 4 Dead](https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf), 2009.** Cited in `plan/party-overhaul-research.md` and `plan/animation-research-register.md`. **Not read: the fetch failed** | From ranitas's `docs/research.md`, which cites PDF pages 79-82 and 92: an intensity estimate comes from gameplay events and decays over time. The director moves through **Build Up, Sustain Peak, Peak Fade and Relax**. Peak Fade lets ongoing action finish before the rest begins. A published example sustains a peak for 3-5 s and relaxes for 30-45 s, with a progress-based escape. It explicitly separates changing encounter frequency from changing difficulty. Other summaries agree on the shape ([AiGameDev](https://www.cs.drexel.edu/~so367/teaching/2012/CS680/papers/11%20Secrets%20about%20LEFT%204%20DEAD%e2%80%99s%20AI%20Director%20and%20its%20Procedural%20Zombie%20Population%20%7c%20AiGameDev.com.pdf), [slide analysis](https://github.com/nick-vas/hyperdot/pull/99)) | B: second-hand, one summary is unreviewed | **The central model for this proposal.** Use the shape, not the numbers: they come from a survival-horror game, as this project's own research already warns |
| **Sweetser and Wyeth, [GameFlow](https://dl.acm.org/doi/pdf/10.1145/1077246.1077253), 2005** | A model of player enjoyment built on flow: eight elements (concentration, challenge, player skills, control, clear goals, feedback, immersion, social interaction) and 38 criteria, for reviewing games. An [RTS version](https://www.researchgate.net/publication/254462666_GameFlow_heuristics_for_designing_and_evaluating_real-time_strategy_games) adds that pace should rise through a game. A [2020 retrospective](https://dl.acm.org/doi/abs/10.1145/3441000.3441048) is reported as saying it hasn't been validated as a measure | A, excerpts | **A review checklist, not a pacing method.** Nothing in the excerpts addresses tension and relax states. See the checklist in Part 3 |
| Simons, Franconeri and Reimer, [Change Blindness in the Absence of a Visual Disruption](https://journals.sagepub.com/doi/10.1068/p3104), 2000; [Frey et al. 2024](https://pmc.ncbi.nlm.nih.gov/articles/PMC11401121/) | Via ranitas: sufficiently gradual changes *sometimes* fail to attract attention. No usable timing threshold. A [summary of Levin et al.](https://en.wikipedia.org/wiki/Change_blindness) says people greatly overestimate their ability to notice change | A, second-hand | Supports slow entrances. Doesn't promise that nobody notices |
| [NN/g on animation](https://www.nngroup.com/articles/animation-usability/), [W3C on motion](https://www.w3.org/WAI/WCAG21/Understanding/animation-from-interactions) | Via ranitas: peripheral movement captures attention, and fading without a position shift is less distracting. Reduced-motion preferences should be honoured | B, second-hand | Fade in at the final position, grow movement separately, and keep reduced motion |
| ranitas, `docs/quiet-awakening.md`, `lib/game/awakening.dart` | A sibling project's method: quintic entrances over 110-180 s. Its own words: the times "are artistic choices", and it has run no user study | Project document | The method, not the timings, and not as evidence of an effect |

### Rhythm game precedents

| Game | What the excerpt says | Grade | Lesson [J] |
|---|---|---|---|
| **PaRappa the Rapper** (closest) | Four modes, Cool to Awful, changing after two lines played better or worse. A strong freestyle while Cool flashes enters Cool: the teacher leaves and you rap freely. Failing twice brings the teacher back at Good. Endings change slightly, and the arrangement changes with rank. Matsuura: without your own "arrangement" there's no COOL ([Wikipedia](https://en.wikipedia.org/wiki/PaRappa_the_Rapper), [Modes](https://parappatherapper.fandom.com/wiki/Modes), [1996 interview](https://shmuplations.com/parappa/), [PlayStation Blog](https://blog.playstation.com/2017/04/04/interview-the-untold-story-of-parappa-the-rapper/)) | B, C | Two-phrase hysteresis has a precedent. The opponent making room is a strong image |
| PaRappa's weakness | Players struggle to work out Cool, and community accounts of how freestyles score disagree ([ResetEra](https://www.resetera.com/threads/parappa-the-rapper-and-my-struggles-with-the-cool-rating-system.635051/), [GameFAQs](https://gamefaqs.gamespot.com/boards/466378-parappa-the-rapper-2/47502115)) | C | **Copy the structure, not the opacity.** The player must see what earned the response |
| PaRappa's cut encore | An unused stage had the audience copy PaRappa; the idea reached the sequel ([VGFacts](https://www.vgfacts.com/game/parappatherapper/)) | C | Being copied is a reward in itself. The storyboard already plans this at C01 |
| Space Channel 5 | Copying moves fills a ratings meter. High ratings bring a visible aura and more stamina next stage; low ratings can end the game. In Part 2, rescued people dance along ([Wikipedia](https://en.wikipedia.org/wiki/Space_Channel_5), [Part 2 review](https://sourcegaming.info/2024/07/28/beat-the-backlog-space-channel-5-part-2/)) | B, C | An audience as the score reads instantly. People joining in beats a number |
| Rhythm Heaven | Try Again, OK, Superb. Superb gives a medal that unlocks extras. A Perfect attempt is offered only on Superb-rated games, for three plays, and pays a gift of text or music ([StrategyWiki](https://strategywiki.org/wiki/Rhythm_Heaven/Gameplay), [Rank](https://rhythmheaven.fandom.com/wiki/Rank)). Tsunku: clearing isn't terribly hard; a high or perfect score takes real grasp of the rhythm ([Iwata Asks](https://iwataasks.nintendo.com/interviews/wii/rhythmheavenfever/0/5/)) | A for Tsunku, C for rules | **The strong challenge is offered only after you've shown you can.** Clear is cheap, mastery is deep |
| Elite Beat Agents | A meter drains and refills. Each scene's outcome is shown as a good or bad story panel, and you can stumble and still pass ([StrategyWiki](https://strategywiki.org/wiki/Elite_Beat_Agents/Walkthrough), [VGChartz](https://www.vgchartz.com/article/258412/elite-beat-agents/)) | C | Performance can change the picture without blocking progress |
| Hi-Fi Rush | The team avoided a fail state where the game refuses an action played out of time ([Unreal Engine interview](https://www.unrealengine.com/en-US/developer-interviews/hi-fi-rush-was-inspired-by-shaun-of-the-dead-and-futurama)). Off-beat attacks still land, delayed ([review](https://videogamelizard.com/reviews/hi-fi-rush-review/)). Rank rewards timing; guides disagree on 85% or 90% ([GameRant](https://gamerant.com/hi-fi-rush-how-to-get-s-rank/), [GamingBolt](https://gamingbolt.com/hi-fi-rush-guide-how-to-get-s-rank-and-farm-gears)). Levels are planned like songs ([Digital Trends](https://www.digitaltrends.com/gaming/hi-fi-rush-john-johanas-interview/)) | A for the first, B and C after | Style is graded, and the game keeps moving regardless. Build by intro, verse, chorus |
| Crypt of the NecroDancer | The groove chain multiplies gold; a missed beat or a hit resets it, and one item protects it ([wiki](https://necrodancer.miraheze.org/wiki/Groove_Chain), [tips](https://crypt-of-the-necrodancer.fandom.com/wiki/Tips_and_Hints)) | C | Great for a game built on tension, wrong here. A bonus you can lose is a punishment. Ours should fade quietly |
| Patapon | Combos bring Fever; the tribe's chants change as the beat lifts. Players report that Fever is pickier to hold, and that the chanted "Fever" can throw off their timing ([Wikipedia](https://en.wikipedia.org/wiki/Patapon), [PlayStation Blog](https://blog.playstation.com/2008/02/29/patapost-friday-pata-tips-1/), [TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/AwesomeMusic/Patapon), [GameFAQs](https://gamefaqs.gamespot.com/boards/942065-patapon/41832944)) | B, C | Voices joining in is a real thrill, **but rewards mustn't disturb timing**. Keep them off the judged beats |
| Just Shapes & Beats | Party or easy mode removes penalties and rewinds; Hardcore adds attacks and cuts reaction time, added later ([Nintendo Life](https://www.nintendolife.com/reviews/switch-eshop/just_shapes_and_beats), [Wikipedia](https://en.wikipedia.org/wiki/Just_Shapes_%26_Beats)) | B | Safety and challenge are separate settings on the same song |
| DDR | Beginner mode passes first-stage players whatever their accuracy ([DDR Extreme](https://en.wikipedia.org/wiki/Dance_Dance_Revolution_Extreme)) | B | The first room should be safe for the very new. The garden is already forgiving, at 75% |
| Beat Saber | Five named difficulties, varying speed and density ([BSMG wiki](https://bsmg.wiki/mapping/basic-mapping.html)). No Fail: no score penalty unless energy runs out, then ×0.5 ([Beat Games](https://x.com/BeatSaber/status/1357406655055605760)) | A, C | A safety net with an honest, stated limit. These are chart difficulties chosen by the player; ours is offers earned in play |
| Dance Central | Each song has a freestyle section with earned photo moments, and a later game let players turn it off ([Wikipedia](https://en.wikipedia.org/wiki/Dance_Central_(2010_video_game)), [manual](https://www.videogamemanual.com/xbox360/Dance%20Central%202.pdf)). Break It Down teaches moves ([GDC Vault](https://www.gdcvault.com/play/1014957/Break-it-Down-How-Harmonix), [prototyping article](https://www.gamedeveloper.com/design/practice-inside-i-dance-central-i-s-prototyping-process)). **I found nothing on an audience system** | B | Teach with small building blocks, and test with the worst dancers on the team |
| Thumper | Grades follow accuracy across everything hit. Perfect turns are bonuses, but one guide says some top grades need them; a player review says their window is too harsh ([Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=1255221235), [reviews](https://steamcommunity.com/app/356400/negativereviews/?l=english&browsefilter=toprated), [TrueAchievements](https://www.trueachievements.com/a238527/all-s-rank-achievement)) | C | **If a top grade requires it, it isn't optional.** Bonus windows that feel unfair get abandoned |
| Rock Band and Karaoke Revolution | Crowd meter: boos in the red, cheers in the yellow, sing-along in the green. Karaoke Revolution's crowd claps in rhythm ([Crowd Meter](https://rockband.fandom.com/wiki/Crowd_Meter), [design essay](https://www.giantbomb.com/profile/gamer_152/blog/let-there-be-rock-the-design-of-rock-band/122285/), [Wikipedia](https://en.wikipedia.org/wiki/Karaoke_Revolution)) | C, B | The best precedent for audience as a feedback system. Take the top half, drop the boos |
| Rez | Your actions are timed to the music and add layers to it ([Wikipedia](https://en.wikipedia.org/wiki/Rez_(video_game)), [PlayStation Blog](https://blog.playstation.com/archive/2017/10/20/classic-levels-deconstructed-tetsuya-mizuguchi-musician-adam-freeland-dissect-rez-infinites-area-5)) | B | The game's quarter-beat flick ornaments already do this [O] |

### Optional challenge and teaching

| Source | What the excerpt says | Grade | Lesson [J] |
|---|---|---|---|
| Hayashida, via [Game Developer](https://www.gamedeveloper.com/design/the-secret-to-i-mario-i-level-design) and [Wikipedia](https://en.wikipedia.org/wiki/Koichi_Hayashida) | A level follows introduction, development, twist, resolution: learn a mechanic, then use it somewhat harder, then a surprise. He became rigorous about this around 3D Land | A | Direct support for one new idea per level |
| Super Mario 3D World, [guide](https://mariopartylegacy.com/guides/super-mario-3d-world/green-stars), [Wikipedia](https://en.wikipedia.org/wiki/Super_Mario_3D_World) | Green Stars are optional, but open optional levels. A later world needs many | B | Optional rewards lead to more optional content, not to the ending |
| Super Mario Bros. analysis ([LinkedIn](https://www.linkedin.com/pulse/perfect-game-tutorial-analyzing-super-marios-level-design-iyer), [25 Years Later](https://25yearslatersite.com/gaming/features/the-original-super-mario-bros-is-a-master-class-in-game-design/)) | Teaches in safety before raising the stakes | C | Same direction |
| Celeste, [Steam](https://steamcommunity.com/app/504230/discussions/0/3288067088110345253/), [fan wiki](https://celeste.ink/wiki/Fun:A_Cautionary_note_about_golden_strawberries) | Players describe strawberries as a bonus with little reward beyond a mark | C | Weak, but suggests that a bare mark of mastery can be enough for those who want it |
| Rhythm Heaven's practice sections ([Iwata Asks](https://iwataasks.nintendo.com/interviews/wii/rhythmheavenfever/0/2/)) | There is practice before the real game, with some elements held back until then | A | Small support for showing first |
| Adaptive music: [arXiv 1907.01154](https://arxiv.org/pdf/1907.01154), [Game Audio Co.](https://www.thegameaudioco.com/making-your-game-s-music-more-dynamic-vertical-layering-vs-horizontal-resequencing) | Layers and re-sequenced sections are the two standard methods and combine well. Many academic systems were never evaluated with users | A, B | **Music reacting to skill is common practice, with little measured proof of benefit** |

### What I take from all this [J]

1. **Offer, don't adjust.** The strongest fit is the Rhythm Heaven and PaRappa pattern: earn the chance, then choose. It sidesteps most complaints about adjustment, since nothing is taken or eased.
2. **Keep the bar low to clear and the ceiling high.** Tiers stay the path. Style is what sits above.
3. **Add, never remove.** Boos, chain resets and lost multipliers suit other games. This one has already ruled out insulting text and game-over screens.
4. **Reward through people joining in.** Rock Band's sing-along, Space Channel 5's followers and PaRappa's encore all point at it, and this game is about earning respect at a party.
5. **Show the cause.** PaRappa's lesson: if players can't tell why, the feature fails.
6. **Peaks need valleys.** Booth's structure. A system that only rises with skill ends with a good player sitting at maximum, which is no longer exciting.

## Part 3: the proposal for Kumbia Kombat [J]

### The safety rules, stated first

These are tests, not intentions.

1. Heat never changes a required note, a timing window, `requiredHits`, a tier, whether a level clears, or how long it takes.
2. A player who never flicks can finish every level, hears every tier and sees every earned moment.
3. Ignoring a dare, or attempting and missing it, leaves progress, combo, crowd support and clock exactly as they'd be without the dare.
4. Optional inputs can't take a tap from a required note.
5. No dare in a room's first phrase, after a failed phrase, or after a phrase with any dropped note.
6. Nothing appears that shows what you failed to earn, in play or at the end.
7. No top grade or required gate may ever depend on answering dares.

### The centre: tension and relief

**The problem with my first draft, which the owner's note corrected.** [S] With a rule that only rises, a good bar run reaches the top by its fifth phrase, then stays there for five more. Nothing's left for tier 4.

So there are three separate inputs, and what the player sees comes from all of them. This follows Booth's split between how intense things are and how hard they are.

| Input | Means | Moves | Who gets it |
|---|---|---|---|
| **Music level** | The current tier, 0 to 4 | With required passes, as now | Everyone |
| **Heat** | How well the player's doing, 0 to 3 | Slowly, between phrases | Earned |
| **Pace** | Where we are in the cycle: Build, Sustain, Peak, Fade or Relax | By the phrase, tier and room. Fixed rules, no chance | Everyone |

**Skill raises the peaks. It doesn't remove the valleys.** Beginners still get a cycle, built from music and scenery, with smaller peaks.

#### Within a phrase (16 beats)

The two curves run in opposite directions, and that's the key. **The show peaks when the player has nothing to do. The player's work peaks when the show goes quiet.**

| Beats | What's happening | Show | Player |
|---|---|---|---|
| 0 to about 6.5 | The call's notes | **Build.** The opponent must be readable. No competing events | Watching, low effort |
| 6.5 to 8 | The call's tail | **Peak.** Dare or show move begins, music leads in | Getting ready |
| 8 to about 10 | Handoff | **Peak Fade.** The spin finishes and only then steps away, as Booth's state does and the owner's fourth-round ruling asks | Starting |
| 10 to about 14.5 | The response | **Quiet.** Nothing new starts near the cues | **Peak effort** |
| About 14.5 to 16 | Last note | **Release.** The answering flick, its musical reply, a guest wave | The payoff |
| Start of the next call | | **Relax.** A short settle before the next build | Breath |

#### Within a level

| Pace | When | Dares and show moves | Music | Scene |
|---|---|---|---|---|
| **Build** | Tiers 0 to 2 | Heat counts for at most 1 at tier 0, and at most 2 at tiers 1 and 2 | Tier arrangement, some party sounds | Slow, meant to pass unnoticed |
| **Sustain** | Tier 3 | Full rate for this player's Heat | Further party sounds | Holds; flames and water wake |
| **Peak** | Tier 4, the proof phrases | The biggest versions, saved for here | Everything earned | Everything in this room's reach, and this one may be noticed |
| **Peak Fade** | The win | Nothing new; moves finish | The music cools, per the fourth-round ruling | Guests thin out as the existing departures do |
| **Relax** | Cinematic, then the next room's first phrase | No dare | Next room's low tier | Back to near still |

**Two kinds of breath inside a level:**

- **Earned breath.** At most 3 dares in a row, then one plain phrase, with the top party sound held back for that phrase. Patterned, not random.
- **Needed breath.** A failed phrase is the level's highest stress. Booth's director relaxes after high stress, and so does this: no dare, and the recovery the storyboard already specifies. **This must read as the party giving room, not as a loss.** It's the one place where "cools down" and "punishes" sit close together, so it needs a watchful playtest.

**Simulation with these limits.** [S] The tier limits barely change dare counts: an expert in the bar goes from about 5.2 to 4.9 per run, and the garden doesn't change. So the limit shapes *when* peaks arrive without starving skilled players. Both figures describe dare counts only; the effect on feel is untested.

#### Across the campaign

A saw-tooth: each room starts low and peaks higher than the last. Cinematics are the valleys.

| Room | Pace in the campaign | Top wake step, proposed (see the ladder below) | Why |
|---|---|---|---|
| `garden` | Build | 3 | Learn the room responds. Matches its small crowd budget |
| `bar` | Build | 4 | |
| `pool-garden` | Build, the breakaway | 4 | Fast duo, outdoors |
| `cool-crowd` | Sustain | 5 | The crowd copies him |
| `restroom` | **Visual relax at high tempo** | 2 | Fast music, a nearly still corridor. Tension from speed, relief for the eye |
| `vip` | Peak | 6 | The only full room, in step with the whole-room ovation |
| Ending | Fade, then Relax | Everything winds down | Timer stopped, he sits. The quietest moment should be right after the biggest |

The order of levels isn't settled, and new levels will arrive. Pace belongs in each level's data, and the campaign sheet should gain a Pace column.

### The performance signal: Heat

Each resolved response phrase gives points, from data the session already has. The total, called **Sway**, stays between 0 and 12.

| How the phrase went | Sway |
|---|---|
| Failed | −3 |
| Passed, some notes dropped | 0 |
| Every note hit | +1 |
| Every note hit, at least half PERFECT | +2 |
| Passed with at least one credited flick | +1 more |

Sway sets **Heat**, with a gap between the rising and falling thresholds so it can't flicker:

| Heat | Rises at Sway | Falls when Sway is below |
|---|---:|---:|
| 1 Warm | 3 | 1 |
| 2 Hot | 6 | 3 |
| 3 On fire | 9 | 6 |

Other rules:

- **Changes only between phrases,** together with the music boundary, and locks for the coming phrase.
- **A rise holds for at least a phrase** before it can fall.
- **Room change:** carry half the Sway, so a good run enters warm. Reset to 0 at an entrance reset. The first phrase of a room is always plain.
- **Pause:** Sway saves and restores with the crowd checkpoint, so replaying can't farm it.
- **No randomness.** Same play, same Heat. That's what keeps it testable.
- **Flicks speed it up but aren't needed,** so taps-only players still get there.
- **Timing counts for little on purpose.** Latency calibration isn't done yet (`plan/roadmap.md` item 02), so a Bluetooth player might never see PERFECT and must not be locked out. Wrong taps aren't used either; they're thumb noise.

**How it drives things.** These are the most each Heat allows. Pace decides when, and the level and room limits above still apply. Heat 3's column is only reached at tier 3 and above.

| | Heat 0 | Heat 1 Warm | Heat 2 Hot | Heat 3 On fire |
|---|---|---|---|---|
| **Opponent's show moves** | As today, by tier | Same | A second move per cycle where a gap allows | Biggest versions |
| **Dares** | None | One phrase in 3 | One in 2 | 3 in 4, always leaving a rest |
| **Music** | The full tier arrangement | Adds light shakers or fills | Adds hand claps | Adds the party's voices |
| **Scene** (see party-up) | Follows the music level | Same | One wake step sooner | One step sooner, bigger movement |
| **Audience** | Today's budget and pace | Flick waves reach further | One or two extra guests stand | The room's small extra budget, clapping together |
| **Mācron off turn** | Taps along | Claps | Bigger claps | Moves with the opponent's groove |
| **Mācron's spin** | As today | As today | Larger finish | Largest, plus the opponent's reply |

The frequencies are starting points for tuning, not findings.

**Why it shouldn't feel like rubber-banding.** Nothing in the row above can slow you down or hold you back. Falling a level means the party cools a little. It's not a penalty, and the required music tier already gives the required feedback about failures.

**Simulation.** [S] Throw-away Python, 2,000 runs per row, using the real pass rules. **The player types are invented,** so these figures only check the arithmetic. "Naive" is a plain moving average with one set of thresholds, for comparison.

| Level | Player type (hit %, perfect %, flick %) | Phrases | Peak Heat 0/1/2/3 (% of runs) | Dares per 10 phrases | Up-then-down flips per 10 phrases, rule vs naive |
|---|---|---:|---|---:|---|
| garden | Expert, flicks (99, 80, 70) | 6.0 | 0/0/0/100 | 4.0 | 0.00 vs 0.05 |
| garden | Expert, taps only (99, 80, 0) | 6.0 | 0/0/7/92 | 4.2 | 0.00 vs 0.05 |
| garden | Average (93, 45, 10) | 6.7 | 4/34/46/17 | 1.5 | 0.00 vs 0.46 |
| garden | Beginner (84, 20, 0) | 11.4 | 75/25/0/0 | 0.1 | 0.00 vs 0.49 |
| garden | Struggling (72, 15, 0) | 57.8 | 96/4/0/0 | 0.0 | 0.00 vs 0.14 |
| bar | Average | 14.5 | 0/2/15/83 | 2.4 | 0.01 vs 0.61 |
| bar | Beginner | 82.4 | 7/81/12/0 | 0.1 | 0.00 vs 0.48 |
| pool-garden | Average | 11.2 | 0/7/27/66 | 2.1 | 0.00 vs 0.58 |
| pool-garden | Beginner | 22.2 | 38/58/4/0 | 0.2 | 0.00 vs 0.55 |

What this shows:

- Beginners and struggling players almost never see a dare.
- Even a clean garden run reaches Heat 3 by its fifth phrase, taps only: Heat goes 0, 1, 2, 2, 3, 3.
- A clean garden run gets only 2 or 3 dares, so the garden can teach one idea and no more.
- Alternating pass and fail stays at Heat 0.
- **My first draft failed this test.** A lower threshold got stuck at Heat 1, and a later version flickered between 0 and 1 under alternating pass and fail. Both were fixed by the numbers above, so expect more changes in play.
- **Two warnings:**
  - One perfect-otherwise player failing every third phrase still climbs to Heat 3. Dares are still held back after each failure, but this may be too generous.
  - The current `PartyAutoplay` pattern, modelled by hand, gets only 1 dare in the garden. The owner reviews through autoplay, so it needs a show-off mode, or the feature won't be visible.
- The bar's beginner cleared only 60% of runs within my 120-phrase limit. That's an effect of invented numbers meeting its 7-of-8 rule, not a finding about real players. It's a reason to watch that room in a playtest.

### The adornment ladder

**A word first.** Today `adornments` in the scores means the player's flick ornaments, and `accents` means the grammar's timed moves. The swing research asked for a new word for what dancers do. I suggest **dare** for an opponent move that invites an answer, and **show move** for one that doesn't. The owner may prefer another word.

Every dare has the same shape: **the opponent does it in the call, and Mācron may answer in the response.**

| Rung | What the opponent does | How the player answers | What a good answer earns | Ignoring costs | Fits where [O] | Needs |
|---|---|---|---|---|---|---|
| 0. Show move | Spin or flare, no question asked | Nothing | Nothing asked | Nothing | Everywhere | Exists; overflow pending |
| 1. **Spin dare** | Spins at the end of the call, mid-floor, overflowing into Mācron's turn, then steps away and gestures "your turn" | **Flick on the phrase's last note**, already flagged | Bigger spin, an answering musical phrase, a wider guest wave, double Pizazz, the opponent's visible nod | Nothing | **All levels, all tempos** | Overflow, Heat, last-note mark |
| 2. Double dare | A short flare in mid-phrase, then the spin | Two flicks, in different directions. This is the existing style chain | The chain's message and a further wave; a bigger reply | Nothing | `garden`, `bar`. **Not `pool-garden`**: only one safe note | Same as rung 1, plus chart data |
| 3. Grace note | A small extra clap or stamp in a rest, marked as a small optional cue | One extra tap in the same zone | A little fill in the music, a small Pizazz bonus | Nothing, and no "KEEP THE PULSE" | Gaps below | **Optional-note lane** |
| 4. Off-beat accent | The same, on an off-beat | The same, a harder tap | A syncopated music reply, the crowd's claps shifting | Nothing | Gaps below | Same; suits `cool-crowd`'s idea |
| 5. Swap (lawn duo) | The two dancers switch places at the end of the call | A flick on the last note. Any direction credits; a sideways one gets an extra reaction | Duo's reply, the swap's music | Nothing | **Only rung-1's note,** at 128-160 BPM | Duet foundations, a swing reviewer |
| 6. Encore | At Heat 3, after the win and with the clock stopped, the opponent steps aside, and guests copy Mācron's flicks over the cooling music | Free flicks, unjudged | Being copied. No score | Nothing | After any clear | Cleared-phase input, crowd copy |
| 7. Signature step | **Reserved. Comes from the salsa teacher, as ruled. No content is proposed here** | To be set after the interview, within the same input limits | Interview guide already asks for beginner, confident and showing-off versions, which could map onto Heat | Nothing | Unknown | Interview, movement register |

**Safe gaps for optional taps.** [O, S] Quarter-beat positions at least 285 ms from every required note. That's a required note's ±180 ms window, plus the ±75 ms perfect window, plus a 30 ms margin. It's my starting rule, not a measured thumb limit.

| Level, BPM | Safe positions in the 8-beat phrase |
|---|---|
| `garden`, 92-104 | 0.5, 1.5, 3, 3.25, 3.5, 4.5, 5.5, 7, 7.25, 7.5 |
| `bar`, 100 | Same as the garden |
| `bar`, 112 | 3.25, 7.25 only |
| `pool-garden`, 128-160 | **None** |

So rungs 3 and 4 work at slower tempos and vanish as music speeds up. The data validator should switch them off per tier, instead of leaving it to judgment. The fast swing level relies on the flick alone. That suits the swing research's point that dancers simplify as tempo rises.

**No new input types.** Taps in fixed zones and flicks on notes, with one thumb. There are no chords, no holds, no zones that move, and nothing above the thumb band. Dare moves can't use the limb-accent drawings: `requireFrames` already reserves those so a groove can't read as a call, and the rule should extend to dares. A big kick must not look like a foot call.

**Flick direction stays free** for rungs 1, 2 and 5. Requiring a specific one would make it a memory test with a one-thumb gesture, and turn a free expression into a thing you get wrong.

### Teaching by showing

No explanatory cards, following the storyboard. The sequence for a player's first dare:

1. **Seen first.** Show moves already run from tier 1, so the player has seen spins before being asked.
2. **Asked once, clearly.** The opponent spins and gestures with the `invite` drawing. The last note's flick mark, today a 16-pixel icon, pulses larger.
3. **Rewarded loudly the first time.** The whole reward fires, including the opponent's reaction. This is the moment that teaches it.
4. **Then it's dropped.** After two ignored prompts in a room, the large pulse stops and only the ordinary mark stays. If the player ignores three dares in a row, the rate drops to one phrase in 3. This isn't simulated. It's politeness, not a penalty. Show moves continue.

In a level, the steps match Hayashida's four parts: show at tier 1, dare at tier 2, a twist at tier 3, and at tier 4 the dare meets the full music. With only 6 to 10 clean phrases, that's a hope and not a promise: many players won't see all four.

**Open worry.** Whether players discover the flick at all is unmeasured. The first phone test should check this, as `plan/roadmap.md` item 01 already requires a pass with optional swipes.

**Reduced motion.** A dare becomes a held finish pose plus the same mark. The answer's unchanged. Marks must also not rely on colour alone (`plan/roadmap.md` item 09).

### Rewards

| Channel | Always there | Heat adds | A skilled answer adds | Guard |
|---|---|---|---|---|
| **Music** | All five tiers, complete at every Heat | Party sounds, joining at phrase boundaries | The existing ornament, now a bigger phrase; quantized | Party sounds leave only when Heat falls, so one failed phrase doesn't strip the music. Nothing percussive that sounds like a cue. Voices stay off judged beats, and under them |
| **Audience** | The room's budget, as designed | `hotBudgets`: a few more guests, a bit sooner | A wider wave, and the crowd copying the flick | No boos. Hot budget can't exceed the next room's base budget, and VIP's whole-room ovation stays unique |
| **Opponent** | Tier-driven show moves | More of them, bigger | A nod or reply | Dance layer reads Heat, never writes it |
| **Mācron** | Spin on any flick; clap on his off turn | Bigger clap and groove, per the third-round ruling | Larger finish | Signature step only after the interview |
| **Score** | Pizazz per flick | No multiplier from Heat, so early rooms and taps-only aren't devalued | +100 extra per answered dare, limited by the slots in the phrase | Elapsed time and Pizazz stay separate columns (`plan/roadmap.md` item 08). Dares take no extra time |
| **Level end** | The earned moment, unconditional | A small tag in the cooling music: an extra guest clap, the opponent's wink or grin | Stamps: **Hot Party** (ended at Heat 3), **Danced Back** (answered most dares) | Show stamps only when earned, with no empty slots. High five and "Chingón" stay unconditional |

**How the music can actually do this.** I had assumed layers fading in. The two parallel notes (`plan/research/local-music-models-2026-11-06.md`, `plan/research/runtime-music-assembly-2026-11-06.md`) change that:

- Their recommendation is **one whole take per tier**, each at its own tempo, switched at phrase boundaries.
- Layers from separate generations are reported as 20 to 80 ms off. Only stems cut from a single take stay together, and the tools that cut them have a licence problem.
- Stems cost memory: their arithmetic gives 88 MB for six stereo stems over 16 bars.

So my earlier idea of Heat layers as stems is **the wrong first step**. Recommended order [J]:

1. **Party sounds as short samples.** Claps, shakers, shouts and guest voices, scheduled by the transport on its beat grid. The transport already schedules flick ornaments this way, and the assembly note keeps the synth for unpitched hits. They need no lock to a take beyond its beat grid, they aren't tied to a tempo, and they can be shared between levels. This is the audible Heat, and it's cheap to test.
2. **A tier's stem, if a single-take stem proves good.** The runtime note says it would accept stems, so this stays possible.
3. **A second "hot" take per tier,** only if the first two aren't enough. It doubles the takes per level.

Unpitched sounds sidestep a real problem: pitched flick ornaments need to know the key of whatever the model wrote. The manifest should carry the key per take, or the ornaments should become unpitched for levels without it.

**Where the owner's fist-bump wink fits.** The third-round note wants the wink to read as approval, so it shouldn't become an expert-only prize. Keep it for everyone and find a different extra for hot runs. The owner decides.

### The party-up ladder

**Owner's ruling, fifth round:** backgrounds and cosmetic assets SHALL follow the music score, and "everything should slowly party up". **This belongs to everyone, not only skilled players.** A taps-only player who clears a level sees the room wake.

**Which step is reached.** One small rule, from the same inputs:

> Reached step = the music tier's step, plus one if Heat is 2 or more, never above the room's limit.

When a tier falls, the step follows only after two phrases, and it fades slowly. So a failed phrase doesn't make the room visibly deflate.

| Step | What wakes | Music level | How it moves | Exists today? [O] |
|---|---|---|---|---|
| 0 | Lamp glow, potted plant idle, waiter's route | Always | Today's ambient clock | Yes: `scenery` in the level files |
| 1 | **Lights** breathe over a phrase | Tier 0 to 1 | Slow brightness change within today's 0.88-1.00 limit | Glow yes, phrase link no |
| 2 | **Leaves and plants** sway | Tier 1 | Small sway every 2 beats | The sprite exists; beat link no |
| 3 | **Hanging things:** lanterns, hanging plants, string lights, umbrellas, tablecloths | Tier 2 | Slow swing every 4 beats | Painted into the plates |
| 4 | **Flames, water, glass:** candles, torches, pool glints, cups | Tier 3 | Shape on the beat, not brightness | Painted into the plates |
| 5 | **People at the edges:** waiters step in time, swimmers bob. Guests already follow their own budget | Tier 3 to 4 | Authored steps | Waiter yes, in-time steps no |
| 6 | **The whole room together:** every prop type awake at once, with guests | Tier 4 proof, VIP only as proposed | Larger, and in unison | No |

**Every room gets its own full swing.** The room limits below step 6 would otherwise leave a garden sitting still through its last tiers. So in every room's proof phrases, whatever has woken hits a shared accent every 2 bars, and cups with straws dance wherever a room has them. That's the room's own peak, as the owner's "at full swings" asks. VIP alone gets every layer at once. The accent is small for everyone and largest at Heat 3.

#### How the slow reveal fits Build, Sustain and Fade

Ranitas's method, as the owner's ruling carries it over:

- **Fade in at the final position.** Nothing slides into place.
- **Movement grows separately,** after it's visible, from zero.
- **Smooth entrances:** quintic smootherstep (`Awakening.reveal`), zero speed at both ends, never switched on at full speed.
- **Measured in music beats, not seconds,** so it freezes on pause and follows tempo changes. Sampled as a pure function, as `partyAmbientAt` and the dance grammar already are.

Applied to pace:

| Pace | Reveal |
|---|---|
| **Build** | Slow reveals are meant to pass unnoticed. Only one step's entrance starts at a time, ideally during the player's response, when their eyes are on the cues |
| **Sustain** | Reached steps hold. Movement grows no further |
| **Peak** | **The one time being seen is the point.** The shared accent is the moment a player looks up and realises the whole place has been dancing |
| **Peak Fade** | After the win, movement shrinks first, then the guests leave, in the cooling music |
| **Relax** | The next room starts near still |

**Handing over from ambient to beat.** Plants already move on a wall-clock wind. Don't jump their phase: fade the wind's size down while the beat's size fades up, so no sudden step shows.

**Limits on this, honestly stated:**

- **My timings are artistic, and no study supports them.** Ranitas says the same of its own.
- **We're much faster than ranitas.** Its entrances take 110-180 s. A clean garden is about 100 beats, 61 s, with each tier about 10 s. The bar is about 93 s, with about 18 s per tier. [O, arithmetic] Starting values: 32 beats to fade in and 48 to 64 for movement, or about 20 to 40 s. These fall outside what ranitas tried, and **some players will notice. That's fine:** the ruling itself says so.
- **The real slow channel is the campaign.** Rooms reach further as the run goes on, over several minutes.
- **It's my inference, not a finding,** that eyes on the tap zones make reveals easier to miss. A busy thumb might also mean nobody ever sees step 3. Both are worth watching.
- **Ranitas is a quiet game.** Its goals are calm and discovery. This one ends in a party. Only its method transfers.

#### Keeping out of the way

Attention has an order: **tap zones and cues, the opponent's call, Mācron, the crowd, the scene.** Rules, in that order:

1. **Nothing moves in the tap band.** The band at y 0.65 to 0.97 stays still except for cues, and the floor reflections painted there stay fixed. The room compiler already refuses anything but floor in that band.
2. **Keep clear of cue paths.** Cues travel from mid-screen to the zones. A prop's whole movement range counts, as `plan/party-perspective-and-life.md` already says, not just where it rests.
3. **A quiet column behind the opponent.** About x 0.35-0.65 and y 0.3-0.6, around their mark. In today's plates this is doorway and back wall, so it can stay still. Props belong in the side columns and the top. Check with a mask per room.
4. **Space, not time.** Don't duck the scene during each call: fading on and off every 16 beats would itself be a flashing signal. Keep the area around the opponent quiet all the time, and only hold back the shared accents during call notes.
5. **Never look like a call.** No prop movement may follow the required limb or side. Left and right props move together or by a fixed pattern. No hand or foot shapes, and no pointing towards a tap zone.
6. **Beat-locked is fine, if it's true.** All movement reads the transport, so the room is honest about the beat. It must never run ahead of what's heard.
7. **No flashes.** Flames change shape, not brightness. Light stays within today's limits, under the no-strobe rule.
8. **Reduced motion** keeps the room still. The player still hears the party, and guests use the existing compact gestures.
9. **The session never reads any of it.** Removing every prop must give the same score, and a test will prove that.

#### The art this needs

**Today's rooms are flat paintings.** [O, looked at all three plates]

| Room | Painted in and can't move today | Already separate | Missing altogether |
|---|---|---|---|
| `garden` | Hanging plants, lanterns, string lights, vines, large pots and palms, floor reflections | Plant sprites, waiter, lamp glows | Candles, cups, flames |
| `bar` | Pendant lamps, ferns, pots, bottles, ice bucket, stools, floor reflections | Plant sprites, waiter, lamp glows | Cups on the bar, candles beyond the painted ones |
| `pool-garden` (a draft) | String lights, post lamps, pool water, palm, hedge | Lamp glows only. `plants` is empty and there's no waiter | **Umbrellas, flames, and the lawn's tables, which the owner asked for and the plate lacks** |

Moving painted pixels isn't an option. As `plan/party-perspective-and-life.md` notes, sliding a copied patch over the original leaves ghosts. It needs clean backgrounds.

**The owner has approved this:** backgrounds and some assets may be regenerated into layers, and shared props are worth the compute.

**The shared prop library.** Each prop is made once and placed in many rooms by data. Every prop needs a transparent sprite, a pivot, a movement range, a wake step, and a palette that can shift to the room's. Suggested order [J], by how much it adds per unit of work:

| Order | Prop | Why this order | Works in |
|---|---|---|---|
| 1 | **Candle and small flame** | Tiny, cheap, a clear first test. Tests the shape-not-brightness rule | All rooms |
| 2 | **Potted plant, then hanging plant** | Sprites already exist, with `plant_a`. Tests beat-locked sway on known art | All rooms |
| 3 | **Hanging lantern or pendant** | Swings simply about one pivot. Needs matched glow | All rooms |
| 4 | **Cup with a straw** | The owner's picture of full swing, and the running gag of each room's peak. Very small, so it must read at phone size. Probe that first | Bar, lawn, VIP |
| 5 | **Umbrella and table** | Bigger, and needs depth sorting. The lawn lacks them | Lawn, others outdoors |
| 6 | **String lights** | Long and thin, so hardest to move as a sprite. Possibly lights only, with no movement | Outdoor rooms |
| Reuse | **Party members** | `party-life` and guest atlases exist. New dance clips come from the crowd plan and `assets/art/ensemble` | All rooms |
| Room-specific | Pool water, torches, bottles | Masks, not library props | One room each |

**Open questions on the art:**

- **Pixel art and smooth growth clash.** [J] Ranitas grows movement continuously on painted layers. Pixel art sways by small rotations, which may crawl, and `plan/duet-foundations.md` measured crawl under scaling. The likely answer is authored frame sets at two or three sizes, changing at the top of a swing. Needs a probe, on a phone.
- **Depth and scale** come from `PartyFloorPlane`, as for people. Props painted by a separate generation might not match a room's light. This hasn't been tried.
- **Memory.** About 137 MiB of atlases load at start. A shared atlas helps, but it needs the planned per-level loading.
- **New rooms are easier.** The room compiler already has an id map and a list of `props`, so a room can leave props out of the plate and mark where they stand. Existing garden and bar plates need regenerating or careful inpainting. **Which of those works is unproven,** and the owner must accept any new plate.

### Rules that have to change

Checked against what the existing documents fix. The owner's fifth-round ruling settles the main conflict. The rest:

| Rule, and where | Status | What changes, and why |
|---|---|---|
| "Avoid making every object bounce to every beat", and ambient separate from music, `plan/party-overhaul.md` | **Already overruled** by the fifth round | Keep the limit it was protecting: don't make everything move on *every* beat. The ladder uses 2-beat and 4-beat swings |
| "Cosmetic effects never request progression/music tiers", `plan/party-overhaul.md` line 187 | **Keep, unchanged** | The ruling sends influence from music to scene. This rule stops the reverse. Party sounds and Heat are not tiers and never call `requestTier`. If anyone expressed Heat by changing tier, this rule would be broken, and rightly |
| "Charts and judgment stay fixed", `plan/party-overhaul-research.md` line 59 | **Holds for flicks. Must be reworded for optional taps** | Rungs 0, 1, 2, 5 and 6 add nothing to the chart. Rungs 3 and 4 add judged optional taps. New wording: "**Required** notes and their judgment stay fixed." Only needed if the owner approves optional taps |
| "Each result is a pure function of the music beat and the sampled pose", `dance_grammar.dart` | **Must be extended** | Needs one more pure input: the phrase's plan, locked in at the phrase boundary. Still deterministic, and still can't affect score |
| "Optional adornments never supply required taps, tier credit or clearance", `plan/input-crowd-research.md` | **Keep, and it's the core safety rule** | Flicks raise Sway, which only changes offers |
| Flick "chains ... without adding lasting interest", the same file; the test "flourish waves cannot make seated holdouts stand"; `CrowdStageProfile` ceilings | **Must be extended, because of the owner's "more popular"** | Waves and earned interest stay as they are. Add a second, small, per-room `hotBudgets` ceiling driven by Heat. The test stays and a new one covers the second ceiling |
| "Pizazz remains 100 per newly credited adornment", the same file; "Pizazz-only award", `plan/music.md` | **Must change** if answers pay more | An answered dare pays +100 more, and a flick now raises Sway. New wording: "Flicks score only Pizazz, and may also warm the party." If you'd rather keep Pizazz at a flat 100, reward answers through the show alone |
| Waiter's and plants' "foreground-only ambient clock", `plan/party-perspective-and-life.md` | **Extended by the ruling** | Add a beat-driven part. Pausing still freezes both. Keep its no-flash light limits |
| "Music complexity and tempo follow authoritative gameplay state; the animation never independently advances them", `plan/storyboard.md` | **Keep** | No conflict |
| "Five original precomposed MIDI-style synth scores build and relax with performance", `openspec/project.md` | **Spirit fits. The word "synth" is out of date** after the owner's music rulings | Agrees with this whole section. Update when the music decision lands |

### GameFlow as a review checklist

Use it when reviewing the build, not as evidence that the design works. These are my readings, to be scored by people playing:

| Element | Question for this design |
|---|---|
| Concentration | Does moving scenery pull eyes off the cues? |
| Challenge | Does a skilled player still have something to reach for at tier 4? |
| Player skills | Do players discover the flick, and improve with dares? |
| Control | Do players feel they choose to answer, and aren't being tested? |
| Clear goals | Is it obvious the opponent is inviting an answer? |
| Feedback | Can a player tell what made the party respond? |
| Immersion | Does the room feel alive by the end? |
| Social interaction | Does the crowd feel like people responding to Mācron? |

### Over a long campaign

**One new idea per level, either required or a dare, never both.** The campaign sheet already has a "New idea" column.

| Level | New idea on the sheet | Rung introduced | Note |
|---|---|---|---|
| `garden` | Learn the mirror | 1, Spin dare | 2 or 3 dares in a clean run |
| `bar` | Hands and feet | 2, Double dare | Uses the existing chain |
| `pool-garden` | Duo | 5, Swap | Only after the duet exists. Until then, rung 1 |
| `cool-crowd` | Syncopation | 4, Off-beat accent | If tempo leaves gaps. Check at chart time |
| `restroom` | The rush | None new | Rungs 1 only. A level of speed |
| `vip` | All motifs recalled | Recall, 7 if ready | Rung 3 somewhere earlier, if phone tests support it |

Beyond these, **rungs run out before levels do**, because input is fixed. That's fine:

- New levels bring a new look and sound for an existing rung. A bartender's dip and a host's bow can be the same mechanic.
- Limit mechanical rungs to about eight, and add one only when a real gap appears.
- Mix rungs in recall levels every so often.
- Cost stays low because a dare needs one drawn move and one music phrase, and the rule is shared.
- A return to a plain level is a pacing tool. The restroom rush shows why.

**Rules live in data.** Shared defaults in one file, with a level overriding only what differs. A sketch, not a schema:

```json
// levels/index.json: shared rules for every level
"heat": {
  "phrasePoints": { "failed": -3, "dropped": 0, "allHit": 1, "halfPerfect": 2, "flick": 1 },
  "rise": [3, 6, 9], "fall": [1, 3, 6], "cap": 12, "carry": 0.5,
  "dareEvery": { "1": [1, 3], "2": [1, 2], "3": [3, 4] }
}

// levels/garden.json: what this level adds
"dares": {
  "introduces": "spin",
  "allowed": ["spin"],
  "hotBudgets": { "standing": 1, "cheering": 1 }
},
"pace": { "campaignRole": "build", "topWake": 3 },
"sceneryProps": [
  { "prop": "candle", "at": [0.18, 0.46], "wake": 4 },
  { "prop": "hanging_plant", "at": [0.09, 0.10], "wake": 3 }
]

// assets/art/ensemble/choreography.json: how a dare looks, per dancer
"dares": {
  "spin": { "clip": "spin_flare", "at": "callTail", "overflow": true, "invite": "invite" }
},
"showByHeat": [ /* accents, as now, with an added minHeat */ ]

// the audio manifest: how Heat sounds, from shared samples
"partySounds": [ { "sample": "shaker_a", "minHeat": 1, "everyBeats": 1 } ]

// a shared prop library file: one entry per prop, used by any level
"candle": { "atlas": "props", "pivot": [0.5, 1.0], "reach": 0.02, "clips": ["calm", "lively"] }
```

Validation should fail loudly, like the existing registry and sprite checks:

- Each dare's slot is checked against **every tier's BPM**, and any rung that doesn't fit at a tier is turned off.
- Named clips exist for every dancer in the level.
- Dare clips avoid reserved limb drawings.
- `hotBudgets` respect the next room's base budget.
- No level introduces two ideas.
- Every prop's full movement range stays out of the tap band, cue paths and the opponent's quiet column.

### What can be tested with what exists

| Test | How | Proves |
|---|---|---|
| **Ignoring costs nothing** | Replay one scripted input through `GardenSession` with dares on and off, comparing outcomes, tiers, `passedPhrases`, `combo`, `earnedSupport`, clear time | Safety rules 1 to 3. The most important test |
| **Taps-only finishes** | `party_autoplay_test.dart` with flicks turned off, across every level | Rule 2 |
| **Beginner floor** | Script failures and drops; no dare may be offered | Rule 5 |
| **Heat stability** | Pure unit test on the patterns above, limiting changes per phrase | Hysteresis |
| **No farming** | Extend "pause replays phrase and credited flourish cannot be farmed" to Sway and dare credit | Checkpointing |
| **Retry credit** | New test for the identity bug in Part 1 | The fix |
| **Optional can't steal** | Tap between an optional and a required note in `RhythmJudge`; the required one wins | Rule 4 |
| **Dare slots per tempo** | Registry-style test over `levels/*.json`, like `level_registry_test.dart` and `pool_garden_level_test.dart` | Rungs fit |
| **Art purity** | `dance_grammar_test.dart`: same beat and Heat gives the same frame | Dance layer stays separate |
| **Music boundary** | `tool/music/transport_check.dart`: a layer changes only at a phrase boundary, through pause and resume | Timing unaffected |
| **Pace determinism** | Unit test: same tier, Heat and phrase give the same Pace and plan, with no more than 3 dares in a row, and none at a failed phrase | The cycle |
| **Party-up sampler** | Pure tests in the style of `partyAmbientAt`: zero speed at both ends of an entrance, frozen on pause, same result at any frame rate, still under reduced motion | The reveal method |
| **Scene can't change score** | Clear a level with props removed and with props at maximum, comparing session outcomes | Rule 9 of keeping out of the way |
| **Prop envelopes** | A check in the room compiler and level registry, using `thumbLimbAt`'s band and the cue path sampler | Tap zones and call stay clear |
| **Owner's review** | Give `PartyAutoplay` a show-off mode that answers dares, using normal judgment | The owner can see it |

**Not testable this way:** whether it feels good, whether dares distract near-limit players, whether flicks get discovered, thumb travel, whether party sounds and moving scenery help or clutter, and whether Heat's response reads as cause and effect, whether the slow reveal goes unnoticed, and whether a cooling room feels like a punishment. These need the phone and fresh players.

### Foundations missing today

These are named to match `plan/foundations-2026-11-05.md`.

| Foundation | What's missing | Blocks |
|---|---|---|
| **Phrase report** | A per-phrase record of hits, perfects and credited flicks. The session keeps totals only; `_hits` is private | Heat |
| **Heat model** | Sway, Heat, checkpoint, carry between rooms | Everything here |
| **Pace director** | Build, Sustain, Peak, Fade and Relax across phrase, level and campaign. `plan/party-overhaul.md` proposed a `PartyDirector` to allow "settling between peaks". It was never built, and it's a good name to reuse | Everything timed |
| **Separable room layers** | **The largest gap. Rooms are single flat plates.** Needs clean backgrounds, separated props, masks for light and water, and a `RoomSceneDefinition` (named in `plan/party-overhaul.md`, not built). The `scenery` block handles only lamps, plants and a waiter | Party-up from step 3 |
| **Shared prop library** | One atlas and one data file of reusable props, each with pivot, range and palette. Approved in principle by the owner | Party-up, cost per level |
| **Party-up sampler** | A pure function of beat, step and Heat, with entrances in music beats. Ranitas's `reveal` is 3 lines; the rest is ours | Party-up |
| **Quiet-zone mask per room** | Tap band, cue paths and the opponent's column, as a check | Readability |
| **Dare schedule** | Which phrase offers what, from Heat and the level's data | Dares |
| **Turn overflow in the grammar** | Show moves in the call, and finishing past the handoff. Accents only play in `watch`. Already asked for in the fourth-round ruling | Rung 1 |
| **Optional-note lane in the judge** | Separate from required notes, excluded from `expire`, `_hits` and the combo, accepted after `_resolved`, and silent on a miss. `tap()` refuses input after the phrase resolves, which rules out slots in the phrase's tail | Rungs 3, 4 |
| **Party sound bank** | Shared claps, shakers and voices, with a Heat gate on the transport's scheduling. Notes gate only by tier today (`audibleAt`), and tier also means tempo | Music rewards |
| **Crowd hot budget** | A second ceiling alongside `CrowdStageProfile`. The current test stays for waves | Audience rewards |
| **Reward ladder** | Started in the campaign sheet, with no skill row | Level end, stamps |
| **Chart grammar** (already listed) | Flickable notes and safe gaps depend on charts and tempo; the pool has one slot. It should guarantee a minimum | Long campaign |
| **Movement register** (already listed) | Slot for the signature step | Rung 7 |
| **Playtest protocol** (already listed) | Fresh players on a phone, including discovery of the flick | Tuning everything |
| **Duet foundations** (already listed) | Two drawn dancers, floor tracks | Rung 5 |
| **Teaching state** | Remembering a player has been taught a dare. Durable save is `plan/roadmap.md` item 03. Until then, per run | Teaching |
| **Encore input after clear** | Gestures stay live only for the final flick's window | Rung 6 |
| **Word for opponent adornments** | The swing research's naming request | Clear data and talk |

**Edge noticed in passing.** [O, not run] In the pool garden at 160 BPM, a late tap on the last note plus a slow flick can reach past the phrase, when `_prepareCycle` clears the judge. The player's flick is silently lost. Check when rung 1 is built.

### Suggested order

1. Fix the credit bug and add the "ignoring costs nothing" test, even before dares exist.
2. Phrase report, Heat model and tests, with no visible effect.
3. Pace director, and show Heat through things that already exist: crowd waves and Mācron's clap. Owner reviews in autoplay.
4. Turn overflow and rung 1 on garden and bar, with existing spins. Phone test.
5. Party-up on what's already separate: lamp glows, plant sprites, waiter. Cheap, and shows whether the slow reveal works before spending on art.
6. First library props (candle, plant, lantern), with one GPU probe of a layered room.
7. Party sounds, alongside the music work.
8. Only if rung 1 works in play: rung 2, then consider optional taps.

## Decisions for the owner

1. **Should the party's mood show as a meter, or only in the room?** I recommend only in the room, plus stamps at the end. Evidence on hiding is mixed, but a meter invites players to watch it instead of the dance, and PaRappa's lesson is met if the room responds clearly. Fallback: a small indicator, if testers can't tell why things change.
2. **Flicks only, or optional taps as well?** Flicks only needs little new code and works at every tempo. Optional taps (rungs 3 and 4) add real depth for skilled players, but need a change to the judge, and vanish at fast tempos. I recommend flicks only for the first release, with taps decided after a phone test.
3. **Regenerate the garden and bar into layers now, or prove it on a new room first?** This drives the art cost. I recommend starting with what's already separate, plus a first library set, then proving layers on the pool lawn, which is still a draft and lacks the umbrellas and tables anyway. Garden and bar come after that, since they're accepted art.

Smaller decisions:

- **Room limits on party-up.** Should the garden stop at step 3, so that VIP stays special, as I propose? You might want every room to reach full swing.
- **What may a hot run change at the end of a level?** I recommend the same earned moment for everyone, plus a small extra for hot runs and stamps. The stronger alternative, a visibly different ending as in PaRappa, is more exciting and costs more art per level.
- **May answered dares pay more Pizazz?** That changes an existing rule; see "Rules that have to change".

Also needed: the teacher's interview for the signature step and for which flourishes feel earned, and a swing reviewer for the duo's swaps.

## What's weakly evidenced

- **All outside sources:** excerpts only, as stated at the top. Priority reads: Hunicke, Ang and Mitchell, Chen, Booth's slides, and the 1996 Matsuura interview.
- **PaRappa's mechanics, Rhythm Heaven's rules, Patapon's numbers and Thumper's grading** rest mainly on fan wikis and forums, and some conflict.
- **Audience as a feedback system:** Rock Band and Space Channel 5 show it exists. I found **no** measurement that it improves engagement, and **nothing** on Dance Central's audience, which the brief assumed.
- **Music reacting to skill:** widespread, loved in reviews, rarely evaluated.
- **Whether hiding or showing adaptive systems is better:** mixed, and much of it comes from other genres.
- **Mario Odyssey's Assist Mode, Galaxy's comet challenges and Super Mario Maker:** my searches found nothing usable, so they aren't used.
- **Booth's paper wasn't read.** The four states and the frequency-versus-difficulty point are second-hand, through ranitas and summaries. Read pages 79-82 and 92 first.
- **GameFlow** is a checklist, reported as unvalidated as a measure, and I found nothing in it about tension and relax states.
- **Tension and relief in rhythm games:** I found no study. The cycle here is reasoning from a zombie game, plus how music works. It's the proposal's centre, and its evidence is thin.
- **Change blindness** was shown in lab settings on still scenes, sometimes. Nothing covers a busy game at our speeds. We run several times faster than ranitas, which itself ran no user test.
- **Generated props in a generated room:** whether they'll match in light and palette is untested.
- **Every number in Part 3** is a starting value: Heat thresholds, frequencies, the 285 ms gap, budgets, wake steps, reveal lengths. Player types in the simulation are invented.
- **Nothing here shows that dares are fun.** That needs a moving test on a phone.

## Sources by topic

Links appear inline above. Other pages seen in excerpt and useful for follow-up:

- Flow and adjustment: [Wiley DDA review](https://onlinelibrary.wiley.com/doi/10.1155/2018/5681652), [PMC: being enjoyably challenged](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5954478/) (title only), [Wikipedia](https://en.wikipedia.org/wiki/Dynamic_game_difficulty_balancing)
- Cool mode: [PaRappa 2 on Wikipedia](https://en.wikipedia.org/wiki/PaRappa_the_Rapper_2), [TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/PaRappaTheRapper)
- Rhythm Heaven: [Iwata Asks, Fever](https://iwataasks.nintendo.com/interviews/wii/rhythmheavenfever/0/1/), [Wikipedia](https://en.wikipedia.org/wiki/Rhythm_Heaven)
- Teaching and optional content: [MCV on Nintendo's four steps](https://mcvuk.com/business-news/publishing/video-nintendos-level-design-secrets-in-four-steps/), [Tutorial (video games)](https://en.wikipedia.org/wiki/Tutorial_(video_games))
- Dance Central: [Behind the scenes](https://www.gamedeveloper.com/production/exclusive-behind-the-scenes-of-i-dance-central-i-)
- In this repository: `plan/owner-rulings-2026-11-05.md`, `plan/party-overhaul.md`, `plan/party-overhaul-research.md`, `plan/animation-research-register.md`, `plan/party-perspective-and-life.md`, `plan/research/local-music-models-2026-11-06.md`, `plan/research/runtime-music-assembly-2026-11-06.md`, `openspec/project.md`, `plan/storyboard.md`, `plan/duet-foundations.md`, `plan/foundations-2026-11-05.md`, `plan/campaign-sheet.md`, `plan/input-crowd-research.md`, `plan/research/level3-design-research-2026-11-05.md`, `plan/research/swing-duet-research-2026-11-05.md`, `plan/research/salsa-bachata-interview-2026-11-05.md`

ranitas's documents were read as a sibling project's data, from a read-only copy, and nothing from it was run. Other games are used for genre lessons only. No content from them is proposed here.
