#!/usr/bin/env python3
"""Build the static sprite review gallery: index.json, images and the viewer.

Rerun it to pick up new atlases and runs; it reads the repository and never
writes to it (everything goes to --out). Discovered without being asked:

  assets/art/ensemble/manifest.json     shipped atlases
  **/*.candidate.json                   packed atlases awaiting acceptance
  art_runs/inputs/*                     rig renders, shown as "rig stand-in"
  art_runs/*                            runs, from whichever final/<pose>.png exist

--source adds a further file or folder of any of those shapes.

Missing data stays missing: a drawing the pose table expects but the set lacks
is listed with `missing: true` and a reason. Anything assumed (timing, anchor,
native grid) is named in the set's fields and warnings, so the viewer can say so.

Usage:
  ~/.cache/kumbia-art/bin/python tool/art/gallery/build_gallery.py --out DIR [--source PATH]...
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import io
import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    raise SystemExit("build_gallery needs Pillow: run it with ~/.cache/kumbia-art/bin/python")

HERE = Path(__file__).resolve().parent
DEFAULT_ROOT = HERE.parents[2]
VIEWER_FILES = ("index.html", "gallery.css", "core.js", "gallery.js")

# No motion data: the viewer says this was assumed rather than authored.
ASSUMED_BEATS_PER_DRAWING = 0.5
# Rig renders are drawn at generation scale; every family so far uses 8.
ASSUMED_PIXEL_SCALE = 8
# Same order as the game's reference frames: challengers ('ready'), guests
# ('standing_idle_a'), the hero ('front_idle').
GAME_REFERENCE_FRAMES = ("ready", "standing_idle_a", "front_idle")

# Runtime phrases, read off ChallengerChoreography.sample for a 1-beat note gap:
# anticipation lead min(.25, gap*.25); duration min(.65, gap*.75), accent to .32
# of it and follow to .70; settle holds until the next anticipation.
_MOVE = lambda side, accent: [(f"anticipate_{side}", .25), (accent, .208), (f"follow_{side}", .247), ("settle", .295)]  # noqa: E731
RUNTIME_PHRASES = {
    "left_hand": _MOVE("left", "left_hand"),
    "right_hand": _MOVE("right", "right_hand"),
    "left_foot": _MOVE("left", "left_foot"),
    "right_foot": _MOVE("right", "right_foot"),
    "lead_in": [("occupied", 1.0), ("turn_in", 1.0), ("ready", 1.0)],
    "watch": [("watch_left", .5), ("watch_right", .5)],
    "cleared": [("approve", .5), ("turn_out", .25), ("cede", .25), ("invite", 1.0)],
    "pass": [("approve", .75)],
    "fail": [("recover", .75)],
}
RUNTIME_SOURCE = "lib/gameplay/challenger_choreography.dart, for a 1-beat note gap"


def read_json(path: Path):
    """Parsed JSON, or None when the file is absent, unreadable or malformed."""
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return None


def is_number_list(value, n: int) -> bool:
    return (isinstance(value, list) and len(value) == n
            and all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in value))


def slug(text: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "-", text).strip("-") or "set"


class ImageStore:
    """Copies images into out/img under their content hash, so a rerun never
    serves a stale frame from a browser cache and unchanged files are not rewritten."""

    def __init__(self, out: Path):
        self.dir = out / "img"
        self.dir.mkdir(parents=True, exist_ok=True)
        self.used: set[str] = set()

    def load(self, path: Path):
        """(relative url, RGBA image), or (None, reason). The other session may be
        writing the file right now, so a partial PNG is a reported miss, not a crash."""
        try:
            data = path.read_bytes()
            im = Image.open(io.BytesIO(data))
            im.load()
        except FileNotFoundError:
            return None, "file not found"
        except OSError as e:
            return None, f"unreadable image ({e})"
        name = hashlib.sha256(data).hexdigest()[:20] + ".png"
        dest = self.dir / name
        if not dest.exists():
            fd, tmp = tempfile.mkstemp(dir=self.dir, suffix=".tmp")
            with os.fdopen(fd, "wb") as f:
                f.write(data)
            os.chmod(tmp, 0o644)
            os.replace(tmp, dest)
        self.used.add(name)
        return f"img/{name}", im

    def prune(self) -> None:
        for p in self.dir.iterdir():
            if p.is_file() and p.name not in self.used:
                p.unlink()


class Repo:
    """Read-only access to definitions under the repository root."""

    def __init__(self, root: Path):
        self.root = root
        self.families = []
        for p in sorted((root / "tool/art/families").glob("*.json")):
            spec = read_json(p)
            if isinstance(spec, dict):
                self.families.append((p, spec))

    def rel(self, path: Path) -> str:
        try:
            return str(path.resolve().relative_to(self.root))
        except ValueError:
            return str(path)

    def motion(self, name):
        data = read_json(self.root / "tool/art/motion" / f"{name}.json") if name else None
        return data if isinstance(data, dict) else None

    def family_at(self, ref):
        """A family named by a run or candidate. Runs may record an absolute path
        from another checkout, so the part after tool/art/ is looked up here first."""
        if not ref:
            return None, None
        text = str(ref)
        tail = text[text.index("tool/art/"):] if "tool/art/" in text else text
        for candidate in (self.root / tail, Path(text)):
            spec = read_json(candidate) if candidate.is_file() else None
            if isinstance(spec, dict):
                return candidate, spec
        return None, None

    def family_with_atlas(self, atlas):
        for path, spec in self.families:
            if any(t.get("atlas") == atlas for t in spec.get("targets", [])):
                return path, spec
        return None, None

    def family_with_rig(self, folder: Path):
        rel = self.rel(folder)
        for path, spec in self.families:
            if spec.get("rigInputs") == rel:
                return path, spec
        return None, None

    def rig_of(self, spec):
        if not spec or not spec.get("rigInputs"):
            return None
        rig = read_json(self.root / spec["rigInputs"] / "rig.json")
        return rig if isinstance(rig, dict) else None


def family_facts(spec) -> dict:
    """What a family says about its frames. Every value is None when unknown."""
    facts = {"character": None, "motion": None, "room": None, "pixelScale": None,
             "frameId": "{clip}_{drawing}", "poses": [], "referencePose": None}
    if not spec:
        return facts
    notes = spec.get("$notes") or {}
    facts["character"] = notes.get("character")
    facts["motion"] = notes.get("motionSet")
    target = next((t for t in spec.get("targets", []) if t.get("type") == "kumbiaManifest"), {})
    facts["room"] = target.get("room")
    facts["frameId"] = target.get("frameId", facts["frameId"])
    frame = spec.get("frame") or {}
    native = frame.get("native") or {}
    if native.get("perRoom"):
        native = native.get(facts["room"]) or {}
    facts["pixelScale"] = native.get("pixelScale")
    facts["referencePose"] = (frame.get("scale") or {}).get("referencePose")
    poses = [p for p in spec.get("poses", []) if isinstance(p, dict) and p.get("id")]
    poses.sort(key=lambda p: p.get("order", 0))  # stable: keeps clip grouping by first seen
    facts["poses"] = [p["id"] for p in poses]
    return facts


def clip_of(pose_id: str) -> str:
    return pose_id.split(".", 1)[0]


def trimmed(im):
    """Opaque bounding box as x, y, w, h; None for a wholly transparent image."""
    box = im.convert("RGBA").getchannel("A").getbbox()
    return None if box is None else (box[0], box[1], box[2] - box[0], box[3] - box[1])


def build_clips(frames_by_pose: dict, pose_table: list, motion, warnings: list) -> list:
    """Motion clips in authored order, then anything the motion set does not name.
    A drawing the table expects and the set lacks stays in place as `missing`."""
    groups: dict[str, list] = {}
    for pid in list(pose_table) + [p for p in frames_by_pose if p not in pose_table]:
        groups.setdefault(clip_of(pid), []).append(pid)
    authored = {c["id"]: c for c in (motion or {}).get("clips", []) if isinstance(c, dict) and c.get("id")}
    aliases = {}
    for alias, pose in (motion or {}).get("runtimeAliases", {}).items():
        aliases.setdefault(pose, []).append(alias)

    clips = []
    for cid in list(authored) + [c for c in groups if c not in authored]:
        pids = groups.get(cid, [])
        spec = authored.get(cid)
        if spec and spec.get("drawings") and len(pids) != spec["drawings"]:
            warnings.append(f"clip {cid}: motion says {spec['drawings']} drawings, pose table has {len(pids)}")
        if spec and not pids:
            # The motion set counts drawings but only the pose table names them.
            pids = [f"{cid}.?{i + 1}" for i in range(spec.get("drawings", 0))]
        if not pids:
            continue
        if spec and isinstance(spec.get("durationBeats"), (int, float)) and spec["durationBeats"] > 0:
            duration = float(spec["durationBeats"])
            timing = {"source": "motion",
                      "note": f"motion data: {duration:g} beats over {len(pids)} evenly spaced drawings"}
            beats = duration / len(pids)
        else:
            beats = ASSUMED_BEATS_PER_DRAWING
            duration = beats * len(pids)
            timing = {"source": "assumed",
                      "note": f"no motion data: assumed {beats:g} beats per drawing"}
        drawings = []
        for pid in pids:
            d = {"poseId": pid, "beats": round(beats, 6)}
            if aliases.get(pid):
                d["aliases"] = aliases[pid]
            frame = frames_by_pose.get(pid)
            if isinstance(frame, dict) and "img" in frame:
                d.update(frame)
            else:
                d["missing"] = True
                d["reason"] = frame if isinstance(frame, str) else "no frame in this set"
            drawings.append(d)
        clips.append({
            "id": cid,
            "kind": "motion" if spec else "group",
            "loop": spec.get("loop", True) if spec else True,
            "durationBeats": round(duration, 6),
            "view": spec.get("view") if spec else None,
            "timing": timing,
            "events": spec.get("events", []) if spec else [],
            "drawings": drawings,
        })
    return clips


def runtime_clips(frames_by_pose: dict, motion) -> list:
    """How the game strings the 20 runtime frames together on beats."""
    aliases = (motion or {}).get("runtimeAliases") or {}
    if not aliases:
        return []
    clips = []
    for name, steps in RUNTIME_PHRASES.items():
        drawings = []
        for alias, beats in steps:
            pose = aliases.get(alias)
            d = {"poseId": pose or alias, "beats": beats, "aliases": [alias]}
            frame = frames_by_pose.get(pose)
            if isinstance(frame, dict) and "img" in frame:
                d.update(frame)
            else:
                d["missing"] = True
                d["reason"] = frame if isinstance(frame, str) else "no frame in this set"
            drawings.append(d)
        clips.append({
            "id": f"game:{name}", "kind": "runtime", "loop": True,
            "durationBeats": round(sum(b for _, b in steps), 6), "view": None,
            "timing": {"source": "game", "note": RUNTIME_SOURCE}, "events": [], "drawings": drawings,
        })
    return clips


def counts_of(clips: list) -> dict:
    motion = [d for c in clips if c["kind"] != "runtime" for d in c["drawings"]]
    missing = sum(1 for d in motion if d.get("missing"))
    return {"present": len(motion) - missing, "missing": missing, "expected": len(motion)}


def game_reference(frames_by_pose, extra_frames, motion, reference_frame, rig, pixel_scale, native_div, facts):
    """Image pixels per game reference height. The game scales a whole atlas by one
    frame's height (EnsembleAtlasDefinition.nativeHeight), never per pose."""
    aliases = (motion or {}).get("runtimeAliases") or {}
    named = dict(extra_frames)
    for alias, pose in aliases.items():
        if isinstance(frames_by_pose.get(pose), dict):
            named.setdefault(alias, frames_by_pose[pose])
    for name in GAME_REFERENCE_FRAMES:
        frame = named.get(name)
        if isinstance(frame, dict) and "rect" in frame:
            return {"frame": name, "heightPx": frame["rect"][3], "approx": False,
                    "note": f"height of frame '{name}'"}
    # Props and old atlases: the game sizes these case by case, not by this frame.
    frame = named.get(reference_frame)
    if isinstance(frame, dict) and "rect" in frame:
        return {"frame": reference_frame, "heightPx": frame["rect"][3], "approx": True,
                "note": f"not how the game sizes this atlas; height of its listed reference '{reference_frame}'"}
    # Set lacks the frame the game scales by: the rig's own bbox is the only other measure.
    if isinstance(rig, dict) and pixel_scale:
        by_id = {p.get("id"): p for p in rig.get("poses", []) if isinstance(p, dict)}
        wanted = [aliases.get("ready"), (motion or {}).get("referencePose"), facts.get("referencePose")]
        for pose_id in filter(None, wanted):
            box = by_id.get(pose_id, {}).get("bbox")
            if is_number_list(box, 4):
                height = (box[3] - box[1]) / pixel_scale * native_div
                return {"frame": pose_id, "heightPx": round(height, 2), "approx": True,
                        "note": f"this set has no reference frame; rig bbox of {pose_id}"}
    # No rig measure either: the motion set's own reference pose, if this set drew it.
    pose_id = (motion or {}).get("referencePose") or facts.get("referencePose")
    frame = frames_by_pose.get(pose_id)
    if isinstance(frame, dict) and "rect" in frame:
        return {"frame": pose_id, "heightPx": frame["rect"][3], "approx": True,
                "note": f"not the frame the game scales by; height of {pose_id}"}
    return None


def finish_set(repo, *, sid, character, kind, source, run_id, status, facts, motion, frames_by_pose,
               extra_frames=None, reference_frame=None, rig=None, native_div=1, native_note=None,
               warnings=None, pose_table=None, anchor_source="atlas", atlas_image=None) -> dict:
    warnings = warnings if warnings is not None else []
    table = pose_table if pose_table is not None else facts["poses"]
    clips = build_clips(frames_by_pose, table, motion, warnings)
    counts = counts_of(clips)
    clips += runtime_clips(frames_by_pose, motion)
    if counts["present"] == 0:
        warnings.append("no frames yet")
    elif counts["missing"]:
        warnings.append(f"partial: {counts['present']} of {counts['expected']} drawings present")
    return {
        "id": sid,
        "character": character or "unknown",
        "sourceKind": kind,
        "sourcePath": source,
        "atlasImage": atlas_image,
        "runId": run_id,
        "status": status,
        "room": facts.get("room"),
        "motionSet": (motion or {}).get("id"),
        "nativeDivisor": native_div,
        "nativeNote": native_note or "1 image pixel = 1 native pixel",
        "anchorSource": anchor_source,
        "gameReference": game_reference(frames_by_pose, extra_frames or {}, motion, reference_frame, rig,
                                        facts.get("pixelScale"), native_div, facts),
        "counts": counts,
        "warnings": warnings,
        "clips": clips,
    }


def atlas_set(repo, store, *, sid, name, atlas, base: Path, kind, status, source, facts, motion, rig, warnings, run_id):
    """A set from a packed atlas block: manifest entry or candidate JSON."""
    raw = atlas.get("frames") if isinstance(atlas.get("frames"), dict) else {}
    image = atlas.get("image")
    url, im = store.load(base / image) if image else (None, "atlas names no image")
    atlas_error = None
    if url is None:
        atlas_error = f"atlas image {image}: {im}"
        warnings.append(atlas_error)
    elif atlas.get("imageWidth") not in (None, im.width) or atlas.get("imageHeight") not in (None, im.height):
        warnings.append(f"atlas says {atlas.get('imageWidth')}x{atlas.get('imageHeight')}, "
                        f"image is {im.width}x{im.height}")

    aliases = (motion or {}).get("runtimeAliases") or {}
    template = facts["frameId"]
    by_frame_id = {}
    for pid in facts["poses"]:
        if "." in pid:
            clip, drawing = pid.split(".", 1)
            by_frame_id[template.format(clip=clip, drawing=drawing)] = pid

    def clean(fid, f):
        if atlas_error:
            return atlas_error
        if not isinstance(f, dict):
            return "malformed frame entry"
        rect, anchor = f.get("rect"), f.get("anchor")
        if not is_number_list(rect, 4) or not is_number_list(anchor, 2):
            return "frame has no usable rect and anchor"
        x, y, w, h = rect
        if w <= 0 or h <= 0 or x < 0 or y < 0 or x + w > im.width or y + h > im.height:
            return f"rect {rect} is outside the {im.width}x{im.height} image"
        out = {"frameId": fid, "img": url, "rect": rect, "anchor": anchor}
        if f.get("mirror") is True:
            out["mirror"] = True
        return out

    frames_by_pose, extra = {}, {}
    for fid, f in raw.items():
        entry = clean(fid, f)
        pose = None
        if isinstance(f, dict):
            if f.get("aliasOf"):  # a copy of a drawing the atlas already has
                if isinstance(entry, dict):
                    extra[fid] = entry
                continue
            pose = (f.get("provenance") or {}).get("pose")
        pose = pose or aliases.get(fid) or by_frame_id.get(fid)
        if isinstance(entry, dict):
            extra[fid] = entry
        if pose is None:
            # No pose id: group the drawings a_b_c by their name, as the game does.
            m = re.fullmatch(r"(.+)_([a-z])", fid)
            pose = f"{m.group(1)}.{m.group(2)}" if m else f"{fid}.{fid}"
        if isinstance(frames_by_pose.get(pose), dict):
            warnings.append(f"frames for pose {pose} collide; kept the first, ignored {fid}")
            continue
        frames_by_pose[pose] = entry

    if not raw:
        warnings.append("atlas lists no frames")
    return finish_set(repo, sid=sid, character=name, kind=kind, source=source, run_id=run_id, status=status,
                      facts=facts, motion=motion, frames_by_pose=frames_by_pose, extra_frames=extra,
                      reference_frame=atlas.get("referenceFrame"), rig=rig, warnings=warnings, atlas_image=image)


def manifest_sets(repo, store, path: Path) -> list:
    data = read_json(path)
    source = repo.rel(path)
    if not isinstance(data, dict) or not isinstance(data.get("atlases"), dict):
        return [broken_set(repo, f"shipped:{slug(source)}", source, "manifest", "shipped", "not a readable atlas manifest")]
    sets = []
    for name, atlas in data["atlases"].items():
        warnings = []
        if not isinstance(atlas, dict):
            sets.append(broken_set(repo, f"shipped:{slug(name)}", source, "manifest", "shipped", "malformed atlas entry"))
            continue
        _, spec = repo.family_with_atlas(name)
        facts = family_facts(spec)
        motion = repo.motion(facts["motion"])
        if motion:
            warnings.append(f"poses named through {motion['id']} runtime aliases; this art predates that pose table")
        sets.append(atlas_set(repo, store, sid=f"shipped:{slug(name)}", name=name, atlas=atlas, base=path.parent,
                              kind="manifest", status="shipped", source=source, facts=facts, motion=motion,
                              rig=repo.rig_of(spec), warnings=warnings, run_id=None))
    return sets


def candidate_set(repo, store, path: Path) -> dict:
    source = repo.rel(path)
    stem = path.name[: -len(".candidate.json")]
    data = read_json(path)
    if not isinstance(data, dict):
        return broken_set(repo, f"candidate:{slug(stem)}", source, "candidate", "candidate", "candidate JSON is unreadable")
    _, spec = repo.family_at(data.get("family"))
    facts = family_facts(spec)
    warnings = []
    if data.get("family") and not spec:
        warnings.append(f"family {data['family']} not found; expected drawings unknown")
    motion = repo.motion(facts["motion"])
    frames = data.get("frames") if isinstance(data.get("frames"), dict) else {}
    runs = sorted({(f.get("provenance") or {}).get("run") for f in frames.values()
                   if isinstance(f, dict)} - {None})
    return atlas_set(repo, store, sid=f"candidate:{slug(stem)}", name=facts["character"] or data.get("atlas") or stem,
                     atlas=data, base=path.parent, kind="candidate", status="candidate", source=source, facts=facts,
                     motion=motion, rig=repo.rig_of(spec), warnings=warnings, run_id=", ".join(runs) or None)


def rig_frame(url, im):
    """A frame's trimmed rect in this image's own pixels, or a reason for a miss."""
    box = trimmed(im)
    if box is None:
        return "image is wholly transparent"
    return {"img": url, "rect": list(box), "box": box}


def anchored(frame: dict, pose: dict | None, divisor: float, warnings: list, pid: str, use_pivot=True) -> dict:
    """Same mapping as pack_atlas: support-foot pivot and ground line, relative to the
    trimmed rect. No rig entry means no known foot: bottom-centre, and the set says so."""
    x, y, w, h = frame["box"]
    has_pivot = isinstance(pose, dict) and isinstance(pose.get("pivotX"), (int, float)) and isinstance(pose.get("groundY"), (int, float))
    if has_pivot and use_pivot:
        anchor = [round(pose["pivotX"] / divisor - x, 1), round(pose["groundY"] / divisor - y, 1)]
        assumed = False
    else:
        anchor = [round(w / 2, 1), h]
        assumed = True
        warnings.append(f"{pid}: no rig pivot, anchor assumed at the bottom centre of the drawing")
    out = {"img": frame["img"], "rect": frame["rect"], "anchor": anchor}
    if assumed:
        out["anchorAssumed"] = True
    return out


def rig_set(repo, store, folder: Path) -> dict:
    """Rig renders: flat false colour regions (or a proxy), never finished art."""
    source = repo.rel(folder)
    rig = read_json(folder / "rig.json")
    warnings = []
    if not isinstance(rig, dict):
        rig = {}
        warnings.append("no readable rig.json: pose order and foot anchors unknown")
    rig_poses = [p for p in rig.get("poses", []) if isinstance(p, dict) and p.get("id")]
    _, spec = repo.family_with_rig(folder)
    facts = family_facts(spec)
    motion = repo.motion(facts["motion"] or folder.name)
    if motion is None:
        character_def = read_json(repo.root / "tool/art/characters" / f"{rig.get('character')}.json")
        if isinstance(character_def, dict):
            motion = repo.motion((character_def.get("motion") or {}).get("set"))
    native_div = facts["pixelScale"]
    native_note = f"{native_div} rig pixels = 1 native pixel (family spec)" if native_div else None
    if not native_div:
        native_div = ASSUMED_PIXEL_SCALE
        native_note = f"no family spec: assumed {native_div} rig pixels = 1 native pixel"
        warnings.append(native_note)

    table = [p["id"] for p in rig_poses]
    by_id = {p["id"]: p for p in rig_poses}
    on_disk = sorted(p.name[: -len(".regions.png")] for p in folder.glob("*.regions.png"))
    on_disk += [p.name[: -len(".proxy.png")] for p in folder.glob("*.proxy.png")
                if p.name[: -len(".proxy.png")] not in on_disk]
    frames, proxies = {}, 0
    for pid in table + [p for p in on_disk if p not in by_id]:
        proxy, regions = folder / f"{pid}.proxy.png", folder / f"{pid}.regions.png"
        chosen = proxy if proxy.exists() else regions
        url, im = store.load(chosen)
        if url is None:
            frames[pid] = f"{chosen.name}: {im}"
            continue
        proxies += chosen is proxy
        frame = rig_frame(url, im)
        if isinstance(frame, str):
            frames[pid] = frame
            continue
        # Anchors stay in image pixels here: the frame is drawn from this same image.
        frames[pid] = anchored(frame, by_id.get(pid), 1, warnings, pid)
    return finish_set(repo, sid=f"rig:{slug(folder.name)}", character=rig.get("character") or facts["character"] or folder.name,
                      kind="rig", source=source, run_id=folder.name, status="rig stand-in", facts=facts, motion=motion,
                      frames_by_pose=frames, rig=rig, native_div=native_div, native_note=native_note, warnings=warnings,
                      pose_table=table or on_disk, anchor_source=f"rig pivot; {proxies} proxy, {len(frames) - proxies} regions images")


def run_set(repo, store, folder: Path) -> dict:
    """A run's final/<pose>.png: whichever poses exist so far, unpacked."""
    source = repo.rel(folder)
    run = read_json(folder / "run.json")
    warnings = []
    if not isinstance(run, dict):
        run = {}
        warnings.append("no readable run.json: family, pose list and anchors unknown")
    path, spec = repo.family_at(run.get("family"))
    if run.get("family") and not spec:
        warnings.append(f"family {run['family']} not found; expected drawings unknown")
    if spec and run.get("familySha256"):
        if hashlib.sha256(path.read_bytes()).hexdigest() != run["familySha256"]:
            warnings.append("the family changed after this run: anchors come from the current rig.json")
    facts = family_facts(spec)
    motion = repo.motion(facts["motion"])
    rig = repo.rig_of(spec)
    by_id = {p["id"]: p for p in (rig or {}).get("poses", []) if isinstance(p, dict) and p.get("id")}
    divisor = facts["pixelScale"]
    if by_id and not divisor:
        warnings.append("family gives no pixelScale: anchors assumed at the bottom centre")

    frames = {}
    for png in sorted((folder / "final").glob("*.png")):
        pid = png.name[: -len(".png")]
        url, im = store.load(png)
        if url is None:
            frames[pid] = im
            continue
        frame = rig_frame(url, im)
        if isinstance(frame, str):
            frames[pid] = frame
            continue
        frames[pid] = anchored(frame, by_id.get(pid), divisor or 1, warnings, pid, use_pivot=bool(divisor))
    assumed = sum(1 for f in frames.values() if isinstance(f, dict) and f.get("anchorAssumed"))
    return finish_set(repo, sid=f"run:{slug(folder.name)}", character=facts["character"] or run.get("character"),
                      kind="run", source=source, run_id=run.get("run") or folder.name, status="candidate", facts=facts,
                      motion=motion, frames_by_pose=frames, rig=rig, warnings=warnings,
                      anchor_source=f"rig pivot; {assumed} assumed" if assumed else "rig pivot")


def broken_set(repo, sid, source, kind, status, reason) -> dict:
    return {"id": sid, "character": "unknown", "sourceKind": kind, "sourcePath": source,
            "atlasImage": None, "runId": None, "status": status, "room": None, "motionSet": None, "nativeDivisor": 1,
            "nativeNote": "", "anchorSource": "none", "gameReference": None,
            "counts": {"present": 0, "missing": 0, "expected": 0}, "warnings": [reason], "clips": []}


def classify(path: Path, depth: int = 1) -> list:
    """(kind, path) for what a --source holds; a plain folder is looked through once."""
    if path.is_file():
        if path.name.endswith(".candidate.json"):
            return [("candidate", path)]
        if path.suffix == ".json":
            return [("manifest", path)]
        return []
    if not path.is_dir():
        return []
    if (path / "rig.json").exists() or any(path.glob("*.regions.png")):
        return [("rig", path)]
    if (path / "final").is_dir() or (path / "run.json").exists():
        return [("run", path)]
    found = []
    for candidate in sorted(path.glob("*.candidate.json")):
        found.append(("candidate", candidate))
    if depth > 0:
        for child in sorted(p for p in path.iterdir() if p.is_dir()):
            found.extend(classify(child, depth - 1))
    return found


def discover(root: Path) -> list:
    found = []
    manifest = root / "assets/art/ensemble/manifest.json"
    if manifest.exists():
        found.append(("manifest", manifest))
    for base in (root / "assets", root / "art_runs"):
        if base.is_dir():
            found.extend(("candidate", p) for p in sorted(base.rglob("*.candidate.json")))
    runs = root / "art_runs"
    if runs.is_dir():
        for child in sorted(p for p in (runs / "inputs").glob("*") if p.is_dir()):
            found.extend(k for k in classify(child, 0) if k[0] == "rig")
        for child in sorted(p for p in runs.iterdir() if p.is_dir() and p.name not in ("inputs", "selections")):
            found.extend(k for k in classify(child, 0) if k[0] == "run")
    return found


def backgrounds(root: Path, store) -> tuple:
    """Opaque room paintings. Sprite sheets in the same folders have alpha and are left out."""
    rooms, notes = [], []
    for room in ("garden", "bar", "party"):
        count = 0
        for png in sorted((root / "assets/art" / room).glob("*.png")):
            try:
                with Image.open(png) as im:
                    size = im.size
                    alpha = im.convert("RGBA").getchannel("A").getextrema()
            except OSError as e:
                notes.append(f"{room}/{png.name}: unreadable ({e})")
                continue
            if alpha[0] < 255:
                continue
            url, _ = store.load(png)
            if url:
                rooms.append({"id": f"{room}/{png.name}", "room": room, "img": url,
                              "width": size[0], "height": size[1]})
                count += 1
        if not count:
            notes.append(f"assets/art/{room}/ has no opaque room background")
    return rooms, notes


def game_scale(root: Path) -> dict:
    """The numbers behind true game size, read from the game's source so they cannot
    drift. If the code moved, game size is reported unavailable rather than guessed."""
    layout = root / "lib/gameplay/party_layout.dart"
    scene = root / "lib/gameplay/garden_scene.dart"
    try:
        layout_src, scene_src = layout.read_text(), scene.read_text()
    except OSError as e:
        return {"available": False, "reason": f"cannot read the game's layout code ({e})"}
    width = re.search(r"logicalWidth\s*=\s*([\d.]+)", layout_src)
    challenger = re.search(r"floorYield,\s*isBar \? ([\d.]+) : ([\d.]+)\)", scene_src)
    hero = re.search(r"homeY = isBar \? ([\d.]+) : ([\d.]+);", scene_src)
    stature = re.search(r"_adultHeight\(viewport, room, floor, stature: ([\d.]+)\)", scene_src)
    if not (width and challenger and hero and stature):
        return {"available": False, "reason": "garden_scene.dart or party_layout.dart no longer match the expected code"}
    marks = {"garden": (challenger.group(2), hero.group(2)), "bar": (challenger.group(1), hero.group(1))}
    rooms = {}
    for room, (foot, hero_foot) in marks.items():
        m = re.search(rf"'{room}':\s*PartyRoomLayout\(.*?PartyFloorPlane\(\s*horizonY:\s*([\d.]+),"
                      r"\s*referenceFootY:\s*([\d.]+),\s*referenceHeight:\s*([\d.]+)", layout_src, re.S)
        if not m:
            return {"available": False, "reason": f"no floor plane found for {room}"}
        rooms[room] = {"horizonY": float(m.group(1)), "referenceFootY": float(m.group(2)),
                       "referenceHeight": float(m.group(3)), "challengerFootY": float(foot),
                       "heroFootY": float(hero_foot)}
    return {"available": True, "logicalWidth": float(width.group(1)), "heroStature": float(stature.group(1)),
            "rooms": rooms, "source": "lib/gameplay/party_layout.dart, garden_scene.dart"}


def tempi(root: Path) -> list:
    data = read_json(root / "assets/music/manifest.json")
    scores = data.get("scores") if isinstance(data, dict) else None
    return [{"id": s.get("id"), "title": s.get("title"), "baseBpm": s.get("baseBpm"), "fullBpm": s.get("fullBpm")}
            for s in scores or [] if isinstance(s, dict)]


def resolve_source(text: str, root: Path) -> Path:
    """Repository paths win: a relative --source must not pick up the same path in
    whatever checkout the command happens to be run from."""
    p = Path(text)
    if p.is_absolute():
        return p.resolve()
    return (root / p).resolve() if (root / p).exists() else p.resolve()


def build(root: Path, out: Path, sources: list) -> dict:
    root, out = root.resolve(), out.resolve()
    if root == out or root.is_relative_to(out):
        raise SystemExit(f"--out {out} would overwrite the repository")
    out.mkdir(parents=True, exist_ok=True)
    repo, store = Repo(root), ImageStore(out)
    warnings = []
    targets = discover(root)
    for text in sources:
        path = resolve_source(text, root)
        found = classify(path)
        if not found:
            warnings.append(f"--source {text}: nothing viewable there")
        targets.extend(found)

    sets, seen = [], set()
    for kind, path in targets:
        key = path.resolve()
        if key in seen:
            continue
        seen.add(key)
        if kind == "manifest":
            sets.extend(manifest_sets(repo, store, path))
        elif kind == "candidate":
            sets.append(candidate_set(repo, store, path))
        elif kind == "rig":
            sets.append(rig_set(repo, store, path))
        else:
            sets.append(run_set(repo, store, path))

    # Same-named sources from different folders must both stay reachable.
    used: dict[str, int] = {}
    for s in sets:
        used[s["id"]] = used.get(s["id"], 0) + 1
        if used[s["id"]] > 1:
            s["id"] = f"{s['id']}-{used[s['id']]}"

    rooms, notes = backgrounds(root, store)
    index = {
        "schema": 1,
        "generatedAt": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "sets": sets,
        "backgrounds": rooms,
        "backgroundNotes": notes,
        "game": game_scale(root),
        "tempi": tempi(root),
        "warnings": warnings,
    }
    for name in VIEWER_FILES:
        shutil.copyfile(HERE / name, out / name)
    fd, tmp = tempfile.mkstemp(dir=out, suffix=".tmp")
    with os.fdopen(fd, "w") as f:
        json.dump(index, f, indent=1, ensure_ascii=False)
    os.chmod(tmp, 0o644)
    os.replace(tmp, out / "index.json")  # a viewer reloading mid-build sees the old or new index, never half
    store.prune()
    return index


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", required=True, help="output folder to serve as static files")
    ap.add_argument("--source", action="append", default=[], help="extra file or folder (repeatable)")
    ap.add_argument("--root", default=str(DEFAULT_ROOT), help="repository to read (default: the one holding this script)")
    a = ap.parse_args(argv)
    index = build(Path(a.root), Path(a.out), a.source)
    for s in index["sets"]:
        c = s["counts"]
        print(f"{s['id']:<42} {s['status']:<13} {c['present']:>3}/{c['expected']:<3} {s['character']}")
    print(f"{len(index['sets'])} sets, {len(index['backgrounds'])} backgrounds -> {Path(a.out).resolve()}")
    for w in index["warnings"] + index["backgroundNotes"]:
        print(f"note: {w}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
