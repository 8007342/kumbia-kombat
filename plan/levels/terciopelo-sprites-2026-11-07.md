# Don Terciopelo sprites, 2026-11-07

Branch `work/1875-terc`. The coordinator delegated acceptance for the salon (`plan/levels/salon-2026-11-07.md`). So every art and design choice below was made by this agent, and each one is a **proposal the owner can reverse**.

## What exists

STATUS_ATLAS

- **Definition:** `tool/art/characters/terciopelo.json`, with pronouns he/him.
  - He uses a new body preset, `tall-slim-adult` in `tool/art/rig/bodies.json`: longer legs and neck, narrower shoulders and hips, and a smaller head for his height than `slim-adult`.
  - The rose in his hand is in the pose words. It isn't a rig prop, because the rig's prop shapes are shaker, bottle and glass.
- **Motion set `opponent-chacha`:** `tool/art/rig/poses.py` and `tool/art/motion/opponent-chacha.json`, 86 drawings.
  - **The 64 shared names,** so every shared choreography table plays him. The groove is redrawn as the cha-cha-chá basic, per side:
    - rock step forward (count 2);
    - replace back (3);
    - chassé to the side (4 and);
    - the landing held on 1, with the hip settled over a straight leg and the arms in long lines.
  - **His finish:** the remate smooths back his silver hair, because he has no hat.
  - **New clips:**
    - `spin` (8 views in a ballroom frame) and `flare.line` (a held line);
    - charisma: `moustache.a/b`, `glance.a/b` (mirror glance) and `offer_hand.a/b`;
    - the win: `bow.a/b/hold`, turned three quarters to the picture's right, and `sweep.a/b`, an arm sweep to the picture's right;
    - `rose.pluck` and `rose.offer`.
  - **New aliases:** `mirror_look` (= `glance.b`) and `flare_open` (= `flare.line`).
- **Pose check:** `tool/art/rig/check_poses.py` gets three exemptions, each named:
  - a hand at the moustache, hair or lapel, or the head coming down in a deep bow (`FACE_TOUCH_CLIPS`);
  - the profile spin views (`SPIN_SIDE`);
  - the three-quarter bow, where the hand behind the back crosses the near arm in 2D (`TURNED_BEHIND`).
- **Choreography:** `dancers.terciopelo` in `assets/art/ensemble/choreography.json`.
  - Clips: `spin_flare`, `flare`, `line_hold`, `giro`, `moustache`, `mirror_glance`, `hand_offer`, `bow`, `sweep` and `rose_offer`.
  - Charisma accents, one per clip:
    - `moustache` every 16 beats at beat 4, from tier 1;
    - `mirror_glance` every 16 at beat 12, from tier 2;
    - `hand_offer` every 32 at beat 28, from tier 3.
  - Hand-off moves: `spin_flare` from tier 1, and `flare` in a cold room.
- **Hardest combo, `EL GIRO DE TERCIOPELO`:** a spin into a held line with a double-time cha-cha-chá. I designed it and sent it to LEVEL for `levels/salon.json`:
  - `giro` over beats 0 to 3, then `groove_double` over 3 to 7, then `line_hold` on beat 7;
  - 15 notes, closing with a circle on the left hand.
  - LEVEL moved my quarter-beat triples onto half beats, because `hardest_combo_test` holds notes at least the good window apart at 124 BPM.
- **Rose handoff close-up:** `assets/art/closeups/salon-*`, described in `salon-art.json` in the shape of `nod-art.json`. He is on the picture's left and Mācron on the right.
  - `salon-dt-{rest,pluck,offer,empty}.png`: four Qwen edits of one bust crop of his accepted front sheet (`art_runs/salon-closeups-20261107/scripts/bust_jobs.py` holds the words). `salon_bust.py` scales and places each one by the bow tie, so his head and shoulders hold still between cuts, then snaps it to his palette on a 2-pixel grid.
  - `salon-mc-{reach,take,tuck,rest}.png`: Mācron drawn from parts by the close-up rig, like `nod-mc-*` (`salon_macron.py`). Only his picture-left arm, his eyes and the rose change between drawings. The rose sits behind his antenna, so the antenna's stem crosses it.
  - `salon-rose.png`: the wide shot's rose, 8 by 9 native pixels, drawn as pixels with its anchor in `salon-art.json`. It's an overlay placed by data, not a walk set. LEVEL pins it to his antenna after the close-up.

## Choices, each reversible

- **Sheets:** front and back are both pass 2, seed 991000 (`art_runs/terciopelo-sheet-20261107b/`).
  - Pass 1 drew four fronts from words, with the BlinBlin sheet as the style only. I kept its fourth: the narrowest, tallest silhouette, swept-back silver hair and a clear rose. The first had a curled dark moustache and a younger, sterner face. The second had a ponytail and the third a goatee.
  - Pass 2 redrew from that one, front and back. Its first front holds the rose, the bow tie and the moustache clearly at 256 by 320, and its build is the slimmest of the four.
  - Its first back is a plain jacket back of the same length, with both hands showing. The second had a seam across the back, and the fourth a shorter jacket.
- **The moustache is grey, not black.** I asked for a dark pencil moustache twice and Qwen drew grey both times. Grey reads at native size and suits his age, so I kept it.
- **Colours** are the accepted front's medians, with the jacket held just off pure white (`#F0EDE6`), as the style guide asks. The rose's green leaf was added to his palette for the close-up.
- **`front-bare.png`** is the accepted front with the rose painted out by code, as a flat jacket-white box. `rose.offer` draws from it, because in the pilot it drew a second rose in the lapel.

## How it was made and checked

STATUS_CHECK

## What went wrong

- **The first front sheet's second attempt was refused.** `run_jobs.py` always sends the two-image graph, and a sheet job drawn from a reference has one image. I bound the same crop to both images, the way the nod close-up did.
- **`collect_qwen.py` files a one-image sheet job by its input's name,** so pass 2's outputs had to be found by their provenance. Every other agent's outputs share that studio folder.
- **Pilot misses:**
  - "a held ballroom fan line" drew a hand fan, and once a hand mirror;
  - the hand offer stood the palm up like a wave;
  - the bow's swept arm read as reaching forward;
  - the rose offer kept a second rose in the lapel.
  
  All four were fixed as data and redrawn in run `terciopelo-v1-20261107d`.
- **I restarted the wave after the fixes, and `collect_qwen.py` brought back the superseded candidates.** It files by skeleton name, not by prompt. So the fixes went into their own run rather than into run `c`.
- **The offer bust's redraw reused the empty bust's seed (991530),** from a bug in my runner. It's named by its real seed now and the runner is fixed.
- **The busts:** Qwen redrew the whole bust for each drawing, so the jacket's folds differ a little between cuts. Only the head and shoulders are held still.

## Not done, or not seen

STATUS_NOT
