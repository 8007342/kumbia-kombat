//! Measures for layered tiers, and how far a stretched tier's attacks sit from its mid.
//! Ported from tool/music/layer/measure.py and lag.py (deleted 2026-11-10); compare/layer_golden.sh holds
//! the Python's outputs on two rooms and checks these against them.
//!
//! Gates (fail): overall stereo correlation under +0.2, more than 10 % of half-second
//! windows anti-correlated, more than 4 clipped runs (3+ samples at |x| >= 0.999), or
//! any dropout (a 10 ms window 30 dB under its second). These numbers measure the
//! signal. They can't say whether it sounds good.

use crate::np::{arange, argmax, convolve_same, hanning, interp, py_round, round_to};
use realfft::RealFftPlanner;
use serde_json::{json, Value};
use std::io::Read;
use std::path::Path;
use std::process::{Command, Stdio};

const CORR_MIN: f64 = 0.2;
const NEG_MAX: f64 = 0.10;
const CLIP_MAX: i64 = 4;

/// The file at its own rate, as f64 frames, like soundfile's always_2d read.
/// A mono file is both channels, as measure.py repeated it.
pub fn decode_native(path: &Path) -> (Vec<[f64; 2]>, usize) {
    // A WAV stream from ffmpeg carries the rate in its header (the forge has no ffprobe).
    let mut child = Command::new("ffmpeg")
        .args(["-nostdin", "-v", "error", "-i"])
        .arg(path)
        .args(["-map_metadata", "-1", "-bitexact", "-ac", "2", "-c:a", "pcm_f64le", "-f", "wav", "-"])
        .stdout(Stdio::piped())
        .spawn()
        .expect("start ffmpeg");
    let mut bytes = Vec::new();
    child.stdout.take().expect("piped stdout").read_to_end(&mut bytes).expect("read ffmpeg");
    assert!(child.wait().expect("wait for ffmpeg").success(), "ffmpeg failed: {}", path.display());
    let u32_at = |i: usize| u32::from_le_bytes(bytes[i..i + 4].try_into().unwrap()) as usize;
    assert!(&bytes[..4] == b"RIFF" && &bytes[8..12] == b"WAVE", "not a wav stream: {}", path.display());
    let (mut at, mut sr) = (12, 0);
    let data = loop {
        let (id, size) = (&bytes[at..at + 4], u32_at(at + 4));
        if id == b"fmt " {
            sr = u32_at(at + 12);
        } else if id == b"data" {
            break &bytes[at + 8..]; // streamed, so the size field can't be trusted: read to the end
        }
        at += 8 + size + (size & 1);
    };
    assert!(sr > 0, "no fmt chunk: {}", path.display());
    let x = data
        .chunks_exact(16)
        .map(|b| [f64::from_le_bytes(b[..8].try_into().unwrap()), f64::from_le_bytes(b[8..].try_into().unwrap())])
        .collect();
    (x, sr)
}

fn db(v: f64) -> f64 {
    10f64.powf(v / 20.0)
}

/// Rising edges of a boolean run, as np.sum(np.diff(b.astype(int8)) == 1).
fn rises(b: &[bool]) -> i64 {
    b.windows(2).filter(|w| !w[0] && w[1]).count() as i64
}

/// Integrated LUFS and peak from ffmpeg's ebur128, read off the file itself.
fn lufs(path: &Path) -> (f64, f64) {
    let out = Command::new("ffmpeg")
        .args(["-hide_banner", "-nostats", "-i"])
        .arg(path)
        .args(["-af", "ebur128=peak=true", "-f", "null", "-"])
        .output()
        .expect("run ffmpeg ebur128");
    let text = String::from_utf8_lossy(&out.stderr);
    let val = |key: &str| -> f64 {
        let tail = text.rsplit(key).next().unwrap_or("");
        tail.split_whitespace().next().and_then(|w| w.parse().ok()).unwrap_or_else(|| panic!("no {key:?} in ebur128 output"))
    };
    (val(" I: "), val("Peak:"))
}

fn clip_runs(x: &[[f64; 2]]) -> i64 {
    let mut n = 0;
    for ch in 0..2 {
        let mut run = 0usize;
        for f in x.iter().chain(std::iter::once(&[0.0, 0.0])) {
            if f[ch].abs() >= 0.999 {
                run += 1;
            } else {
                n += (run >= 3) as i64;
                run = 0;
            }
        }
    }
    n
}

/// Informational only, not a gate: it counts thousands on clean takes. Sample steps far
/// above the neighbourhood: the second difference over 12x its 50 ms block median.
fn clicks(x: &[[f64; 2]], sr: usize) -> i64 {
    let k = (sr as f64 * 0.05) as usize | 1;
    let mut n = 0;
    for ch in 0..2 {
        let d: Vec<f64> = x.windows(3).map(|w| ((w[2][ch] - w[1][ch]) - (w[1][ch] - w[0][ch])).abs()).collect();
        let mut hot = Vec::with_capacity(d.len());
        for block in d.chunks_exact(k) {
            let mut s = block.to_vec();
            let (_, med, _) = s.select_nth_unstable_by(k / 2, f64::total_cmp);
            let thr = 12.0 * *med + 0.02;
            hot.extend(block.iter().map(|&v| v > thr));
        }
        n += rises(&hot);
    }
    n
}

/// 10 ms windows over 30 dB under the second around them, away from the ends.
fn dropouts(x: &[[f64; 2]], sr: usize) -> i64 {
    let w = sr / 100;
    let m: Vec<f64> = x.iter().map(|f| (f[0].abs() + f[1].abs()) / 2.0).collect();
    let rms: Vec<f64> = m.chunks_exact(w).map(|c| (c.iter().sum::<f64>() / w as f64).powi(2).sqrt()).collect();
    let ctx = convolve_same(&rms, &[0.01; 100]);
    let mut low: Vec<bool> = rms.iter().zip(&ctx).map(|(&r, &c)| r < c * db(-30.0) && c > db(-40.0)).collect();
    let len = low.len();
    for i in (0..100.min(len)).chain(len.saturating_sub(100)..len) {
        low[i] = false;
    }
    rises(&low)
}

/// Centroid, bass share and onset rate of the mono mix, from 4096-sample Hann frames, half overlapped.
fn spectrum_measures(m: &[f64], sr: usize) -> (f64, f64, f64) {
    let n = 4096;
    let win = hanning(n);
    let fft = RealFftPlanner::<f64>::new().plan_fft_forward(n);
    let bins = n / 2 + 1;
    let mut p = vec![0.0; bins];
    let mut prev: Option<Vec<f64>> = None;
    let mut flux = Vec::new();
    let mut buf = fft.make_input_vec();
    let mut out = fft.make_output_vec();
    let mut start = 0;
    while start + n <= m.len() {
        for i in 0..n {
            buf[i] = m[start + i] * win[i];
        }
        fft.process(&mut buf, &mut out).expect("fft");
        let mag: Vec<f64> = out.iter().map(|c| c.norm_sqr().sqrt()).collect();
        for (pi, c) in p.iter_mut().zip(&out) {
            *pi += c.norm_sqr();
        }
        if let Some(prev) = &prev {
            flux.push(mag.iter().zip(prev).map(|(a, b)| (a - b).max(0.0)).sum::<f64>());
        }
        prev = Some(mag);
        start += n / 2;
    }
    let f = |k: usize| k as f64 * sr as f64 / n as f64;
    let total: f64 = p.iter().sum();
    let centroid = p.iter().enumerate().map(|(k, v)| f(k) * v).sum::<f64>() / total;
    let bass: f64 = p.iter().enumerate().filter(|(k, _)| f(*k) < 150.0).map(|(_, v)| v).sum();
    let smooth = convolve_same(&flux, &[1.0 / 9.0; 9]);
    let flux: Vec<f64> = flux.iter().zip(&smooth).map(|(a, b)| a - b).collect();
    let mean = flux.iter().sum::<f64>() / flux.len() as f64;
    let std = (flux.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / flux.len() as f64).sqrt();
    let peaks = flux.windows(3).filter(|w| w[1] > w[0] && w[1] > w[2] && w[1] > std).count();
    (centroid, 10.0 * (bass / total).log10(), peaks as f64 / (m.len() as f64 / sr as f64))
}

pub fn measure(path: &Path) -> Value {
    let (x, sr) = decode_native(path);
    let (mut ll, mut rr, mut lr, mut dd, mut ss) = (0.0, 0.0, 0.0, 0.0, 0.0);
    for f in &x {
        let (l, r) = (f[0], f[1]);
        ll += l * l;
        rr += r * r;
        lr += l * r;
        dd += (l - r) * (l - r);
        ss += (l + r) * (l + r);
    }
    let corr = lr / ((ll * rr).sqrt() + 1e-12);
    let w = sr / 2;
    let (mut neg, mut tot) = (0usize, 0usize);
    let mut i = 0;
    while i + w < x.len() {
        let (mut aa, mut bb, mut ab) = (0.0, 0.0, 0.0);
        for f in &x[i..i + w] {
            aa += f[0] * f[0];
            bb += f[1] * f[1];
            ab += f[0] * f[1];
        }
        let e = (aa * bb).sqrt();
        if e >= 1e-6 {
            tot += 1;
            neg += (ab / e < 0.0) as usize;
        }
        i += w;
    }
    let m: Vec<f64> = x.iter().map(|f| (f[0] + f[1]) / 2.0).collect();
    let (centroid, bass_db, onsets) = spectrum_measures(&m, sr);
    let side = 10.0 * (dd / (ss + 1e-12)).log10();
    let (il, peak) = lufs(path);
    let neg_windows = round_to(neg as f64 / tot.max(1) as f64, 3);
    let clip = clip_runs(&x);
    let drops = dropouts(&x, sr);
    let mut fails = Vec::new();
    if corr < CORR_MIN {
        fails.push(format!("stereo correlation {corr:+.2} < {CORR_MIN:+.2}"));
    }
    if neg_windows > NEG_MAX {
        fails.push(format!("{:.0}% windows anti-correlated", neg_windows * 100.0));
    }
    if clip > CLIP_MAX {
        fails.push(format!("{clip} clipped runs"));
    }
    if drops > 0 {
        fails.push(format!("{drops} dropouts"));
    }
    json!({
        "file": path.to_string_lossy(), "seconds": round_to(x.len() as f64 / sr as f64, 2), "corr": round_to(corr, 3),
        "negWindows": neg_windows, "clipRuns": clip, "clicks": clicks(&x, sr), "dropouts": drops,
        "centroidHz": py_round(centroid), "bassDb": round_to(bass_db, 1), "sideDb": round_to(side, 1),
        "onsetsPerS": round_to(onsets, 2), "lufs": il, "peakDb": peak, "fails": fails,
    })
}

/// Onset flux at 1 kHz (scipy.signal.stft's defaults: periodic Hann, 1024 long, zero
/// boundary, padded, scaled by the window's sum), resampled onto mid's clock.
fn lag_envelope(path: &Path, ratio: f64, pad: f64) -> Vec<f64> {
    let (x, sr) = decode_native(path);
    let hop = sr / 1000;
    let n = 1024;
    let half = n / 2;
    let mut m = vec![0.0; half];
    m.extend(x.iter().map(|f| (f[0] + f[1]) / 2.0));
    m.extend(std::iter::repeat(0.0).take(half));
    let extra = ((hop - (m.len() - n) % hop) % hop) % n;
    m.extend(std::iter::repeat(0.0).take(extra));
    let frames = (m.len() - n) / hop + 1;
    let win: Vec<f64> = (0..n).map(|i| 0.5 - 0.5 * (2.0 * std::f64::consts::PI * i as f64 / n as f64).cos()).collect();
    let scale = 1.0 / win.iter().sum::<f64>();
    let fft = RealFftPlanner::<f64>::new().plan_fft_forward(n);
    let mut buf = fft.make_input_vec();
    let mut out = fft.make_output_vec();
    let mut prev: Option<Vec<f64>> = None;
    let mut flux = Vec::with_capacity(frames);
    for k in 0..frames {
        let s = &m[k * hop..k * hop + n];
        for i in 0..n {
            buf[i] = s[i] * win[i];
        }
        fft.process(&mut buf, &mut out).expect("fft");
        let lg: Vec<f64> = out.iter().map(|c| (100.0 * c.norm() * scale).ln_1p()).collect();
        if let Some(prev) = &prev {
            flux.push(lg.iter().zip(prev).map(|(a, b)| (a - b).max(0.0)).sum::<f64>());
        }
        prev = Some(lg);
    }
    let t: Vec<f64> = (0..flux.len()).map(|i| pad + (i as f64 / 1000.0 - pad) / ratio).collect();
    arange(0.0, t[t.len() - 1], 0.001).iter().map(|&g| interp(g, &t, &flux)).collect()
}

/// The lag in ms of STRETCHED against MID over the middle 70 % of the take: positive is late.
pub fn lag(mid: &Path, stretched: &Path, ratio: f64, pad: f64) -> Value {
    let a = lag_envelope(mid, 1.0, pad);
    let b = lag_envelope(stretched, ratio, pad);
    let n = a.len().min(b.len());
    let (lo, hi) = ((n as f64 * 0.15) as usize, (n as f64 * 0.85) as usize);
    let reach = 40i64;
    let scores: Vec<f64> = (-reach..=reach)
        .map(|k| (lo..hi).map(|i| a[i] * b[(i as i64 + k) as usize]).sum())
        .collect();
    json!(argmax(&scores) as i64 - reach)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clip_runs_count_three_or_more() {
        let mut x = vec![[0.0, 0.0]; 20];
        for i in 2..5 {
            x[i][0] = 1.0; // a run of three: counted
        }
        for i in 8..10 {
            x[i][1] = -1.0; // two: not
        }
        for i in 17..20 {
            x[i][1] = 1.0; // three at the end: counted
        }
        assert_eq!(clip_runs(&x), 2);
    }

    #[test]
    fn rises_skip_a_leading_high() {
        assert_eq!(rises(&[true, false, true, true, false, true]), 2);
    }
}
