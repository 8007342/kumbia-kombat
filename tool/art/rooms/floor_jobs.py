"""Bake the two GPU routes for a separately painted floor, and stage their inputs. Queue each with studio.run_workflow.

  flat:   Qwen paints a slab texture straight from above; floor.py texture warps it through the room's camera.
  refine: Qwen repaints the coded floor at low denoise; only the floor is kept, under the matte.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

from plates import STAGE, bake_workflow
from compiler import REPO

FLAT = ("Image 1 shows a polished stone floor in a pixel art game, as a sample of its pixel technique and palette only. "
        "Paint a flat texture seen straight from above, with no perspective, filling the whole picture: one big polished slab of "
        "near-black violet marble, with thin irregular veins of dim plum and a little faint old gold, and fine mottled texture, "
        "as late 16-bit pixel art with very fine small pixels. The lighting is flat and even, and the surface is plain stone from edge to edge.")
REFINE = ("Image 1 is a game background in late 16-bit pixel art. Keep the composition exactly: every wall, pilaster, door, the platform, "
          "every floor joint and every reflection stay at the same place and size. Repaint only the texture of the floor, as dark polished marble, "
          "nearly black with a violet cast, with fine mottled pixel texture and thin faint veins, and thin straight joints between large slabs, "
          "keeping its long soft reflections of the lamps and pale columns. The picture has very fine small pixels, moody low-key light and deep soft shadows.")


def main():
    run = "room-cool-crowd-v2-floor"
    out = REPO / "art_runs/rooms/cool-crowd/workflows"
    out.mkdir(parents=True, exist_ok=True)
    staged = STAGE / run / "in"
    staged.mkdir(parents=True, exist_ok=True)
    bar = Image.open(REPO / "assets/art/bar/bar-interior.png").convert("RGB").crop((220, 800, 800, 1380)).resize((832, 832), Image.NEAREST)
    bar.save(staged / "bar-floor.png")
    wf = bake_workflow(["sample"], FLAT, f"kk/{run}/flat", 4, (832, 832))
    (out / "floor-flat.api.json").write_text(json.dumps(wf, indent=1, ensure_ascii=False) + "\n")
    for denoise in (35, 55):
        wf = bake_workflow(["base"], REFINE, f"kk/{run}/refine{denoise}", 4, (832, 1248))
        wf["71"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["60", 0], "vae": ["7", 0]}}
        wf["12"]["inputs"]["latent_image"] = ["71", 0]
        wf["12"]["inputs"]["denoise"] = denoise / 100
        wf.pop("8", None)
        (out / f"floor-refine{denoise}.api.json").write_text(json.dumps(wf, indent=1, ensure_ascii=False) + "\n")
    for f in sys.argv[1:]:
        Image.open(f).convert("RGB").resize((832, 1248), Image.LANCZOS).save(staged / Path(f).name)
    print(staged)


if __name__ == "__main__":
    main()
