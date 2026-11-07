#!/usr/bin/env python3
"""The band's finish: lock each pick to its player's relaxed.a, pixel-finish it, and make the puppet frames.

register_frames.py scales a frame so its whole figure matches the rig, so a raised bell shrinks the player. Band frames
lock instead to what must not move: the instrument, or a trumpeter's legs. tap.up_a, tap.up_b and swing.d are
drawings with the foot lifted (band_tap.py). PICKS records the choices and why they stand in plan/levels/indoor-band-2026-11-07.md.

Usage, from the worktree root: FOOT='{"bass":[x0,y0,x1,y1,lift],...}' band_finish.py <player>
"""
import json, subprocess, sys, os, shutil
from pathlib import Path
import numpy as np
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parent))
from band_tap import lift_foot
from finish_local import palette_of


def finish(src, palette, scale=3):
    """finish_local.finish, with blue counting triple. Warm skin and brass differ mostly in blue, and with plain
    distance a lit face snapped to the brass ramp, which read as yellow patches on the face."""
    a = np.asarray(Image.open(src).convert("RGBA")).astype(np.int64)
    h, w = a.shape[0] // scale, a.shape[1] // scale
    s = a[np.ix_(np.arange(h) * scale + scale // 2, np.arange(w) * scale + scale // 2)]
    diff = s[:, :, None, :3] - palette[None, None]
    d = ((diff * np.array([1, 1, 3])) ** 2).sum(-1)
    # Skin's shadows still reach brass that way. Brass is yellower, so an orange pixel may not take a brass colour.
    p = palette.astype(float)
    brass = (p[:, 2] < p[:, 0] * 0.35) & (p[:, 0] > 100) & (p[:, 1] > p[:, 0] * 0.6)
    orange = s[..., 1] < s[..., 0] * 0.72
    d[orange[..., None] & brass[None, None]] = np.iinfo(np.int64).max
    # And it may not take a drum's or a marimba bar's red: those are far less green than any skin.
    red = (p[:, 0] > 80) & (p[:, 1] < p[:, 0] * 0.5)
    greener = s[..., 1][..., None] > (p[:, 1] / np.maximum(p[:, 0], 1) + 0.2)[None, None] * s[..., 0][..., None]
    d[greener & red[None, None]] = np.iinfo(np.int64).max
    rgb = palette[d.argmin(-1)]
    alpha = np.where(s[..., 3] >= 128, 255, 0)
    return Image.fromarray(np.dstack([np.where(alpha[..., None] > 0, rgb, 0), alpha]).astype(np.uint8), "RGBA")

# RGB boxes for the part each player's frames are locked to, measured on the matted raw frames.
LOCK = {
 'bass': dict(lo=(170, 90, 0), hi=(255, 160, 70), size='h'),
 'congas': dict(lo=(100, 0, 0), hi=(190, 45, 60), size='h'),
 'marimba': dict(lo=(180, 70, 60), hi=(255, 130, 120), size='w'),
 'trumpet': dict(lo=(10, 10, 15), hi=(60, 60, 70), size='h', legs=True),
}
def measure(rgba, spec):
    a = np.asarray(rgba)
    op = a[..., 3] > 128
    m = op.copy()
    for i in range(3):
        m &= (a[..., i] >= spec['lo'][i]) & (a[..., i] <= spec['hi'][i])
    body = np.where(op.any(axis=1))[0]
    if spec.get('legs'):
        # A trumpeter's legs: from the jacket's hem, the lowest wide row of cream, to the floor.
        cream = op & (a[..., 0] > 200) & (a[..., 1] > 190) & (a[..., 2] > 150)
        rows = np.where(cream.sum(axis=1) >= 30)[0]
        hem = rows[rows < body.max() - 160].max()  # shoes are cream too
        m[:hem + 1] = False
        ys, xs = np.where(m)
        return dict(cx=float(np.median(xs)), w=float(np.percentile(xs, 99) - np.percentile(xs, 1)), h=float(body.max() - hem), floor=int(body.max()), n=int(m.sum()))
    ys, xs = np.where(m)
    return dict(cx=float(np.median(xs)), w=float(np.percentile(xs, 99) - np.percentile(xs, 1)),
                h=float(np.percentile(ys, 99) - np.percentile(ys, 1)), floor=int(body.max()), n=int(m.sum()))
def lock(src, ref, spec, s_extra=1.0):
    """src and ref: RGBA, the same canvas. Returns src scaled and moved to match ref's part, on ref's canvas."""
    a, b = measure(src, spec), measure(ref, spec)
    s = (b['w'] / a['w'] if spec['size'] == 'w' else b['h'] / a['h']) * s_extra
    W, H = src.size
    big = src.resize((round(W * s), round(H * s)), Image.LANCZOS)
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    out.alpha_composite(big, (0, 0)) if False else None
    dx = round(b['cx'] - a['cx'] * s); dy = round(b['floor'] - a['floor'] * s)
    out.paste(big, (dx, dy), big)
    return out, dict(scale=round(s, 3), dx=dx, dy=dy)

K = Path.home() / '.cache/tillandsias-project/kumbia-art'
PICKS = {
 'bass': dict(run='band-bass-v1-20261107d', seeds={p: 989511 for p in ('relaxed.a', 'relaxed.b', 'swing.a', 'swing.b', 'swing.c')}, foot=None, shear={'swing.a': 7, 'swing.c': -7}),
 'congas': dict(run='band-congas-v1-20261107d', seeds={'relaxed.a': 989620, 'relaxed.b': 989620, 'swing.a': ('band-congas-v1-20261107f', 989620), 'swing.c': 989620}, foot=None, shear={}, alias={'swing.b': 'relaxed.a'}),
 'trumpet': dict(run='band-trumpet-v1-20261107d', seeds={p: 989710 for p in ('relaxed.a', 'relaxed.b', 'swing.a', 'swing.b', 'swing.c')}, foot=None, shear={}),
 'marimba': dict(run='band-marimba-v1-20261107e', seeds={p: 989810 for p in ('relaxed.a', 'relaxed.b', 'swing.a', 'swing.b', 'swing.c')}, foot=None, shear={}),
}
FEET = {'bass': [100, 280, 119, 298, 8], 'trumpet': [98, 277, 120, 298, 8], 'marimba': [102, 278, 133, 298, 8], 'congas': [108, 274, 121, 296, 6]}  # native px: x0, y0, x1, y1, lift
FOOT = json.loads(os.environ.get('FOOT') or json.dumps(FEET))
def shear(a, top_shift):
    ys = np.where(a[..., 3].any(axis=1))[0]
    y0, y1 = ys.min(), ys.max()
    out = np.zeros_like(a)
    for y in range(y0, y1 + 1):
        dx = round(top_shift * (y1 - y) / (y1 - y0))
        out[y] = np.roll(a[y], dx, axis=0)
    return out
n = sys.argv[1]; c = PICKS[n]; run = c['run']
fam = f'band-{n}-v1'; pal = palette_of(f'tool/art/palettes/band-{n}.json')
final = Path('art_runs') / run / 'final'; final.mkdir(parents=True, exist_ok=True)
sel = {}
for pose, pick in c['seeds'].items():
    r, seed = pick if isinstance(pick, tuple) else (run, pick)
    subprocess.run([sys.executable, 'tool/art/pipeline/register_frames.py', '--run', r, '--family', fam, '--root', str(K / r), '--shirt', 'EADFC2'], check=True, capture_output=True)
    reg = K / r / 'registered' / pose / f'{seed}.png'
    ref_pick = c['seeds']['relaxed.a']
    ref_run, ref_seed = ref_pick if isinstance(ref_pick, tuple) else (run, ref_pick)
    ref = Image.open(K / ref_run / 'registered' / 'relaxed.a' / f'{ref_seed}.png').convert('RGBA')
    locked, info = lock(Image.open(K / r / 'raw' / pose / f'{seed}.png').convert('RGBA'), ref, LOCK[n])
    lp = K / run / 'locked' / f'{pose}.png'; lp.parent.mkdir(exist_ok=True, parents=True); locked.save(lp)
    print(pose, info, measure(locked, LOCK[n]))
    im = finish(lp, pal)
    a = np.asarray(im)
    if pose in c['shear']:
        a = shear(a, c['shear'][pose])
    Image.fromarray(a, 'RGBA').save(final / f'{pose}.png')
    sel[pose] = {'k': seed, 'accepted': True}
    ys, xs = np.where(a[..., 3] > 0)
    print(pose, seed, 'bbox', xs.min(), ys.min(), xs.max(), ys.max())
for dst, src in c.get('alias', {}).items():
    shutil.copy(final / f'{src}.png', final / f'{dst}.png')
    sel[dst] = {**sel[src], 'puppet': f'same drawing as {src}'}
box = FOOT.get(n)
if box:
    for src, dst in (('relaxed.a', 'tap.up_a'), ('relaxed.b', 'tap.up_b'), ('swing.b', 'swing.d')):
        a = np.asarray(Image.open(final / f'{src}.png').convert('RGBA'))
        Image.fromarray(lift_foot(a, tuple(box[:4]), box[4]), 'RGBA').save(final / f'{dst}.png')
        sel[dst] = {'k': sel[src]['k'], 'accepted': True, 'puppet': f'{src} with the foot lifted'}
json.dump(sel, open(Path('art_runs') / run / 'selection.json', 'w'), indent=1)
