# Dress code: everyone at the party dressed for the room, 2026-11-08

Owner, verbatim: "please make sure that the majority of the party people are dressed up nicely, the Pool room has some people in hoodies and baseball caps, please note they're at an elegant party at a huge mansion, so everyone should be dressed up, not necessarily expensive or night dresses, but everyone should be classying it up for the room they're in."

Agent DRESS, branch `work/1890-drss`. Every choice below is the agent's own, a proposal the owner can reverse.

## The audit (fact)

Every crowd and guest atlas that `levels/*.json` uses was looked at by eye, whole sheet and enlarged. Local vision was not used: it fails on whole sheets, and this check was a single pass over 30-odd sheets.

| Level | Atlases | Verdict |
|---|---|---|
| garden, pool-garden, bar | guest0, guest1, guest2 (plus outfit recolours) | Dressed. A puff-sleeved blouse with wide embroidered trousers, a waistcoat over a white shirt, a linen jacket over a print shirt with a panama hat. |
| cool-crowd, salon, galeria, terraza | guest0 to guest6, the band | Dressed. guest3: a long dress. guest4: a lilac shirt, bow tie, braces and dark trousers. guest5: a wrap dress. guest6: a sport coat. The band wear white or black dinner jackets. |
| comedor | diner-a to diner-h, waiter-a, guest4 to guest6 | Dressed. Dinner jackets, gowns, a waistcoat and bow tie on the waiter. |
| **billiards** | **pool-bg-a, pool-bg-b, pool-bg-c** (the four background players in `scenery.band`) | **Too casual.** a: a flat tweed cap (reads as a baseball cap at phone size), shirtsleeves and braces. b: a buttoned cardigan (reads as a hoodie), jeans and white sneakers. c: a red plaid flannel shirt, jeans and work boots. |

"The Pool room" fits the billiards room: those three are the only casual people in the game. The pool-garden's guests are guest0 to guest2, who are dressed, and its plate has no painted people. The billiards plate has none either.

Out of scope and not changed: opponents (the PoolPlayer is in a green waistcoat, which is fine anyway), Mācron, plates and music.

## What changed (fact), with before and after

| Figure | Before | After |
|---|---|---|
| pool-bg-a, tall older man | Flat brown tweed cap, pale blue shirt with rolled sleeves, brown braces, baggy grey trousers, scuffed shoes | No hat, neat silver hair combed back. Pale blue dress shirt, buttoned brown tweed waistcoat, burgundy tie, pressed charcoal trousers, black oxfords |
| pool-bg-b, round woman with a halo of curls | Mustard cardigan, navy jeans, white sneakers | Mustard-gold satin blouse with a slim gold belt, tailored navy wide-leg trousers, navy low heels, small gold earrings |
| pool-bg-c, broad bald bearded man | Red plaid flannel shirt, jeans, tan work boots | Deep red dinner jacket, white shirt, black bow tie, charcoal trousers, brown brogues |

Each figure keeps their body, face, hair or beard, glasses, cue and pose, and their colour role in the room: a's pale blue and grey, b's mustard over navy, c's red. Same frame ids, frame count, floor anchors, `pixelsPerUnit` and clips. No level JSON or game code changed.

**Atlas layout.** The rects are repacked, because nearly every new drawing is a pixel or two past its old box. Each new rect is the union of the old box and the new drawing, so anchors move with it. The manifest gains `playerHeightPx` (239, 249, 225: the old idle heights) for the three, so taking a's cap off doesn't make him grow. This is the smallest manifest change that keeps the scale exact.

## How (fact)

`tool/art/pipeline/redress.py`, one spec per atlas in `tool/art/redress/`:

1. Each shipped drawing goes onto a flat green backdrop in the 256 by 320 native canvas, with its floor anchor fixed, and is enlarged x3.
2. A Qwen-Image-Edit 2511 (Lightning, 4 steps) edit of the idle drawing from words alone gives the key. Picks: a 990810, b 990831, c 990852.
3. Every other drawing gets the same words, two seeds each, and is picked by eye against the key.
4. Each pick is shifted back to the old outline, keyed off the backdrop, snapped to the redressed palette (`tool/art/palettes/pool-bg-*.json`, rebuilt from the edited `tool/art/characters/pool-bg-*.json`) and packed. `chalk_b` is derived from `chalk_a` as before (one row out at the waist).

What went wrong along the way:
- **Two-picture route failed.** "Dress picture 1 like picture 2" made Qwen paste the key's figure in beside the old one (pilot, a's lean_b). It was dropped for words alone.
- **Room words painted rooms.** "At a party in a mansion's billiard room" gave a whole painted room on 3 of 6 key seeds. The prompts now say only "an elegant evening party".
- **Dropped cues.** Both seeds of a's clap_a and clap_b dropped the cue leaning on his shoulder. The old drawing's cue pixels go back wherever the new drawing is empty, minus the old cap's colours, which would otherwise come back behind his head (`restoreProps` in the spec). Both seeds of b's watch_a also dropped her cue. Laying the old cue on top dragged the old cardigan hem with it, so that drawing was redrawn with words that name the cue (3 seeds, 990871 picked).
- **b's idle key added a cue** that her idle drawing doesn't hold. Her idle was redrawn like the other frames, and the key served only as the bar to pick by.
- **Old family files are stale.** `tool/art/families/pool-bg-*-v1.json` still describe the old clothes, because this sparse worktree lacks the rig inputs that `compile_family.py` needs. The palettes were written straight from the definitions. Recompile them in a full checkout if those families are ever used again.

Checked by eye: every candidate sheet, every packed atlas on a green ground, and old against new at about phone size (80 px tall). No automated scorer was run: the poses are the shipped ones.

## Left as is, and why

- guest4's braces and bow tie, no jacket: dapper, not casual, and he dances in a ballroom where a jacketless gentleman reads as warmed up.
- guest0 to guest2's festive blouse, waistcoat and linen: right for the lawn and the pool garden.
- Opponents, out of scope: the PoolPlayer is already in a waistcoat.

## Needs the owner's eye on a phone

- The billiards room at full party. At phone size, does b's satin blouse read as dressy, or still as a sweater? If it's still a sweater, the next step is a mustard jacket over a blouse.
- a without his cap: about 4 px less head height at the same standing scale, which should be invisible.

## Compute

Qwen-Image-Edit on the local GPU: 32 jobs and 65 images, 1452 s of GPU run time (queue wait not counted). The two-picture pilot is included. Local CPU for finishing and packing: a few minutes. Both are in `plan/compute-ledger.jsonl`.
