Relaunch checklist from kumbia-kombat, written for macuahuitl-fedora and not yet delivered: tray_build 56.11.6.2+8ab23b59434614e2, models_tsv 84978ce69ab1, all checks pass.

- Cache survived: ~/.cache/tillandsias-project/kumbia-art is still 1.1 GB.
- ACE-Step files listed: studio.models shows on_disk true for ace-dit/acestep_v1.5_xl_turbo_bf16, ace-te/qwen_0.6b_ace15, ace-te/qwen_4b_ace15 and ace-vae/ace_1.5_vae, and the loaders list them. The 2511 Lightning LoRA is on disk too.
- Marker test (2001-stpr): fixed. ComfyUI /history shows the override in TextEncodeQwenImageEditPlus node 10's prompt, replacing the baked sentinel.
- First ACE-Step GPU run: success on cuda, no node_not_pinned. run_0 took 15.5 s for an 88.2 s take, output 48 kHz stereo FLAC, 11.65 MB, peak -0.5 dB, mean -14 dB. The seed reached both the encoder and KSampler at /history. Nobody has listened to it. Later batches: 24 takes at about 10 s each, fetch 0 ms, with 6 of 12 Garden and 7 of 12 lawn passing our timing filter.
- WebGL: ANGLE (NVIDIA RTX A5000) in a visible window. 60 fps versus the old 7-9: about 26 s of Garden on autoplay, p50 16.7 ms, p95 16.8 ms, GPU otherwise idle. One 504 ms frame at most, cause not traced.

Three things to look at:
- That first ACE run spent 452 s in the fetch stage although the files were already on_disk true, and the run_workflow description says nothing is fetched. It did not repeat: the next run, a 12-take batch, showed fetch 0 ms and about 10.9 s per take.
- Before the window had focus, rAF gave 1 frame in 32 s even though visibilityState was visible.
- Audio render shortfall: in a visible window, Web Audio rendered 44.26 s of the garden_mojo score in 45 s of wall clock, seen at an AudioWorklet and again at MediaRecorder (44.16 s of 45.07 s). The capture ran about 2% fast at 99.97 BPM against 98. The pool_swing score captured clean at 144.05 BPM. Cause not traced; it could be the container's audio path or the score's load.

Also: uv python install 3.13 works. cloud.usage works. cloudflare.scope_probe works, with pages.read missing. flutter analyze shows the 4 baseline notes and 174 tests pass; the first flutter attempt was refused with podman failed at step source (timeout), and the retry after studio.start finished succeeded.

models_tsv could not be compared against the checkout: this project has no images/imagegen/models.tsv.
