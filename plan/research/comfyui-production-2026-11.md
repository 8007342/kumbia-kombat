# How practitioners use ComfyUI for consistent game characters and sprites

Researched 2026-11-04 for Kumbia Kombat (96x120 pixel-art dancers, 64 drawings per
character, SDXL at 768x960). Practical recipes are in `plan/comfyui-cheatsheet.md`, and the
target pipeline is in `openspec/changes/comfyui-studio-pipeline/`.

## Summary

- **Our graph has one concrete fault and one structural one.** The fault is that IP-Adapter
  applies the reference's composition at full strength, whatever weight we set. The
  structural one is that we ask one sampling pass to get everything right, including a face
  only about 15 native pixels wide.
- **Practitioners split the work by job.** ControlNet carries pose, a reference or LoRA
  carries appearance, later passes fix regions, and deterministic steps end the chain. That
  division is widely repeated, though mostly by guides rather than by studios.
- **Pixel-art pipelines treat the model as a source of raw material.** Every serious one
  ends in a deterministic step that puts the result on a grid with a controlled palette.
- **Partial assets are supported only in a narrow form.** Rigid parts such as head and hat,
  and pixel-aligned overlays, have precedent. AI layer decomposition and limb-level paper
  dolls do not fit 96x120. Our Blender rig already gives exact per-frame region masks, so
  we don't need decomposition.
- **The evidence is thin at the top.** I found no studio postmortem with production numbers.
  The best material is official docs, node authors' READMEs and source, and two open
  community pipelines.

## How to read this

Each claim is labelled:

- **[S]** a source states it, and the link follows.
- **[O]** observed in our own studio, repo or runs.
- **[I]** my inference. Treat it as a hypothesis to test.

Numbers marked as defaults are tool defaults, not tested recommendations.

### Research limits

- `WebSearch` worked. `WebFetch` failed on every attempt (`read ECONNRESET`).
- `curl` reached only `raw.githubusercontent.com`, `api.github.com`, `huggingface.co`, the
  ComfyUI examples site and one project page. Blogs, wikis, arXiv, itch.io and
  docs.comfy.org were not directly readable.
- I read docs.comfy.org through its source repo, [Comfy-Org/docs](https://github.com/Comfy-Org/docs),
  and cite the published URL. Published pages could differ slightly from that source.
- Anything known only from a search snippet is marked in the register at the end. I did not
  watch any videos, so Latent Vision, Nerdy Rodent and Pixaroma are unassessed.
- Reading official templates through the studio's `/templates/` route was read-only, and I
  saved nothing and ran nothing.

## 1. Multi-pass structure

### What sources state

- **Hires fix is one thing.** Generate low, upscale, then img2img. ComfyUI has no separate
  txt2img: it is the same node with an empty latent at maximum denoise.
  [S: official example](https://comfyanonymous.github.io/ComfyUI_examples/2_pass_txt2img/)
- **Denoise and steps.** ComfyUI builds a schedule of `steps / denoise` steps, rounded down,
  and runs the last `steps`. Lower denoise means staying closer to the input, not fewer
  steps. [S: docs](https://docs.comfy.org/tutorials/basic/image-to-image)
- **Why crop for detail passes.** Upscaling a crop before sampling generates more detail,
  downscaling a large area avoids doubled bodies, and unmasked pixels never go through the
  VAE. Use `InpaintModelConditioning` rather than `VAEEncodeForInpaint` to get denoise below
  1. [S: Crop and Stitch README](https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch)
- **Non-inpainting models can inpaint.** [S: official example](https://comfyanonymous.github.io/ComfyUI_examples/inpaint/)
- **Tool defaults for a face pass:**
  - ADetailer: denoise 0.4, padding 32, mask blur 4, dilate 4.
    [S: `args.py`](https://github.com/Bing-su/adetailer/blob/main/adetailer/args.py)
  - Impact Pack FaceDetailer: denoise 0.5, guide size 512, max size 1024, feather 5.
    [S: `impact_pack.py`](https://github.com/ltdrdata/ComfyUI-Impact-Pack/blob/Main/modules/impact/impact_pack.py)
  - Impact's own docs chain two FaceDetailers for a two-pass setup.
    [S: README](https://github.com/ltdrdata/ComfyUI-Impact-Pack)
- **Hires default.** A1111's second-pass denoise slider defaults to 0.7.
  [S: `ui.py`](https://github.com/AUTOMATIC1111/stable-diffusion-webui/blob/master/modules/ui.py)
- **Why faces need their own pass.** Guides say small faces in a 1024x1024 SDXL image often
  don't render correctly. This came from search-result summaries, so I can't pin it to one page.
- **Identity drift in detail passes.** A troubleshooting table in the same search results
  suggests lower denoise and a smaller region. Same caveat.
- **SDXL's preferred size is about 1 MP.** [S: official example](https://comfyanonymous.github.io/ComfyUI_examples/sdxl/)
- **Union ProMax does more than structure.** Its card shows tile and inpainting uses
  [S](https://huggingface.co/xinsir/controlnet-union-sdxl-1.0), and `SetUnionControlNetType`
  offers `tile` and `repaint` [O].

### What we observed

- At 8x the face is **about 15 x 10 to 13 native pixels**, and the hat about 31 x 10 to 14.
  Measured on the rig's regions for `groove.down_l`, `left_hand.peak` and
  `finish_turn.turn_in`. At 768x960 the face is therefore about 120 x 100 canvas pixels, or
  15 x 13 latent cells [O].
- Lowering denoise from 0.7 to 0.56 kept the painted stripes and mustache but flattened the
  faces, because the proxy has almost no face to keep
  (`art_runs/gk-style-20261104c/review/style-test.png`) [O].
- The same denoise can vary a lot by seed. See the grid measurement in section 3 [O].

### Inference: recommended order for this project

| Order | Pass | Denoise | Why |
|---|---|---|---|
| 1 | Base: whole figure, rig proxy as init, controls, masked references | 0.6-0.7 now; lower as the proxy gains detail | Establishes form and shading; 0.7 is our only tested good value |
| 2 | Region passes: hat, shirt, by rig mask, same canvas | 0.3-0.4 | Corrects drift without moving the silhouette; no crop needed for large regions |
| 3 | Head: crop window, upscaled, stitched back | 0.4-0.5 (from the tool defaults above) | Only if the head is generated at all; see section 4 |
| 4 | Optional edit-model repair of flagged frames | n/a | Section 2 |
| 5 | Matte, colour match, grid and palette finish | none | Deterministic, so the same inputs give the same bytes |

**Colour goes last, and outside the sampler.** I found no source that ranks colour stages for
sprites. Our design D7 already does per-region matching in Python, and I would keep it: the
core `ColorTransfer` node works on whole-image statistics, and pose changes those statistics.

**Hires fix does not map onto us.** [I] The 8x rule ties the canvas to the native size, and
there is no upscale model on disk (`UpscaleModelLoader` lists nothing) [O]. A true hires
stage would break the grid, so our second pass runs at the same resolution.

**Crop passes conflict with the pixel LoRA.** [I] Pixel Art XL paints an 8-pixel grid on
whatever it samples. In a head crop upscaled 3x, those "pixels" are about a third of a native
pixel, and they won't survive the finish. Test the head pass with the LoRA reduced or off,
and let the finish make the pixels. Nothing I read covers this case, so it's a question for
our own tests.

## 2. Character consistency across many frames

### IP-Adapter

From [cubiq's README](https://github.com/cubiq/ComfyUI_IPAdapter_plus),
[`NODES.md`](https://github.com/cubiq/ComfyUI_IPAdapter_plus/blob/main/NODES.md) and
`IPAdapterPlus.py`, read directly [S]:

- Reference images should be square, and other shapes are centre-cropped.
- `linear` starts around 0.8; other weight types can go higher.
- `attn_mask` should match the latent's aspect ratio. White gets full influence, black none,
  and grey is allowed.
- `start_at` above 0 gives very light conditioning, since early steps matter most.
- `style transfer` is described as transferring style but not content.
- On SDXL, `style transfer` applies only to block 6 and `composition` only to block 3.
- FaceID needs `insightface`, its own model and usually a paired LoRA.
- The repo has been in maintenance-only mode since 2025-04.

[InstantStyle](https://github.com/InstantStyle/InstantStyle) is the research behind the
block-level split [S, partly read].

**A fault in our current graph** [S+O]: `style and composition` maps to
`{3: weight_composition, 6: weight}`. `IPAdapterAdvanced` does not expose
`weight_composition` (confirmed in our `object_info`), and it defaults to 1.0 in the source.
So our graph's "0.7" means **style 0.7 and composition 1.0**: the reference's layout is
pushed at full strength against the pose controls. I read the upstream `main` source, not the
studio's installed copy, so confirm the installed version matches.

**Our reference is also weak by construction.** It is 198x310, so a square crop cuts the hat
and shoes [S+O; D7 lists this as untested]. With CLIP vision at 224x224
[Snippet](https://runcomfy.com/comfyui-workflows/create-consistent-characters-in-comfyui-with-ipadapter-faceid-plus),
a full-figure reference gives the face very few input pixels [I].

**Recommended test** [I]:

- Drop the composition route; ControlNet already carries pose.
- Use two chained adapters. Task 5.3 proved masks bind and take effect [O].
- Head crop on the head mask. Try `linear` at 0.5-0.8 against `style transfer`.
- Outfit crop on the body mask. Note the current D7 says `style transfer` for both, and
  style-only may not carry shirt pattern or facial features at all.

**FaceID does not apply.** [I] It depends on a face detector built for human faces, its
models aren't on our disk, and a stylised 15-pixel face gives it nothing to hold. Its
recognition models also carry their own licence terms, which I did not review. The
`ip-adapter-plus-face_sdxl_vit-h` file is the only face-specific candidate, is not on disk,
and I would not request it until the head-crop test has run.

### Model sheets as references

- Comfy ships official turnaround templates: `templates-1_click_multiple_character_angles-v1.0`
  and `template_qwen_multiangle.app` use Qwen-Image-Edit-2511 plus Lightning and a multi-angle
  LoRA [O: installed templates]. Neither LoRA is on our disk.
- Qwen's card says new viewpoints now work with the base 2511 model.
  [S](https://huggingface.co/Qwen/Qwen-Image-Edit-2511)
- `templates-character_sheet` uses a paid Gemini API node [O], so it's not usable here.
- Our task 6.1, the model sheet, is still open, and identity still comes from
  `gatekeeper-v2.png`, which the owner has said is not a target [O].

### Trained LoRAs

- Guides agree that LoRAs are the tool for a recurring character, with reference adapters for
  faster work. They disagree on strength: [0.4-0.6](https://www.media.io/image-tips/comfyui-consistent-characters.html)
  and [1.0-1.2 for sprites](https://www.apatero.com/blog/comfyui-character-consistency-advanced-workflows-2026).
  Both are snippet-only, SEO-style guides, so treat the numbers as anecdote.
- A named artist's 2026 write-up trains an SDXL LoRA on curated, hand-corrected references,
  then uses it with ControlNet and IP-Adapter.
  [Snippet: Ian Steplowski](https://www.artstation.com/artwork/41Nenn)
- `TrainLoraNode`, `MakeTrainingDataset` and `SaveLoRA` are **core nodes in our studio** [O],
  so "no trainer exists" in the sprite pipeline's proposal may be out of date. Whether they
  are pinned for `run_workflow` is unknown, and the owner's decision stands: wait for the
  proof clips.
- [I] Our best dataset would be owner-accepted frames plus the model sheet, once they exist.
  I expect this to be the strongest consistency step available, but it depends on those.

### Edit models as consistency editors

- **Qwen-Image-Edit-2511:** the card highlights reduced drift and better character
  consistency, at 40 steps with `true_cfg_scale` 4.
  [S](https://huggingface.co/Qwen/Qwen-Image-Edit-2511) Comfy's template uses 40 steps, CFG 3,
  euler/simple, shift 3.1, `CFGNorm` 1 and `index_timestep_zero` [O]. These are the vendor's
  claims, on photographic examples.
- **FLUX.2 klein 4B:** distilled, 4 steps, CFG 1, euler, `Flux2Scheduler`, `ReferenceLatent`
  [O: template]; up to 4 references through BFL's API
  [Snippet](https://docs.bfl.ai/flux_2/flux2_image_editing).
- **The only sprite-specific evidence** is
  [Pixel Studio's PR #4](https://github.com/bunnyUFO-lab/pixel-studio-comfyui-workflows/pull/4),
  from one developer with a young repo (5 stars). It reports 96 benchmark jobs, with every
  edit passing its pixel-art check and 2511 at 4 steps winning blind picks for recolours and
  directions. The blind-pick data isn't public. Two practical points from it:
  - Transparent backgrounds reached the model as black, and it drew a dark checkerboard. So
    upscale by an integer factor onto a flat background first.
  - Its [sprite-edit builder](https://github.com/bunnyUFO-lab/pixel-studio-comfyui-workflows/blob/main/tools/build_pixel_sprite_edit.py)
    edits a roughly 1024-pixel upscale, then re-pixelates on the sprite's own grid with its
    palette, and restores the original canvas. This is the most copyable idea I found.
- **Caveats for us** [O]: that repo marks its 2511 workflows as needing ComfyUI 0.41, and we
  run 0.40.0. Comfy's own 2511 template is installed here, so basic use should work. The
  Lightning LoRA for 2511 is not on disk, so we'd run 40 steps until one is approved. The
  [Lightning repo](https://huggingface.co/lightx2v/Qwen-Image-Lightning) is Apache-2.0.
- **Pose transfer:** a guide feeds character, cleaned pose reference and skeleton into 2511,
  and warns that an uncleaned reference leaks hair and face into the output.
  [Snippet](https://myaiforce.com/qwen-image-edit-pose-transfer/)

**Inference:** use edit models for two jobs, not as the default frame path: producing the
model sheet, and repairing frames flagged by selection scoring. Running 64 frames through a
model trained for general editing would add a new source of drift, and I found no evidence
that it holds across a 64-frame set.

### Video models

- [mor-o/comfyui-2d-character-pipeline](https://github.com/mor-o/comfyui-2d-character-pipeline)
  (MIT, 120 stars, tuned for 24 GB) drives sprite sheets from Wan i2v plus BiRefNet. It was
  verified on one idle animation by its author, as a work in progress.
- Its author tried Wan Animate for cosmetics and **rejected** it: DWPose couldn't represent
  subtle motion and the model hallucinated legs. VACE inpainting replaced it because it keeps
  pixels outside the mask. [S: overview](https://github.com/mor-o/comfyui-2d-character-pipeline/blob/main/docs/pipeline-overview.md)
- Pixel Studio animates with Wan or LTX, then re-pixelates with stability and deflicker
  settings. [S: skill doc](https://github.com/bunnyUFO-lab/pixel-studio-comfyui-workflows/blob/main/.claude/skills/pixel-art/SKILL.md)
- Comfy's VACE tutorial reports about 7 minutes for 49 frames at 640x640 on a 4090, and the
  reference works best when it lines up with the control's first frame.
  [S: VACE](https://docs.comfy.org/tutorials/video/wan/vace),
  [Fun Control](https://docs.comfy.org/tutorials/video/wan/wan2-2-fun-control)
- The installed VACE templates are for Wan 2.1 (4 steps, CFG 1, uni_pc, shift 8) [O]. **I
  found no official template for our Wan 2.2 VACE Fun files**, so their settings are unsourced.
- Nothing I found compares a video route with stills on pixel-art sprites at this size.

**Inference:** this is the only approach with temporal coherence built in, and it deserves
the one bake-off D11 already allows. It stays out of the default path because our drawings are
authored poses rather than continuous footage, and the owner picks at drawing level.

## 3. Pixel-art-specific workflows

### What sources state

- **Generate big, reduce.** [Pixel Art XL](https://huggingface.co/nerijs/pixel-art-xl) says to
  downscale 8x with nearest neighbour and use a fixed VAE (0.9 or fp16-fix). It also says no
  refiner and no trigger word are needed, and that it works with VAE 0.9 and 1.0 [S].
- **Purpose-built models use cleanup too.** Retro Diffusion is a tuned model with colour tools
  around it. [Snippet: profile](https://medium.com/curiouserinstitute/ai-art-profiles-cody-claus-retro-diffusion-8cb9f45e939a)
  Its author's open tools are [pixeldetector](https://github.com/Astropulse/pixeldetector) for
  grid recovery and [sd-palettize](https://github.com/Astropulse/sd-palettize) for k-means
  palettes [S].
- **Deterministic repair is its own tool category:**
  - [unfake.js](https://github.com/jenissimo/unfake.js) detects scale, snaps to the grid,
    downscales with `dominant` or `median`, quantises to fixed palettes, and cleans up
    morphologically and along jaggies [S].
  - [PixelOE](https://github.com/KohakuBlueleaf/PixelOE) expands outlines by contrast before
    reducing so thin features survive. It uses classical image processing, and it's Apache-2.0
    with a CLI [S].
  - Pixel Studio ends every pixel workflow with a pass/fail "Pixel Art Check" [S].
- **Hand finishing.** Guides say true pixel art may still need dedicated tools.
  [Snippet](https://apatero.com/blog/generate-clean-spritesheets-comfyui-guide-2025)
- **Clusters.** Pixels should read as groups of one colour and purpose.
  [Snippet: slides, not SLYNYRD](https://de.slideshare.net/speckandtech/pixel-art-simple-shapes-for-better-designs)
  I could not read SLYNYRD's blog itself.
- **Dead Cells** is the shipped precedent for rig-first pixel art: 3D models, converted to
  pixel animation by an in-house tool, to avoid hand-drawing each retake.
  [Snippet: Game Developer reprint](https://www.jikguard.com/news/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-dead-cells),
  [Snippet: 80.lv](https://80.lv/articles/case-study-dead-cells-character-art-pipeline/)

### What we measured

On raw frames in `art_runs/gk-style-20261104c/raw/` [O]. This is a small sample of four poses,
two seeds and two denoise values:

- **The grid is already right.** The best 8x8 alignment offset was (0, 0) on all 12 frames I
  tested for it. The 8x rule matches SDXL's 8x latent, so one native pixel is one latent cell
  [I for the cause]. We don't need grid detection for SDXL output, though edit models may differ.
- **Lower denoise gives cleaner cells.** The share of near-uniform foreground cells was 60-69%
  at denoise 0.56 and 36-46% at 0.7, using a variance cutoff I chose arbitrarily. I excluded one
  0.7 frame whose lighter background broke my foreground test. The cutoff affects the numbers,
  but the gap between the two groups is clear in this sample.
- **Centre sampling is rarely badly wrong.** Across all 16 frames, the centre pixel differed from
  the cell's median by more than 30 (summed RGB) in 0.3-4.9% of foreground cells, which is up to
  about 120 cells per frame. These are likely to fall on edges, though I did not map them.

**Inference:** moving `finish.sample` from `centre` to `majority` is cheap and worth doing, but
it is a modest gain. I suspect messy edges owe more to the matte, because BiRefNet's alpha is
soft (about 13,000 edge pixels, task 5.5 [O]) and is then cut at 128. The rig's silhouette gives
us a clamp most pipelines don't have: keep the matte only within a slightly dilated rig mask.
The uniform-cell measure could also serve as a free candidate score, and the denoise result gives
another reason to lower base denoise once the proxy carries enough detail.

**Palette:** we already lock it, and that is what the sources point to. Per-region ramps (D13)
go further than anything I read. Don't use `ImageQuantize` for the final palette, since it only
takes a colour count and so builds an adaptive palette [O: its inputs].

**VAE check:** the LoRA card asks for a fixed VAE, and our graph uses the checkpoint's. A
`sdxl_vae.safetensors` file exists [O], but I don't know which version it is. An A/B on edge
quality is cheap.

## 4. Partial assets for runtime composition

### What practitioners do

- **Layered sprites are an established game technique, using hand-authored sets:**
  - Stardew Valley's farmer is 16x32 per frame. A base holds head, torso and boots, with arms,
    pants, shirts, hair and accessories drawn in a fixed order. Regions are recognised by colour,
    and placement is tied to the animation.
    [Snippet: modding wiki](https://stardewvalleywiki.com/Modding:Farmer_sprite)
  - The [LPC generator](https://github.com/liberatedpixelcup/Universal-LPC-Spritesheet-Character-Generator)
    composes community parts on a shared sheet layout [S].
  - Commercial packs use identical sheet layouts so parts can swap.
    [Snippet: itch.io modular listings](https://itch.io/game-assets/tag-modular/tag-sprites)
- **Known failure modes:**
  - Weapons must switch between in front and behind during some animations, and a buyer reports
    a sword that doesn't align with hands and spills into neighbouring frames. Both come from
    pack pages in search results; I didn't keep the exact page for each.
    [Snippet: itch.io modular listings](https://itch.io/game-assets/tag-modular/tag-sprites)
  - Draw-order management gets tedious quickly.
    [Snippet: Elliot Bentine](https://medium.com/@elliotbentine/pixelizing-3d-objects-b55ec33328f1)
  - Hats may need alternative hair art, as in Stardew.
    [Snippet: wiki mirror](https://ru.stardewvalleywiki.com/%D0%A1%D0%BB%D1%83%D0%B6%D0%B5%D0%B1%D0%BD%D0%B0%D1%8F:%D0%A1%D1%80%D0%B0%D0%B2%D0%BD%D0%B5%D0%BD%D0%B8%D0%B5_%D0%B2%D0%B5%D1%80%D1%81%D0%B8%D0%B9/13001)
- **The closest AI pipeline** is
  [mor-o's](https://github.com/mor-o/comfyui-2d-character-pipeline/blob/main/docs/workflow-4-cosmetic-inpaint.md).
  It outputs a base sheet and cosmetic sheets that stack pixel-for-pixel. It needs per-frame
  masks, and rejected or deferred five simpler masking approaches, largely because it has no
  rig (that last reason is my reading). It also says silhouette-changing cosmetics remain unsolved. It's built for greyscale,
  tintable sprites, and it's a work in progress at larger sizes than ours [S].
- **AI decomposition is real, but for a different purpose:**
  - [Qwen-Image-Layered](https://github.com/QwenLM/Qwen-Image-Layered) (Apache-2.0) splits an
    image into RGBA layers, best at 640 px. Its prompt is not meant to control what each layer
    holds [S]. The template is installed, but **the model isn't on disk** [O].
  - [See-through](https://github.com/shitagaki-lab/see-through) makes up to 23 semantic layers
    from one anime illustration, for 2.5D rigging [S]. A hands-on reviewer found it isn't
    instant Live2D. [Snippet](https://lilting.ch/en/articles/see-through-anime-layer-decomposition)
  - [Bunraku](https://arxiv.org/html/2607.27348v1) adds meshes and keyposes on Qwen-Image-Layered.
    [Snippet]
  - All of these work on one high-resolution still, not on 64 poses at 96x120 [I].
- **LayerDiffuse:** the [ComfyUI port](https://github.com/huchenlei/ComfyUI-layerdiffuse)
  supports SD1.5 and SDXL only, and needs dimensions that are multiples of 64 for RGBA. Our 768x960
  fits. In our tests it gave no useful separation from a proxy or empty latent, and
  `LayeredDiffusionDecodeRGBA` is now refused `node_not_pinned` (task 5.5) [O]. It covered one
  pose on SDXL, so it isn't conclusively dead, but the owner has already accepted BiRefNet.

### Where it breaks at 96x120

These are my inferences, from the sources above and our sample:

- **Rotation.** A pixel-art part can't be rotated arbitrarily without wrecking its clusters.
  Head tilt needs its own drawing, not a transform.
- **Sub-pixel motion.** Anchors snap to whole pixels. A short neck offers little room to hide a
  1-pixel jump, and head bob can read as jitter.
- **Seams.** A one-pixel outline must join across each part, and any mismatch shows at this size.
  Limbs cross and overlap too often in a dance set for arm-level parts to work.
- **Occlusion.** A raised hand passes over the hat in `left_hand.peak`, so draw order changes per
  frame.
- **Lighting.** A head drawn once won't pick up the body's shading in each pose. It only works
  with flat shading and shared ramps, which we have.
- **Silhouette garments.** Coats and aprons change the outline and must follow the motion, so they
  aren't simple overlays. mor-o reports the same limit.

### Verdict

The findings **do support partial assets, in one narrow form**, and do not support the full
paper-doll idea:

1. **Head-and-hat parts, composed at build time.** A small library of native-resolution heads, one
   per bucket of `head_turn`, `head_nod` and `head_side`, is composited into each frame. The rig
   provides placement and the visible-region mask, so a hand in front stays in front with no z-order
   logic at all. [I] This turns an unsolved generation problem (a stable 15-pixel face across 64
   frames) into a small authoring problem: on the order of 15 drawings to accept, or to hand-correct,
   rather than 64. The poses need counting to confirm that figure.
2. **Rig-masked overlays for later variants.** Hats, gloves and chains are the owner's stated future
   pass. The mask of a garment's region in masked mode defines an overlay directly. Coats that change
   the silhouette need whole-frame variants.
3. **Runtime composition stays optional.** The same data (part, anchor, order per frame) can later
   feed a Flutter compositor. Build-time baking comes first because it needs no game change and can
   be judged in the existing review flow.

**Not supported:** AI decomposition of frames, limb-level parts, or hand and arm layers. No source
shows these working at this size, and our rig already gives what decomposition would provide.

**Unproven:** no source demonstrates this head-library approach with AI art at this size. Stardew's
separately drawn parts are the nearest precedent, so it needs a test on one clip.

## 5. Engineering practice

### What sources state

- **Two formats.** Save format reopens with layout, while API format omits layout, colours and groups.
  API JSON can be loaded in the UI, but without layout.
  [S: docs](https://docs.comfy.org/development/api-development/workflow-api-format)
- **Workflow schema** is versioned JSON. [S: docs](https://docs.comfy.org/specs/workflow_json)
- **Subgraphs** need frontend 1.24.3 or later; publishing as a blueprint needs 1.27.7 or later. They
  can be unpacked back to nodes. [S: docs](https://docs.comfy.org/interface/features/subgraph)
  Blueprints use native subgraph format under `definitions.subgraphs` and are served at
  `/global_subgraphs`.
  [S: docs](https://docs.comfy.org/custom-nodes/subgraph_blueprints),
  [S: templates repo](https://github.com/Comfy-Org/workflow_templates/blob/main/docs/BLUEPRINTS.md)
  Our studio's list has 116 [O].
- **Userdata.** `GET /userdata?dir=workflows` lists files; `POST /userdata/{file}` saves one, with
  `overwrite=false` to refuse clobbering, and the path is URL-encoded.
  [S: routes](https://docs.comfy.org/development/comfyui-server/comms_routes),
  [S: `user_manager.py`](https://github.com/comfyanonymous/ComfyUI/blob/master/app/user_manager.py)
  The list was empty when I checked [O].
- **Versioning.** Vendors say production teams keep both formats and pin ComfyUI, nodes and model hashes.
  [Snippet: Runflow](https://www.runflow.io/blog/comfyui-api-developer-guide). The official docs don't
  discuss version control.
- **Exemplars of generated workflows:**
  - Pixel Studio generates **UI-format** JSON from Python (`tools/comfy_workflow.py`), with a `READ ME`
    note in each workflow, and colours for inputs, prompts and key settings. It converts UI to API using
    `/object_info`, checked against the frontend's own `graphToPrompt`. Its authors say to keep repo
    workflows flat because their converter doesn't expand subgraphs.
    [S](https://github.com/bunnyUFO-lab/pixel-studio-comfyui-workflows/blob/main/.claude/skills/comfyui/SKILL.md)
  - mor-o ships API format only and says this leaves the graph without a usable layout, which is the
    trade-off the owner wants to avoid [S].
  - A community script flattens subgraphs for headless conversion.
    [Snippet](https://huggingface.co/aleph65/ComfyUI/raw/main/workflows/scripts/convert_workflow.py)

### What applies to us

- `run_workflow` runs API JSON, and overrides reach only `$seed`, `$prompt`, `$negative_prompt`, plus
  named image inputs [O].
- **`object_info` is not the allowlist.** `run_workflow` also refuses classes that aren't pinned, as
  `node_not_pinned` [O]. `LayeredDiffusionDecodeRGBA` appears in `object_info` and is refused, and the
  sibling agent's notes record the same for `ComfyMathExpression`.
- **Inference:** treat the UI JSON as the source and the API JSON as generated. Keep source graphs flat,
  or test flattening first, since the only expansion evidence is a community script. Keep all per-frame
  values in images. A sibling agent's `stage_parts.py` already encodes the head window's x and y as a
  blank image's size, read back with `GetImageSize`; it's a neat answer to the override limit, and
  nothing I read describes it, so it may be new.
- **Batching.** `count` runs seed, seed+1 and so on, up to 16 [O]. At our measured 12.6 s per image, 64
  frames x 4 candidates is about 54 minutes for one pass [O+I]. Extra passes multiply this, so run them
  only on selected candidates.
- **Keep passes separately saved and separately keyed.** One graph with a save node per pass is good for
  editing. Check that `run_workflow` returns all of them, since a comment in `build_workflows.py` says it
  returns one save node's outputs. That comment may be out of date.

## 6. Exemplars worth copying

| Exemplar | What to copy | Trust |
|---|---|---|
| [cubiq IPAdapter nodes and example workflows](https://github.com/cubiq/ComfyUI_IPAdapter_plus) | Weight types, attention masks | High for mechanics: the node author. Installed in our studio as templates (`ipadapter_*`); I didn't open them. Maintenance-only |
| [Comfy official templates](https://github.com/Comfy-Org/workflow_templates) | Exact settings for 2511, klein and VACE, and flat graphs with notes | High for settings. They aren't about sprites |
| [ComfyUI_examples](https://comfyanonymous.github.io/ComfyUI_examples/) | Canonical two-pass and inpaint forms | High, but basic. I read the text only; the graphs sit in the images, which I didn't download |
| [Crop and Stitch](https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch) | Crop context, target size, seam blend, resize order. Its changelog lists bugs to avoid, such as 1-pixel stitch shift | High. GPL-3.0, so copy ideas, not code |
| [Pixel Studio workflows](https://github.com/bunnyUFO-lab/pixel-studio-comfyui-workflows) | Generated UI JSON, READ ME notes, re-pixelate on own grid, pass/fail check | Medium: thoughtful and on-topic, but new and small. Licence unclear on GitHub (`NOASSERTION`) |
| [mor-o 2D character pipeline](https://github.com/mor-o/comfyui-2d-character-pipeline) | Written-down rejected options; pixel-aligned layers; 24 GB budgeting | Medium: self-described work in progress |
| [PixelOE](https://github.com/KohakuBlueleaf/PixelOE), [unfake.js](https://github.com/jenissimo/unfake.js) | Contrast-aware reduction, dominant sampling | Medium-high: reproducible algorithms; I didn't run them |
| [Dead Cells write-ups](https://www.jikguard.com/news/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-dead-cells) | The rig is the source of truth | High as shipped precedent, though not AI, and snippet only |

**Dismissed:** an [Alibaba "product insights" page](https://www.alibaba.com/product-insights/how-to-generate-retro-pixel-art-sprites-using-comfyui-with-consistent-palette-and-animation-frames.html)
cites accuracy figures and a Steam release I couldn't verify. Apatero, media.io and comfyui.org read as
SEO content, so I use them only to show what guides commonly repeat.

## Findings that would most change our graph

The order is my judgement of expected improvement. None has been tested here yet.

1. **Stop generating the face per frame.** It's about 15 native pixels wide. Use a rig-placed library of
   accepted head-and-hat parts, and paint a real face into the proxy in the meantime.
2. **Fix IP-Adapter.** Remove the hidden composition 1.0, use square crops, and split head and outfit on
   masks, testing `linear` against style-only.
3. **Put more identity in the init, and add region passes.** Rig-painted detail worked in our own test.
   Follow with masked hat and shirt passes at about 0.35.
4. **Build the model sheet with Qwen-Image-Edit-2511, and use it to repair flagged frames.** Upscale by an
   integer factor onto a flat background, and re-pixelate on the original grid with a locked palette.
5. **Clean edges deterministically.** Clamp the matte to the dilated rig silhouette, use `majority`
   sampling, remove orphan pixels, and try PixelOE-style outline expansion.

The next step after these is a character LoRA from accepted frames, gated by the owner's decision on
proof clips.

## Source register

**Read in full or nearly so (fetched as text):**

- cubiq `README.md`, `NODES.md`
- `nerijs/pixel-art-xl` card; Qwen-Image-Edit-2511 card
- Crop and Stitch README; `huchenlei/ComfyUI-layerdiffuse` README
- Pixel Studio PR #4 body; `Astropulse/pixeldetector` and `sd-palettize` READMEs
- docs: subgraph blueprints; `ComfyUI_examples` text for 2-pass, inpaint, SDXL, Qwen, FLUX.2

**Read in part (relevant sections or targeted search of the text):**

- `IPAdapterPlus.py`, `user_manager.py`, `nodes_differential_diffusion.py`, ADetailer `args.py`, Impact
  `impact_pack.py`, A1111 `ui.py`
- docs: workflow API format, subgraphs, routes table, image-to-image, VACE, Wan 2.2 Fun Control, 2511,
  klein, Qwen-Image-Layered, workflow JSON
- `BLUEPRINTS.md`, xinsir union card, FLUX.2 klein card, Wan 2.2 VACE Fun card, Qwen-Image-Layered README
- mor-o README, overview and workflow 4
- Pixel Studio README, both skill docs, and two tool scripts
- PixelOE, unfake.js, See-through, LPC, InstantStyle and `sd-forge-layerdiffuse` READMEs

**Read from our studio (settings only, read-only):** templates `image_qwen_image_edit_2511`,
`image_flux2_klein_image_edit_4b_distilled`, `video_wan_vace_14B_v2v`, `video_wan_vace_14B_ref2v`,
`image_qwen_image_layered`, `templates-character_sheet`, `templates-1_click_multiple_character_angles-v1.0`,
`template_qwen_multiangle.app`.

**Snippets from search only, not read:** everything marked "Snippet" above, including Stardew wiki, Dead
Cells articles, Retro Diffusion profile, BFL docs, MyAIForce, Runflow, Steplowski, Bunraku, the See-through
hands-on, itch.io pages, Bentine, and the Apatero, media.io, runcomfy and eastondev guides.

**Could not read:** [the unfake article](https://dev.to/jenissimo/how-to-tame-your-ai-pixel-art-3pk5),
SLYNYRD Pixelblog, arXiv papers, all video tutorials, and Mariel Cartwright or other fighting-game palette
material, which search did not surface.
