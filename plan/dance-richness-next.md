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
