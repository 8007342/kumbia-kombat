#!/usr/bin/env python3
"""Add the pair drawings to the swing dancers' atlases, and Mācron's held turn to his: each old atlas stays pixel for pixel, with new shelves below, so no existing frame moves. Every new frame records `hold`, its holding hand in the frame's own pixels, as `anchor` does.
Writes swing-X-v3.png and macron-dance-v3.png, points the manifests at them, removes the images they replace (they are in git history), and copies finals under pair/final/. Run from the worktree root, once finish_pixels has run for the dancers and puppet.py for him."""
import hashlib, json, pathlib, shutil
from PIL import Image
RUN = "pair-20261106"; HERE = pathlib.Path("art_runs/duet-20261106/pair"); LANE = pathlib.Path("/work/tmp/imagegen/kumbia") / RUN / "finished"
HELD = pathlib.Path.home() / ".cache/tillandsias-project/kumbia-art/pair-20261106/held"
ENS = pathlib.Path("assets/art/ensemble"); PARTY = pathlib.Path("assets/art/party"); GUTTER = 2

def shelves(base, tiles, W):
    """Lays tiles out under base. Returns the atlas and each tile's top-left."""
    x, y, h = GUTTER, base.height + GUTTER, 0; at = {}
    for k, t in tiles.items():
        if x + t["im"].width + GUTTER > W: x, y, h = GUTTER, y + h + GUTTER, 0
        at[k] = (x, y); x += t["im"].width + GUTTER; h = max(h, t["im"].height)
    atlas = Image.new("RGBA", (W, y + h + GUTTER), (0, 0, 0, 0)); atlas.paste(base, (0, 0))
    for k, t in tiles.items(): atlas.paste(t["im"], at[k])
    return atlas, at

picks = json.load(open(HERE / "picks.json")); holds = json.load(open(HERE / "holds.json"))
mpath = ENS / "manifest.json"; manifest = json.load(open(mpath))
for dancer, c in picks.items():
    live = manifest["atlases"][dancer]; ppu = live["frames"]["occupied"]["pixelsPerUnit"]; d = HERE / "final" / dancer; d.mkdir(parents=True, exist_ok=True); tiles = {}
    for name, p in c["poses"].items():
        shutil.copy(LANE / f"{dancer}.{name}.png", d / f"{name}.png"); shutil.copy(LANE / f"{dancer}.{name}.finish.json", d / f"{name}.finish.json")
        im = Image.open(d / f"{name}.png").convert("RGBA"); b = im.getbbox(); sha = hashlib.sha256((d / f"{name}.png").read_bytes()).hexdigest(); hx, hy = holds[f"{dancer}.{name}"]
        b = (b[0], b[1], b[2], max(b[3], round(c["groundY"]) + 1))
        tiles[name] = dict(im=im.crop(b), ax=128 - b[0], ay=c["groundY"] - b[1], hold=[round(hx - b[0], 1), round(hy - b[1], 1)],
                           prov={"run": RUN, "raw": p["raw"], "seed": p["seed"], "sha256": sha, "selectedBy": "agent's eye", "accepted": False})
    old = live["image"]; base = Image.open(ENS / old).convert("RGBA")
    bottom = max(f["rect"][1] + f["rect"][3] for k, f in live["frames"].items() if k not in tiles) + GUTTER
    atlas, at = shelves(base.crop((0, 0, base.width, bottom)), tiles, base.width)
    for k, t in tiles.items():
        live["frames"][k] = {"rect": [*at[k], t["im"].width, t["im"].height], "anchor": [round(t["ax"], 1), round(t["ay"], 1)], "hold": t["hold"], "pixelsPerUnit": ppu, "status": "candidate", "facing": "front", "provenance": t["prov"]}
    name = f"{dancer}-v3.png"; atlas.save(ENS / name, optimize=True); live["image"] = name; live["imageWidth"] = atlas.width; live["imageHeight"] = atlas.height
    if old != name: (ENS / old).unlink()
    print(dancer, atlas.size, (ENS / name).stat().st_size // 1024, "KiB")
json.dump(manifest, open(mpath, "w"), indent=1, ensure_ascii=False); open(mpath, "a").write("\n")

ppath = PARTY / "manifest.json"; party = json.load(open(ppath)); hero = party["atlases"]["hero"]; M = json.load(open(HELD / "held.json")); O, H = M["origin"], M["hold"]; tiles = {}
fd = HERE / "final" / "macron"; fd.mkdir(parents=True, exist_ok=True)
for name in M["frames"]:
    shutil.copy(HELD / f"{name}.png", fd / f"{name}.png"); im = Image.open(fd / f"{name}.png").convert("RGBA"); b = im.getbbox(); b = (b[0], b[1], b[2], max(b[3], O[1] + 1))  # the floor point stays inside the frame
    tiles[name] = dict(im=im.crop(b), ax=O[0] - b[0], ay=O[1] - b[1], hold=[O[0] + H[0] - b[0], O[1] + H[1] - b[1]])
old = hero["image"]; base = Image.open(PARTY / old).convert("RGBA")
bottom = max(f["rect"][1] + f["rect"][3] for k, f in hero["frames"].items() if k not in tiles) + GUTTER
atlas, at = shelves(base.crop((0, 0, base.width, bottom)), tiles, base.width)
for k, t in tiles.items():
    hero["frames"][k] = {"rect": [*at[k], t["im"].width, t["im"].height], "anchor": [t["ax"], t["ay"]], "hold": t["hold"], "pixelsPerUnit": 8.0}
name = "macron-dance-v3.png"; atlas.save(PARTY / name, optimize=True); hero["image"] = name; hero["imageWidth"] = atlas.width; hero["imageHeight"] = atlas.height
if old != name: (PARTY / old).unlink()
print("hero", atlas.size, (PARTY / name).stat().st_size // 1024, "KiB")
json.dump(party, open(ppath, "w"), indent=1, ensure_ascii=False); open(ppath, "a").write("\n")
