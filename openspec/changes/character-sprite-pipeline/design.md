# Design

## Context

Motivation is in proposal.md, requirements in the `character-asset-pipeline` spec.
Base: `work/1832-gk64`, where `tool/art/pipeline/README.md` describes the current
stages. Run `gatekeeper-v3-20261103a` generated 64 poses × 4 candidates.

**Hard-wiring today.** `standin.py` holds `GATEKEEPER`/`MACRON` proportions and
`REGIONS`, and builds geometry in code. `poses.py` holds clip tables per character
and per-pronoun intent text. `gatekeeper-v3.json` is 2,800 lines mixing authored
fields with generated ones. Rerunning means regenerating everything.

**Causes of the last run's defects.**

| Finding | Status |
|---|---|
| `suggest.py` inverts its region map, so every region is skipped; all 256 candidates have `identityScore` 0.0, and picks came from matte speck counts | Confirmed from code and committed scores |
| CFG 1 disables the negative pass, so `floor shadow` and the rest had no effect | ComfyUI source; floor shadows in the output fit |
| `int(4/0.85)=4` steps uses the full schedule, so denoise 0.85 is really a full repaint and the colour init barely survives | ComfyUI source; not measured |
| Rig has small heads, thin forearms and no hands | Likely cause of thin limbs and missing faces |
| IP-Adapter "style and composition" transfers the reference's layout against the pose | Likely, from the node's block mapping |
| One tall reference crop may lose its hat and shoes to a centre-crop | Untested |

**Studio facts (macuahuitl-fedora, 2026-11-03).** Packs: GGUF, IPAdapter_plus,
layerdiffuse and BiRefNet_ll, plus core nodes. Classes are allowlisted per pack.
`IPAdapterAdvanced` takes `attn_mask`; `PrepImageForClipVision` is admitted;
`IPAdapterRegionalConditioning` is not. `run_workflow` overrides reach only
`$seed`, `$prompt`, `$negative_prompt`, plus `$strength`, `$mask`, `$init_image`
and named `LoadImage` inputs. No HTTP route to `:8188`. No LoRA trainer.
`/work/tmp/imagegen/` is wiped at forge teardown.

## Goals / Non-Goals

**Goals:** one code path for any humanoid character; rebuild cost proportional to
the size of the edit; quality decided by measured comparison; no new node packs
needed for the core path.

**Non-Goals:** a natural-language parser inside the pipeline (D8); non-humanoid
support beyond keeping Mācron's existing rig working; video generation in the
default path (D11); LoRA training; a review UI beyond contact sheets, GIFs and
galleries.

## Decisions

### D1. Three definition layers; the family spec becomes generated

`tool/art/characters/<id>.json`, `tool/art/styles/<id>.json` and
`tool/art/backends/<id>.json` are authored. A compiler produces the family spec,
which is studio-facing, never hand-edited and validated by
`studio.validate_family`.

Character definition, in outline:

```jsonc
{
  "id": "bartender", "style": "party-pixel", "backend": null,
  "body": { "preset": "slim-adult", "overrides": {} },
  "garments": [
    { "id": "waistcoat", "region": "cloth", "shape": "torso-fitted",
      "colour": "#0F5A5E", "text": "fitted deep teal waistcoat" },
    { "id": "apron", "region": "apron", "shape": "waist-apron",
      "colour": "#7A1F57", "text": "plum apron tied at the waist",
      "secondaryMotion": "lag-1" },
    { "id": "hair", "region": "hair", "shape": "puff",
      "colour": "#2A1712", "text": "compact curly dark hair in a rounded puff" }
  ],
  "props": [{ "id": "shaker", "hand": "right", "colour": "#BFC6CC", "clips": ["groove"] }],
  "skin": "#B5784A",
  "traits": "friendly adult woman bartender, fully buttoned shirt and waistcoat, warm confident smile, dignified professional who dances superbly",
  "pronoun": "her",
  "motion": { "set": "opponent-64", "overrides": {} },
  "references": { "sources": ["assets/art/bar/bartender.png"], "mode": "derive" },
  "targets": [{ "room": "bar", "atlas": "bartender", "native": [96, 120] }]
}
```

Why: a single definition is what makes "add a red hat" a small diff. Alternative,
keeping the family spec as the source, was rejected because it mixes 2,800 lines
of generated pose records with the few authored facts, and it is a contract owned
by another project.

### D2. Shared motion sets, characters only override

Move the 64 clips out of `GATEKEEPER` into a named `opponent-64` set in normalized
joint angles, which are already proportion-independent. Intent text uses
`{his}/{him}/{he}` placeholders filled from the definition. Bartender overrides
styling (shaker hand, apron and shirt settling) rather than copying tables.
`check_poses.py` runs per character, because different proportions can break
clearances that passed on Gatekeeper.

Alternative: per-character tables, as now. Rejected: each new character would be
64 hand-copied poses.

### D3. Garment shapes are a small parametric library

`standin.py` builds geometry from named shapes: `hat`, `puff`, `torso-fitted`,
`waist-apron`, `sleeve-rolled`, `trousers`, `shoes-heeled`, `mitten-hand`, and a
prop primitive. Each shape owns one flat region colour in `regions.png`. Regions
become dynamic per character and are declared to the spec automatically.

Baseline fixes for all humans: larger head, sturdier forearms, mitten hands. These
are expected to fix thin limbs and vanishing faces, and the proof clip tests that.

Alternative: garments described only in the prompt. Rejected: prompt-only items
have no mask, so they cannot be scored, recoloured or masked-regenerated.

### D4. Content-addressed stage graph

Stages: `rig → proxy/masks → references → generate → matte → colour → finish →
select → pack`. Each stage's key is the sha256 of its inputs plus upstream keys,
narrowed to what it actually consumes:

| Stage | Key covers |
|---|---|
| rig | body, garment geometry, pose params, camera |
| proxy/masks | rig key + region colours |
| references | sources, garment geometry and colours, style |
| generate | control hashes, references, prompts, seed, backend, workflow hash |
| colour | generate key + region targets |
| finish | colour key + palette + native size |
| pack | set of finish keys + selection |

Outputs live in `art_cache/<stage>/<key>/` beside `art_runs/`, gitignored except
for selected finals and provenance. `art_runs/<run>/` remains an immutable record
pointing at keys. Selection stores `{pose: {key, accepted}}`, so acceptance
survives while a frame's key is unchanged, which gives partial re-review directly.

Alternative: timestamps, Make-style. Rejected: unreliable on a tmpfs checkout, and
cannot express "same inputs, reuse".

**The cache must survive forges.** The checkout and `/work/tmp` are wiped, so raw
candidates would be lost and "only rebuild what changed" would degrade to "rebuild
everything" after every restart. The cache goes in the persistent
`~/.cache/tillandsias-project` if it survives restarts (verify in task 1.3), with
selected finals committed to git either way.

### D5. Update-mode planner

`art plan` diffs the old and new definition to get changed fields, then derives
per-frame modes from which regions each frame contains (from `rig.json`
`regionPixels`):

| Edit | Mode | GPU |
|---|---|---|
| Colour of an existing garment | **recolour:** remap that region's ramp, using the mask, on the finished frame | none |
| New or reshaped garment, prop | **masked:** re-render rig, regenerate within the changed-region mask dilated by a few px via `$mask` + `$init_image` | per frame |
| Body, motion, style or backend | **full** | per frame |
| Text only (`traits`) | **full**, unless forced lower | per frame |

Frames where the region is invisible are skipped. A rear view with no visible
edit keeps its key.

A part can declare `alsoIn` regions: surface detail with no rig geometry, such as
embroidered panels painted on a shirt, keeps its own ramp and is not snapped away
by the ramp stage.

Masked jobs bake their denoise in the workflow rather than passing `$strength`:
a KSampler has one title, and it must stay `$seed` so seeds can vary. If the studio
later binds both, this can become a runtime value. The workflow's latent round trip
alters unmasked pixels slightly, so the masked stage composites the result over the
previous frame, which is what guarantees byte-identical pixels outside the mask.

Alternative: always full regeneration. Rejected: 256 images per edit would make
iteration impractical, and it would churn frames the owner already accepted.

Recolour is limited by design: it is exact, but a shade ramp remap can't change
how cloth reads. A large value change, such as cream to black, is flagged as
"recolour may look flat; `--mode masked` available".

### D6. Backends as data, workflows generated per backend

`build_workflows.py` crosses backends × profiles into `<backend>/<profile>.api.json`
because overrides can't reach control strengths or checkpoints. A backend names its
checkpoint, sampler, steps, CFG, denoise, LoRAs and role:

```jsonc
{ "id": "animagine-xl4", "role": "pose-frame", "checkpoint": "…",
  "sampler": { "steps": 28, "cfg": 5.0, "name": "euler_ancestral", "scheduler": "normal" },
  "denoise": 0.7, "loras": [{ "name": "pixel-art-xl.safetensors", "weight": 0.8 }],
  "negatives": "effective" }
```

Selection order: `--backend` > character > style default. Backends with
`"negatives": "ineffective"` make the planner warn if a definition relies on them.
Roles are `pose-frame` (default path), `edit` (Qwen/klein, for references and
repairs) and `video` (D11), so optional models plug in without path changes. All
parameters are starting points, set by the bake-off (D10).

### D7. Identity: masked adapters, derived references, per-region colour

- **Two chained `IPAdapterAdvanced`** with `attn_mask` from the rig: head crop on
  the head mask, outfit crop on the body mask, weight type `style transfer`, each
  crop square through `PrepImageForClipVision`. No new pack is needed. Whether a
  mask can be bound through `run_workflow` (LoadImage's mask output, or an
  image-to-mask core node) is tested first; if it can't, fall back to a single
  unmasked adapter with a square crop.
- **References are stage outputs**, not fixed files. In `derive` mode a small
  model sheet (front, 3/4, rear) is generated from source art and accepted by a
  person. Edits invalidate it through its key. This honours "nothing is final",
  and is what stops an old reference undoing a red hat.
- **Colour stage in the repo, not ComfyUI:** per-region matching in Python using
  rig masks, against the definition's colours, before finishing. Deterministic,
  needs no KJNodes, and is safer than global matching because pose changes the
  global statistics.

Alternative: requesting KJNodes, Impact and PixelOE packs. Deferred: each needs a
lock file, class rows and licence approval, and may prove unnecessary.

### D8. Natural language stays in the agent

"Add a red hat to Bartender" is handled by the `art-family` skill: the agent writes
a definition diff, runs `art plan`, shows the result and proceeds. The pipeline only
ever sees validated data, so runs stay deterministic and reviewable in git.

Alternative: a local LLM parsing edits inside the pipeline. Rejected: it would add
non-determinism at the one point where the diff should be inspectable.

### D9. Selection fails closed

Fix the inverted map, then score per-region colour (ΔE in OKLab against definition
colours) plus silhouette IoU against the rig mask. Zero or uniform scores abort.
A regression test uses a synthetic candidate with a wrong hat.

### D10. Bake-off before scale

Three hard poses (`left_hand.peak`, `groove.down_l`, `finish_turn.turn_in`) across
Lightning with real partial denoise, SDXL base and Animagine; adapter variants;
BiRefNet vs LayerDiffuse. The winner becomes the style default, recorded with
measured time per image. Lightning stays selectable for fast previews.

### D11. Video is an optional backend role, tested once

Wan 2.2 VACE Fun runs one groove loop as a bake-off once pinned: render continuous
16 fps rig motion, select keyed frames, re-finish through the stills path. It stays
out of the default path unless it clearly wins, because research found no direct
sprite comparison, and doctrine forbids shipping raw interpolated sequences.

### D12. Runtime compatibility through aliases

`pack_atlas` writes the 64 `{clip}_{drawing}` frames plus the 20
`challengerFrameIds` as aliases, from a mapping in the motion set (for example
`left_hand` → `left_hand.peak`, `settle` → `left_hand.return`). Extra manifest keys
are ignored at runtime, so promoting needs no game change. A rig-derived `facing`
replaces the hard-coded `front`.

### D13. Palette-aware frames and named variants

Owner direction: replays after beating the game show slightly different opponents,
with more complex music and faster play. This change makes the art ready for that;
the replay mode itself is out of scope.

- **Ramps are per-region.** Each garment, skin and hair declares a ramp of 3–5
  shades, and no colour belongs to two ramps. A finished frame therefore records
  which part of the character every pixel is.
- **A ramp stage follows `finish_pixels`:** it remaps each opaque pixel to the
  nearest shade of an allowed ramp, using the rig mask. This is needed because
  the shared-palette quantise can give a hat and trousers the same cream.
- **Variants are data:** `"variants": {"replay-1": {"apron": "#1F4E7A"}}`. A
  colour-only variant is a ramp LUT, so it costs no GPU and uses one atlas plus a
  small table. A variant that also changes garment shapes (the "slightly differently
  composed" case) goes through masked mode, and gets its own atlas.
- **Runtime contract:** the pack step emits `ramps` in the manifest block. Extra
  keys are ignored today, so nothing breaks, and a later boss-variant shader can
  read them. The existing guest outfit gates in `party_palette.frag` are untouched,
  and opponent ramps must still fail those gates (see the spec).

Alternative: baking a full atlas per variant. Rejected as the default because it
multiplies memory on phones, against the existing atlas budget concerns.

### D14. Bartender's plum and the recolour gates (task 7.2, awaiting the owner)

Measured 2026-11-03 against the style's reserved gates (`cool`, `plum`, `pink`), with
distances in OKLab scaled by 100:

| Colour | Gates hit | Result |
|---|---|---|
| Trousers `#3A1A38`, all four shades | none | Clear, no change |
| Apron `#7A1F57`, base shade | `plum` | Moves to `#7A3057`, distance 3.29 |
| Apron's three other shades (`#270014`, `#4E0033`, `#934671`) | none | Clear, though the shared ramp pass nudges them slightly to avoid collisions |

Options for the apron:

- **A, provisional in the definition:** `"nudge": true`, base `#7A3057`. Slightly greyer
  and pinker, and visible side by side on swatches, so it is the owner's call.
- **B:** the nearest whole-ramp colour, `#762D51`, at distance 3.05. About the same shift.
- **C:** base `#511837`, sampled from the source art's apron, which clears every gate
  unchanged but is much darker.
- **D:** declare the apron recolourable, keeping `#7A1F57`, so outfit tinting could reach it.

## Risks / Trade-offs

- [Bartender's plum apron and trousers may fall inside the outfit recolour gates]
  → `palette_fails_all_gates` runs at definition time. Nudge if the visual change is
  small; otherwise declare the region recolourable with the owner's agreement.
- [Mask binding through `run_workflow` may not work] → test first; D7 has a
  fallback, and an admitted-class request is the next step.
- [Full-step backends cost roughly 14× Lightning in sampling steps] → bake-off
  measures it; candidates per pose can drop once selection scores really work.
- [Masked edits can leave seams at the mask edge] → dilate masks and run seam
  review in the proof; `--mode full` remains available.
- [Cached outputs depend on model bytes] → keys include model sha256 from
  provenance, so a re-pin invalidates correctly rather than silently reusing.
- [Studio or pins may lag] → all CPU stages and tests run without a studio; the
  pipeline runs on Lightning if the new checkpoints aren't live yet.
- [Rig fixes may not be enough for appeal] → the proof clip is reviewed before the
  64-frame run; LoRA and edit-model routes remain as escalation.
- [Bartender's source art is cut low at the neckline, and identity references could
  carry that through] → owner decision 2026-11-03: fully buttoned, fully clothed
  adult professional who dances superbly. The rig's waistcoat and collar cover the
  chest, the text says so, and references are derived rather than copied from it.
- [Mask-based ramp assignment can misclassify pixels where generated art leaves the
  rig mask] → assign by nearest ramp within a dilated mask, and count the pixels
  that fall outside any allowed ramp as a review signal.

## Migration Plan

1. Land definitions alongside existing files. Compiling `gatekeeper` must reproduce
   the current pose list (same IDs, count and order).
2. Keep `art_runs/gatekeeper-v3-20261103a` untouched as the comparison baseline.
3. `gatekeeper-v3.json` becomes a generated file. The candidate atlas is replaced
   only by a reviewed new run.
4. Mācron keeps his `standin.py` path, moved behind the same interface, and is
   checked by re-rendering and comparing `rig.json` at this stage.

Rollback: nothing touches the runtime until promotion, which is per-atlas and
reversible through git.

## Open Questions

- Native size for the bar: start at 96×120, as in the garden, and confirm at game
  size during Bartender review.
- Exact candidates-per-pose after scoring is fixed: decide from bake-off data.
