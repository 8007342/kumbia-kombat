# Tasks

Measure each gain alone, on the same poses and seeds, before stacking the next. Poses for
quick tests: `groove.down_l`, `left_hand.peak`, `finish_turn.turn_in`. Proof clip:
`groove` + `left_hand` (12 drawings), as in `character-sprite-pipeline` 6.2.

## 1. Editable workflows and sync

- [ ] 1.1 Commit one UI-format workflow with groups and notes; verify it opens in the studio with its layout and no missing nodes
- [ ] 1.2 Generate its API file; verify conversion matches a recording of the frontend's own output, and that a check fails on drift
- [ ] 1.3 Add install and pull commands; verify both on a fresh studio and after a real operator edit, including the conflict report
- [ ] 1.4 Check whether userdata survives a studio restart, and record the result in the design
- [ ] 1.5 Test one subgraph through conversion, including `$` titles, against the frontend; record whether D3 can relax
- [ ] 1.6 Verify whether `run_workflow` returns every save node's output from one graph; record the result and settle D4's job shape

## 2. Fix what we have, on the single pass

- [ ] 2.1 Confirm the installed `IPAdapterPlus.py` has the hidden composition weight, by reading the studio's copy or by a seed-locked A/B between `style and composition` and `style transfer` (D8)
- [ ] 2.2 Square the reference crops, and bake off `linear` against `style transfer` for head and outfit, masked, on the three poses; record the winner and contact sheets
- [ ] 2.3 Paint a real face into the rig proxy: eyes, brows, nose shadow and mouth, in rig colours; verify `check_poses.py` still passes and the head variance score improves
- [ ] 2.4 Retest base denoise at 0.5, 0.56, 0.62 and 0.7 with the painted proxy; record the lowest value that keeps faces alive, and uniform-cell share per value
- [ ] 2.5 A/B the checkpoint's VAE against `sdxl_vae.safetensors` for edges; record which version the file is, if it can be determined
- [ ] 2.6 Try a fixed seed across a clip against the current per-pose seed policy; record drift scores

## 3. Model sheet

- [ ] 3.1 Prove the Qwen-Image-Edit-2511 classes with a one-image run at template settings; report any refusal verbatim
- [ ] 3.2 Generate front, 3/4 and rear views, plus a head sheet, from the rig and current references, comparing against an SDXL route; verify the flat-background rule holds
- [ ] 3.3 Get owner acceptance; this also closes `character-sprite-pipeline` 6.1
- [ ] 3.4 Point identity references at the accepted sheet, and verify an edit marks dependents stale

## 4. Region passes and edges

- [ ] 4.1 Add hat and shirt passes at about 0.35; verify outside pixels are byte-identical, and compare identity scores against the base alone
- [ ] 4.2 Clamp the matte to the dilated rig silhouette; verify no opaque pixels outside it, and pick the margin from three poses
- [ ] 4.3 Compare `finish.sample` `centre` and `majority` at game size; record the choice
- [ ] 4.4 Add orphan-pixel cleanup; verify on fixtures that it never changes byte-exact masked regions unexpectedly, and review at game size
- [ ] 4.5 Decide whether uniform-cell share earns a place in selection, by comparing it with owner picks

## 5. Head route decision

- [ ] 5.1 Count head buckets across `opponent-64` for Gatekeeper and Bartender; report before authoring anything
- [ ] 5.2 Build the crop-and-stitch head pass, testing the pixel LoRA at 0.8, 0.4 and off
- [ ] 5.3 Author head-and-hat parts for the buckets the proof clip needs, from the model sheet
- [ ] 5.4 Add part compositing, with placement and clipping from the rig; verify the hand-in-front case on `left_hand.peak`
- [ ] 5.5 Deliver both routes as proof-clip GIFs at game size; the owner picks one, and the design records it

## 6. Repair and scale

- [ ] 6.1 Add the edit repair pass; verify on three deliberately flagged frames that grid, palette and silhouette gates apply
- [ ] 6.2 Measure time per pass, then estimate a full character run
- [ ] 6.3 Wire the accepted sequence into `art.py`, extending stage keys per D12; verify reruns reuse earlier passes
- [ ] 6.4 Run Gatekeeper's full 64 drawings; verify selection scores are real, and deliver a candidate atlas and gallery
- [ ] 6.5 Run Bartender with definitions only as the generality check; verify no workflow or pipeline change is needed

## 7. Layers and documents

- [ ] 7.1 Write layer data at pack time; verify the current game renders the same with or without it
- [ ] 7.2 Produce one masked accessory overlay on the proof clip; verify it aligns with the base frames, and record what broke
- [ ] 7.3 Record settings sources in workflow notes and definitions (D13)
- [ ] 7.4 Update `plan/comfyui-cheatsheet.md` with tested values, replacing guesses, and run its class check
- [ ] 7.5 Update the `art-family` skill and `tool/art/pipeline/README.md` with the new flow; verify by following them end to end

## Follow-up

- Run the Wan VACE bake-off from `character-sprite-pipeline` task 9.2 only after section 5, so it's compared with the improved stills.
- Ask the owner about a character LoRA once the proof clips are accepted. Check first whether `TrainLoraNode` is pinned.
- Consider a Lightning LoRA request for 2511 if repairs prove useful and 40 steps is the bottleneck.
- Link the new documents from `plan/README.md`, which was out of scope for this research task.
- Archive this change after owner review, then sync the spec.
