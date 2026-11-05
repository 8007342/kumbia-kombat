# Next: richer dances for the challengers

The owner accepted Gatekeeper v3 and Bartender v3 on 2026-11-05 and asked for
these next.

## Owner's notes

- **Bartender's shaker:** "there's a shaker in some frames, we might need to
  remove that". It is drawn in the groove and challenge clips only. Either draw
  it out or use it on purpose in every clip.
- **Richer dances:** "only an animation or two used in the dance, we'll want much
  more richer dance moves to match the music, the party enthusiasm".
- **Adornments:** "similar adournments like the optional extra spin we have for
  our adorable Mācron".
- **Gatekeeper's build:** he came out too skinny against the chubby original.
  Refine him later, this time with real prompts.

## Why the dance looks thin

The art already has more than the game shows. Each new atlas holds 84 frame ids
drawn from 64 poses, but `challengerFrameIds` in
`lib/gameplay/ensemble_sprites.dart` lists the small set that
`lib/gameplay/challenger_choreography.dart` uses. It plays a limb accent per call
note and yields the floor on the player's turn. Check first which drawn clips
(`groove`, `clap`, `challenge`, `approval`, `reassurance`, `finish_turn`) reach
the screen; wiring those to the music costs no GPU time.

## Suggested order

1. Measure which frames a full run shows, and wire the unused clips to the music:
   groove between calls and clap or challenge on phrase accents, chosen from the
   score's sections and the party's energy.
2. Give challengers optional flourishes on the player's model, starting from how
   the hero's `spin_front` and `flourishGesture` work. New drawings only where
   the existing clips can't do it.
3. Decide the shaker, then redraw affected poses with one baked prompt per pose.
4. Keep the challenger readable on the player's turn: in the bar she steps aside
   and ends up mostly behind the right-hand guest, and the "WATCH THE CALL" label
   sits across her waist. Check both during step 1.

## Grammar first pass (work/1837-chor)

`lib/gameplay/dance_grammar.dart` dresses the sampler's pose using
`assets/art/ensemble/choreography.json`. It only picks a drawing, so marks,
timing and each call's accent stay the sampler's. Names and tables are
provisional until the teacher's interview.

Clean run on a fake clock, up to and through the exit (64 drawings per dancer):

| Measure | Garden before | Garden after | Bar before | Bar after |
|---|---|---|---|---|
| Distinct drawings to clear | 18 | 43 | 18 | 35 |
| Distinct, with exit | 19 | 44 | 18 | 36 |
| `watch_*` time to clear | 40.6% | 3.0% | 41.5% | 8.8% |
| Limb peak time to clear | 8.7% | 8.7% | 8.8% | 8.8% |
| Shaker flips, with exit | n/a | n/a | 24 | 0 |

- **Shaker.** All 12 of her `groove_*` and `challenge_*` drawings hold it and no
  others do. `groove_up_r` also holds it in the other hand. Today it already
  flips 24 times a bar run through the `ready`, `invite` and `occupied` aliases.
  The shared groove would flip it 70 times (35 appearances in 104 s). Her data
  entry avoids all of those drawings, so she shows it never. To try the shared
  groove, delete her `clips` and `frames` in the data file; her shaker test will
  then fail on purpose.
- **Sideline.** Most groove plays at the response mark, where a guest covers much
  of the Bartender and part of the Gatekeeper. This needs the room marks fixed.
- **Not wired.** `enter_forward_*` and `retreat_backward_*` wait for staging. The
  walk back from the sideline stays a slide because no step is drawn that way.
