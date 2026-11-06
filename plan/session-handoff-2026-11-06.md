# Session handoff, 2026-11-06

Read this first after the relaunch. Work branch: `work/1841-toda`, based on `game` at `589b9f8`.

## Why the relaunch

macuahuitl-fedora pinned ACE-Step for the music pilot, but the running tray build predates the pins (#956). The owner exits the forge and tray, then macuahuitl-fedora installs and relaunches. No GPU batch ran before this, so nothing in `/work/tmp/imagegen` had to be saved.

## Files macuahuitl-fedora reports on disk

Unverified by this lane. All are from Comfy-Org/ACE-Step-1.5 rev `371bb168`, in the tier's `I1` folder. Trust `studio.models` for the names and loader folders.

- Diffusion model: `ace-dit/acestep_v1.5_xl_turbo_bf16.safetensors`
- Text encoders: `ace-te/qwen_0.6b_ace15.safetensors`, `ace-te/qwen_4b_ace15.safetensors`
- VAE: `ace-vae/ace_1.5_vae.safetensors`

XL base isn't pinned yet; it's a separate PR. Build the workflow in the shape of Comfy-Org's `audio_ace_step1_5_xl_turbo` template. Per-take overrides are `$node:<encoder id>.tags/.seed/.bpm/.keyscale`. Output is `kind=audio` (`.flac`) with a provenance sidecar. This has had no real GPU run, so ours may be the first. Report the result to macuahuitl-fedora.

## Owner's decisions today

See the seventh round in `owner-rulings-2026-11-05.md`.

## Today's plan, approved by the owner

1. Done: `game` fast-forwarded to `589b9f8` with the research docs.
2. After the relaunch, run the checks below.
3. Fourth-round fixes, no GPU: remove the exit walk-through after cinematics, let opponent spins finish mid-floor before stepping away, and play cinematics over the music's cool-down.
4. Music pilot, `music-rebuild.md` stage 2: 12 takes each for Garden and the lawn, timing filter, then the owner listens blind to the best 3 per level against the synth.
5. Art between music runs, one GPU job at a time: oil gulp redraw, then one room split into layers with shared props.

## Checks after the relaunch

- `studio.status`, `studio.models`: the ACE files and the 2511 Lightning LoRA should show `on_disk: true`. Report to macuahuitl-fedora if the LoRA doesn't.
- 2001-stpr marker test: #937 should be in this build. Confirm at ComfyUI `/history`, not from a sidecar.
- `flutter analyze` and `flutter test`: **no baseline yet.** Both were refused before the relaunch: `runtime_unavailable: podman did not answer (image exists)`, `refused:flutter:host-toolchain-unavailable`. Report it if it persists.
- macuahuitl-fedora's checklist: WebGL renderer and fps against the old 7-9, `uv python install 3.13`, and whether the cache survived (`~/.cache/tillandsias-project/kumbia-art`, 1.1 GB before the relaunch). `cloud.usage` and `cloudflare.scope_probe` should work again.

## Where the fourth-round fixes live

Read so far, nothing changed:

- `lib/gameplay/exit_shot.dart`: `ExitShot` data, with `walkFrom`/`walkTo`, close-up beats, and `routeAt`, the departure progress after the close-up.
- `lib/gameplay/room_departure.dart`: the departure routes per room.
- `lib/gameplay/garden_page.dart` lines 131-155: success and bridge beats drive `warmDown` and travel.
- `levels/garden.json`, `levels/bar.json`: `exitShot` data. The lawn has none.
- `lib/gameplay/challenger_choreography.dart` and `lib/gameplay/dance_grammar.dart`: the call, handoff and accents. Spin accents come from `assets/art/ensemble/choreography.json`.

Keep the rule these files state: art reads the music beat and can't move the music, notes or score.
