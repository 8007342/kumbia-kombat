# El Gran Comedor: the room, its life, the diners, the staff and Don Charolas

**2026-11-08, branch `work/1881-cmdr`, agent COMEDOR.** This is for the owner, WIRE2 (who wires `levels/comedor.json`) and whoever finishes the level. Facts are marked [F] and my proposals [P]. I made every choice under the owner's delegation ("agents accept their own art and design choices"), and each one can be reversed. Nobody has seen any of this moving or on a phone. I built to `plan/levels/mansion-act-two-2026-11-08.md`, section 6.

## What's on the branch

| What | Where | State |
|---|---|---|
| Room spec | `tool/art/rooms/comedor.json` | Done |
| Accepted plate (the source) | `art_runs/rooms/comedor/picks/plate-992300.png` | Done |
| Clean plate the game draws | `assets/art/comedor/comedor-room.png` | Done |
| Layers: chandeliers and room life | `tool/art/rooms/layers/comedor.json`, `assets/art/comedor/comedor-layers.png`, level block in `art_runs/rooms/comedor/layers-level.json` | Done, wired by WIRE2 |
| Marks for WIRE2 | `art_runs/rooms/comedor/marks.json` (plate fractions) | Done, sent |
| Diners | atlases `diner-a` to `diner-h`, `tool/art/rooms/inplace.py`, `tool/art/rooms/inplace/diners.json` | Done, in the manifest, wired by WIRE2 |
| Junior waiters | atlases `waiter-a`, `waiter-b`, `waiter-c`, motion set `staff-polka` | Done, in the manifest, wired by WIRE2 |
| Don Charolas | atlas `charolas` (81 drawings, 104 frames), `tool/art/characters/charolas.json`, motion set `opponent-polka` | Done, in the manifest (2892b75); WIRE2 swaps it in |
| His choreography | `dancers.charolas` in `assets/art/ensemble/choreography.json` | Done |
| LA TORRE DE CHAROLAS | `art_runs/rooms/comedor/hardest-combo.json`, a proposal for the level file | Done, sent |
| Close-up | `assets/art/closeups/comedor-*`, `art_runs/comedor-closeups-20261108/scripts/` | Done, wired by WIRE2 (beats 5 to 11.5) |


## The room

**Look** [P]: the mansion's long dining hall, seen broadside from the dance floor.
- A banquet table runs across the room in front of the far wall, with a cream damask cloth to the floor, soup bowls, wine glasses and two silver candelabra.
- On the wine-red damask: a gentleman's portrait on the left, a wide still life (fruit and a silver jug) in the middle, a lady's portrait on the right.
- A white marble statue stands in a lit arched niche at the far left, and two crystal chandeliers hang high at the corners.
- The service door, with a round window and a brass plate, is at the far right: the way out toward the salon.
- The floor is dark walnut planks, calm in the tap band.

**How it was made** [F]: the `rooms.py` route, three runs and 18 candidates.

| Run | What | Result |
|---|---|---|
| run-a, pass 1, 4 candidates | Style reference: the salon (newly added to `style.json` `acceptedRooms`) | All four ignored the layout: a deep room with a tiny table far away |
| run-b, pass 1, 4 candidates | Style reference: the billiard room | Held the broadside layout. 992102 and 992100 kept the table across the room |
| run-b, pass 2, 6 candidates | From 992102 and 992100 | Five of six turned the table to run toward the viewer, filling the dance floor. **992300** (from 992100) kept it across |
| run-c, pass 2, 4 candidates | From 992100, with words "runs straight across ... parallel to the far wall ... no chairs on the near side" | All four ran the table toward the viewer. The word "long" seems to pull it into depth |

**Picked 992300** [P], by eye at phone crop beside the salon and billiard plates. It has every element the brief asks for, the warm candle light, wine red and cream, and a calm floor. Its faults, all fixed as layers:
- a row of five black chairs on the table's near side, hiding the table front;
- two orange lamp discs left from the guide's lamp marks;
- chandeliers at the corners, partly outside a 390-wide phone (x .15-.29 and .72-.88).

**Local vision** [F]: qwen2.5vl:7b on the 8 first passes, asked for chandeliers, table, people, statue, text and wall colour. It said "three chandeliers" on run-a's (true for two of them) and "no statue" on all eight, which was right for pass 1. It answered nothing that changed the pick. Four calls hit a 45 s model load and one timed out, so it cost more than it saved. The pick was made by eye.

**Camera** [F]: horizon .27 and eye 1.0 adult, the salon's camera. On the paint, the far wall's foot is at y .394 (s 5.23 against the spec's 5.0) and the cloth's foot at y .437. The service door is 1.41 adults tall at its foot. Mācron at heroHome is about 45 logical px. The spec's comment holds the measurements. `rooms.py compile comedor` passes.

## Clean plate and layers

`tool/art/rooms/layers/comedor.json` [F]:
- **Chandeliers:** lifted out as `hanging` props. They sway on a 4-beat period with a 2 px reach, and wake at minTier 3. A new colour rule, `crystal`, separates them from the red damask. The fills are Qwen removals: left 77000, right 77101.
  - The left one hangs in front of the niche's arch. Its polygon's foot follows the arch, so the arch doesn't move, but a thin cream arc of arch pixels still sits inside the matte and sways with it (at most 2 px).
  - Both fills keep a faint orange glow halo where the chandelier was. The chandelier covers it at rest.
- **Orange discs:** painted out (fillOnly, 77200, 77300).
- **Near-side chairs:** painted out, so the diners can sit behind the table and be seen.
  - Above the table edge: Qwen fills, one per chair.
  - The cloth front: Qwen redrew it with damask patterns in different places, so the patches read as a quilt. The whole front is now one clean 34 px strip of the painted cloth, tiled across (a new `tile` fill). It reads as regular folds.
- Rest frame against the painted original at phone size: mean difference 4.47. That's the removed chairs and discs, on purpose.

## Room life at full party

The owner asked for paintings and a sculpture "doing gently invisible motions" at full party. Here it is a reusable layer type: `kind: "artwork"` with a `minTier`. The data contract and how to make one are in `tool/art/rooms/README.md`, "Room life at full party". WIRE2's loader (on `work/1883-lvls`, merged to `game` at 8c84e31) gates the props on the tier, and the chandeliers wake one tier earlier. [F]

| Prop | What moves | How | Timing |
|---|---|---|---|
| statue-nod | The marble statue's head nods | Warp about the neck, 2 px, `marble` colour rule, harmonic fill under it | pulse, every 2 beats, minTier 4 |
| statue-tap | The statue's foot taps | Warp of the toe about the heel, 3 px lift | pulse, every beat, minTier 4 |
| portrait-lady | The lady in the portrait tilts her head | Warp about the neck, 2 px | sway, 4 beats, minTier 4 |
| portrait-snap | The gentleman in the portrait snaps his fingers | A drawn Qwen edit of the portrait (78301), whole polygon, the plate as rest | pulse on 2 and 4 (`periodBeats 2`, `phaseBeats 1`), minTier 4 |
| chandeliers | Both sway | The salon's hanging warp, 2 px | sway, 4 beats, minTier 3 |

- **The snap took two tries** [F]. First wording (78200, 78201): the hand rose, but both folded hands stayed at the waist, giving three hands. Naming each hand on its own ("rests alone at his waist ... is raised beside his shoulder") fixed it in both seeds. I kept 78301, whose fingers read more as a snap.
- **What I dropped** [P]: a foot tap on a painted portrait. Both portraits are cut at the knee, so there was no painted foot to tap; the statue's foot does it instead. The still life stays still.
- **Not seen moving** [F]: `motion.gif` and `before-after.png` are in `~/.cache/tillandsias-project/kumbia-art/layers-comedor-20261108/`, but a GIF can't be judged by any tool here.

## Diners

**Route** [P, F]: drawn in place, as the salon's pianist was, using the generalised tool `tool/art/rooms/inplace.py` with spec `tool/art/rooms/inplace/diners.json`.
- Qwen drew the whole row of diners onto a 3x crop of the clean plate behind the table, and every meter stage is one group edit of that key.
- Each figure is cut from its own column, so the table, candelabra and light are the plate's own, and the cloth hides their laps.
- That made eight atlases for 1 key plus 8 edits, 19 images in all (3 keys and 2 candidates per edit), instead of eight sprite families.
- The trade-off: they are plate pixels, not palette-locked sprites, the same trade as the pianist.

**Cast** [P]: eight diners in formal dinner dress, left to right:
1. an older gentleman with white hair and a grey beard in a tailcoat;
2. a woman with a dark chignon in emerald;
3. her neighbour in the same gown, which the key drew twice. Code turns the gown plum (`recolour`), so they read as sisters;
4. a bald man in a burgundy velvet dinner jacket;
5. a young woman with a long braid in gold;
6. a bearded man in a navy suit;
7. an elderly woman with a silver updo and pearls in lavender;
8. a young man with round glasses in grey and a green bow tie.

All are covered and elegant, and mixed in age and build.

**Picks** [F], each judged by eye on the strip:

| Frame | Kept | Why |
|---|---|---|
| eat_a | key 995000 | 995001 held seven diners but moved the left candelabrum, which would flicker as single diners change; 995002 doubled the gown too and hid a candelabrum |
| eat_b | 995100 | Spoons at their mouths |
| watch_a | 995200 | 995201 gave the bald man hair |
| watch_b | 995301 | Most hands at the chin |
| clap_a | 995400 | Hands at the chest |
| clap_b | 995501 | 995500 gave the bald man hair |
| rise_a | 995600 | Hands on the table edge, leaning up |
| toast_a | 995700 | Every glass raised |
| toast_b | 995800 | Laughing, glasses tilted together |

**Weak points** [F]:
- The diners never fully stand. "Rise" is a lean up off the chair, and both toasts are seated with glasses high. The words asked them to stand, and every candidate kept them seated.
- In toast_b the bald man has a little grey hair.
- In toast_a the gentleman on the far left lost his raised arm, because it reached outside his column.
- Edits shift a few pixels (aligned back, residual 22-38). The candelabra sit on column edges and may shimmer as neighbours change.

**Crowd count** [P]: WIRE2's crowd needs exactly 12. That's 8 diners, 3 junior waiters and 1 late guest (guest4, in evening dress, by the right wall).

## Don Charolas

**Definition** [P]: `tool/art/characters/charolas.json`, he/him.
- Body preset `short-round-adult` (new in `tool/art/rig/bodies.json`): short legs, a round belly, a big head, a short neck. He's the opposite of Don Terciopelo's tall narrow vertical.
- Look: round rosy cheeks, slick black hair, a tiny black moustache, a white double-breasted waiter's jacket with brass buttons, a black bow tie, a long white apron, black trousers and shoes.
- The silver tray (two glasses of red wine), the cloche, the tower and the napkin are in the pose words, not rig props.

**Motion set `opponent-polka`** (new, `tool/art/rig/poses.py` and `tool/art/motion/opponent-polka.json`), 81 drawings:
- **The 64 shared names, with the tray on his left hand (the picture's right) in every drawing.** Mirrored right-side drawings get the tray put back on the left, so it never changes hands. The shared words are rewritten by code: clauses about his left arm are dropped and the tray clause is added.
- **Groove: the norteño polka hop step** per side: a bouncy step on 1, the feet closed on the balls on "and", a second step on 2, and a hop with the free knee high on "and".
- **left_hand** is the tray itself thrust up high. **clap** slaps the free hand on his thigh, because the other hand holds the tray. **finish** smooths his slick hair.
- **New clips:**
  - `spin` (8 views, the tray up the whole way round);
  - charisma: `tray_wobble.a/b` (the tray tips and the glasses slide, then it's saved level with a smug flourish) and `napkin.a/b`;
  - the tower: `torre.a/b` (five stacked trays held high, then a hop under them);
  - the win: `cloche.stop/present/lift`.
- **Pose check:** spin views held at three quarters are exempt from the wrist-near-head rule (`TRAY_TURNS` in `check_poses.py`), because there the tray hand crosses the head in 2D. The shared side-step's trailing knee bends a little more for his short legs.

**Sheets** [F, P]:
- Pass 1 drew four fronts from words, with Don Terciopelo's front as the style only.
  - The first wore a red rose: Don Terciopelo's accent, copied. Rejected.
  - I kept the third, 993002, for its rosy cheeks, tiny moustache and double-breasted jacket.
- Pass 2 redrew from that one: front 993102 and back 993101.
- **The centre parting doesn't show** at this size in any candidate, even with words that ask for it twice. His hair reads as slick and black.
- The back sheet holds the tray on the picture's right, which from behind is his right hand. No back-view frame is planned, so it doesn't matter yet.

**Choreography** (`dancers.charolas`, `assets/art/ensemble/choreography.json`) [P]:
- Clips: polka_spin, tray_save, napkin_flick, torre, torre_hop, spin_stop, cloche_present and cloche_lift.
- Accents: the tray save from tier 1 at beat 4 of 16, the napkin flick from tier 2 at beat 12, and the tower from tier 3 every 32.
- Hand-off moves: polka_spin, and tray_save in a cold room.

**LA TORRE DE CHAROLAS** (`art_runs/rooms/comedor/hardest-combo.json`) [P]:
- Moves: a polka spin (beats 0-2), the tower up (2-3), hops under the tower (3-7), the tower held (7-8).
- WIRE2 re-timed my notes to gaps of 0.75 beats or more, because half a beat is 221 ms at 136 BPM, under the 230 ms good window. It closes on a right-foot stomp.

## Staff: three junior waiters

[P] The juniors wear black waistcoats, long black bistro aprons and black bow ties over white shirts, so the head waiter stays the one in white.
- `waiter-a`: a young man with dark hair and an eager grin.
- `waiter-b`: a young woman with auburn hair in a high bun.
- `waiter-c`: a young man with a shaved head and a neat beard.

Each holds the tray on the picture's right.

**Route** [F]: the `art-family` skill. Each sheet was drawn from words with Don Charolas' front as the style reference, three candidates each; I kept a 994001, b 994102 and c 994201.
- All three came out a little rounder than the words asked (lean, slim, sturdy): the style reference pulls build toward his. A's curly hair came out straight.
- Frames: a new motion set `staff-polka` holds only Don Charolas' polka groove (8 drawings) and one standing drawing, `idle.a`, so the atlas needs no runtime aliases for clips the staff never dance. That's 9 poses at 2 candidates each per waiter, all picked by eye. I rejected a pointing hand (reserved), and a white sock and a white heel the model invented.
- waiter-c was planned on `stocky-adult`, but the rig put two of the shared poses outside the frame margins, so he's on `slim-adult` with "sturdy" in the words.

**Manifest** [F]: waiter-a, b and c, frames `groove_*` and `idle_a`. WIRE2 mirrors waiter-b, so the tray swaps hands on that one figure. I told WIRE2 that was acceptable.

## Close-up: QUÉ / BANQUETE

`assets/art/closeups/comedor-art.json`, in the salon-art.json shape. WIRE2 wired it on beats 5 to 11.5. [F]
- **Don Charolas** (`comedor-dc-*`): four Qwen edits of one bust crop of his accepted front (`art_runs/comedor-closeups-20261108/scripts/bust_jobs.py` holds the words), two seeds each, placed by hair top and face centre by `comedor_bust.py`, then snapped to his palette plus the can's colours on a 2-px grid.
  - **present** (996001): the cloche closed on the tray.
  - **lift** (996011): the cloche lifted, the tiny green oil can with a lit birthday candle revealed.
  - **offer** (996020): the tray with the can held out to the right, the cloche raised like a trophy.
  - **empty** (996030): the tray empty, eyes in happy arcs.
- **Mācron** (`comedor-mc-*`): drawn from parts by the close-up rig, no GPU (`comedor_macron.py`). The can and candle are code shapes.
  - **reach**, then **take** (the can held up, round eyes);
  - **sip**: the can tipped to the bottom of his face screen, eyes shut. He has no mouth, so the screen does the sipping;
  - **happy**: big arcs, a blush.
- **Plate:** `comedor-banquete-plate.png`, a crop of the clean plate.
- **Weak points** [F]:
  - The cloche runs off the top edge in *empty*, and a little off the right in *lift*, because the source drawings put it at their own edge.
  - His cheeks snap browner than his sprite's in *present*.
  - Between present and lift the tray drops from head height to chest height. Those are cuts on beats, but it's a jump.

**Frames** [F]:
- The route: the Qwen frame route from this worktree with `run_jobs.py` and the 2511 Lightning LoRA.
  - A pilot of 12 hard poses ran at 2 candidates; the rest ran at 2, then 1 once the shared queue was taking 250 s a job.
  - Registered, then the local vision pass, then picked by eye on contact sheets of every candidate.
  - Finished with `finish_run_picks.py` on his own palette, packed and promoted with `promote.py --new`.
- Picks are in `art_runs/charolas-v1-20261108a/picks.json`, with the reasons.
- **Redrawn:**
  - `watch.hold_l` had a tray in each hand. A pose override that says "exactly one tray" fixed it (993500).
  - `left_hand.peak/follow`, the tray call, never lift the tray above his shoulder: 4 candidates over two skeletons, the second with the arm straight up. I kept the best of them (993501). **Weakest drawing in the set.**
- **Rejected by eye:** a tray that swapped hands (tray_wobble.a 993101), invented white shoes or socks, and spin side views with the tray on the far side.
- **New in `finish_run_picks.py`:** `dropFloorShadow`. Qwen sometimes paints a soft grey floor shadow under the shoes, and the matte keeps it. Style guide: no floor shadow in frames.
- **Pilot findings, kept as data:** clap slaps the thigh (one hand holds the tray); spin side views at three quarters are exempt from the wrist-near-head rule.

## Local vision against my eyes

qwen2.5vl:7b through `vision_curate.py`, heads and hands on all 96 registered candidates of Don Charolas: 227 s, 8 flagged. [F]
- **All 8 flags were wrong.** It counted the apron's bow or the napkin as a third hand. I checked the five clearest at 2x.
- **It missed every real fault my eyes caught that it was asked about:**
  - the tray in each hand (that candidate had been set aside before the pass, so it was never asked);
  - the swapped tray;
  - the white socks;
  - the floor shadows;
  - the tray that never rises.
- On room plates it answered the easy questions right and the question that mattered (where the table runs) not at all.
- It remains a pre-filter that, here, filtered nothing.

## Compute

In `plan/compute-ledger.jsonl`, agent `comedor`. GPU seconds are studio elapsed or wall time per job on the shared host queue, so they are an upper bound: other agents' jobs were interleaved.

| Batch | Images | Seconds |
|---|---|---|
| Room plates, runs a, b and c | 18 | 457 |
| Layer fills and the drawn snap | 22 | 1,308 |
| Diners: key and eight edits | 19 | 2,191 |
| Don Charolas sheets | 10 | 142 |
| Waiter sheets | 9 | 759 |
| Close-up busts | 8 | 941 |
| Don Charolas frames | about 115 | 13,572 |
| Waiter frames | 54 | 5,952 |
| **GPU total** | **about 255** | **about 25,300, or 7 hours of queue time** |
| Local vision | 104 calls | 371 |
| CPU (estimate) | | 900 |

## What was checked, and how

- `rooms.py compile comedor` passes. The `tool/art/tests` room, rig and definition suites pass (39, 7 skipped). Every opponent-polka and staff-polka pose passes `check_poses.py`, with the exemptions named above. [F]
- **Diner atlases:** every anchor lies inside its rect. I checked this in code after WIRE2's loader refused the first version. [F]
- **My eyes saw:** every room candidate at phone crop beside the salon and billiard plates; every layer fill; the layer atlas and a rest-against-original composite; every diner group edit; every candidate of all four figure families beside its skeleton; each packed atlas; and the close-up drawings. [F]
- **Not run by me:** `flutter test`. WIRE2 runs the suite on its wiring branch and reported 788 passing at 913f36a, with my plate, layers, close-up and diners.
- **Nobody has seen any of it moving.**

## What went wrong

- **Run-a's salon style reference** gave a deep room with a tiny far table: the style image's perspective overrode the layout.
- **Five of six pass-2 candidates, and all four of a reworded run-c,** turned the banquet table to run toward the viewer. A "long banquet table" pulls into depth. Next time, say "a table seen from its long side, across the picture" and leave out "long".
- **The plate painted chairs on the table's near side.** Painting them out took Qwen fills for the table top and a tiled strip for the cloth, because Qwen's cloth fills came back as patchwork damask.
- **My first chandelier mattes** took the gilt edge of the portrait frames and the niche's arch with them. Tightened by polygon. A thin arc of the arch still sways with the left chandelier.
- **The snap's first wording** drew a third hand.
- **The crowd needs exactly 12** (WIRE2). My first marks gave 7, which became 8 diners, 3 waiters and 1 late guest.
- **Engine and data mismatches, both fixed in data:**
  - The diners' first atlases put the floor anchor outside the frame rect, and the loader refused them. Rects are now padded to the anchor.
  - The waiters on the opponent motion set needed runtime aliases for clips they never dance. A small `staff-polka` set fixed that.
- **`/home/forge/src` filled up at 02:13** and git failed in every worktree. Nothing of mine was lost: my output never went there.
- **My own errors:**
  - A `pgrep -f` wait loop matched its own shell, the brief's warned trap. I caught it before it hung and replaced it with `kill -0` on a literal PID.
  - A `mv` into an existing directory nested one folder in another; I removed it.

## Needs eyes, on a phone, moving

- [ ] The room at full party: do the statue's nod and tap, the lady's head tilt and the gentleman's snap read as "felt more than seen", or not at all? Are the chandeliers' halos and the swaying arch arc invisible?
- [ ] The diners' meter: does eat, then watch, then clap, then the lean-up and toast read across the room? Do the candelabra shimmer as single diners change?
- [ ] Don Charolas' polka hop at tempo, and the tray save and napkin flick between phrases.
- [ ] The tray call (`left_hand`): does the cue read without the tray going up?
- [ ] waiter-b mirrored, with the tray in the other hand.
- [ ] The close-up: the jump from present to lift, and Mācron's sip.
- [ ] The tablecloth's tiled folds in the tap band's upper edge: regular enough to read as cloth, not as a pattern?

## Not done

- **A real stand-up for the diners.** No candidate stood them up behind the table. A drawn standing pose would need another key.
- **The centre parting** in Don Charolas' hair.
- **A drawn foot tap on a portrait.** Neither portrait shows a foot; the statue taps instead.
