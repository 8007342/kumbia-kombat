# Wardrobe visibility on Flutter web

The live shader and retained shader-picture approaches both passed native pixel
tests but later lost crowd sprites in the hosted CanvasKit preview. Runtime
crowd drawing now uses ordinary `ui.Image` atlas crops exclusively. A fragment
shader runs once during asynchronous preparation, and its result is rasterized
before the shader and picture are disposed. Original plum art remains visible
while preparation is pending, unsupported, rejected, or over the cache limit.

## Alternatives considered

| Approach | Consequence |
| --- | --- |
| Live fragment shader or retained shader picture | Rejected for this fix: still carries the resource/lifetime path implicated by the hosted failure. |
| Global `ColorFilter` | Does not isolate clothing; would also alter skin, hair and props. A separate authored clothing mask/layer could make this viable later. |
| Runtime CPU pixel recoloring | Can preserve the same mask but adds a second color implementation and CPU pixel rewriting. Unnecessary for this fix. |
| Pre-generated PNG variants | Most independent of runtime shader support, at the cost of twelve additional assets and fixed exported wardrobes. A viable later fallback if preparation proves too costly. |
| Shader pre-rasterization to retained images | Selected. Reuses the reviewed clothing mask; runtime follows the same ordinary image path as the still-visible ambient sprites. |

Flutter documents [`Picture.toImage`](https://api.flutter.dev/flutter/dart-ui/Picture/toImage.html)
as rasterizing a picture into an image. The exact preview engine's
[`CkPicture.toImage`](https://raw.githubusercontent.com/flutter/flutter/deb287481e3ce9468f3434937ced4240a70539ca/engine/src/flutter/lib/web_ui/lib/src/engine/canvaskit/picture.dart)
reads back the snapshot and makes a separate raster image. This is shader-based
recoloring with one-time readback, not a claim of GPU-only loading.
[`Canvas.drawImageRect`](https://api.flutter.dev/flutter/dart-ui/Canvas/drawImageRect.html)
then selects poses normally.
[`ColorFilter.mode`](https://api.flutter.dev/flutter/dart-ui/ColorFilter/ColorFilter.mode.html)
applies a blend to its input, without a clothing-selection contract.

## Bounds and failure behavior

- At most twelve full atlas variants: three guests × four wardrobes. Jobs are
  deduplicated and serialized, with an event-loop yield between jobs.
- Every output alpha pixel must match the source within two byte values. Blank
  or partial output is discarded before it can replace visible source art.
- Failed requests remain failed instead of retrying on every animation frame.
  `lastPreparationError` exposes the reason. Compilation failure selects source
  art; it does not fail scene loading.
- Sources are cloned while jobs run. Removal disposes cached images immediately
  and late results when their jobs finish. Callers retain ownership of originals.
- Twelve variants contain about 72 MiB of decoded RGBA pixels. Total residency
  may include both CPU and GPU copies (potentially about 144 MiB for variants,
  plus originals and transient allocations). This is not a measured phone memory
  budget. Cropped-pose variants total about 43.7 MiB but introduce 288 jobs/cache
  entries; a bounded pose cache is a later optimization if measurements justify it.

## Browser evidence and limits

An isolated temporary browser probe cycled all 24 poses for all twelve variants.
Its initial hosted Chromium run completed rasterization and alpha checks in
4.53 seconds, then retained visible, differently colored characters after all
source images, shaders and recorded pictures were disposed. Explicit
`HeapProfiler.collectGarbage` calls and subsequent pose changes also retained
visible characters. The host uses SwiftShader, so this is browser lifetime
evidence, not hardware-GPU or physical-phone performance proof.
The temporary probe was removed after verification. The actual hosted garden
also displayed all four wardrobes after explicit garbage collection with the
replacement renderer.

The installed toolchain reports Flutter 3.47.7 / engine deb287481e. The implementation
uses longstanding `Picture.toImage`, `drawImageRect` and image-disposal APIs; no
Flutter 3.35.7 run was performed. Native tests additionally cover actual garment,
skin and hair samples, atlas bounds, transparent edges, repeated transforms,
source fallback, and disposal while preparation is pending.
