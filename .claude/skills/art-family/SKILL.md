---
name: art-family
description: Produce or refresh a Kumbia Kombat character sprite family (opponent, audience member, bartender…) end to end through the local ComfyUI studio — rig poses, family spec, generation, review, pixel finish, atlas. Use when asked to create a new opponent/level character, re-generate a character's dance frames, or "add a level with <style> opponent / <audience> / <music>".
---

# Character sprite family, end to end

Read `tool/art/pipeline/README.md` first: it has the stage diagram. Contract is
Tillandsias `1935-k2ib/v1`; the operator's standing approval covers local GPU
time for this project (2026-11-02). Partial work stays on a `work/NNNN-xxxx`
branch (discipline level 2); mature work merges into `game`.

## 0. Inputs from the request

Pin down, and write into the family spec: character look (`character_prompt`),
room (`targets[].room`, native size per room in `frame.native`), camera
(`floor-perspective` or `side-on`), clip vocabulary (start from
`plan/opponent-depth-staging-pass.md` §Opponent production target), the dance
style, and the identity reference image. If the style is a real dance culture,
commission research first (vocabulary, key poses, cultural-respect notes) and
save it under `plan/research/`; add any new authority to
`tool/art/references/animation-principles.json`.

## 1. Poses (CPU)

- Key the poses in `tool/art/rig/poses.py` (new character: add body dimensions
  and `REGIONS` in `standin.py`), with `poses.intent.json` text per pose.
- Render: `~/.cache/kumbia-bpy/bin/python tool/art/rig/standin.py --character <c> --out art_runs/inputs/<family>`
- `check_poses.py` must pass. Show the user `contact.png` and the clip GIFs.

## 2. Spec (CPU)

- Palette: `tool/art/palettes/extract_palette.py --source <approved art> ...`
- `python3 tool/art/pipeline/sync_family.py tool/art/families/<family>.json`
- MCP `studio.validate_family` until `ok:family:<name>`.

## 3. Generate (GPU, MCP)

- `python3 tool/art/pipeline/plan_jobs.py <spec> --run <family>-<yyyymmdd><a-z>`
- For each entry of `art_runs/<run>/jobs.json`, call `studio.run_workflow`
  with its `args` verbatim; save each result JSON verbatim to
  `art_runs/<run>/results/<pose>.json`. Run a single pose first and look at it.
- `python3 tool/art/pipeline/collect.py --run <run>`
- `studio.contact_sheet` per clip (rows = poses, cols = candidates).

## 4. Review, finish, pack

- Pick one candidate per pose into `art_runs/<run>/selection.json`
  (`{pose: k}`); judge identity, limb call readability, grounding, and the
  animation principles named in the spec's `animationReferences`.
- `studio.finish_pixels` each selected RGBA into `art_runs/<run>/final/<pose>.png`.
- `python3 tool/art/pipeline/pack_atlas.py <spec> --run <run>` → candidate atlas.
- Publish a review gallery (Artifact) of the atlas, clip GIFs and contact
  sheets; promotion into `assets/art/ensemble/manifest.json` needs the
  owner's acceptance.

## Known infrastructure notes

- `image.generate` with `control_net`/`loras` crashed the host-services MCP on
  2026-11-02 (Tillandsias P0). Use `studio.run_workflow` for controlled frames.
- Overrides only reach nodes titled `$seed`, `$prompt`, `$negative_prompt`;
  control strengths are baked per profile (`build_workflows.py`).
- Model file names: `tool/art/workflows/models.json`.
