# Session handoff, 2026-11-05

Read this before resuming after the forge restart. Older context is in
`plan/session-handoff-2026-11-03.md`. Work branch: `work/1833-cast`.

## Owner's verdict on the draft wave

"The motion looks good enough, but the artwork is lagging behind." Keep the
poses. The next work is art detail only.

## State

- Gatekeeper's model sheet is accepted: `tool/art/references/gatekeeper/`.
- Draft wave: `art_runs/gatekeeper-v3-20261105a/`, 64 of 64 frames, no failures,
  typically 51.5 s per frame. Pass images are in
  `~/.cache/tillandsias-project/kumbia-art/session-save-20261104/gatekeeper-v3-20261105a/passes/`
  (63 poses; `groove.down_l` ran earlier and has no folder there).
- Candidate atlas: `assets/art/ensemble/gatekeeper-v3.png` and `.candidate.json`,
  84 frames including 20 aliases.
- The committed manifest still uses v2. `tool/build_local_site.sh` swaps
  candidates listed in `tool/local_preview_candidates.txt` into the built
  manifest. Promotion needs the owner's acceptance.
- Game: https://www.kumbia-kombat.localhost:18443/ and gallery at `/gallery`.
  Reach gameplay in a headless window with CDP `Input.dispatchMouseEvent`:
  synthetic pointer events don't unlock audio.

## What is weak in the draft

Simple face, mustache barely reads at game size, flat shirt and trousers,
embroidery reads as two teal bars, and the guests beside him are much richer.
Likely cause, not yet tested: the plain rig holds back detail.

## Next, in order

1. After relaunch, run one QwenImage workflow with nothing else in flight. Send
   `stages_ms`, `total_ms` and wall time verbatim to macuahuitl-fedora, as it
   asked. Then the Lightning experiment. Ask before pinning the 2509 model.
2. Enrich the rig: full-length embroidered panels with mapped texture, head-only
   mask, eye and nose positions or head rotation in `rig.json`, sleeve and
   jewellery regions, shading and fold hints.
3. Retry Qwen frames now that `FluxKontextMultiReferenceLatentMethod` is pinned,
   and compare them with the multi-pass frames.
4. Run a 12-drawing proof with GIFs for the owner, before any full wave.
5. Full Gatekeeper wave (about an hour), then pack, rebuild, report.
6. Bartender model sheet for acceptance (her 64 jobs are held), then frames.
7. Levels 1 and 2 assembly; merge accepted sets to `game`.

## Loose ends

- `tool/art/references/gatekeeper/rear.provenance.json` still describes the
  sheet's original rear view. `rear.png` is the Qwen repair, seed 940001, from
  `art_runs/gatekeeper-v3-20261105a/rear-repair/`, which has no provenance file
  for that seed. Regenerate or record it; don't guess the values.
- Owner has not answered whether to delete the stale
  `kumbia/frame-multipass.json` from the studio sidebar.
- `art_runs/studio-proof-20261104/raw/` (25 MB) is deliberately uncommitted; a
  copy is in the session-save cache.
- Leftover branch `worktree-agent-a0254df3821b67663` has nothing unique: it sits
  on a `main` commit and its untracked gallery files match this branch.
