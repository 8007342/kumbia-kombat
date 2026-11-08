//! One tier, master to mastered loop, on disk as it goes, so a level holds one tier at a time.

use crate::analysis::*;
use crate::audio;
use crate::np::*;
use crate::render::*;
use crate::verify::to_rate_mono;
use crate::{Stereo, RATE, SR};
use serde_json::{json, Value};
use std::path::Path;

const MAX_DECODED_PEAK_DB: f64 = -0.3;

pub fn encode_cfg(cfg: &Value) -> audio::Encode {
    audio::Encode {
        opus_kbps: cfg["encode"]["opusKbps"].as_i64().expect("opusKbps"),
        aac_kbps: cfg["encode"]["aacKbps"].as_i64().expect("aacKbps"),
    }
}

pub fn pad_samples(cfg: &Value) -> usize {
    py_round(cfg["padSeconds"].as_f64().expect("padSeconds") * SR as f64) as usize
}

fn rows(values: &[V12]) -> Value {
    Value::Array(values.iter().map(|r| json!(r.to_vec())).collect())
}

pub fn parse_rows(v: &Value) -> Vec<V12> {
    v.as_array()
        .expect("rows")
        .iter()
        .map(|r| {
            let mut out = [0.0; 12];
            for (k, x) in r.as_array().expect("row").iter().enumerate() {
                out[k] = x.as_f64().expect("number");
            }
            out
        })
        .collect()
}

pub fn floats(v: &Value) -> Vec<f64> {
    v.as_array().expect("numbers").iter().map(|x| x.as_f64().expect("number")).collect()
}

fn sum_rows(part: &[V12]) -> V12 {
    let mut out = [0.0; 12];
    for r in part {
        for k in 0..12 {
            out[k] += r[k];
        }
    }
    out
}

fn mean_rows(part: &[V12]) -> V12 {
    let mut out = sum_rows(part);
    for v in out.iter_mut() {
        *v /= part.len() as f64;
    }
    out
}

fn grid_pair(t: (f64, f64)) -> Value {
    json!({"typical": t.0, "worstBlock": t.1})
}

/// Master to grid to chosen loop, mastered. Writes loop.f32, grid.f32 and tier.json in `out`.
pub fn prepare(job: &Value, out: &Path) -> Value {
    let (cfg, level, tier) = (&job["cfg"], &job["level"], &job["tier"]);
    let follow = job.get("follow").filter(|f| !f.is_null());
    std::fs::create_dir_all(out).expect("make tier directory");
    let masters = cfg["mastersDir"].as_str().expect("mastersDir");
    let source = tier["source"].as_str().expect("source");
    let path = Path::new(masters).join(source);
    let name = tier["name"].as_str().expect("name");
    let lid = level["id"].as_str().expect("id");
    let mut audio_in = audio::decode_stereo(&path);
    // Another take of the same performance, sample-aligned, added before warping.
    if let Some(extras) = tier["layer"].as_array() {
        for extra in extras {
            let other_path = Path::new(masters).join(extra["source"].as_str().expect("layer source"));
            let mut other = audio::decode_stereo(&other_path);
            other.truncate(audio_in.len());
            let harmonic = harmonic_part(&other);
            let percussive = extra["part"] == "percussive";
            let gain = 10f64.powf(extra["db"].as_f64().unwrap_or(0.0) / 20.0);
            for i in 0..other.len() {
                for ch in 0..2 {
                    let part = if percussive { other[i][ch] as f64 - harmonic[i][ch] as f64 } else { harmonic[i][ch] as f64 };
                    audio_in[i][ch] = (audio_in[i][ch] as f64 + part * gain) as f32;
                }
            }
        }
    }
    let mono = audio::decode_mono(&path, RATE as u32);
    let target = tier["bpm"].as_f64().expect("bpm");
    let fit = beat_times(&mono, target);
    let (mut beats, mut measured) = (fit.beats, fit.bpm);
    let error_pct = (measured - target) / target * 100.0;
    let mut report = serde_json::Map::new();
    report.insert("source".into(), json!(source));
    report.insert("targetBpm".into(), json!(target));
    report.insert("measuredBpm".into(), json!(round_to(measured, 3)));
    report.insert("errorPct".into(), json!(round_to(error_pct, 3)));
    report.insert("wanderMs".into(), json!(round_to(fit.wander_ms, 2)));
    let timing = path.with_extension("timing.json");
    if let Ok(text) = std::fs::read_to_string(&timing) {
        let parsed: Value = serde_json::from_str(&text).expect("timing json");
        let file = path.file_name().expect("file name").to_string_lossy().to_string();
        report.insert("timingFileBpm".into(), parsed[&file]["measured_bpm"].clone());
    }
    let max_pct = cfg["maxCorrectionPct"].as_f64().expect("maxCorrectionPct");
    let corrected = error_pct.abs() <= max_pct;
    report.insert("corrected".into(), json!(corrected));
    if let Some(f) = follow {
        report.insert("followsGridOf".into(), f["name"].clone());
        beats = floats(&f["beats"]);
        measured = f["measured"].as_f64().expect("measured");
    } else if !corrected {
        eprintln!("{lid}/{name}: {error_pct:+.2}% is past the {max_pct}% allowed, not corrected");
        std::process::exit(3);
    }

    let beat_len = beat_samples(target);
    let out_len = py_round(beats.len() as f64 * beat_len) as usize;
    let out_beats: Vec<f64> = (0..beats.len()).map(|i| i as f64 * beat_len).collect();
    let in_beats: Vec<f64> = beats.iter().map(|b| b * SR as f64).collect();
    let rates: Vec<f64> = in_beats.windows(2).map(|w| (w[1] - w[0]) / beat_len).collect();
    let worst_rate = rates.iter().fold(0.0f64, |m, r| m.max((r - 1.0).abs()));
    report.insert("maxLocalStretchPct".into(), json!(round_to(worst_rate * 100.0, 2)));
    let slope = rates[rates.len() - 1];
    let last_out = out_beats[out_beats.len() - 1];
    let last_in = in_beats[in_beats.len() - 1];
    let (mut grid, splices) = wsola(
        &audio_in,
        |o| if o <= last_out { interp(o, &out_beats, &in_beats) } else { last_in + (o - last_out) * slope },
        out_len,
    );
    drop(audio_in);
    report.insert("splices".into(), json!(splices));
    let eq: Vec<(f64, f64, bool)> = tier["eq"]
        .as_array()
        .map(|bands| {
            bands.iter().map(|b| (b["freq"].as_f64().expect("freq"), b["gain"].as_f64().expect("gain"), b["type"] == "highshelf")).collect()
        })
        .unwrap_or_default();
    shelf_eq(&mut grid, &eq);

    let grid_mono = to_rate_mono(&grid);
    let env = onset_envelope(&grid_mono);
    let after = fit_tempo(&env, target, 1.0);
    report.insert("bpmAfterWarp".into(), json!(round_to(after, 3)));
    report.insert("wanderAfterMs".into(), json!(round_to(phase_wander_ms(&env, target), 2)));
    drop(env);
    let (mono_rise, mono_step) = attack_curve(&mono);
    drop(mono);
    let straight: Vec<f64> = (0..beats.len()).map(|i| beats[0] + i as f64 * 60.0 / measured).collect();
    report.insert("gridErrorBeforeMs".into(), grid_pair(grid_error_ms(&mono_rise, mono_step, &straight)));
    drop(mono_rise);
    let beat_seconds = beat_len / SR as f64;
    let exact: Vec<f64> = (0..beats.len()).map(|i| i as f64 * beat_seconds).collect();
    let (rise_curve, step) = attack_curve(&grid_mono);
    let exact_beat_len: Vec<f64> = (0..beats.len()).map(|i| i as f64 * beat_len / SR as f64).collect();
    report.insert("gridErrorAfterMs".into(), grid_pair(grid_error_ms(&rise_curve, step, &exact_beat_len)));

    let feats = beat_features(&grid_mono, beat_seconds, beats.len());
    drop(grid_mono);
    let (mut first, mut confidence, mut margin) = find_bar_one(&feats.chroma, &feats.attack);
    if let Some(f) = follow {
        first = f["first"].as_u64().expect("first") as usize;
        confidence = f["confidence"].as_f64().expect("confidence");
        margin = f["margin"].as_f64().expect("margin");
    }
    report.insert("bar1Beat".into(), json!(first));
    report.insert("bar1Seconds".into(), json!(round_to(beats[first], 3)));
    report.insert("bar1Confidence".into(), json!(confidence));
    report.insert("bar1Margin".into(), json!(margin));
    let (key, key_r) = measure_key(&feats.chroma);
    report.insert("measuredKey".into(), json!(key));
    report.insert("keyCorrelation".into(), json!(key_r));
    report.insert("askedKey".into(), level["key"].clone());

    let total_bars = (beats.len() - first) / 4 - 1;
    let bar_chroma: Vec<V12> = (0..total_bars).map(|b| sum_rows(&feats.chroma[first + 4 * b..first + 4 * b + 4])).collect();
    let bar_band: Vec<V12> = (0..total_bars).map(|b| mean_rows(&feats.band[first + 4 * b..first + 4 * b + 4])).collect();
    drop(feats);
    let bar_len = 4.0 * beat_len;
    let bias = match follow {
        Some(f) => f["bias"].as_f64().expect("bias"),
        None => grid_bias_seconds(&rise_curve, step, &exact),
    };
    report.insert("beatBiasMs".into(), json!(round_to(bias * 1000.0, 2)));
    let shifted: Vec<f64> = exact.iter().map(|b| b + bias).collect();
    report.insert("gridErrorAfterMs".into(), grid_pair(grid_error_ms(&rise_curve, step, &shifted)));
    drop(rise_curve);
    let mut origin = first as f64 * beat_len + bias * SR as f64;
    if origin < 0.0 {
        origin += 4.0 * beat_len;
    }
    let bar_at = |b: usize| py_round(origin + b as f64 * bar_len) as usize;
    let bar_rms: Vec<f64> = (0..total_bars)
        .map(|b| {
            let part = &grid[bar_at(b).min(grid.len())..bar_at(b + 1).min(grid.len())];
            let sum: f64 = part.iter().map(|f| (f[0] as f64).powi(2) + (f[1] as f64).powi(2)).sum();
            (sum / (2 * part.len()) as f64).sqrt()
        })
        .collect();
    let bars = tier["loopBars"].as_u64().expect("loopBars") as usize;
    let (choice_json, start_bar) = match follow {
        Some(f) => (f["loop"].clone(), f["loop"]["startBar"].as_u64().expect("startBar") as usize),
        None => {
            let c = choose_loop(&bar_chroma, &bar_band, &bar_rms, bars);
            (json!({"startBar": c.start_bar, "score": c.score, "harmony": c.harmony, "texture": c.texture,
                    "quietShare": c.quiet_share, "candidates": c.candidates}), c.start_bar)
        }
    };
    report.insert("loop".into(), choice_json.clone());
    report.insert("totalBars".into(), json!(total_bars));

    let start = bar_at(start_bar);
    let length = py_round(bars as f64 * bar_len) as usize;
    let seam_beats = cfg["seamFadeBeats"].as_f64().expect("seamFadeBeats");
    let fade = (py_round(seam_beats * beat_len) as usize).min(grid.len() - (start + length));
    let mut lp: Stereo = grid[start..start + length].to_vec();
    let follow_part = &grid[start + length..start + length + fade];
    let (mut ff, mut hh, mut fh) = (0.0, 0.0, 0.0);
    for (f, h) in follow_part.iter().zip(&lp[..fade]) {
        for ch in 0..2 {
            let (a, b) = (f[ch] as f64, h[ch] as f64);
            ff += a * a;
            hh += b * b;
            fh += a * b;
        }
    }
    let corr = fh / (ff * hh).sqrt().max(1e-12);
    for i in 0..fade {
        let x = (i as f64 + 0.5) / fade as f64;
        let (fade_in, fade_out) = if corr.abs() < 0.5 {
            ((0.5 * std::f64::consts::PI * x).sin(), (0.5 * std::f64::consts::PI * x).cos())
        } else {
            (x, 1.0 - x)
        };
        for ch in 0..2 {
            lp[i][ch] = (follow_part[i][ch] as f64 * fade_out + lp[i][ch] as f64 * fade_in) as f32;
        }
    }
    report.insert("seamFadeSamples".into(), json!(fade));
    report.insert("seamCorrelation".into(), json!(round_to(corr, 3)));

    // The grid goes to disk now, so mastering holds only the loop. Its gain travels with it.
    audio::write_raw(&out.join("grid.f32"), &grid);
    drop(grid);

    // The codecs overshoot what they're given, so the ceiling that counts is measured on
    // the decoded files; lower it until they clear.
    let mut ceiling = cfg["ceilingDb"].as_f64().expect("ceilingDb");
    let pad = pad_samples(cfg);
    let encode = encode_cfg(cfg);
    let target_lufs = tier["targetLufs"].as_f64().expect("targetLufs");
    let scratch = out.join("scratch");
    let mut done = None;
    let mut worst = 0.0;
    for _ in 0..5 {
        let m = master_loop(&lp, target_lufs, ceiling);
        let wrapped = wrap(&m.out, pad);
        worst = audio::codec_peak(&wrapped, &scratch, encode);
        done = Some(m);
        if worst <= MAX_DECODED_PEAK_DB {
            break;
        }
        ceiling -= worst - MAX_DECODED_PEAK_DB + 0.2;
    }
    let _ = std::fs::remove_dir_all(&scratch);
    let m = done.expect("at least one round");
    report.insert("makeupDb".into(), json!(round_to(m.gain_db, 2)));
    report.insert("limiter".into(), limit_json(&m.stats));
    report.insert("ceilingDb".into(), json!(round_to(ceiling, 2)));
    report.insert("decodedPeakDb".into(), json!(worst));
    report.insert("lufs".into(), json!(m.level.lufs));
    report.insert("lra".into(), json!(m.level.lra));
    report.insert("truePeakDb".into(), json!(m.level.true_peak_db));
    audio::write_raw(&out.join("loop.f32"), &m.out);

    let loop_chroma = &bar_chroma[start_bar..start_bar + bars];
    let result = json!({
        "level": lid, "name": name, "bpm": target, "bars": bars, "gainDb": m.gain_db,
        "barChroma": rows(loop_chroma), "firstBarSample": first as f64 * beat_len,
        "barLen": bar_len, "beatLen": beat_len, "allBarChroma": rows(&bar_chroma), "barRms": bar_rms,
        "loopSamples": m.out.len(),
        "report": Value::Object(report),
        "follow": {"name": name, "beats": beats, "measured": measured, "first": first,
                   "confidence": confidence, "margin": margin, "bias": bias, "loop": choice_json},
    });
    std::fs::write(out.join("tier.json"), serde_json::to_vec(&result).expect("json")).expect("write tier.json");
    result
}

pub fn wrap(lp: &[[f32; 2]], pad: usize) -> Stereo {
    let mut out = Vec::with_capacity(lp.len() + 2 * pad);
    out.extend_from_slice(&lp[lp.len() - pad..]);
    out.extend_from_slice(lp);
    out.extend_from_slice(&lp[..pad]);
    out
}

pub fn limit_json(s: &LimitStats) -> Value {
    json!({"maxReductionDb": s.max_reduction_db, "limitedShare": s.limited_share})
}

pub struct Loaded {
    pub meta: Value,
    pub lp: Stereo,
}

pub fn load(dir: &Path) -> Loaded {
    let meta: Value = serde_json::from_slice(&std::fs::read(dir.join("tier.json")).expect("read tier.json")).expect("tier json");
    Loaded { meta, lp: audio::read_raw(&dir.join("loop.f32")) }
}

impl Loaded {
    pub fn source(&self) -> Source<'_> {
        Source {
            lp: &self.lp,
            bpm: self.meta["bpm"].as_f64().expect("bpm"),
            bar_len: self.meta["barLen"].as_f64().expect("barLen"),
            beat_len: self.meta["beatLen"].as_f64().expect("beatLen"),
        }
    }
}

pub fn join_cfg(cfg: &Value) -> JoinCfg {
    JoinCfg {
        beats: cfg["transition"]["beats"].as_u64().expect("beats") as usize,
        width: cfg["transition"]["crossfadeBeats"].as_f64().expect("crossfadeBeats"),
        fill_db: cfg["transition"]["fillDb"].as_f64().expect("fillDb"),
        ceiling_db: cfg["ceilingDb"].as_f64().expect("ceilingDb"),
        boost_db: cfg["bridge"]["percussionBoostDb"].as_f64().expect("percussionBoostDb"),
    }
}

pub fn transition(a: &Loaded, b: &Loaded, cfg: &Value, out: &Path) -> Value {
    let jc = join_cfg(cfg);
    let chroma_a = parse_rows(&a.meta["barChroma"]);
    let chroma_b = parse_rows(&b.meta["barChroma"]);
    let dest = b.source();
    let j = render_transition(&a.source(), &chroma_a[chroma_a.len() - 1], &dest, &chroma_b, &jc, pad_samples(cfg));
    audio::write_raw(out, &j.mix);
    json!({"entryBar": j.entry, "harmonyMatch": j.match_score, "limiter": limit_json(&j.stats),
           "beats": jc.beats, "bpm": dest.bpm, "samples": j.mix.len()})
}

pub fn bridge(a: &Loaded, b: &Loaded, cfg: &Value, out: &Path, phase: (usize, usize)) -> Value {
    let jc = join_cfg(cfg);
    let chroma_a = parse_rows(&a.meta["barChroma"]);
    let chroma_b = parse_rows(&b.meta["barChroma"]);
    let dest = b.source();
    let j = render_bridge(&a.source(), &chroma_a[chroma_a.len() - 1], &dest, &chroma_b, &jc, pad_samples(cfg), phase);
    audio::write_raw(out, &j.mix);
    json!({"entryBar": j.entry, "harmonyMatch": j.match_score, "limiter": limit_json(&j.stats),
           "bars": 2, "beats": 8, "bpm": dest.bpm, "samples": j.mix.len()})
}

/// The tag reads only its own window of the grid, not the take.
pub fn success(dir: &Path, key: &str, bars: usize, is_final: bool, cfg: &Value, out: &Path) -> Value {
    let meta: Value = serde_json::from_slice(&std::fs::read(dir.join("tier.json")).expect("read tier.json")).expect("tier json");
    let all = parse_rows(&meta["allBarChroma"]);
    let rms = floats(&meta["barRms"]);
    let (start_bar, score) = choose_tag(&all, &rms, key, bars);
    let bpm = meta["bpm"].as_f64().expect("bpm");
    let beat_len = meta["beatLen"].as_f64().expect("beatLen");
    let length = py_round((bars * 4) as f64 * beat_samples(bpm)) as usize;
    let pad = pad_samples(cfg);
    let at = py_round(meta["firstBarSample"].as_f64().expect("firstBarSample") + start_bar as f64 * meta["barLen"].as_f64().expect("barLen"));
    let total = pad + length + pad;
    let begin = at - pad as i64;
    let gain = 10f64.powf(meta["gainDb"].as_f64().expect("gainDb") / 20.0);
    let grid_path = dir.join("grid.f32");
    let mut window: Stereo = if begin < 0 {
        let mut w = vec![[0.0f32; 2]; (-begin) as usize];
        w.extend(audio::scale(&audio::read_raw_window(&grid_path, 0, (begin + total as i64).max(0) as usize), gain));
        w
    } else {
        audio::scale(&audio::read_raw_window(&grid_path, begin as usize, total), gain)
    };
    window.resize(total, [0.0, 0.0]);
    let ceiling = cfg["ceilingDb"].as_f64().expect("ceilingDb");
    let (mix, stats) = render_success(&window, beat_len, bars, is_final, ceiling, pad);
    audio::write_raw(out, &mix);
    json!({"sourceBar": start_bar, "tagScore": score, "limiter": limit_json(&stats),
           "bars": bars, "beats": bars * 4, "bpm": bpm, "samples": mix.len()})
}

/// Encode, lowering any peak the codecs push too high, then measure where ffmpeg's decoder
/// puts the content.
pub fn write_asset(raw: &Path, base: &Path, cfg: &Value, scratch: &Path) -> Value {
    let mut audio_now = audio::read_raw(raw);
    let encode = encode_cfg(cfg);
    let mut ceiling = cfg["ceilingDb"].as_f64().expect("ceilingDb");
    for _ in 0..5 {
        let worst = audio::codec_peak(&audio_now, scratch, encode);
        if worst <= MAX_DECODED_PEAK_DB {
            break;
        }
        ceiling -= worst - MAX_DECODED_PEAK_DB + 0.2;
        audio_now = limit(audio_now, ceiling, false).0;
    }
    let (opus, aac) = audio::encode(&audio_now, base, encode);
    let offset = |p: &Path| audio::decode_offset(&audio_now, &audio::decode_stereo(p));
    let (a, b) = rayon::join(|| offset(&opus), || offset(&aac));
    json!({"opus": opus.to_string_lossy(), "aac": aac.to_string_lossy(), "offsets": {"opus": a, "aac": b}})
}
