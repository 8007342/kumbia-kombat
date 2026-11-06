# Session handoff, 2026-11-06

**Update, later on 2026-11-06.** The relaunch checks and the music pilot are done. Results: `plan/music-pilot-2026-11-06.md`. Checklist for macuahuitl-fedora: `plan/relaunch-report-2026-11-06.md`, **not delivered**, because that session wasn't reachable and this lane has no fleet address for it. Still to do from below: see the mid-floor spin, exit walk and hard cut on screen, then the art items. Music stage 3 needs the owner's phones. The rest of this file is the plan as written before the relaunch.

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
3. Fourth-round fixes, no GPU: code done and pushed in `a7aedba`, not yet seen on screen. Cinematics already play over the cool-down, so that needed no change.
4. Music pilot, `music-rebuild.md` stage 2: 12 takes each for Garden and the lawn, timing filter, then the owner listens blind to the best 3 per level against the synth.
5. Art between music runs, one GPU job at a time: oil gulp redraw, then one room split into layers with shared props.

## Checks after the relaunch

- `studio.models` `tray_build`: the old lane reports `56.11.6.1+6a509f720d853e8b`, a local build that shares its version label with the published release but lacks the ACE change. The new label must differ. Report it to macuahuitl-fedora. Then rerun `tool/music/workflows/ace-xl-turbo.api.json`, which this lane refused with `node_not_pinned`.
- Baseline before the relaunch: 174 tests pass on `work/1841-toda`; `flutter analyze` shows 4 style notes in `battle_staging.dart`.
- **Not yet seen on screen:** the mid-floor spin and the removed exit walk. Check whether the opponent crowds Mācron, the lost open-palm cue during the overflow, and the hard cut to the next room.
- `studio.status`, `studio.models`: the ACE files and the 2511 Lightning LoRA should show `on_disk: true`. Report to macuahuitl-fedora if the LoRA doesn't.
- 2001-stpr marker test: #937 should be in this build. Confirm at ComfyUI `/history`, not from a sidecar.
- `flutter analyze` and `flutter test`: an early refusal, `podman did not answer`, came from host image builds and cleared by itself. Rerun them against the baseline above.
- macuahuitl-fedora's checklist: WebGL renderer and fps against the old 7-9, `uv python install 3.13`, and whether the cache survived (`~/.cache/tillandsias-project/kumbia-art`, 1.1 GB before the relaunch). `cloud.usage` and `cloudflare.scope_probe` should work again.

## Where the fourth-round fixes live

Changed in `a7aedba`, except the level data and `room_departure.dart`:

- `lib/gameplay/exit_shot.dart`: `ExitShot` data, with `walkFrom`/`walkTo`, close-up beats, and `routeAt`, the departure progress after the close-up.
- `lib/gameplay/room_departure.dart`: the departure routes per room.
- `lib/gameplay/garden_page.dart` lines 131-155: success and bridge beats drive `warmDown` and travel.
- `levels/garden.json`, `levels/bar.json`: `exitShot` data. The lawn has none.
- `lib/gameplay/challenger_choreography.dart` and `lib/gameplay/dance_grammar.dart`: the call, handoff and accents. Spin accents come from `assets/art/ensemble/choreography.json`.

Keep the rule these files state: art reads the music beat and can't move the music, notes or score.
