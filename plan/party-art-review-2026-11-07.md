# Party art review and dancing pairs, 2026-11-07

Branch `work/1868-gues`. Owner's words: "The dancing crowd started looking away all of them, they would likely be dancing in pairs, so we might need a few more different party people." and "The original party assets are mostly fine but they do have a few oddities, loke pointing in the wrong direction, or oddly crossed legs please take a pass at them as well for some review."

Facts are marked [F], my choices [P]; a [P] is a proposal the owner can reverse. Nobody has seen any of this moving on a phone.

## How the review was done

- Every frame of `guest0`-`guest2`, `life` and `hero` was laid out per clip, and 113 frames went one at a time, cropped, to the local vision model (458 s). Then I looked at all the sheets myself, and zoomed on everything suspect. [F]
- **How the local model did** [F]. It found both pointing arms still in the step cycle when pointing was the question. But it also said "pointing" for 62 of 113 frames, including a candle, and it called the man's crossed legs "crossed" on some frames and not others of the same pose. It missed every fault below except pointing: the wrong-way arm, chair stubs, stray neighbour pieces and doubled shoe all got "none". It didn't notice the woman's neckline. Good for a question with a countable answer, no use as a fault finder. This agrees with `plan/compute-ledger-2026-11-07.md`.

## What I found

| Where | Frames | Oddity | What was done |
|---|---|---|---|
| guest1 (man) | `step_touch_c` | **Points.** The earlier fix excluded `step_touch_b`, which only points on guest0. This one is in the a, d, c, d step cycle | Status below |
| guest2 (host) | `step_touch_d` | **Points.** Worse: it is shown twice per cycle, and `ownThing` on the indoor party uses it | Status below |
| guest0 (woman) | `step_touch_b` | Points. Unused since the earlier fix | Status below |
| guest2 | `notice_b` | **Wrong way.** Points picture-left while every guest is drawn to face picture right, so he points away from the fight. He also looks the other way from his arm | Status below |
| guest1 | `seated_idle_a,b`, `notice_a,b`, `sit_down_d` | **Oddly crossed legs:** a thigh runs straight into a foot with no knee, floating beside the other leg | Status below |
| guest1 | `notice_a`, `notice_b` | Rects overlap: a piece of the neighbour's elbow and shoe shows at the edge | Status below |
| guest0 | `stand_up_a,b` | Grips brown blocks, left over from erased chair arms | Status below |
| guest0 | `seated_follow_a,b` | Lifted foot has a doubled shoe. `_a` keeps a brown cuff on the wrist | Status below |
| guest0 | all | Off-shoulder neckline with cleavage, against the style guide's "closed or modest necklines" | Status below |
| guest1, guest2 | `cheer_b` | Hands meet high with the head sunk between the arms. Reads as an overhead clap. Left | No change [P] |
| guest2 | `sit_down_a,b` | Hat tips forward and the face goes down. Reads as looking at the seat, for one beat. Left | No change [P] |
| hero | `held_*` | Hard cut edges where the puppet joined the raised arm (from `art_runs/duet-20261106/pair`) | Status below |
| hero | `rear_finish`, `held_rear` | A faint stray outline loop behind the lifted foot | Status below |
| hero | `profile`, `held_side` | Knees cross in profile. Fine for one spin drawing | No change [P] |
| life | all | Nothing wrong | No change |
| `party/guests-v1.png` | | Old `crowd` atlas: the manifest requires it, but nothing draws it now | Left |

Pointing direction elsewhere is right: guest0 and guest1 `notice_b` point picture-right, and a guest is flipped to face the middle of the room (`facingRight` is `x < .5`). [F, from `party_layout.dart`]
