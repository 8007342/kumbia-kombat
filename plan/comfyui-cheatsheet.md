# ComfyUI cheatsheet for Kumbia Kombat

One-stop reference for our studio: ComfyUI 0.40.0, frontend 1.55.17, 24 GB VRAM. Evidence
and links are in `plan/research/comfyui-production-2026-11.md`; the target pipeline is in
`openspec/changes/comfyui-studio-pipeline/`.

**Node classes.** Every class named here was checked against the studio's `object_info` on
2026-11-04. That list is not the allowlist: `run_workflow` also refuses unpinned classes with
`node_not_pinned`. Treat any class outside this list as "exists, may need a pin".

Already in a committed workflow or run record, so most likely pinned: `CheckpointLoaderSimple`,
`LoraLoader`, `CLIPTextEncode`, `CLIPVisionLoader`, `IPAdapterModelLoader`, `IPAdapterAdvanced`,
`PrepImageForClipVision`, `ControlNetLoader`, `SetUnionControlNetType`, `ControlNetApplyAdvanced`,
`LoadImage`, `ImageToMask`, `MaskToImage`, `ImageColorToMask`, `InvertMask`, `GrowMask`,
`FeatherMask`, `ThresholdMask`, `MaskComposite`, `CropMask`, `ImageCrop`, `ImageScale`, `ImageBlur`,
`ImageCompositeMasked`, `GetImageSize`, `SetLatentNoiseMask`, `EmptyLatentImage`, `VAEEncode`,
`VAEDecode`, `KSampler`, `SaveImage`, `JoinImageWithAlpha`, `LoadRembgByBiRefNetModel`,
`RembgByBiRefNet`, `LayeredDiffusionApply`, `LayeredDiffusionDecode`.

No edit-model or video class has run here yet.

**Source tags.** [doc] official docs or templates. [author] the tool's own source or card.
[ours] measured or observed here. [guess] untested starting point.

## Sizes to remember

| What | Value | Source |
|---|---|---|
| Native frame | 96x120 | ours |
| Generation canvas | 768x960, exactly 8x | ours |
| One native pixel | 8 canvas pixels, one SDXL latent cell | [author] LoRA card says 8x; grid offset measured (0,0) [ours] |
| Face | about 15 x 10-13 native, or 120 x 100 canvas | [ours] |
| Hat | about 31 x 10-14 native | [ours] |
| RGBA from LayerDiffuse | Dimensions must be multiples of 64 | [author] |
| `attn_mask` | Same aspect ratio as the latent | [author] |

## Denoise and CFG

Tool defaults aren't tested recommendations. Everything needs confirming on our frames.

| Pass | Denoise | Steps, CFG | Source |
|---|---|---|---|
| Base from rig proxy | 0.7 works; 0.56 flattens the face if the proxy has no face | 28, CFG 6, `dpmpp_2m`/`karras` | [ours] |
| Base with detail-painted proxy | 0.5-0.65 | same | [guess] 0.56 kept stripes and gave cleaner cells [ours] |
| Region pass on canvas (hat, shirt) | 0.3-0.4 | 24, CFG 6 | [guess] the sibling workflow starts at 0.35 |
| Head crop | 0.4-0.5 | 24, CFG 6 | ADetailer default 0.4, FaceDetailer default 0.5 [author] |
| Second pass, hires style | Slider default 0.7 | n/a | A1111 [author]. Doesn't apply: no upscale stage for us |
| Qwen-Image-Edit-2511 | 1.0 (edit, not img2img) | 40, CFG 3, `euler`/`simple`, shift 3.1, `CFGNorm` 1 | template [doc]; card says `true_cfg_scale` 4 [author] |
| FLUX.2 klein 4B distilled | n/a | 4, CFG 1, `euler`, `Flux2Scheduler` | template [doc] |
| Wan 2.1 VACE template | 1.0 | 4, CFG 1, `uni_pc`/`simple`, shift 8, strength 1 | template [doc]. **Not** our 2.2 Fun files, which have no template I could find |
| Qwen-Image-Layered | n/a | 20, CFG 2.5, shift 1, 640 px | template [doc]; model not on disk |

**How denoise really works:** the schedule has `int(steps / denoise)` steps and the last `steps`
run [doc]. So 4 steps at 0.85 is a full repaint. `build_workflows.py` refuses this.

**IP-Adapter:** `linear` starts near 0.8, and other weight types can go higher [author]. Don't start
later than 0: `start_at` 0.3 gives "very light" conditioning [author].

**LoRA:** `pixel-art-xl` at 0.8 is ours. The card's only other figure is 1.2, alongside an LCM LoRA.

## Recipes

Titles starting `$` bind at run time. `LoadImage` titled and valued `$name` takes a file;
per-pose numbers travel as images (recipe 3).

### 1. Base pass

```
CheckpointLoaderSimple -> LoraLoader(pixel-art-xl)
  -> IPAdapterAdvanced(head) -> IPAdapterAdvanced(outfit)     recipe 2
CLIPTextEncode($prompt), CLIPTextEncode($negative_prompt)
  -> ControlNetApplyAdvanced(openpose) -> (depth) -> (lineart)
     ControlNetLoader, SetUnionControlNetType for the union file
LoadImage($init_image) -> VAEEncode -> KSampler($seed, denoise)
  -> VAEDecode -> SaveImage
```

Keep the summed control strength near 2.0 (our earlier research). Use `profiles.json` per pose type.

### 2. Masked references: the IP-Adapter fix

```
IPAdapterModelLoader + CLIPVisionLoader
LoadImage($ref_head)   -> PrepImageForClipVision(crop_position: center)  -> image
LoadImage($mask_head)  -> ImageToMask(channel: red)                      -> attn_mask
IPAdapterAdvanced(weight_type: linear, weight 0.5-0.8 [guess])
LoadImage($ref_outfit), LoadImage($mask_body), same again, chained on the model
```

- **Never use `style and composition` on `IPAdapterAdvanced`.** Composition is fixed at 1.0
  and hidden (`IPAdapterPlus.py`, upstream source) [author].
- Compare `linear` with `style transfer`. On SDXL, the latter touches block 6 only and is documented
  as not carrying content [author].
- The body mask must cover everything but the head. A figure-only mask invented text at the bottom
  edge on one seed [ours, task 5.3].
- Crop references square yourself. Otherwise hat and shoes may be centre-cropped away [author].

### 3. Crop and stitch with core nodes

The GPL-3.0 `InpaintCrop` pack isn't installed and isn't needed.

**In the graph**, as in `tool/art/workflows/studio/frame-multipass.json`:

```
LoadImage($head_xy) -> GetImageSize                        width, height carry x, y
ImageCrop(x, y, 256 x 256) -> ImageScale(target, lanczos)
  -> VAEEncode -> SetLatentNoiseMask(mask from ImageToMask)
  -> KSampler -> VAEDecode -> ImageScale(back to 256)
  -> ImageCompositeMasked(destination: frame, x, y, mask)
```

**Or in the repo:** Python crops, a workflow samples the crop, and `masked.py` stitches.

- Composite in image space with `ImageCompositeMasked`. A latent round trip alters unmasked pixels
  [ours, D5], which is what Crop and Stitch was written to avoid [author].
- Soften with `GrowMask` and `FeatherMask`. Tool defaults for comparison: ADetailer padding 32, blur 4,
  dilate 4; FaceDetailer feather 5, guide 512 [author].
- `InpaintModelConditioning` is the author-recommended route for denoise below 1, rather than
  `VAEEncodeForInpaint` [author]. With a non-inpainting checkpoint, `SetLatentNoiseMask` is the plain
  route we have tested.
- Add `DifferentialDiffusion` for graded masks, where a grey level means partial change [author].
- A union ControlNet in `tile` mode can hold structure at low denoise [author: card; use is a guess].
- **Lower or remove the pixel LoRA for upscaled crops** [guess]. At 3x its "pixels" are a third of
  a native pixel.

### 4. Region pass on the canvas

Same as the base pass, with these changes: the init is the previous pass's output, `SetLatentNoiseMask`
takes the rig region mask from recipe 2's route, denoise is about 0.35, and the prompt describes only
that region. Finish with `ImageCompositeMasked` for exact pixels outside the mask.

### 5. Qwen-Image-Edit-2511 as an editor or sheet maker

```
UNETLoader(qwen_image_edit_2511_fp8mixed.safetensors)
  -> ModelSamplingAuraFlow(3.1) -> CFGNorm(1)
CLIPLoader(qwen_2.5_vl_7b_fp8_scaled.safetensors, qwen_image)
VAELoader(qwen_image_vae.safetensors)
TextEncodeQwenImageEditPlus(prompt, vae, image1: frame, image2: reference)      up to 3 images
TextEncodeQwenImageEditPlus("", same images)                                    negative
  each -> FluxKontextMultiReferenceLatentMethod(index_timestep_zero)
VAEEncode(frame) -> KSampler(40, CFG 3, euler, simple, denoise 1)
```

Settings from `image_qwen_image_edit_2511` [doc]. Before and after [author: Pixel Studio]:

- Upscale **by an integer factor** onto a flat background with `ImageScaleBy(nearest-exact)`. A
  transparent background reached the model as black.
- Say what must stay the same in the prompt: same pose, same style, everything else unchanged.
- Bring the result back to its own grid and locked palette, and check the silhouette against the rig
  for drift. Don't treat an edit's output as pixel art until it passes the finish.
- Install Lightning only with approval. Without it, expect 40 steps per frame, so don't run it on
  whole sets.

Prefer the installed template when building this: `image_qwen_image_edit_2511`. It's a subgraph, so
unpack or flatten it first.

### 6. FLUX.2 klein 4B edit

```
UNETLoader(flux-2-klein-4b.safetensors)
CLIPLoader(qwen_3_4b.safetensors, flux2), VAELoader(flux2-vae.safetensors)
CLIPTextEncode -> ReferenceLatent(VAEEncode(reference)) per reference
EmptyFlux2LatentImage, Flux2Scheduler(4), KSamplerSelect(euler),
RandomNoise, CFGGuider(cfg 1) -> SamplerCustomAdvanced -> VAEDecode
```

Settings from `image_flux2_klein_image_edit_4b_distilled` [doc]. Good for quick previews. Its card lists
about 13 GB VRAM.

### 7. Matte clamped to the rig

```
LoadRembgByBiRefNetModel(model.safetensors) -> RembgByBiRefNet  -> MASK
LoadImage($mask_figure) -> ImageToMask -> GrowMask(about 8-16 px) [guess]
MaskComposite(operation: and)
```

Pick `model.safetensors` in the loader; the list also holds a lock file and a checksum file [ours].
`finish_pixels` then cuts alpha at 128. You can do the clamp in Python instead.

### 8. Wan VACE for one test clip

```
UNETLoader(wan2.2_fun_vace_high_noise_14B_fp8_scaled.safetensors) and the low_noise file
CLIPLoader(umt5_xxl_fp8_e4m3fn_scaled.safetensors, wan), VAELoader(wan_2.1_vae.safetensors)
WanVaceToVideo(control_video, reference_image, width, height, length, strength)
  -> KSampler (high noise, then low noise)
  -> TrimVideoLatent(trim_amount: WanVaceToVideo's fourth output) -> VAEDecode
```

- `control_video` is the rig render. Line the reference up with the first control frame [doc]. Templates
  use 81 and docs mention 49 frames; "4n+1 frames" is from memory, so confirm it.
- Two-sampler split and settings for the 2.2 Fun files are **unsourced**; use its card and test.
- About 7 minutes for 49 frames at 640x640 on a 4090 [doc]. It's a bake-off only (D11).

### 9. Pixel finish (outside the graph)

`colourmatch.py` -> `studio.finish_pixels` -> `ramps.py`, plus optional additions:

- Set `finish.sample` to `majority`: the centre pixel strays by over 30 summed-RGB from its cell in up
  to 4.9% of foreground cells [ours].
- Clean up orphan pixels in Python.
- Trial [PixelOE](https://github.com/KohakuBlueleaf/PixelOE) (Apache-2.0, has a CLI, repo-side) to keep
  thin features like the mustache. It would be a dependency, not a node pack, so it still needs the
  owner's and host's review.

## Pitfalls

| Pitfall | Do instead | Source |
|---|---|---|
| Believing the node's `weight` for `style and composition` | Use another weight type | [author] |
| Tall references | Square crops, with head and body separate | [author] |
| Assuming `object_info` means runnable | Test each new class once; `LayeredDiffusionDecodeRGBA` is listed and refused | [ours] |
| `LayeredDiffusionDecodeRGBA` | Refused now, and crashed on v0.40; use `LayeredDiffusionDecode` + `JoinImageWithAlpha`, and note its alpha came out inverted | [ours] |
| `ImageQuantize` for a final palette | It builds an adaptive palette; use `finish_pixels` | [ours: inputs] |
| `ColorTransfer` per frame | It works from whole-image statistics; use `colourmatch.py` | [ours, D7] |
| `MediaPipeFaceMask` | Needs detected landmarks, unlikely on a sprite; use rig masks | [guess] |
| `IPAdapterFaceID` | Needs insightface and a FaceID model that we don't have | [author] |
| `IPAdapterRegionalConditioning` | Not admitted when last checked; use `attn_mask` | [ours, design] |
| Masks that look white | Must be 100% opaque or the original shows through | [author: Crop and Stitch] |
| Scaling upward with `ResizeImageMaskNode` in API JSON | Its V3 dynamic combos are awkward by hand; use `ImageScale` | [guess] |
| Transparent input to edit models | Flat background first | [author: Pixel Studio] |
| Upscale models | `UpscaleModelLoader` lists nothing, so no ESRGAN route | [ours] |
| `$strength` and `$seed` together on one KSampler | One title per node; bake denoise per workflow | [ours, D5] |
| API-only workflows | They load without layout; keep UI JSON as the source | [doc] |
| Subgraphs in source workflows | Keep flat until flattening is tested against the frontend | [author: Pixel Studio] |
| Loose negatives like "beard" fixing drift | Paint identity into the proxy, or composite it | [ours] |

## Studio routes (read-only unless noted)

```bash
curl -s --noproxy '*' http://studio:8188/object_info/KSampler
curl -s --noproxy '*' 'http://studio:8188/userdata?dir=workflows'
curl -s --noproxy '*' http://studio:8188/workflow_templates     # custom-pack templates
curl -s --noproxy '*' http://studio:8188/global_subgraphs       # 116 blueprints
curl -s --noproxy '*' http://studio:8188/templates/index.json   # official template list
```

Writing: `POST /userdata/workflows%2F<name>.json`, with `overwrite=false` to refuse clobbering [doc].

## Templates worth opening in the studio

| Task | Template |
|---|---|
| IP-Adapter weight types | `ipadapter_weight_types`, `ipadapter_precise_weight_type`, `ipadapter_style_composition` |
| Attention masks, regional | `ipadapter_regional_conditioning` (class not admitted, but shows the idea) |
| Edit with references | `image_qwen_image_edit_2511` |
| Character turnaround | `templates-1_click_multiple_character_angles-v1.0` (needs LoRAs we don't have) |
| Klein edit | `image_flux2_klein_image_edit_4b_distilled` |
| VACE with reference | `video_wan_vace_14B_ref2v`, `video_wan_vace_14B_v2v` (Wan 2.1) |
| Layers | `image_qwen_image_layered` (model not on disk) |

## Asking for more

New packs and models need host approval and a licence review. Worth asking for only with a reason:

| Item | Why | Licence | Core or repo alternative |
|---|---|---|---|
| `Qwen-Image-Edit-2511-Lightning-4steps` | 4 steps instead of 40 makes repairs and sheets cheap; won blind picks in one small test | Apache-2.0 (repo card; check the file) | 40 steps, on flagged frames only |
| `ip-adapter-plus-face_sdxl_vit-h` | Face-specific reference | Check on request | Head crop with the plus model |
| Impact Pack | FaceDetailer, automatic SEGS | GPL-3.0 (from memory; check) | Rig masks do better for us, so **don't request** |
| Crop and Stitch | Convenience | GPL-3.0 | Recipe 3 is enough, so **don't request** |

## Check this file

Every class above must be in the studio. Run after edits:

```bash
python3 -I - <<'E'
import json,re,urllib.request as u
o=json.load(u.build_opener(u.ProxyHandler({})).open('http://studio:8188/object_info'))
t=open('plan/comfyui-cheatsheet.md').read()
names=set(re.findall(r'\b(?=\w*[a-z])(?=[A-Z]\w*[A-Z])[A-Z][A-Za-z0-9_]+\b',t))
print(sorted(n for n in names if n not in o))
E
```

It prints mixed-case names not in the studio. Product names such as `PixelOE` also appear; anything
else is a typo or a node that has gone.
