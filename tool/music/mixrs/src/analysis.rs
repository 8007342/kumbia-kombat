//! Beat, harmony and level measures: one frame at a time, with only the answers kept.

use crate::np::*;
use crate::{ENV_RATE, HOP, RATE, WINDOW};
use rayon::prelude::*;
use realfft::RealFftPlanner;
use std::f64::consts::PI;

const FRAME_BATCH: usize = 512;

/// Half-wave rectified log spectral flux, with its slow trend removed. Frames are read in
/// parallel batches; a batch keeps one spectrum, its previous frame's, and no other.
pub fn onset_envelope(mono: &[f32]) -> Vec<f64> {
    let count = mono.len().saturating_sub(WINDOW) / HOP;
    assert!(count >= 2, "take is too short to measure");
    let window = hanning(WINDOW);
    let fft = RealFftPlanner::<f64>::new().plan_fft_forward(WINDOW);
    let mut env = vec![0.0; count];
    env.par_chunks_mut(FRAME_BATCH).enumerate().for_each(|(batch, part)| {
        let mut input = fft.make_input_vec();
        let mut output = fft.make_output_vec();
        let mut scratch = fft.make_scratch_vec();
        let bins = output.len();
        let mut prev = vec![0.0; bins];
        let mut spec = vec![0.0; bins];
        let first = batch * FRAME_BATCH;
        let mut log_spectrum = |i: usize, into: &mut [f64]| {
            let frame = &mono[i * HOP..i * HOP + WINDOW];
            for k in 0..WINDOW {
                input[k] = frame[k] as f64 * window[k];
            }
            fft.process_with_scratch(&mut input, &mut output, &mut scratch).expect("fft");
            for (v, c) in into.iter_mut().zip(output.iter()) {
                *v = (100.0 * c.norm()).ln_1p();
            }
        };
        if first > 0 {
            log_spectrum(first - 1, &mut prev);
        }
        for (j, slot) in part.iter_mut().enumerate() {
            let i = first + j;
            log_spectrum(i, &mut spec);
            if i > 0 {
                *slot = spec.iter().zip(&prev).map(|(a, b)| (a - b).max(0.0)).sum();
            }
            std::mem::swap(&mut spec, &mut prev);
        }
    });
    let size = ENV_RATE as usize;
    let boxcar = vec![1.0 / size as f64; size];
    let trend = convolve_same(&env, &boxcar);
    env.iter().zip(&trend).map(|(e, t)| (e - t).max(0.0)).collect()
}

pub fn env_times(count: usize) -> Vec<f64> {
    (0..count)
        .map(|i| (i as f64 - 0.5) * HOP as f64 / RATE as f64 + (WINDOW / 2) as f64 / RATE as f64)
        .collect()
}

fn pulse(env: &[f64], t: &[f64], freq: f64) -> (f64, f64) {
    let (mut re, mut im) = (0.0, 0.0);
    for (e, x) in env.iter().zip(t) {
        let (s, c) = (-2.0 * PI * freq * x).sin_cos();
        re += e * c;
        im += e * s;
    }
    (re, im)
}

pub fn fit_tempo(env: &[f64], target: f64, span_pct: f64) -> f64 {
    let t = env_times(env.len());
    let grid: Vec<f64> = linspace(-span_pct, span_pct, 601).iter().map(|p| target * (1.0 + p / 100.0)).collect();
    let power: Vec<f64> = grid
        .par_iter()
        .map(|g| {
            let (re, im) = pulse(env, &t, g / 60.0);
            re.hypot(im)
        })
        .collect();
    let i = argmax(&power);
    let mut bpm = grid[i];
    if i > 0 && i < grid.len() - 1 {
        let (a, b, c) = (power[i - 1], power[i], power[i + 1]);
        bpm += 0.5 * (a - c) / (a - 2.0 * b + c) * (grid[1] - grid[0]);
    }
    bpm
}

/// A fine, uncompressed energy rise, read every 32 samples. Reads only what it needs.
pub fn attack_curve(mono: &[f32]) -> (Vec<f64>, f64) {
    let (size, step) = (128usize, 32usize);
    let n = mono.len();
    let count = n.div_ceil(step);
    let mut energy = vec![0f64; count];
    energy.par_chunks_mut(4096).enumerate().for_each(|(batch, part)| {
        for (j, slot) in part.iter_mut().enumerate() {
            let i = (batch * 4096 + j) * step;
            // np.convolve "same" with 128 ones: indices i - 64 ..= i + 63, clipped.
            let lo = i.saturating_sub(64);
            let hi = (i + 64).min(n);
            let mut sum = 0.0;
            for s in &mono[lo..hi] {
                let v = *s as f64;
                sum += v * v;
            }
            *slot = (sum / size as f64).sqrt();
        }
    });
    let mut rise = vec![0f64; count];
    for i in 1..count {
        rise[i] = (energy[i] - energy[i - 1]).max(0.0);
    }
    (rise, step as f64 / RATE as f64)
}

fn pick_attacks(curve: &[f64], step: f64, beats: &[f64]) -> Vec<f64> {
    let reach = (0.05 / step) as i64;
    let mut found = Vec::with_capacity(beats.len());
    for beat in beats {
        let at = (beat / step) as i64;
        let low = (at - reach).max(0);
        let high = (at + reach + 1).min(curve.len() as i64);
        if high > low {
            let (mut best, mut pos) = (curve[low as usize], low);
            for k in low..high {
                if curve[k as usize] > best {
                    best = curve[k as usize];
                    pos = k;
                }
            }
            found.push(pos as f64 * step - beat);
        }
    }
    found
}

/// Typical and worst-block distance from real attacks to given beats, in ms.
pub fn grid_error_ms(curve: &[f64], step: f64, beats: &[f64]) -> (f64, f64) {
    let found = pick_attacks(curve, step, beats);
    let mut blocks = Vec::new();
    let top = if found.len() > 15 { found.len() - 15 } else { 1 };
    let mut i = 0;
    while i < top {
        blocks.push(median(&found[i..(i + 16).min(found.len())]));
        i += 8;
    }
    let abs: Vec<f64> = found.iter().map(|v| v.abs()).collect();
    let worst = blocks.iter().fold(0.0f64, |m, v| m.max(v.abs()));
    (round_to(median(&abs) * 1000.0, 2), round_to(worst * 1000.0, 2))
}

pub fn grid_bias_seconds(curve: &[f64], step: f64, beats: &[f64]) -> f64 {
    median(&pick_attacks(curve, step, beats))
}

/// The likeliest path of beat offsets around a straight line: Viterbi over comb scores.
fn track_offsets(env: &[f64], t: &[f64], line: &[f64]) -> (Vec<f64>, Vec<f64>) {
    let kernel7: Vec<f64> = hanning(7).iter().map(|v| v / 3.0).collect();
    let smooth = convolve_same(env, &kernel7);
    let offsets = arange(-0.15, 0.1501, 0.003);
    let (rows, cols) = (line.len(), offsets.len());
    let mut columns: Vec<Vec<f64>> = offsets
        .par_iter()
        .map(|o| {
            let it = Interp { xp: t, fp: &smooth, left: 0.0, right: 0.0 };
            line.iter().map(|l| it.at(l + o)).collect()
        })
        .collect();
    let kernel: Vec<f64> = hanning(11)[1..10].to_vec();
    for c in columns.iter_mut() {
        *c = convolve_same(c, &kernel);
    }
    let all = columns.iter().flatten().sum::<f64>() / (rows * cols) as f64;
    let norm = all.max(1e-9);
    let score: Vec<Vec<f64>> = (0..rows).map(|r| (0..cols).map(|c| columns[c][r] / norm).collect()).collect();
    let mut total = score[0].clone();
    let mut back = vec![vec![0i64; cols]; rows];
    let cost: Vec<f64> = (-3i64..=3).map(|s| 0.15 * (s * s) as f64).collect();
    for n in 1..rows {
        let mut next = vec![0.0; cols];
        for j in 0..cols {
            let (mut best, mut pick) = (f64::NEG_INFINITY, 0i64);
            let mut found = false;
            for (si, s) in (-3i64..=3).enumerate() {
                let from = j as i64 - s;
                let v = if from >= 0 && from < cols as i64 { total[from as usize] - cost[si] } else { f64::NEG_INFINITY };
                if !found || v > best {
                    best = v;
                    pick = s;
                    found = true;
                }
            }
            next[j] = best + score[n][j];
            back[n][j] = j as i64 - pick;
        }
        total = next;
    }
    let mut j = argmax(&total) as i64;
    let mut path = vec![0usize; rows];
    for n in (0..rows).rev() {
        path[n] = j as usize;
        j = back[n][j as usize].clamp(0, cols as i64 - 1);
    }
    let weight = (0..rows).map(|n| score[n][path[n]]).collect();
    (path.iter().map(|&p| offsets[p]).collect(), weight)
}

/// Solves (diag(w) + s * D2'D2) x = w * v, a symmetric pentadiagonal system, by banded Cholesky.
fn solve_penta(w: &[f64], v: &[f64], s: f64) -> Vec<f64> {
    let n = w.len();
    // l[i][b]: the entry b places left of the diagonal in row i.
    let mut a = vec![[0.0f64; 3]; n];
    for i in 0..n.saturating_sub(2) {
        let row = [1.0, -2.0, 1.0];
        for x in 0..3 {
            for y in 0..=x {
                a[i + x][x - y] += s * row[x] * row[y];
            }
        }
    }
    for i in 0..n {
        a[i][0] += w[i];
    }
    let mut l = a;
    for i in 0..n {
        for b in (0..3).rev() {
            if b > i {
                continue;
            }
            let j = i - b;
            let mut sum = l[i][b];
            for k in 1..3 {
                if b + k < 3 && k <= j {
                    sum -= l[i][b + k] * l[j][k];
                }
            }
            if b == 0 {
                l[i][0] = sum.sqrt();
            } else {
                l[i][b] = sum / l[j][0];
            }
        }
    }
    let mut x: Vec<f64> = w.iter().zip(v).map(|(a, b)| a * b).collect();
    for i in 0..n {
        for b in 1..3 {
            if b <= i {
                x[i] -= l[i][b] * x[i - b];
            }
        }
        x[i] /= l[i][0];
    }
    for i in (0..n).rev() {
        for b in 1..3 {
            if i + b < n {
                x[i] -= l[i + b][b] * x[i + b];
            }
        }
        x[i] /= l[i][0];
    }
    x
}

fn smooth_curve(values: &[f64], weight: &[f64], period: f64) -> Vec<f64> {
    let max_slope = 0.0075;
    let w: Vec<f64> = weight.iter().map(|v| v.max(1e-3)).collect();
    let mut stiffness = 50.0;
    let mut curve = Vec::new();
    for _ in 0..12 {
        curve = solve_penta(&w, values, stiffness);
        let worst = curve.windows(2).fold(0.0f64, |m, p| m.max((p[1] - p[0]).abs()));
        if worst / period <= max_slope {
            return curve;
        }
        stiffness *= 4.0;
    }
    curve
}

pub fn phase_wander_ms(env: &[f64], bpm: f64) -> f64 {
    let size = (16.0 * 60.0 / bpm * ENV_RATE) as usize;
    let t = env_times(env.len());
    let freq = bpm / 60.0;
    let (mut phases, mut centres) = (Vec::new(), Vec::new());
    let hop = (size / 2).max(1);
    let mut start = 0;
    while size > 0 && start + size <= env.len() {
        let (re, im) = pulse(&env[start..start + size], &t[start..start + size], freq);
        phases.push(im.atan2(re));
        centres.push(mean(&t[start..start + size]));
        start += hop;
    }
    if phases.len() < 3 {
        return 0.0;
    }
    let unwrapped = unwrap(&phases);
    let (m, b) = polyfit1(&centres, &unwrapped);
    let sq: f64 = unwrapped.iter().zip(&centres).map(|(u, c)| (u - (m * c + b)).powi(2)).sum::<f64>() / phases.len() as f64;
    sq.sqrt() / (2.0 * PI * freq) * 1000.0
}

pub struct BeatFit {
    pub beats: Vec<f64>,
    pub bpm: f64,
    pub wander_ms: f64,
}

/// Measured beats: a straight fit, then the slow wander around it.
pub fn beat_times(mono: &[f32], target: f64) -> BeatFit {
    let env = onset_envelope(mono);
    let bpm = fit_tempo(&env, target, 3.0);
    let period = 60.0 / bpm;
    let t = env_times(env.len());
    let duration = mono.len() as f64 / RATE as f64;
    let (re, im) = pulse(&env, &t, 1.0 / period);
    let start = (im.atan2(re) / (2.0 * PI) * period).rem_euclid(period);
    let line: Vec<f64> = (0..(duration / period) as usize + 2).map(|i| start + i as f64 * period).collect();
    let (offset, weight) = track_offsets(&env, &t, &line);
    let smooth = smooth_curve(&offset, &weight, period);
    let (rise, step) = attack_curve(mono);
    let shifts: Vec<f64> = arange(-0.5, 0.5, 0.001).iter().map(|v| v * period).collect();
    let combs: Vec<f64> = shifts
        .par_iter()
        .map(|shift| {
            let (mut sum, mut n) = (0.0f64, 0usize);
            for (l, s) in line.iter().zip(&smooth) {
                let w = ((l + s + shift) / step) as i64;
                if w >= 0 && (w as usize) < rise.len() {
                    sum += rise[w as usize];
                    n += 1;
                }
            }
            sum / n as f64
        })
        .collect();
    let best = shifts[argmax(&combs)];
    let beats = line
        .iter()
        .zip(&smooth)
        .map(|(l, s)| l + s + best)
        .filter(|b| *b >= 0.0 && b + period <= duration)
        .collect();
    BeatFit { beats, bpm, wander_ms: phase_wander_ms(&env, bpm) }
}

pub type V12 = [f64; 12];

pub struct Features {
    pub chroma: Vec<V12>,
    pub band: Vec<V12>,
    pub attack: Vec<f64>,
}

#[derive(Clone, Copy)]
struct FrameFeatures {
    chroma: V12,
    bands: V12,
    low: f64,
}

/// Per beat: low-band attack, chroma and coarse band energy, on an exact grid. Each frame
/// reduces to 25 numbers as it's read; no spectrum is kept.
pub fn beat_features(mono: &[f32], beat_seconds: f64, beats: usize) -> Features {
    let (size, step) = (4096usize, 512usize);
    let count = mono.len().saturating_sub(size) / step;
    let window = hanning(size);
    let fft = RealFftPlanner::<f64>::new().plan_fft_forward(size);
    let bins = size / 2 + 1;
    let val = 1.0 / (size as f64 * (1.0 / RATE as f64));
    let freq: Vec<f64> = (0..bins).map(|k| k as f64 * val).collect();
    let edges: Vec<f64> = {
        let (a, b) = (60f64.log10(), 10000f64.log10());
        let mut e: Vec<f64> = linspace(a, b, 13).iter().map(|v| 10f64.powf(*v)).collect();
        e[0] = 60.0;
        e[12] = 10000.0;
        e
    };
    let pc: Vec<i32> = freq
        .iter()
        .map(|&f| {
            if (80.0..=2000.0).contains(&f) {
                let x = (12.0 * (f / 261.626).log2()).round_ties_even() as i64;
                x.rem_euclid(12) as i32
            } else {
                -1
            }
        })
        .collect();
    let band_of: Vec<i32> = freq
        .iter()
        .map(|&f| {
            for b in 0..12 {
                if f >= edges[b] && f < edges[b + 1] {
                    return b as i32;
                }
            }
            -1
        })
        .collect();
    let low_top = freq.iter().filter(|f| **f < 180.0).count();
    let blank = FrameFeatures { chroma: [0.0; 12], bands: [0.0; 12], low: 0.0 };
    let mut frames = vec![blank; count];
    frames.par_chunks_mut(256).enumerate().for_each(|(batch, part)| {
        let mut input = fft.make_input_vec();
        let mut output = fft.make_output_vec();
        let mut scratch = fft.make_scratch_vec();
        for (j, slot) in part.iter_mut().enumerate() {
            let i = batch * 256 + j;
            let frame = &mono[i * step..i * step + size];
            for k in 0..size {
                input[k] = frame[k] as f64 * window[k];
            }
            fft.process_with_scratch(&mut input, &mut output, &mut scratch).expect("fft");
            let mut lows = 0.0;
            for (k, c) in output.iter().enumerate() {
                let p = c.norm_sqr();
                if pc[k] >= 0 {
                    slot.chroma[pc[k] as usize] += p;
                }
                if band_of[k] >= 0 {
                    slot.bands[band_of[k] as usize] += p;
                }
                if k < low_top {
                    lows += p;
                }
            }
            for b in slot.bands.iter_mut() {
                *b = b.ln_1p();
            }
            slot.low = lows.sqrt();
        }
    });
    let mut low_rise = vec![0.0; count];
    for i in 1..count {
        low_rise[i] = (frames[i].low - frames[i - 1].low).max(0.0);
    }
    let frame_at: Vec<usize> = (0..=beats)
        .map(|b| {
            let x = (b as f64 * beat_seconds * RATE as f64 - (size / 2) as f64) / step as f64;
            (x as i64).clamp(0, count as i64) as usize
        })
        .collect();
    let mut out = Features { chroma: vec![[0.0; 12]; beats], band: vec![[0.0; 12]; beats], attack: vec![0.0; beats] };
    for b in 0..beats {
        let a = frame_at[b];
        let z = frame_at[b + 1].max(a + 1);
        let top = z.min(count);
        if a < top {
            for f in &frames[a..top] {
                for k in 0..12 {
                    out.chroma[b][k] += f.chroma[k];
                }
            }
        }
        if z <= count && a < count {
            let span = (z - a) as f64;
            for f in &frames[a..z] {
                for k in 0..12 {
                    out.band[b][k] += f.bands[k];
                }
            }
            for k in 0..12 {
                out.band[b][k] /= span;
            }
        }
        let from = a.saturating_sub(2).min(count);
        let to = (a + 4).min(count);
        if from < to {
            out.attack[b] = low_rise[from..to].iter().fold(f64::NEG_INFINITY, |m, v| m.max(*v));
        }
    }
    out
}

/// Which beat is bar one, with confidence and margin.
pub fn find_bar_one(chroma: &[V12], attack: &[f64]) -> (usize, f64, f64) {
    let per_bar = 4;
    let n = attack.len();
    let units: Vec<Vec<f64>> = chroma.iter().map(|c| unit(c)).collect();
    let mut change = vec![0.0; n];
    for b in 2..n.saturating_sub(2) {
        let sum = |x: usize, y: usize| -> Vec<f64> {
            (0..12).map(|k| units[x][k] + units[y][k]).collect()
        };
        change[b] = 1.0 - dot(&unit(&sum(b - 2, b - 1)), &unit(&sum(b, b + 1)));
    }
    let score = |lo: usize, hi: usize| -> [f64; 4] {
        let mut result = [0.0; 4];
        let at = mean(&attack[lo..hi]).max(1e-9);
        let ch = mean(&change[lo..hi]).max(1e-9);
        for (p, slot) in result.iter_mut().enumerate() {
            let pick: Vec<usize> = (lo..hi).filter(|b| b % per_bar == p).collect();
            let a = pick.iter().map(|&b| attack[b]).sum::<f64>() / pick.len() as f64;
            let c = pick.iter().map(|&b| change[b]).sum::<f64>() / pick.len() as f64;
            *slot = 1.0 * a / at + 2.0 * c / ch;
        }
        result
    };
    let whole = score(0, n);
    let best = argmax(&whole);
    let size = 8 * per_bar;
    let mut blocks = Vec::new();
    let top = if n > size { n - size } else { 1 };
    let mut lo = 0;
    while lo < top {
        blocks.push(argmax(&score(lo, lo + size)));
        lo += size / 2;
    }
    let agree = if blocks.is_empty() { 0.0 } else { blocks.iter().filter(|b| **b == best).count() as f64 / blocks.len() as f64 };
    let mut ordered = whole;
    ordered.sort_by(f64::total_cmp);
    let margin = (ordered[3] - ordered[2]) / ordered[3];
    (best, round_to(agree * (margin / 0.15).min(1.0), 2), round_to(margin, 3))
}

const TONICS: [(&str, usize); 12] = [("C", 0), ("C#", 1), ("D", 2), ("Eb", 3), ("E", 4), ("F", 5), ("F#", 6), ("G", 7), ("Ab", 8), ("A", 9), ("Bb", 10), ("B", 11)];
const MAJOR: V12 = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88];
const MINOR: V12 = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17];

pub fn measure_key(chroma: &[V12]) -> (String, f64) {
    let mut total = [0.0; 12];
    for c in chroma {
        for k in 0..12 {
            total[k] += c[k];
        }
    }
    let mut best = (-2.0, String::new());
    for (name, tonic) in TONICS {
        for (mode, profile) in [("major", &MAJOR), ("minor", &MINOR)] {
            let rolled: Vec<f64> = (0..12).map(|k| profile[(k + 12 - tonic) % 12]).collect();
            let r = corrcoef(&total, &rolled);
            if r > best.0 {
                best = (r, format!("{name} {mode}"));
            }
        }
    }
    (best.1, round_to(best.0, 3))
}

pub fn tonic_template(key: &str) -> Vec<f64> {
    let mut parts = key.split_whitespace();
    let (name, mode) = (parts.next().unwrap_or("C"), parts.next().unwrap_or("major"));
    let root = TONICS.iter().find(|t| t.0 == name).map(|t| t.1).unwrap_or(0);
    let mut t = vec![0.0; 12];
    let third = if mode == "minor" { 3 } else { 4 };
    for (step, weight) in [(0, 1.0), (third, 0.8), (7, 0.8)] {
        t[(root + step) % 12] = weight;
    }
    unit(&t)
}

pub struct LoopChoice {
    pub start_bar: usize,
    pub score: f64,
    pub harmony: f64,
    pub texture: f64,
    pub quiet_share: f64,
    pub candidates: usize,
}

/// The start bar whose continuation past the loop's end most resembles its head.
pub fn choose_loop(bar_chroma: &[V12], bar_band: &[V12], bar_rms: &[f64], loop_bars: usize) -> LoopChoice {
    let total = bar_rms.len();
    assert!(total >= loop_bars + 1, "take has {total} bars, needs {}", loop_bars + 1);
    let floor = median(bar_rms) * 0.5;
    let chroma: Vec<Vec<f64>> = bar_chroma.iter().map(|c| unit(c)).collect();
    let mut means = [0.0; 12];
    for b in bar_band {
        for k in 0..12 {
            means[k] += b[k] / total as f64;
        }
    }
    let band: Vec<Vec<f64>> = bar_band
        .iter()
        .map(|b| unit(&(0..12).map(|k| b[k] - means[k]).collect::<Vec<_>>()))
        .collect();
    let mut best: Option<(f64, usize, f64, f64, f64)> = None;
    let mut rows = 0;
    for start in 0..total - loop_bars {
        let end = start + loop_bars;
        let mut pairs = vec![(start, end)];
        if end + 1 < total {
            pairs.push((start + 1, end + 1));
        }
        if start > 0 {
            pairs.push((start - 1, end - 1));
        }
        let harmony = pairs.iter().map(|&(a, b)| dot(&chroma[a], &chroma[b])).sum::<f64>() / pairs.len() as f64;
        let texture = pairs.iter().map(|&(a, b)| dot(&band[a], &band[b])).sum::<f64>() / pairs.len() as f64;
        let level = 1.0 - (bar_rms[start].max(1e-6) / bar_rms[end].max(1e-6)).log2().abs().min(1.0);
        let quiet = bar_rms[start..end].iter().filter(|v| **v < floor).count() as f64 / loop_bars as f64;
        let row = (harmony + 0.5 * texture + 0.5 * level - 2.0 * quiet, start, harmony, texture, quiet);
        // Python's max over tuples: score first, then the later start on a tie.
        if best.is_none_or(|b| row.0 > b.0 || (row.0 == b.0 && row.1 > b.1)) {
            best = Some(row);
        }
        rows += 1;
    }
    let b = best.expect("at least one candidate");
    LoopChoice { start_bar: b.1, score: round_to(b.0, 3), harmony: round_to(b.2, 3), texture: round_to(b.3, 3), quiet_share: round_to(b.4, 3), candidates: rows }
}

/// Beat lock, against the take's own pattern. Returns ends spread and worst stretch, in ms.
pub fn pattern_drift(mono: &[f32], bpm: f64) -> (f64, f64) {
    let raw = onset_envelope(mono);
    let kernel: Vec<f64> = hanning(5).iter().map(|v| v / 2.0).collect();
    let env = convolve_same(&raw, &kernel);
    let t = env_times(env.len());
    let bar = 240.0 / bpm;
    let res = 256usize;
    let mut sums = vec![0.0; res];
    let mut counts = vec![0.0; res];
    for (e, x) in env.iter().zip(&t) {
        let cell = ((x.rem_euclid(bar) / bar * res as f64) as usize).min(res - 1);
        sums[cell] += e;
        counts[cell] += 1.0;
    }
    let pattern: Vec<f64> = sums.iter().zip(&counts).map(|(s, c)| s / f64::max(*c, 1.0)).collect();
    let pm = mean(&pattern);
    let pattern: Vec<f64> = pattern.iter().map(|p| p - pm).collect();
    let lags = arange(-0.15, 0.1501, 0.002);
    let last = t[t.len() - 1];
    let starts = arange(0.0, (last - 2.0 * bar).max(bar), bar);
    let found: Vec<f64> = starts
        .par_iter()
        .map(|start| {
            let from = t.partition_point(|x| *x < *start);
            let to = t.partition_point(|x| *x < *start + 2.0 * bar);
            let scores: Vec<f64> = lags
                .iter()
                .map(|lag| {
                    let mut s = 0.0;
                    for i in from..to {
                        let pos = (t[i] - lag).rem_euclid(bar) / bar * res as f64;
                        // np.interp with period: linear between cells, wrapping.
                        let j = pos.floor() as usize % res;
                        let f = pos - pos.floor();
                        s += env[i] * (pattern[j] * (1.0 - f) + pattern[(j + 1) % res] * f);
                    }
                    s
                })
                .collect();
            lags[argmax(&scores)] * 1000.0
        })
        .collect();
    let edge = 8.min((found.len() / 3).max(1));
    let med = median(&found);
    let worst = found.iter().fold(0.0f64, |m, v| m.max((v - med).abs()));
    (round_to(median(&found[found.len() - edge..]) - median(&found[..edge]), 1), round_to(worst, 1))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn clicks(bpm: f64, seconds: f64) -> Vec<f32> {
        let n = (seconds * RATE as f64) as usize;
        let mut out = vec![0f32; n];
        let mut state = 7u32;
        for s in out.iter_mut() {
            state = state.wrapping_mul(1664525).wrapping_add(1013904223);
            *s = ((state >> 16) as f32 / 65536.0 - 0.5) * 0.004;
        }
        let period = 60.0 / bpm;
        let mut k = 0;
        while (k as f64 * period + 0.02) * (RATE as f64) < (n - 400) as f64 {
            let at = ((k as f64 * period) * RATE as f64) as usize;
            for j in 0..400 {
                let t = j as f64;
                out[at + j] += (0.6 * (-t / 60.0).exp() * (2.0 * PI * 2500.0 * t / RATE as f64).sin()) as f32;
            }
            k += 1;
        }
        out
    }

    #[test]
    fn a_click_track_gives_its_own_tempo_and_beats() {
        let mono = clicks(100.0, 60.0);
        let fit = beat_times(&mono, 100.0);
        assert!((fit.bpm - 100.0).abs() < 0.05, "{}", fit.bpm);
        assert!(fit.wander_ms < 5.0, "{}", fit.wander_ms);
        let (rise, step) = attack_curve(&mono);
        let (typical, worst) = grid_error_ms(&rise, step, &fit.beats);
        assert!(typical < 5.0 && worst < 8.0, "{typical} {worst}");
    }

    #[test]
    fn the_key_finder_names_a_plain_a_minor() {
        let mut pcs = vec![[0.0; 12]; 16];
        for (i, row) in pcs.iter_mut().enumerate() {
            for &p in [[9, 0, 4], [2, 5, 9], [4, 7, 11], [9, 0, 4]][i % 4].iter() {
                row[p] = 1.0;
            }
        }
        assert_eq!(measure_key(&pcs).0, "A minor");
    }

    /// A real take, against mix.py's numbers for it. Masters aren't in the repository, so this
    /// says so and passes where the file is missing. compare/compare.py covers the rest.
    #[test]
    fn a_real_take_matches_the_python() {
        let home = std::env::var("HOME").unwrap_or_default();
        let path = std::path::PathBuf::from(home)
            .join(".cache/tillandsias-project/kumbia-audio/themes-20261106/lows-garden/mid.flac");
        if !path.exists() {
            eprintln!("skipped: no master at {}", path.display());
            return;
        }
        let mono = crate::audio::decode_mono(&path, RATE as u32);
        let fit = beat_times(&mono, 98.0);
        assert_eq!(round_to(fit.bpm, 3), 97.986);
        assert_eq!(round_to(fit.wander_ms, 2), 22.81);
    }
}
