# Owner rulings, 2026-11-05

These settle the Level 3 discussion's first round. Where an older plan disagrees, this file wins until the
plan is updated.

| Topic | Ruling | Owner's words |
|---|---|---|
| Campaign size | Add levels, never replace them. Cool Crowd stays, and the pool garden is a new level | "We'll want many more levels, don't replace, just add levels" |
| Pipeline goal | Adding a level and its assets should take a few prompts and compute time | "adding and generating levels and assets should become a few prompts and throwing some compute power at it" |
| Level 1 to 2 transition | The Gatekeeper fist-bumps Mācron as he walks in. The full high five stays for the finale | "let's have the gardener just fist bump Mācron" |
| Name | Gatekeeper, for the first level's character | "Gatekeeper is a better term" |
| Screen layout | Tap zones stay fixed and thumb-reachable at the bottom. The top shows the dance | "the visuals should be independent of the controller scheme" |
| Mācron's signature step | It comes from the salsa teacher's interview. Don't invent one | "Mācron signature step shall come from our salsa master" |
| Missing foundations | Keep looking for gaps like the absent choreography grammar | "what we want to detect is those things missing" |
| Compute | Local throw-away GPU batches are approved for research; this host is dedicated to it | "you are approved to run local gpu throw-away batches of work as needed" |
| Publishing | Push work branches often | "push work branches often" |

Earlier the same day: the oil gulp stays at the bar's exit, and Level 3's scene is an angled path to the top
right, with a classy covered pool at top left and swimmers watching, guests at cocktail tables on the lawn,
and two women dancing in the middle who stop Mācron. Its position in the campaign is not settled yet.

Still open: the pool garden's place among the levels, the level's mood, and whether the two dancers alternate
calls, pending research and the teacher's interview.

## Second round, the same day

| Topic | Ruling | Owner's words |
|---|---|---|
| The two dancers | Fast swing dancers who dance with each other, in combinations, switching places, tempo, complexity and adornments. A deliberate test of the pipelines | "fast swing dancers, so they can dance with each other in combinations" |
| Perspective | They move toward and away from the viewer, and size must follow the background | "their sizes follow and match the background's perspective" |
| Fist bump staging | Extreme close-up, so the Gatekeeper's kneeling is never shown | "we can just use an extreme closeup" |
| Cinematic reference | Learn from Cannonball's work, for the intro and for transitions such as the fist bump and the oil | "we could learn a lot for our intro and level transitions" |

This replaces the desk recommendation of cha-cha-chá for this level's music. Mācron's signature step still comes from the
salsa teacher. Swing isn't that teacher's stated field, so swing vocabulary needs its own reviewer.

## Third round, 2026-11-06, after watching the autoplay build

| Topic | Ruling | Owner's words |
|---|---|---|
| Fist bump | Loved. Later: better timing and a lightning face-off with a winking eye, so it clearly reads as approval | "that fistbump was epic", "we'll add sugar later" |
| Bar to lawn | The cutscene between the bartender and the pool is missing | "We're also missing the cutscene between the bartender and the pool" |
| Lawn draft | The background and dancers are a strong first run | "fantastic for a first run" |
| Gatekeeper | v4's build and moves are right. Read as acceptance, so v4 and its stocky front sheet are promoted | "The gatekeeper is chubby again ;) and its moves are much better" |
| Unused moves | Use the drawn moves the game still leaves out | "there might be a few more animations not being used" |
| Handoff | The opponent stays on the main dance area during Mācron's turn, and doesn't hide back in the party | "remain somewhat on the main dance area, even for Mācron's turn" |
| Mācron off turn | He takes a few steps back and claps or taps along, depending on the music and the party's excitement | "take a few steps back, and clap along, and/or tap along" |
| Opponent flares | The Gatekeeper and bartender get spins and optional flares, as Mācron has | "might need to also do some spins and optional flares" |

Status, 2026-11-06: the handoff, Mācron's clap, opponent spins and the oil gulp are in the game as candidates on `work/1839-intg`, not yet merged. The fist bump's lightning face-off and wink aren't started.

## Fourth round, 2026-11-06, after playing the merged build's candidate

| Topic | Ruling | Owner's words |
|---|---|---|
| Oil gulp | Timing is great. The art needs direction: arm and head need a body, and the gulp should take a few sub-second transitions | "the arm and head might need a body", "a few sub-second transitions" |
| Exit walk | Remove the walk-through after the cinematics: Mācron walks through the Gatekeeper | "that walking through is no longer needed if we use the cinematic transitions" |
| Transition music | Cinematics can play while the previous level's music is still cooling down | "while the music is still cooling down from the previous level" |
| Spin timing | Spins must not end the opponent's turn at their resting place. Let the animation finish even if it overflows the turn, then step away, so the full spin happens mid-floor. They can also come a little more often | "let the animation of the opponent end even if it overflows their turn, and step away afterwards" |
| Skill reward | Optional adornments appear more often and become more rewarding for players doing well, with music, audience and dance moves; opponents gain adornments as challenges for skilled players | "more popular if the player is doing well" |
| Music direction | Research local audio models that output composable looping segments, crossfaded at runtime from compressed files | "composable segments that loop, that you could then crossfade at runtime" |
| Music freedom | The current scores no longer limit the music. Audio models may reimagine each level's music from its concept | "give the new models free reign to reimplement the concept of the music in the levels" |
| Audio in git | Never commit WAV to the remote, only MP3 and other compressed formats | "be mindful not to commit WAV files to remote" |

## Fifth round, 2026-11-06: everything parties up

Backgrounds, the party and other cosmetic assets SHALL be affected by the music score. This is intended by design, and the older specs that said otherwise are obsolete.

As the game progresses, the music gains complexity and the party stands up and dances, the plants, umbrellas, waiters, fire flames and other background items also dance to the beat: "everything should slowly party up".

The method comes from sibling project ranitas: movement introduced without players noticing. See its `docs/quiet-awakening.md` and `docs/research.md` (slow change blindness, Simons, Franconeri & Reimer 2000; Frey et al. 2024). Its own limits carry over: slow changes can escape attention, but nothing guarantees every player misses them, and its timings are artistic choices, not study results. New layers fade in at their final anchors, movement amplitude grows separately, entrances use quintic smootherstep, and motion is never switched on at full speed. Reduced motion still applies.
