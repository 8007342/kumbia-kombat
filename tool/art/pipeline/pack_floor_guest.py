#!/usr/bin/env python3
"""Finish a floor guest's picked candidates, pack them and write their atlas into the ensemble manifest.

Picks are data: art_runs/<run>/picks.json, {pose: seed}, chosen by eye from contact sheets. A pose with no pick is
left out, so a partly drawn guest can already ship the clips it has. Repeats are the motion set's own: see
tool/art/motion/party-floor.json. `standing_idle_a` is measuring only: the game scales a guest so this frame's height
is one adult, so its rect's height is the figure's height divided by the guest's stature.

Usage: pack_floor_guest.py <character> --run <run> --stature 1.0 [--root DIR]
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

from finish_local import finish, palette_of

ROOT = Path(__file__).resolve().parents[3]
CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"
ENSEMBLE = ROOT / "assets/art/ensemble"
SCALE = 3
PPU = 8.0
# frame id -> the drawing it shows
REPEATS = {f"{c}_{n}": f"{c}.{d}" for c, seq in {
    "groove": "aacc", "pair_dance": "aacc", "back_dance": "aacc", "sidestep": "abab", "glance": "aa", "clap": "ab", "cheer": "aa",
}.items() for n, d in zip("abcd", seq)}
GUTTER = 2


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("character")
    ap.add_argument("--run", required=True)
    ap.add_argument("--stature", type=float, default=1.0)
    a = ap.parse_args()
    run_dir = ROOT / "art_runs" / a.run
    picks = json.loads((run_dir / "picks.json").read_text())
    palette = palette_of(ROOT / "tool/art/palettes" / f"{a.character}-sheet.json")
    rig = {p["id"]: p for p in json.loads((ROOT / "art_runs/inputs" / f"{a.character}-v1/rig.json").read_text())["poses"]}
    drawn: dict[str, Image.Image] = {}
    out = run_dir / "final"
    for pose, seed in picks.items():
        im = finish(CACHE / a.run / "registered" / pose / f"{seed}.png", palette, SCALE)
        box = im.getbbox()
        drawn[pose] = im
        (CACHE / a.run / "final").mkdir(parents=True, exist_ok=True)
        im.save(CACHE / a.run / "final" / f"{pose}.png")
    # Shelf pack the drawings; repeats share a rect.
    width = 1024
    x = y = GUTTER
    shelf = 0
    place: dict[str, tuple[int, int, int, int, int, int]] = {}
    for pose, im in drawn.items():
        l, t, r, b = im.getbbox()
        w, h = r - l, b - t
        if x + w + GUTTER > width:
            x, y, shelf = GUTTER, y + shelf + GUTTER, 0
        place[pose] = (x, y, w, h, l, t)
        x, shelf = x + w + GUTTER, max(shelf, h)
    ref = next(p for p in ("pair_dance.a", "sidestep.a", "groove.a") if p in place)
    ref_h = place[ref][3]
    height = y + shelf + GUTTER
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    frames: dict[str, dict] = {}
    for pose, im in drawn.items():
        px, py, w, h, l, t = place[pose]
        sheet.paste(im.crop((l, t, l + w, t + h)), (px, py))
    def entry(pose: str) -> dict:
        px, py, w, h, l, t = place[pose]
        # The rig's support pivot and floor line, on the native grid, measured from the trimmed rect.
        return {"rect": [px, py, w, h], "anchor": [round(rig[pose]["pivotX"] / SCALE - l, 1), round(rig[pose]["groundY"] / SCALE - t, 1)],
                "pixelsPerUnit": PPU, "provenance": {"run": a.run, "pose": pose, "seed": picks[pose],
                "sha256": hashlib.sha256(drawn[pose].tobytes()).hexdigest()}}
    for fid, pose in REPEATS.items():
        if pose in place:
            frames[fid] = entry(pose)
    px, py, w, h, l, t = place[ref]
    frames["standing_idle_a"] = {"rect": [px, py, w, round(ref_h / a.stature)], "anchor": entry(ref)["anchor"], "pixelsPerUnit": PPU,
                                 "measureOnly": True}
    name = f"{a.character}-v1.png"
    sheet.save(ENSEMBLE / name, optimize=True)
    path = ENSEMBLE / "manifest.json"
    manifest = json.loads(path.read_text())
    manifest["atlases"][a.character] = {"image": name, "imageWidth": width, "imageHeight": height, "referenceFrame": "standing_idle_a", "stature": a.stature, "frames": frames}
    path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n")
    prov = json.loads((ENSEMBLE / "provenance.json").read_text())
    prov["assets"][name] = {"route": "qwen-frame, 2511 Lightning LoRA, $node overrides; tool/art/pipeline/pack_floor_guest.py", "definition": f"tool/art/characters/{a.character}.json",
                            "run": a.run, "picks": picks, "acceptedBy": "agent, proposal: plan/party-art-review-2026-11-07.md"}
    (ENSEMBLE / "provenance.json").write_text(json.dumps(prov, indent=2, ensure_ascii=False) + "\n")
    print(a.character, "drawings", len(drawn), "frames", len(frames), sheet.size)


if __name__ == "__main__":
    main()
