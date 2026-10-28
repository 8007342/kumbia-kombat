# Kumbia Kombat playable storyboard

Status: authored five-level sequence and asset contract; Garden background source is generated and visually inspected; single gatekeeper sprite is generated and visually inspected. All timings are transport beats unless explicitly seconds. Sequence IDs are stable integration hooks. Pose IDs below describe required production clips; a source concept does not imply its clip exists. Stage duration includes teaching/calls/responses, recovery-free progress and traversal. Authoritative clean combat budgets are [60, 80, 95, 45, 110] seconds (390 seconds total), targets pending chart tuning. Traversal and short transitions must keep the full run within the 5–8 minute target; tune chart density and repetition from playtesting rather than padding cutscenes.

## Visual and input grammar
LH/RH/LF/RF mean Mācron's left hand/right hand/left foot/right foot. The player uses one thumb; these are move identities, not actual limb instructions. `LH LH` is two sequential hits, never a chord. A token occupies a beat unless `/` indicates half beats; `—` is a rest. `LH→RF` means required LH tap followed by an optional swipe toward RF; the arrow never adds a required judgment. Camera transitions happen between phrases while each flying cue keeps its own previewed destination. Calls show the challenger then responses show Mācron mirroring them; later patterns can shorten demonstration without removing preview lead. Existing canonical music/chart data determines exact timestamps.

## Shared staging and recovery
Baseline `cam.rear`: Mācron low-center, challenger farther up the converging path. `cam.duel`: modest lateral pan, same rear sprite. `cam.side`: authored side silhouettes on a flat floor strip; transition on a rest with a 0.5–1-beat eased pan/scale. `cam.detail`: brief gesture closeup after judgments, never obscures upcoming notes. `cam.rear` returns before traversal. Reduced motion uses fixed rear/side cuts at phrase boundaries and no zoom.

Every stage progresses through arrival → invitation → demonstration/call → player response → escalation → full-arrangement proof → approval → gate traversal. Music complexity and tempo follow authoritative gameplay state; the animation never independently advances them. On an ordinary failed phrase: sympathetic opponent shrug, Mācron recovery step, music descends one tier on the scheduled boundary, phrase repeats with readable preview. Repeated failure triggers that stage's reset threshold: challenger guides Mācron back along the same path, then looped teaching resumes. No black game-over screen or insulting text. Stage entrance remains its own checkpoint; completed earlier stages are retained. Reset loss escalates by losing more local progress later in the run, not by lengthening an unskippable animation.

## Five-stage beat sheet
| ID | Location / target / clean budget | Entrance, pose and camera | Example call → response | Escalation, style and proof | Acceptance and transition |
|---|---|---|---|---|---|
| G01 | Mansion garden / Mojo / 60s | 4-beat rear walk; lanterns guide eye to gatekeeper's open stopping palm. Mācron antenna tilts; no explanatory card. `cam.rear` | Gatekeeper demonstrates `LH — RH —`; response repeats. Next `LH RH LH/LH —` teaches separated double tap | Feet join: `LF RH RF LH`. Optional `LH→RF` makes robot pivot and shaker-like particle arc. `cam.duel` at tier 2; full mix requires all authored proof phrases | Gatekeeper eyebrow softens, taps own chest then points toward door; rope lifts. Optional brief “OK, you cool”. Four-beat walk through gate; warm bar light fills next scene |
| B01 | Bar / Swag / 80s | Counter-height parallax, bartender slides shaker instead of serving Mācron immediately. `cam.rear`; robot peers around counter edge, emphasizing toy scale | `RH — LH RH`; reply adds predictable `RF — LF —` phrase after teaching | Half-beat hand pair separated in time, foot accents. Optional `RH→LF` produces spin and short keyboard ornament. One authored `cam.side` phrase on clear floor strip; final proof at full mix | Bartender nods, slides festive non-specific drink on small saucer, opens counter-end route. Robot takes one proud step; pan follows crowd circle beyond |
| C01 | Cool crowd / Flow / 95s | Three dancer silhouettes make a closed semicircle. Lead dancer jacket sweep invites challenge; Mācron mirrors posture. `cam.rear` | `LF LH RF RH`; call and response visibly alternate arm/foot emphasis | Rhythmic rests and syncopation become recognizable, not random notes. Optional `LF→RH` adds slide. `cam.side` on alternating full phrases; crowd bounces without competing with cues. Full-tier proof shows crowd already mirroring robot | Circle opens into corridor, lead dancer repeats Mācron's signature step. Closeup nod for two beats, then rear walk toward restroom pictogram |
| R01 | Restroom dash / Nerve / 45s | Corridor is short; distant restroom pictogram and attendant key establish urgency. Robot politely shifts weight, not pain/humiliation. `cam.rear` | `LH RH — RF`; answer `LH/RH LF — —` teaches short fast phrase with breathing room | Faster music, fewer total phrases; preserve readable 2-beat cue lead. Optional `RF→LH` is a tiny swivel, not a time-consuming stunt. Avoid zoom while shortest notes resolve. Full mix proof remains mandatory | Attendant twirls key and steps aside; door opens, tasteful wipe past door, relieved robot bounce. No restroom interior imagery. Bass pickup pulls toward VIP stair |
| V01 | VIP / Presence / 110s | Rope, lounge height and seated pink Tlatoāni in distance make status clear. Elegant host sash frames gate, robot stands poised. `cam.rear` | Motif recall `LH RH LF RF`, then `LH/LH — RH RF`; readable call previews despite longest phrases | Combine prior motifs with rests and optional linked swipes. Side camera reserved for one rehearsed phrase; final proof returns rear with full layered music. Continuous misses can clear all current VIP progress, making reset meaningful while previous levels remain safe | Host gives restrained bow, lifts velvet rope; final judgment locks timer and result. Robot walks to Tlatoāni; ending E01–E05 follows |

## Stage reset shots
| ID | Trigger | Visual reset | Lost local progress / visual intent |
|---|---|---|---|
| G.reset | stage-1 repeated-failure threshold | 2-beat backward shuffle, doorkeeper encouraging demonstration | Small early setback, quick invitation back |
| B.reset | stage-2 threshold | Counter slide/pan returns robot to bar approach, 2 beats | More current-stage phrases lost; bartender calmly restarts shaker motif |
| C.reset | stage-3 threshold | Crowd closes and robot shuffles to outside, 2 beats | Current crowd progress resets; circle remains welcoming |
| R.reset | stage-4 threshold | Attendant points back to corridor marker, 2 beats | Short entire stage retries quickly; speed supplies challenge |
| V.reset | stage-5 threshold | Rope gently closes; rear track returns to VIP approach, 2 beats | All VIP phrase progress lost; strongest local reset, no prior stage loss |

Reset thresholds, proof counts and exact retained tiers belong to combat specs/config. This storyboard must not silently invent competing tuning values.

## Ending: 4–6 seconds, timer stopped
| Shot | Duration | Camera and action | Assets |
|---|---|---|---|
| E01 | 1s | VIP host moves aside; push toward lounge. Tiny Mācron approaches seated Tlatoāni | `vip.rope.open`, `macron.walk.rear`, `tlatoani.seated.idle`, `vip.lounge.back` |
| E02 | 1s | Closeup at robot height: Tlatoāni lowers an open hand; Mācron raises modular right arm | `ending.highfive.reach`, `macron.highfive.reach` |
| E03 | 0.5s | Hands meet on a musical accent, restrained glint; no body scale change | `ending.highfive.contact`, `fx.accept.glint` |
| E04 | 1s | Tlatoāni smiles, exact caption “Chingón”, palm gestures toward adjacent small seat | `tlatoani.invite`, `ending.caption.chingon` (runtime text) |
| E05 | 1–2s | Wide lounge: robot sits beside Tlatoāni; Covi in verified design and crowd celebrate quietly. Dissolve into qualifying arcade initials entry/results | `macron.seated`, `tlatoani.seated.idle`, `covi.seated.verified`, `crowd.lounge.loop` |

Covi is a reserved non-identifying silhouette until a verified identity reference is supplied. Ending skip moves to results; completion/result write is idempotent and does not depend on finishing animation. Text belongs in UI, never baked into art.

## Garden asset handoff
| Asset ID | File / state | Usage |
|---|---|---|
| `garden.background.base` | `assets/art/garden/garden-mansion.png` generated source, 1024×1536 RGB, inspected | Single portrait background; contains no HUD or characters. Parent may add procedural foreground/parallax overlay |
| `garden.gatekeeper.source` | `assets/art/garden/gatekeeper.png` generated single pose, 1024×1536 RGBA, inspected | Single transparent source pose; additional animation frames remain production work |
| `macron.source.poses` | `assets/art/macron-dance-concepts.png` existing inspected concept | Rear/front poses for cleanup; not uniform grid |
| `ui.move.lh/rh/lf/rf` | `assets/ui/{left_hand,right_hand,left_foot,right_foot}.svg` | Matching note/target vocabulary |

## Next sessions in production order
1. Garden playable: finish clean robot and gatekeeper atlas, demonstrate/call/respond, acceptance, retry and walk transitions; validate on a phone.
2. Bar and crowd: generate backgrounds, challenger sheets and side-view variants; implement Swag/Flow beats with the same input system.
3. Restroom and VIP: short fast sequence, progressively costly local reset, lounge establishing shot; verify total clean run duration.
4. Ending: obtain Covi reference, animate scaled high five and seat invitation; integrate arcade initials/results and reload recovery.
5. Polish: split source environments into genuine parallax layers, final palette pass, motion/contrast/reach testing and asset packaging. Single flattened generated images are starter runtime art, not a claim that parallax production is complete.

## Stage-2 delivered art handoff (2026-10-18)

`bar.background.base` → `assets/art/bar/bar-interior.png` (1024×1536 RGB, generated and visually inspected). `bar.bartender.source` → `assets/art/bar/bartender.png` (1024×1536 RGBA single pose, generated and visually inspected). These fulfill starter scene composition, not the full B01 demonstrate/response/acceptance animation inventory. Source prompts and status are in `assets/art/bar/README.md`.

## Progressive departures and standing ovation

The updated room-by-room social arc and six-part transition structure are in
[play-and-transition-overhaul.md](play-and-transition-overhaul.md). Peak support
precedes varied full-arrangement proof. Approval then yields to a thinning coda,
staggered returns to activity and a few guests clapping Mācron onward. Later
rooms progressively recruit more standing guests; VIP earns the whole-room
standing ovation before the high five. Planned seated/standing contact clips
and doors require authored assets and are not delivered by procedural motion.
