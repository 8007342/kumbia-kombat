#!/usr/bin/env node
// Does each chart note land on something you can hear in the rendered take that plays it?
//
//   node tool/music/align_charts.mjs                 # every level in the manifest
//   node tool/music/align_charts.mjs --level bar --worst 20
//   node tool/music/align_charts.mjs --json out.json # the full numbers, for a plan note
//   node tool/music/align_charts.mjs --root ../salon # another worktree's manifest, levels and takes
//   node tool/music/align_charts.mjs --min 55        # exit 1 if any tier scores under 55
//
// Analysis is `mixrs salience` (Rust, streaming, about 10 MB a take), run one take at a time
// and cached by file size and time in ~/.cache/tillandsias-project/kumbia-audio/align/.
// This measures attacks, not taste: a note can sit on a strong onset and still feel wrong,
// and nobody here can listen. See plan/chart-alignment-2026-11-07.md.
import {execFileSync} from 'node:child_process';
import {existsSync, mkdirSync, readFileSync, statSync, writeFileSync} from 'node:fs';
import {homedir} from 'node:os';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const here = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i < 0 ? fallback : args[i + 1];
};
const root = resolve(opt('root', here));
const onlyLevel = opt('level', null);
const worstCount = Number(opt('worst', 12));
const minScore = opt('min', null) == null ? null : Number(opt('min'));
const jsonOut = opt('json', null);
const quiet = args.includes('--quiet');

export const DIV = 12; // grid points per beat: sixteenths and triplets
export const BANDS = ['low', 'mid', 'high', 'pitch'];
export const BAND_NAMES = {low: 'kick/bass', mid: 'congas/keys/melody body', high: 'güiro/shaker/clave/brass edge', pitch: 'new note'};
// A note's score in one band is its salience (1.0 = a typical sixteenth in that take and band)
// times a lag weight: full within 25 ms, nothing past 60 ms. Perfect is ±75 ms in the judge,
// and people notice audio-visual offsets of about 30-100 ms (RESEARCH, 2026-11-07).
export const LAG_FULL_MS = 25, LAG_ZERO_MS = 60;
export const STRONG = 1.5, ON = 1.0, WEAK = 0.6, SILENT = 0.35;

const read = path => JSON.parse(readFileSync(path, 'utf8'));

function mixrsBinary() {
  if (process.env.MIXRS) return process.env.MIXRS;
  // Its own target directory: mix.py's shared one is rebuilt from whichever worktree ran last.
  const target = process.env.ALIGN_CARGO_TARGET_DIR || resolve(homedir(), '.cache/tillandsias-project/mixrs-work/target-align');
  const bin = resolve(target, 'release/mixrs');
  execFileSync('cargo', ['build', '--release', '--quiet'], {
    cwd: resolve(here, 'tool/music/mixrs'), env: {...process.env, CARGO_TARGET_DIR: target}, stdio: 'inherit',
  });
  return bin;
}
let mixrs = null;

const cacheDir = resolve(homedir(), '.cache/tillandsias-project/kumbia-audio/align');
export function salience(file, bpm, start, beats) {
  const st = statSync(file);
  const key = `${file.replace(/[^a-zA-Z0-9]+/g, '_')}-${st.size}-${Math.round(st.mtimeMs)}-${bpm}-${start}-${beats}-${DIV}-v1.json`;
  const cached = resolve(cacheDir, key);
  if (existsSync(cached)) return read(cached);
  mixrs ??= mixrsBinary();
  const out = execFileSync(mixrs, ['--threads', '2', 'salience', '--file', file, '--bpm', String(bpm),
    '--start', String(start), '--beats', String(beats), '--div', String(DIV)], {maxBuffer: 64 << 20});
  mkdirSync(cacheDir, {recursive: true});
  writeFileSync(cached, out);
  return JSON.parse(out);
}

// The chart's patterns, as FightChart.pattern and ChartPattern.rich build them.
export function patternNotes(chart, index) {
  const rich = chart.rich?.patterns?.[String(index)];
  if (rich) {
    const notes = [];
    rich.forEach((s, step) => {
      notes.push({at: s.at, limb: s.limb, step, move: s.move ?? null});
      if (s.move === 'pair') notes.push({at: s.at, limb: s.with, step, move: 'pair'});
      if (s.move === 'split') notes.push({at: s.at + s.gap, limb: s.with, step, move: 'split'});
      if (s.move === 'doubleTap') notes.push({at: s.at + s.gap, limb: s.limb, step, move: 'doubleTap'});
    });
    return notes.sort((a, b) => a.at - b.at);
  }
  const limbs = index === 0 ? chart.limbs : chart.variants[index - 1];
  return chart.offsets.map((at, step) => ({at, limb: limbs[step], step, move: null}));
}
// FightChart.patternIndex: tier 4 plays one pattern per final challenge, wrapping round the
// variants, so a third challenge replays variants[0] at the top tier's tempo. FEEL raised
// finalChallenges to 3 on four levels (work/1873-feel), so at least 3 are assumed.
export const finalChallengesOf = level => Math.max(level?.rules?.finalChallenges ?? 2, 3);
export function patternIndices(chart, tier, finals = 3) {
  const n = chart.variants?.length ?? 0;
  if (n === 0 || tier === 0) return [0];
  if (tier === 4) return [...new Set(Array.from({length: finals}, (_, peak) => 1 + ((3 + peak) % n)))];
  return [1 + ((tier - 1) % n)];
}

// Where a level's calls start in each take's file, in bars, with weights. The transport's
// origin is -entryBar bars at the level's first beat and carries across layered tiers; the
// lawn's cuts re-anchor at a 16-beat boundary to one of their entry bars.
export function callPhases(manifest, id, level, take) {
  const m = manifest.levels[id];
  const L = m.takes[take].bars;
  const introBars = level.chart.introBeats / 4;
  const prev = Object.values(manifest.levels).find(x => x.bridge?.to === id);
  const entry = prev?.bridge?.entryBar ?? 0;
  const weights = new Map();
  const add = (bar, w) => weights.set(((bar % 4) + 4) % 4, (weights.get(((bar % 4) + 4) % 4) ?? 0) + w);
  if (m.cuts?.length) {
    // A cut lands at a transport beat 16k, which is introBeats before a call starts.
    if (m.tierTakes[0] === take) add(entry + introBars, 1);
    for (const c of m.cuts.filter(c => c.to === take)) for (const e of c.entryBars) add(e + introBars, 1 / c.entryBars.length);
  } else {
    add(entry + introBars, 1);
  }
  const total = [...weights.values()].reduce((a, b) => a + b, 0);
  return {bars: L, phases: [...weights].map(([bar, w]) => ({bar, weight: w / total}))};
}

const lagWeight = lag => {
  const a = Math.abs(lag);
  return a <= LAG_FULL_MS ? 1 : a >= LAG_ZERO_MS ? 0 : (LAG_ZERO_MS - a) / (LAG_ZERO_MS - LAG_FULL_MS);
};
export function pointScore(sal, g) {
  let best = {score: 0, band: null, lag: null};
  for (const b of BANDS) {
    const v = sal.salience[b][g] * lagWeight(sal.lagMs[b][g]);
    if (v > best.score) best = {score: v, band: b, lag: sal.lagMs[b][g]};
  }
  return best;
}
const gridAt = (sal, beat) => {
  const n = sal.salience.low.length;
  return ((Math.round(beat * DIV) % n) + n) % n;
};

// One pattern in one half (call or response), over every place the loop can put it.
export function scorePattern(sal, notes, phases, half) {
  const L = sal.beats;
  const rows = notes.map(n => ({...n, score: 0, bands: {}, lag: 0, silent: 0, weak: 0, on: 0}));
  for (const {bar, weight} of phases) {
    const starts = [];
    for (let b = bar * 4 + half * 8; b < L + bar * 4; b += 16) starts.push(b % L);
    for (const s of starts) {
      rows.forEach(r => {
        const p = pointScore(sal, gridAt(sal, s + r.at));
        const w = weight / starts.length;
        r.score += w * Math.min(p.score, 3);
        r.lag += w * (p.lag ?? 0);
        if (p.band) r.bands[p.band] = (r.bands[p.band] ?? 0) + w;
        if (p.score < SILENT) r.silent += w;
        if (p.score < WEAK) r.weak += w;
        if (p.score >= ON) r.on += w;
      });
    }
  }
  return rows.map(r => ({...r, band: Object.entries(r.bands).sort((a, b) => b[1] - a[1])[0]?.[0] ?? null}));
}

// The take's accent profile over one 8-beat half, on sixteenths, averaged over the places the
// loop can put that half. Strong accents with no note within an eighth are "unanswered".
export function accentProfile(sal, phases, half) {
  const L = sal.beats;
  const prof = new Array(32).fill(0);
  for (const {bar, weight} of phases) {
    const starts = [];
    for (let b = bar * 4 + half * 8; b < L + bar * 4; b += 16) starts.push(b % L);
    for (const s of starts) for (let i = 0; i < 32; i++) prof[i] += (weight / starts.length) * Math.min(pointScore(sal, gridAt(sal, s + i / 4)).score, 3);
  }
  return prof;
}

// Phrase structure: which bar of four looks like a phrase start, from bar-to-bar change in
// harmony and loudness and the downbeat's low-band hit. A guess, reported with its margin.
export function hypermeter(sal) {
  const bars = sal.barChroma.length;
  const novelty = new Array(4).fill(0), count = new Array(4).fill(0);
  for (let k = 0; k < bars; k++) {
    const a = sal.barChroma[(k - 1 + bars) % bars], b = sal.barChroma[k];
    let d = 0;
    for (let i = 0; i < 12; i++) d += Math.abs(a[i] - b[i]);
    const loud = Math.abs(sal.barDb[k] - sal.barDb[(k - 1 + bars) % bars]) / 3;
    const hit = sal.salience.low[k * 4 * DIV] / 3;
    novelty[k % 4] += d + loud + hit;
    count[k % 4]++;
  }
  const mean = novelty.map((v, i) => v / count[i]);
  const order = mean.map((v, i) => [v, i]).sort((a, b) => b[0] - a[0]);
  return {start: order[0][1], margin: +(order[0][0] / Math.max(1e-9, order[1][0])).toFixed(2), byBar: mean.map(v => +v.toFixed(3))};
}

export function auditLevel(manifest, id, level, takePath) {
  const m = manifest.levels[id];
  const chart = level.chart;
  const tiers = [];
  const takes = {};
  for (const [name, take] of Object.entries(m.takes)) {
    const file = takePath(take.files.opus);
    takes[name] = {sal: salience(file, take.bpm, take.loopStartSeconds, take.bars * 4), ...callPhases(manifest, id, level, name), bpm: take.bpm};
    takes[name].meter = hypermeter(takes[name].sal);
  }
  for (let tier = 0; tier < 5; tier++) {
    const take = m.tierTakes[tier];
    const t = takes[take];
    for (const index of patternIndices(chart, tier, finalChallengesOf(level))) {
      const notes = patternNotes(chart, index);
      for (const half of [0, 1]) {
        const rows = scorePattern(t.sal, notes, t.phases, half);
        const prof = accentProfile(t.sal, t.phases, half);
        const noteAt = notes.map(n => n.at);
        const unanswered = prof.map((v, i) => ({at: i / 4, v})).filter(a => a.v >= 1.6 && !noteAt.some(n => Math.abs(n - a.at) < 0.126));
        tiers.push({tier, take, bpm: t.bpm, pattern: index, half: half ? 'response' : 'call', rows, profile: prof, unanswered});
      }
    }
  }
  return {id, tiers, takes: Object.fromEntries(Object.entries(takes).map(([k, v]) => [k, {bpm: v.bpm, bars: v.bars, phases: v.phases, meter: v.meter}]))};
}

export function summarize(rows) {
  const n = rows.length;
  const mean = f => rows.reduce((a, r) => a + f(r), 0) / n;
  return {
    score: Math.round(100 * mean(r => Math.min(r.score, 2) / 2)),
    on: Math.round(100 * mean(r => r.on)),
    weak: Math.round(100 * mean(r => r.weak)),
    silent: Math.round(100 * mean(r => r.silent)),
    lagMs: Math.round(mean(r => r.lag)),
  };
}

function main() {
  const manifest = read(resolve(root, 'assets/music/rendered/manifest.json'));
  const takePath = p => resolve(root, p);
  const ids = Object.keys(manifest.levels).filter(id => !onlyLevel || id === onlyLevel);
  const report = {};
  let failed = false;
  for (const id of ids) {
    const levelFile = resolve(root, `levels/${id}.json`);
    if (!existsSync(levelFile)) continue;
    const audit = auditLevel(manifest, id, read(levelFile), takePath);
    report[id] = audit;
    const byTier = [0, 1, 2, 3, 4].map(t => summarize(audit.tiers.filter(x => x.tier === t).flatMap(x => x.rows)));
    const all = summarize(audit.tiers.flatMap(x => x.rows));
    audit.summary = {all, byTier};
    if (quiet) continue;
    console.log(`\n== ${id}: score ${all.score}  on-accent ${all.on}%  weak ${all.weak}%  silent ${all.silent}%`);
    for (const [name, t] of Object.entries(audit.takes)) {
      console.log(`   take ${name} ${t.bpm} BPM, ${t.bars} bars; calls start on bar ${t.phases.map(p => `${p.bar} mod 4${p.weight < 1 ? ` (${Math.round(p.weight * 100)}%)` : ''}`).join(', ')}; music's 4-bar phrase looks like it starts on bar ${t.meter.start} mod 4 (margin ${t.meter.margin})`);
    }
    byTier.forEach((s, t) => console.log(`   tier ${t} (${manifest.levels[id].tierTakes[t]}): score ${s.score}  on ${s.on}%  weak ${s.weak}%  silent ${s.silent}%  mean lag ${s.lagMs} ms`));
    for (const x of audit.tiers) {
      if (!x.unanswered.length) continue;
      console.log(`   tier ${x.tier} p${x.pattern} ${x.half}: strong accents with no note at ${x.unanswered.map(a => `${a.at}(${a.v.toFixed(1)})`).join(' ')}`);
    }
    const worst = audit.tiers.flatMap(x => x.rows.map(r => ({...r, tier: x.tier, pattern: x.pattern, half: x.half})))
      .sort((a, b) => a.score - b.score).slice(0, worstCount);
    console.log('   worst notes:');
    for (const r of worst) console.log(`     tier ${r.tier} p${r.pattern} ${r.half.padEnd(8)} beat ${String(r.at).padEnd(5)} ${r.limb.padEnd(9)} score ${r.score.toFixed(2)}  weak ${Math.round(r.weak * 100)}%  best band ${r.band ?? '-'}  lag ${r.lag.toFixed(0)} ms`);
    if (minScore != null && byTier.some(s => s.score < minScore)) failed = true;
  }
  if (jsonOut) {
    const slim = Object.fromEntries(Object.entries(report).map(([id, a]) => [id, {...a, tiers: a.tiers.map(x => ({...x, profile: x.profile.map(v => +v.toFixed(2)), rows: x.rows.map(r => ({at: r.at, limb: r.limb, step: r.step, move: r.move, score: +r.score.toFixed(3), on: +r.on.toFixed(2), weak: +r.weak.toFixed(2), silent: +r.silent.toFixed(2), band: r.band, lag: +r.lag.toFixed(1)}))}))}]));
    writeFileSync(jsonOut, JSON.stringify(slim, null, 1));
  }
  if (failed) {
    console.error(`\nA tier scored under ${minScore}.`);
    process.exit(1);
  }
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
