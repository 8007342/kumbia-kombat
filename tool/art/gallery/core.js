/* Pure gallery logic: timing, scaling, joins and the URL hash. No DOM, so it can be
   checked under node. Loaded before gallery.js and exposed as GalleryCore. */
(function (global) {
  'use strict';

  // Portrait phones the game is reviewed on. The game fills the screen, so its true
  // size depends on the screen: this is an assumption, chosen in the toolbar.
  const DEVICES = [
    { id: 'phone390', label: 'Phone 390×844', w: 390, h: 844 },
    { id: 'phone412', label: 'Phone 412×915', w: 412, h: 915 },
    { id: 'phone360', label: 'Phone 360×800', w: 360, h: 800 },
    { id: 'tablet768', label: 'Tablet 768×1024', w: 768, h: 1024 },
  ];

  const ZOOMS = [
    { id: 'fit', label: 'Fit' },
    { id: 'game', label: 'Game size', kind: 'game', m: 1 },
    { id: 'game2', label: 'Game ×2', kind: 'game', m: 2 },
    { id: 'game4', label: 'Game ×4', kind: 'game', m: 4 },
    { id: 'n1', label: 'Native ×1', kind: 'native', n: 1 },
    { id: 'n2', label: 'Native ×2', kind: 'native', n: 2 },
    { id: 'n3', label: 'Native ×3', kind: 'native', n: 3 },
    { id: 'n4', label: 'Native ×4', kind: 'native', n: 4 },
    { id: 'n6', label: 'Native ×6', kind: 'native', n: 6 },
    { id: 'n8', label: 'Native ×8', kind: 'native', n: 8 },
  ];

  function zoomOf(id) {
    return ZOOMS.find((z) => z.id === id) || ZOOMS[0];
  }

  function deviceOf(id) {
    return DEVICES.find((d) => d.id === id) || DEVICES[0];
  }

  function clipDuration(clip) {
    return clip.drawings.reduce((sum, d) => sum + d.beats, 0);
  }

  function sequenceDuration(seq) {
    return seq.reduce((sum, c) => sum + clipDuration(c), 0);
  }

  /* Which drawing shows at this beat of a looping sequence of clips. */
  function sample(seq, beat) {
    const total = sequenceDuration(seq);
    if (!(total > 0)) return null;
    const t = ((beat % total) + total) % total;
    let start = 0;
    for (let i = 0; i < seq.length; i++) {
      const clip = seq[i];
      let at = start;
      for (let j = 0; j < clip.drawings.length; j++) {
        const end = at + clip.drawings[j].beats;
        if (t < end - 1e-9) {
          return { clipIndex: i, clip, drawingIndex: j, drawing: clip.drawings[j],
            beatInClip: t - start, beatInSequence: t, total };
        }
        at = end;
      }
      start = at;
    }
    // Rounding at the very end of the loop: wrap to the first drawing.
    return { clipIndex: 0, clip: seq[0], drawingIndex: 0, drawing: seq[0].drawings[0],
      beatInClip: 0, beatInSequence: 0, total };
  }

  /* The drawing shown just before this one in a looping sequence, for onion skin. */
  function previousDrawing(seq, s) {
    if (s.drawingIndex > 0) return s.clip.drawings[s.drawingIndex - 1];
    const clip = seq[(s.clipIndex - 1 + seq.length) % seq.length];
    return clip.drawings[clip.drawings.length - 1];
  }

  /* Start beat of every drawing in the sequence. */
  function boundaries(seq) {
    const out = [];
    let at = 0;
    for (const clip of seq) {
      for (const d of clip.drawings) {
        out.push(at);
        at += d.beats;
      }
    }
    return out;
  }

  /* The beat of the next (dir 1) or previous (dir -1) drawing, wrapping round. */
  function stepBeat(seq, beat, dir) {
    const marks = boundaries(seq);
    const total = sequenceDuration(seq);
    if (!marks.length || !(total > 0)) return beat;
    const t = ((beat % total) + total) % total;
    let index = 0;
    for (let i = 0; i < marks.length; i++) {
      if (marks[i] <= t + 1e-6) index = i;
    }
    return marks[(index + dir + marks.length) % marks.length];
  }

  /* Where each clip after the first begins, and what meets at that join. Offsets are
     native pixels from the planted foot, so a pop shows as a number as well as by eye. */
  function joins(seq, set) {
    const out = [];
    let at = 0;
    for (let i = 0; i < seq.length; i++) {
      const next = seq[(i + 1) % seq.length];
      at += clipDuration(seq[i]);
      const a = seq[i].drawings[seq[i].drawings.length - 1];
      const b = next.drawings[0];
      out.push({ beat: at % sequenceDuration(seq), from: seq[i].id, to: next.id,
        fromPose: a.poseId, toPose: b.poseId, delta: frameDelta(a, b, set) });
    }
    return out;
  }

  function frameDelta(a, b, set) {
    if (a.missing || b.missing) return null;
    const div = set.nativeDivisor || 1;
    const edges = (d) => ({ left: d.anchor[0], right: d.rect[2] - d.anchor[0],
      top: d.anchor[1], bottom: d.rect[3] - d.anchor[1] });
    const ea = edges(a);
    const eb = edges(b);
    const round = (v) => Math.round((v / div) * 10) / 10;
    return { left: round(eb.left - ea.left), right: round(eb.right - ea.right),
      top: round(eb.top - ea.top), bottom: round(eb.bottom - ea.bottom) };
  }

  /* Largest reach from the anchor across drawings: placing by this keeps every
     drawing on canvas with the ground point fixed. */
  function extents(clips) {
    const e = { left: 0, right: 0, top: 0, bottom: 0, any: false };
    for (const clip of clips) {
      for (const d of clip.drawings) {
        if (d.missing) continue;
        e.any = true;
        e.left = Math.max(e.left, d.anchor[0]);
        e.right = Math.max(e.right, d.rect[2] - d.anchor[0]);
        e.top = Math.max(e.top, d.anchor[1]);
        e.bottom = Math.max(e.bottom, d.rect[3] - d.anchor[1]);
      }
    }
    return e;
  }

  /* PartyViewport: a 180-unit-wide world, with the room painting covering the screen. */
  function viewport(game, device, bgWidth, bgHeight) {
    const pxPerUnit = device.w / game.logicalWidth;
    const logicalHeight = device.h / pxPerUnit;
    const sourceScale = Math.max(game.logicalWidth / bgWidth, logicalHeight / bgHeight);
    const width = bgWidth * sourceScale;
    const height = bgHeight * sourceScale;
    return { pxPerUnit, logicalWidth: game.logicalWidth, logicalHeight, sourceScale, bgHeight,
      rect: { left: (game.logicalWidth - width) / 2, top: (logicalHeight - height) / 2, width, height } };
  }

  /* PartyFloorPlane.standingHeightAt, in world units. Null off the visible floor. */
  function adultUnits(room, vp, footY, stature) {
    if (!(footY > room.horizonY) || footY > 1) return null;
    const scale = (footY - room.horizonY) / (room.referenceFootY - room.horizonY);
    return room.referenceHeight * scale * stature * vp.bgHeight * vp.sourceScale;
  }

  /* CSS pixels per image pixel in the running game: the whole atlas scales by one
     reference frame's height, so all its poses share one stature. */
  function gameScale(set, room, vp, footY, stature) {
    if (!set.gameReference) return null;
    const units = adultUnits(room, vp, footY, stature);
    if (units === null) return null;
    return (units * vp.pxPerUnit) / set.gameReference.heightPx;
  }

  /* Native ×N: N screen pixels per native pixel. Rig renders hold several image
     pixels per native pixel, and that is what nativeDivisor records. */
  function nativeScale(set, n) {
    return n / (set.nativeDivisor || 1);
  }

  /* Largest scale at which extents fit; whole multiples of native when it can be. */
  function fitScale(set, e, width, height) {
    const w = e.left + e.right;
    const h = e.top + e.bottom;
    if (!(w > 0) || !(h > 0)) return nativeScale(set, 1);
    const raw = Math.min(width / w, height / h) * 0.94;
    const div = set.nativeDivisor || 1;
    const multiple = raw * div;
    return multiple >= 1 ? Math.floor(multiple) / div : raw;
  }

  function defaultStature(set, game) {
    if (game && game.available && (set.character === 'macron' || set.character === 'hero')) return game.heroStature;
    return 1;
  }

  /* The floor mark a set stands on: the hero's is nearer the camera than a challenger's. */
  function defaultFootY(set, game, room) {
    return defaultStature(set, game) !== 1 ? room.heroFootY : room.challengerFootY;
  }

  function defaultRoom(set, game) {
    if (!game || !game.available) return null;
    return game.rooms[set.room] ? set.room : Object.keys(game.rooms)[0];
  }

  function spreadX(i, n) {
    return Math.round(Math.min(0.92, Math.max(0.08, 0.5 + (i - (n - 1) / 2) * 0.17)) * 100) / 100;
  }

  /* --- URL hash: the whole selection, so a view can be shared or reloaded. --- */

  function encodeSlots(slots) {
    return slots.map((s) => [s.set, s.clip, s.x, s.y, s.st].map(encodeURIComponent).join('|')).join(';');
  }

  function decodeSlots(text) {
    if (!text) return [];
    const number = (v, fallback) => (Number.isFinite(parseFloat(v)) ? parseFloat(v) : fallback);
    const decode = (v) => {
      try { return decodeURIComponent(v); } catch (e) { return ''; }
    };
    return text.split(';').map((part) => {
      const f = part.split('|').map(decode);
      return { set: f[0], clip: f[1] || '', x: number(f[2], 0.5), y: number(f[3], 0.53), st: number(f[4], 1) };
    }).filter((s) => s.set);
  }

  function encodeHash(state) {
    const p = new URLSearchParams();
    p.set('v', state.view);
    p.set('bpm', String(state.bpm));
    p.set('zoom', state.zoom);
    p.set('dev', state.device);
    if (state.set) p.set('set', state.set);
    if (state.clip) p.set('clip', state.clip);
    if (state.queue && state.queue.length) p.set('q', state.queue.join(','));
    if (state.slots && state.slots.length) p.set('slots', encodeSlots(state.slots));
    if (state.bg) p.set('bg', state.bg);
    if (state.mode) p.set('mode', state.mode);
    if (state.compareA) p.set('ca', state.compareA);
    if (state.compareB) p.set('cb', state.compareB);
    if (state.compareClip) p.set('cc', state.compareClip);
    if (state.guides) p.set('g', '1');
    if (state.onion) p.set('o', '1');
    if (!state.playing) p.set('beat', String(Math.round(state.beat * 1000) / 1000));
    return p.toString();
  }

  function decodeHash(text) {
    const p = new URLSearchParams(String(text || '').replace(/^#/, ''));
    const out = {};
    const take = (key, name) => { if (p.has(key)) out[name] = p.get(key); };
    take('v', 'view');
    take('zoom', 'zoom');
    take('dev', 'device');
    take('set', 'set');
    take('clip', 'clip');
    take('bg', 'bg');
    take('mode', 'mode');
    take('ca', 'compareA');
    take('cb', 'compareB');
    take('cc', 'compareClip');
    if (p.has('bpm')) {
      const bpm = parseFloat(p.get('bpm'));
      if (bpm > 0) out.bpm = bpm;
    }
    if (p.has('q')) out.queue = p.get('q').split(',').filter(Boolean);
    if (p.has('slots')) out.slots = decodeSlots(p.get('slots'));
    if (p.has('g')) out.guides = true;
    if (p.has('o')) out.onion = true;
    if (p.has('beat')) {
      const beat = parseFloat(p.get('beat'));
      if (Number.isFinite(beat)) {
        out.beat = beat;
        out.playing = false;
      }
    }
    return out;
  }

  global.GalleryCore = { DEVICES, ZOOMS, zoomOf, deviceOf, clipDuration, sequenceDuration, sample, previousDrawing,
    boundaries, stepBeat, joins, frameDelta, extents, viewport, adultUnits, gameScale, nativeScale, fitScale,
    defaultStature, defaultFootY, defaultRoom, spreadX, encodeHash, decodeHash };
})(typeof globalThis !== 'undefined' ? globalThis : this);
