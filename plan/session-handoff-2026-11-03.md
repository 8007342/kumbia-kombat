# Session handoff, 2026-11-03: asset pipelines before the tray restart

Read this first after the restart. The owner (the operator) is the human; the peer
session `macuahuitl-fedora` is the host coordinator (see `/list-agents`). Our repo is
private, so paste content into messages to peers. Forges have no route to claude.ai.

## Goal

Make all characters dance through parameterizable pipelines: "add a red hat to
character X" runs its pipeline and updates every necessary frame and shot; one prompt
per level drives character, room, score, chart and shots. These are pathfinding for
generic forge services, which macuahuitl-fedora generalizes for other projects.

## Branches (all pushed; nothing merged into `game` yet)

| Branch | Holds | State |
|---|---|---|
| `work/1833-cast` | Character pipeline, based on `work/1832-gk64`. Also holds this file and the proposals for `cinematic-shot-pipeline` and `score-composition-pipeline` | Tasks 1–4 and 7.1 done |
| `work/1834-scor` | Music: gates, arranger, voices, Garden and Bar briefs. Branched from 1833-cast | Implementation for 1.x, 2.x, 3.1, 4.2 done; 4.1 waits on listening |
| `work/1835-lvls` | `level-production-pipeline`, `plan/level-3-readiness.md`, `plan/forge-generic-services.md`. Branched from an earlier 1833-cast | Design only; 1833-cast has moved on since |

**Merge note:** 1834 and 1835 each add a `dynamic-music` delta for the same rule;
reconcile them when merging. `dynamic-music`'s Purpose still says "synth cumbia" and
needs a direct edit to the main spec, and `assets/music/README.md` is out of date too.

## Resume steps

```bash
git fetch origin && git switch work/1833-cast
export UV_NATIVE_TLS=1
uv venv ~/.cache/kumbia-art && VIRTUAL_ENV=~/.cache/kumbia-art uv pip install pillow numpy jsonschema
uv python install 3.13 && uv venv --python 3.13 ~/.cache/kumbia-bpy
VIRTUAL_ENV=~/.cache/kumbia-bpy uv pip install bpy==5.2.3 pillow numpy
~/.cache/kumbia-art/bin/python -m unittest discover -s tool/art/tests   # expect 98 OK, 7 skipped
```

Only `~/.cache/tillandsias-project` is confirmed to survive restarts, so check whether
those venvs are still there before rebuilding. The art cache defaults to
`~/.cache/tillandsias-project/kumbia-art`. `/work/tmp/imagegen/` is wiped at teardown.

Then:

1. **`studio.start {}`** once macuahuitl-fedora pings. Report the result verbatim to
   it. Also report whether `/work/tmp/imagegen/studio` is writable from a real run
   **without** the old ACL stopgap (it asked; do not recreate the stopgap first).
2. **Model pins** (#903) land after #902, then 13 files (about 102 GB) are pre-fetched;
   it will ping. Basenames are in `plan/forge-generic-services.md` on 1835. The
   backends `sdxl-base-1` and `animagine-xl4` already name them; their settings are
   untested starting points.
3. **Republish the listening page** if the owner still wants it (recipe below).
4. **Continue tasks in order:** `openspec/changes/character-sprite-pipeline/tasks.md`,
   from 5.1.

## Immediate next tasks

- 5.1 confirm pins; one-image run per backend.
- 5.2 generate workflows per backend × profile. `build_workflows.py` does not read
  `tool/art/backends/` yet, so this is real work, and Lightning's denoise must become a
  true partial denoise (`int(steps/denoise)` truncates, so 4 steps at 0.85 is a full repaint).
- 5.3 test `attn_mask`: bind the mask with `LoadImageMask` (or `LoadImage` plus
  `ImageToMask`) into `IPAdapterAdvanced.attn_mask`; macuahuitl-fedora says no new
  class row is needed. Fallback in design D7.
- 5.4 three-pose bake-off (`left_hand.peak`, `groove.down_l`, `finish_turn.turn_in`);
  5.5 BiRefNet vs LayerDiffuse. #881 should make BiRefNet usable; verify.
- 6.x Gatekeeper model sheet, 12-drawing proof with GIFs at game size, then all 64.
- 7.4 Bartender generation; her 64 jobs are held in
  `art_runs/bartender-v1-8f1f71d942/jobs.held.json` until her model sheet is accepted.
- 8.x red-hat tests. **Masked mode has never run end to end**; 8.2 is its first real test.
- Then `cinematic-shot-pipeline` (pilot `bar.outro`), which is proposed and not started.

## Owner decisions on record

- Music is free to change but **dominantly Latin**, with hints of other styles.
- Level music follows the character: Gatekeeper reads salsa, Bartender electronic/synth.
  "Digital cumbia" for the Bar is our own label, so confirm it.
- Level 4: chill country backdrop building into heavy metal, over a Latin base. Future.
- Current focus is levels 1 and 2. Level 3: only prepare, using `plan/level-3-readiness.md`.
- Art style is not fixed; no earlier sheet (including `gatekeeper-v2.png`) is a target.
- Bartender: fully buttoned, fully clothed adult professional who dances superbly.
  Defeated, she pours a glass of motor oil; Mācron gulps it comically and relatably.
- Opponent replay variants are palette-only for now; hats, gloves, chains and coats
  come in a later pass, so pipelines must keep that open.
- Models approved by the owner: SDXL base 1.0, Animagine XL 4.0, Qwen-Image-Edit-2511,
  FLUX.2-klein-4B, Wan2.2-VACE-Fun, ACE-Step 1.5 XL, Anticipatory Music Transformer,
  Text2midi. Basic Pitch and Demucs are not yet approved by the host.
- LoRA training: wait for the proof clips before requesting a trainer.

## Open questions for the owner

Unanswered when this was written. Ask again rather than assuming.

1. Candidate scores: keep, change or redo? Nobody has listened yet.
2. Bartender's apron: A `#7A3057` (applied, provisional), B `#762D51` (recommended,
   nearest with a safe ramp), C `#511837` (from source art, much darker), D keep
   `#7A1F57` and let outfit tinting reach it. Trousers are fine.
3. Bartender's silhouette (review: https://claude.ai/artifact/DqsxZ5ka25XYDgB5TD17bg).
4. Gatekeeper's poses stay cumbia for this run while his music goes salsa-led? We recommend yes.
5. Promotion rule proposed by macuahuitl-fedora: a piece becomes a host tool when a
   second project needs it, and the owner decides.
6. For level 3, later: Mācron's signature step, jacket over a guayabera or instead of
   one, disco reflections, number of dancers.

## Host state and co-design

- **Studio:** blocked. #902 fixes the hardening refusal but the running tray predates
  it. The error `spawn image ensure helper: No such file or directory` came from the
  old tray, whose binary was replaced under it (macuahuitl-fedora's diagnosis), so #902
  is still untested. macuahuitl-fedora filed that as a bug.
- **ComfyUI browser route:** approved by the owner; lenovinha builds it after the
  SaveVideo row and confirms once more with the owner.
- **Music engine:** yoga's row. ACE-Step, AMT and Text2midi wait on it. Text2midi's
  pickle must be converted and never loaded directly.
- **Host rows being filed:** node-ID overrides `$node:<id>.<input>`, provenance/v1 with
  parents, basename-collision refusal, `tillandsias-cache` and `tillandsias-impact` CLIs
  in the forge image, `review.publish` over `preview.*`.
- **Stays in Kumbia:** character and level definitions, rig, motion sets, music brief and arranger.
- **Review delivery:** forges can't publish Artifacts. Put files in
  `/work/tmp/imagegen/kumbia/review/<name>/` and ask macuahuitl-fedora to publish.

## Known gaps

- `art.py`: masked jobs and the finish queue have no real end-to-end run. Only the
  recolour and full paths ran, on fixtures.
- Masked workflow bakes denoise at 0.75 until node-ID overrides land.
- Rig changes went beyond the plan: human `orthoScale` 2.5 to 2.6, trouser hems above
  the ankle, thicker thighs and shins. The owner has not reviewed Gatekeeper's new
  `art_runs/inputs/gatekeeper-v3/contact.png`.
- `assets/art/ensemble/gatekeeper-v3.png` and its candidate JSON still hold the old run.
  `art_runs/inputs/macron-pilot/` is stale. Run `gatekeeper-v3-20261103a` is the baseline.
- New synth voices `montunoKeys`, `synthLead` and `synthArp` have not been heard or
  measured, and phone CPU cost is unmeasured for all new voices.
- The Bar candidate is 244 KB against a 250 KB budget.
- `latinIdentity` measures note patterns, not authenticity. Gate thresholds were chosen
  after seeing the shipped scores, so those failures are partly by construction.
- `character-sprite-pipeline` tasks 4.1 to 4.10 are verified module by module. 4.11 chains them.
- `design.md` of `cinematic-shot-pipeline` budgets `bar.outro` at 6.5 beats; the check
  against the real bridge length has not run.

## Listening page recipe

`build/` is gitignored and lost at teardown.

```bash
git switch work/1834-scor     # or use a worktree
node tool/music/compose/build_candidate.mjs tool/music/briefs/garden_mojo.json
node tool/music/compose/build_candidate.mjs tool/music/briefs/bar_swag.json
node tool/music/build_preview.mjs
# Copy build/music-preview/{index.html,main.js} into build/listen/{shipped,garden,bar}/.
# Copy assets: shipped from build/music-preview/assets, garden and bar from
# build/music-candidates/<id>/assets. Add a small build/listen/index.html linking all three.
```

Then `preview.publish {category:"WEB", app_dir:"build/listen", runtime:"static"}` and
`browser.open {url:"https://www.kumbia-kombat.localhost:18443", headless:false, dev:true}`.
Audio needs a real user gesture.

## Pitfalls

- zsh: `$B:a`, `$B:t` and similar are history modifiers, so write `"${B}:path"`. `$var`
  does not word-split in `for`. `====` at the start of a word is an expansion error.
- The Bash policy hook refuses `rm` on a variable path; name literal paths.
- Stop processes with `pgrep` and `kill <PID>`, never `pkill -f`.
- Palette and region colours must fail the outfit gates unless a region is declared recolourable.
- Never relax a guard or gate to make progress: report refusals verbatim to macuahuitl-fedora.
- A peer's relay isn't first-hand owner approval: macuahuitl-fedora asks the owner directly.
- Don't call a score good from the numbers, or art final from a contact sheet. The owner decides.
