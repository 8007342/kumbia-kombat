# El Gran Comedor: the room, its life, the diners, the staff and Don Charolas

**2026-11-08, branch `work/1881-cmdr`, agent COMEDOR.** This is for the owner, WIRE2 (who wires `levels/comedor.json`) and whoever finishes the level. Facts are marked [F] and my proposals [P]. I made every choice under the owner's delegation ("agents accept their own art and design choices"), and each one can be reversed. Nobody has seen any of this moving or on a phone. I built to `plan/levels/mansion-act-two-2026-11-08.md`, section 6.

## What's on the branch

| What | Where | State |
|---|---|---|
| Room spec | `tool/art/rooms/comedor.json` | Done |
| Accepted plate (the source) | `art_runs/rooms/comedor/picks/plate-992300.png` | Done |
| Clean plate the game draws | `assets/art/comedor/comedor-room.png` | Done |
| Layers: chandeliers and room life | `tool/art/rooms/layers/comedor.json`, `assets/art/comedor/comedor-layers.png`, level block in `art_runs/rooms/comedor/layers-level.json` | See "Room life" |
| Marks for WIRE2 | `art_runs/rooms/comedor/marks.json` (plate fractions) | Done, sent |
| Diners | atlases `diner-a` to `diner-g`, `tool/art/rooms/inplace.py`, `tool/art/rooms/inplace/diners.json` | See "Diners" |
| Junior waiters | atlases `waiter-a`, `waiter-b`, `waiter-c` | See "Staff" |
| Don Charolas | atlas `charolas`, `tool/art/characters/charolas.json`, motion set `opponent-polka` | See "Don Charolas" |
| His choreography | `dancers.charolas` in `assets/art/ensemble/choreography.json` | Done |
| LA TORRE DE CHAROLAS | `art_runs/rooms/comedor/hardest-combo.json`, a proposal for the level file | Done, sent |
| Close-up | `assets/art/closeups/comedor-*`, `art_runs/comedor-closeups-20261108/scripts/` | See "Close-up" |

(Each section below closes with what landed and what didn't.)

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
