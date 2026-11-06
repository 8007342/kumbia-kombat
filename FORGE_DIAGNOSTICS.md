# FORGE_DIAGNOSTICS

The live, short file: what is broken or awkward in this forge now, and how to work around it. Last
checked 2026-11-05 on `work/1833-cast`.

- Distilled lessons and known-wrong records: [LESSONS_LEARNED.md](LESSONS_LEARNED.md)
- Dated session logs, verbatim: [plan/diagnostics/forge-diagnostics-2026-10.md](plan/diagnostics/forge-diagnostics-2026-10.md)

Keep this file short. When an issue is fixed, delete it. Put a lasting lesson in `LESSONS_LEARNED.md`
and any long session log in `plan/diagnostics/`.

## Host and studio

| Issue | Workaround | Status |
|---|---|---|
| **2001-stpr.** `studio.run_workflow` prompt overrides didn't reach `TextEncodeQwenImageEditPlus`, and provenance recorded them anyway | None needed on 56.11.6.2. Older baked workflows still run. Runs made before the fix keep their false provenance | Fixed: marker test passed at ComfyUI `/history`, 2026-11-06, tray `56.11.6.2+8ab23b59434614e2` |
| **2001-bwgl.** Visible browser windows had no hardware WebGL, so the game ran on software CanvasKit at 7-9 fps | None needed on 56.11.6.2. Headless still has SwiftShader WebGL, so measure in a visible window | Fixed: ANGLE on the NVIDIA RTX A5000, 60 fps over about 26 s of Garden autoplay, 2026-11-06 |
| Before a visible window has focus, `requestAnimationFrame` barely runs (1 frame in 32 s) although `visibilityState` says visible | Click the window, or send CDP `Emulation.setFocusEmulationEnabled`, before measuring. Discard earlier readings | Open, macuahuitl-fedora is filing it |
| The first `studio.run_workflow` with newly pinned ACE-Step files spent 452 s in the `fetch` stage although they were `on_disk` | Allow for about 8 minutes on first use. Later runs showed 0 ms | Seen once. macuahuitl-fedora's likely explanation, not checked: hashing about 20 GB fetched by hand without `.sha256` sidecars |
| An MCP result over 4 MiB per line is refused with `ResponseTooLarge` | Keep browser eval results under about 3 MB. Larger ones under the cap are saved to a file you can decode | Seen 2026-11-06 |
| A tray restart doesn't replace a running forge's lane process | Tool-server fixes need a forge relaunch | Open |
| Git mirror says "expired or unavailable while auto-auth re-authenticates" (Vault Agent token expiry) | Restart the mirror | Seen 2026-11-05 |
| `/work/tmp/imagegen/` dies with the forge | Copy studio outputs to `~/.cache/tillandsias-project` during a wave, and commit what matters | By design |
| `object_info` lists classes that `run_workflow` refuses (`node_not_pinned`) | Prove each new class with a one-image run. Pinned models match by basename, not Hub path | By design |
| Overrides reach only `$`-titled nodes, and one node has one title | Bake denoise per workflow, and pass per-pose numbers as images | Node-id overrides planned |
| Refusals in general | Report verbatim to the host coordinator. Never relax a guard or gate to progress | Rule |

## Git and publishing

| Issue | Workaround | Status |
|---|---|---|
| `gh` is unauthenticated, and the GitHub connector returned 404 on this private repo | Pushes through the mirror work. Don't expect to open PRs from a forge | `gh` checked 2026-11-05; connector last seen 2026-10-18 |
| Discipline is level 2 with `default_branch: warn`, but the remedy text still says pushes "are refused" | Read the verdict, not the wording. A push to `main` will be accepted, so don't use one as a probe. Keep to `work/*` then `game` then `main` | Open |
| `.openspec.yaml` with an unquoted ISO date is rejected at pre-receive | Quote date-like YAML values | Last seen 2026-10-29 |
| Peers can't read this private repo, and forges have no route to claude.ai | Paste content into messages. Put review files in `/work/tmp/imagegen/kumbia/review/<name>/` and ask the host coordinator to publish | By design |

## Preview and browser

The first two rows were last seen on 2026-10-18, and nobody has re-tested them since.

| Issue | Workaround |
|---|---|
| The managed static preview returned 404 for `canvaskit/` and `music/` | Publish the root project with `runtime=wrangler`. After a Flutter build, reload if Wrangler exited on a transient ENOENT |
| The Flutter dev route was refused by `browser.open` (`URL_NOT_ALLOWED`) | Use the release build through the preview |
| Synthetic pointer events don't unlock audio | Use CDP `Input.dispatchMouseEvent`. Headless has no speakers, so it can't approve music |
| Large screenshots flood tool output | Use `Page.captureScreenshot` with JPEG at quality 50 or DPR 1, and never print base64 |
| Minified release builds hide scene exceptions | Debug in a debug web build |
| The editor's Dart LSP reports phantom `package:flutter` errors (last seen 2026-10-18) | `flutter analyze` is ground truth |

## Shell

- zsh: `$B:a`, `$B:t` and similar are history modifiers, so write `"${B}:path"`. `$var` doesn't word-split
  in `for`. A leading `====` is an expansion error.
- Stop processes with `pgrep` then `kill <PID>`, never `pkill -f`.
- The Bash policy hook refuses `rm` on a variable path, so name literal paths.

## Project state that looks like a bug

- Gatekeeper v3 is too skinny against the chubby original art. Check build against source on the next wave.
- Treat prompts and provenance in `art_runs/gatekeeper-v3-20261105q/` as false (`PROMPTS-NOT-APPLIED.md`).
- `.claude/skills/art-family/SKILL.md` and `styles/party-pixel.json` still describe the SDXL route. Current
  frames come from the Qwen route in `tool/art/pipeline/README.md`.
- On a host without hardware WebGL the game runs at about 7-9 fps. It no longer pauses itself on those stalls, but it
  looks choppy and taps can score late.

## Fixed since the old logs

Checked 2026-11-05. `tillandsias-plan` is on PATH, `dart` resolves to 3.13.5, and `core.hooksPath` is set
to `.git/hooks`. If one of these breaks again, the archive has the old fixes.
