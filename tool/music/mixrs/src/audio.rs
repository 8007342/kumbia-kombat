//! Audio in and out: ffmpeg through pipes, in small buffers, with nothing held twice.

use crate::{SR, Stereo};
use realfft::RealFftPlanner;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

const CHUNK: usize = 1 << 16;

fn run_reader(mut child: std::process::Child, what: &str, mut sink: impl FnMut(&[u8])) {
    let mut out = child.stdout.take().expect("piped stdout");
    let mut buf = vec![0u8; CHUNK];
    let mut held = 0usize;
    loop {
        let got = out.read(&mut buf[held..]).expect("read ffmpeg");
        if got == 0 {
            break;
        }
        held += got;
        let usable = held - held % 4;
        sink(&buf[..usable]);
        buf.copy_within(usable..held, 0);
        held -= usable;
    }
    let status = child.wait().expect("wait for ffmpeg");
    assert!(status.success(), "ffmpeg failed: {what}");
}

fn decoder(path: &Path, rate: u32, channels: u32, format: &str) -> std::process::Child {
    Command::new("ffmpeg")
        .args(["-nostdin", "-v", "error", "-i"])
        .arg(path)
        .args(["-map_metadata", "-1", "-ac", &channels.to_string(), "-ar", &rate.to_string(), "-f", format, "-"])
        .stdout(Stdio::piped())
        .spawn()
        .expect("start ffmpeg")
}

pub fn decode_stereo(path: &Path) -> Stereo {
    let mut out: Stereo = Vec::new();
    run_reader(decoder(path, SR as u32, 2, "f32le"), &path.display().to_string(), |bytes| {
        out.extend(bytes.chunks_exact(8).map(|b| {
            [f32::from_le_bytes([b[0], b[1], b[2], b[3]]), f32::from_le_bytes([b[4], b[5], b[6], b[7]])]
        }));
    });
    out.shrink_to_fit();
    out
}

pub fn decode_mono(path: &Path, rate: u32) -> Vec<f32> {
    let mut out: Vec<f32> = Vec::new();
    run_reader(decoder(path, rate, 1, "f32le"), &path.display().to_string(), |bytes| {
        out.extend(bytes.chunks_exact(4).map(|b| f32::from_le_bytes([b[0], b[1], b[2], b[3]])));
    });
    out.shrink_to_fit();
    out
}

fn write_stereo(w: &mut impl Write, parts: &[&[[f32; 2]]]) -> std::io::Result<()> {
    let mut buf = Vec::with_capacity(CHUNK);
    for part in parts {
        for frame in part.iter() {
            buf.extend_from_slice(&frame[0].clamp(-4.0, 4.0).to_le_bytes());
            buf.extend_from_slice(&frame[1].clamp(-4.0, 4.0).to_le_bytes());
            if buf.len() + 8 > CHUNK {
                w.write_all(&buf)?;
                buf.clear();
            }
        }
    }
    w.write_all(&buf)
}

#[derive(Clone, Copy, Debug)]
pub struct Level {
    pub lufs: f64,
    pub lra: f64,
    pub true_peak_db: f64,
}

fn parse_level(stderr: &[u8]) -> Level {
    let text = String::from_utf8_lossy(stderr);
    let tail = text.rsplit("Summary:").next().unwrap_or("");
    let grab = |key: &str| -> f64 {
        let needle = format!("{key}:");
        for line in tail.lines() {
            if let Some(at) = line.find(&needle) {
                let rest = line[at + needle.len()..].trim_start();
                let word = rest.split_whitespace().next().unwrap_or("");
                if let Ok(v) = word.parse::<f64>() {
                    return v;
                }
            }
        }
        panic!("no {key} in ebur128 output: {tail}");
    };
    Level { lufs: grab("I"), lra: grab("LRA"), true_peak_db: grab("Peak") }
}

fn ebur128_args() -> Vec<&'static str> {
    vec![
        "-nostdin", "-hide_banner", "-nostats", "-f", "f32le", "-ar", "48000", "-ac", "2", "-i", "-",
        "-af", "ebur128=peak=true", "-f", "null", "-",
    ]
}

/// Integrated LUFS, LRA and true peak from ffmpeg's ebur128, fed the parts in order.
pub fn loudness(parts: &[&[[f32; 2]]]) -> Level {
    let mut child = Command::new("ffmpeg")
        .args(ebur128_args())
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .expect("start ffmpeg");
    let mut input = child.stdin.take().expect("piped stdin");
    let output = std::thread::scope(|s| {
        s.spawn(move || {
            let _ = write_stereo(&mut input, parts);
        });
        child.wait_with_output().expect("wait for ffmpeg")
    });
    assert!(output.status.success(), "ebur128 failed");
    parse_level(&output.stderr)
}

/// The level of an encoded file, decoder piped straight into ebur128: nothing held here.
pub fn file_level(path: &Path) -> Level {
    let mut dec = decoder(path, SR as u32, 2, "f32le");
    let out = dec.stdout.take().expect("piped stdout");
    let meter = Command::new("ffmpeg")
        .args(ebur128_args())
        .stdin(Stdio::from(out))
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .expect("start ffmpeg");
    let output = meter.wait_with_output().expect("wait for ffmpeg");
    assert!(dec.wait().expect("wait for ffmpeg").success(), "decode failed");
    assert!(output.status.success(), "ebur128 failed");
    parse_level(&output.stderr)
}

#[derive(Clone, Copy, Debug)]
pub struct Encode {
    pub opus_kbps: i64,
    pub aac_kbps: i64,
}

fn encode_one(audio: &[[f32; 2]], path: &Path, codec: &[String]) {
    let mut child = Command::new("ffmpeg")
        .args(["-nostdin", "-y", "-v", "error", "-f", "f32le", "-ar", "48000", "-ac", "2", "-i", "-",
            "-map_metadata", "-1", "-fflags", "+bitexact", "-flags", "+bitexact"])
        .args(codec)
        .arg(path)
        .stdin(Stdio::piped())
        .spawn()
        .expect("start ffmpeg");
    let mut input = child.stdin.take().expect("piped stdin");
    write_stereo(&mut input, &[audio]).expect("feed ffmpeg");
    drop(input);
    assert!(child.wait().expect("wait for ffmpeg").success(), "encode failed: {}", path.display());
}

pub fn with_suffix(base: &Path, suffix: &str) -> PathBuf {
    // Path.with_suffix: replaces an existing suffix, as mix.py does.
    base.with_extension(suffix)
}

/// Both formats, side by side, without the master's metadata, repeatably.
pub fn encode(audio: &[[f32; 2]], base: &Path, cfg: Encode) -> (PathBuf, PathBuf) {
    if let Some(dir) = base.parent() {
        std::fs::create_dir_all(dir).expect("make output directory");
    }
    let opus = with_suffix(base, "ogg");
    let aac = with_suffix(base, "m4a");
    let opus_args: Vec<String> = ["-c:a", "libopus", "-b:a", &format!("{}k", cfg.opus_kbps), "-vbr", "on", "-application", "audio"]
        .iter().map(|s| s.to_string()).collect();
    let aac_args: Vec<String> = ["-c:a", "aac", "-b:a", &format!("{}k", cfg.aac_kbps), "-movflags", "+faststart"]
        .iter().map(|s| s.to_string()).collect();
    // Written beside the target and renamed, so a killed build can't leave half a file.
    let stem = base.file_name().expect("file name").to_string_lossy().to_string();
    let part_opus = base.with_file_name(format!("{stem}.part.ogg"));
    let part_aac = base.with_file_name(format!("{stem}.part.m4a"));
    rayon::join(|| encode_one(audio, &part_opus, &opus_args), || encode_one(audio, &part_aac, &aac_args));
    std::fs::rename(&part_opus, &opus).expect("move opus into place");
    std::fs::rename(&part_aac, &aac).expect("move aac into place");
    (opus, aac)
}

/// The higher true peak of the two formats, once encoded and decoded.
pub fn codec_peak(audio: &[[f32; 2]], scratch: &Path, cfg: Encode) -> f64 {
    std::fs::create_dir_all(scratch).expect("make scratch directory");
    let base = scratch.join("probe");
    let (opus, aac) = encode(audio, &base, cfg);
    let (a, b) = rayon::join(|| file_level(&opus), || file_level(&aac));
    let _ = std::fs::remove_file(&opus);
    let _ = std::fs::remove_file(&aac);
    a.true_peak_db.max(b.true_peak_db)
}

/// Where the decoded file's content sits against what was encoded, in samples.
pub fn decode_offset(reference: &[[f32; 2]], decoded: &[[f32; 2]]) -> i64 {
    let span = 1usize << 15;
    let reach = 4096usize;
    let at = (reference.len() / 2).min(decoded.len() / 2);
    let mono = |f: &[f32; 2]| 0.5 * (f[0] as f64 + f[1] as f64);
    let r: Vec<f64> = reference[at..(at + span).min(reference.len())].iter().map(mono).collect();
    let d: Vec<f64> = decoded[at.saturating_sub(reach)..(at + span + reach).min(decoded.len())].iter().map(mono).collect();
    let need = r.len() + d.len();
    let bits = usize::BITS - (need.max(2) - 1).leading_zeros();
    let size = 1usize << bits;
    let mut planner = RealFftPlanner::<f64>::new();
    let fwd = planner.plan_fft_forward(size);
    let inv = planner.plan_fft_inverse(size);
    let mut a = vec![0.0; size];
    a[..d.len()].copy_from_slice(&d);
    let mut b = vec![0.0; size];
    b[..r.len()].copy_from_slice(&r);
    let mut sa = fwd.make_output_vec();
    let mut sb = fwd.make_output_vec();
    fwd.process(&mut a, &mut sa).expect("fft");
    fwd.process(&mut b, &mut sb).expect("fft");
    for (x, y) in sa.iter_mut().zip(&sb) {
        *x *= y.conj();
    }
    sa[0].im = 0.0;
    let last = sa.len() - 1;
    sa[last].im = 0.0;
    let mut xc = inv.make_output_vec();
    inv.process(&mut sa, &mut xc).expect("ifft");
    let usable = d.len() - r.len() + 1;
    crate::np::argmax(&xc[..usable]) as i64 - reach.min(at) as i64
}

pub fn write_raw(path: &Path, audio: &[[f32; 2]]) {
    let file = std::fs::File::create(path).expect("create raw file");
    let mut w = std::io::BufWriter::with_capacity(CHUNK, file);
    for frame in audio {
        w.write_all(&frame[0].to_le_bytes()).expect("write");
        w.write_all(&frame[1].to_le_bytes()).expect("write");
    }
    w.flush().expect("flush");
}

pub fn read_raw(path: &Path) -> Stereo {
    let bytes = std::fs::read(path).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
    bytes
        .chunks_exact(8)
        .map(|b| [f32::from_le_bytes([b[0], b[1], b[2], b[3]]), f32::from_le_bytes([b[4], b[5], b[6], b[7]])])
        .collect()
}

/// A window of a raw stereo file; what lies past the end comes back as nothing.
pub fn read_raw_window(path: &Path, start: usize, frames: usize) -> Stereo {
    use std::io::{Seek, SeekFrom};
    let mut file = std::fs::File::open(path).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
    let size = file.metadata().expect("stat").len() as usize / 8;
    if start >= size {
        return Vec::new();
    }
    file.seek(SeekFrom::Start(start as u64 * 8)).expect("seek");
    let take = frames.min(size - start);
    let mut bytes = vec![0u8; take * 8];
    file.read_exact(&mut bytes).expect("read");
    bytes
        .chunks_exact(8)
        .map(|b| [f32::from_le_bytes([b[0], b[1], b[2], b[3]]), f32::from_le_bytes([b[4], b[5], b[6], b[7]])])
        .collect()
}

pub fn scale(audio: &[[f32; 2]], gain: f64) -> Stereo {
    audio.iter().map(|f| [(f[0] as f64 * gain) as f32, (f[1] as f64 * gain) as f32]).collect()
}
