# Studio workflows

Character workflows you can open, read and edit in the ComfyUI studio, kept in the repo so they
survive it. Studio: `https://comfyui.kumbia-kombat.localhost:18443/` (from the forge,
`http://studio:8188`).

| Workflow, in `tool/art/workflows/studio/` | What it does |
|---|---|
| `frame-multipass` | One frame in six passes: base, shirt, embroidery, hat, head, matte. Each pass saves its own output |
| `model-sheet` | Front, 3/4 and rear reference for the owner's acceptance |
| `parts-from-frame` | Cuts a frame into head, hat, shirt, arms and legs as RGBA layers on the rig masks |
| `frame-from-sheet` | Experiment: draw the sheet's man in a rig pose. It fails today, see below |

`<name>.json` is the source: it's what you open in the studio. `<name>.api.json` is generated from
it for `studio.run_workflow`, so never edit one by hand. `frame-multipass` also writes
`.peak`, `.overlap` and `.turn` API files, from `extra.kumbia.variants` in the same source.

## Edit in the studio

```bash
PY=~/.cache/kumbia-art/bin/python
$PY tool/art/studio/sync_studio.py push            # puts workflows and sample inputs in the sidebar
```

1. Open a `kumbia-*` workflow from the sidebar and press Run. It runs as saved on sample inputs for
   `groove.down_l`.
2. Change what you like and press Save. Keep titles that start with `$`: they're how a headless run
   binds its seed, prompt and images.
3. To try another pose, stage it and pick its files in the `$` Load Image nodes:

```bash
$PY tool/art/pipeline/plan_jobs.py tool/art/families/gatekeeper-v3.json --run <run> --only <poses> --count 2
$PY tool/art/studio/stage_parts.py --run <run> --only <poses>
$PY tool/art/studio/sync_studio.py inputs --dir /work/tmp/imagegen/kumbia/<run>/in --pose <pose>
```

## Bring edits back

```bash
$PY tool/art/studio/sync_studio.py status          # exit 1 if edits are waiting
$PY tool/art/studio/sync_studio.py diff <name>     # what changed, node by node
$PY tool/art/studio/sync_studio.py pull <name>     # writes the source and its API files; see them with git diff
```

`push` refuses to overwrite a workflow changed in the studio. Pull it, or discard the edit with
`push --force`. If the repo changed too, `pull` writes `<name>.studio.json` beside the source and
leaves the source alone, to merge by hand.

The repo is the source of truth, so after a rebuilt studio `push` restores everything. Saving with
no edit doesn't count as a change, but moving a node does. `sync_state.json` records the last
synced version of each workflow: commit it with them.

## Convert

```bash
$PY tool/art/studio/ui_to_api.py                   # regenerate the API files
$PY tool/art/studio/ui_to_api.py --check           # exit 1 if any is stale
$PY tool/art/studio/ui_to_api.py --refresh-schemas # after adding a node class; needs the studio
```

Conversion reads `node_schemas.json`, a snapshot of the classes in use, so it works offline. A
Load Image titled `$name` gets the image `$name` in the API file. Everything else matches
`app.graphToPrompt()`, as recorded in `recorded/` and checked by `tool/art/tests/test_studio.py`.
To re-record after a frontend upgrade, load each workflow in a browser and save that call's output.

Keep sources flat. The converter refuses subgraphs by name. The frontend itself flattens them to ids
like `11:1` and keeps `$` titles (tested once), so they could be added later.

## Run headlessly

Use `studio.run_workflow` with these arguments, then copy outputs to `art_runs/`, since
`/work/tmp/imagegen/` is wiped at teardown. `D` is the staged folder and `P` the pose.

```
workflow    tool/art/workflows/studio/frame-multipass.api.json     (or .peak.api.json, by the pose's profile)
tier        I1
count       2                                                      seeds run seed, seed+1
init_image  D/P.proxy.png
overrides   seed, prompt, negative_prompt                          from the run's jobs.json
inputs      pose depth lineart        D/P.<name>.png
            ref_head ref_outfit       D/<name>.png
            mask_head                 D/P.mask.face.png
            mask_hat mask_shirt mask_figure mask_embroidery mask_ref_head mask_ref_body   D/P.mask.<...>.png
            face embroidery           D/P.<name>.png
            head_xy torso_xy          D/P.headxy.png, D/P.torsoxy.png
```

- `run_workflow` returns every save node's output, named by node id: 34 base, 113 shirt, 521
  embroidery, 213 hat, 334 head at working size, 342 head pass, 402 matte.
- All samplers are titled `$seed`, and the override reaches every one of them.
- Every input must be bound. A Load Image left in the graph with no binding is refused.
- `colourmatch.py` and `studio.finish_pixels` run after the graph, on the matte's alpha.

## Why the graph looks like this

Measured in `art_runs/studio-proof-20261104/`. Values not listed are the cheat sheet's.

| Choice | Evidence |
|---|---|
| Per-pose numbers carried as a blank image's size | No core node reads a box from a mask, and `ComfyMathExpression` is refused |
| IP-Adapter `style transfer` at 0.6, masked, square crops | `ipadapter/ipadapter-ab.png`: `linear` copies teeth and a thick mustache; `style and composition` grows a beard |
| Wipe a region from the rig or a drawn guide, then sample | Sampling at 0.5 can't remove what the base drew; flat skin at 0.8 loses the face on a tilted head |
| Shirt and hat at 0.35 after the wipe | At 0.5 stripes break into dots |
| Head at 0.55 from a drawn face | Holds the tilt, with no teeth or beard |
| Embroidery laid as one strip, then 0.3 with tile control | A prompt alone stays plain stripes |
| Pixel LoRA 0.35 in crops | No visible difference between 0, 0.35 and 0.8 at this denoise |
| Masks for parts staged by `stage_parts.py` | Skin covers head and arms, and accessory covers band and stripes, so one colour can't separate them |

## What it doesn't do

- **Detail stays as low as the base pass allows.** At pixel LoRA 0.8 the frame has 8px cells, so
  768x960 isn't more detailed than 256x320 outside the embroidery. LoRA 0.2 removes the cells
  (`detail-variant/`) but gives smooth mannequin shapes, not v2's drawing.
- **Consistency comes from what's composited.** The stitches and the face match across frames
  because they start as the same pixels; the sampler only blends them in.
- **`frame-from-sheet` fails.** Given a flat proxy it returns the proxy; given line art it keeps the
  pose but loses the man. `FluxKontextMultiReferenceLatentMethod`, which the template uses, is refused.
- **Partial assets:** only head-and-hat parts earn their place, in the same bucket of head angle.
  `parts/` has the numbers.
