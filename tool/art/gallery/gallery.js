/* Sprite gallery viewer: reads index.json, draws on canvas with nearest-neighbour
   scaling. Each frame is placed by its anchor, as PartySpriteFrame.destination does,
   so feet stay on the ground point whatever the drawing's size. */
(function () {
  'use strict';

  const C = window.GalleryCore;
  const VIEWS = [
    ['browser', 'Characters'],
    ['player', 'Clip player'],
    ['transitions', 'Transitions'],
    ['combos', 'Combinations'],
  ];

  let index = null;
  const defaults = () => ({
    view: 'browser', set: null, clip: null, bpm: 104, zoom: 'fit', device: 'phone390',
    guides: false, onion: false, queue: [], slots: [], bg: null, mode: 'stage',
    compareA: null, compareB: null, compareClip: null, playing: true, beat: 0,
  });
  const S = defaults();
  let drawView = () => {};
  let dirty = true;
  let animated = false;
  let pan = { x: 0, y: 0 };
  let lastTs = null;
  let hashTimer = null;

  /* ---------- small DOM helpers ---------- */

  function el(tag, props, ...children) {
    const node = document.createElement(tag);
    Object.entries(props || {}).forEach(([k, v]) => {
      if (k === 'class') node.className = v;
      else if (k === 'text') node.textContent = v;
      else if (k.startsWith('on')) node.addEventListener(k.slice(2), v);
      else if (v !== false && v !== null && v !== undefined) {
        if (k in node && k !== 'list') node[k] = v;
        else node.setAttribute(k, v);
      }
    });
    children.flat().forEach((c) => { if (c !== null && c !== undefined) node.append(c); });
    return node;
  }

  function field(label, control) {
    return el('label', {}, label, control);
  }

  function select(options, value, onchange) {
    const node = el('select', { onchange: (e) => onchange(e.target.value) });
    options.forEach((o) => {
      if (o.group) {
        const group = el('optgroup');
        group.label = o.group;
        o.options.forEach((x) => group.append(option(x, value)));
        node.append(group);
      } else {
        node.append(option(o, value));
      }
    });
    return node;
  }

  function option(o, value) {
    const node = el('option', { value: o.value, text: o.label });
    if (o.value === value) node.selected = true;
    return node;
  }

  function notice(text, warn) {
    return el('p', { class: warn ? 'notice warn' : 'notice', text });
  }

  /* ---------- data lookups ---------- */

  const setById = (id) => (index ? index.sets.find((s) => s.id === id) : null) || null;
  const clipIn = (set, id) => (set ? set.clips.find((c) => c.id === id) : null) || null;
  const playable = () => index.sets.filter((s) => s.counts.present > 0);
  // Open on a dance character, not whichever atlas happens to be listed first.
  const dancers = () => {
    const withMotion = playable().filter((s) => s.motionSet);
    return withMotion.length ? withMotion : playable();
  };
  const firstPlayableSet = () => dancers()[0] || index.sets[0] || null;
  const firstClip = (set) => (set ? set.clips.find((c) => c.drawings.some((d) => !d.missing)) || set.clips[0] : null) || null;
  const backgroundById = (id) => index.backgrounds.find((b) => b.id === id) || null;
  const game = () => (index.game && index.game.available ? index.game : null);

  function setLabel(s) {
    const run = s.runId ? ` · ${s.runId}` : '';
    const image = s.atlasImage ? ` · ${s.atlasImage}` : '';
    return `${s.status}${run}${image} · ${s.counts.present}/${s.counts.expected}`;
  }

  function setOptions() {
    const groups = new Map();
    index.sets.forEach((s) => {
      if (!groups.has(s.character)) groups.set(s.character, []);
      groups.get(s.character).push({ value: s.id, label: setLabel(s) });
    });
    return [...groups].map(([group, options]) => ({ group, options }));
  }

  function clipLabel(c) {
    const missing = c.drawings.filter((d) => d.missing).length;
    const part = missing ? `, ${missing} missing` : '';
    const assumed = c.timing.source === 'assumed' ? ', assumed timing' : '';
    return `${c.id} (${c.drawings.length} dr, ${c.durationBeats} b${part}${assumed})`;
  }

  const clipOptions = (set) => (set ? set.clips.map((c) => ({ value: c.id, label: clipLabel(c) })) : []);

  /* ---------- images and sprite drawing ---------- */

  const images = new Map();

  function image(url) {
    let entry = images.get(url);
    if (!entry) {
      const img = new Image();
      entry = { img, ok: false, failed: false };
      img.onload = () => { entry.ok = true; dirty = true; };
      img.onerror = () => { entry.failed = true; dirty = true; };
      img.src = url;
      images.set(url, entry);
    }
    return entry;
  }

  function prepare(canvas) {
    const dpr = window.devicePixelRatio || 1;
    const w = canvas.clientWidth || 300;
    const h = canvas.clientHeight || 150;
    if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
    }
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.imageSmoothingEnabled = false;
    ctx.clearRect(0, 0, w, h);
    return { ctx, w, h };
  }

  function drawSprite(ctx, frame, gx, gy, scale, alpha) {
    const entry = image(frame.img);
    if (!entry.ok) return;
    const [rx, ry, rw, rh] = frame.rect;
    ctx.save();
    ctx.globalAlpha = alpha === undefined ? 1 : alpha;
    ctx.translate(gx, gy);
    if (frame.mirror) ctx.scale(-1, 1);
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(entry.img, rx, ry, rw, rh, -frame.anchor[0] * scale, -frame.anchor[1] * scale, rw * scale, rh * scale);
    ctx.restore();
  }

  /* A drawing the set lacks is shown as a gap, never substituted. */
  function drawMissing(ctx, drawing, gx, gy, height) {
    const h = Math.max(height, 30);
    const w = h * 0.5;
    ctx.save();
    ctx.strokeStyle = '#e0675a';
    ctx.fillStyle = '#e0675a';
    ctx.setLineDash([5, 4]);
    ctx.strokeRect(gx - w / 2, gy - h, w, h);
    ctx.setLineDash([]);
    ctx.beginPath();
    ctx.moveTo(gx - w / 2, gy - h);
    ctx.lineTo(gx + w / 2, gy);
    ctx.stroke();
    ctx.font = '11px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('MISSING', gx, gy - h - 16);
    ctx.fillText(drawing.poseId, gx, gy - h - 4);
    ctx.restore();
  }

  function drawDrawing(ctx, drawing, gx, gy, scale, fallbackHeight) {
    if (drawing.missing) drawMissing(ctx, drawing, gx, gy, fallbackHeight);
    else drawSprite(ctx, drawing, gx, gy, scale);
  }

  function drawGuides(ctx, w, gx, gy) {
    ctx.save();
    ctx.strokeStyle = 'rgba(242,184,75,.7)';
    ctx.beginPath();
    ctx.moveTo(0, gy + 0.5);
    ctx.lineTo(w, gy + 0.5);
    ctx.moveTo(gx + 0.5, gy - 8);
    ctx.lineTo(gx + 0.5, gy + 8);
    ctx.stroke();
    ctx.restore();
  }

  /* ---------- zoom ---------- */

  /* Sprite scale for a set placed alone on a canvas, with what the reader should
     know about it. Falls back to Fit if this set has no way to know game size. */
  function soloScale(set, e, w, h) {
    const zoom = C.zoomOf(S.zoom);
    if (zoom.kind === 'native') {
      return { scale: C.nativeScale(set, zoom.n), note: `${zoom.n} screen px per native px; ${set.nativeNote}` };
    }
    if (zoom.kind === 'game') {
      const g = game();
      const roomId = C.defaultRoom(set, g);
      if (g && set.gameReference) {
        const room = g.rooms[roomId];
        const bg = index.backgrounds.find((b) => b.room === roomId);
        const vp = C.viewport(g, C.deviceOf(S.device), bg ? bg.width : 1024, bg ? bg.height : 1536);
        const scale = C.gameScale(set, room, vp, C.defaultFootY(set, g, room), C.defaultStature(set, g));
        if (scale) {
          const ref = set.gameReference;
          return {
            scale: scale * zoom.m,
            note: `${(scale * zoom.m).toFixed(2)} CSS px per image px: ${roomId} floor mark on ${C.deviceOf(S.device).label}; `
              + `${ref.note}, ${ref.heightPx}px${ref.approx ? ' (approximate)' : ''}`,
          };
        }
      }
      return { scale: C.fitScale(set, e, w, h), note: 'Game size unavailable for this set, so showing Fit', warn: true };
    }
    const scale = C.fitScale(set, e, w, h);
    return { scale, note: `Fit: ${(scale * (set.nativeDivisor || 1)).toFixed(2)} screen px per native px` };
  }

  /* Ground point keeping the widest and tallest drawings on the canvas. */
  function soloGround(e, scale, w, h) {
    const contentH = (e.top + e.bottom) * scale;
    const gx = w / 2 + ((e.left - e.right) * scale) / 2;
    const gy = contentH <= h ? (h + contentH) / 2 - e.bottom * scale : h - 12 - e.bottom * scale;
    return { gx, gy };
  }

  /* ---------- shared controls ---------- */

  function zoomControl() {
    const options = C.ZOOMS.map((z) => ({ value: z.id, label: z.label }));
    return field('Zoom', select(options, S.zoom, (v) => { S.zoom = v; pan = { x: 0, y: 0 }; changed(); }));
  }

  function deviceControl() {
    const options = C.DEVICES.map((d) => ({ value: d.id, label: d.label }));
    return field('Game size screen', select(options, S.device, (v) => { S.device = v; changed(); }));
  }

  function bpmControl() {
    const number = el('input', { type: 'number', min: 10, max: 300, step: 1, value: S.bpm });
    number.addEventListener('input', () => {
      const bpm = parseFloat(number.value);
      if (bpm >= 10 && bpm <= 300) { S.bpm = bpm; changed(); }
    });
    const presets = [{ value: '', label: 'Song tempo…' }];
    index.tempi.forEach((t) => {
      [['baseBpm', 'base'], ['fullBpm', 'full']].forEach(([key, name]) => {
        if (t[key]) presets.push({ value: String(t[key]), label: `${t[key]} · ${t.id} ${name}` });
      });
    });
    const nodes = [field('BPM', number)];
    if (presets.length > 1) {
      nodes.push(field('From a song', select(presets, '', (v) => {
        if (v) { S.bpm = parseFloat(v); number.value = v; changed(); }
      })));
    }
    return nodes;
  }

  function checkbox(label, key) {
    const input = el('input', { type: 'checkbox', checked: S[key] });
    input.addEventListener('change', () => { S[key] = input.checked; changed(); });
    return el('label', { class: 'inline' }, input, label);
  }

  function transport(sequence, stepSize) {
    const play = el('button', { type: 'button', text: S.playing ? 'Pause' : 'Play' });
    play.addEventListener('click', () => {
      S.playing = !S.playing;
      lastTs = null;
      play.textContent = S.playing ? 'Pause' : 'Play';
      changed();
    });
    const pause = () => { S.playing = false; play.textContent = 'Play'; };
    const step = (dir) => {
      pause();
      if (sequence) S.beat = C.stepBeat(sequence(), S.beat, dir);
      else S.beat = Math.max(0, S.beat + dir * stepSize);
      changed();
    };
    const restart = () => { S.beat = 0; changed(); };
    return el('div', { class: 'buttons' }, play,
      el('button', { type: 'button', text: '◀ Step', onclick: () => step(-1) }),
      el('button', { type: 'button', text: 'Step ▶', onclick: () => step(1) }),
      el('button', { type: 'button', class: 'quiet', text: 'Restart', onclick: restart }));
  }

  function setMeta(set) {
    const row = (k, v) => el('div', {}, el('dt', { text: k }), el('dd', { text: v === null || v === undefined || v === '' ? '—' : String(v) }));
    return el('dl', { class: 'meta' },
      row('Character', set.character),
      row('Status', set.status),
      row('Source kind', set.sourceKind),
      row('Run', set.runId),
      row('Atlas image', set.atlasImage),
      row('Drawings', `${set.counts.present} present, ${set.counts.missing} missing, of ${set.counts.expected}`),
      row('Motion set', set.motionSet),
      row('Anchors', set.anchorSource),
      row('Native grid', set.nativeNote),
      row('Source', set.sourcePath));
  }

  function warningsOf(set) {
    if (!set.warnings.length) return null;
    const box = el('div', { class: 'notice warn' });
    const shown = set.warnings.slice(0, 8);
    box.append(el('ul', {}, shown.map((w) => el('li', { text: w }))));
    if (set.warnings.length > shown.length) box.append(`…and ${set.warnings.length - shown.length} more`);
    return box;
  }

  /* ---------- Character browser ---------- */

  function browserView(root) {
    const set = setById(S.set);
    root.append(el('div', { class: 'controls' },
      field('Set', select(setOptions(), S.set, (v) => { S.set = v; S.clip = null; S.queue = []; renderView(); }))));
    if (!set) { root.append(notice('No set selected.', true)); return; }
    root.append(setMeta(set));
    const warn = warningsOf(set);
    if (warn) root.append(warn);
    if (!set.clips.length) { root.append(notice('This set has no clips to show.', true)); return; }

    const tiles = [];
    const motionClips = set.clips.filter((c) => c.kind !== 'runtime');
    const extent = C.extents(motionClips);
    set.clips.forEach((clip) => {
      const grid = el('div', { class: 'tiles' });
      clip.drawings.forEach((drawing, i) => {
        const canvas = el('canvas', { 'aria-hidden': 'true' });
        const aliases = drawing.aliases ? drawing.aliases.join(', ') : '';
        const button = el('button', {
          type: 'button',
          class: drawing.missing ? 'tile missing' : 'tile',
          title: drawing.missing ? `${drawing.poseId}: ${drawing.reason}` : drawing.poseId,
          onclick: () => {
            S.view = 'player';
            S.clip = clip.id;
            S.playing = false;
            S.beat = C.boundaries([clip])[i];
            renderTabs();
            renderView();
          },
        }, canvas, el('span', { class: 'pose' }, drawing.poseId,
          el('small', { text: [drawing.missing ? 'missing' : '', aliases].filter(Boolean).join(' · ') })));
        grid.append(button);
        tiles.push({ canvas, drawing });
      });
      root.append(el('h2', { text: clip.id }),
        el('p', { class: 'readout', text: `${clip.drawings.length} drawings, ${clip.durationBeats} beats. ${clip.timing.note}` }),
        grid);
    });

    drawView = () => {
      tiles.forEach(({ canvas, drawing }) => {
        const { ctx, w, h } = prepare(canvas);
        // One scale per set, so poses compare; extents exclude nothing but gaps.
        const scale = extent.any ? C.fitScale(set, extent, w, h) : 1;
        const { gx, gy } = soloGround(extent, scale, w, h);
        drawDrawing(ctx, drawing, gx, gy, scale, h * 0.5);
      });
    };
  }

  /* ---------- Clip player and Transitions share one sequence stage ---------- */

  function sequenceStage(root, set, sequence) {
    const canvas = el('canvas', { class: 'stage', 'aria-label': 'Animation stage' });
    const info = el('p', { class: 'readout', 'aria-live': 'off' });
    const scaleNote = el('p', { class: 'readout' });
    const timeline = el('div', { class: 'timeline' });
    const head = el('div', { class: 'head' });
    root.append(canvas, timeline, info, scaleNote);

    let builtFor = null;
    animated = true;
    drawView = () => {
      const seq = sequence();
      const { ctx, w, h } = prepare(canvas);
      if (!seq.length) return;
      const e = C.extents(seq);
      const s = C.sample(seq, S.beat);
      if (!s) { info.textContent = 'This selection has no drawings to play.'; return; }
      const { scale, note } = soloScale(set, e, w, h);
      const { gx, gy } = soloGround(e, scale, w, h);
      if (S.guides) drawGuides(ctx, w, gx, gy);
      if (S.onion) {
        const prev = C.previousDrawing(seq, s);
        if (!prev.missing) drawSprite(ctx, prev, gx, gy, scale, 0.35);
      }
      const fallback = (e.top || 200) * scale;
      drawDrawing(ctx, s.drawing, gx, gy, scale, fallback);

      const key = seq.map((c) => c.id).join();
      if (key !== builtFor) {
        builtFor = key;
        timeline.replaceChildren(...seq.map((c) => el('div', {
          class: 'segment', text: c.id,
          style: `flex: ${C.clipDuration(c)} 1 0`,
        })), head);
      }
      head.style.left = `${(s.beatInSequence / s.total) * 100}%`;

      const accent = s.clip.events.find((ev) => ev.drawing === s.drawing.poseId.split('.')[1]);
      info.replaceChildren(
        el('strong', { text: s.drawing.poseId }),
        ` ${s.clip.id}, drawing ${s.drawingIndex + 1} of ${s.clip.drawings.length}, beat ${s.beatInClip.toFixed(2)} of ${C.clipDuration(s.clip)}`,
        s.drawing.anchorAssumed ? ' · anchor assumed' : '',
        accent ? el('span', { class: 'accent-flag', text: ` · accent at ${accent.beat}` }) : '',
      );
      const timings = [...new Set(seq.map((c) => c.timing.note))].join('; ');
      scaleNote.textContent = `${note}. Timing: ${timings}.`;
    };
  }

  function playerView(root) {
    const set = setById(S.set);
    if (set && !clipIn(set, S.clip)) S.clip = (firstClip(set) || {}).id || null;
    root.append(el('div', { class: 'controls' },
      field('Set', select(setOptions(), S.set, (v) => { S.set = v; changed(); renderView(); })),
      field('Clip', select(clipOptions(set), S.clip, (v) => { S.clip = v; S.beat = 0; changed(); renderView(); })),
      bpmControl(), zoomControl(), deviceControl()));
    if (!set) { root.append(notice('No set selected.', true)); return; }
    const clip = clipIn(set, S.clip);
    if (!clip) { root.append(notice('This set has no clips to play.', true)); return; }
    const sequence = () => { const c = clipIn(set, S.clip); return c ? [c] : []; };
    root.append(el('div', { class: 'buttons' }, checkbox('Ground line', 'guides'), checkbox('Onion skin', 'onion')));
    root.append(transport(sequence));
    sequenceStage(root, set, sequence);
    const warn = warningsOf(set);
    if (warn) root.append(warn);
  }

  function transitionsView(root) {
    const set = setById(S.set);
    root.append(el('div', { class: 'controls' },
      field('Set', select(setOptions(), S.set, (v) => { S.set = v; S.queue = []; renderView(); })),
      bpmControl(), zoomControl(), deviceControl()));
    if (!set) { root.append(notice('No set selected.', true)); return; }
    if (!set.clips.length) { root.append(notice('This set has no clips to play.', true)); return; }

    S.queue = S.queue.filter((id) => clipIn(set, id));
    const first = firstClip(set).id;
    while (S.queue.length < 2) S.queue.push(S.queue[0] && set.clips[1] ? set.clips[1].id : first);

    const list = el('div');
    S.queue.forEach((id, i) => {
      const remove = el('button', {
        type: 'button', class: 'quiet', text: 'Remove', 'aria-label': `Remove clip ${i + 1}`, disabled: S.queue.length <= 2,
        onclick: () => { S.queue.splice(i, 1); S.beat = 0; changed(); renderView(); },
      });
      list.append(el('div', { class: 'queue-row' },
        field(i === 0 ? 'Clip A' : i === 1 ? 'Clip B' : `Then clip ${i + 1}`,
          select(clipOptions(set), id, (v) => { S.queue[i] = v; S.beat = 0; changed(); renderView(); })),
        remove));
    });
    root.append(list);
    root.append(el('div', { class: 'buttons' },
      el('button', { type: 'button', text: 'Add clip to queue', onclick: () => { S.queue.push(S.queue[S.queue.length - 1]); changed(); renderView(); } }),
      checkbox('Ground line', 'guides'), checkbox('Onion skin', 'onion')));

    const sequence = () => S.queue.map((id) => clipIn(set, id)).filter(Boolean);
    root.append(transport(sequence));
    sequenceStage(root, set, sequence);

    const joinList = el('div', { class: 'notice' }, el('strong', { text: 'Joins (change in reach from the planted foot, native px)' }));
    const items = el('ul');
    C.joins(sequence(), set).forEach((j) => {
      const d = j.delta;
      const text = d ? `left ${signed(d.left)}, right ${signed(d.right)}, height ${signed(d.top)}, below ${signed(d.bottom)}` : 'a drawing is missing';
      items.append(el('li', { text: `${j.fromPose} → ${j.toPose}: ${text}` }));
    });
    joinList.append(items);
    root.append(joinList);
    const warn = warningsOf(set);
    if (warn) root.append(warn);
  }

  const signed = (v) => (v > 0 ? `+${v}` : String(v));

  /* ---------- Combinations ---------- */

  function defaultSlot(i, n) {
    const sets = dancers();
    const set = sets[i % Math.max(sets.length, 1)] || index.sets[0];
    const g = game();
    const bg = backgroundById(S.bg);
    const room = set && g ? g.rooms[bg ? bg.room : C.defaultRoom(set, g)] : null;
    return {
      set: set ? set.id : '',
      clip: set && firstClip(set) ? firstClip(set).id : '',
      x: C.spreadX(i, n),
      y: room ? C.defaultFootY(set, g, room) : 0.53,
      st: set ? C.defaultStature(set, g) : 1,
    };
  }

  function slotEditor(slot, i) {
    const set = setById(slot.set);
    const title = el('summary', { text: `Slot ${i + 1}: ${set ? `${set.character} ${set.status}` : 'set is gone'} · ${slot.clip || 'no clip'}` });
    const range = (label, key, min, max, step) => {
      const input = el('input', { type: 'range', min, max, step, value: slot[key] });
      input.addEventListener('input', () => { slot[key] = parseFloat(input.value); changed(); });
      return field(label, input);
    };
    const remove = el('button', {
      type: 'button', class: 'quiet', text: 'Remove slot', disabled: S.slots.length <= 2,
      onclick: () => { S.slots.splice(i, 1); changed(); renderView(); },
    });
    return el('details', { class: 'slot', open: i === 0 }, title, el('div', { class: 'controls' },
      field('Set', select(setOptions(), slot.set, (v) => {
        slot.set = v;
        const next = setById(v);
        if (!clipIn(next, slot.clip)) slot.clip = firstClip(next) ? firstClip(next).id : '';
        slot.st = C.defaultStature(next, game());
        changed();
        renderView();
      })),
      field('Clip', select(clipOptions(set), slot.clip, (v) => { slot.clip = v; changed(); renderView(); })),
      range('Floor across', 'x', 0, 1, 0.01),
      range('Floor depth', 'y', 0.3, 1, 0.005),
      range('Stature', 'st', 0.2, 1.5, 0.05),
      remove));
  }

  function stageScale(set, zoom, room, vp, slot, unitsToPx) {
    if (zoom.kind === 'native') return { scale: C.nativeScale(set, zoom.n) };
    const scale = room && vp ? C.gameScale(set, room, vp, slot.y, slot.st) : null;
    if (scale !== null) return { scale: (scale / vp.pxPerUnit) * unitsToPx };
    return { scale: C.nativeScale(set, 1), fallback: true };
  }

  function drawStage(canvas, slots) {
    const { ctx, w, h } = prepare(canvas);
    const g = game();
    const zoom = C.zoomOf(S.zoom);
    const bg = backgroundById(S.bg);
    const device = C.deviceOf(S.device);
    const firstSet = slots.map((s) => setById(s.set)).find(Boolean);
    const roomId = bg && g && g.rooms[bg.room] ? bg.room : firstSet ? C.defaultRoom(firstSet, g) : null;
    const room = g && roomId ? g.rooms[roomId] : null;
    const notes = [];

    if (!room) {
      // Without the game's numbers there is no floor to project on: an even row at native scale.
      const y = h * 0.85 + pan.y;
      slots.forEach((slot) => {
        const set = setById(slot.set);
        const clip = clipIn(set, slot.clip);
        const s = clip ? C.sample([clip], S.beat) : null;
        if (!s) return;
        const scale = C.nativeScale(set, zoom.kind === 'native' ? zoom.n : 1);
        drawDrawing(ctx, s.drawing, slot.x * w + pan.x, y, scale, 100);
      });
      return ['Game scale is unavailable, so these are drawn at native size without a floor.'];
    }

    const dims = bg || index.backgrounds.find((b) => b.room === roomId) || { width: 1024, height: 1536 };
    const vp = C.viewport(g, device, dims.width, dims.height);
    const markY = room.challengerFootY;
    let k = vp.pxPerUnit;
    if (zoom.kind === 'game') k = vp.pxPerUnit * zoom.m;
    else if (zoom.kind === 'native') {
      const ref = firstSet && firstSet.gameReference;
      const adult = C.adultUnits(room, vp, markY, 1);
      k = ref && adult ? (zoom.n * (ref.heightPx / (firstSet.nativeDivisor || 1))) / adult : vp.pxPerUnit;
    } else k = Math.min(h / vp.logicalHeight, w / vp.logicalWidth);

    const project = (x, y) => ({ x: vp.rect.left + x * vp.rect.width, y: vp.rect.top + y * vp.rect.height });
    const mark = project(0.5, markY);
    const ox = w / 2 - (zoom.id === 'fit' ? vp.logicalWidth / 2 : mark.x) * k + pan.x;
    const oy = (zoom.id === 'fit' ? (h - vp.logicalHeight * k) / 2 : h * 0.72 - mark.y * k) + pan.y;

    // The room is clipped to the device, as the game clips to its screen.
    ctx.save();
    ctx.beginPath();
    ctx.rect(ox, oy, vp.logicalWidth * k, vp.logicalHeight * k);
    ctx.clip();
    if (bg) {
      const entry = image(bg.img);
      if (entry.ok) {
        ctx.drawImage(entry.img, ox + vp.rect.left * k, oy + vp.rect.top * k, vp.rect.width * k, vp.rect.height * k);
      }
    } else {
      ctx.fillStyle = '#23272f';
      ctx.fillRect(ox, oy, vp.logicalWidth * k, vp.logicalHeight * k);
    }
    ctx.restore();
    ctx.strokeStyle = 'rgba(255,255,255,.25)';
    ctx.strokeRect(ox + 0.5, oy + 0.5, vp.logicalWidth * k, vp.logicalHeight * k);

    // Painter's order by floor depth, as compareEnsembleDepth does.
    const ordered = slots.slice().sort((a, b) => a.y - b.y);
    ordered.forEach((slot) => {
      const set = setById(slot.set);
      const clip = clipIn(set, slot.clip);
      const n = slots.indexOf(slot) + 1;
      if (!set || !clip) { notes.push(`Slot ${n}: its set or clip is not in this data`); return; }
      const s = C.sample([clip], S.beat);
      if (!s) { notes.push(`Slot ${n}: nothing to play`); return; }
      const p = project(slot.x, slot.y);
      const gx = ox + p.x * k;
      const gy = oy + p.y * k;
      const { scale, fallback } = stageScale(set, zoom, room, vp, slot, k);
      if (fallback) notes.push(`Slot ${n}: no game reference, drawn at native ×1`);
      const adult = C.adultUnits(room, vp, slot.y, slot.st);
      const height = (adult || 40) * k;
      ctx.save();
      ctx.fillStyle = 'rgba(3,12,20,.33)'; // GardenScene._shadow
      ctx.beginPath();
      ctx.ellipse(gx, gy, height * 0.17, height * 0.0325, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
      if (S.guides) drawGuides(ctx, w, gx, gy);
      drawDrawing(ctx, s.drawing, gx, gy, scale, height);
      if (s.drawing.missing) notes.push(`Slot ${n}: ${s.drawing.poseId} missing`);
      if (s.drawing.anchorAssumed) notes.push(`Slot ${n}: anchor assumed`);
      if (set.gameReference && set.gameReference.approx && zoom.kind !== 'native') notes.push(`Slot ${n}: game size approximate (${set.gameReference.note})`);
    });
    const label = zoom.kind === 'native'
      ? `Native ×${zoom.n}: each sprite at ${zoom.n} screen px per native px; room scaled to the first slot`
      : zoom.kind === 'game'
        ? `Game size${zoom.m > 1 ? ` ×${zoom.m}` : ''}: ${device.label}, ${vp.pxPerUnit.toFixed(2)} CSS px per world unit, floor plane of ${roomId}`
        : `Fit: the whole ${device.label} screen, in proportion`;
    notes.unshift(label);
    return notes;
  }

  function combosView(root) {
    root.append(el('div', { class: 'buttons' },
      modeButton('stage', 'Stage'), modeButton('compare', 'Compare two sets')));
    if (S.mode === 'compare') compareView(root);
    else stageView(root);
  }

  function modeButton(mode, label) {
    return el('button', {
      type: 'button', text: label, 'aria-pressed': String(S.mode === mode),
      onclick: () => { S.mode = mode; changed(); renderView(); },
    });
  }

  function stageView(root) {
    if (S.bg === null) S.bg = index.backgrounds.length ? index.backgrounds[0].id : 'none';
    if (S.slots.length < 2) {
      const keep = S.slots.slice();
      S.slots = [0, 1].map((i) => keep[i] || defaultSlot(i, 2));
    }
    const bgOptions = [{ value: 'none', label: 'No background' }]
      .concat(index.backgrounds.map((b) => ({ value: b.id, label: b.id })));
    root.append(el('div', { class: 'controls' },
      field('Room', select(bgOptions, S.bg, (v) => { S.bg = v; pan = { x: 0, y: 0 }; changed(); })),
      bpmControl(), zoomControl(), deviceControl()));
    index.backgroundNotes.forEach((n) => root.append(notice(n)));
    const canvas = el('canvas', { class: 'stage pannable', 'aria-label': 'Combination stage; drag to pan' });
    root.append(canvas);
    enablePan(canvas);
    const info = el('p', { class: 'readout' });
    root.append(info);
    root.append(el('div', { class: 'buttons' }, checkbox('Ground lines', 'guides'),
      el('button', { type: 'button', class: 'quiet', text: 'Recentre', onclick: () => { pan = { x: 0, y: 0 }; dirty = true; } })));
    root.append(transport(null, 0.25));
    S.slots.forEach((slot, i) => root.append(slotEditor(slot, i)));
    root.append(el('div', { class: 'buttons' }, el('button', {
      type: 'button', text: 'Add slot', disabled: S.slots.length >= 6,
      onclick: () => {
        const n = S.slots.length + 1;
        S.slots.push(defaultSlot(S.slots.length, n));
        S.slots.forEach((slot, i) => { slot.x = C.spreadX(i, n); });
        changed();
        renderView();
      },
    })));
    let last = '';
    animated = true;
    drawView = () => {
      const text = drawStage(canvas, S.slots).join(' · ');
      if (text !== last) { last = text; info.textContent = text; }
    };
  }

  function enablePan(canvas) {
    let from = null;
    canvas.addEventListener('pointerdown', (e) => {
      from = { x: e.clientX - pan.x, y: e.clientY - pan.y };
      if (canvas.setPointerCapture) canvas.setPointerCapture(e.pointerId);
    });
    canvas.addEventListener('pointermove', (e) => {
      if (!from) return;
      pan = { x: e.clientX - from.x, y: e.clientY - from.y };
      dirty = true;
    });
    const end = () => { from = null; };
    canvas.addEventListener('pointerup', end);
    canvas.addEventListener('pointercancel', end);
  }

  function compareView(root) {
    // Old against new of one character is what this view is for.
    const sets = dancers();
    if (!setById(S.compareA)) S.compareA = (sets[0] || index.sets[0] || {}).id || null;
    if (!setById(S.compareB)) {
      const first = setById(S.compareA);
      const peer = sets.find((s) => first && s.id !== first.id && s.character === first.character);
      S.compareB = (peer || sets[1] || first || {}).id || null;
    }
    const a = setById(S.compareA);
    const b = setById(S.compareB);
    if (!a || !b) { root.append(notice('No sets to compare.', true)); return; }

    const ids = [...new Set([...a.clips, ...b.clips].map((c) => c.id))];
    const label = (id) => {
      const lacking = [[a, 'A'], [b, 'B']].filter(([s]) => !clipIn(s, id)).map(([, n]) => n);
      return lacking.length ? `${id} (not in ${lacking.join(' or ')})` : id;
    };
    if (!ids.includes(S.compareClip)) {
      S.compareClip = ids.find((id) => clipIn(a, id) && clipIn(b, id)) || ids[0] || null;
    }
    root.append(el('div', { class: 'controls' },
      field('Set A', select(setOptions(), S.compareA, (v) => { S.compareA = v; changed(); renderView(); })),
      field('Set B', select(setOptions(), S.compareB, (v) => { S.compareB = v; changed(); renderView(); })),
      field('Clip', select(ids.map((id) => ({ value: id, label: label(id) })), S.compareClip, (v) => { S.compareClip = v; S.beat = 0; changed(); })),
      bpmControl(), zoomControl(), deviceControl()));
    root.append(el('div', { class: 'buttons' }, checkbox('Ground lines', 'guides')));
    root.append(transport(null, 0.25));

    const panes = [a, b].map((set, i) => {
      const canvas = el('canvas', { class: 'stage', 'aria-label': `Set ${i ? 'B' : 'A'}` });
      const info = el('p', { class: 'readout' });
      return { set, canvas, info, node: el('div', {}, el('p', { class: 'readout' }, el('strong', { text: `${i ? 'B' : 'A'}: ${set.character}` }), ` ${setLabel(set)}`), canvas, info) };
    });
    root.append(el('div', { class: 'compare' }, panes.map((p) => p.node)));

    animated = true;
    drawView = () => {
      panes.forEach(({ set, canvas, info }) => {
        const { ctx, w, h } = prepare(canvas);
        const clip = clipIn(set, S.compareClip);
        if (!clip) {
          drawMissing(ctx, { poseId: S.compareClip || 'clip' }, w / 2, h * 0.8, h * 0.5);
          info.textContent = 'This set has no such clip.';
          return;
        }
        const e = C.extents([clip]);
        const s = C.sample([clip], S.beat);
        if (!s) { info.textContent = 'No drawings to play.'; return; }
        const { scale, note } = soloScale(set, e, w, h);
        const { gx, gy } = soloGround(e, scale, w, h);
        if (S.guides) drawGuides(ctx, w, gx, gy);
        drawDrawing(ctx, s.drawing, gx, gy, scale, (e.top || 200) * scale || h * 0.5);
        info.textContent = `${s.drawing.poseId}${s.drawing.missing ? ' MISSING' : ''}. ${clip.timing.note}. ${note}.`;
      });
    };
  }

  /* ---------- frame ---------- */

  function renderTabs() {
    const tabs = document.getElementById('tabs');
    tabs.replaceChildren(...VIEWS.map(([id, label]) => el('button', {
      type: 'button', text: label, 'aria-current': S.view === id ? 'page' : null,
      onclick: () => { S.view = id; renderTabs(); changed(); renderView(); },
    })));
  }

  function renderView() {
    const main = document.getElementById('main');
    main.replaceChildren();
    drawView = () => {};
    animated = false;
    if (!setById(S.set)) S.set = (firstPlayableSet() || {}).id || null;
    if (!index.sets.length) { main.append(notice('No sets found. Check the sources given to build_gallery.py.', true)); return; }
    ({ browser: browserView, player: playerView, transitions: transitionsView, combos: combosView }[S.view] || browserView)(main);
    index.warnings.forEach((w) => main.append(notice(w, true)));
    main.append(el('p', { class: 'readout', text: `Data built ${index.generatedAt}. ${index.sets.length} sets.` }));
    writeHash();
    dirty = true;
  }

  function changed() {
    dirty = true;
    clearTimeout(hashTimer);
    hashTimer = setTimeout(writeHash, 150);
  }

  function writeHash() {
    const text = C.encodeHash(S);
    // replaceState fires no hashchange, so this cannot loop back into readHash.
    if (location.hash.slice(1) !== text) history.replaceState(null, '', `#${text}`);
  }

  function readHash() {
    // The hash is the whole selection: what it omits goes back to its default, so a
    // link opened in a tab already in use shows what its sender saw.
    Object.assign(S, defaults(), C.decodeHash(location.hash));
    pan = { x: 0, y: 0 };
    if (!C.ZOOMS.some((z) => z.id === S.zoom)) S.zoom = 'fit';
    if (!VIEWS.some(([id]) => id === S.view)) S.view = 'browser';
  }

  function tick(ts) {
    if (S.playing && animated && lastTs !== null) {
      S.beat += ((ts - lastTs) / 60000) * S.bpm;
      dirty = true;
    }
    lastTs = ts;
    if (dirty) {
      dirty = false;
      drawView();
    }
    requestAnimationFrame(tick);
  }

  async function load() {
    const response = await fetch('index.json', { cache: 'no-store' });
    if (!response.ok) throw new Error(`index.json: ${response.status}`);
    index = await response.json();
  }

  async function start() {
    document.getElementById('reload').addEventListener('click', async () => {
      try {
        await load();
        renderTabs();
        renderView();
      } catch (e) {
        document.getElementById('main').prepend(notice(`Could not reload: ${e.message}`, true));
      }
    });
    window.addEventListener('hashchange', () => {
      readHash();
      renderTabs();
      renderView();
    });
    window.addEventListener('resize', () => { dirty = true; });
    try {
      await load();
    } catch (e) {
      document.getElementById('main').replaceChildren(
        notice(`Could not load index.json (${e.message}). Serve this folder over HTTP; a file:// page cannot read it.`, true));
      return;
    }
    readHash();
    renderTabs();
    renderView();
    requestAnimationFrame(tick);
  }

  start();
})();
