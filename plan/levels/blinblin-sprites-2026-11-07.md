# BlinBlin sprites, 2026-11-07

Branch `work/1860-blwv`. The owner delegated completion of the indoor party on 2026-11-07, so every art choice below was made by this agent and is a **proposal the owner can reverse**. Review sheet: `art_runs/blinblin-v1-20261107c/review.png`; picks: `art_runs/blinblin-v1-20261107c/picks.json` (a `d:` prefix means the redraw run `blinblin-v1-20261107d`).

## What exists

- **Atlas `blinblin`** (`assets/art/ensemble/blinblin-v1.png`, 1024x2952), promoted into `assets/art/ensemble/manifest.json` with `promote.py --new`. 82 drawings and 24 aliases, 106 frames in all, `pixelsPerUnit` 6.0645, so a standing frame is 38.75 world units tall like the other opponents. It loads by data: it isn't in `EnsembleManifest.atlasIds`.
- **Motion set `opponent-facing-away`**: the 64 opponent drawings plus 18 new ones.
  - `back_groove` 8: the groove turned 180 degrees, drawn from the accepted back sheet.
  - `back_accent` 2: an arm thrown up while facing away.
  - `reveal` 4: glance over the shoulder, rear three-quarter, profile, front three-quarter.
  - `crossed` 4: settle, hold, nod down, nod up.
  - New aliases: `facing_away`, `reveal_turn`, `defeat_stance` and `defeat_nod`. `approve` still points at the old palm-to-chest nod.
- **Medallion swing, baked in**: 47 frames carry it. The medallion trails the neck's movement since the previous drawing, by up to 4 native pixels. Rear views have no medallion, so they carry none, and 4 frames where the detector found no clean medallion hold still: `enter_forward.contact_l`, `retreat_backward.contact_l`, `retreat_backward.pass_l` and `retreat_backward.pass_r`.
- **Sprite nod**: `crossed.nod_down` and `nod_up` are `crossed.hold` with only the head moved, 5 and 1 native px. Qwen's own nod drawings barely bowed the head and redrew the whole body.
- **Matched-nod close-up**: `assets/art/closeups/nod-bb-{rest,down,up}.png` and `nod-mc-{rest,down,up}.png`, 400x440, described in `nod-art.json`.
  - BlinBlin's bowed head is Qwen's, pasted onto the rest drawing's body after aligning the two by the body. Below the collar his three drawings are pixel-identical.
  - Mācron's are drawn from parts with the close-up rig, arms crossed above the āi mark.

## How it was made and checked

- **Route**: Qwen frame route at 4 candidates a pose, and 2 for the second half of the wave once the GPU was contended. The 2511 Lightning LoRA was passed by override. Pilot first, on 12 poses.
- **Pilot fixes**, all as data:
  - The front sheet is staged at 0.84 (`stageScale`), because standing poses ran off the top of the frame.
  - "His mouth stays closed in a cool half smile": open grins were drawn.
  - The back view has its own `extra` words, so it doesn't say "chains on the shirt".
  - A warm closed-eye nod, because "eyes looking down" drew a scowl.
  - The finish salutes from the temple, because he has no hat.
  - Bartender's clap skeleton fixes, which suit the same body preset.
- **Running from a worktree**: `studio.run_workflow` and `studio.finish_pixels` only read the main checkout, so this worktree couldn't use them directly.
  - `tool/art/pipeline/run_jobs.py` sends the committed graph with each pose's baked prompt as a node override.
  - Provenance then records an empty `prompt`. `run_jobs.py --verify` found every planned prompt equal to what ComfyUI received: 78 of 78 in the wave and 6 of 6 in the redraw. The 4 wave poses reused from the pilot were checked against the pilot's baked prompts and staged inputs instead.
  - `finish_local.py` repeats the finish. It matched host output pixel for pixel on one frame only (17,166 pixels), on the palette in the main checkout.
- **Palette**: taken from the accepted sheets' medians, plus a gold ramp. It isn't in the main checkout until merged.
- **Review**: everything was scored and every candidate was looked at in contact sheets with the skeleton beside it. Six poses were redrawn with new words, each with its `why` in the definition:
  - three back poses whose head turned to profile;
  - `left_hand.follow`, which raised the wrong arm;
  - `retreat_backward.down_r`, which had a crossed leg;
  - `clap.open`, with the hands too high.
- **Local vision**: qwen2.5vl:7b, 238 candidates, 184 s. Counting heads and hands per cropped figure caught a doubled figure (`back_groove.pass_l` 01: 2 heads, 4 hands).
  - It missed a second head drawn on a coat's back (`back_groove.up_l` 02), and earlier a four-armed frame it called fine.
  - It reported 0 heads on most rear views and 4 hands on crossed arms. So it is only a pre-filter: picks were made by eye.
- **Compute**: about 6.3 GPU hours of wall time, mostly waiting behind other agents' jobs, plus 3 minutes of local vision. Lines are in `plan/compute-ledger.jsonl`.

## What went wrong

- **My idle time:** the wave finished about 50 minutes before I noticed. My progress monitor expired and I hadn't re-armed it.
- **The first close-up nod job failed:** I queued it before its input file had been written.
- **My test edit was wrong:** I raised the frame count in `test/ensemble_sprites_test.dart` without running it, and PARTY found it fails, since that test counts only `atlasIds`. It's reverted.
- **Strand cutting failed:** cutting every chain strand into a layer by colour broke the strands up and left ghost strands behind. Only the medallion cuts cleanly, so only it swings.

## Not done, or not seen

- **Nobody has seen any of this moving or in a browser.** Flutter doesn't run in this worktree.
- **Strands:** they stay still while the medallion swings. Swinging them would take chain-free frames from Qwen plus code-drawn ropes, which I estimate is one more wave.
- **Weak picks**, kept as the best of their candidates:
  - The groove frames are scored high, because the coat widens his silhouette.
  - `watch.hold_r` reads a little seated.
  - Several walk frames have the medallion off centre.
- **His own choreography:** `blinblin` has no `frames`, `accents` or named hardest combo yet. The late bathroom boss needs one.
