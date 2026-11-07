#!/usr/bin/env python3
"""Add the skirt drawings to the swing dancers' atlases: the old atlas stays pixel for pixel, with new shelves below it, so no existing frame moves. Mirrors are flips of finals, named in `mirrorOf`.
Writes swing-X-v2.png, points the manifest at it (v1 is in git history), and copies finals under final/<dancer>/. Run from the worktree root, once finish_pixels has run."""
import hashlib, json, pathlib, shutil
from PIL import Image
RUN = "duet-20261106"; HERE = pathlib.Path("art_runs") / RUN; LANE = pathlib.Path("/work/tmp/imagegen/kumbia") / RUN / "finished"
ENS = pathlib.Path("assets/art/ensemble"); mpath = ENS / "manifest.json"; manifest = json.load(open(mpath)); picks = json.load(open(HERE / "picks.json"))["skirt"]
GUTTER = 2
for dancer, c in picks.items():
    live = manifest["atlases"][dancer]; ppu = live["frames"]["occupied"]["pixelsPerUnit"]; d = HERE / "final" / dancer; d.mkdir(parents=True, exist_ok=True); tiles = {}
    for name, p in c["poses"].items():
        shutil.copy(LANE / f"{dancer}.{name}.png", d / f"{name}.png"); shutil.copy(LANE / f"{dancer}.{name}.finish.json", d / f"{name}.finish.json")
        im = Image.open(d / f"{name}.png").convert("RGBA"); b = im.getbbox(); sha = hashlib.sha256((d / f"{name}.png").read_bytes()).hexdigest()
        prov = {"run": RUN, "raw": p["raw"], "seed": p["seed"], "sha256": sha, "selectedBy": "agent's eye", "accepted": False}
        tiles[name] = dict(im=im.crop(b), ax=128 - b[0], ay=c["groundY"] - b[1], extra={"facing": "front", "provenance": prov})
        flip = im.transpose(Image.FLIP_LEFT_RIGHT); fb = flip.getbbox(); m = name[:-1] + "l"
        tiles[m] = dict(im=flip.crop(fb), ax=128 - fb[0], ay=c["groundY"] - fb[1], extra={"facing": "front", "mirrorOf": name, "provenance": prov})
    old = pathlib.Path(live["image"]); base = Image.open(ENS / old).convert("RGBA"); W = base.width
    # A re-run must not stack on its own last output: keep only what the frames before this run use.
    bottom = max(f["rect"][1] + f["rect"][3] for k, f in live["frames"].items() if not k.startswith("skirt_")) + GUTTER
    base = base.crop((0, 0, W, bottom))
    x, y, h = GUTTER, base.height + GUTTER, 0; at = {}
    for k, t in tiles.items():
        if x + t["im"].width + GUTTER > W: x, y, h = GUTTER, y + h + GUTTER, 0
        at[k] = (x, y); x += t["im"].width + GUTTER; h = max(h, t["im"].height)
    atlas = Image.new("RGBA", (W, y + h + GUTTER), (0, 0, 0, 0)); atlas.paste(base, (0, 0))
    for k, t in tiles.items():
        atlas.paste(t["im"], at[k]); fx, fy = at[k]
        live["frames"][k] = {"rect": [fx, fy, t["im"].width, t["im"].height], "anchor": [round(t["ax"], 1), round(t["ay"], 1)], "pixelsPerUnit": ppu, "status": "candidate", **t["extra"]}
    name = f"{dancer}-v2.png"; atlas.save(ENS / name, optimize=True); live["image"] = name; live["imageWidth"] = atlas.width; live["imageHeight"] = atlas.height
    print(dancer, atlas.size, (ENS / name).stat().st_size // 1024, "KiB")
json.dump(manifest, open(mpath, "w"), indent=1, ensure_ascii=False); open(mpath, "a").write("\n")
