#!/usr/bin/env node
// Checks a level's chart the way the game and its tests do, before running Flutter:
// FightChart._validateRich's shape, fairnessProblems at the tempo each tier plays (and the
// peak's replay of pattern 1 at the top tempo), the join from a call into its answer, a
// same-limb spacing for cues, and both chart checks of test/cue_path_test.dart (through
// cue_geometry.mjs). Prints each pattern's presses, rich steps, presses a second and
// off-beat share. The Dart tests stay the authority.
//   node tool/music/chart_check.mjs levels/comedor.json 120,124,128,132,136
import fs from 'node:fs';
import {cueProblems, testNotes} from './cue_geometry.mjs';

const [file, bpmArg, sameLimbArg] = process.argv.slice(2);
const level = JSON.parse(fs.readFileSync(file, 'utf8'));
const bpms = bpmArg.split(',').map(Number);
const sameLimbBeats = Number(sameLimbArg ?? 1.5);
const chart = level.chart;
const limits = {sameSpotMs: 285, thumbHopMs: 330, crossThumbMs: 170, sameLimbMs: 400, phraseEndMs: 100, ...(chart.rich?.limits ?? {})};
const guaranteed = 180, flourish = 400;
const isLeft = l => l === 'leftHand' || l === 'leftFoot';
const isFoot = l => l === 'leftFoot' || l === 'rightFoot';
const count = chart.variants.length + 1;
const stepsOf = i => chart.rich?.patterns?.[String(i)] ?? chart.offsets.map((at, k) => ({at, limb: (i === 0 ? chart.limbs : chart.variants[i - 1])[k]}));
const notesOf = steps => steps.flatMap((s, step) => {
  const out = [{at: s.at, limb: s.limb, step, offer: s.offer}];
  if (s.move === 'pair') out.push({at: s.at, limb: s.with, step});
  if (s.move === 'split') out.push({at: s.at + s.gap, limb: s.with, step});
  if (s.move === 'doubleTap') out.push({at: s.at + s.gap, limb: s.limb, step});
  return out;
}).sort((a, b) => a.at - b.at || a.step - b.step);
const patternIndex = (tier, peak) => tier === 0 ? 0 : 1 + (tier === 4 ? 3 + peak : tier - 1) % chart.variants.length;
let bad = 0;
const fail = m => { bad++; console.log('  FAIL ' + m); };

function checkPair(a, b, beats, beatMs, where) {
  if (beats === 0) return;
  const same = a.step === b.step;
  const floor = a.limb === b.limb ? (same ? limits.sameSpotMs : limits.sameLimbMs) : isLeft(a.limb) === isLeft(b.limb) ? limits.thumbHopMs : limits.crossThumbMs;
  const ms = beats * beatMs;
  if (ms < floor) fail(`${where}: ${a.limb}@${a.at} ${b.limb}@${b.at} ${ms.toFixed(0)} ms < ${floor}`);
  if (a.limb === b.limb && !same && beats < sameLimbBeats - 1e-9) fail(`${where}: ${a.limb} again after ${beats} beats`);
}

const plays = new Map();
for (let tier = 0; tier < 5; tier++) for (let peak = 0; peak < (tier === 4 ? 3 : 1); peak++) {
  const i = patternIndex(tier, peak);
  plays.set(i, Math.max(plays.get(i) ?? 0, bpms[tier]));
}
for (let i = 0; i < count; i++) {
  const steps = stepsOf(i);
  if (steps.length !== chart.limbs.length) fail(`pattern ${i} has ${steps.length} steps`);
  let prev = -1;
  for (const s of steps) {
    if (s.at <= prev) fail(`pattern ${i} out of order at ${s.at}`);
    prev = s.at + (s.gap ?? 0);
    if (prev >= chart.callBeats) fail(`pattern ${i} runs past the call`);
    if ((s.move === 'pair' || s.move === 'split') && isLeft(s.with) === isLeft(s.limb)) fail(`pattern ${i} ${s.at}: one thumb`);
  }
  const notes = notesOf(steps);
  const bpm = plays.get(i);
  if (bpm === undefined) { console.log(`pattern ${i}: never played`); continue; }
  const beatMs = 60000 / bpm;
  for (let a = 0; a < notes.length; a++) for (let b = a + 1; b < notes.length; b++) checkPair(notes[a], notes[b], notes[b].at - notes[a].at, beatMs, `pattern ${i} @${bpm}`);
  // Into its own answer, 8 beats on.
  for (const a of notes) for (const b of notes) {
    const beats = b.at + chart.callBeats - a.at;
    if (beats < 3) checkPair(a, {...b, step: -1}, beats, beatMs, `pattern ${i} join`);
  }
  for (let k = 0; k + 1 < notes.length; k++) {
    if (!notes[k].offer) continue;
    const next = notes.slice(k + 1).find(n => n.at > notes[k].at);
    if (next && (next.at - notes[k].at) * beatMs < 2 * guaranteed + flourish + 40) fail(`pattern ${i}: no room for the offer at ${notes[k].at}`);
  }
  if ((chart.callBeats - notes.at(-1).at) * beatMs - guaranteed < limits.phraseEndMs) fail(`pattern ${i}: ends late`);
  const rich = steps.filter(s => s.move).length;
  const off = notes.filter(n => n.at % 1 !== 0).length;
  const feetOnBeat = notes.filter(n => isFoot(n.limb) && n.at % 1 === 0).length, feet = notes.filter(n => isFoot(n.limb)).length;
  const handsOff = notes.filter(n => !isFoot(n.limb) && n.at % 1 !== 0).length, hands = notes.length - feet;
  console.log(`pattern ${i} @${bpm}: ${notes.length} presses, ${rich} rich, ${(notes.length / (chart.callBeats * beatMs / 1000)).toFixed(2)}/s, off-beat ${(100 * off / notes.length).toFixed(0)}%, feet on beat ${feetOnBeat}/${feet}, hands off beat ${handsOff}/${hands}`);
}
const patterns = [...Array(count).keys()].map(i => notesOf(stepsOf(i)));
// Any answer into any call: a failed phrase can drop the music to another tier.
for (let i = 0; i < count; i++) for (let j = 0; j < count; j++) {
  if (i === j || !plays.has(i) || !plays.has(j)) continue;
  const beatMs = 60000 / Math.max(plays.get(i), plays.get(j));
  for (const a of patterns[i]) for (const b of patterns[j]) {
    const beats = b.at + chart.callBeats - a.at;
    if (beats < 3) checkPair({...a, step: -2}, {...b, step: -1}, beats, beatMs, `pattern ${i} into ${j}`);
  }
}
const cue = cueProblems(testNotes(level.id, patterns));
if (cue) fail('cue: ' + cue);
console.log(bad ? `${bad} problems` : 'clean');
process.exit(bad ? 1 : 0);
