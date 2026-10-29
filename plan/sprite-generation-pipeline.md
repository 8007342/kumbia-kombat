# Automated sprite generation pipeline

Status: research and readiness plan. No generated frames are runtime-approved by
this document. The first pipeline proof should use one garden challenger and one
short, beat-authored dance phrase before expanding to crowd variants or rooms.

## Why this project needs a controlled pipeline

The game already has an asset contract and a renderer that consumes measured
frame rectangles, anchors, `pixelsPerUnit`, facing, palette eligibility and
provenance (`assets/art/ensemble/manifest.json` and
`lib/gameplay/party_sprites.dart`). Its scene timing is sampled from the music
beat. Generated frames therefore need to preserve identity, grounding, view,
pose order and beat events; a visually appealing contact sheet alone cannot be
installed safely.

The current crowd and chair overlap is a layout/art calibration problem, not a
reason to generate denser crowd sheets. Crowd slots and chairs are already
separate floor-anchored objects. Fix placement from the measured background
plane and inspect chairs at smaller physical dimensions together with seated
body support points. Do not shrink each animation frame independently. Existing
garden/bar floor calibrations are estimates against starter paintings, and the
current 0.80 adult chair height / 0.53 width are measurements of the current
chair art, not final design constraints.

Challenger choreography currently reads the actual limb motif and note offsets.
Round progression should author increasingly coordinated motifs and rests in
the chart data for the chosen character, room, and game style. Do not make later
rounds harder by randomly adding motion, accelerating the same clip, or showing
notes absent from the judged chart.

## Pipeline contract

Keep ComfyUI workflow JSON, generation inputs, and generated candidates outside
the Flutter runtime asset bundle until reviewed. A run is reproducible from a
run manifest containing:

- character/room/style IDs and source art hashes;
- workflow JSON hash, ComfyUI version, custom-node commit IDs, model filenames,
  model hashes and license/source records;
- authored pose/control images, positive and negative prompts, seed, dimensions
  and all exposed node settings;
- output frame order and source prompt ID for every frame;
- post-processing tool versions and options;
- validation results, reviewer decision, and final manifest revision.

Use an immutable run directory such as
`art_runs/<run-id>/{inputs,raw,processed,review,run.json}`. Accepted files are
copied into `assets/art/<character>/` by an explicit promotion step. Store
provenance and authored workflow artifacts in the repository; store large
model weights and disposable raw generations in the Forge-managed model/cache
location, not Git.

### Generation stages

1. **Specify the action.** A human-authored clip sheet defines character,
   visual style, facing, support foot, limb, anticipation, accent,
   follow-through, settle, duration in beats and looping rules. Reuse actual
   `RhythmChart` limb sequences and the character/room/style canon. Provide one
   pose-control image per key pose. The tool may draft prompt language, but it
   cannot invent or alter gameplay timing.
2. **Generate isolated keyframes.** Start with one frame per explicit pose,
   using the approved character image for identity and the pose image for body
   control. Generate separate frames rather than asking a video model to choose
   timing or pose count. Hold a seed fixed while tuning one pose; change it only
   when exploring candidates. Require transparent output or a removable plain
   background, whole character in frame, consistent camera and enough margins
   for the full antenna/hands/feet.
3. **Clean and align.** Remove background into RGBA; inspect alpha edges; align
   frames to a shared ground pivot and cell size; snap to the chosen pixel grid;
   quantize to the approved character/room palette; detect crop, detached
   limbs, view drift, silhouette/identity changes, duplicate frames and empty
   alpha. Preserve original candidate frames for comparison. Never auto-repair a
   failed identity or anatomy check into production silently.
4. **Pack and describe.** Pack only approved frame crops with transparent
   gutters. Emit the project's JSON frame records, anchors, facing, tags,
   palette eligibility, loop rules, beat events and provenance. Keep pose order
   explicit. Packing may be automated; art acceptance remains human-reviewed.
5. **Validate and promote.** Run structural checks for image decode, alpha,
   bounds, dimensions, anchor ranges, required clip IDs, unique IDs, pose order,
   metadata schema and manifest references. Produce a review contact sheet and
   looping preview at native game size and target phone size. Promote only after
   character/art-direction review and an in-game scene review.

### First proof asset set

Use the Gatekeeper or bartender (one consistent, already integrated identity)
for a four-to-eight-key-pose cumbia phrase. Include anticipation, left/right
weight changes, one chart-matched limb accent, follow-through, settle, cede,
invite, and watch poses only as needed by the scene. Generate a second phrase
for a later round with more coordination (for example alternating limbs and a
syncopated pause), while preserving the room and character style. The two
phrases must have distinct authored chart motifs and matching frame/beat
markers. Test whether generated crops remain readable at the actual challenger
height and through the room's floor projection.

Do not start with all 72 audience poses, all 40 challenger poses, or bulk room
assets. The existing ensemble manifest is valuable training/reference material
for acceptance criteria; first compare a few candidate frames against it and
against the canon. Crowd poses additionally need seated/standing transitions,
rear/three-quarter views, outfit-only palette changes and a stable ground line.

## ComfyUI deployment and node research

The production runner should be a Forge-managed sibling service with persistent
model and custom-node storage. The game container should submit jobs through the
service's internal API and fetch completed output through the Forge artifact
handoff, not try to launch another container or assume shared filesystem paths.
Keep the UI/API on enclave-only routes; no public ComfyUI endpoint is needed.
Provide queue status, cancellation, run IDs, output retrieval, timeout handling
and failure logs in a small project driver.

Start with standard ComfyUI nodes plus the smallest validated set of pinned
extensions:

- character-reference conditioning (IP-Adapter or a maintained equivalent);
- pose conditioning (OpenPose/pose ControlNet, with authored pose images);
- transparent-background removal (BiRefNet or an equivalent tested segmenter);
- pixel-grid restoration, shared palette quantization, nearest-neighbor export,
  stable crop/alignment and sprite-sheet packing.

Candidate node repositories are research leads only, not selected dependencies.
Before adoption, check maintenance activity, ComfyUI API compatibility, source
license, model license, security/install requirements, deterministic behavior,
alpha quality and whether an equivalent built-in node is sufficient. Avoid
video-first extraction for the first playable clips: it can drift in identity,
feet, camera, and exact pose timing. Consider it later for ambient loops whose
timing does not communicate judged input.

ComfyUI's official documentation describes it as a local node-based inference
engine with custom workflows and deployment options. Its workflow/API contract
and routes must be confirmed against the exact sibling image once available;
the driver should not depend on unverified third-party API assumptions.

## Ollama and current Forge session

Forge's installed OpenCode configuration advertises an Ollama sibling at
`http://inference:11434/v1`. A direct query of its sibling API succeeded during
this session. It currently reports `qwen2.5:0.5b` and `nomic-embed-text`; the
first is a small text model suitable for prompt/metadata drafting experiments,
while the latter is embedding-only. No image-generation model was reported.
This makes Ollama useful for local prompt drafting, clip-metadata drafting,
manifest lint suggestions and run-report summaries, but not image synthesis.
Generated metadata must be schema-validated and human-reviewed. `ollama` is not
installed as a command in this project container, so use the configured
sibling endpoint or Forge tooling rather than a local binary.

No ComfyUI process or local `:8188` endpoint was present, and this session did
not find a ComfyUI sibling route/tool. Do not attempt to start another
container from the project container; verify the appropriate Forge provisioning
facility and model storage with the platform owner before beginning G0.

## Questions to resolve before implementation

1. Which Forge facility provisions and routes the ComfyUI sibling, and which
   persistent model/cache mount and artifact handoff does it support?
2. What GPU/VRAM and disk budget does that sibling have? This determines the
   family, precision, resolution and batch size; CPU-only image generation is
   not a sensible default.
3. Which locally available image checkpoint/LoRA and pose/identity controls
   have redistribution rights compatible with this project's intended release?
   Record each license and hash before workflow lock-in.
4. Does the installed Ollama sibling answer at `inference:11434`, which models
   are actually pulled, and can any available vision model inspect candidate
   sheets? Keep visual QA backed by deterministic checks and human review.
5. Can the chosen background-removal stage preserve thin antennae, fingers,
   dark outlines and semi-transparent effects at sprite scale?
6. What native character pixel grid and final cell sizes should be approved per
   role? Current generated sources range from large concept sheets to 1024px
   isolated art; runtime manifest measurements should decide this.
7. Which clips are actually needed for each opponent archetype, room and round,
   and which gameplay chart data owns the complexity progression?
8. What objective crowd spacing/occlusion and chair-size gates will be reviewed
   on the published mobile build at multiple aspect ratios?

## Readiness gates

- **G0 — facility:** sibling ComfyUI endpoint, GPU budget, persistent storage,
  local model inventory and safe output handoff are measured.
- **G1 — static frame:** one approved identity produces a clean transparent
  pose at game resolution; operator can rerun from recorded settings.
- **G2 — short clip:** four-to-eight poses preserve identity, facing, feet,
  palette, anchor and authored order; contact sheet is approved.
- **G3 — runtime:** generated manifest loads in-game, beat markers align with
  chart events, crowd/chair occlusion is readable on phone, and asset memory is
  measured before expanding the cast.
- **G4 — scale-up:** only after G3, batch the remaining opponent and crowd clips;
  each batch retains run provenance, validation report and human promotion.

## Research references

- [ComfyUI official documentation](https://docs.comfy.org/) — local node-based
  engine, workflows, deployment and custom-node documentation.
- [ComfyUI controlled pixel-animation deployment design](https://github.com/xl732236362/ComfyUI-GameAsset-Workflows/blob/main/docs/superpowers/specs/2026-07-17-pose-controlled-pixel-animation-deployment-design.md)
  — useful proposed combination of pose control, character reference, alpha
  cleanup and nearest-neighbor sprite packing; validate all versions, licenses
  and hardware assumptions independently before reuse.
- [ComfyUI PixelPipeline](https://github.com/PeaarLi/ComfyUI-PixelPipeline) —
  candidate grid restoration, palette, export, background and packing stages;
  third-party node quality and license need review before adoption.
- Existing project contracts: [art direction](../openspec/specs/art-direction/spec.md),
  [asset plan](assets.md), [ensemble manifest](../assets/art/ensemble/manifest.json),
  [party perspective guide](party-perspective-and-life.md), and
  [dance choreography plan](dance-battle-choreography.md).
