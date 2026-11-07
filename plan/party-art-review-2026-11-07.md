# Party art review and dancing pairs, 2026-11-07

Branch `work/1868-gues`. Owner's words: "The dancing crowd started looking away all of them, they would likely be dancing in pairs, so we might need a few more different party people." and "The original party assets are mostly fine but they do have a few oddities, loke pointing in the wrong direction, or oddly crossed legs please take a pass at them as well for some review."

Facts are marked [F], my choices [P]; a [P] is a proposal the owner can reverse. Nobody has seen any of this moving on a phone.

## How the review was done

- Every frame of `guest0`-`guest2`, `life` and `hero` was laid out per clip, and 113 frames went one at a time, cropped, to the local vision model (458 s). Then I looked at all the sheets myself, and zoomed on everything suspect. [F]
- **How the local model did** [F]. It found both pointing arms still in the step cycle when pointing was the question. But it also said "pointing" for 62 of 113 frames, including a candle, and it called the man's crossed legs "crossed" on some frames and not others of the same pose. It missed every fault below except pointing: the wrong-way arm, chair stubs, stray neighbour pieces and doubled shoe all got "none". It didn't notice the woman's neckline. Good for a question with a countable answer, no use as a fault finder. This agrees with `plan/compute-ledger-2026-11-07.md`.

## What I found

| Where | Frames | Oddity | What was done |
|---|---|---|---|
| guest1 (man) | `step_touch_c` | **Points.** The earlier fix excluded `step_touch_b`, which only points on guest0. This one is in the a, d, c, d step cycle | Fixed: a loose fist, hand area only |
| guest2 (host) | `step_touch_d` | **Points.** Worse: it is shown twice per cycle, and `ownThing` on the indoor party uses it | Fixed: a loose fist, hand area only |
| guest0 (woman) | `step_touch_b` | Points. Unused since the earlier fix | Fixed: an open hand. A few stray pixels remain at the fingertips of this unused drawing |
| guest2 | `notice_b` | **Wrong way.** Points picture-left while every guest is drawn to face picture right, so he points away from the fight. He also looks the other way from his arm | Fixed: redrawn from `notice_a`, pointing and looking picture-right. Mirroring alone would have left him looking away from his own arm |
| guest1 | `seated_idle_a,b`, `notice_a,b`, `sit_down_d` | **Oddly crossed legs:** a thigh runs straight into a foot with no knee, floating beside the other leg | Fixed: both feet on the floor |
| guest1 | `notice_a`, `notice_b` | Rects overlap: a piece of the neighbour's elbow and shoe shows at the edge | Fixed: each has its own space now |
| guest0 | `stand_up_a,b` | Grips brown blocks, left over from erased chair arms | Fixed |
| guest0 | `seated_follow_a,b` | Lifted foot has a doubled shoe. `_a` keeps a brown cuff on the wrist | Fixed |
| guest0 | all 24 | Off-shoulder neckline with cleavage, against the style guide's "closed or modest necklines" | Fixed: a closed round neckline in the same pink, on every frame. The owner didn't ask for this one; it's the guide's rule, and easy to reverse [P] |
| guest1, guest2 | `cheer_b` | Hands meet high with the head sunk between the arms. Reads as an overhead clap | Left [P] |
| guest2 | `sit_down_a,b` | Hat tips forward and the face goes down. Reads as looking at the seat, for one beat | Left [P] |
| hero | `held_*` | Hard cut edges where the puppet joined the raised arm (from `art_runs/duet-20261106/pair`) | Left: barely visible at 80 px tall, which I judged by looking at a downscaled sheet, not in the game [P] |
| hero | `rear_finish`, `held_rear` | A faint stray outline loop behind the lifted foot | Left, same reason [P] |
| hero | `profile`, `held_side` | Knees cross in profile. Fine for one spin drawing | Left [P] |
| life | all | Nothing wrong | No change |
| `party/guests-v1.png` | | Old `crowd` atlas: the manifest requires it, but I found nothing that draws it | Left. I didn't look at it closely |

Pointing direction elsewhere is right: guest0 and guest1 `notice_b` point picture-right, and a guest is flipped to face the middle of the room (`facingRight` is `x < .5`). [F, from `party_layout.dart`] That is the direction of the room's middle, not of the fight's exact spot.

**Pointing in the room.** `notice_b` points at the floor's middle, with a guest flipped by which side of the room they're on, and pointing is now only in `notice`, as the rule reserves it. [F for the frames] The garden's cleared-sample golden will change with these drawings.

**How the repairs were made.** `tool/art/pipeline/repair_frames.py` gives Qwen the frame with one change in words. Requests and picks: `art_runs/guest-fix-20261107/`. [F]

- Hand fixes paste only the hand's box back.
- Whole redraws move to their own place in the atlas, at the frame's old height, with the anchor at the feet. Qwen draws a little larger, which would otherwise grow a person between drawings.
- Clip and frame names are unchanged. Atlas sizes changed: guest0 is now 1536 by 777 (down from 1024 tall, repacked), guest1 is 1254 by 1503, and guest2 is 1536 by 1258. The old drawings are still in guest1 and guest2 under their new ones, unused. [F]
- Guest0's blouse pink wandered between frames, so `repack_guest0.py` evens it out with per-channel gains. By eye it no longer flickers on a sheet. Nobody has seen it moving. [F for the gains]
- **Recolor gates:** I recomputed the gates from `plan/asset-inventory-contract.md` on the new art. Share of opaque pixels recoloured on repaired frames: guest0 about .23 to .31 before the neckline, guest1 .32 to .35, guest2 .26 (each atlas's old frames averaged .28, .27 and .21). For guest0's final atlas I simulated the sample areas in `test/outfit_palette_test.dart`: the four protected areas have no recolouring, and the two clothing areas are 85% and 94%, against the test's .35. That is my own arithmetic, not the test: Flutter won't run in this worktree. [F]

Before and after: `art_runs/guest-review-20261107/repairs-before-after.png`, `guest0-neckline-before-after.png`, and `guest0-after.png`, `guest1-after.png`, `guest2-after.png`.

**What went wrong in repairs:** my first compose had no alignment on whole-frame repairs and clipped feet and hair, and my first repack overlapped a frame. I caught both on the sheets and redid them.

## Dancing pairs and more party people

**Route: two sprites sharing beat and facing, not drawn pairs.** `plan/duet-foundations.md` warns that one-image pairs distort people, and two sprites let anyone dance with anyone. [P]

**The people** [P, all accepted by me as the finishing push allows]. Sheets are in `tool/art/references/guest3..6/`.

| Atlas | Who | Wears | Stature |
|---|---|---|---|
| `guest3` | Short, round woman of about seventy, silver curls | Amber-gold long-sleeved dress, mid-calf, cream shoes | .90 |
| `guest4` | Very tall, thin man of about seventy, white hair and moustache | Dusty lavender shirt, amber bow tie, charcoal trousers and suspenders | 1.06 |
| `guest5` | Tall, broad woman of about forty, long black braid | Deep plum wrap dress below the knee, amber earrings and shoes | 1.0 |
| `guest6` | Short, stocky man of about thirty, flat-top | Burnt-amber jacket, dark violet shirt, dark brown trousers | .94 |

None of them wears a cream dinner jacket (the band) or a long violet jacket and gold (BlinBlin). guest5's plum dress reads more wine than violet.

**Frames, the same 23 on all four** (`tool/art/pipeline/pack_floor_guest.py`). 12 drawings each, repeated in the atlas to save GPU:

| Clip | Frames shown | What it is |
|---|---|---|
| `pair_dance_a..d` | a, a, c, c | Three-quarter, hands reaching picture right at chest and waist height |
| `back_dance_a..d` | a, a, c, c | Rear three-quarter, hands hidden in front of the body |
| `sidestep_a..d` | a, b, a, b | Near profile, walking picture right |
| `glance_a,b` | a, a | From behind, looking over the shoulder picture right |
| `groove_a..d` | a, a, c, c | Facing front, arms low, no pointing |
| `clap_a,b` | a, b | Clapping |
| `cheer_a,b` | a, a | Both arms up |
| `standing_idle_a` | measuring only | Its height is one adult, so stature is data. Carries `"measureOnly": true`; PARTY's `party_sprites.dart` change on `work/1869-prty` lets it past the bounds check, so **this branch's manifest needs that commit to load** |

Spacing, measured by compositing: left partner unflipped, right flipped, **anchors .42 of an adult height apart**. Hands meet at `pair_dance_a`; at `_c` they step in, and a reach lands near the partner's shoulder. Proof: `art_runs/guest-review-20261107/couples-guest3-guest4.png`. All frames: `guest3-guest4.png`, `guest5-guest6.png` there. [F for the compositing, not the game]

**Not recoloured.** Outfit recolour covers guest0-2 only, so these four are drawn as they are, with no outfit variants.

**What went wrong on the way:**

- **Hold from behind:** the first `back_dance` used the same forward hold, and Qwen drew arms spread wide, with a third hand at the hip on guest4. I redrew all four with hands hidden in front. This is what the owner's "absorbed in their partner" needs from behind anyway.
- **Wrong-way or broken takes, rejected by eye:** guest5 `pair_dance.a` (arms reaching left, a foot kicked up behind), guest4 `sidestep.b` (a stray second head at the hip), guest5 `groove` (a raised knee, and an open skirt).
- **Which way sheets face:** the three-quarter sheets all came out facing left against the prompt, and I mirrored them. So earrings and the braid swap sides between front and three-quarter views. Rear sheets faced right as asked.
- **Atlas load:** my first push broke the sprite bounds check with `standing_idle_a`; PARTY fixed it with `measureOnly`.
- **GPU:** the queue ran about 10 to 15 minutes a job, so I cut the plan from 22 drawings a person to 12. That's why each dance has two drawings rather than four. More in-betweens would help if they look stiff when moving.

## Not done, and what needs eyes

- **Nothing has been seen moving** or on a phone. PARTY looked at couples in a few stills of the real scene at phone size. Worth a moving look: whether `sidestep`'s wide stride reads as stepping aside, whether two-drawing dances look stiff, and whether couples look absorbed in each other.
- `glance` looks picture right only if the guest is unflipped, like the rest, so its direction relies on the flip the level chooses.
- guest0-2 have no pair or rear clips. PARTY keeps them as solos with `step_touch`.
- `flutter test` can't run in this worktree. Goldens that draw guest0-2 change with these fixes, and PARTY regenerates them on merge.
