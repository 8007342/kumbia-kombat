//! Onset salience by band, on a beat grid: what `tool/music/align_charts.mjs` needs to say
//! whether a chart note lands on something the player can hear.
//!
//! One STFT pass over the take, a frame at a time. Each frame keeps five numbers (one log
//! spectral flux per band) and drops its spectrum, so a minute of audio costs a few MB.

use crate::np::*;
use crate::RATE;
use rayon::prelude::*;
use realfft::RealFftPlanner;
use serde_json::{json, Map, Value};

pub const SIZE: usize = 1024;
pub const STEP: usize = 128;
const BATCH: usize = 512;

/// Frequency bands in Hz. "pitch" is a chroma flux over 250 to 2000 Hz: a new note in the
/// melody or harmony, even one without a hard attack. "full" is the whole spectrum.
pub const BANDS: [&str; 5] = ["low", "mid", "high", "pitch", "full"];
const EDGES: [(f64, f64); 3] = [(30.0, 200.0), (200.0, 2000.0), (2000.0, 10000.0)];

pub struct Envelopes {
    /// bands[b][frame]: half-wave rectified flux, slow trend removed.
    pub bands: Vec<Vec<f64>>,
}

/// Where frame i's flux puts an attack. The flux between frames i - 1 and i peaks before the
/// attack reaches the window's centre; `clicks_land_on_their_grid` measured 19 ms early on
/// decaying noise clicks, so that is added back. Slower attacks, such as a bowed or blown
/// note, will still read somewhat late.
pub const CAL_SECONDS: f64 = 0.019;
pub fn frame_time(i: f64) -> f64 {
    ((i - 0.5) * STEP as f64 + (SIZE / 2) as f64) / RATE as f64 + CAL_SECONDS
}

pub fn envelopes(mono: &[f32]) -> Envelopes {
    let count = mono.len().saturating_sub(SIZE) / STEP;
    assert!(count >= 2, "take is too short to measure");
    let window = hanning(SIZE);
    let fft = RealFftPlanner::<f64>::new().plan_fft_forward(SIZE);
    let bins = SIZE / 2 + 1;
    let hz = RATE as f64 / SIZE as f64;
    let band_of: Vec<i32> = (0..bins)
        .map(|k| {
            let f = k as f64 * hz;
            EDGES.iter().position(|(a, b)| f >= *a && f < *b).map(|v| v as i32).unwrap_or(-1)
        })
        .collect();
    let pc: Vec<i32> = (0..bins)
        .map(|k| {
            let f = k as f64 * hz;
            if (250.0..=2000.0).contains(&f) {
                (12.0 * (f / 261.626).log2()).round_ties_even().rem_euclid(12.0) as i32
            } else {
                -1
            }
        })
        .collect();
    let mut raw = vec![[0f64; 5]; count];
    raw.par_chunks_mut(BATCH).enumerate().for_each(|(batch, part)| {
        let mut input = fft.make_input_vec();
        let mut output = fft.make_output_vec();
        let mut scratch = fft.make_scratch_vec();
        let mut prev = vec![0.0; bins];
        let mut spec = vec![0.0; bins];
        let mut prev_chroma = [0.0f64; 12];
        let mut chroma = [0.0f64; 12];
        let mut measure = |i: usize, into: &mut [f64], chroma: &mut [f64; 12]| {
            let frame = &mono[i * STEP..i * STEP + SIZE];
            for k in 0..SIZE {
                input[k] = frame[k] as f64 * window[k];
            }
            fft.process_with_scratch(&mut input, &mut output, &mut scratch).expect("fft");
            *chroma = [0.0; 12];
            for (k, c) in output.iter().enumerate() {
                into[k] = (100.0 * c.norm()).ln_1p();
                if pc[k] >= 0 {
                    chroma[pc[k] as usize] += c.norm_sqr();
                }
            }
            for v in chroma.iter_mut() {
                *v = (1000.0 * *v).ln_1p();
            }
        };
        let first = batch * BATCH;
        if first > 0 {
            measure(first - 1, &mut prev, &mut prev_chroma);
        }
        for (j, slot) in part.iter_mut().enumerate() {
            let i = first + j;
            measure(i, &mut spec, &mut chroma);
            if i > 0 {
                for k in 0..bins {
                    let d = (spec[k] - prev[k]).max(0.0);
                    if band_of[k] >= 0 {
                        slot[band_of[k] as usize] += d;
                    }
                    slot[4] += d;
                }
                slot[3] = chroma.iter().zip(&prev_chroma).map(|(a, b)| (a - b).max(0.0)).sum();
            }
            std::mem::swap(&mut spec, &mut prev);
            std::mem::swap(&mut chroma, &mut prev_chroma);
        }
    });
    let size = (RATE as f64 / STEP as f64) as usize;
    let boxcar = vec![1.0 / size as f64; size];
    let bands = (0..5)
        .map(|b| {
            let env: Vec<f64> = raw.iter().map(|r| r[b]).collect();
            let trend = convolve_same(&env, &boxcar);
            env.iter().zip(&trend).map(|(e, t)| (e - t).max(0.0)).collect()
        })
        .collect();
    Envelopes { bands }
}

/// The strongest flux within `reach` seconds of t, and where it is relative to t.
fn peak_near(env: &[f64], t: f64, reach: f64) -> (f64, f64) {
    let index = |s: f64| ((s - CAL_SECONDS) * RATE as f64 - (SIZE / 2) as f64) / STEP as f64 + 0.5;
    let lo = index(t - reach).floor().max(0.0) as usize;
    let hi = ((index(t + reach).ceil() as usize) + 1).min(env.len());
    let (mut best, mut at) = (0.0, None);
    for i in lo..hi {
        if (frame_time(i as f64) - t).abs() <= reach && env[i] > best {
            best = env[i];
            at = Some(i);
        }
    }
    let Some(i) = at else { return (0.0, 0.0) };
    // Parabolic interpolation between neighbouring frames, for a lag finer than a step.
    let mut x = i as f64;
    if i > 0 && i + 1 < env.len() {
        let (a, b, c) = (env[i - 1], env[i], env[i + 1]);
        let d = a - 2.0 * b + c;
        if d < 0.0 {
            x += (0.5 * (a - c) / d).clamp(-0.5, 0.5);
        }
    }
    (best, frame_time(x) - t)
}

/// Salience and lag on a grid of `div` points per beat, for `beats` beats from `start`.
/// Salience is in units of the band's mean peak at sixteenth positions over the same span,
/// so 1.0 is a typical sixteenth and 0 is silence.
pub fn salience(mono: &[f32], bpm: f64, start: f64, beats: usize, div: usize, reach_ms: f64) -> Value {
    let env = envelopes(mono);
    let spb = 60.0 / bpm;
    let reach = reach_ms / 1000.0;
    let points = beats * div;
    let mut sal = Map::new();
    let mut lag = Map::new();
    let mut norms = Map::new();
    for (b, name) in BANDS.iter().enumerate() {
        let e = &env.bands[b];
        let sixteenth = (0..beats * 4).map(|g| peak_near(e, start + g as f64 * spb / 4.0, reach.min(spb / 8.0)).0).collect::<Vec<_>>();
        let norm = mean(&sixteenth).max(1e-9);
        let (mut s, mut l) = (Vec::with_capacity(points), Vec::with_capacity(points));
        for g in 0..points {
            let (v, d) = peak_near(e, start + g as f64 * spb / div as f64, reach);
            s.push(json!(round_to(v / norm, 3)));
            l.push(json!(round_to(d * 1000.0, 1)));
        }
        sal.insert(name.to_string(), Value::Array(s));
        lag.insert(name.to_string(), Value::Array(l));
        norms.insert(name.to_string(), json!(norm));
    }
    // Per bar: loudness and a 12-bin chroma, for the phrase-structure checks.
    let per_bar = (4.0 * spb * RATE as f64) as usize;
    let first = (start * RATE as f64) as usize;
    let bars = beats / 4;
    let mut bar_db = Vec::with_capacity(bars);
    for k in 0..bars {
        let a = (first + k * per_bar).min(mono.len());
        let z = (a + per_bar).min(mono.len());
        let ms = mono[a..z].iter().map(|v| (*v as f64) * (*v as f64)).sum::<f64>() / (z - a).max(1) as f64;
        bar_db.push(json!(round_to(10.0 * ms.max(1e-12).log10(), 2)));
    }
    let feats = crate::analysis::beat_features(&mono[first.min(mono.len())..], spb, beats.min(((mono.len() - first.min(mono.len())) as f64 / (spb * RATE as f64)) as usize).saturating_sub(1));
    let mut bar_chroma = Vec::with_capacity(bars);
    for k in 0..bars {
        let mut c = [0.0f64; 12];
        for b in k * 4..(k * 4 + 4).min(feats.chroma.len()) {
            for i in 0..12 {
                c[i] += feats.chroma[b][i];
            }
        }
        let total: f64 = c.iter().sum::<f64>().max(1e-12);
        bar_chroma.push(json!(c.iter().map(|v| round_to(v / total, 4)).collect::<Vec<_>>()));
    }
    json!({
        "bpm": bpm, "start": start, "beats": beats, "div": div, "reachMs": reach_ms,
        "stepMs": STEP as f64 * 1000.0 / RATE as f64,
        "bands": BANDS, "norm": norms, "salience": sal, "lagMs": lag,
        "barDb": bar_db, "barChroma": bar_chroma,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Clicks of filtered noise at known times: the measured lag should be near zero, and an
    /// off-grid point should read as weaker than an on-grid one.
    #[test]
    fn clicks_land_on_their_grid() {
        let bpm = 120.0;
        let spb = 0.5;
        let n = (RATE as f64 * 12.0) as usize;
        let mut mono = vec![0f32; n];
        let mut seed: u32 = 1;
        for beat in 0..22 {
            let at = ((0.25 + beat as f64 * spb) * RATE as f64) as usize;
            for k in 0..600 {
                seed = seed.wrapping_mul(1664525).wrapping_add(1013904223);
                let noise = (seed >> 9) as f32 / (1u32 << 23) as f32 - 0.5;
                mono[at + k] += noise * (-(k as f32) / 120.0).exp();
            }
        }
        let out = salience(&mono, bpm, 0.25, 20, 4, 60.0);
        let full = out["salience"]["full"].as_array().unwrap();
        let lags = out["lagMs"]["full"].as_array().unwrap();
        for b in 1..19 {
            let on = full[b * 4].as_f64().unwrap();
            let off = full[b * 4 + 2].as_f64().unwrap();
            assert!(on > 2.0 * off.max(0.01), "beat {b}: {on} vs {off}");
            let lag = lags[b * 4].as_f64().unwrap();
            assert!(lag.abs() <= 5.0, "beat {b} lag {lag} ms");
        }
    }
}
