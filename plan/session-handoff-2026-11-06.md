# Session handoff, 2026-11-06

**Read this first after the relaunch.** `game` holds all merged work. Start the next work ref from `origin/game`, for example `git switch -c work/1853-ordr origin/game`; ref grammar is `work/[0-9]{3,4}-[a-z0-9]{4}`.

## First, after the relaunch

1. `df -h /home/forge/src` should show about 4 GB, from `src_mb = 4096`. macuahuitl-fedora read that in the code, and it had never run on a real relaunch. Report the result to it.
2. `studio.status`, `studio.start`, `studio.models`: tray build differs from `56.11.6.2+8ab23b59434614e2`, and the XL base file shows `on_disk: true`. Report the build label and the result to macuahuitl-fedora. Its first GPU use may spend minutes in the `fetch` stage.
3. Check `flutter analyze` (4 style notes in `battle_staging.dart`) and `flutter test` (453 passing at merge time). A first refusal `podman failed at step source (timeout)` clears on retry.
4. Build and preview: `flutter build web --release --no-web-resources-cdn --no-pub`, `preview.publish {category: WEB, app_dir: build/web, runtime: static}`, then restore the listening page: `mkdir -p build/web/listen && cp -a ~/.cache/tillandsias-project/kumbia-audio/themes-20261106/listen-built/. build/web/listen/`. Rebuild with `build_listening.py --latest <run dir> <served dir>`. The blind and old-ladder page is archived beside it as `listen-archive-20261106/`.
5. Wait for macuahuitl-fedora's word before relaunching: it installs the XL base build after its land gate and verifies the pin first. Bridges between tiers: try ACE-Step extend or repaint nodes on our side; if one returns `node_not_pinned`, send it the class name, since a core ComfyUI node is a small addition.
6. Deploys: Cloudflare Workers Builds only triggers on `main`, so `game` doesn't reach kumbias.tlatoani.net. Production is still `6f0b862`. Promoting to `main` is the owner's call.
7. `ListAgents` lists macuahuitl-fedora when it's on Remote Control; `SendMessage` by that name. The owner asked for occasional status and any shortcomings.

## Latest, late 2026-11-06, on work refs, not yet in `game`

- `work/1853-ordr`: campaign order garden, pool party, bar. New bridges `garden_to_pool` and `pool_to_bar`. The bar is last for now, so `bar_swag_finale` carries the gulp; when the indoor party ships, point `bar.json` back at `bar_swag_success` and use `bar_to_crowd`. The bar's chart sits on its syncopated melody. Rooms now dissolve in 1.2 s (`room_dissolve.dart`). Fuller lows are at the bottom of the listening page. 457 tests pass, and a flawless muted run reached the end screen at 60 fps with no errors. Nobody has played or heard it.
- `work/1854-blin`: the BlinBlin definition and draft sheets, waiting for the owner to pick a front and a back. Then `art.py accept-sheet`, pilot, wave. `KUMBIA_BPY_PYTHON=~/.cache/tillandsias-project/venvs/kumbia-bpy/bin/python`, and run `uv python install 3.13` first after a relaunch: `~/.local/share/uv` doesn't survive it, which leaves the Blender venv's python dangling. The kumbia-art venv is at `~/.cache/tillandsias-project/venvs/kumbia-art/bin/python`, not the path in the art-family skill.
- Tier bridges are blocked on 2018-auin: macuahuitl-fedora pins `LoadAudio` and friends and has `inputs` bind audio, then a relaunch. Draft workflow: `tool/music/workflows/ace-xl-bridge.api.json`. Its input is a tempo-matched join of low and mid, built with ffmpeg. Rebuild it, since the scratchpad doesn't survive, and don't use the upload route.
- For the owner's eye: about 5 s after the lawn's kiss, while the 100 BPM bridge plays, the wide shot looks almost still. The bridge used to be faster. Extending the close-up into the bridge is the likely fix.
- Still to do: one style guide with a cinematic section; slow party-up by tier for everyone; layers for the other rooms; indoor plate with the floor painted separately; named hardest combos.
- Browser checks: `browser.screenshot` output lands in a file as JSON with base64 `data`, so decode it and read the PNG. Set device scale 1 or it's refused. Flutter's canvas is in a shadow root, so hook `getContext` to find it, and draw frames to an overlay contact sheet to review a long run in one screenshot. `browser.eval` times out on a 6 s promise.

## Working notes

- Agent worktrees have started on `main`: tell agents to `git fetch origin && git switch -c <ref> origin/game`. Filed as 2017-wtbr.
- Flutter only runs under the checkout. Filed as 2017-flwt. Worktrees cost about 300 MB each; `git sparse-checkout set --no-cone '/*' '!/art_runs/' '/art_runs/rooms/'` drops old art runs and keeps the floor file a test needs. Evict merged worktrees. `/work/tmp/imagegen` doesn't survive the forge, so copy keepers to the cache.
- Browser checks: send CDP `Emulation.setFocusEmulationEnabled` first, since frames barely run before focus. To stay silent and capture frames, add a script with `Page.addScriptToEvaluateOnNewDocument` that routes the audio destination through a zero gain and samples the largest canvas. Results over 4 MiB per line are refused, so take frames in slices. Close-ups draw in a 180-unit-wide view.
- Art: `$prompt` overrides work (2001-stpr fixed). Pass `$node:30.lora_name` = `Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors`; workflows still load 2509. Qwen won't hold chains of moments; use a code rig or puppet (`art_runs/closeups-v3-20261106/scripts/rig.py`, `plan/cinematics.md`).
- Music: timing passing doesn't mean a take is good. The owner's test is "lively and identifiable". Compare decoded audio, not FLAC hashes.

**Latest, 2026-11-06, merged to `game`.** A flawless run through all three levels in a real browser, muted: no errors, 60 fps median, 58 lowest second, about 4.6 minutes. Merged: cinematic titles, text-free play, accents, curved cues, taps near rings, VCR pause, lenient crowd scoring, close-ups as the sprite grown large with the real āi logo, fuller rooms, stools at the bar, opponents larger, Mācron's retreat, the Girls as a pair with spins, gesture moves, garden layers. Branches `work/1842` to `work/1852` are all included.

Music winners: Garden 51002, lawn 52011, bar 55005, indoor party 53010. The owner heard the ladders: the progression is right, but lows are too quiet and thin, the lawn low too slow, and joins don't crossfade cleanly. Next steps are in `plan/music-rebuild.md`, "Ladder notes". Lawn high candidate: seed 52019, which passes timing and isn't on the page yet.

Next batch, approved: level order garden, pool party, bar, indoor party, with the bar's chart the more complex; a single style guide including a cinematic style guide, and a gentle flow into the next room in place of the hard cut; model sheets for the BlinBlin dancer; slow party-up by tier for every player; layers for other rooms; indoor plate with the floor painted separately, since words failed twice. Later: the PoolPlayer dancer and billiards room, rendered music in the game (needs phones), and the late bathroom boss, so every opponent needs a named hardest combo.

FLAC masters and art raws are in `~/.cache/tillandsias-project/`, on this machine only.

**Update, later on 2026-11-06.** The relaunch checks and the music pilot are done. Results: `plan/music-pilot-2026-11-06.md`. Checklist: `plan/relaunch-report-2026-11-06.md`, delivered to macuahuitl-fedora over Remote Control once it appeared in `ListAgents`, and answered: no restart needed. It will say when a relaunch would bring the XL base pin. Next are the art items. Music stage 3 needs the owner's phones.

**Seen on screen, Garden on autoplay, from 4 frames a second, muted:**
- Spin: the opponent turns through side, back and front on centre floor and finishes arms up, then moves right. It runs about 1 s into `YOUR TURN`.
- Crowding: Mācron stays well clear during play. After the fist bump he stands right beside the opponent, under his feet, without overlapping.
- Exit: `MUCHO MOJO`, Mācron steps in, fist-bump close-up, then about 4 s back in the garden with no walk out.
- Hard cut: confirmed. The garden changes to the bar between two frames, with no transition.
- Not judged: the lost open-palm cue during the overflow, which the frames can't settle. These are for the owner's eye. The rest of this file is the plan as written before the relaunch.

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
