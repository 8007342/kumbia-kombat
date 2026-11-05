# Lessons learned: Kumbia Kombat

Written 2026-11-05 for people and agents on sibling projects who know nothing about this one.
Last source commit read: `07cd19d` on `work/1833-cast`, plus the merge that adds this file to `game`.

**What Kumbia is.** A portrait, one-thumb rhythm dance game in Flutter and Flame, on the web, with
synthesised music and pixel-art dancers. Each character needs 64 identity-locked drawings, made by a
local ComfyUI pipeline.

**Terms.** A *forge* is the Tillandsias development container agents work in. The *host* runs the
GPU and the browser windows, and the *tray* is the host's control app. The *studio* is the
project's ComfyUI container. The *lane* is the forge's tool server. The *owner* is the human who
decides. The *host coordinator* is a peer agent that maintains Tillandsias.

**Tags.** `Portable`: applies to any project. `Forge`: any Tillandsias project. `Kumbia`: this game;
copy the idea, not the numbers.

**Evidence.** Shas are on `work/1833-cast` unless a branch is named. The repo is private, so if you
can't read it, the lessons still stand alone. "Inferred" marks this author's reading, not a recorded result. Live problems and
workarounds are in [FORGE_DIAGNOSTICS.md](FORGE_DIAGNOSTICS.md).

## The eight that matter most

1. **Check what actually reached the model, not what the provenance says.** A silent bug sent a
   whole art wave out on the wrong prompt, and we drew false conclusions from it. (A1)
2. **Make tools fail closed.** Every candidate scoring 0.0 looked like success. (A2)
3. **Get the character from a model sheet and the pose from a bare skeleton.** Nothing else held
   both identity and pose. (A3, A4)
4. **Scores rank; eyes and ears approve.** No scorer here has seen an extra arm, and no gate has
   heard a song. (A6, C2)
5. **Prompt and control image must agree,** or the model draws both. (A5)
6. **Test in the environment the player actually uses.** Our test windows hid the real bug. (D1)
7. **Wrap generation in deterministic code.** Rig for pose, finisher for pixels, arranger for form,
   audio clock for time. (A7, B1, C1)
8. **Run a small pilot, and keep outputs where they survive.** (F1, G1)

## A. Asset generation pipeline

**A1. A silent tool bug produced a wrong conclusion.** `Portable` Studio prompt overrides wrote only
`text`, `text_g` and `text_l`, while `TextEncodeQwenImageEditPlus` takes `prompt`. The override was
skipped without error and provenance recorded it anyway (host bug 2001-stpr). All of Gatekeeper's
64-pose wave ran on one old baked prompt. From that the session concluded "the model ignores text" and
"it can't draw two forearms", and committed the second in a message.
*Instead:* confirm inputs at the engine (ComfyUI `/history` shows each node's inputs). Put a marker
string in any override as a cheap test. Workaround: bake one prompt per pose per workflow.
*Evidence:* `art_runs/gatekeeper-v3-20261105q/PROMPTS-NOT-APPLIED.md`,
`art_runs/bartender-v1-20261105q/PROVENANCE-NOTES.md`, `07cd19d`.

**A2. Scorers that fail silently pick at random.** `Portable` An inverted region map scored all 256
candidates 0.0, so picks really came from speck counts, and the run looked fine.
*Instead:* abort on uniform or missing scores, and test that a known-bad candidate ranks last.
*Evidence:* `478d360`, `character-sprite-pipeline` D9.

**A3. The approach that gave stable identity and pose.** `Portable` for the method, `Kumbia` for the
values. Qwen-Image-Edit-2511 with a Lightning 4-step LoRA. `image1` is a model sheet front view and
`image2` an OpenPose skeleton only, scaled 0.8 about bottom centre. 768x960, BiRefNet matte, 4
candidates a pose, about 92 s a pose. Then register to the rig, score, review by eye, finish
without a GPU to a locked palette, and pack the atlas. Registration matters because the figure's
scale and position wander per frame, which reads as jitter.
*Caveat:* the LoRA file is `Qwen-Image-Edit-2509-Lightning-4steps`, built for 2509. The workflow's
own node title says "unproven on 2511". I found no written verdict comparing it with 40 steps.
*Evidence:* `tool/art/pipeline/README.md`, `tool/art/workflows/qwen-frame.api.json`, `250ed53`,
`art_runs/qwen-trials-20261105/`, `art_runs/gk-qwen-20261105a/lightning-compare/`.

**A4. Why the earlier approaches fell short.** `Portable`

| Approach | What went wrong | Evidence |
|---|---|---|
| Prose prompt to one big sheet (v2 art, cloud sheets on `2610-pipe`) | Identity and baseline drift, overlapping cells, a fake pixel grid, no usable pivots | `plan/generative-animation-research.md` §1 |
| SDXL-Lightning, three ControlNets, IP-Adapter, colour-proxy init | Denoise 0.6-0.7 gave flat blobs. 4 steps at 0.85 is really a full repaint, since the schedule is `int(steps/denoise)`. CFG 1 disables negatives | `9992a66`, `plan/comfyui-cheatsheet.md` |
| IP-Adapter tuning | `style and composition` grew a beard and `linear` copied teeth and a thick mustache. Upstream source hides composition at 1.0; the installed copy was not confirmed | `tool/art/studio/README.md`, `plan/research/comfyui-production-2026-11.md` |
| Six-pass SDXL frames on rig masks | Held the look but stayed flat. Consistency came only from pixels composited in, and detail was capped by the base pass. Owner: "The motion looks good enough, but the artwork is lagging behind" | `5f26880`, `plan/session-handoff-2026-11-05.md` |
| Qwen with a clay or colour mannequin | It copied the mannequin's shapes | `250ed53` |

The research doc predicted edit models would suit only sheets and repairs. That was an inference, and
practice overturned it. Inferred caveat on the last row: the trials used a baked prompt asking for
the "proportions of the flat figure", so the mannequin result has not been retested with real prompts.

**A5. When prompt and skeleton disagree, the model tends to draw both.** `Portable` to edit models.
`clap.open` asked for raised forearms over a skeleton with arms down, and all 4 candidates had four
arms. Rewriting the prompt to match fixed it first try. "Her right hand" alone gave wrong-hand
props.
*Instead:* generate prompts from the same pose data as the skeleton. Name the hand by picture side
("the hand on the left side of the picture").
*Evidence:* `art_runs/bartender-v1-20261105q/workflows/clap.open.override-test.api.json`, session
observation 2026-11-05.

**A6. Eye review stays mandatory.** `Portable` The automated scorers can't see extra arms, lost hands,
wrong-hand props, winks or an open collar.
*Instead:* use a contact sheet per clip with the rig skeleton beside the candidates. Our scorer rewrites
`selection.json`, so run it before picking, or it erases your picks.
*Evidence:* `tool/art/pipeline/score_frames.py`, `226d93b`.

**A7. The model supplies raw material; deterministic code makes it pixel art.** `Portable` A locked
palette, binary alpha and a fixed grid come from a GPU-free finisher that gives the same bytes every
time. BiRefNet was chosen over LayerDiffuse, which gave no useful separation, but its soft alpha still
needs cutting. Palette colours must be checked against recolour gates at definition time, since
an outline colour and two palette entries fell inside them by accident.
*Evidence:* `character-sprite-pipeline` tasks 5.5, `6cb9247`, `ca2d24a`.

**A8. Check body build against source art on every wave.** `Portable` The owner found Gatekeeper v3
too skinny against the chubby original. Skeleton and registration pull a character towards rig
proportions. Inferred second cause: the baked prompt that wave ran on asked for the "proportions of
the flat figure" and never said stocky. **Not fixed and not isolated.** Pose scores can't catch this,
because they reward matching the rig.
*Evidence:* `226d93b:tool/art/workflows/qwen-frame.api.json`, `plan/dance-richness-next.md`.

**A9. Make characters data, and key outputs by input hash.** `Portable` Definitions compile to the
family spec (about 2,800 generated lines, never hand-edited). Keys cover only what shows in a frame,
so a hat edit skips frames without a hat. A dry run reports cost before any GPU work. Bartender needed
only a definition file on that route.
*Limits:* at last record, recolour had only run on fixtures and masked mode had never run end to end. The later Qwen
route sits outside this: `plan_qwen_frames.py` keeps per-character prompt text in code, and
`art.py` still targets SDXL (`styles/party-pixel.json`). Reconcile them before relying on either.
*Evidence:* `8389e68`, `c47b21a`, `c7213e3`, `plan/session-handoff-2026-11-03.md` (Known gaps).

## B. Animation and choreography

**B1. The music clock owns all motion.** `Portable` to rhythm games. Sample every clip, route and crowd
reaction from transport beats, never from frame count or a separate timer. Render stalls then can't
drift the dance from the song.
*Evidence:* `plan/dance-fluidity-pass.md`, `plan/input-crowd-research.md`.

**B2. Authored key poses, not interpolation.** `Portable` Each opponent tag mapped to one source
rectangle, so correct chart logic still read as "random poses jumping". Blur, crossfades and optical
flow can't supply anatomy or weight. Use planted support feet, unequal holds, breakdowns, and smears
only on fast arcs.
*Evidence:* `plan/dance-fluidity-pass.md`; `plan/animation-research-register.md` on `2610-pipe`.

**B3. Gameplay data owns timing and difficulty.** `Kumbia` Later rounds get harder through authored
chart motifs, not random motion. Art connects fixed events. Acceptance test: identical input gives
identical score with cinematics on or off.
*Evidence:* `plan/dance-fluidity-pass.md`; `opponent-performance` on `2610-pipe`.

**B4. Key poses on a simple rig and enforce them with a checker.** `Portable` Cumbia is absent from
every licensable mocap set, so poses are hand-keyed in Blender. `check_poses.py` enforces grounding,
limb crossings and wrist clearance. Commission vocabulary research for a real dance culture, and
don't invent step names the sources lack. The skeleton is the only part of the rig that reaches the
model now.
*Evidence:* `f62929a`, `plan/research/gatekeeper-dance-2026-11-02.md`,
`plan/asset-pipeline-requirements.md`.

**B5. Built is not shown.** `Portable` Atlases hold 84 frame ids, but choreography plays a small set,
and the owner saw "only an animation or two". `BattleStaging` exists with tests, yet the scene renderer
still doesn't use it (found on `2610-pipe`; I confirmed it has no reference in `garden_scene.dart`).
*Instead:* after each integration, measure which frames and modules a full run really uses, before
making more.
*Evidence:* `plan/dance-richness-next.md`, `8cc7ac8` (text in the archive).

## C. Music

**C1. A planner writes the brief; code arranges it.** `Portable` idea, unproven result. No model we
checked promises arranged, tiered, loop-safe scores. An agent writes a JSON brief and a deterministic
arranger renders it, so seams, tiers and validity are guaranteed. Models may contribute motifs only.
*Evidence:* `score-composition-pipeline` D1 and `6dd3ecf` on `1834-scor`.

**C2. Measure patterns, but only ears approve.** `Portable` All five shipped scores fail repetition
gates: 83-92% of pitched bars copy or transpose an earlier bar. Thresholds were chosen after seeing
those numbers, so that failure is partly by construction. The `latinIdentity` gate measures that
patterns exist, not authenticity. As of `b34dae7` nobody had listened to the candidates, and the new
voices had not been heard or measured on a phone.
*Evidence:* `plan/research/score-gates-baseline-2026-11-03.md` on `1834-scor`, `ea9069b`.

**C3. Schedule on the audio clock and test with the real data.** `Portable` One absolute clock across
rooms, success phrases and bridges gives gapless handoffs. Integration tests on real scores caught two
floating-point boundary bugs, including zero-duration duplicate notes.
*Evidence:* `plan/session-garden.md`, `plan/music.md`.

## D. Game runtime and web performance

**D1. Test where the player plays; a clean headless run proved nothing.** `Portable` The game paused
itself during play. The cause was `MusicTransport.pump` force-pausing when the queue ran 25 ms overdue.
The trigger was a browser with no WebGL: CanvasKit in software, 120-170 ms frames as measured (a code comment says 120-160), outfit recolours
freezing for about 1 s. The owner's guesses, focus and new art, were ruled out by comparing v2 and v3
and measuring. Headless windows had SwiftShader WebGL, so they looked fine.
*Instead:* reproduce in the player's environment and read `chrome://gpu` first.
*Fix:* a 1.5 s starvation grace that drops late notes, a pump on every frame,
`inactive` no longer pausing, and slow recolours deferred during play.
*Evidence:* `lib/music/transport.dart`, `lib/gameplay/garden_page.dart`,
`lib/gameplay/outfit_palette.dart`; `test/starvation_grace_test.dart`.

**D2. Native pixel tests don't cover the web renderer.** `Portable` to Flutter web. A live fragment
shader and a retained shader picture both passed native tests, then lost crowd sprites in hosted
CanvasKit, across several successive fixes. Final answer: run the shader once while preparing, rasterize
to ordinary images, and keep source art visible on failure. That design later became the software-mode
freeze in D1, so budget it on slow renderers.
*Evidence:* `f621708`, `37b66e3`, `b1f23bc`, `8593c0c`, `plan/wardrobe-rendering-stability.md`.

**D3. Flutter web build traps.** `Portable` to Flutter web. Stock builds fetch CanvasKit and a font from
a CDN, so build with `--no-web-resources-cdn` and bundle the font. Minified release builds hide scene
exceptions: `Bad state: Transport has no audio anchor` appeared only in a debug web build.
*Evidence:* `tool/build.sh`, `plan/diagnostics/forge-diagnostics-2026-10.md`.

**D4. Budget art memory early, and treat the manifest as a contract.** `Kumbia` numbers. Contact sheets
decoded to about 54 MiB, plus about 72 MiB of outfit variants, against a 16 MiB plan. A missing frame id
or a size mismatch fails the whole scene. Image viewers show hidden RGB where alpha is 0, so test
transparency by decoding the PNG.
*Evidence:* `plan/asset-pipeline-requirements.md`, `plan/session-sprites-autoplay.md`.

## E. Testing and verification

**E1. State what a check does not prove.** `Portable` Headless has no speakers, a browser has no thumb,
and an emulator gives no latency evidence. Our best docs say this plainly ("no claim of listening
approval"), which stopped gates being ticked on weak evidence. Physical-phone and listening gates in
`plan/roadmap.md` were still open at last record.

**E2. Build a player for a host with no touchscreen.** `Portable` AutoPlay drives the real session APIs,
fails phrases on purpose and recovers. It tests real judgement paths, and is always labelled as
automatic so it can't pass as a human run.
*Evidence:* `7d50cc0`, `plan/session-sprites-autoplay.md`.

**E3. Audio gates need a real gesture.** `Forge` Synthetic pointer events and `browser.click` did not
unlock audio in headless windows. CDP `Input.dispatchMouseEvent` and a CDP `userGesture` did.
*Evidence:* `plan/session-handoff-2026-11-05.md`; `plan/forge-generic-services.md` on `1835-lvls`.

## F. Forge and host infrastructure

**F1. Assume everything outside git and one volume will vanish.** `Forge` Studio outputs under
`/work/tmp/imagegen` die with the forge, so copy them to `~/.cache/tillandsias-project` during a wave. An
interruption on 2026-10-28 reset a checkout and destroyed an uncommitted 56-drawing pilot.
*Instead:* commit and push small and often; wave commits `76e0a57` to `f15b153` show the pattern.
*Evidence:* `plan/diagnostics/forge-diagnostics-2026-10.md`, `stages.py`.

**F2. Know which restart replaces what.** `Forge` A tray restart doesn't replace a running forge's lane
process, so tool-server fixes need a forge relaunch. This is why the 2001-stpr fix had not taken
effect in our marker test. A token expiry on the git mirror reads "expired or unavailable while
auto-auth re-authenticates", and restarting the mirror fixed it.
*Evidence:* session observation 2026-11-05, `art_runs/bartender-v1-20261105q/PROVENANCE-NOTES.md`.

**F3. Visible browser windows break WebGL.** `Forge` They get `/dev/nvidia*` and `renderD128` but the image
has only Mesa, so the GPU process crashes on llvmpipe and WebGL is disabled (filed as 2001-bwgl). Host
browsers run the game smoothly. The owner has asked for hardware acceleration in future browser
containers.

**F4. Treat refusals as information.** `Forge` Report them verbatim and never relax a guard to progress.
`object_info` is not the allowlist: classes must also be pinned (`node_not_pinned`). Pinned models match
by basename, never Hub path. Overrides reach only `$`-titled nodes, and one node has one title, so
denoise is baked per workflow.
*Evidence:* `plan/comfyui-cheatsheet.md`, `4f529ed`, `plan/forge-generic-services.md` on `1835-lvls`.

**F5. Confirm a landing path before adopting branch rules.** `Forge` Level 2 enforcement refused every
push to `main` while no PR path existed (`gh` unauthenticated, connector 404), so `main` was unreachable
until the operator loosened it to warn. The remedy text still says "refused" in warn mode, so read the
verdict, not the wording. A pre-receive hook also rejected an unquoted ISO date in `.openspec.yaml`, so
quote date-like YAML values.
*Evidence:* `bfe84cf`, `087b186` and `8cc7ac8` (text in the archive).

**F6. Small traps.** `Forge` In zsh, `$B:a` is a path modifier, so write `"${B}:path"`; `$var` doesn't
word-split in `for`; a leading `====` is an error. Read large results through files: screenshots as base64
and 25k-token provenance results flood context. Forges have no route to claude.ai, and peers can't read a
private repo, so paste content into messages.
*Evidence:* `plan/session-handoff-2026-11-03.md`, `plan/forge-generic-services.md` on `1835-lvls`.

## G. Process and collaboration

**G1. Pilot, then one job at a time.** `Portable` A 3-pose pilot before a 64-pose wave caught problems
cheaply, as did a 12-drawing proof and a bake-off of hard poses. For long waves, use one job at a time in a
background agent, plus a looping collector copying to persistent storage. Change one thing at a time when
measuring.
*Evidence:* session observation 2026-11-05, `character-sprite-pipeline` task 5.4.

**G2. The human decides, first-hand.** `Portable` Don't call a score good from numbers or art final from
a contact sheet. A peer's relay isn't approval. Keep promotion behind explicit acceptance: atlases stayed
candidates, swapped into local builds only, until the owner accepted them.
*Evidence:* `plan/session-handoff-2026-11-03.md`, `d7dc67a`.

**G3. Label evidence and write corrections down.** `Portable` The research docs tag each claim as sourced,
observed or inferred, which is what let us see which conclusions to drop. Commit messages can't be edited
once pushed, so a marker file beside the bad data is what warns the next reader.
*Evidence:* `plan/research/comfyui-production-2026-11.md`, `PROMPTS-NOT-APPLIED.md`.

**G4. Land knowledge separately from code.** `Portable` Docs sat on unmerged branches, and parallel work
stacked on each other, including two `dynamic-music` deltas for one rule. Docs in `work/*` are invisible
to anyone reading the integration branch.
*Evidence:* the table below, `plan/session-handoff-2026-11-03.md`.

## Corrections to earlier records

| Record | What it says | What is true |
|---|---|---|
| `226d93b` message | Qwen "won't draw two forearms" | Wrong: the prompts never arrived. With real prompts it draws two hands meeting |
| `art_runs/gatekeeper-v3-20261105q/` `jobs.json`, sidecars | Per-pose prompts | Never ran; all frames used one baked prompt |
| Bartender job `st-1793899634208-161` provenance | Prompt ending `OVERRIDE-TEST-MARKER.` | False, by `/history` |
| `art_runs/qwen-trials-20261105/` provenance | Trial prompts | Inferred false, by the same bug: `qwen-frame-lightning.api.json` holds a different baked prompt |
| `plan/comfyui-cheatsheet.md` | "No edit-model class has run"; native frame 96x120; a 2511 Lightning file | All out of date. Trust `qwen-frame.api.json` and the family spec (256x320, `pixelScale` 3) |
| `plan/research/comfyui-production-2026-11.md`, `comfyui-studio-pipeline` D9 | Edit models not for the default frame path | Inference, overtaken by `250ed53` |
| `tool/art/studio/README.md` | `frame-from-sheet` fails; the Flux reference node is refused | The node now runs in `qwen-frame.api.json` |
| `.claude/skills/art-family/SKILL.md` | The SDXL route as the way to make frames | Doesn't mention Qwen, so don't follow it for new frames |
| `character-sprite-pipeline` task 5.4 | Owner chose SDXL base | True that day; the frames the owner accepted on 2026-11-05 are Qwen |
| Archive: PATH and hook items, `dart` 3.12 | Broken | Checked today: `tillandsias-plan` on PATH, Dart 3.13.5, `core.hooksPath` set to `.git/hooks` |
| Archive: `main` is refused | Enforced | Warn mode since `bfe84cf`; trust `.tillandsias/branch-discipline.yaml` and `087b186` |
| `README.md`, "Current prototype" | Starter single poses, code-native Mācron | Out of date since `47f7443`. Left for its owner, per this task's scope |

## Unmerged branches

These stay on the remote. Their research docs named as copied below are also in this merge, verbatim. "Dry run" is `git merge-tree` against `07cd19d` with its objects kept outside
the repo; it ignores uncommitted work. Whether to land code is my judgement, for the owner to decide.

| Branch, tip | Not in this branch | Knowledge held | Code worth landing? |
|---|---|---|---|
| `work/2610-pipe`, `8cc7ac8` | 6 commits | `plan/animation-research-register.md` (sources, how each applies, its limits; copied here), `plan/sprite-generation-pipeline.md` (readiness gates; mostly superseded), `opponent-performance` OpenSpec change, session diagnostics (now in the archive) | Partly. `b4eaf8f` (room cooling after repeated failures) is small and absent here, but no tests ran that session and its 0.025 is a tuning guess. Land the spec. Skip the two cloud PNGs: never wired in, and superseded. Dry run: conflict in `plan/README.md` only |
| `work/1834-scor`, `b34dae7` | 6 commits | Arranger, complexity gates, score baseline (`plan/research/score-gates-baseline-2026-11-03.md`, copied here), Latin measures, briefs | Yes as tooling: it builds to a gitignored path and leaves shipped scores unchanged. Candidates still need listening (task 4.1). Dry run: clean |
| `work/1835-lvls`, `e9b1448` | 3 commits | `plan/forge-generic-services.md` (the best single doc for another forge project; copied here), `level-production-pipeline`, `plan/level-3-readiness.md` (copied here), host decisions | Docs only: land the OpenSpec change. Some statements are dated, such as "nothing has run on full-step". Reconcile its `dynamic-music` delta with 1834's. Dry run: clean |
| `work/1829-danc`, `087b186` | 1 commit | Why the direct push to `main` was allowed (now in the archive) | No code. Nothing left to land |
| `work/1831-pdoc`, `ffbbb33`; `origin/game`, `cf81edc` | 1 and 2 commits | The same three pipeline docs, minus 14 log lines this branch has | No. Keep this branch's copy of `asset-pipeline-requirements.md`; dry run shows add/add conflicts |
| `origin/main`, `caacc6b` | 1 merge commit | Same tree as `e045f16`, already here | No |

Nothing is ahead of this branch on `work/1824-kumb`, `1825-gard`, `1826-time`, `1827-publ`, `1828-anim`,
`1830-pipe`, `1832-gk64` or `kumbia-foundation`.

## What I could not determine

- Whether a current build fixes 2001-stpr. The marker test is still to be re-run after a relaunch.
- Whether the 2509 Lightning LoRA harms quality on 2511, and whether mannequin copying survives real prompts.
- Why Gatekeeper came out thin: rig, registration or the baked prompt.
- Whether anyone has listened to the candidate scores since 2026-11-03, or how the phone playtest behind `caacc6b` went.
- Host issue details. The Tillandsias repo and its 2001-* rows weren't readable from here. A1 (bug
  mechanism), A5, A8, D1, F2, F3 and G1 rest partly on the session lead's first-hand report. That includes
  the 92 s figure and the 3-pose pilot, which have no file of their own.
- macron.dev itself. All I saw is that it hosts the character canon (`plan/assets.md`), so applicability
  to it is untested.
