# The Pool Player's sprites, 2026-11-07

Written while the wave runs: this says what stands today, and gets updated as frames land.

## Facts so far

- **The pipeline carries a cue.** `drawing.cue` says where it lies per pose, planted through the wrist or held along a direction. The rig renders it as a mask (`cue-shaft`, `cue-butt`), and planning draws it into the skeleton as a white line. `otherHand` moves the free wrist onto it. `register_frames.py --thin-prop` lets the body alone set height and floor.
- **The line works.** In 7 pilot poses, 2 candidates each, the cue went where the line said and the line itself was never drawn. I did not run the no-line control I had planned, because the guided results left nothing to decide.
- **Words beat the skeleton on facing.** "Torso turned away" drew her back on `left_hand.prep`. Fixed in the words; `right_hand.prep` was changed before it was drawn.
- **The accepted back sheets have the cue on the picture's left,** which from behind is her left hand. They are staged mirrored (`stageFlip`) for the spin; the files are untouched.
- **The GPU is contended:** jobs took 420 to 1250 s against the 92 s the backend file assumes. So her set is cut (below) and drawn in priority order.

## Proposals (the owner can reverse any of these)

- Her dance: the cue planted like a pole on groove and foot calls, leaned away from on the free-hand call, swung in an arc on the cue-hand call, sighted down on `invite`, chalked on `challenge_load`, both hands stacked on it to watch.
- `retreat_backward` isn't drawn, to save 6 jobs. The billiards level's dancer block doesn't use it.
- Eight spin views added, because the level's spin clip reads them.
- **Hardest combo: Tres Bandas,** for three-cushion billiards. It hasn't been played, and its test hasn't run: Flutter can't run in this worktree.
- Background players: A, a tall thin man of about seventy in a flat cap; B, a short round woman of about forty-five with a halo of curls; C, a broad bald man of about fifty with a red beard. Sheets chosen by me. C's hooked cue butt was straightened by hand.
- Close-up: she chalks, winks, and dabs. The key is candidate 989700, mirrored so she faces Mācron. Title proposal QUÉ CARAMBOLA is the billiards agent's call.

## Not done yet

The rest of the wave, picking, finish, pack, the close-up's reach and dab, and local-vision curation.
