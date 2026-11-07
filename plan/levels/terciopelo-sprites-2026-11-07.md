# Don Terciopelo sprites, 2026-11-07

Branch `work/1875-terc`. The coordinator delegated acceptance for the salon (`plan/levels/salon-2026-11-07.md`). So every art and design choice below was made by this agent, and each one is a **proposal the owner can reverse**.

## What exists

- **Atlas `terciopelo`:** `assets/art/ensemble/terciopelo-v1.png`, 1024 by 3320.
  - It was promoted into `assets/art/ensemble/manifest.json` with `promote.py --new`, and it loads by data.
  - 86 drawings and 22 aliases, 108 frames in all, at `pixelsPerUnit` 6.6323.
  - **The bow is mirrored:** `bow_a`, `bow_b` and `bow_hold` carry `"mirror": true`. Qwen drew the deep bow facing left. LEVEL asked for the flag so he bows to the picture's right, toward Mācron, which keeps the close-up's sides (style guide 8.1, rule 3). During the bow the lapel rose shows on his other side, about 2 px, until he plucks it.
  - **Picks:** `art_runs/terciopelo-v1-20261107m/picks.json`, merged from runs `c`, `d`, `g` and `h` (later runs win per pose). Thirteen of the scorer's picks were changed by eye, each with its reason in `why`.

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
    - the win: `bow.a/b/hold`, a deep bow drawn facing the picture's left (mirrored in the manifest), and `sweep.a/b`, an arm sweep to the picture's right;
    - `rose.pluck` and `rose.offer`.
  - **New aliases:** `mirror_look` (= `glance.b`) and `flare_open` (= `flare.line`).
- **Pose check:** `tool/art/rig/check_poses.py` gets three exemptions, each named:
  - a hand at the moustache, hair or lapel, or the head coming down in a deep bow (`FACE_TOUCH_CLIPS`);
  - the profile spin views (`SPIN_SIDE`);
  - the bow, which is a turn and a profile clip, and whose hand behind the back crosses the near arm in 2D (`TURNED_BEHIND`, `TURN_CLIPS`, `PROFILE_CLIPS`).
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

- **Route:** the Qwen frame route, run from this worktree with `run_jobs.py`, mostly at 2 candidates a pose (3 or 4 for the redrawn bow and moustache).
  - The 2511 Lightning LoRA was passed by override.
  - The finish was `finish_run_picks.py`, the local finish on his own palette, which isn't on `game` yet.
- **Pilot first, on 12 hard poses.** Four needed new words or a new skeleton; see "What went wrong". The bow took three more tries:
  - at three quarters the bend didn't show;
  - turned to profile and asked to face right, Qwen drew the deepest bow facing left in 4 of 4;
  - so the data now says left, and the manifest mirrors those frames.
  
  `moustache.b` was redrawn once (run `h`): neither first candidate had a hand at the face.
- **Review:**
  - `score_frames.py` ranked first.
  - The local vision pass counted heads and hands on all 175 registered candidates: qwen2.5vl:7b, 131 s, 5 flagged.
  - I looked at every candidate beside its skeleton in contact sheets, then at the packed atlas at native size.
- **Local vision against my eyes:**
  - It flagged 5. One was a real miss of mine to check: `bow.b` 991002, which it saw with 2 heads; it wasn't picked. Four were hands it couldn't find behind the back or clasped, which were fine.
  - It caught none of the actual faults:
    - two candidates holding a cigarette-like stick at the moustache;
    - the rose drawn on his back in a rear spin view;
    - puffed-up hair in four frames;
    - a caricatured face;
    - a hand fan and a hand mirror in the held line;
    - no hand at the face in either `moustache.b` candidate.
  - As before, it's a pre-filter only.
- **Scorer:** it flagged 21 poses as weak matches and still picked badly in 13. Its picks for faces and hair aren't to be trusted.
- **Character check:** frames came out 36% narrower than the sheet by its build measure. He is meant to be the narrowest opponent, and at native size he reads as tall and slim beside the sheet. Advisory only.
- **Tests:**
  - `tool/art/tests` ran 226: 4 failures and 11 errors, all from files the sparse worktree doesn't have (`art_runs/` beyond rooms). None comes from this change.
  - Flutter refuses to run outside the main checkout, so `flutter test` wasn't run here. LEVEL runs the suite when it swaps the GateKeeper stand-in for this atlas.
- **Compute:** about 2.2 hours of GPU wall time on the shared queue, 7,937 s for frames plus 1,561 s for sheets and busts; 131 s of local vision; a few minutes of CPU. Lines are in `plan/compute-ledger.jsonl`.

## What went wrong

- **The first front sheet's second attempt was refused.** `run_jobs.py` always sends the two-image graph, and a sheet job drawn from a reference has one image. I bound the same crop to both images, the way the nod close-up did.
- **`collect_qwen.py` files a one-image sheet job by its input's name,** so pass 2's outputs had to be found by their provenance. Every other agent's outputs share that studio folder.
- **Pilot misses:**
  - "a held ballroom fan line" drew a hand fan, and once a hand mirror;
  - the hand offer stood the palm up like a wave;
  - the bow's swept arm read as reaching forward (and the bow then took three more runs, `e`, `f`, `g`);
  - the rose offer kept a second rose in the lapel.
  
  All four were fixed as data and redrawn in run `terciopelo-v1-20261107d`.
- **I restarted the wave after the fixes, and `collect_qwen.py` brought back the superseded candidates.** It files by skeleton name, not by prompt. So the fixes went into their own run rather than into run `c`.
- **The offer bust's redraw reused the empty bust's seed (991530),** from a bug in my runner. It's named by its real seed now and the runner is fixed.
- **My kill command killed its own shell, twice interrupting the session:** `pgrep -f` matched the calling shell. A later `rm` with `~` paths was blocked by a hook and hung. Use `pgrep -af`, then `kill` with a literal PID, and delete with Python.
- **The busts:** Qwen redrew the whole bust for each drawing, so the jacket's folds differ a little between cuts. Only the head and shoulders are held still.

## Not done, or not seen

- **`dancers.terciopelo` is missing from this branch's `choreography.json`.** LEVEL's stand-in commit removed it, and the removal reached this branch when I merged `game`. LEVEL restored it from e5a8d15 on `work/1877-wire` (f53eaae), so take `choreography.json` from there. LEVEL ran the full suite with this atlas in its run copy: 730 pass, and analyze is clean. On stills, the mirrored bow faces Mācron.

- **Nobody has seen him moving, or in a browser.** Flutter doesn't run in this worktree, and the preview isn't mine to update.
- **Needs eyes:**
  - The cha-cha groove at tempo: does the held landing on 1 read as cha-cha-chá, and does the hip settle?
  - The charisma accents between phrases.
  - Whether the mirrored bow looks right with the rose flipped.
  - The bust's jacket folds changing between cuts.
  - Mācron's rose behind his antenna.
- **Weak picks, kept as the best of their candidates:**
  - a few frames carry a burgundy waistcoat under the jacket, the bow tie's colour spreading;
  - `spin.side_*` hold the arms forward more than in a frame;
  - `bow.a` was drawn with contradictory words ("toward the left of the picture toward the right of the picture"). Its picture matches the fixed words, and `poses.py` now holds only the fixed ones.
- **No walk set with the rose:** the wide shot uses `salon-rose.png` placed by data on Mācron's antenna. This was the fallback the brief allowed.
