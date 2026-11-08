//! Warping, limiting, separation and the joins. Samples stay f32; sums and gains are f64.

use crate::analysis::V12;
use crate::audio;
use crate::np::*;
use crate::{Stereo, SR};
use rayon::prelude::*;
use realfft::RealFftPlanner;
use std::f64::consts::PI;

pub fn mid(f: &[f32; 2]) -> f64 {
    0.5 * (f[0] as f64 + f[1] as f64)
}

/// Waveform-similarity overlap-add; see mix.py's wsola. `in_at` maps output positions to
/// input positions. The input's padding is implied rather than copied, and frame energies
/// are summed where they're asked for instead of from a running total of the whole take.
pub fn wsola(audio: &[[f32; 2]], in_at: impl Fn(f64) -> f64, out_len: usize) -> (Stereo, usize) {
    let (frame, drift) = (1920usize, 192usize);
    let hop = frame / 2;
    let edge = frame + 2 * drift + hop;
    let total = audio.len() + 2 * edge;
    let at = |i: usize| -> [f32; 2] {
        if i >= edge && i < edge + audio.len() { audio[i - edge] } else { [0.0, 0.0] }
    };
    let window: Vec<f64> = (0..frame).map(|n| 0.5 - 0.5 * (2.0 * PI * n as f64 / frame as f64).cos()).collect();
    let mut out = vec![[0f32; 2]; out_len + 2 * frame];
    let size = 2 * drift + frame;
    let mut splices = 0;
    let mut prev: Option<usize> = None;
    let last = total - size - 1;
    let sum_sq = |a: usize, b: usize| -> f64 {
        (a..b).map(|i| { let m = mid(&at(i)); m * m }).sum()
    };
    let mut o = 0;
    while o < out_len + hop {
        let want = (py_round(in_at(o as f64)) + edge as i64).clamp(drift as i64, last as i64) as usize;
        let mut chosen = want;
        if let Some(p) = prev {
            let natural = (p + hop).min(last);
            let middle = natural + hop;
            let attack = sum_sq(middle, natural + frame) > 2.0 * sum_sq(natural.saturating_sub(hop), middle);
            let allowed = if attack { drift * 3 / 2 } else { drift };
            if natural.abs_diff(want) <= allowed {
                chosen = natural;
            } else {
                let low = want - drift;
                let reference: Vec<f64> = (natural..natural + frame).map(|i| mid(&at(i))).collect();
                let ref_energy = dot(&reference, &reference);
                let seg: Vec<f64> = (low..low + size).map(|i| mid(&at(i))).collect();
                // Only the far side of the map: the near edge always correlates best, and
                // choosing it would splice again on the next frame.
                let far: Vec<usize> = if want > natural { (drift + 1..=2 * drift).collect() } else { (0..drift).collect() };
                let scores: Vec<f64> = far
                    .par_iter()
                    .map(|&k| {
                        let part = &seg[k..k + frame];
                        let xc = dot(part, &reference);
                        let e = dot(part, part);
                        xc / (e * ref_energy).max(1e-12).sqrt()
                    })
                    .collect();
                chosen = low + far[argmax(&scores)];
                splices += 1;
            }
        }
        for i in 0..frame {
            let f = at(chosen + i);
            let w = window[i];
            let slot = &mut out[o + i];
            slot[0] += (f[0] as f64 * w) as f32;
            slot[1] += (f[1] as f64 * w) as f32;
        }
        prev = Some(chosen);
        o += hop;
    }
    out.truncate(out_len);
    (out, splices)
}

pub fn stretch_linear(audio: &[[f32; 2]], out_len: usize) -> Stereo {
    let ratio = audio.len() as f64 / out_len.max(1) as f64;
    wsola(audio, |o| o * ratio, out_len).0
}

const EQ_FFT: usize = 1 << 16;

fn shelf_gain(freq_hz: f64, bands: &[(f64, f64, bool)]) -> f64 {
    let freq = freq_hz.max(1.0);
    let mut db = 0.0;
    for &(f0, g, high) in bands {
        let rise = 1.0 / (1.0 + (-4.0 * (freq / f0).log2()).exp());
        db += g * if high { rise } else { 1.0 - rise };
    }
    10f64.powf(db / 20.0)
}

/// mix.py's zero-phase shelves, by overlap-save over short blocks, wrapping round the take's
/// ends as its single whole-take FFT does. That FFT took over a gigabyte in Python and 700 MB
/// here, because a take's length is rarely a friendly FFT size. The shelf's response is
/// smooth, so its impulse fits a 1.4 s block; the unit test states how close this comes.
pub fn shelf_eq(audio: &mut Stereo, bands: &[(f64, f64, bool)]) {
    if bands.is_empty() || audio.is_empty() {
        return;
    }
    let n = audio.len();
    let size = EQ_FFT;
    let quarter = size / 4;
    let mut planner = RealFftPlanner::<f64>::new();
    let fwd = planner.plan_fft_forward(size);
    let inv = planner.plan_fft_inverse(size);
    let gain: Vec<f64> = (0..size / 2 + 1).map(|k| shelf_gain(k as f64 * SR as f64 / size as f64, bands)).collect();
    let mut out = vec![[0f32; 2]; n];
    let input: &[[f32; 2]] = audio;
    out.par_chunks_mut(size / 2).enumerate().for_each(|(block, part)| {
        let start = block * (size / 2);
        let mut buf = fwd.make_input_vec();
        let mut spec = fwd.make_output_vec();
        let mut scratch = fwd.make_scratch_vec();
        let mut back_scratch = inv.make_scratch_vec();
        for ch in 0..2 {
            for (k, slot) in buf.iter_mut().enumerate() {
                let at = (start + k + n * size - quarter) % n;
                *slot = input[at][ch] as f64;
            }
            fwd.process_with_scratch(&mut buf, &mut spec, &mut scratch).expect("fft");
            for (c, g) in spec.iter_mut().zip(&gain) {
                *c *= *g;
            }
            inv.process_with_scratch(&mut spec, &mut buf, &mut back_scratch).expect("ifft");
            for (j, f) in part.iter_mut().enumerate() {
                f[ch] = (buf[quarter + j] / size as f64) as f32;
            }
        }
    });
    *audio = out;
}

fn sliding_min(values: &[f64], half: usize, circular: bool) -> Vec<f64> {
    use std::collections::VecDeque;
    let n = values.len();
    let size = 2 * half + 1;
    let get = |i: usize| -> f64 {
        if i < half {
            if circular { values[n - half + i] } else { 1.0 }
        } else if i < half + n {
            values[i - half]
        } else if circular {
            values[i - half - n]
        } else {
            1.0
        }
    };
    let mut q: VecDeque<usize> = VecDeque::new();
    let mut out = Vec::with_capacity(n);
    for i in 0..n + 2 * half {
        let v = get(i);
        while q.back().is_some_and(|&b| get(b) >= v) {
            q.pop_back();
        }
        q.push_back(i);
        if i + 1 >= size {
            let start = i + 1 - size;
            while *q.front().expect("window not empty") < start {
                q.pop_front();
            }
            if start < n {
                out.push(get(*q.front().expect("window not empty")));
            }
        }
    }
    out
}

#[derive(Clone, Copy, Debug)]
pub struct LimitStats {
    pub max_reduction_db: f64,
    pub limited_share: f64,
}

/// A look-ahead peak limiter; see mix.py's limit.
pub fn limit(audio: Stereo, ceiling_db: f64, circular: bool) -> (Stereo, LimitStats) {
    let half_ms = 8.0;
    let ceiling = 10f64.powf(ceiling_db / 20.0);
    let peak = |f: &[f32; 2]| (f[0] as f64).abs().max((f[1] as f64).abs());
    let top = audio.iter().map(peak).fold(0.0, f64::max);
    if top <= ceiling {
        return (audio, LimitStats { max_reduction_db: 0.0, limited_share: 0.0 });
    }
    let half = (SR as f64 * half_ms / 1000.0) as usize;
    let need: Vec<f64> = audio.iter().map(|f| (ceiling / peak(f).max(1e-12)).min(1.0)).collect();
    let held = sliding_min(&need, half, circular);
    drop(need);
    let hann = hanning(2 * half + 3);
    let kernel: Vec<f64> = {
        let inner = &hann[1..hann.len() - 1];
        let sum: f64 = inner.iter().sum();
        inner.iter().map(|v| v / sum).collect()
    };
    let n = held.len();
    let get = |i: usize| -> f64 {
        if i < half {
            if circular { held[n - half + i] } else { 1.0 }
        } else if i < half + n {
            held[i - half]
        } else if circular {
            held[i - half - n]
        } else {
            1.0
        }
    };
    let mut gain = vec![0.0; n];
    gain.par_chunks_mut(8192).enumerate().for_each(|(batch, part)| {
        for (j, slot) in part.iter_mut().enumerate() {
            let i = batch * 8192 + j;
            let mut s = 0.0;
            for (k, w) in kernel.iter().enumerate() {
                s += get(i + 2 * half - k) * w;
            }
            *slot = s.min(held[i]);
        }
    });
    let out: Stereo = audio
        .iter()
        .zip(&gain)
        .map(|(f, g)| [(f[0] as f64 * g) as f32, (f[1] as f64 * g) as f32])
        .collect();
    let lowest = gain.iter().cloned().fold(f64::INFINITY, f64::min);
    let share = gain.iter().filter(|g| **g < 0.999).count() as f64 / n as f64;
    (out, LimitStats { max_reduction_db: round_to(-20.0 * lowest.log10(), 2), limited_share: round_to(share, 4) })
}

pub struct Mastered {
    pub out: Stereo,
    pub gain_db: f64,
    pub stats: LimitStats,
    pub level: audio::Level,
}

/// Gain to the target, measured through the limiter; a few rounds settle it.
pub fn master_loop(lp: &[[f32; 2]], target: f64, ceiling_db: f64) -> Mastered {
    let mut gain_db = target - audio::loudness(&[lp, lp]).lufs;
    let mut result = None;
    for _ in 0..5 {
        let (out, stats) = limit(audio::scale(lp, 10f64.powf(gain_db / 20.0)), ceiling_db, true);
        let level = audio::loudness(&[&out, &out]);
        let done = (level.lufs - target).abs() <= 0.05;
        let lufs = level.lufs;
        result = Some(Mastered { out, gain_db, stats, level });
        if done {
            break;
        }
        gain_db += target - lufs;
    }
    result.expect("at least one round")
}

const HPSS_BLOCK: usize = 10 * SR;

/// The harmonic part, a block at a time with one-second crossfades, as mix.py's hpss.
pub fn harmonic_part(input: &[[f32; 2]]) -> Stereo {
    if input.len() <= HPSS_BLOCK * 3 / 2 {
        return hpss_block(input).0.iter().map(|f| [f[0] as f32, f[1] as f32]).collect();
    }
    let overlap = SR;
    let n = input.len();
    let mut harmonic = vec![[0f32; 2]; n];
    let mut weight = vec![0f32; n];
    let mut start = 0;
    loop {
        let stop = (start + HPSS_BLOCK).min(n);
        let (part, _) = hpss_block(&input[start..stop]);
        let len = stop - start;
        for i in 0..len {
            let ramp = |k: usize| (k as f64 + 0.5) / overlap as f64;
            let mut shape = 1.0;
            if start > 0 && i < overlap {
                shape = ramp(i);
            }
            if stop < n && i >= len - overlap {
                shape = ramp(len - 1 - i);
            }
            harmonic[start + i][0] += (part[i][0] * shape) as f32;
            harmonic[start + i][1] += (part[i][1] * shape) as f32;
            weight[start + i] += shape as f32;
        }
        if stop == n {
            break;
        }
        start += HPSS_BLOCK - overlap;
    }
    for (h, w) in harmonic.iter_mut().zip(&weight) {
        let d = w.max(1e-9);
        h[0] /= d;
        h[1] /= d;
    }
    harmonic
}

/// Harmonic and percussive parts by median masks; they sum back to the input.
pub fn hpss(input: &[[f32; 2]]) -> (Vec<[f64; 2]>, Vec<[f64; 2]>) {
    if input.len() <= HPSS_BLOCK * 3 / 2 {
        return hpss_block(input);
    }
    let h = harmonic_part(input);
    let harmonic: Vec<[f64; 2]> = h.iter().map(|f| [f[0] as f64, f[1] as f64]).collect();
    let percussive = input.iter().zip(&harmonic).map(|(a, b)| [a[0] as f64 - b[0], a[1] as f64 - b[1]]).collect();
    (harmonic, percussive)
}

fn hpss_block(input: &[[f32; 2]]) -> (Vec<[f64; 2]>, Vec<[f64; 2]>) {
    let (nfft, hop, width) = (2048usize, 512usize, 17usize);
    let hann = hanning(nfft + 1);
    let window = &hann[..nfft];
    let total = input.len() + 2 * nfft;
    let count = (total - nfft) / hop + 1;
    let bins = nfft / 2 + 1;
    let mut planner = RealFftPlanner::<f64>::new();
    let fwd = planner.plan_fft_forward(nfft);
    let inv = planner.plan_fft_inverse(nfft);
    let sample = |i: usize, ch: usize| -> f64 {
        if i >= nfft && i < nfft + input.len() { input[i - nfft][ch] as f64 } else { 0.0 }
    };
    // Per frame, per channel: the spectrum; and the summed magnitude the masks read.
    let mut specs = vec![realfft::num_complex::Complex::<f64>::new(0.0, 0.0); count * bins * 2];
    let mut mag = vec![0.0f64; count * bins];
    specs.par_chunks_mut(bins * 2).zip(mag.par_chunks_mut(bins)).enumerate().for_each(|(i, (spec, m))| {
        let mut buf = fwd.make_input_vec();
        let mut scratch = fwd.make_scratch_vec();
        for ch in 0..2 {
            for k in 0..nfft {
                buf[k] = sample(i * hop + k, ch) * window[k];
            }
            let part = &mut spec[ch * bins..(ch + 1) * bins];
            fwd.process_with_scratch(&mut buf, part, &mut scratch).expect("fft");
            for k in 0..bins {
                m[k] += part[k].norm();
            }
        }
    });
    let half = width / 2;
    let mut mask = vec![0.0f64; count * bins];
    mask.par_chunks_mut(bins).enumerate().for_each(|(i, row)| {
        let mut held = [0.0f64; 17];
        for k in 0..bins {
            for (w, slot) in held.iter_mut().enumerate() {
                let t = (i + w).saturating_sub(half).min(count - 1);
                *slot = mag[t * bins + k];
            }
            let (_, t, _) = held.select_nth_unstable_by(half, f64::total_cmp);
            let along_time = *t;
            for (w, slot) in held.iter_mut().enumerate() {
                let f = (k + w).saturating_sub(half).min(bins - 1);
                *slot = mag[i * bins + f];
            }
            let (_, f, _) = held.select_nth_unstable_by(half, f64::total_cmp);
            let along_freq = *f;
            let (a, b) = (along_time * along_time, along_freq * along_freq);
            row[k] = a / (a + b).max(1e-12);
        }
    });
    drop(mag);
    let mut harmonic = vec![[0.0f64; 2]; total];
    let mut norm = vec![0.0f64; total];
    let mut buf = inv.make_output_vec();
    let mut spec = inv.make_input_vec();
    let mut scratch = inv.make_scratch_vec();
    for i in 0..count {
        for ch in 0..2 {
            let part = &specs[i * bins * 2 + ch * bins..i * bins * 2 + (ch + 1) * bins];
            for k in 0..bins {
                spec[k] = part[k] * mask[i * bins + k];
            }
            spec[0].im = 0.0;
            spec[bins - 1].im = 0.0;
            inv.process_with_scratch(&mut spec, &mut buf, &mut scratch).expect("ifft");
            let at = i * hop;
            for k in 0..nfft {
                harmonic[at + k][ch] += buf[k] / nfft as f64 * window[k];
            }
        }
        let at = i * hop;
        for k in 0..nfft {
            norm[at + k] += window[k] * window[k];
        }
    }
    let n = input.len();
    let mut h = vec![[0.0f64; 2]; n];
    let mut p = vec![[0.0f64; 2]; n];
    for i in 0..n {
        let d = norm[i + nfft].max(1e-6);
        for ch in 0..2 {
            h[i][ch] = harmonic[i + nfft][ch] / d;
            p[i][ch] = input[i][ch] as f64 - h[i][ch];
        }
    }
    (h, p)
}

/// A raised-cosine ramp from 0 to 1 between two beats, at one sample.
pub fn rise(i: usize, beat_len: f64, start: f64, end: f64) -> f64 {
    let x = ((i as f64 / beat_len - start) / (end - start).max(1e-9)).clamp(0.0, 1.0);
    0.5 - 0.5 * (PI * x).cos()
}

pub fn circ(lp: &[[f32; 2]], start: i64, count: usize) -> Stereo {
    let n = lp.len() as i64;
    (0..count as i64).map(|i| lp[(start + i).rem_euclid(n) as usize]).collect()
}

pub fn beat_samples(bpm: f64) -> f64 {
    60.0 * SR as f64 / bpm
}

pub struct Source<'a> {
    pub lp: &'a [[f32; 2]],
    pub bpm: f64,
    pub bar_len: f64,
    pub beat_len: f64,
}

/// The source's last loop bar and what follows it, stretched to the new tempo.
pub fn outgoing_at(s: &Source, bpm_out: f64, beats_out: f64, pad: usize) -> Stereo {
    let bar = py_round(s.bar_len) as i64;
    let in_pad = py_round(pad as f64 * s.bpm / bpm_out) + 1;
    let extra = py_round(s.beat_len * (beats_out - 4.0 + 1.0));
    let raw = circ(s.lp, s.lp.len() as i64 - bar - in_pad, (in_pad + bar + extra) as usize);
    let ratio = bpm_out / s.bpm;
    stretch_linear(&raw, py_round(raw.len() as f64 / ratio) as usize)
}

/// The even destination bar whose lead-in best matches the given chroma.
pub fn best_entry(source: &V12, dest: &[V12]) -> (i64, f64) {
    best_entry_on(source, dest, (2, 0))
}

/// The same, over bars `offset`, `offset + step`, ...: a bridge can land where the
/// next room's chart starts its calls on the music's phrase.
pub fn best_entry_on(source: &V12, dest: &[V12], (step, offset): (usize, usize)) -> (i64, f64) {
    let src = unit(source);
    let count = dest.len();
    let mut best: Option<(f64, i64)> = None;
    let mut k = offset % count;
    while k < count {
        let c = unit(&dest[(k + count - 1) % count]);
        let row = (dot(&c, &src), -(k as i64));
        if best.is_none_or(|b| row.0 > b.0 || (row.0 == b.0 && row.1 > b.1)) {
            best = Some(row);
        }
        k += step.max(1);
    }
    let b = best.expect("a destination with bars");
    (-b.1, round_to(b.0, 3))
}

fn fit_total(mut v: Stereo, total: usize) -> Stereo {
    v.resize(total, [0.0, 0.0]);
    v
}

fn to_f32(mix: &[[f64; 2]]) -> Stereo {
    mix.iter().map(|f| [f[0] as f32, f[1] as f32]).collect()
}

pub struct JoinCfg {
    pub beats: usize,
    pub width: f64,
    pub fill_db: f64,
    pub ceiling_db: f64,
    pub boost_db: f64,
}

pub struct JoinOut {
    pub mix: Stereo,
    pub entry: i64,
    pub match_score: f64,
    pub stats: LimitStats,
}

pub fn render_transition(src: &Source, src_chroma: &V12, dest: &Source, dest_chroma: &[V12], cfg: &JoinCfg, pad: usize) -> JoinOut {
    let beats = cfg.beats as f64;
    let width = cfg.width;
    let fill = 10f64.powf(cfg.fill_db / 20.0);
    let bpm = dest.bpm;
    let beat_len = beat_samples(bpm);
    let length = py_round(beats * beat_len) as usize;
    let total = pad + length + pad;
    let (entry, match_score) = best_entry(src_chroma, dest_chroma);
    let entry_at = py_round(entry as f64 * dest.bar_len);
    let incoming = circ(dest.lp, entry_at - length as i64 - pad as i64, total);
    let outgoing = fit_total(outgoing_at(src, bpm, beats, pad), total);
    let ((out_h, out_p), (in_h, in_p)) = rayon::join(|| hpss(&outgoing), || hpss(&incoming));
    let middle = beats / 2.0;
    let (lo, hi) = (middle - width / 2.0, middle + width / 2.0);
    let shift = pad as f64 / beat_len;
    let done = py_round((hi + 0.25) * beat_len) as usize + pad;
    let mut mix = vec![[0.0f64; 2]; total];
    for i in 0..total {
        if i >= done {
            mix[i] = [incoming[i][0] as f64, incoming[i][1] as f64];
            continue;
        }
        let ramp = |a: f64, b: f64| rise(i, beat_len, a + shift, b + shift);
        let keep_h = 1.0 - ramp(lo, middle);
        let keep_p = 1.0 - ramp(middle - width / 4.0, middle + width / 4.0);
        let enter_p = ramp(lo, middle);
        let enter_h = ramp(middle - width / 4.0, hi);
        let bump = 1.0 + (fill - 1.0) * (ramp(lo, middle) - ramp(middle, hi));
        for ch in 0..2 {
            mix[i][ch] = out_h[i][ch] * keep_h + out_p[i][ch] * keep_p + in_h[i][ch] * enter_h + in_p[i][ch] * enter_p * bump;
        }
    }
    let (mix, stats) = limit(to_f32(&mix), cfg.ceiling_db, false);
    JoinOut { mix, entry, match_score, stats }
}

pub fn render_bridge(src: &Source, src_chroma: &V12, dest: &Source, dest_chroma: &[V12], cfg: &JoinCfg, pad: usize, phase: (usize, usize)) -> JoinOut {
    let beats = 8.0;
    let bpm = dest.bpm;
    let beat_len = beat_samples(bpm);
    let length = py_round(beats * beat_len) as usize;
    let total = pad + length + pad;
    let (entry, match_score) = best_entry_on(src_chroma, dest_chroma, phase);
    let incoming = circ(dest.lp, py_round(entry as f64 * dest.bar_len) - length as i64 - pad as i64, total);
    let mut outgoing = outgoing_at(src, bpm, beats, pad);
    outgoing.resize(total, [0.0, 0.0]);
    let ((out_h, _), (in_h, in_p)) = rayon::join(|| hpss(&outgoing), || hpss(&incoming));
    let shift = pad as f64 / beat_len;
    let boost = 10f64.powf(cfg.boost_db / 20.0);
    let done = py_round(5.25 * beat_len) as usize + pad;
    let mut mix = vec![[0.0f64; 2]; total];
    for i in 0..total {
        if i >= done {
            mix[i] = [incoming[i][0] as f64, incoming[i][1] as f64];
            continue;
        }
        let ramp = |a: f64, b: f64| rise(i, beat_len, a + shift, b + shift);
        let hot = boost + (1.0 - boost) * ramp(2.0, 5.0);
        let (keep, enter_p, enter_h) = (1.0 - ramp(0.0, 3.0), ramp(-0.25, 0.0) * hot, ramp(1.0, 5.0));
        for ch in 0..2 {
            mix[i][ch] = out_h[i][ch] * keep + in_p[i][ch] * enter_p + in_h[i][ch] * enter_h;
        }
    }
    let (mix, stats) = limit(to_f32(&mix), cfg.ceiling_db, false);
    JoinOut { mix, entry, match_score, stats }
}

/// The run of bars ending nearest the tonic, loud enough, with a strong third bar in a finale.
pub fn choose_tag(all_chroma: &[V12], rms: &[f64], key: &str, bars: usize) -> (usize, f64) {
    let tonic = crate::analysis::tonic_template(key);
    let level = median(rms);
    let (mut best, mut start) = (-9.0, 0);
    for b in 0..rms.len().saturating_sub(bars) {
        let lowest = rms[b..b + bars].iter().cloned().fold(f64::INFINITY, f64::min);
        let mut score = dot(&unit(&all_chroma[b + bars - 1]), &tonic) + 0.5 * (lowest / level).min(1.0);
        if bars >= 4 {
            score += 0.5 * (rms[b + 2] / level).min(1.2);
        }
        if score > best {
            best = score;
            start = b;
        }
    }
    (start, round_to(best, 3))
}

pub fn render_success(window: &[[f32; 2]], beat_len: f64, bars: usize, is_final: bool, ceiling_db: f64, pad: usize) -> (Stereo, LimitStats) {
    let (harmonic, percussive) = hpss(window);
    let shift = pad as f64 / beat_len;
    let beats = (bars * 4) as f64;
    let mut mix = vec![[0.0f64; 2]; window.len()];
    for i in 0..window.len() {
        for ch in 0..2 {
            mix[i][ch] = if is_final {
                let settle = 1.0 - rise(i, beat_len, beats - 4.0 + shift, beats + shift);
                (harmonic[i][ch] + percussive[i][ch]) * settle
            } else {
                let thin = 1.0 - 0.5 * rise(i, beat_len, beats - 1.0 + shift, beats + shift);
                harmonic[i][ch] + percussive[i][ch] * thin
            };
        }
    }
    limit(to_f32(&mix), ceiling_db, false)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tone(hz: f64, n: usize, amp: f64) -> Stereo {
        (0..n).map(|i| {
            let v = (amp * (2.0 * PI * hz * i as f64 / SR as f64).sin()) as f32;
            [v, v]
        }).collect()
    }

    #[test]
    fn stretching_keeps_pitch_length_and_level() {
        let input = tone(440.0, SR * 4, 0.5);
        let want = (input.len() as f64 / 1.02) as usize;
        let out = stretch_linear(&input, want);
        assert_eq!(out.len(), want);
        let body = &out[SR / 2..out.len() - SR / 2];
        let rms = (body.iter().map(|f| (f[0] as f64).powi(2)).sum::<f64>() / body.len() as f64).sqrt();
        assert!((rms - 0.5 / 2f64.sqrt()).abs() < 0.03, "level moved to {rms}");
        let crossings = body.windows(2).filter(|p| p[0][0] < 0.0 && p[1][0] >= 0.0).count();
        let hz = crossings as f64 / (body.len() as f64 / SR as f64);
        assert!((hz - 440.0).abs() < 1.0, "pitch moved to {hz}");
    }

    /// Against the whole-take FFT mix.py uses: a length with a large prime factor, wrapped ends.
    #[test]
    fn block_eq_matches_a_whole_take_fft() {
        let n = 2 * 3 * 37 * 1201; // 266622 samples
        let mut state = 12345u64;
        let mut next = || {
            state = state.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            ((state >> 40) as f64 / (1u64 << 24) as f64 - 0.5) as f32
        };
        let input: Stereo = (0..n).map(|_| [next(), next()]).collect();
        let bands = [(1500.0, -3.0, true)];
        let mut fast = input.clone();
        shelf_eq(&mut fast, &bands);
        let mut planner = RealFftPlanner::<f64>::new();
        let (fwd, inv) = (planner.plan_fft_forward(n), planner.plan_fft_inverse(n));
        let mut x: Vec<f64> = input.iter().map(|f| f[0] as f64).collect();
        let mut spec = fwd.make_output_vec();
        fwd.process(&mut x, &mut spec).unwrap();
        for (k, c) in spec.iter_mut().enumerate() {
            *c *= shelf_gain(k as f64 * SR as f64 / n as f64, &bands);
        }
        inv.process(&mut spec, &mut x).unwrap();
        let (mut diff, mut power) = (0.0, 0.0);
        for (f, v) in fast.iter().zip(&x) {
            let exact = v / n as f64;
            diff += (f[0] as f64 - exact).powi(2);
            power += exact * exact;
        }
        let db = 10.0 * (diff / power).log10();
        assert!(db < -80.0, "block EQ is {db:.1} dB from the whole-take FFT");
        println!("block EQ residual {db:.1} dB");
    }

    #[test]
    fn running_minimum_matches_a_slow_one() {
        let values: Vec<f64> = (0..400).map(|i| 0.2 + 0.8 * ((i * 7919 % 397) as f64 / 397.0)).collect();
        for circular in [false, true] {
            let fast = sliding_min(&values, 5, circular);
            let n = values.len();
            let data: Vec<f64> = (0..n + 10).map(|i| {
                if i < 5 { if circular { values[n - 5 + i] } else { 1.0 } }
                else if i < 5 + n { values[i - 5] }
                else if circular { values[i - 5 - n] } else { 1.0 }
            }).collect();
            for i in 0..n {
                let slow = data[i..i + 11].iter().cloned().fold(f64::INFINITY, f64::min);
                assert_eq!(fast[i], slow);
            }
        }
    }

    #[test]
    fn the_limiter_holds_its_ceiling_and_leaves_quiet_audio_alone() {
        let loud: Stereo = (0..SR).map(|i| {
            let v = ((i * 7919 % 2003) as f32 / 2003.0 - 0.5) * 2.4;
            [v, -v]
        }).collect();
        let (limited, stats) = limit(loud.clone(), -1.5, true);
        let top = limited.iter().map(|f| f[0].abs().max(f[1].abs())).fold(0.0, f32::max) as f64;
        assert!(top <= 10f64.powf(-1.5 / 20.0) + 1e-6, "{top}");
        assert!(stats.max_reduction_db > 0.0);
        let quiet = audio::scale(&loud, 0.01);
        let (same, stats) = limit(quiet.clone(), -1.5, false);
        assert_eq!(stats.max_reduction_db, 0.0);
        assert_eq!(same, quiet);
    }

    #[test]
    fn separation_sums_back_to_its_input() {
        let input = tone(330.0, SR / 2, 0.4);
        let (h, p) = hpss(&input);
        for i in 0..input.len() {
            assert!((h[i][0] + p[i][0] - input[i][0] as f64).abs() < 1e-9);
        }
    }
}
