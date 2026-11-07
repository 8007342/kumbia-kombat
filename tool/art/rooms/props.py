#!/usr/bin/env python3
"""One set of furniture drawings, baked to each room's pixel size and light.

    props.py masters   cut the drawn props into art_runs/rooms/crowd-props/masters/
    props.py bake      write assets/art/props/<room>.png and manifest.json
    props.py sheet OUT a review sheet: every set at game size, on its own plate

props.json holds the rooms' numbers. `cell` is the room's pixel, in plate pixels,
measured by `props.py measure`, and `midY` where a typical guest sits, so one baked
pixel lands on one painted pixel there. Nearer furniture draws a little coarser, as
everything on a floor plane does.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
RUN = os.path.join(ROOT, 'art_runs', 'rooms', 'crowd-props')
MASTERS = os.path.join(RUN, 'masters')
OUT = os.path.join(ROOT, 'assets', 'art', 'props')
GUTTER = 2


def spec():
    with open(os.path.join(HERE, 'props.json'), encoding='utf8') as f:
        return json.load(f)


def trim(im):
    alpha = np.array(im)[:, :, 3] >= 128
    ys, xs = np.where(alpha)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def cmd_masters():
    os.makedirs(MASTERS, exist_ok=True)
    s = spec()
    for name, source in s['masters'].items():
        im = Image.open(os.path.join(ROOT, source['from'])).convert('RGBA')
        if 'crop' in source:
            x, y, w, h = source['crop']
            im = im.crop((x, y, x + w, y + h))
        trim(im).save(os.path.join(MASTERS, f'{name}.png'))
        print(name, trim(im).size)


def adult_plate_pixels(room, y):
    floor = room['floor']
    return (
        floor['referenceHeight']
        * (y - floor['horizonY'])
        / (floor['referenceFootY'] - floor['horizonY'])
        * room['plateHeight']
    )


def bake_prop(master, height_px, room):
    """Area-average to the room's grid, hard alpha, the room's light, few colours."""
    w, h = master.size
    width_px = max(1, round(w * height_px / h))
    premultiplied = np.array(master).astype(float)
    premultiplied[:, :, :3] *= premultiplied[:, :, 3:] / 255
    small = np.stack(
        [
            np.array(
                Image.fromarray(premultiplied[:, :, c]).resize(
                    (width_px, height_px), Image.BOX
                )
            )
            for c in range(4)
        ],
        axis=2,
    )
    alpha = small[:, :, 3]
    rgb = small[:, :, :3] / np.maximum(alpha[:, :, None] / 255, 1e-3)

    # The room's key: a gain on the whole prop, and its lamps from above.
    light = room['light']
    gain = np.array(light['gain'], dtype=float)
    top = np.array(light['top'], dtype=float)
    ramp = np.linspace(1, 0, height_px)[:, None, None] ** 2
    lit = rgb * (gain + (top - gain) * ramp)
    lit = np.clip(lit, 0, 255)

    # Quantise on the opaque pixels only, so the edge colour can't leak into them.
    opaque = alpha >= 128
    out = np.zeros((height_px, width_px, 4), dtype=np.uint8)
    pal = Image.fromarray(lit.astype(np.uint8)).quantize(
        colors=light['colours'], method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    )
    out[:, :, :3] = np.array(pal.convert('RGB'))
    out[:, :, 3] = opaque * 255
    out[~opaque] = 0
    return Image.fromarray(out)


def lean(master, amount):
    """A drink dancing: its foot stays put and its top leans, by `amount` of its width."""
    a = np.array(master)
    h, w = a.shape[:2]
    reach = int(abs(amount) * w) + 2
    out = np.zeros((h, w + 2 * reach, 4), dtype=np.uint8)
    for y in range(h):
        out[y, reach + round(amount * w * ((h - 1 - y) / (h - 1)) ** 1.5):][:w] = a[y]
    return Image.fromarray(out)


def bake_room(room_id, s):
    room = s['rooms'][room_id]
    adult_at_mid = adult_plate_pixels(room, room['midY'])
    native_adult = adult_at_mid / room['cell']
    cells = {}
    for frame, info in s['frames'].items():
        master = Image.open(os.path.join(MASTERS, f"{info['master']}.png")).convert('RGBA')
        if info.get('flip'):
            master = master.transpose(Image.FLIP_LEFT_RIGHT)
        if info.get('lean'):
            master = lean(master, info['lean'])
        height = max(4, round(native_adult * info['heightInAdults']))
        lit_room = room
        if info.get('lift'):  # small and meant to read: brighter than the furniture around it
            lit_room = {**room, 'light': {**room['light'], 'gain': [g * info['lift'] for g in room['light']['gain']]}}
        cells[frame] = bake_prop(master, height, lit_room)
    width = sum(c.width + GUTTER for c in cells.values()) - GUTTER
    height = max(c.height for c in cells.values())
    atlas = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    frames = {}
    x = 0
    for frame, cell in cells.items():
        y = height - cell.height
        atlas.paste(cell, (x, y))
        frames[frame] = {
            'rect': [x, y, cell.width, cell.height],
            'anchor': [cell.width / 2, cell.height],
            'pixelsPerUnit': 8.0,
        }
        x += cell.width + GUTTER
    return atlas, frames


def cmd_bake():
    s = spec()
    os.makedirs(OUT, exist_ok=True)
    sets = {}
    for room_id in s['rooms']:
        atlas, frames = bake_room(room_id, s)
        atlas.save(os.path.join(OUT, f'{room_id}.png'), optimize=True)
        sets[room_id] = {
            'image': f'{room_id}.png',
            'imageWidth': atlas.width,
            'imageHeight': atlas.height,
            'frames': frames,
        }
        print(room_id, atlas.size)
    with open(os.path.join(OUT, 'manifest.json'), 'w', encoding='utf8') as f:
        json.dump({'version': 1, 'sets': sets}, f, indent=1)
        f.write('\n')


def cmd_measure():
    """The room's pixel: the commonest run of one colour along lit rows of the plate."""
    s = spec()
    for room_id, room in s['rooms'].items():
        a = np.array(Image.open(os.path.join(ROOT, room['plate'])).convert('RGB')).astype(int)
        h, w, _ = a.shape
        region = a[h // 3: 2 * h // 3, w // 6: 5 * w // 6]
        runs = {}
        for row in region[::7]:
            change = np.abs(np.diff(row, axis=0)).sum(axis=1) > 30
            edges = np.where(change)[0]
            for run in np.diff(edges):
                runs[int(run)] = runs.get(int(run), 0) + 1
        top = sorted(runs.items(), key=lambda kv: -kv[1])[:6]
        print(room_id, top)


def cmd_sheet(out):
    s = spec()
    rows = []
    manifest = json.load(open(os.path.join(OUT, 'manifest.json'), encoding='utf8'))
    for room_id, room in s['rooms'].items():
        plate = Image.open(os.path.join(ROOT, room['plate'])).convert('RGBA')
        atlas = Image.open(os.path.join(OUT, f'{room_id}.png')).convert('RGBA')
        adult = adult_plate_pixels(room, room['midY'])
        crop = plate.crop((100, int(room['midY'] * 1536) - 300, 924, int(room['midY'] * 1536) + 40))
        x = 20
        for frame, geo in manifest['sets'][room_id]['frames'].items():
            rx, ry, w, h = geo['rect']
            cell = atlas.crop((rx, ry, rx + w, ry + h))
            info = s['frames'][frame]
            th = round(adult * info['heightInAdults'])
            tw = round(w * th / h)
            cell = cell.resize((tw, th), Image.NEAREST)
            crop.alpha_composite(cell, (x, 310 - th))
            x += tw + 20
        rows.append(crop.convert('RGB'))
    sheet = Image.new('RGB', (rows[0].width, sum(r.height for r in rows)))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    sheet.save(out)
    print(out)


if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else ''
    if command == 'masters':
        cmd_masters()
    elif command == 'bake':
        cmd_bake()
    elif command == 'measure':
        cmd_measure()
    elif command == 'sheet':
        cmd_sheet(sys.argv[2])
    else:
        sys.exit(__doc__)
