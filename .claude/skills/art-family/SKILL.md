---
name: art-family
description: Produce or refresh a Kumbia Kombat character sprite family (opponent, audience member, bartender…) end to end through the local ComfyUI studio — character definition, model sheet, Qwen frames, review, pixel finish, atlas. Use when asked to create a new opponent/level character, re-generate a character's dance frames, draw Mācron's clips, or "add a level with <style> opponent / <audience> / <music>".
---

# Character sprite family, end to end

One route: Qwen draws the character from a model sheet, posed by a bare skeleton (or by words, for
Mācron). `tool/art/pipeline/README.md` has the details. Prompts come from data, so never hand-edit a
workflow: fix the definition and re-plan. The operator's standing approval covers local GPU time
for this project (2026-11-02). Partial work stays on a `work/NNNN-xxxx` branch; mature work merges
into `game`.

Below, `PY=~/.cache/kumbia-art/bin/python`, and `<c>` is a character id or a `.json` path.

## 1. Define (no GPU)

Write `tool/art/characters/<id>.json`; copy `tool/art/tests/fixtures/trial-dancer.json`. The prompts live
under `drawing`:

- `noun`, `fits`, `look`, `extra`: identity. **Describe what is there.** Negation backfires: "glasses-free"
  drew glasses. Name the build outright; A8 came from a prompt that didn't.
- `drawing.sheet`: the accepted views, and a `source` to draw missing ones from (`styleOnly` for a new person).
- `props[].clips`: which clips carry a prop. Its hand becomes a picture side in the prompt.
- `drawing.buildReference`: the art the owner has in mind, if any.
- `drawing.score.knee`: what covers the knees, for anyone not in trousers. A swinging skirt also wants
  `silhouetteTolerance`. The rig has no skirt shape yet, so its silhouette only approximates one.
- `pronouns` as stated in the brief; otherwise they/them.

If the style is a real dance culture, commission research first and save it under `plan/research/`.

## 2. Dry run, and read the prompts

```bash
$PY tool/art/pipeline/art.py build <c> --dry-run --prompts
```

It reports jobs, images and minutes. Prompt and skeleton must agree, or the model draws both (A5), so read
a few against `art_runs/inputs/<family>/contact.png`.

## 3. Sheet (GPU), then the owner

```bash
$PY tool/art/pipeline/art.py build <c> --run <family>-<yyyymmdd><a-z>
```

If views are missing, it writes `jobs.sheet.json` and holds frames in `jobs.held.json`. Run the sheet jobs,
show the owner, and only after they approve a view:
`$PY tool/art/pipeline/art.py accept-sheet <c> --view front --image <png>`. Then build again.

## 4. Pilot, then the wave (GPU, MCP)

Pilot a few hard poses first: `build <c> --run <run> --only clap.contact,groove.down_l`. For each entry of
`art_runs/<run>/jobs.json`, call `studio.run_workflow` with its `args` verbatim. About 92 s a pose. Then,
during the wave, since the studio folder doesn't outlive the forge:

```bash
$PY tool/art/pipeline/collect_qwen.py --run <run>
R=~/.cache/tillandsias-project/kumbia-art/<run>
$PY tool/art/pipeline/register_frames.py --run <run> --family <family> --root $R --shirt <rrggbb>
$PY tool/art/pipeline/character_check.py <c> --run <run> --dir $R/registered
```

If frames look unrelated to the prompt, check ComfyUI's `/history` (A1). Keep the check's advisories in
mind: stop and look if the build is off, before spending the rest of the wave.

## 5. Review, finish, pack

- `$PY tool/art/pipeline/score_frames.py --run <run> --family <family> --dir $R/registered --partial` ranks
  candidates. It rewrites `selection.json`, so run it **before** picking. It aborts rather than rank on bad
  data.
- **Look at every candidate**: a contact sheet per clip with the skeleton beside it (`studio.contact_sheet`). No
  scorer has seen an extra arm, a wrong-hand prop or an open collar.
- A pose needs a fix? Put it in `drawing.poseOverrides` (words, with `why`) or `drawing.skeletonOverrides`
  (joints), and `build --only` that pose. Data survives re-planning; edited workflows don't.
- `studio.finish_pixels` each pick into `art_runs/<run>/final/<pose>.png`, then
  `$PY tool/art/pipeline/art.py ingest <c> --run <run>` and `art.py build <c>` to pack.
- Publish a review gallery (Artifact). Promotion into `assets/art/ensemble/manifest.json` needs the owner's
  acceptance.

## Mācron

He has no human skeleton, so a pose is a sheet view plus words (`tool/art/motion/macron-drawn.json`). The
plan is `art_runs/macron-v1-planned/`; re-plan and stage with `art.py build macron --run <run>`. Register with
`register_frames.py --run <run> --character macron --root $R`, and pick from contact sheets: `score_frames.py`
refuses him. `signature_step` is reserved for the salsa teacher's step, so don't invent one. See the README for
what stays unproven.

## Known infrastructure notes

- `image.generate` with `control_net`/`loras` crashed the host-services MCP on 2026-11-02 (Tillandsias P0). Use
  `studio.run_workflow` for controlled frames.
- Prompts are baked per pose because the host's override didn't reach this node (2001-stpr). Pass no prompt
  override, which keeps provenance true.
- The older SDXL route stays selectable with `--backend sdxl-base-1`. Don't use it for new frames.
