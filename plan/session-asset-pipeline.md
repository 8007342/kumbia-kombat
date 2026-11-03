# Session record: generative asset pipeline (2026-11-01/02)

Handoff for resuming after a forge restart. Requirements, inventory and
research are on `game` (`plan/asset-pipeline-requirements.md`,
`plan/asset-inventory-contract.md`, `plan/generative-animation-research.md`).
The rig, family spec and control images are on `work/1830-pipe` (partial work,
not yet merged by owner policy).

## Delivered

- `work/1830-pipe`: `tool/art/families/gatekeeper-v3.json` (contract
  `1935-k2ib/v0` example), `tool/art/rig/` (Blender stand-in rig, see its
  README for bpy setup), `art_runs/inputs/gatekeeper-v3/` (64 poses) and
  `art_runs/inputs/macron-pilot/` (54 poses): pose, depth, regions, lineart,
  rig.json, contact sheets, clip GIFs.
- `game` @ `cf81edc`: the three docs above, via `work/1831-pdoc`.

## Owner decisions (2026-11-01)

Per-room native pixel size; rooms may differ in perspective, level 4 is the
side-on candidate; hand-keyed Blender stand-ins for motion; mature work merges
into `game`, partial work stays on `work/*`.

## Peers and where their work lives

| Peer session | Role | Durable location |
|---|---|---|
| macuahuitl-fedora | Tillandsias coordinator | Tillandsias repo |
| calmecacpilli-silverblue | owns design row `1935-k2ib` | Tillandsias `work/1935-k2ib` @ `84236b088` (contract v0 file `plan/issues/comfyui-studio-family-contract-v0-2026-11-01.md`), revision `4c7f51c1a` |
| demon_attack-forge | project-local pipeline (process/QA/pack) | github `8007342/demon_attack` branch `research/local-image-large-models`: `tools/asset_pipeline/`, `plan/asset-pipeline/{licence-review,shared-contract-notes}.md` |

Our repo `8007342/kumbia-kombat` is **private**: peers cannot read it. Paste
content into messages. Public sibling files are readable via
`raw.githubusercontent.com/8007342/<repo>/<branch>/<path>`.

## Waiting on

1. **Operator sign-off of contract `1935-k2ib/v0`** (calmecacpilli only
   records; sign-off is the operator's). calmecacpilli recommends YES to:
   (a) `palette_fails_all_gates` mandatory when `reservedRamps` exist;
   (b) `camera` on `targets[]` with `frame.camera` as family default.
   demon_attack builds character-frame features (regionMask, structured gate
   grammar, baseline/pivot writer, baseline_drift/head_size QA) only after
   sign-off. Relay the sign-off to demon_attack-forge when it lands.
2. **Interim ControlNet test.** Tillandsias `work/1954-gdi6` (control_net +
   control_image + loras on `image.generate`), `1955-rjv3` (queued parallel
   calls) and `1957-pins` @ `15b6f59bc` (xinsir OpenPose SDXL + pixel-art-xl
   admitted) must merge into `linux-next` and reach this forge's build. Check
   the `image.generate` schema shows `control_net` before testing. Then:

   ```
   cp art_runs/inputs/gatekeeper-v3/left_hand.peak.pose.png /work/tmp/imagegen/kumbia-gk-left_hand.peak.pose.png
   image.generate {prompt, tier:"I1", control_net:"openpose",
     control_image:"/work/tmp/imagegen/kumbia-gk-left_hand.peak.pose.png",
     loras:[{name:"pixel-art-xl", weight:0.8}]}
   ```

   SDXL files require tier I1. sd.cpp `master-1015-e41fbcf` documents
   ControlNet for SD1.5 only; if it fails, send the verbatim error to
   calmecacpilli. The SD1.5 route (`lllyasviel/control_v11p_sd15_openpose`,
   plain "openrail") needs an SD1.5 base tier and a code change to accept that
   licence.
3. **ComfyUI studio** (drafts #791/#793/#794, :8188): needed for depth/lineart
   control (Mācron), IP-Adapter identity, LayerDiffuse, region masks.

## Licences

Operator standing approval (2026-11-01, relayed): free models on demon_attack's
`licence-review.md` for own, non-sale projects, including dinov2-small; flagged
rows excluded (FLUX.2-dev / klein-9B, Depth-Anything Base/Large,
lllyasviel/LayerDiffuse_Diffusers, ntc-ai slider). Fetching still goes through
the forge licence register; gated click-through (FLUX.1-schnell) needs the
operator. Never: flux.1-dev, sd3.5, sd/sdxl-turbo, RMBG-1.4/2.0, InsightFace.

## Next steps on our side

- Tune Mācron raised-hand peaks (arm passes behind the head) at review.
- Extract a locked Gatekeeper palette (`tool/art/palettes/gatekeeper.json`)
  from approved v2 frames; demon_attack needs it for real tests.
- Write the Mācron family spec once the pilot is reviewed.
- Side-on camera rig for level 4 once its characters are designed.
- Merge `work/1830-pipe` into `game` after the first generation test shows the
  stand-ins steer the generator.

## Environment notes

- bpy: `UV_NATIVE_TLS=1 uv python install 3.13`, venv at `~/.cache/kumbia-bpy`
  (lost on restart; rebuild per `tool/art/rig/README.md`).
- zsh does not word-split `$var` in `for` loops; call commands explicitly.
- `/work/tmp/imagegen/` is deleted on forge teardown.

## Session 2026-11-02/03: Gatekeeper v3 cumbia re-key and scripted pipeline (`work/1832-gk64`)

Operator decisions: all 64 drawings in one pass; GPU time has standing approval
for this project; prefer the largest admitted models; adopt the research's
pose changes; cite the animation authorities in the specs and prompts.

Delivered:
- Research: `plan/research/gatekeeper-dance-2026-11-02.md`, with cumbia
  vocabulary in part 1 and animation craft plus the SDXL control stack in part 2.
- Rig: hip tilt (`pelvis_roll`), outward knee bends, pinned support ankle,
  foot pitch and stocky proportions. All 64 poses are re-keyed, with prompt
  intents in `poses.intent.json`. `check_poses.py` passes for both characters.
- Pipeline: see `tool/art/pipeline/README.md` and the project skill
  `.claude/skills/art-family/SKILL.md`. The spec is on contract v1 and passes
  the schema; it has a locked palette and garden native size 96x120 at x8
  (my choice, for the owner to confirm). Workflows live in
  `tool/art/workflows/`, and model names were confirmed by macuahuitl-fedora.
- Animation references: `tool/art/references/animation-principles.json`. The
  spec's `animationReferences` and each pose's `animationPrinciples` cite it.
- The planned run `art_runs/gatekeeper-v3-20261103a/jobs.json` has 64 jobs
  with 4 candidates each.

Resume after restart:
1. Rebuild the virtual environments: `~/.cache/kumbia-art` (pillow numpy
   jsonschema) and `~/.cache/kumbia-bpy` (see `tool/art/rig/README.md`).
2. Re-stage the inputs, because `/work/tmp` is wiped:
   `plan_jobs.py tool/art/families/gatekeeper-v3.json --run gatekeeper-v3-20261103a`
3. Run `studio.validate_family`, then one `studio.run_workflow` for
   `left_hand.peak`. Check the model names against `/object_info` and report
   any refusals verbatim to macuahuitl-fedora. Then run all 64 jobs, then
   `collect.py`, contact sheets, selection, `finish_pixels`, `pack_atlas.py`,
   and a review gallery artifact.

Infrastructure state:
- Calling `image.generate` with `control_net` or `loras` panicked the
  host-services MCP (Tillandsias P0). Avoid both until the fix lands.
- The studio container `tillandsias-kumbia-kombat-studio` has no HTTP route
  from the forge, so it is reachable through the MCP only.
- Host services 56.11.3.1 (studio fixes, #875) needs the operator's tray to
  restart.
- Music: Tillandsias PR #874 shortlists ACE-Step 1.5 XL, the Anticipatory
  Music Transformer and Text2midi, pending licence approval. Our needs were
  sent: cumbia at 112-144 BPM, an exact bar grid, and intensity stems.

## Session 2026-11-03 (resume)

- Palette nudged out of the outfit recolor gates (`extract_palette.py
  --avoid-gates`); `studio.validate_family` → `ok:family:gatekeeper-v3`.
- `studio.run_workflow` returned `studio_unavailable`: the tray exit had torn
  the studio down. macuahuitl-fedora restarted it from the host
  (`tillandsias --cloud 8007342/kumbia-kombat --studio comfyui`). Operator
  ruling: studios are on-demand appliances, never auto-started at forge launch
  (start-from-tool is order 1969-cfyt), so do NOT add `[imagegen] studio = true`
  to `.tillandsias/config.toml`; the error text suggesting it is stale (#873).
  If the studio is down, ask macuahuitl-fedora to restart it.
- The ComfyUI web UI is not reachable from the forge (`browser.open` allows only
  the https preview URL; no HTTP route to :8188), so review happens through
  contact sheets and an Artifact gallery.
- After relaunch: rebuild `~/.cache/kumbia-art`, re-run `plan_jobs.py`, then
  run `left_hand.peak` first.

## Run gatekeeper-v3-20261103a (2026-11-03): all 64 drawings generated

- Studio (re)started by macuahuitl-fedora with
  `tillandsias --cloud 8007342/kumbia-kombat --studio comfyui`. Host bugs, now with
  lenovinha (studio.start, order 1969-cfyt): the output dir is not pre-created
  for the forge uid (stopgap: `mkdir /work/tmp/imagegen/studio`, chmod 0777 and a
  default ACL set via `os.setxattr('system.posix_acl_default', …)`); BiRefNet is
  pinned but never fetched (the validator misses LoadRembgByBiRefNetModel.model);
  run_workflow returns only one SaveImage node's outputs.
  Fixed in #881 on linux-next (7b9fcf50f): image.generate ControlNet panic +
  per-call panic guard, BiRefNet `model` fetched, one prefix per SaveImage node.
  Not live until the operator's next tray rebuild/restart (fedora will say);
  keep the stopgaps until then, then retry BiRefNet and drop the ACL stopgap.
- Pinned models match the file basename (or `<tier>/<basename>`), never the Hub path.
- Workflow: denoise 0.85 on every profile (0.6–0.7 let the colour proxy win:
  flat blobs), one SaveImage, matte keyed locally (`tool/art/pipeline/matte.py`).
- 64 jobs × 4 candidates ran through 8 subagents (each result is ~25k tokens of
  provenance; `collect.py --from-disk` rebuilds results from the sidecars).
- `prep_finish.py` mattes + scores, `suggest.py` picks by identity (hat/shirt
  colour vs rig regions) and matte debris, `review_sheets.py` draws per-clip sheets.
- Selection = suggestion (first pass, owner to correct). 64 frames finished,
  packed to `assets/art/ensemble/gatekeeper-v3.png` + `.candidate.json` (status
  candidate; not promoted). Review gallery: https://claude.ai/artifact/CLHiM7owAHX21esVpgbkKJ
- Raw candidates (139 MB) stay on disk under `art_runs/<run>/raw/` (gitignored).
- Next: owner corrections → re-finish → re-pack → promote; outline enforcement;
  BiRefNet once fixed.
