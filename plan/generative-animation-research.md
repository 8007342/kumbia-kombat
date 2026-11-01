# Generative animation research: consistent, animation-ready dance sprites

Status: research input for the sibling ComfyUI pipeline + review studio team.
Sources checked **2026-11-01**. Licence statements are quoted from the linked
model cards / READMEs on that date; re-check before any model enters the cache.
This document does not change canon in `openspec/specs/art-direction`,
`assets/art/STYLEGUIDE.md`, `plan/dance-fluidity-pass.md` or
`plan/opponent-depth-staging-pass.md`; it proposes how a generator can serve them.

## 0. Constraints this research is bound by

**Art doctrine (ours).** Authored key poses + breakdowns, planted support feet,
unequal holds, beat-sampled timing, hand-drawn-style smears only. No Gaussian
blur, crossfade or optical-flow interpolation. Nearest-neighbour pixel finish.

**Forge constraints (from the forge coordinator, 2026-11-01).**

- GPU: one RTX A5000, 24 GB. ComfyUI runs in a sibling container on port 8188,
  **no network egress, read-only model cache** — every model, custom node,
  palette and annotator must be provisioned ahead of time; nodes that download
  weights on first use (common for annotators and rembg) will fail.
- Tier I1 (today): **SDXL-Lightning 4-step** (openrail++). Tiers I2/I3 (soon):
  **FLUX.1-schnell** Q4/Q8 (Apache-2.0).
- Shippable licences only: apache-2.0, mit, bsd, creativeml-openrail-m, openrail++.
- **Forbidden**: sd-turbo, sdxl-turbo, SD3.5, FLUX.1-dev and anything dev-derived
  (ControlNets/LoRAs/adapters), RMBG-1.4/2.0.
- **Pending operator approval**: Qwen-Image-Edit-2511, FLUX.2-klein-4B, Z-Image,
  BiRefNet/BEN2, xinsir OpenPose SDXL, Depth-Anything-V2-Small.
- LoRA training is not built yet (in design).
- Forge specs `openspec/specs/local-image-generation` and
  `openspec/specs/web-studio-lanes` live in the Tillandsias project, which is
  **not readable from this workspace** (only `kumbia-kombat` is mounted). Nothing
  here was checked against them; the studio team should reconcile.

Status legend used below: **ALLOWED** (shipped tier or allowlisted licence and
already approved), **PENDING** (allowlisted licence, awaiting operator approval),
**PROPOSE** (allowlisted licence, not yet on any list — needs a request),
**FORBIDDEN** (explicitly banned or licence outside the allowlist),
**TOOL** (offline tooling/code, not a weight; licence noted for the record).

## 1. What is wrong with the current art (observed)

`assets/art/party/macron-dance-v1.png` (4×4, ~1243×1265) and
`assets/art/ensemble/gatekeeper-v2.png` (5×4, ~1214×1295) were produced by a
built-in image generator from a prose prompt (`provenance.json`). Inspected
visually:

| Problem | Mācron | Gatekeeper | Root cause |
| --- | --- | --- | --- |
| Identity drift | head width, antenna orb size and cuff arm vary per cell; rear head shape differs from front | hat band, shirt panel pattern, moustache vary | no identity conditioning; each cell re-invents details |
| Scale/baseline drift | head-to-body ratio changes between cells | feet do not share a baseline; body height varies | no structural control; "same scale" in prompt is not enforced |
| Overlapping cells | arms nearly touch neighbours | extended hands cross into adjacent cells (row 1–3) | free composition on one canvas |
| Fake pixel grid | stair-steps of mixed size, AA'd edges | same, plus semi-transparent halos | generated "pixel-look", never quantised to a real grid |
| Matting fringe | dark/teal edge noise | yellow/red rim on many edges | soft alpha from background removal, no colour decontamination or binarisation |
| Pivots | not derivable | not derivable | no ground-truth foot positions |

Every recommendation below targets one of these: **structure comes from a
controllable source (rig/puppet), identity from references/LoRA, pixels from a
deterministic finisher, pivots from the rig — never from guessing the image.**

## 2. Identity consistency

| Method | Works for | Licence / status | Verdict |
| --- | --- | --- | --- |
| IP-Adapter (image prompt adapter, [repo](https://github.com/tencent-ailab/IP-Adapter), [paper](https://arxiv.org/abs/2308.06721)) — "Plus" SDXL ViT-H variant | robot and humans (whole-image style/identity) | code Apache-2.0; weight licence **not stated on the README** — verify `h94/IP-Adapter` card → PROPOSE | **Use** as the zero-training identity anchor |
| IP-Adapter **FaceID** variants | humans only | needs InsightFace, whose pretrained models are "for non-commercial research purposes only" ([insightface](https://github.com/deepinsight/insightface)) | **FORBIDDEN** |
| InstantID ([repo](https://github.com/instantX-research/InstantID)) | humans only | code Apache-2.0, but needs InsightFace antelopev2 and checkpoints are "for research purposes only" | **FORBIDDEN** |
| PuLID | humans only | InsightFace dependency; the Flux variant is FLUX.1-dev-derived | **FORBIDDEN** |
| Reference-only attention ([ComfyUI_experiments](https://github.com/comfyanonymous/ComfyUI_experiments) `reference_only.py`, GPL-3.0) | both | TOOL (no extra weights) | Cheap fallback; weaker than IP-Adapter, unreliable at 4 steps (untested) |
| Shared-attention batches (ConsiStory [2402.03286](https://arxiv.org/abs/2402.03286), StoryDiffusion [2405.01434](https://arxiv.org/abs/2405.01434)) | both | research methods; no vetted ComfyUI node chosen | Watch; the "grid on one canvas" trick (§4.2) is the poor-man's version |
| Character LoRA (kohya [sd-scripts](https://github.com/kohya-ss/sd-scripts) Apache-2.0; ostris [ai-toolkit](https://github.com/ostris/ai-toolkit) MIT) | both | TOOL; the resulting LoRA inherits the base model licence | **Best long-term lock** once training exists |
| Instruction editing with reference (Qwen-Image-Edit-2511 [card](https://huggingface.co/Qwen/Qwen-Image-Edit-2511), Apache-2.0; FLUX.2-klein-4B [card](https://huggingface.co/black-forest-labs/FLUX.2-klein-4B), Apache-2.0, multi-reference editing, ~13 GB) | both | PENDING | Strong for turnaround/bootstrap and fixing one cell; card claims "significantly improved" character consistency |

Notes and trade-offs:

- **ComfyUI_IPAdapter_plus** ([cubiq](https://github.com/cubiq/ComfyUI_IPAdapter_plus), GPL-3.0)
  is the standard node pack but has been in **"maintenance only" mode since
  2025-04-14**. Pin a commit; expect breakage on ComfyUI upgrades. Its FaceID
  paths pull InsightFace — do not install that dependency in the container, so
  nothing can silently use it.
- **Robot (Mācron)**: face-identity tools are irrelevant (no human face). Its
  identity is *geometry* (head:body ratio, screen inset, antenna, cuff on the
  anatomical right arm) plus a palette. Geometry is better locked by a 3D/2D
  puppet render (§3.3) than by any adapter; IP-Adapter then only carries the
  surface finish. This is the single largest fix for the drift in §1.
- **Humans (Gatekeeper, crowd)**: IP-Adapter Plus (non-face) from 1–3 approved
  frames + pose control is the I1 baseline. Faces at our sprite size are ~6–12
  native pixels; face-ID precision is wasted there — costume, hat, silhouette
  and palette carry identity, and those are what LoRA/IP-Adapter learn.
- **LoRA bootstrap order** (when training lands): (1) proxy-render turnaround +
  edit model or IP-Adapter → (2) human-curate ~15–40 approved, pixel-finished,
  varied-pose frames per character (count is a community heuristic, not a
  measured number for us) → (3) train an SDXL LoRA with kohya or ai-toolkit →
  (4) every studio-approved frame becomes a candidate for the next dataset
  version. Caption the invariant traits *out* (so the LoRA owns them) and the
  pose/view *in*. Version LoRAs; record dataset hashes.
- **Flux schnell caveat**: it is step-distilled; LoRA training on it is less
  established (ai-toolkit lists FLUX.1-dev, and a schnell config exists, but
  support is not stated explicitly). Do not plan identity LoRAs on schnell until
  a test passes. SDXL is the safe training target.
- **Uncertain**: whether IP-Adapter and ControlNet keep their strength with
  SDXL-Lightning at 4 steps / CFG 0 (the [Lightning card](https://huggingface.co/ByteDance/SDXL-Lightning)
  says CFG must be 0 and does not mention ControlNet). Negative prompts are
  ineffective at CFG 0. Run an A/B before committing; a slower 20–30-step SDXL
  base ([openrail++](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0))
  path may be needed for final frames.

## 3. Pose control

### 3.1 ControlNet availability under our licences

| Model | Base | Licence | Status |
| --- | --- | --- | --- |
| [xinsir/controlnet-openpose-sdxl-1.0](https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0) | SDXL | Apache-2.0 | PENDING |
| [xinsir/controlnet-union-sdxl-1.0](https://huggingface.co/xinsir/controlnet-union-sdxl-1.0) (openpose, depth, canny, lineart, normal, segment…; ProMax adds tile/inpaint) | SDXL | Apache-2.0 | PROPOSE — one model covers robot and human |
| XLabs / InstantX / BFL "Tools" Flux ControlNets | FLUX.1-dev | dev licence (non-commercial, §2(a)–(b) of [dev licence](https://huggingface.co/black-forest-labs/FLUX.1-dev/blob/main/LICENSE.md)) | **FORBIDDEN** |
| Any schnell-native pose ControlNet | FLUX.1-schnell | none found that is clearly not dev-derived | gap |
| [DWPose](https://github.com/IDEA-Research/DWPose) detector | — | code Apache-2.0; weight licence not stated | PROPOSE only if we must extract poses from video |
| [Depth-Anything-V2-Small](https://github.com/DepthAnything/Depth-Anything-V2) | — | Small Apache-2.0; **Base/Large/Giant CC-BY-NC-4.0** | PENDING (Small only) |

Consequence: **pose-controlled generation lives on SDXL** for the foreseeable
future. Flux schnell (I2/I3) is useful for concept/turnaround ideation and
img2img finishing, not for pose-locked frames, unless a clean control path
appears. Note xinsir's card: it was trained with **thicker skeleton lines** and
ships a replacement `draw_bodypose`; best at ~1024² SDXL buckets; swap in the
`sdxl-vae-fp16-fix` VAE for non-default bases.

### 3.2 Author poses synthetically — skip detectors

The key insight for our pipeline: **we do not need to detect poses from images.**
If poses come from a rig, we can rasterise the OpenPose skeleton (in xinsir's
thicker style), depth, normals, lineart and a flat ID mask *directly from the
rig* at exact pixel positions. Benefits: no detector weights to license or
provision, no detection errors, exact limb left/right identity (which the
fluidity pass needs for "dedicated left-hand peak"), and **ground-truth floor
pivot and support-foot flags per frame** for the manifest.

Options for authoring, in order of fit:

1. **Blender** (GPL tool; outputs are ours): one proxy rig per character with
   exact proportions (Mācron at .35 adult height; Gatekeeper silhouette). Keyframe
   on a timeline in beats (set scene FPS so 1 beat = N frames at reference BPM),
   mark keys/breakdowns with markers, and export only marked frames. A
   Python exporter writes control images + per-frame JSON (pivot, support foot,
   accent flag, beat position).
2. A 2D skeleton editor (e.g. an OpenPose editor node) — fast for single poses,
   but no volume/depth and no consistent pivots. Fine for crowd one-offs.
3. Mocap retarget onto the Blender rig, then **select** keys from it (§3.4).

### 3.3 Robot: puppet render → control

For Mācron, OpenPose is the wrong signal (no human skeleton; the head is half
the body). Use a low-poly proxy puppet (primitives: rounded box head with inset
screen plane, sphere antenna, capsule limbs, cuff ring on the anatomical right
forearm) and render per pose:

- **depth + normal** → ControlNet union (structure, volume, scale lock);
- **lineart** (Freestyle/outline pass) → ControlNet lineart (silhouette lock);
- **flat colour render** in the locked palette → img2img init at moderate
  denoise (≈0.35–0.6, to tune), so the generator paints *over* correct shapes
  rather than inventing them.

This deterministically fixes head-scale drift, antenna placement, cuff side and
rear/side views (the eight-view turn becomes a camera orbit, §6). For a small
toy robot, it is reasonable to evaluate whether a toon-shaded render + pixel
finish *without* diffusion is already good enough for breakdown frames, using
generation only for hero keys. Same for the antenna one-drawing lag: author it on
the rig.

### 3.4 Real dance motion sources — licences

| Source | Content | Licence (as found) | Use for shipped art? |
| --- | --- | --- | --- |
| CMU Graphics Lab mocap ([site](http://mocap.cs.cmu.edu/)) | ~2,600 clips incl. dance; a 2005 forum report mentions salsa clips (unverified) | Mirrors quote: "You may include this data in commercially-sold products, but you may not resell this data directly, even in converted form." The CMU page was **unreachable from here (connection reset)**; a 2024 FBX conversion on [4TU](https://data.4tu.nl/datasets/0448aab2-3332-449f-a8e2-d208cb58c7df) is tagged CC BY-NC | **Probably yes** (original CMU data, not the NC conversion) — confirm text on the live page first |
| AIST++ ([overview](https://google.github.io/aistplusplus_dataset/factsfigures.html), [api](https://github.com/google/aistplusplus_api), [paper](https://arxiv.org/abs/2101.08779)) | 1,408 sequences, 10 street genres (break, pop, lock, waack, hip-hop ×2, house, krump, street jazz, ballet jazz) — **no cumbia/salsa** | annotations CC BY 4.0, but download requires agreeing to the AIST Dance Video DB Terms of Use ([download](https://google.github.io/aistplusplus_dataset/download.html)), which I could not retrieve; the DB is described as free "for academic research". Motion is SMPL parameters — the SMPL body model has its own licence (not checked here; believed non-commercial) | **Not until the ToU and SMPL terms are read**; reference only |
| CoMPAS3D salsa duets ([HF](https://huggingface.co/datasets/Rosie-Lab/compas3d)) | 3 h improvised salsa, beginner→pro, SMPL-X | **CC-BY-NC-4.0**, "not for commercial use" | **No** — study only |
| Motorica Dance | 8 styles | research only, no commercial use without consent (per search results) | **No** |
| Mixamo ([FAQ](https://helpx.adobe.com/en/creative-cloud/faq/mixamo-faq.html)) | humanoid clips incl. several dances (salsa/samba-style) | royalty-free in games; no redistribution of raw files; reposted FAQ says Mixamo content may not be used to train ML models | Pose renders from Mixamo clips are likely OK as *conditioning*; **do not put Mixamo-derived frames into a LoRA training set** without legal review |
| Quaternius Universal Animation Library ([page](https://quaternius.com/packs/universalanimationlibrary.html)) | 120+ humanoid clips (locomotion, emotes) | **CC0** | Yes — walks/idles/claps; no confirmed dances |
| Our own capture | team dancing cumbia basics on phone video → pose estimation, or hand-keyed in Blender | ours (with performer consent) | **Best fit**: cumbia basic, side basic, turns, crowd claps |

Recommendation: **hand-key in Blender, using legally-viewable video/mocap as
reference only**, and optionally retarget CMU/Quaternius/Mixamo clips for walks
and generic motion. Cumbia vocabulary (basic back-step, side step, turns, the
characteristic shoulder/hip lilt) is absent from every permissive dataset found.
Variation comes from authored offsets (arm height, hip lilt amplitude, holds),
not from randomness — matching "increasing coordination comes from the authored
chart". Whatever the source, **sample keys at musical positions** (downbeat
extremes, off-beat passings) rather than exporting every mocap frame.

## 4. Temporal consistency for sequences

### 4.1 Why select keys rather than use every frame

Our renderer samples clips from conductor beats with unequal holds; a 1-beat
move needs ~3–5 drawings (prep, peak, follow-through, settle), not 30. Every
extra generated frame is an extra chance for identity/pixel drift (pixel art
shows single-pixel shimmer that blurred video hides), extra atlas memory (already
flagged as a budget risk) and extra review cost. Model-generated in-betweens are
a form of *generated interpolation*: evenly-timed, physically averaged motion is
exactly the "crossfade" look our doctrine bans. So: generate **chosen keys and
breakdowns only**, each as its own controlled image.

### 4.2 Grid-in-one-canvas trick

Generating 4–9 poses on one canvas makes them share attention and noise, so
identity matches better than separate images (an informal cousin of ConsiStory/
StoryDiffusion). It is how the current sheets were made — and why they overlap.
If used, make it controlled:

- build the control image as a fixed grid with **wide gutters**, one rig render
  per cell, identical floor baseline per cell, and a body that fits in a cell
  with margin for extended limbs;
- slice by the *known* control rectangles, never by detecting blobs;
- reject any cell whose alpha touches its gutter.

Trade-off: per-cell resolution drops (a 1024² canvas with 3×3 cells gives
~340 px per character before pixel finishing — fine for crowd at ~64–96 px
native, marginal for hero frames). Use 2×2 for heroes, 3×3/4×4 for crowd.

### 4.3 Video models and AnimateDiff

| Option | Licence | 24 GB fit | Doctrine fit |
| --- | --- | --- | --- |
| [AnimateDiff](https://github.com/guoyww/AnimateDiff) (SDXL beta motion module, ~13 GB; SparseCtrl is SD1.5-only) | Apache-2.0 (code/module; base inherits) | yes | poor — produces dense, evenly-timed frames; dated quality |
| [Wan 2.2](https://github.com/Wan-Video/Wan2.2) TI2V-5B / Animate-14B (motion copied from a driving video onto a character image) | Apache-2.0 | 5B "at least 24 GB" with offload; 14B needs quantisation (untested here) | candidate *harvester* only |
| [VACE](https://github.com/ali-vilab/VACE) (Wan2.1-VACE 1.3B/14B, reference-to-video + control) | Apache-2.0 | 1.3B yes | same |
| [HunyuanVideo](https://github.com/Tencent-Hunyuan/HunyuanVideo/blob/main/LICENSE.txt) | Tencent licence, **excludes EU/UK/South Korea** | — | **FORBIDDEN** (not on allowlist) |
| [LTX-Video](https://github.com/Lightricks/LTX-Video) (pose/depth IC-LoRAs) | code Apache-2.0; weight licence varies per checkpoint (README links OpenRail-M for 0.9.5) | — | unclear; not on any list |

Honest assessment: Wan-class models are the only route to *continuous body
mechanics* (weight shift, overlapping cloth) from a reference image + pose video,
and their Apache licence is shippable. But none are in our tiers, VRAM is tight,
and their output is interpolated motion at video resolution. If ever used, treat
them strictly as a **key-candidate harvester**: drive with the rig's pose video,
sample only the frames at the authored key/breakdown beat positions, then send
each sampled frame through the same pixel finish and studio review as any other
frame. Never ship contiguous video frames. Not recommended for the pilot.

## 5. Pixel-art finishing (deterministic, scriptable)

The finisher should be **our own small Python stage** (Pillow/NumPy, run
outside or inside ComfyUI as a custom node) so it is bit-reproducible and
reviewable. ComfyUI nodes are acceptable references/prototypes:

- [ComfyUI-PixelArt-Detector](https://github.com/dimtoneff/ComfyUI-PixelArt-Detector)
  (MIT, TOOL): palette loader (bundled Lospec palettes — good, since no egress),
  palette converter, k-means/median-cut reduction, colour cleanup threshold,
  wraps Astropulse's downscale. **No outline tool and no grid detection.**
- [K-Centroid](https://astropulse.itch.io/k-centroid) (Astropulse; MIT per a
  commenter, not verified in-repo, TOOL): per-tile k-means "dominant colour"
  downscale — better than nearest for downscaling noisy diffusion output.

Recommended finish, per frame:

1. **Generate on a flat key colour** excluded from every palette (e.g. pure
   #00FF00) and at an exact integer multiple of the native grid (e.g. native
   128 px tall × 8 = 1024). `pixel-art-xl` ([card](https://huggingface.co/nerijs/pixel-art-xl),
   **creativeml-openrail-m** → PROPOSE) advises "Downscale 8 times … use Nearest
   Neighbors", which aligns with this.
2. **Downscale by the integer factor** with mode/k-centroid per cell (not
   bilinear; plain nearest picks one noisy sample per cell and shimmers between
   frames).
3. **Quantise to the locked palette** for the character (fixed indices; the
   plum/pink recolour ramp reserved as specific indices, §7). No dithering for
   character sprites unless authored.
4. **Binary alpha**: everything that maps to the key colour → transparent;
   all else opaque. This removes the halos in §1. Colour-decontaminate edge
   pixels (re-quantise them to the nearest *non-background-tinted* palette entry).
5. **Cleanup**: remove orphan pixels / 1-px islands, enforce a 1-px outline in
   the outline palette entry, restore known landmark pixels from the rig ID mask
   (face screen, antenna orb, cuff) if the generator mangled them.
6. **Human touch-up** in a pixel editor for keys; breakdowns may ship untouched
   if review passes.

Background removal when a key colour is impossible (img2img from paintings):

| Tool | Licence | Status |
| --- | --- | --- |
| [BiRefNet](https://github.com/ZhengPeng7/BiRefNet) (general, matting, lite variants; Comfy-Org integration listed) | MIT (repo) | PENDING |
| [BEN2](https://huggingface.co/PramaLLC/BEN2) base | MIT | PENDING |
| [rembg](https://github.com/danielgatis/rembg) | MIT code, **but its default session is `bria-rmbg`**, and weights "carry their own licenses" | TOOL — only with an explicitly pinned allowed session (e.g. `birefnet-general`); downloads on first use, so pre-provision |
| [RMBG-2.0](https://huggingface.co/briaai/RMBG-2.0) / 1.4 | CC BY-NC 4.0 | **FORBIDDEN** |

Even with ML matting, binarise alpha after quantisation; soft mattes are what
produce coloured rims at nearest-neighbour scale.

## 6. Turnarounds / multi-view (8 views)

The fluidity pass requires eight real turn views, not mirrored swivels.

- **Recommended: 3D proxy orbit.** Render the puppet/rig at 0°, 45°, …, 315°
  (same pivot, same scale), push each through §3 control + identity. Deterministic,
  exactly eight views, and the views share proportions by construction.
  Mirroring is allowed only for genuinely symmetric views and never for Mācron's
  asymmetric cuff.
- [MV-Adapter](https://github.com/huanngzh/MV-Adapter) (Apache-2.0 code; SDXL;
  6 views; image→multiview ~14 GB; geometry-guided from a mesh; ComfyUI node
  available): weight licence not confirmed on the README → PROPOSE after check.
  Six fixed views ≠ our eight; useful to *bootstrap* a turnaround sheet for LoRA
  data, not as runtime frames.
- [Zero123++](https://github.com/SUDO-AI-3D/zero123plus): code Apache-2.0 but
  **weights CC-BY-NC 4.0** ("not … in a commercial product pipeline") →
  **FORBIDDEN**. Also fixed 30°/90°/… azimuths, not ours.
- Qwen-Image-Edit-2511 / FLUX.2-klein-4B (PENDING): "show this character from
  the back" edits are a fast way to get a first rear view for the LoRA set;
  unverified for exact proportion preservation — always check against the proxy.

## 7. Crowd variation at scale

The styleguide fixes the combinatorics: **3 silhouettes × 4 outfits = 12 guests**,
only the reserved plum/pink cloth ramp varies, chair is a separate prop.

- **Generate once per silhouette, recolour at runtime.** Produce each pose set
  in the canonical plum ramp; outfits are palette-index swaps (engine side), not
  separate generations. This multiplies variety without multiplying drift or
  atlas memory. The quantiser (§5.3) must *guarantee* cloth pixels land on the
  reserved indices and that no skin/hair/chair pixel does — validate with a
  per-frame histogram check; a single stray reserved index on skin breaks
  recolouring.
- **Identity per silhouette**: fixed seed per (silhouette, clip, frame), one
  IP-Adapter reference set, later one LoRA per silhouette. Seeds are not
  portable across model/ComfyUI versions; pinning them gives reproducibility,
  not identity.
- **Loops to author on the rig** (beats from `plan/crowd-animation-system.md`):
  seated idle A/B, notice/look, seated foot tap, lean forward, **stand-up and
  sit-down transitions** (mandatory, 4 drawings each, chair-contact frame
  explicit), standing idle, step-touch, **clap with a visible contact frame**,
  cheer A/B. Render with the chair as an occluding proxy in the depth control
  (so the body sits *on* something) but key it out / mask it from the output —
  actor sheets must contain no chair.
- **Grid generation** (§4.2) is most appropriate here: crowd sprites are small,
  so 3×3/4×4 controlled grids per silhouette are efficient.
- **Phase/variation** is runtime (phase offsets, attention ranks), not more
  drawings.

## 8. Provenance and reproducibility

- ComfyUI embeds `workflow` and `prompt` JSON in PNG text chunks
  ([docs](https://docs.comfy.org/development/api-development/workflow-metadata)),
  but "any operation that rewrites the file may remove or replace the metadata",
  and it **does not include model files, input assets or custom nodes**. Our
  finisher rewrites every file, so **store a sidecar record**, not just chunks.
- Headless batching: POST `{"prompt": <API-format graph>}` to `/prompt`
  (returns `prompt_id`), watch `/ws`, fetch results from `/history/{id}` and
  `/view`; validate node availability via `/object_info`
  ([routes](https://docs.comfy.org/development/comfyui-server/comms_routes),
  [example](https://github.com/Comfy-Org/ComfyUI/blob/master/script_examples/basic_api_example.py)).
  Keep workflows in the repo in **API format** with named placeholder inputs
  (seed, prompt, control image paths, LoRA strength) filled by the batch driver.
- Per-frame sidecar (extends today's `provenance.json`, which only records
  "built-in imagegen" and a prompt): workflow JSON hash, ComfyUI version/commit,
  custom-node commits, **sha256 of every model file** (ComfyUI does not record
  this; hash the read-only cache once and look up), model licence + status from
  §0, seed, sampler/steps/CFG, control image hashes, rig file + action + frame,
  finisher version + palette id, reviewer verdict and date.
- **Base-model licences for a commercial-possible game**:
  SDXL base / SDXL-Lightning — openrail++ (ALLOWED; use-based restrictions apply
  to the *model*, outputs are ours). FLUX.1-schnell — Apache-2.0 (ALLOWED soon).
  FLUX.1-dev — its licence lets you use Outputs commercially but restricts the
  *model* to non-commercial use and forbids "commercial or production purposes"
  (§2(a)–(b), §4(a)(i)); producing shipped game art is production use →
  FORBIDDEN, as the forge rule says. FLUX.2-klein-4B, Qwen-Image-Edit-2511,
  Z-Image ([repo](https://github.com/Tongyi-MAI/Z-Image), Turbo/Base released;
  Edit "to be released"; no official ControlNet) — Apache-2.0, PENDING.
- LoRAs/fine-tunes inherit the base licence; a LoRA trained on SDXL stays
  openrail++. A LoRA trained on any dev-derived base is forbidden regardless of
  our data.
- ComfyUI itself and IPAdapter_plus / experiments are GPL-3.0 tools; they run
  locally and are not shipped, so GPL does not reach the game binary.

## 9. Recommended end-to-end pipeline

```text
 CHOREOGRAPHY (repo, authoritative)
   chart + ChallengerChoreography beats ─► clip spec per character:
   [{clip, beat, role: key|breakdown|smear, supportFoot, accent, holdBeats}]
          │
 POSE AUTHORING (Blender, offline)
   proxy rig/puppet per character (exact proportions, .35 rule for Mācron)
   hand-keyed cumbia/social motion; optional CMU/Quaternius/Mixamo retarget
   export ONLY marked key/breakdown frames ─► per frame:
     openpose(thick).png | depth.png | normal.png | lineart.png | flatcolor.png
     idmask.png | frame.json {pivotPx, supportFoot, view(0..7), beat}
          │
 GENERATION (ComfyUI :8188, API mode, batch driver)
   I1 SDXL-Lightning (or SDXL base for finals)
   + ControlNet  human: openpose(+depth)   robot: depth+normal+lineart
   + identity    IP-Adapter Plus refs  → later character LoRA
   + img2img from flatcolor (robot / crowd)          key-colour background
   2×2 grid for heroes, 3×3–4×4 for crowd, fixed cell rects
          │
 MATTE + PIXEL FINISH (deterministic script, versioned)
   slice by known rects ─► key-colour alpha (BiRefNet/BEN2 if pending→approved)
   integer k-centroid downscale ─► locked palette (+reserved plum ramp)
   binary alpha, decontaminate, orphan cleanup, 1-px outline, landmark restore
          │
 SLICE + MANIFEST
   pivot = rig pivot (never image-guessed); fixed cell size per atlas;
   pack atlas; manifest.json: clip, frame order, beat offsets, holds,
   supportFoot, accent, pivot, reducedMotionPose, palette regions, provenance id
          │
 STUDIO REVIEW (web studio lane)
   playback sampled from beats at each shipped BPM, native + NN-enlarged,
   pivot/baseline overlay, onion-skin of previous key, per-frame approve/reject
   with reason codes (identity, scale, foot slide, limb identity, pixel noise)
   approved ─► repo assets + LoRA dataset v(n+1);  rejected ─► reseed / fix rig
```

## 10. Pilot recommendation and open questions

Pilot = Mācron 6–8-pose groove + 8-view turn, then Gatekeeper walk/clap, matching
`plan/dance-fluidity-pass.md`. Measure: per-frame identity score (human), pivot
error (should be 0 by construction), palette violations (0), review pass rate.

Uncertain / to test:

1. ControlNet + IP-Adapter strength at Lightning 4-step/CFG 0 vs SDXL base 25 steps.
2. Whether toon-render + finish alone suffices for Mācron breakdowns.
3. CMU live terms text; AIST Dance DB ToU; SDXL `h94/IP-Adapter` and MV-Adapter
   weight licences; K-Centroid licence in-repo.
4. Flux-schnell LoRA trainability and any non-dev schnell pose control.
5. Native grid size per character (needs `party_layout.dart` projection numbers
   at the performance marks; staging pass cites ~114–215 px at 360×640).
6. Reconciliation with the Tillandsias `local-image-generation` and
   `web-studio-lanes` specs (not readable from this workspace).
