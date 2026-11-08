// A port of lib/gameplay/cue_path.dart and the two chart checks in test/cue_path_test.dart, so
// align_suggest.mjs can reject a chart the Flutter test would reject without running Flutter.
// The Dart test stays the authority: if they ever disagree, fix this file to match it.
const cueLandingJitterX = .04, cueLandingJitterY = .018, cueLandingMinimumStray = .5;
const cueStartNearX = .012, cueStartFarX = .05, cueStartNearY = .006, cueStartFarY = .028;
const cueHandBend = .85, cueFootBend = .6, cueBendJitter = .1;
export const cueFadeInSpan = .3;
const cueRingRadius = 29;
const thumbBandTop = .65, thumbBandSplit = .81, thumbBandBottom = .97;
const padCentre = {x: .5, y: .805}, reachX = .20, reachY = .09;
export const SCREENS = [[320, 454], [320, 568], [360, 640], [375, 667], [390, 664], [390, 844], [412, 915], [430, 932], [500, 700], [500, 1000]];

const isLeft = limb => limb === 'leftHand' || limb === 'leftFoot';
const isUpper = limb => limb === 'leftHand' || limb === 'rightHand';
export const cueExtent = p => 25 + Math.min(Math.max(p, 0), 1) * 21;
const clamp = (v, a, b) => Math.min(Math.max(v, a), b);
const within = (v, lo, hi) => (lo > hi ? (lo + hi) / 2 : clamp(v, lo, hi));
const dartRound = v => (v < 0 ? -Math.round(-v) : Math.round(v)); // half away from zero

function draws(id, beat) {
  const M = 2147483647, A = 48271;
  let state = 20112;
  for (const unit of [...[...id].map(c => c.charCodeAt(0)), dartRound(beat * 16)]) state = (state * A + unit + 1) % M;
  const next = () => (state = (state * A) % M) / M;
  next();
  next();
  return next;
}

function insideZone(limb, x, y, w, h) {
  const left = isLeft(limb) ? 0 : w / 2;
  const top = (isUpper(limb) ? thumbBandTop : thumbBandSplit) * h;
  const bottom = (isUpper(limb) ? thumbBandSplit : thumbBandBottom) * h;
  return {x: within(x * w, left + cueRingRadius, left + w / 2 - cueRingRadius), y: within(y * h, top + cueRingRadius, bottom - cueRingRadius)};
}

export function cuePath(limb, beat, id, w, h) {
  const side = isLeft(limb) ? -1 : 1;
  const rise = isUpper(limb) ? -1 : 1;
  const home = {x: padCentre.x + (isLeft(limb) ? -reachX : reachX), y: padCentre.y + (isUpper(limb) ? -reachY : reachY)};
  const next = draws(id, beat);
  const strayX = next(), strayY = next(), startX = next(), startY = next(), bend = next();
  const quarter = (((dartRound(beat * 4) % 2) + 2) % 2) !== 0;
  const onBeat = quarter ? Math.floor(beat) % 2 === 0 : dartRound(beat * 2) % 2 === 0;
  const landingX = home.x + side * (onBeat ? 1 : -1) * cueLandingJitterX * (cueLandingMinimumStray + (1 - cueLandingMinimumStray) * strayX);
  const landingY = home.y + (strayY * 2 - 1) * cueLandingJitterY;
  const landing = insideZone(limb, landingX, landingY, w, h);
  const between = (near, far, d) => near + (far - near) * d;
  const start = {x: (padCentre.x + side * between(cueStartNearX, cueStartFarX, startX)) * w, y: (padCentre.y + rise * between(cueStartNearY, cueStartFarY, startY)) * h};
  const mid = {x: (start.x + landing.x) / 2, y: (start.y + landing.y) / 2};
  const amount = (isUpper(limb) ? cueHandBend : cueFootBend) + (bend * 2 - 1) * cueBendJitter;
  const control = {x: mid.x + (landing.x - mid.x) * amount, y: mid.y + (start.y - mid.y) * amount};
  return t => {
    t = clamp(t, 0, 1);
    const a = (1 - t) * (1 - t), b = 2 * (1 - t) * t, c = t * t;
    return {x: a * start.x + b * control.x + c * landing.x, y: a * start.y + b * control.y + c * landing.y};
  };
}
const dist = (p, q) => Math.hypot(p.x - q.x, p.y - q.y);

// The test's layout: every pattern 0..variants in order, called then answered, from beat 4.
// `patterns` is a list of note lists [{at, limb}] in ChartPattern order.
export function testNotes(level, patterns) {
  const notes = [];
  let base = 4;
  patterns.forEach((notesOfPattern, p) => {
    for (const turn of [0, 8]) notesOfPattern.forEach((n, i) => notes.push({limb: n.limb, beat: base + turn + n.at, id: `${level}:${p}:0:0:${i}`}));
    base += 16;
  });
  return notes;
}

// Both chart checks. Returns null if they pass, or the first failure. The different-limb
// check can be limited to notes near `focus` beats, to keep a search fast.
export function cueProblems(notes, {focus = null} = {}) {
  const paths = new Map();
  const path = (n, s) => {
    const key = `${n.id}|${n.beat}|${s}`;
    if (!paths.has(key)) paths.set(key, cuePath(n.limb, n.beat, n.id, SCREENS[s][0], SCREENS[s][1]));
    return paths.get(key);
  };
  const near = focus ? n => focus.some(([a, b]) => n.beat >= a - 3 && n.beat <= b + 3) : () => true;
  // Same limb: the ratio floor of 0.35 over all charts.
  for (let s = 0; s < SCREENS.length; s++) {
    for (let i = 0; i < notes.length; i++) for (let j = i + 1; j < notes.length; j++) {
      const a = notes[i], b = notes[j];
      const gap = Math.abs(a.beat - b.beat);
      if (a.limb !== b.limb || gap > 2.5 || gap === 0 || !(near(a) || near(b))) continue;
      for (let step = 0; step <= 40; step++) {
        const beat = Math.max(a.beat, b.beat) - 2 + step / 16;
        if (beat > Math.min(a.beat, b.beat) + .5) break;
        const ta = clamp((beat - a.beat + 2) / 2, 0, 1), tb = clamp((beat - b.beat + 2) / 2, 0, 1);
        if (ta < cueFadeInSpan || tb < cueFadeInSpan) continue;
        const ratio = dist(path(a, s)(ta), path(b, s)(tb)) / ((cueExtent(ta) + cueExtent(tb)) / 2);
        if (ratio < .35 + 1e-6) return `same limb ${a.limb} at ${a.beat} and ${b.beat}, screen ${SCREENS[s]}: ${ratio.toFixed(3)}`;
      }
    }
  }
  // Different limbs: a full cue apart once both have faded in.
  const last = notes.at(-1).beat + 1;
  for (let s = 0; s < SCREENS.length; s++) {
    for (let step = 0; step < Math.ceil(last * 16); step++) {
      const beat = step / 16;
      if (focus && !focus.some(([a, b]) => beat >= a - 3 && beat <= b + 3)) continue;
      const live = notes.filter(n => beat >= n.beat - 2 && beat <= n.beat + .5);
      for (let i = 0; i < live.length; i++) for (let j = i + 1; j < live.length; j++) {
        const a = live[i], b = live[j];
        if (a.limb === b.limb) continue;
        const ta = clamp((beat - a.beat + 2) / 2, 0, 1), tb = clamp((beat - b.beat + 2) / 2, 0, 1);
        if (ta < cueFadeInSpan || tb < cueFadeInSpan) continue;
        if (dist(path(a, s)(ta), path(b, s)(tb)) < (cueExtent(ta) + cueExtent(tb)) / 2 - 1e-9) return `limbs ${a.limb} ${b.limb} at beat ${beat}, screen ${SCREENS[s]}`;
      }
    }
  }
  return null;
}
