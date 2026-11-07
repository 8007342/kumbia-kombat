# Level bible: pool garden

**Draft, 2026-11-05. Not approved.** Items marked "teacher" wait for the dance teacher's interview. The evidence is in `plan/research/level3-design-research-2026-11-05.md`, `level3-art-pipeline-2026-11-05.md` and `level3-engine-audit-2026-11-05.md`.

**In the campaign as a draft, 2026-11-06.** The level plays third, after the bar, with the draft plate and the candidate atlases `swing-a` and `swing-b`. The owner asked for a draft level 3 but has not accepted its art, music or cast. What the draft does not do yet:

- The pair dance the call hand in hand, as one figure, and one partners Mācron on his turn: `plan/duet-foundations.md`, "As built: the pair". Swing-outs still wait.
- They glide along their 16-beat floor tracks, with no travelling steps in the art.
- Both skeletons are borrowed from the bartender and Gatekeeper, because the rig would not run in the forge.
- All atlases still load at startup, so the dancers cost memory in the first two rooms.

| Field | Draft |
|---|---|
| Id, slot | `pool-garden`, proposed after `bar` and before `cool-crowd` |
| Premise | Mācron steps out of the bar onto the back lawn. Mid-path, two grown women who own this stretch of floor stop him, and he earns his way through |
| Feeling | Awe at the size of the party, playful rivalry, then welcome |
| Respect word | Grace for the draft. Sabor if the teacher likes it |
| Teaches | Reading rhythm shapes: syncopation and rests you can recognise |
| New idea, only one | Two dancers, one partnership: they dance a phrase together and Mācron answers. Same four tap zones, no chords, no new scoring. Details: `plan/duet-foundations.md` |
| Music | Fast swing, by owner's ruling. `pool_swing`, E-flat major, draft ladder 128, 136, 144, 152, 160 BPM. Nobody has listened to it. See below |
| Dance vocabulary | Swing, from `plan/research/swing-duet-research-2026-11-05.md`, with real step names and a reviewer still to find. Signature step stays with the salsa teacher |
| Space | Diagonal path to the top right, covered pool at top left, cocktail tables on the lawn at top and left. Night by default, matching the garden and bar. Everything that tells the story stays in the central 69% of the plate's width, which is what a 390×844 phone shows |
| Screen | Tap zones stay fixed in the thumb band. The top shows the dance. Cues and the scene don't depend on each other |
| Cast | Two adult women with contrasting silhouettes; table guests standing and chatting; a few swimmers. Proposal: friends or sisters, middle-aged or older |
| In | Terrace door from the bar, reveal of the lawn, walk up the diagonal, two palms raised in a smiling stop |
| Out | They part, nod and try a piece of the signature step (teacher), then a walk to the top-right door |
| Reset | They step together and kindly walk him back, 2 beats |
| Tone | Classy and warm. Whole-figure or waist-up framing, no shots from robot height toward them, no leering. They laugh with each other and aren't on show for him. Swimmers stay small and distant, chest up. Modest, covered wardrobe; state clothing and age in every prompt |
| Done when | A fresh player can say whose turn it is by phrase 3 without any text, and clears it with taps only; the score is identical with visuals on or off; the two dancers read apart at native size; teacher and owner approve; a full reduced-motion run works |

## Transitions into this level

Beats are provisional. No extra bars are added: success plus bridge is 16 beats. Music never stops.

Storyboards for the fist bump and the oil gulp moved to `plan/cinematics.md`, as extreme close-ups by the owner's ruling.

**Walk to the lawn.** Along the counter end, through a terrace door, reveal, up the diagonal. Two figures step in and close the path, and the first call follows.

## Tempo and chart, draft

**Ladder: 128, 136, 144, 152, 160 BPM.** The research's 150 to 200 would make the slowest tier faster than anything in the campaign, and the top nearly double the bar's 112. Here the first tier is 14% above the bar's top and the last is 43%. These tempos are in the forum range the research gives for beginners to intermediate Lindy dancers, up to where it says "very fast" starts. It hasn't been played on a phone. Each step is 8 BPM, more than double the other rooms' 3.

**Chart: `[0, 1, 1.75, 3, 4, 5, 5.75, 6.75]`.** This is the Charleston rhythm with two beats added. The `.75` notes are swung eighths, within about 6 ms of the music at every tier. The rules:

- No same limb within 400 ms at any tier. The tightest in the file is 656 ms.
- A swung offbeat never has a note a quarter beat after it: every gap is at least three quarters of a beat, 281 ms at the top tier. The bar's tightest is 268 ms.
- Two taps under a beat apart use different thumbs.
- Eight notes per call, because the peak's rule in `progression.dart` is a hard-coded 87.5%, which only forgives a miss at eight notes or more. Early tiers use a 75% ratio, as the garden does, since the speed is the new difficulty.
- The last note is at 6.75, the swung form of the research's 6.5 limit. At the top tempo a late tap followed by a slow flourish can run past the end of the cycle and lose its flourish points, and nothing else.

**What the chart can't do yet.** Density was meant to peak at the middle tier, with the fastest sparser. A level has one offset list and variants must keep the note count, so every tier taps the same rhythm, and taps per second rise with tempo. For now only limb load peaks there:

| Tier | BPM | Limbs (pairs of consecutive limbs) | Taps/s now | Proposed offsets, once the chart format allows them | Taps/s then |
|---|---|---|---|---|---|
| 0 | 128 | Hands (2) | 2.13 | 0, 1.75, 3, 4, 5.75 | 1.33 |
| 1 | 136 | Hands, then feet (5) | 2.27 | 0, 1, 1.75, 3, 4, 5.75 | 1.70 |
| 2 | 144 | All four, shifting (7) | 2.40 | The shipped list | 2.40 |
| 3 | 152 | All four, repeating (4) | 2.53 | 0, 1, 1.75, 3, 4, 5.75, 6.75 | 2.22 |
| 4 | 160 | Feet, then hands (2) | 2.67 | 0, 1.75, 3, 4, 5.75, 6.75 | 2.00 |

Per-tier offsets need three things in `lib/`: the format, `limbsFor`, and the peak rule, because at six notes 87.5% means no misses at the fastest tier. The research's table puts its densest rhythm at tier 3, and this draft follows the brief's middle tier.

**Tier changes.** The tempo moves on a phrase boundary, which with a 4-beat intro falls 4 beats into the next call, as in every level. Steps are bigger here, so the second half of that call speeds up by 5 to 6%. Listen for it.

**Handoff from the bar.** The bar already has `bar_swag_success`. Adding this level to `levels/index.json` needs `"bridgeToNext": "bar_to_pool"` and new exit and next lines on the bar's entry, which still point at the crowd. Exit runs at 112 BPM and `bar_to_pool` takes 128 at its downbeat, inside the drum break.
