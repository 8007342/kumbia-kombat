# Generic forge services discovered by Kumbia Kombat

For macuahuitl-fedora and other Tillandsias maintainers. Written 2026-11-03 so that it
makes sense without access to this private repository: all formats needed are inline.
Kumbia is a pixel-art rhythm game that needs hundreds of identity-locked animation
frames, so it hit most of these problems first.

## How to read this

**Interface.** Everything is an MCP tool on the host-services server, reachable from
Claude, OpenCode, Codex and Antigravity forges. Each tool is a call over files: name,
inputs, output paths, a provenance sidecar beside each output, and typed refusals. No
large inline payloads, no image bytes. Proposed tools below are sketches for co-design;
names and fields are yours to change.

**Evidence labels.** `[fact]` was observed or stated by the host owner. `[guess]` is our
inference, or a design that has not run yet. **Nothing below has been run on the
full-step checkpoints, masked workflows or music engine yet.**

**Ownership, agreed with macuahuitl-fedora.**

| Owner | Services |
|---|---|
| Host (generic facility) | 2 stage cache, 3 impact analysis, 1 studio job bindings, 4 review surface, 7 provenance format |
| Host (already building) | 5 music engine |
| Kumbia until a second project needs them; **no tools proposed** | Character and level definitions, rig, motion sets, music brief and arranger, shots |

## Summary of the flow

```
definition edit ─▶ impact analysis ─▶ stage cache lookup ─▶ only missing jobs ─▶ studio run
      ▲                                                                            │
      └── person accepts ◀── review surface ◀── deterministic finish ◀── provenance┘
```

---

## 1. Studio job bindings (image generation)

**Problem.** A project commits ComfyUI API-format workflows and must vary them per job
without editing JSON, with no route to the ComfyUI server.

**Interface today** `[fact]`:

```
studio.start {}                     idempotent; builds on first use; stops with the forge
studio.status {}
studio.validate_family { spec }     -> ok:family:<name> | refused:<check>:<detail> lines
studio.run_workflow { workflow, tier, count, inputs:{name:path}, init_image, mask,
                      layout_mask, strength, overrides:{seed,prompt,negative_prompt}, family, verbose }
                                    -> output paths under /work/tmp/imagegen/studio/<job>/
                                       plus <file>.provenance.json beside each
studio.finish_pixels { input, matte?, family, out, room? }   GPU-free, deterministic
studio.contact_sheet { cells:[{path,row,col}], out, cell_px, family?, title? }
gpu.status {}                       holders, free VRAM
```

Compact results are the default since #895; `verbose=true` opts in. Earlier, each result
carried about 25k tokens of provenance, and forced us to run jobs through subagents.

**Our usage pattern (generic).** One generated workflow per backend × control profile,
because overrides can't reach control strengths or checkpoints:

```jsonc
// backend definition (project data, the pattern is generic)
{ "id": "lightning-4step", "role": "pose-frame", "checkpoint": "sdxl_lightning_4step.safetensors",
  "sampler": { "steps": 4, "cfg": 1.0, "name": "euler", "scheduler": "sgm_uniform" },
  "denoise": 0.85, "loras": [{ "name": "pixel-art-xl.safetensors", "weight": 0.8 }],
  "negatives": "ineffective", "tier": "I1" }
```

A job, as queued:

```jsonc
{ "workflow": "tool/art/workflows/character-frame-moderate.api.json", "tier": "I1", "count": 4,
  "inputs": { "pose": "/work/tmp/imagegen/…/x.pose.png", "depth": "…", "lineart": "…", "identity": "…" },
  "init_image": "…/x.proxy.png",
  "overrides": { "prompt": "…", "negative_prompt": "…", "seed": 930000 } }
```

**Generic vs project.** Generic: bindings, refusals, provenance, the workflow-variant
pattern. Project: the workflows themselves, prompts, control strengths.

**Missing** (from the host):

| Gap | State |
|---|---|
| Node-id overrides `$node:<id>.<input>` alongside titles | Planned `[fact]`. Removes the title limit below |
| Mask bindings for chained `IPAdapterAdvanced` `attn_mask` | Untested `[guess]`: `$name` binds a LoadImage, whose mask output or an image-to-mask core node should reach it |
| Read-only `/object_info` and a ComfyUI UI route | Awaiting operator; see section 4 |
| Admitted classes | Per-pack allowlist in `node-classes.tsv`. `IPAdapterRegionalConditioning` is not admitted `[fact]` |
| Extra packs (KJNodes, Impact, PixelOE) | Not requested: we do colour matching and pixel prep in project Python |
| Upscalers | None pinned `[fact]`. Not needed so far |
| LoRA training | None exists. A trained LoRA would need a pinned row like any model, which is awkward for private projects. Deferred until proof clips say it is needed |

**Pitfalls** `[fact]`, unless marked:

- **Title limit:** overrides reach only nodes titled `$seed`, `$prompt`, `$negative_prompt`,
  and `$strength` sets a KSampler's denoise. A node has one title, so a KSampler cannot be both
  `$seed` and `$strength`. We bake denoise per workflow until node-id overrides arrive.
- **SaveImage:** `run_workflow` returned only one SaveImage node's outputs. #881 gives each
  node its own prefix; live only after a tray relaunch. Our workflows still keep one.
- **Basenames:** pinned models match file basename or `<tier>/<basename>`, never the Hub path.
- **Same basename across roots:** `model.safetensors` and `diffusion_pytorch_model.safetensors`
  recur, so name collisions are a hazard. Worth a clear refusal `[guess]`.
- **Refusals before queueing:** `node_not_pinned`, `model_refused`, `workflow_has_no_input:<name>`.
  Report them verbatim.
- **Hardening guard:** `studio.start` refused with `launch argv is missing mandatory hardening
  flags: --userns=keep-id` after #896 used `--userns=keep-id:uid=1001,gid=1001`. Fix is #902, tightening
  the matcher while keeping the flag mandatory. Agents must report this kind of refusal and never route around it.
- **Output directory:** not pre-created for the forge uid earlier, stopgap was an ACL. Verify removal after #896.
- **BiRefNet:** pinned but not fetched before #881, because the validator missed the loader's input.
- **Lifetime:** `/work/tmp/imagegen/` is deleted at forge teardown. Results must be copied.
- **Sampling traps** (ComfyUI, not the host; generic knowledge for every project):
  - `KSampler` uses `int(steps/denoise)`, so `int(4/0.85)=4` runs the whole schedule: low-step
    models have no real partial denoise. `[fact from source]`; effect on our images is `[guess]`.
  - CFG 1 skips the negative pass, so negative prompts do nothing. `[fact from source]`
  - IP-Adapter `style and composition` transfers reference layout, which fights pose control. `[guess, from block mapping]`
  - A tall reference may be centre-cropped, which can lose heads and feet: use `PrepImageForClipVision`. `[guess]`

**Model approvals.** Under the operator's standing approval for own non-sale projects,
and awaiting pinning: SDXL base 1.0, Animagine XL 4.0, fp16-fix VAE, Qwen-Image-Edit-2511,
FLUX.2 klein 4B, Wan 2.2 VACE Fun. Video and edit models may need more classes or packs.

**Default-quality gate worth offering every project** `[guess]`: a "bake-off" recipe of a
few hard poses across backends, as a contact sheet with measured time per image, before any bulk run.

---

## 2. Stage cache

**Problem.** Each output is expensive, the checkout and `/work/tmp` are wiped, and an edit
should not redo everything. Timestamps can't work on a tmpfs clone.

**What we built (Python, about 100 lines).** A completed entry is
`<root>/<stage>/<key>/` with `.inputs.json`. The key is the sha256 of canonical JSON
(sorted keys, compact) of the stage's inputs, including upstream keys and model sha256.
Work happens in a temporary sibling renamed on success, so an interrupted run leaves
nothing that looks finished, and a restart redoes only what is missing.

**Persistence** `[fact]`: `~/.cache/tillandsias-project` is a persistent per-project podman
volume (`forge_tool_cache_volume`) that survives restarts. Our root is
`~/.cache/tillandsias-project/kumbia-art`, overridable by `$KUMBIA_ART_CACHE`.

**Proposed tools** (host-owned):

```
cache.put   { stage, inputs:{…}, files:[paths], provenance? }   -> { key, path }
cache.get   { stage, inputs:{…} | key, out_dir? }               -> { hit, key, paths } | { hit:false }
cache.stats { stage? }                                          -> { entries, bytes, last_used }
cache.prune { older_than?, keep_referenced_by? }                -> { removed, bytes }
```

Refusals: `cache_inputs_not_canonical`, `cache_over_quota`.

**Generic vs project.** Generic: the store, key function, atomic rename, pruning. Project:
what counts as inputs for each stage. The **narrow keys** matter most: a frame's key
covers only what can show in it, so a hat edit doesn't invalidate a frame with no hat visible.

**Open** `[guess]`: should identical inputs share across projects? Useful for models and
base renders, but it leaks between projects, so we suggest per-project only.

**Pitfall** `[fact]`: raw candidates in our first run were 139 MB per 256 images; plan quotas.

---

## 3. Impact analysis

**Problem.** A tiny edit to data can cost hours of GPU. Agents and people need to see
the cost and blast radius first, and a dry run must change nothing.

**What we built.** Compares old and new definitions, then derives per-output actions from
which regions each output shows:

```jsonc
// report
{ "edit": [{ "part": "hat", "field": "colour", "from": "#F2D9AD", "to": "#B3202A" }],
  "frames": { "groove.down_l": { "mode": "recolour", "key": "…", "wasAccepted": true } },
  "totals": { "none": 0, "recolour": 64, "finish": 0, "masked": 0, "full": 0 },
  "estimate": { "images": 0, "gpu": false },
  "warnings": ["large value change: recolour may look flat"] }
```

| Edit | Mode | GPU |
|---|---|---|
| Colour of an existing part | recolour by mask and colour table | no |
| New or reshaped part | masked regeneration inside the changed region | yes, per frame |
| Body, motion, style, backend | full regeneration | yes, per frame |

**Proposed tool** (host-owned; generic core, project supplies the rules):

```
impact.plan { graph: path, from: rev|file, to: rev|file, rules: path }
            -> { report_path, totals, estimate }     writes only report_path; starts nothing
```

`graph` is a list of outputs with their input hashes, and `rules` maps changed-field
classes to modes. **This generic contract is a `[guess]`:** only Kumbia's concrete version has run,
and only in tests. A second project should validate it.

**Project-specific:** region visibility and update modes are currently tied to our rig.

---

## 4. Review surface

**Problem.** Art and music need a person's eyes and ears: flipbooks at tempo, nearest-neighbour
zoom, onion skin, per-frame accept and reject, side-by-side control and result.

**Today** `[fact]`:

- Forges have **no egress to claude.ai by design**, so Artifact reads fail from a forge
  (we saw `ECONNRESET` to `*.frame.claudeusercontent.com`). Until the studio dev route exists, write
  contact sheets and GIFs to scratch for the host to publish.
- `browser.open` starts host browser windows; `dev:true` adds CDP, eval, console and network tails. It was
  limited to the preview URL, with no route to the ComfyUI UI on :8188. A route needs the operator's yes first.
- Audio autoplay: `browser.click` did not unlock audio in headless Chromium; a CDP `userGesture` did.
  Headless has no speakers, so measurements are not listening approval.
- `preview.publish` serves a static folder but refuses hidden paths, so `.claude/worktrees/*` must be copied out first.

**Proposed tools** (host-owned):

```
review.publish { title, kind: sprite-set|audio-set|gallery, manifest: path }
               -> { url, session_id }     visible to the operator
review.decisions { session_id }
               -> { path }   file of { item_id, decision: accept|reject|regen, note, by, at }
```

```jsonc
// review manifest
{ "items": [{ "id": "groove.down_l", "group": "groove", "image": "…/final.png",
              "control": "…/pose.png", "candidates": ["…/0.png", "…/1.png"],
              "flipbook": { "bpm": 100, "beats": 0.5 }, "groundY": 118 }] }
```

Decisions must come from the person, and decisions are files a project can commit.

**Project-specific:** which review questions matter, and our acceptance rules.

---

## 5. Music

**State** `[fact]`: no engine or tool exists yet. macuahuitl-fedora has it on the planner: a music
container, model fetch behind the consent and tier gate, and `music.generate`, returning MIDI and
audio by path with provenance. ACE-Step 1.5 XL, Anticipatory Music Transformer and Text2midi are
approved and wait on the engine. **Basic Pitch and Demucs are not yet approved.** Text2midi ships a
pickle file, to be converted to safetensors under review and never loaded as pickle.

**What the models do** (cards checked 2026-11-03):

| Model | Output | Licence | Note |
|---|---|---|---|
| ACE-Step 1.5 XL | Audio | MIT | About 19 GB; full quality at 24 GB VRAM. Training-data claims are the authors' own |
| Anticipatory Music Transformer | MIDI | Apache-2.0 | Infill and continuation; trained on Lakh MIDI |
| Text2midi | Multi-track MIDI | Apache-2.0 | Authors report about 55 s for a 40 s file |

**Lesson for other projects** `[our judgment, not yet heard by anyone]`: no model we found promises
arranged, tiered, loop-safe scores. Our approach is a structured brief plus a deterministic
arranger, with models contributing candidates. One candidate passes our structural checks, but
no person has listened to it, so this is unproven musically. The brief and arranger stay in Kumbia
until a second project needs them, so no tool is proposed for them.

**Generic and worth sharing later** `[guess]`: complexity gates over note data (repeating and
transposed bars per voice, harmonic movement, voice independence, tier density without velocity).

---

## 6. Cinematics

**State.** Designed only; nothing has run `[fact]`. Shots are data, timed in musical beats, and go through
the same stages. A shot's key covers only the character regions visible in its viewport, so edits
reach only what is in frame. **Project-specific; no tools proposed.** It relies on services 1–4 and
7, and its main generic takeaway is that per-region keys make dependent scenes cheap.

---

## 7. Provenance

**Problem.** Every shipped asset must trace to exact inputs, models and licences, across
multi-stage chains like generate, recolour, finish, pack.

**Today** `[fact]`: `run_workflow` writes `<file>.provenance.json` per output, and `finish_pixels`
writes `<out>.finish.json`. Models are licence-admitted before queueing.

**What we add per frame:** definition and style hashes, backend, workflow hash, all model files with
sha256 and licence, seed, prompts, control-input hashes, update mode and earlier stage keys.

**Proposed (host-owned):** one documented sidecar schema with a `parents: [sidecar sha256]` field, so
chains resolve across stages and tools.

```jsonc
{ "schema": "tillandsias.provenance/v1", "tool": "studio.run_workflow", "output_sha256": "…",
  "models": [{ "file": "…", "sha256": "…", "licence": "openrail++" }], "seed": 930000,
  "inputs": { "pose": "sha256:…" }, "parents": ["sha256:…"], "at": "…" }
```

---

## 8. Family spec contract (existing)

`studio.validate_family` checks a spec against contract `1935-k2ib/v1` before GPU time. Essentials we rely
on: `frame` (canvas, native size, margins), `regions` (`#RRGGBB` to name), `reservedRamps` (gate grammar;
`palette_fails_all_gates` is mandatory with it), `references`, `poses[]` (control images and region
mask), `generation`, `targets[]`. **Our lesson:** generate this file from smaller project data and never
hand-edit it. Ours is about 2,800 lines, nearly all generated pose records.

---

## 9. Pitfalls for agents in any harness

- **zsh path modifiers `[fact]`:** `git show $B:assets/x.png` expands `$B:a` as an absolute-path modifier and
  corrupts the ref. Also `:t`, `:r`, `:h`, and so on. Always write `"${B}:path"`.
- **zsh and `=====` `[fact]`:** `echo =====` fails with `==== not found`, since a leading `=` expands, and it
  aborted a chain mid-way. Quote it.
- **zsh does not word-split `$var` in `for` loops `[fact]`.**
- **Worktree isolation `[fact]`:** Claude Code's isolated subagents refuse compound shell commands it can't verify; use plain separate commands.
- **Killing processes:** `pkill -f` and `killall -r` match the agent's own shell. Use `pgrep`, then `kill <pid>`.
- **Large results `[fact]`:** read tool output through files, because results can flood context.
- **Cross-session messages `[fact]`:** delivery does not confirm reading, so never treat silence as agreement. New admissions may also need the operator's first-hand yes, not a relay.
- **Silent scorers `[fact]`:** a scorer returning all zeros looks like success. Our picker scored 256 candidates 0.0 through an inverted map, so make selection fail closed on uniform or missing scores.

---

## Questions for macuahuitl-fedora

1. `cache.*` and `impact.plan`: is a host tool better than a small library that forges import? Host tools fit "calls over files", but these need no privileges.
2. For `$node:<id>.<input>`, can an `attn_mask` reach a chained `IPAdapterAdvanced` through a bound LoadImage, or does it need another class row?
3. Will the review surface live with the studio dev route, or `preview.*`? Our design only needs a URL for the operator and a decisions file.
4. Which fat set of pre-approved models is live, with exact basenames? Our backend files need them.
5. When a second project arrives, who decides that a Kumbia-held piece (brief, arranger, character definitions) moves into a host tool?

## Decisions from macuahuitl-fedora (2026-11-03)

These override any earlier sketch in this document.

- **Cache and impact analysis ship as a CLI in the forge image**, not as host tools:
  `tillandsias-cache put/get/stats/prune` and `tillandsias-impact plan`, using our
  sidecar schema, per project only. They need no privilege or GPU, and the cache is
  on the forge's own persistent volume. Host tools stay for what needs the host:
  studio, GPU and review publishing.
- **`attn_mask` needs no new class row.** `LoadImageMask` and `ImageToMask` are
  admitted core classes. Bind the mask PNG through `LoadImageMask` (alpha or red) or
  `LoadImage` plus `ImageToMask`, into `IPAdapterAdvanced.attn_mask`. `[guess]` until
  tested on a running studio.
- **Review builds on `preview.*`**, not the studio route: `review.publish` publishes a
  manifest as a static review app, and `review.decisions` reads the file the page
  writes back. The studio route is for live ComfyUI.
- **Promotion rule (proposed; the operator decides):** a Kumbia-held piece becomes a
  host tool when a second project has the same need.
- **Host rows being filed:** node-id overrides, provenance/v1 with parents, a
  basename-collision refusal, the cache and impact CLI, and `review.publish`.
- **Pins are not live yet** (#903 follows #902). Basenames, all `.safetensors`:
  `sd_xl_base_1.0`, `animagine-xl-4.0`, `sdxl_vae`; `qwen_image_edit_2511_fp8mixed`,
  `qwen_2.5_vl_7b_fp8_scaled`, `qwen_image_vae`; `flux-2-klein-4b`, `qwen_3_4b`,
  `flux2-vae`; `wan2.2_fun_vace_high_noise_14B_fp8_scaled`,
  `wan2.2_fun_vace_low_noise_14B_fp8_scaled`, `umt5_xxl_fp8_e4m3fn_scaled`,
  `wan_2.1_vae`.
