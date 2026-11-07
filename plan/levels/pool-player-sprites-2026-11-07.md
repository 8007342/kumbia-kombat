# The Pool Player's sprites, 2026-11-07

Everything below is on `work/1870-pool`. Art choices here are the agent's, under the owner's delegation, and the owner can reverse any of them. **Nobody has seen any of this moving or in the game.** Checks were contact sheets and still composites, by eye.

## What exists

| Atlas or art | File | Frames |
|---|---|---|
| `pool-player` | `assets/art/ensemble/pool-player-v1.png` | 92 ids: 63 picked drawings, 9 copied names, 20 runtime aliases |
| `pool-bg-a`, `pool-bg-b`, `pool-bg-c` | `assets/art/ensemble/pool-bg-*-v1.png` | 12 ids each: `stand`, `chalk_a/b`, `lean_a/b`, `stroke`, `watch_a/b`, `clap_a/b` |
| Her close-up | `assets/art/closeups/pool-player-{chalk-a,chalk-b,wink,reach,dab}.png` | 440 x 620, scale .36, contact `[436, 203]` |
| Mācron with the dot | `assets/art/closeups/pool-macron-{round,wide,squash,arc,arc-blush}.png` | contact `[200, 22]` |

Review sheet of her picks: `art_runs/pool-player-v1-merged/review.png`.

## Her dance (proposal)

Her right hand keeps the cue, so her arms differ from the shared table; her legs and hips mostly don't.

- **Planted like a pole:** groove, foot calls, approval, reassurance.
- **Free-hand call:** she leans away from the planted cue at arm's length, free arm thrown up.
- **Cue-hand call:** the cue swung in an arc over three drawings, gripped near the butt, as the twirl.
- **`invite`:** bent over, sighting down the cue like a shot.
- **`challenge_load`:** chalking the tip with a blue cube. **`watch_*`:** both hands stacked on the cue. **`clap_*`:** the free palm comes to the cue held upright. **`finish_b`:** the cue held up like a salute, since she has no hat.
- **Turns:** pivoting round the planted cue. **Spin:** eight views with the cue carried upright.

**Hardest combo, proposal: Tres Bandas,** after three-cushion billiards. 8 beats, 11 notes; chalk and sight, a spin, then notes ricocheting corner to corner and speeding up into the last hit. In `levels/index.json` here; the billiards agent takes it into `levels/billiards.json`, which wins at merge.

**Close-up, proposal:** she chalks, the tip turns blue, she winks, the cue comes in level above his head and dabs a blue dot on his antenna, and his eyes turn to arcs. Title QUÉ CARAMBOLA is the billiards agent's call.

**Background players, proposal:** A, a tall thin man of about seventy in a flat cap. B, a short round woman of about forty-five with a halo of curls. C, a broad bald man of about fifty with a red beard. All adults and fully clothed. Sheets and frames chosen by the agent.

## What the pipeline gained

`drawing.cue`, the white guide line in the skeleton, `otherHand`, the mask shapes `cue-shaft` and `cue-butt`, `register_frames.py --thin-prop`, `stageFlip`, the `opponent-cue` and `pool-bg` motion sets, and `finish_picks.py`, `merge_runs.py`, `cue_review.py`, `cue_sheet.py`. Details in `tool/art/pipeline/README.md`. New tests: `tool/art/tests/test_cue.py`, 5 pass.

## What was found

- **The guide line worked.** The cue went along it in the pilot's 7 poses, 14 candidates. I had planned a no-line control and skipped it, so "works" is not "better than nothing, measured".
- **It sometimes draws the line itself.** A thin white stroke showed up in roughly a dozen candidates, a rough count from the sheets rather than a measure, and on B most of all. Rejected by eye, not by any tool. One more reason to look at every pick.
- **Consistency in a moving set:** body height and floor measured on the finished groove and spin frames: floor within 1 native pixel across all 16; head top 50 to 52 except the two deep-knee `down` drawings, at 63, which is the dip. That measures position, not whether it looks good moving.
- **Words beat the skeleton on facing.** "Torso turned away" drew her back on `left_hand.prep`. Fixed in the words.
- **Qwen often turned the cue end for end** when swung (butt up, tip down). I picked the right way round; `right_hand` has two reversed candidates rejected.
- **The first palette was wrong.** Written before the sheet existed, it made her shoes brown and her skin dull. Colours now come from the accepted sheet. Dark trouser shadow also snapped to shoe red, so shoe colours now need the raw drawing to be red there.
- **The accepted back sheets carry the cue on the picture's left, with a cream knob on the butt.** From behind that's her left hand, so they're staged mirrored for the spin (`stageFlip`). The knob came along on `spin_back*`.

## Known weaknesses, for an owner's eye

- **Walk frames:** the cue jumps between upright and slanted through `enter_forward` and `yield_side`. It could read as swinging or as flicker.
- **`clap_release`** moves the free hand out more than a bounce. **`clap_close`** has the cue across the edge of her face.
- **`spin_side_l`** has the cue slanted behind her legs where the others carry it upright. It's one frame of a fast turn.
- **Hand work in the close-up:** `reach` and `dab` have a squinting smile, not a clean wink. Body below the drawing is a plain column carried down, which the table is meant to hide.
- **Background:** `chalk_b` is `chalk_a` settled one pixel at the waist, because Qwen wouldn't draw chalking twice the same, so that loop is very subtle. B's `stand` has no cue: it was drawn apart from her hand and the matte dropped it. B has faint pale strokes on her cardigan on `chalk`, a remnant of the line. C's sheet had its hooked butt straightened by hand.
- **Not drawn:** `retreat_backward`, 6 jobs saved; its names are copies of `enter_forward`, and the level doesn't use them. Three `yield_side` names are copies too.

## Tests and tools

- **Art tests:** 247 run, 2 fail, 7 skipped. Both failures (`test_only_the_edited_part_changes`, `test_the_skinny_gatekeeper_wave_is_caught`) also fail on `game` at 42a669d, without this branch.
- **Flutter hasn't run here:** the worktree is outside the path the `flutter` command accepts. So `test/hardest_combo_test.dart`, the manifest loading the new atlases, and Tres Bandas are all unverified until merge. Clip lengths for the combo were checked by hand against `choreography.json`.
- **`run_jobs.py --verify` wasn't run,** so the baked prompts weren't compared with ComfyUI's history. The frames do follow the prompts' words where I looked.

## Local vision against my eyes

qwen2.5vl:7b counted heads and hands and named the view on all 63 picks, and on 6 frames I had rejected. 1240 s across 256 calls, in the ledger.

- **Front or back: useful.** It named all three rear picks as back, and caught `left_foot.peak` candidate 1, the rejected back-turned frame. It called side views front, except one it called side, so it only separates a real back from everything else.
- **Heads: said 0 on the three rear views.** Otherwise 1. It can't count a head from behind.
- **Hands: 2 false alarms in 63.** `clap_close` got 4 and `yield_side.pass_r` got 1; `clap_close` has two hands when enlarged. I didn't enlarge `pass_r`, where one hand is out of sight.
- **Faults it missed:** on 6 rejected frames I asked only for sticks and view. The stray patch on a shin, the hook on a butt and a white line over the tip all got one stick and the right view. A white line beside the cue got "2 sticks", which is a hit if you ask that way. A small sample. All my rejections other than facing came from my own reading of the sheets.

## Compute

In `plan/compute-ledger.jsonl`. GPU seconds there are wall time per job **including the shared queue**, because the driver doesn't get the engine's own time: 20761 s for her 71 jobs, 14133 s for the background players' 40, 3100 s for 4 close-up jobs. Jobs ran 123 s when the queue was clear and up to 1250 s when not, against the 92 s the backend file assumes.

## Needs an on-screen look

Her dance in the room, especially the groove and spin moving; her standing height from `occupied`; whether the call poses read as hand calls from that distance; the close-up on the real plate with the table; the players behind table cut-outs, and B's `stature`.
