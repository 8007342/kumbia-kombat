# This wave's per-pose prompts never ran

Every frame here used the prompt baked into `tool/art/workflows/qwen-frame.api.json` at the time
("Redraw the man from image 1..."). `studio.run_workflow`'s prompt override skipped the
`TextEncodeQwenImageEditPlus` input, which is named `prompt`, yet the provenance sidecars and
`jobs.json` still show the per-pose text. Don't trust those fields (host issue 2001-stpr).

So nothing from this wave shows what the prompt can or can't do. Two-hand claps and the stocky build
worked or are expected to work once prompts arrive: see `art_runs/bartender-v1-20261105q/`. This run
stays as a draft until Gatekeeper is re-run, which is also the chance to restore his chubby build.
