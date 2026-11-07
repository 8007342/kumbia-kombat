#!/usr/bin/env node
// Proposes small shifts of chart steps onto the rendered take's accents, inside the fairness
// limits the game enforces (FightChart.fairnessProblems and _validateRich), and prints them.
// It never writes a level file unless --write is given, and then only the `at` and `gap`
// values of the steps it moved. Every proposal still needs a thumb and an ear.
//
//   node tool/music/align_suggest.mjs --level bar            # print proposals
//   node tool/music/align_suggest.mjs --level bar --write    # apply them to levels/bar.json
//   options: --root DIR, --max-shift 0.5, --below 1.0 (only move steps whose notes score under this),
//            --keep 0,3 (pattern indices to leave alone), --good-ms 180 --flourish-ms 400 (judge windows)
import {readFileSync, writeFileSync} from 'node:fs';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {cueProblems, testNotes} from './cue_geometry.mjs';
import {DIV, callPhases, finalChallengesOf, patternIndices, pointScore, salience} from './align_charts.mjs';

const here = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i < 0 ? fallback : args[i + 1];
};
const root = resolve(opt('root', here));
const id = opt('level');
const maxShift = Number(opt('max-shift', 0.5));
const below = Number(opt('below', 1.0));
const keep = new Set((opt('keep', '') || '').split(',').filter(Boolean).map(Number));
const GOOD_MS = Number(opt('good-ms', 180));
const FLOURISH_MS = Number(opt('flourish-ms', 400));
const MIN_SAME_LIMB_BEATS = Number(opt('same-limb-beats', 1.25)); // the doubles plan's floor; cue_geometry.mjs checks the screen itself
const write = args.includes('--write');
const MAX_TRIES = Number(opt('tries', 3000));
const relayout = new Set((opt('relayout', '') || '').split(',').filter(Boolean).map(Number)); // patterns to lay out afresh
// Credit for an off-beat step that stays off the beat. Charts grow by off-beat share through the
// campaign (test/level_registry_test.dart), so later levels can ask for more of it.
const KEEP_OFFBEAT = Number(opt('keep-offbeat', 0.15));
// The most off-beat steps a pattern may move onto a whole beat (default: no limit).
const MAX_TO_BEAT = Number(opt('max-to-beat', 99));
const minGain = Number(opt('min-gain', 0.1)); // per note, below which a pattern is left as written
if (!id) throw new Error('--level is required');

const read = p => JSON.parse(readFileSync(p, 'utf8'));
const manifest = read(resolve(root, 'assets/music/rendered/manifest.json'));
const levelPath = resolve(root, `levels/${id}.json`);
const level = read(levelPath);
const chart = level.chart;
const m = manifest.levels[id];
const limits = {sameSpotMs: 285, thumbHopMs: 330, crossThumbMs: 170, sameLimbMs: 400, phraseEndMs: 100, ...(chart.rich?.limits ?? {})};
const isLeft = limb => limb.startsWith('left');

const takes = {};
for (const [name, take] of Object.entries(m.takes)) {
  takes[name] = {sal: salience(resolve(root, take.files.opus), take.bpm, take.loopStartSeconds, take.bars * 4), ...callPhases(manifest, id, level, name), bpm: take.bpm};
}

// The score of one note at one position, averaged over call and response and every place in
// the loop: what align_charts.mjs reports per note.
function positionScore(t, at) {
  let total = 0, weight = 0;
  for (const {bar, weight: w} of t.phases) {
    for (const half of [0, 1]) {
      const starts = [];
      for (let b = bar * 4 + half * 8; b < t.sal.beats + bar * 4; b += 16) starts.push(b % t.sal.beats);
      for (const s of starts) {
        const n = t.sal.salience.low.length;
        const g = ((Math.round((s + at) * DIV) % n) + n) % n;
        total += (w / starts.length / 2) * Math.min(pointScore(t.sal, g).score, 2);
        weight += w / starts.length / 2;
      }
    }
  }
  return total / weight;
}

const stepsOf = index => {
  const rich = chart.rich?.patterns?.[String(index)];
  if (rich) return rich.map(s => ({...s}));
  const limbs = index === 0 ? chart.limbs : chart.variants[index - 1];
  return chart.offsets.map((at, i) => ({at, limb: limbs[i]}));
};
const notesOf = steps => steps.flatMap((s, step) => {
  const out = [{at: s.at, limb: s.limb, step}];
  if (s.move === 'pair') out.push({at: s.at, limb: s.with, step});
  if (s.move === 'split') out.push({at: s.at + s.gap, limb: s.with, step});
  if (s.move === 'doubleTap') out.push({at: s.at + s.gap, limb: s.limb, step});
  return out;
}).sort((a, b) => a.at - b.at);

// Mirrors FightChart._validateRich and fairnessProblems, plus a same-limb spacing for cues.
// Two presses by different steps, `beats` apart: the rule FightChart.fairnessProblems applies.
function pairOk(a, b, beats, beatMs, sameStep, sameLimbBeats) {
  if (beats === 0) return true;
  const floor = a.limb === b.limb ? (sameStep ? limits.sameSpotMs : limits.sameLimbMs) : isLeft(a.limb) === isLeft(b.limb) ? limits.thumbHopMs : limits.crossThumbMs;
  if (beats * beatMs < floor) return false;
  return !(a.limb === b.limb && !sameStep && beats < sameLimbBeats - 1e-9);
}

// Every pattern as it stands, so a candidate is also checked across the join from one half
// to the next: a call into its own response, and a response into any pattern's call.
const settled = new Map();

function fair(steps, bpms, sameLimbBeats = MIN_SAME_LIMB_BEATS, index = null, joinBeats = sameLimbBeats) {
  let previous = -1;
  for (const s of steps) {
    if (s.at <= previous || s.at < 0) return false;
    previous = s.at + (s.gap ?? 0);
    if (previous >= chart.callBeats) return false;
  }
  const notes = notesOf(steps);
  for (const bpm of bpms) {
    const beatMs = 60000 / bpm;
    for (let i = 0; i < notes.length; i++) for (let j = i + 1; j < notes.length; j++) {
      if (!pairOk(notes[i], notes[j], notes[j].at - notes[i].at, beatMs, notes[i].step === notes[j].step, sameLimbBeats)) return false;
    }
    for (let i = 0; i + 1 < steps.length; i++) {
      if (!steps[i].offer) continue;
      // The offer rides the step's last press, so a double's room starts at its second tap.
      if ((steps[i + 1].at - steps[i].at - (steps[i].gap ?? 0)) * beatMs < 2 * GOOD_MS + FLOURISH_MS + 40) return false;
    }
    if ((chart.callBeats - notes.at(-1).at) * beatMs - GOOD_MS < limits.phraseEndMs) return false;
    const others = [notes, ...[...settled].filter(([k]) => k !== index).map(([, v]) => notesOf(v))];
    for (const other of others) {
      for (const [early, late] of [[notes, other], [other, notes]]) {
        for (const a of early) for (const b of late) {
          const beats = b.at + chart.callBeats - a.at;
          // The game's own rule doesn't reach across a join; the cue-separation test does,
          // for one limb, so that is what is held here.
          if (a.limb === b.limb && beats < joinBeats - 1e-9) return false;
        }
      }
    }
  }
  return true;
}

const tiersOf = new Map();
for (let tier = 0; tier < 5; tier++) for (const index of patternIndices(chart, tier, finalChallengesOf(level))) {
  if (!tiersOf.has(index)) tiersOf.set(index, new Set());
  tiersOf.get(index).add(tier);
}

for (const index of tiersOf.keys()) settled.set(index, stepsOf(index));
for (let k = 0; k <= chart.variants.length; k++) if (!settled.has(k)) settled.set(k, stepsOf(k));
const cuesPassed = cueProblems(testNotes(id, [...settled.keys()].sort((a, b) => a - b).map(k => notesOf(settled.get(k)).map(n => ({at: n.at, limb: n.limb}))))) === null;
if (!cuesPassed) console.log(`${id} fails the on-screen cue checks as written; they are not applied to proposals`);
const proposals = [];
for (const [index, tiers] of [...tiersOf].sort((a, b) => a[0] - b[0])) {
  if (keep.has(index)) continue;
  const takeNames = [...new Set([...tiers].map(t => m.tierTakes[t]))];
  const bpms = takeNames.map(n => takes[n].bpm);
  const score = (steps) => notesOf(steps).reduce((a, n) => a + takeNames.reduce((x, k) => x + positionScore(takes[k], n.at), 0) / takeNames.length, 0);
  const original = stepsOf(index);
  // Cue separation: never closer than the pattern already is, nor than 1.25 beats otherwise.
  const ns = notesOf(original);
  // A fresh layout leans on the ported screen check alone, with the 400 ms rule underneath.
  let closest = relayout.has(index) ? 0.5 : MIN_SAME_LIMB_BEATS;
  for (let i = 0; i < ns.length; i++) for (let j = i + 1; j < ns.length; j++) {
    if (ns[i].limb === ns[j].limb && ns[i].step !== ns[j].step) closest = Math.min(closest, ns[j].at - ns[i].at);
  }
  // The joins between halves count too, as the original charts have them.
  let joinClosest = MIN_SAME_LIMB_BEATS;
  for (const other of [...settled.values()].map(notesOf)) for (const a of ns) for (const b of other) {
    if (a.limb === b.limb) joinClosest = Math.min(joinClosest, b.at + chart.callBeats - a.at, a.at + chart.callBeats - b.at);
  }
  const fairHere = (steps, b) => fair(steps, b, closest, index, joinClosest);
  if (!fairHere(original, bpms)) console.warn(`pattern ${index} already fails a limit here; proposals keep to the limits anyway`);
  const stepScore = s => notesOf([s]).map(n => takeNames.reduce((x, k) => x + positionScore(takes[k], n.at), 0) / takeNames.length);
  const movable = original.map(s => Math.min(...stepScore(s)) < below);
  const options = original.map((s, i) => {
    // A fresh layout keeps the steps (limbs, moves, gaps, offers) and their order, and puts
    // them anywhere on the sixteenth grid; the music decides between eighths and sixteenths.
    if (relayout.has(index)) {
      const out = [];
      for (let at = 0; at < chart.callBeats; at += 0.25) {
        out.push({at, gap: s.gap});
      }
      return out;
    }
    if (!movable[i]) return [{at: s.at, gap: s.gap}];
    const out = [];
    for (let d = -maxShift; d <= maxShift + 1e-9; d += 0.25) {
      // Gaps stay as written: a half-beat double put one billiards cue over its twin on screen.
      const gaps = [s.gap];
      const at = +(s.at + d).toFixed(2);
      // Never to a finer subdivision: a note on an eighth stays on eighths, so a teaching
      // tier doesn't gain sixteenths.
      if (Number.isInteger(s.at * 2) && !Number.isInteger(at * 2)) continue;
      for (const gap of gaps) out.push({at, gap});
    }
    return out;
  });
  // Exhaustive over the movable steps, with a small cost per quarter beat moved so the nearest
  // good spot wins, and a small credit for a foot on a whole beat (feet take the pulse).
  const found = [];
  const current = original.map(s => ({...s}));
  // Step i against the steps before it, by the in-pattern rules, so the search prunes early.
  const partialOk = (steps, i) => {
    const ns = notesOf(steps.slice(0, i + 1));
    const mine = ns.filter(n => n.step === i), before = ns.filter(n => n.step < i);
    if (mine.at(-1).at >= chart.callBeats) return false;
    for (const bpm of bpms) {
      const beatMs = 60000 / bpm;
      for (const b of mine) for (const a of before) if (!pairOk(a, b, b.at - a.at, beatMs, false, closest)) return false;
      if (mine.length === 2 && !pairOk(mine[0], mine[1], mine[1].at - mine[0].at, beatMs, true, closest)) return false;
      if (i > 0 && steps[i - 1].offer && (steps[i].at - steps[i - 1].at - (steps[i - 1].gap ?? 0)) * beatMs < 2 * GOOD_MS + FLOURISH_MS + 40) return false;
    }
    return true;
  };
  const walk = i => {
    if (i === original.length) {
      if (current.filter((s, k) => !Number.isInteger(original[k].at) && Number.isInteger(s.at)).length > MAX_TO_BEAT) return;
      if (!fairHere(current, bpms)) return;
      let v = score(current);
      current.forEach((s, k) => {
        v -= (relayout.has(index) ? 0.03 : 0.12) * Math.abs(s.at - original[k].at) / 0.25 + (s.gap !== original[k].gap ? 0.2 : 0);
        if (s.limb.endsWith('Foot') && Number.isInteger(s.at)) v += 0.05;
        // Keep the syncopation the chart was written with: an off-beat stays off the beat.
        if (!Number.isInteger(original[k].at) && !Number.isInteger(s.at)) v += KEEP_OFFBEAT;
      });
      found.push({v, steps: current.map(s => ({...s}))});
      return;
    }
    for (const o of options[i]) {
      if (i > 0 && o.at <= current[i - 1].at + (current[i - 1].gap ?? 0)) continue;
      current[i] = {...original[i], at: o.at, ...(o.gap === undefined ? {} : {gap: o.gap})};
      if (!partialOk(current, i)) continue;
      walk(i + 1);
    }
    current[i] = {...original[i]};
  };
  walk(0);
  // The best that also passes the on-screen cue checks (test/cue_path_test.dart, ported in
  // cue_geometry.mjs), where the level passed them as written.
  found.sort((a, b) => b.v - a.v);
  if (process.env.ALIGN_DEBUG) console.log(`  pattern ${index}: ${found.length} fair candidates; best ${found[0]?.v.toFixed(2)}`);
  if (process.env.ALIGN_DEBUG) console.log(`  pattern ${index}: ${found.length} fair candidates, original fair: ${fairHere(original, bpms)}, movable ${movable}`);
  const layout = steps => testNotes(id, [...Array(chart.variants.length + 1).keys()].map(k =>
    notesOf(k === index ? steps : settled.get(k) ?? stepsOf(k)).map(n => ({at: n.at, limb: n.limb}))));
  const checkCues = cuesPassed;
  const focus = [0, 8].map(turn => [4 + 16 * index + turn, 4 + 16 * index + turn + 8]);
  let best = null, tried = 0;
  for (const f of found) {
    if (tried++ > MAX_TRIES) break;
    const problem = checkCues && cueProblems(layout(f.steps), {focus});
    if (problem) { if (process.env.ALIGN_DEBUG && tried < 4) console.log(`    cue: ${problem}`); continue; }
    best = f;
    break;
  }
  if (!best) {
    console.log(`pattern ${index}: ${found.length ? 'no fair shift passes the cue checks' : 'no fair layout found'}; left as written`);
    continue;
  }
  const changes = best.steps.map((s, k) => ({k, from: original[k], to: s})).filter(c => c.from.at !== c.to.at || c.from.gap !== c.to.gap);
  const before = score(original) / notesOf(original).length, after = score(best.steps) / notesOf(best.steps).length;
  if (after - before < minGain) {
    console.log(`pattern ${index} (tier ${[...tiers].join(',')}): left as written, ${before.toFixed(2)}${changes.length ? `, best fair shift only reaches ${after.toFixed(2)}` : ''}`);
    continue;
  }
  settled.set(index, best.steps);
  proposals.push({index, tiers: [...tiers], takes: takeNames, before: +before.toFixed(3), after: +after.toFixed(3), changes, steps: best.steps});
  console.log(`pattern ${index} (tier ${[...tiers].join(',')}, ${takeNames.join('/')}): mean note ${before.toFixed(2)} -> ${after.toFixed(2)}`);
  for (const c of changes) console.log(`   step ${c.k} ${c.from.limb}${c.from.move ? ' ' + c.from.move : ''}: beat ${c.from.at}${c.from.gap ? ` gap ${c.from.gap}` : ''} -> ${c.to.at}${c.to.gap ? ` gap ${c.to.gap}` : ''}`);
}

if (write) {
  // Rewrites only the chart's "patterns" block, in the files' one-step-per-line style.
  const text = readFileSync(levelPath, 'utf8');
  const out = JSON.parse(text);
  if (!out.chart.rich) throw new Error(`${id} has no chart.rich block to write into; add one by hand first`);
  for (const p of proposals) {
    if (!p.changes.length) continue;
    const key = String(p.index);
    const existing = out.chart.rich.patterns[key];
    if (existing) {
      for (const c of p.changes) {
        existing[c.k].at = c.to.at;
        if (c.to.gap !== undefined) existing[c.k].gap = c.to.gap;
      }
    } else {
      out.chart.rich.patterns[key] = p.steps.map(s => ({at: s.at, limb: s.limb}));
    }
  }
  const keys = Object.keys(out.chart.rich.patterns).sort((a, b) => a - b);
  const start = text.indexOf('"patterns": {', text.indexOf('"rich"'));
  let depth = 0, end = start + '"patterns": '.length;
  for (; end < text.length; end++) {
    if (text[end] === '{') depth++;
    if (text[end] === '}' && --depth === 0) break;
  }
  const indent = text.slice(text.lastIndexOf('\n', start) + 1, start);
  const step = s => '{' + Object.entries(s).map(([k, v]) => `${JSON.stringify(k)}: ${JSON.stringify(v)}`).join(', ') + '}';
  // Keep the file's own style: one step per line, or JSON.stringify's expanded form.
  const firstKey = text.slice(start).match(/\n( *)"/);
  const unit = firstKey ? firstKey[1].slice(indent.length) : '  ';
  const expanded = /\[\s*\n\s*\{\s*\n/.test(text.slice(start, end));
  const ordered = Object.fromEntries(keys.map(k => [k, out.chart.rich.patterns[k]]));
  const block = expanded
    ? '"patterns": ' + JSON.stringify(ordered, null, unit).split('\n').join('\n' + indent)
    : '"patterns": {\n' + keys.map(k => `${indent}${unit}${JSON.stringify(k)}: [\n` +
      ordered[k].map(s => `${indent}${unit}${unit}${step(s)}`).join(',\n') + `\n${indent}${unit}]`).join(',\n') + `\n${indent}}`;
  const next = text.slice(0, start) + block + text.slice(end + 1);
  JSON.parse(next);
  writeFileSync(levelPath, next);
  console.log(`wrote ${levelPath}`);
}
