"""The plate runner: from a compiled room, bake workflows and job files, collect outputs, and fit review sheets.

The GPU step is studio.run_workflow, an MCP tool: an agent (or person) reads jobs-*.json and queues one call per entry.
Prompts are baked per workflow because $prompt overrides don't reach TextEncodeQwenImageEditPlus (host bug 2001-stpr).
"""
from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from compiler import REPO, STYLE, RoomError, compile_room, level_fragment, load_spec, write_outputs

CACHE = Path.home() / ".cache/tillandsias-project/kumbia-art"
STAGE = Path("/work/tmp/imagegen/kumbia")
STUDIO = Path("/work/tmp/imagegen/studio")
TEMPLATE = REPO / "tool/art/workflows/qwen-frame.api.json"
ROOMS = REPO / "art_runs/rooms"


def bake_workflow(images, prompt, prefix, steps=4, size=(832, 1248)):
    """Qwen edit with N input images and no matte; the prompt goes into the graph."""
    wf = json.loads(TEMPLATE.read_text())
    for k in ("1", "2"):
        wf.pop(k)
    for i, name in enumerate(images):
        nid = str(60 + i)
        wf[nid] = {"_meta": {"title": f"${name}"}, "class_type": "LoadImage", "inputs": {"image": f"${name}"}}
        for enc in ("10", "11"):
            wf[enc]["inputs"][f"image{i + 1}"] = [nid, 0]
    for enc in ("10", "11"):
        wf[enc]["inputs"] = {k: v for k, v in wf[enc]["inputs"].items() if not k.startswith("image") or int(k[5:]) <= len(images)}
    wf["10"]["inputs"]["prompt"] = prompt
    wf["8"]["inputs"].update(width=size[0], height=size[1])
    wf["12"]["inputs"].update(steps=steps, cfg=1.0)
    if steps > 8:  # the Lightning LoRA is for 4 steps only
        del wf["30"]
        wf["5"]["inputs"]["model"] = ["4", 0]
    for k in ("40", "41"):
        wf.pop(k, None)
    wf["14"]["inputs"]["images"] = ["13", 0]
    wf["14"]["inputs"]["filename_prefix"] = prefix
    return wf


def plan(room, run, pass_no, count, seed, steps=4, bases=(), name=None, append=""):
    spec = load_spec(room)
    guide = ROOMS / spec["id"]
    write_outputs(spec, guide)  # always from the current spec; a refused layout plans nothing
    text = (guide / f"prompt-pass{pass_no}.txt").read_text().strip()
    if append:
        text = f"{text} {append}"
    run_dir = REPO / "art_runs" / run
    (run_dir / "workflows").mkdir(parents=True, exist_ok=True)
    staged = STAGE / run / "in"
    staged.mkdir(parents=True, exist_ok=True)
    name = name or f"p{pass_no}"
    wf_path = run_dir / "workflows" / f"{name}.api.json"
    jobs = []
    if pass_no == 1:
        shutil.copy(guide / "greybox.png", staged / "greybox.png")
        ref = REPO / STYLE["acceptedRooms"][spec["styleRef"]]
        Image.open(ref).convert("RGB").resize(tuple(spec.get("genSize", [832, 1248])), Image.LANCZOS).save(staged / "style.png")
        wf = bake_workflow(["layout", "style"], text, f"kk/{run}/{name}", steps, spec.get("genSize", (832, 1248)))
        jobs.append(dict(name=name, workflow=str(wf_path.relative_to(REPO)), inputs={"layout": str(staged / "greybox.png"), "style": str(staged / "style.png")},
                         overrides={"seed": seed}, count=count))
    else:
        if not bases:
            raise RoomError("pass 2 needs --from: chosen pass 1 images")
        wf = bake_workflow(["base"], text, f"kk/{run}/{name}", steps, spec.get("genSize", (832, 1248)))
        for i, base in enumerate(bases):
            target = staged / f"{Path(base).stem}.png"
            shutil.copy(base, target)
            jobs.append(dict(name=f"{name}-{Path(base).stem}", workflow=str(wf_path.relative_to(REPO)), inputs={"base": str(target)},
                             overrides={"seed": seed + i * 100}, count=count))
    wf_path.write_text(json.dumps(wf, indent=1, ensure_ascii=False) + "\n")
    (run_dir / "workflows" / f"{name}.prompt.txt").write_text(text + "\n")
    doc = dict(room=spec["id"], run=run, passNo=pass_no, steps=steps, promptSha256=hashlib.sha256(text.encode()).hexdigest(), jobs=jobs,
               how="Queue one studio.run_workflow per job, one at a time. Then: rooms.py collect --run " + run)
    out = run_dir / f"jobs-{name}.json"
    out.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n")
    return out, doc


def collect(run):
    """Copy this run's finished outputs to the cache: <job>-<seed>.png with provenance. Safe to repeat."""
    root = CACHE / run
    root.mkdir(parents=True, exist_ok=True)
    n = 0
    for prov in sorted(STUDIO.glob("st-*/*.provenance.json")):
        doc = json.loads(prov.read_text())
        wf = doc.get("workflow", {}).get("path", "")
        if not wf.startswith(f"art_runs/{run}/workflows/"):
            continue
        job = Path(wf).name.removesuffix(".api.json")
        base = [i for i in doc.get("inputs", []) if i["name"] == "base"]
        tag = f"{job}-{Path(base[0]['path']).stem}" if base else job
        png = prov.with_name(prov.name.removesuffix(".provenance.json"))
        shutil.copy(png, root / f"{tag}-{doc['seed']}.png")
        shutil.copy(prov, root / f"{tag}-{doc['seed']}.provenance.json")
        n += 1
    return root, n


def verify(run, url="http://studio:8188"):
    """Confirm at the engine (A1) that every job of this run carried the planned prompt."""
    import hashlib as _h
    import urllib.request
    planned = {}
    for f in (REPO / "art_runs" / run).glob("jobs-*.json"):
        planned[json.loads(f.read_text())["promptSha256"]] = f.name
    seen = {}
    hist = json.load(urllib.request.urlopen(f"{url}/history?max_items=1000", timeout=30))
    for v in hist.values():
        g = v["prompt"][2]
        if not any(f"/{run}/" in str(n["inputs"].get("image", "")) for n in g.values() if n.get("class_type") == "LoadImage"):
            continue
        sha = _h.sha256(g["10"]["inputs"]["prompt"].encode()).hexdigest()
        seen[sha] = seen.get(sha, 0) + 1
    stray = [s for s in seen if s not in planned]
    if stray or not seen:
        raise RoomError(f"engine prompts for {run} don't match its plan: seen {seen}, planned {list(planned)}")
    return {planned[s]: n for s, n in seen.items()}


def _phone(im, phone=(390, 844)):
    W, H = im.size
    vw = int(round(H * phone[0] / phone[1]))
    x = (W - vw) // 2
    return im.crop((x, 0, x + vw, H)).resize(phone, Image.LANCZOS)


def _plate(path):
    return Image.open(path).convert("RGB").resize((1024, 1536), Image.LANCZOS)


def metrics(im, floor):
    """Numbers to read beside the eye review. Nothing here accepts a plate (A6)."""
    H = im.height
    a = np.asarray(im.convert("HSV"), float) / 255
    upper = a[: int(.65 * H)]
    band = floor["tapBand"]["y"]
    b = np.asarray(im.convert("L"), float)[int(band[0] * H): int(band[1] * H), int(.153 * im.width): int(.847 * im.width)]
    gx, gy = np.abs(np.gradient(b, axis=1)), np.abs(np.gradient(b, axis=0))
    return dict(sat=round(float(upper[..., 1].mean()), 2), val=round(float(upper[..., 2].mean()), 2),
                bandLuma=round(float(b.mean()), 1), bandP98=round(float(np.percentile(b, 98)), 1), bandEdge=round(float((gx + gy).mean()), 1))


def water_hold(im, room_ids, floor):
    """Did the model keep the water where the guide put it? IoU of cyan paint against the water zone. None if no water."""
    if "water" not in floor["ids"]:
        return None
    want = room_ids == floor["ids"]["water"]
    if not want.any():
        return None
    rgb = np.asarray(im.convert("RGB"), float)
    R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    got = (B > R + 40) & (G > R + 30) & (B > 90) & (G > 90)
    return round(float((got & want).sum() / max(1, (got | want).sum())), 2)


def drift(im, floor, search=40):
    """Median distance (1024-wide px) from each authored floor line to the strongest nearby edge. Unreliable on
    reflective floors, so confirm with the overlay by eye (research: auto fit said 70 px on a plate that sits close)."""
    Hm = np.array(floor["floorHomography_st_to_px"]); W, H = floor["image"]
    g = np.asarray(im.convert("L").resize((W, H), Image.BICUBIC), float)
    G = np.hypot(np.gradient(g, axis=1), np.gradient(g, axis=0))
    offs = []
    for pts in floor["lines"].values():
        P = []
        for s, t in pts:
            q = Hm @ np.array([s, t, 1.0]); P.append(q[:2] / q[2])
        for i in range(1, len(P) - 1):
            v = P[i + 1] - P[i - 1]; L = np.hypot(*v)
            if L < 1e-6 or not (20 < P[i][0] < W - 20 and 20 < P[i][1] < H - 20):
                continue
            n = np.array([-v[1], v[0]]) / L
            vals = []
            for o in range(-search, search + 1):
                x, y = (P[i] + o * n).astype(int)
                vals.append(G[y, x] if 0 <= x < W and 0 <= y < H else 0)
            vals = np.array(vals)
            if vals.max() > 6:
                offs.append(abs(int(np.argmax(vals)) - search))
    if not offs:
        return None
    return dict(median=round(float(np.median(offs)), 1), p90=round(float(np.percentile(offs, 90)), 1), n=len(offs))


def sheet(room, run, pattern, cols=8, out=None, height=844):
    """Accepted rooms first, then each candidate at phone crop, with its name and numbers printed under it."""
    spec = load_spec(room); floor = json.loads((ROOMS / spec["id"] / "floor.json").read_text())
    ids = np.asarray(Image.open(ROOMS / spec["id"] / "ids.png"))
    files = sorted((CACHE / run).glob(pattern + ".png"))
    if not files:
        raise RoomError(f"nothing matches {pattern} in {CACHE / run}")
    scale = height / 844
    cw, ch = int(390 * scale), height
    cells = []
    for name, rel in STYLE["acceptedRooms"].items():
        cells.append((name.upper(), _plate(REPO / rel)))
    rows = []
    for f in files:
        im = _plate(f)
        m = metrics(im, floor); d = drift(im, floor); w = water_hold(im, ids, floor)
        rows.append(dict(file=f.name, **m, drift=d, waterIoU=w))
        cells.append((f.stem.split("-")[-1] + f" s{m['sat']} v{m['val']} d{d['median'] if d else '-'} w{w}", im))
    label = 22
    n = len(cells); nrows = (n + cols - 1) // cols
    S = Image.new("RGB", (cols * (cw + 6), nrows * (ch + label + 6)), (15, 15, 18))
    d = ImageDraw.Draw(S)
    for i, (text, im) in enumerate(cells):
        x, y = (i % cols) * (cw + 6), (i // cols) * (ch + label + 6)
        S.paste(_phone(im).resize((cw, ch), Image.LANCZOS), (x, y + label))
        d.text((x + 3, y + 4), text, fill=(235, 235, 235))
    out = Path(out) if out else REPO / "art_runs" / run / "sheets" / (pattern.replace("*", "").strip("-") + "-phone.png")
    out.parent.mkdir(parents=True, exist_ok=True)
    S.save(out)
    (out.with_suffix(".json")).write_text(json.dumps(rows, indent=1) + "\n")
    return out, rows


# --- proof: real sprites at the runtime's sizes -----------------------------------------------------------
def _atlas(path, key):
    man = json.loads((path / "manifest.json").read_text())["atlases"][key]
    return Image.open(path / man["image"]).convert("RGBA"), man


def _draw_sprite(base, atlas, man, frame, foot, height, reference=None):
    """As the scene: scale = height / nativeHeight(reference), drawn from the frame's anchor."""
    fr = man["frames"][frame]; ref = man["frames"][reference or man.get("referenceFrame", frame)]
    x, y, w, h = fr["rect"]
    if "aliasOf" in ref and "rect" not in ref:
        ref = man["frames"][ref["aliasOf"]]
    native = ref["rect"][3] / ref["pixelsPerUnit"]
    k = height / native / fr["pixelsPerUnit"]
    sp = atlas.crop((x, y, x + w, y + h))
    a = np.asarray(sp.getchannel("A")).copy(); a[a < 128] = 0; a[a >= 128] = 255
    sp.putalpha(Image.fromarray(a))
    if fr.get("flipX"):
        sp = sp.transpose(Image.FLIP_LEFT_RIGHT)
    sp = sp.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
    ax, ay = fr["anchor"]
    base.alpha_composite(sp, (int(foot[0] - ax * k), int(foot[1] - ay * k)))
    return dict(frame=frame, height=height, foot=[round(v) for v in foot])


def proof(room, run, plate, out_dir=None):
    """Writes floor overlay, cast proof at near and far marks, and the phone view beside the accepted rooms."""
    spec = load_spec(room); _, cam, floor, report = compile_room(spec)
    frag = level_fragment(spec, cam, floor)
    W, H = cam.W, cam.H
    im = _plate(plate).convert("RGBA")
    out = Path(out_dir) if out_dir else REPO / "art_runs" / run / "sheets"
    out.mkdir(parents=True, exist_ok=True)
    tag = Path(plate).stem
    # floor overlay: authored grid and path over the plate
    ov = im.copy(); d = ImageDraw.Draw(ov)
    Hm = np.array(floor["floorHomography_st_to_px"])
    for pts in floor["lines"].values():
        P = []
        for s, t in pts:
            q = Hm @ np.array([s, t, 1.0]); P.append(tuple(q[:2] / q[2]))
        d.line(P, fill=(255, 255, 0, 255), width=2) if len(pts) == 90 else [d.point(p, fill=(0, 255, 255, 255)) for p in P]
    x0, x1 = floor["phoneVisibleX"]
    d.rectangle([x0 * W, 0, x1 * W, H - 1], outline=(255, 0, 255, 255), width=2)
    d.line([0, cam.hz, W, cam.hz], fill=(255, 255, 0, 255), width=2)
    ov.convert("RGB").save(out / f"{tag}-floor-overlay.png")

    # cast at the marks, with the level's real numbers
    ens, party = REPO / "assets/art/ensemble", REPO / "assets/art/party"
    hero_img, hero = _atlas(party, "hero")
    gk_img, gk = _atlas(ens, "gatekeeper")
    guest_img, guest = _atlas(ens, "guest1")
    furn_img, furn = _atlas(ens, "furniture")
    scene = im.copy(); record = []

    def adult(y):
        return (y - cam.hz) / cam.eye

    draws = []
    for g in frag["crowd"]["guests"]:
        p = (g[0] * W, g[1] * H)
        draws.append((p[1], lambda p=p: record.append(_draw_sprite(scene, guest_img, guest, "standing_idle_a", p, adult(p[1]), "standing_idle_a"))))
    for pr in frag["crowd"]["props"]:
        p = (pr["at"][0] * W, pr["at"][1] * H)
        draws.append((p[1], lambda p=p, pr=pr: record.append(_draw_sprite(scene, furn_img, furn, "table", p, adult(p[1]) * pr["heightInAdults"], "table"))))
    c = frag["stage"]["challengers"][0]
    near_gk = (c["mark"][0] * W, c["mark"][1] * H)
    draws.append((near_gk[1], lambda: record.append(_draw_sprite(scene, gk_img, gk, gk.get("referenceFrame"), near_gk, adult(near_gk[1])))))
    home = (frag["stage"]["heroHome"][0] * W, frag["stage"]["heroHome"][1] * H)
    far = frag["departure"]["waypoints"][-1]; far = (far["x"] * W, far["y"] * H)
    stature = spec["cast"]["heroStature"]
    draws.append((home[1], lambda: record.append(_draw_sprite(scene, hero_img, hero, "rear_idle", home, adult(home[1]) * stature, "front_idle"))))
    draws.append((far[1], lambda: record.append(_draw_sprite(scene, hero_img, hero, "rear_idle", far, adult(far[1]) * stature, "front_idle"))))
    for _, fn in sorted(draws, key=lambda q: q[0]):
        fn()
    scene_rgb = scene.convert("RGB")
    scene_rgb.save(out / f"{tag}-cast-proof.png")

    # phone row: garden, bar, this plate, this plate with cast and the tap band marked
    phone = [_phone(_plate(REPO / r)) for r in STYLE["acceptedRooms"].values()]
    phone.append(_phone(im.convert("RGB")))
    cast = _phone(scene_rgb).convert("RGBA")
    band = Image.new("RGBA", cast.size, (0, 0, 0, 0)); bd = ImageDraw.Draw(band)
    by = spec["tapBand"]["y"]
    bd.rectangle([0, by[0] * 844, 390, by[1] * 844], fill=(255, 255, 255, 18), outline=(255, 255, 255, 120), width=1)
    bd.line([195, by[0] * 844, 195, by[1] * 844], fill=(255, 255, 255, 80)); bd.line([0, .81 * 844, 390, .81 * 844], fill=(255, 255, 255, 80))
    cast.alpha_composite(band); phone.append(cast.convert("RGB"))
    S = Image.new("RGB", (len(phone) * 396, 844), (15, 15, 18))
    for i, p in enumerate(phone):
        S.paste(p, (i * 396, 0))
    S.save(out / f"{tag}-phone-row.png")

    logical_h = 180 * 844 / 390

    def sizes(px):
        px = float(px)
        return dict(sourcePx=round(px, 1), logical=round(px / H * logical_h, 1), dp=round(px / H * 844, 1))

    meas = dict(
        heroNear=sizes(adult(home[1]) * stature), heroFar=sizes(adult(far[1]) * stature), challenger=sizes(adult(near_gk[1])),
        gardenHeroLogical=38.4, barHeroLogical=66.7,
    )
    im_rgb = im.convert("RGB")
    (out / f"{tag}-proof.json").write_text(json.dumps(dict(cast=meas, metrics=metrics(im_rgb, floor), drift=drift(im_rgb, floor)), indent=1) + "\n")
    return meas, out / f"{tag}-phone-row.png"


# --- level file --------------------------------------------------------------------------------------------
def write_level(room, out, base_level, background):
    spec = load_spec(room); _, cam, floor, _ = compile_room(spec)
    frag = level_fragment(spec, cam, floor)
    base = json.loads((REPO / base_level).read_text())
    extra = spec.get("level", {})
    doc = dict(id=spec["id"], title=spec.get("title", spec["id"].upper()), background=background)
    doc["music"] = extra.get("music", base["music"]); doc["rules"] = extra.get("rules", base["rules"]); doc["chart"] = extra.get("chart", base["chart"])
    doc["stage"] = frag["stage"]
    doc["crowd"] = dict(budgets=extra.get("budgets", base["crowd"]["budgets"]), guests=frag["crowd"]["guests"], props=frag["crowd"]["props"])
    doc["scenery"] = frag["scenery"]
    doc["departure"] = dict(threshold=extra.get("threshold", "far gateway"), **frag["departure"])
    doc["copy"] = extra.get("copy", base["copy"])
    Path(out).write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
    return doc


def check_level(room, level_path):
    """A level's marks against the compiled room: floor formula, walkable route, guests on standable ground."""
    spec = load_spec(room); p, cam, floor, _ = compile_room(spec)
    lv = json.loads(Path(level_path).read_text())
    ids = np.asarray(p.idm); idn = floor["ids"]
    walk = [idn[n] for n in floor["walkable"]]; stand = [idn[n] for n in floor["standable"]]
    W, H = cam.W, cam.H
    prob = []
    fl = lv["stage"]["floor"]
    eye = (fl["referenceFootY"] - fl["horizonY"]) / fl["referenceHeight"]
    if abs(eye - cam.eye) > .02 or abs(fl["horizonY"] - cam.hz / H) > .002:
        prob.append(f"stage.floor: eye {eye:.2f}, horizon {fl['horizonY']} disagree with the room's {cam.eye}, {cam.hz / H:.3f}")

    def on(field, xy, zones):
        x, y = int(xy[0] * W), int(xy[1] * H)
        win = ids[max(y - 3, 0):y + 4, max(x - 3, 0):x + 4]
        if not np.isin(win, zones).all():
            prob.append(f"{field}: {xy} isn't on allowed ground")

    st = lv["stage"]
    on("stage.heroHome", st["heroHome"], walk); on("stage.heroEntrance", st["heroEntrance"], walk); on("stage.heroRetreat", st["heroRetreat"], walk)
    for c in st["challengers"]:
        on(f"challenger {c['id']}.mark", c["mark"], walk); on(f"challenger {c['id']}.yieldMark", c["yieldMark"], walk + stand)
    for i, w in enumerate(lv["departure"]["waypoints"]):
        on(f"departure.waypoints[{i}]", [w["x"], st["heroHome"][1] + w["y"] - lv["departure"]["originY"]], walk)
    for i, g in enumerate(lv["crowd"]["guests"]):
        on(f"crowd.guests[{i}]", g, stand)
    for pr in lv["crowd"]["props"]:
        on(f"crowd.props {pr['id']}", pr["at"], stand)
    if prob:
        raise RoomError("level refused:\n  - " + "\n  - ".join(prob))
    return "ok"
