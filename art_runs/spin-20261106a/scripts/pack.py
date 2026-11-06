#!/usr/bin/env python3
"""Pack the spin and clap candidates: an atlas PNG and .candidate.json per character, frame fields as in the live manifests. Mirrors are flips of finals,
named in `mirrorOf`. Mācron has no family spec: LANCZOS down to rear_idle's 8 ppu and a 64-colour palette taken from rear_idle itself. Run from the repo root."""
import hashlib, json, pathlib, shutil, sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, "tool/art/pipeline")
from register_frames import matte_mask, bbox
RUN = "spin-20261106a"; HOME = pathlib.Path.home() / ".cache/tillandsias-project/kumbia-art" / RUN
OUT = pathlib.Path("art_runs") / RUN; FINAL = OUT / "final"; CAND = OUT / "candidate"; CAND.mkdir(exist_ok=True)
LANE = pathlib.Path("/work/tmp/imagegen/kumbia") / RUN / "finished"
picks = json.load(open(OUT / "picks.json"))
ens = json.load(open("assets/art/ensemble/manifest.json"))["atlases"]; hero = json.load(open("assets/art/party/manifest.json"))["atlases"]["hero"]
FACING = {"spin_front": "front", "spin_34_r": "front_3q", "spin_side_r": "profile", "spin_back34_r": "rear_3q", "spin_back": "rear",
          "spin_back34_l": "rear_3q", "spin_side_l": "profile", "spin_34_l": "front_3q"}  # pack_atlas.py's words
MIRROR = {"spin_back34_l": "spin_back34_r", "spin_side_l": "spin_side_r", "spin_34_l": "spin_34_r"}
SPIN = ["spin_front", "spin_34_r", "spin_side_r", "spin_back34_r", "spin_back", "spin_back34_l", "spin_side_l", "spin_34_l"]

def shelf(tiles, W=1024, gutter=2):
    """tiles {id: RGBA crop}, returns (atlas, {id: (x, y)})."""
    x = y = h = 0; at = {}
    for k, im in tiles.items():
        if x + im.width + gutter > W: x, y, h = 0, y + h + gutter, 0
        at[k] = (x + gutter, y + gutter); x += im.width + gutter; h = max(h, im.height)
    atlas = Image.new("RGBA", (W, y + h + 2 * gutter), (0, 0, 0, 0))
    for k, im in tiles.items(): atlas.paste(im, at[k])
    return atlas, at

def write(char, atlas_id, tiles, meta, ppu, ref):
    atlas, at = shelf({k: t["im"] for k, t in tiles.items()})
    name = f"{atlas_id}-candidate"
    atlas.save(CAND / f"{name}.png", optimize=True)
    frames = {}
    for k, t in tiles.items():
        x, y = at[k]
        frames[k] = {"rect": [x, y, t["im"].width, t["im"].height], "anchor": [round(t["ax"], 1), round(t["ay"], 1)], "pixelsPerUnit": ppu, "status": "candidate", **t["extra"]}
    json.dump({"status": "candidate for review, not accepted, not promoted; picks by agent's eye", "atlas": atlas_id, "image": f"{name}.png", "imageWidth": atlas.width, "imageHeight": atlas.height,
               "referenceFrame": ref, **meta, "frames": frames}, open(CAND / f"{name}.candidate.json", "w"), indent=1, ensure_ascii=False)
    print(name, atlas.size, len(frames))
    return atlas, frames

for char in ("gatekeeper", "bartender"):
    c = picks[char]; live = ens[char]; d = FINAL / char; d.mkdir(parents=True, exist_ok=True); ppu = live["frames"]["occupied"]["pixelsPerUnit"]; ims = {}
    for name in c["poses"]:
        shutil.copy(LANE / f"{char}.{name}.png", d / f"{name}.png"); shutil.copy(LANE / f"{char}.{name}.finish.json", d / f"{name}.finish.json")
        ims[name] = Image.open(d / f"{name}.png").convert("RGBA")
    for m, src in MIRROR.items():
        ims[m] = ims[src].transpose(Image.FLIP_LEFT_RIGHT); ims[m].save(d / f"{m}.png")
    tiles = {}
    for name in SPIN + [p for p in c["poses"] if p.startswith("flare")]:
        im = ims[name]; b = im.getbbox(); p = c["poses"].get(MIRROR.get(name, name))
        extra = {"facing": FACING.get(name, "front"), "provenance": {"run": RUN, "raw": p["raw"], "seed": p["seed"], "sha256": hashlib.sha256((d / f"{name}.png").read_bytes()).hexdigest(), "selectedBy": "agent's eye", "accepted": False}}
        if name in MIRROR: extra["mirrorOf"] = MIRROR[name]
        tiles[name] = {"im": im.crop(b), "ax": 128 - b[0], "ay": c["groundY"] - b[1], "extra": extra}
    write(char, f"{char}-spin", tiles, {"clips": {"spin": {"order": SPIN, "loop": True, "note": "continuous turn; reverse it for the other direction"}, "flare": [p for p in c["poses"] if p.startswith("flare")]}, "family": c["family"]}, ppu, "spin_front")

# Mācron: no family, so this is the finish
x, y, w, h = hero["frames"]["rear_idle"]["rect"]; ax, ay = hero["frames"]["rear_idle"]["anchor"]
src = Image.open("assets/art/party/" + hero["image"]).convert("RGBA").crop((x, y, x + w, y + h)); sa = np.asarray(src); solid = sa[..., 3] > 128
HEAD = np.where(solid[60:190].any(0))[0]; head_cx = (HEAD.min() + HEAD.max()) / 2; head_w = int(HEAD.max() - HEAD.min() + 1)
pal_im = Image.fromarray(sa[solid][:, :3].reshape(-1, 1, 3)).quantize(64, method=Image.MEDIANCUT); print("rear_idle head", head_w, "centre", head_cx, "anchor", ax, ay)
d = FINAL / "macron"; d.mkdir(parents=True, exist_ok=True); tiles = {}
HEADTOP = {"clap_high_alt": 150}
for name, p in picks["macron"]["poses"].items():
    r = Image.open(HOME / "raw" / p["raw"] / f"{p['seed']}.png").convert("RGBA"); a = np.array(r); m = matte_mask(a[..., 3]); x0, y0, x1, y1 = bbox(m)
    # Same floor-to-antenna height as rear_idle: tried against head width, which sat above the ear discs and came out 5% too big. Band gives the head's centre only.
    top = HEADTOP.get(name, y0); rows = m[top + int(.24 * (y1 - top)) : top + int(.32 * (y1 - top))]; rc = np.where(rows.any(0))[0]; raw_hw = int(rc.max() - rc.min() + 1); raw_cx = (rc.min() + rc.max()) / 2
    s = 316 / (y1 - top)
    r.putalpha(Image.fromarray((m * 255).astype(np.uint8)))
    small = r.convert("RGBa").resize((round(r.width * s), round(r.height * s)), Image.LANCZOS).convert("RGBA")
    ar = np.array(small); keep = ar[..., 3] > 128
    q = Image.fromarray(ar[..., :3]).quantize(palette=pal_im, dither=Image.NONE).convert("RGB")
    out = np.dstack([np.array(q), keep * 255]).astype(np.uint8); b = bbox(keep); crop = Image.fromarray(out).crop(b)
    crop.save(d / f"{name}.png"); ca = np.asarray(crop)[..., 3] > 0
    cx = raw_cx * s - b[0]
    print(name, "scale", round(s, 3), "size", crop.size, "raw head", raw_hw, "centre in crop", round(cx, 1), "height above floor", crop.height, "rear_idle", h)
    tiles[name] = {"im": crop, "ax": cx + (ax - head_cx), "ay": crop.height - (h - ay), "extra": {"facing": "rear", "provenance": {"run": RUN, "raw": p["raw"], "seed": p["seed"], "sha256": hashlib.sha256((d / f"{name}.png").read_bytes()).hexdigest(), "selectedBy": "agent's eye", "accepted": False}}}
write("macron", "hero-rear-clap", tiles, {"clips": {"rear_clap": {"order": ["clap_apart", "clap_together", "clap_release"], "loop": True, "note": "clap_together lands on the beat; clap_release is optional, and rear_idle can stand in for it"}, "rear_clap_high_alternate": {"order": ["clap_apart", "clap_high_alt"], "note": "arms longer than his model; owner's call"}},
      "matchesLive": {"frame": "rear_idle", "rect": [x, y, w, h], "anchor": [ax, ay]}}, 8.0, "clap_apart")
