//! The measures verify takes from encoded files: everything except the pass and fail rules,
//! which stay in mix.py.

use crate::analysis::*;
use crate::audio;
use crate::np::*;
use crate::render::{beat_samples, circ, mid};
use crate::{RATE, SR};
use rayon::prelude::*;
use serde_json::{json, Value};
use std::path::Path;

/// mono, resampled by straight interpolation, as mix.py's decode_mono_from.
pub fn to_rate_mono(stereo: &[[f32; 2]]) -> Vec<f32> {
    let n = stereo.len();
    let count = (n as f64 * RATE as f64 / SR as f64) as usize;
    let mut out = vec![0f32; count];
    out.par_chunks_mut(1 << 14).enumerate().for_each(|(batch, part)| {
        for (j, slot) in part.iter_mut().enumerate() {
            let i = batch * (1 << 14) + j;
            let x = i as f64 * SR as f64 / RATE as f64;
            let at = x.floor() as usize;
            if at + 1 >= n {
                *slot = mid(&stereo[n - 1]) as f32;
            } else {
                let f = x - at as f64;
                let (a, b) = (mid(&stereo[at]), mid(&stereo[at + 1]));
                *slot = (a + (b - a) * f) as f32;
            }
        }
    });
    out
}

fn power(part: &[[f32; 2]]) -> f64 {
    let sum: f64 = part.iter().map(|f| (f[0] as f64).powi(2) + (f[1] as f64).powi(2)).sum();
    sum / (2 * part.len()) as f64
}

fn bar_level_jumps(lp: &[[f32; 2]], bars: usize) -> Vec<f64> {
    let size = (lp.len() as f64 / bars as f64 / 4.0) as usize;
    (0..bars)
        .map(|b| {
            let at = py_round((b * lp.len()) as f64 / bars as f64);
            let before = power(&circ(lp, at - size as i64, size));
            let after = power(&circ(lp, at, size));
            10.0 * (after.max(1e-12) / before.max(1e-12)).log10()
        })
        .collect()
}

fn top_end(part: &[[f32; 2]]) -> f64 {
    let mut sum = 0.0;
    let mut n = 0usize;
    for w in part.windows(3) {
        for ch in 0..2 {
            let d = w[2][ch] as f64 - 2.0 * w[1][ch] as f64 + w[0][ch] as f64;
            sum += d * d;
            n += 1;
        }
    }
    (sum / n as f64).sqrt()
}

fn frame_step(a: &[f32; 2], b: &[f32; 2]) -> f64 {
    (b[0] as f64 - a[0] as f64).abs().max((b[1] as f64 - a[1] as f64).abs())
}

fn seam_numbers(audio: &[[f32; 2]], start: usize, end: usize, bars: usize) -> Value {
    let n = 2400;
    let mut joined = audio[end - n..end].to_vec();
    joined.extend_from_slice(&audio[start..start + n]);
    let steps: Vec<f64> = joined.windows(2).map(|w| frame_step(&w[0], &w[1])).collect();
    let others: Vec<f64> = steps.iter().enumerate().filter(|(i, _)| *i != n - 1).map(|(_, v)| *v).collect();
    let typical = percentile(&others, 99.9);
    let lp = &audio[start..end];
    let jumps: Vec<f64> = bar_level_jumps(lp, bars).iter().map(|v| v.abs()).collect();
    let step = frame_step(&audio[start], &audio[end - 1]);
    let loop_steps: Vec<f64> = lp.windows(2).map(|w| frame_step(&w[0], &w[1])).collect();
    let w = 48;
    let mut around = audio[end - w..end].to_vec();
    around.extend_from_slice(&audio[start..start + w]);
    let looped = top_end(&around);
    let straight = top_end(&audio[end - w..end + w]);
    let above = loop_steps.iter().filter(|s| **s > step).count() as f64 / loop_steps.len() as f64 * 100.0;
    let top = loop_steps.iter().cloned().fold(0.0, f64::max);
    json!({
        "stepRatio": round_to(steps[n - 1] / typical.max(1e-9), 2),
        "wrapJumpDb": round_to(jumps[0], 2),
        "otherBarsP90JumpDb": round_to(percentile(&jumps[1..], 90.0), 2),
        "step": round_to(step, 4),
        "stepStraightThrough": round_to(frame_step(&audio[end], &audio[end - 1]), 4),
        "headMismatch": round_to(frame_step(&audio[start], &audio[end]), 4),
        "loopMaxStep": round_to(top, 4),
        "shareOfLoopStepsAbovePct": round_to(above, 3),
        "burstDb": round_to(20.0 * (looped.max(1e-9) / straight.max(1e-9)).log10(), 2),
    })
}

fn wrap_residual(audio: &[[f32; 2]], start: usize, end: usize) -> f64 {
    let n = py_round(0.1 * SR as f64) as usize;
    let (a, b) = (&audio[start..start + n], &audio[end..end + n]);
    let diff: f64 = a.iter().zip(b).map(|(x, y)| (x[0] as f64 - y[0] as f64).powi(2) + (x[1] as f64 - y[1] as f64).powi(2)).sum::<f64>() / (2 * n) as f64;
    round_to(10.0 * (diff.max(1e-14) / power(a).max(1e-14)).log10(), 1)
}

pub fn verify_take(file: &Path, bpm: f64, bars: usize, start: usize, end: usize) -> Value {
    let audio = audio::decode_stereo(file);
    let lp = &audio[start..end];
    let level = audio::loudness(&[lp, lp]);
    let mono = to_rate_mono(lp);
    let env = onset_envelope(&mono);
    let (ends, worst) = pattern_drift(&mono, bpm);
    let seconds = lp.len() as f64 / SR as f64;
    let expected = (bars * 4) as f64 * 60.0 / bpm;
    json!({
        "lufs": level.lufs, "truePeakDb": level.true_peak_db,
        "driftEndsMs": ends, "driftWorstMs": worst,
        "pulseBpm": round_to(fit_tempo(&env, bpm, 1.0), 3),
        "wanderMs": round_to(phase_wander_ms(&env, bpm), 2),
        "seam": seam_numbers(&audio, start, end, bars),
        "wrapResidualDb": wrap_residual(&audio, start, end),
        "decodedSamples": audio.len(),
        "lengthErrorMs": round_to((seconds - expected) * 1000.0, 3),
    })
}

pub fn verify_segment(file: &Path, bpm: f64, start: usize, end: usize) -> Value {
    let audio = audio::decode_stereo(file);
    let body = &audio[start..end];
    let peak = audio::loudness(&[&audio, &audio]).true_peak_db;
    let size = beat_samples(bpm);
    let beats = py_round(body.len() as f64 / size);
    let rms: Vec<f64> = (0..beats)
        .map(|i| {
            let a = (i as f64 * size) as usize;
            let z = (((i + 1) as f64 * size) as usize).min(body.len());
            round_to(10.0 * power(&body[a..z]).max(1e-12).log10(), 1)
        })
        .collect();
    json!({"truePeakDb": peak, "seconds": round_to(body.len() as f64 / SR as f64, 4), "beatRmsDb": rms})
}
