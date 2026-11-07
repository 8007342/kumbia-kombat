//! mixrs: the heavy parts of tool/music/mix/mix.py, without holding whole spectrograms.
//! mix.py writes a job file, calls a subcommand, and reads JSON back from stdout.

mod analysis;
mod audio;
mod np;
mod render;
mod tier;
mod verify;

use clap::{Parser, Subcommand};
use serde_json::Value;
use std::path::{Path, PathBuf};

pub const SR: usize = 48000;
pub const RATE: usize = 22050;
pub const HOP: usize = 256;
pub const WINDOW: usize = 1024;
pub const ENV_RATE: f64 = RATE as f64 / HOP as f64;
pub type Stereo = Vec<[f32; 2]>;

#[derive(Parser)]
#[command(name = "mixrs", about = "Streaming analysis and rendering for mix.py")]
struct Cli {
    /// Worker threads. mix.py passes its own count; MIXRS_THREADS or 4 otherwise.
    #[arg(long, global = true)]
    threads: Option<usize>,
    #[command(subcommand)]
    command: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// A tier, from master to mastered loop. The job holds cfg, level, tier and maybe follow.
    Prepare { #[arg(long)] job: PathBuf, #[arg(long)] out: PathBuf },
    /// A join between two prepared tiers. The job holds cfg.
    Transition { #[arg(long)] a: PathBuf, #[arg(long)] b: PathBuf, #[arg(long)] job: PathBuf, #[arg(long)] out: PathBuf },
    /// Two bars into the next level's first tier.
    Bridge { #[arg(long)] a: PathBuf, #[arg(long)] b: PathBuf, #[arg(long)] job: PathBuf, #[arg(long)] out: PathBuf },
    /// The tag at the end of a level.
    Success {
        #[arg(long)] tier: PathBuf,
        #[arg(long)] key: String,
        #[arg(long)] bars: usize,
        #[arg(long)] r#final: bool,
        #[arg(long)] job: PathBuf,
        #[arg(long)] out: PathBuf,
    },
    /// Encode raw stereo f32 to both formats and say where the decoder puts it.
    WriteAsset { #[arg(long)] audio: PathBuf, #[arg(long)] base: PathBuf, #[arg(long)] job: PathBuf, #[arg(long)] scratch: PathBuf },
    /// Measures of one encoded loop.
    VerifyTake { #[arg(long)] file: PathBuf, #[arg(long)] bpm: f64, #[arg(long)] bars: usize, #[arg(long)] start: usize, #[arg(long)] end: usize },
    /// Measures of one encoded segment.
    VerifySegment { #[arg(long)] file: PathBuf, #[arg(long)] bpm: f64, #[arg(long)] start: usize, #[arg(long)] end: usize },
    /// Beat and key measures of any audio file, for checking against the Python.
    Analyze { #[arg(long)] file: PathBuf, #[arg(long)] bpm: f64 },
}

fn read_json(path: &Path) -> Value {
    serde_json::from_slice(&std::fs::read(path).unwrap_or_else(|e| panic!("{}: {e}", path.display()))).expect("job json")
}

fn main() {
    let cli = Cli::parse();
    let threads = cli
        .threads
        .or_else(|| std::env::var("MIXRS_THREADS").ok().and_then(|v| v.parse().ok()))
        .unwrap_or(4);
    rayon::ThreadPoolBuilder::new().num_threads(threads).build_global().expect("thread pool");
    let result = match cli.command {
        Cmd::Prepare { job, out } => tier::prepare(&read_json(&job), &out),
        Cmd::Transition { a, b, job, out } => {
            let (a, b) = (tier::load(&a), tier::load(&b));
            tier::transition(&a, &b, &read_json(&job)["cfg"], &out)
        }
        Cmd::Bridge { a, b, job, out } => {
            let (a, b) = (tier::load(&a), tier::load(&b));
            tier::bridge(&a, &b, &read_json(&job)["cfg"], &out)
        }
        Cmd::Success { tier: dir, key, bars, r#final, job, out } => {
            tier::success(&dir, &key, bars, r#final, &read_json(&job)["cfg"], &out)
        }
        Cmd::WriteAsset { audio, base, job, scratch } => tier::write_asset(&audio, &base, &read_json(&job)["cfg"], &scratch),
        Cmd::VerifyTake { file, bpm, bars, start, end } => verify::verify_take(&file, bpm, bars, start, end),
        Cmd::VerifySegment { file, bpm, start, end } => verify::verify_segment(&file, bpm, start, end),
        Cmd::Analyze { file, bpm } => {
            let mono = audio::decode_mono(&file, RATE as u32);
            let fit = analysis::beat_times(&mono, bpm);
            let beat = 60.0 / bpm;
            let count = (mono.len() as f64 / RATE as f64 / beat) as usize - 1;
            let feats = analysis::beat_features(&mono, beat, count);
            let (first, confidence, margin) = analysis::find_bar_one(&feats.chroma, &feats.attack);
            let (key, r) = analysis::measure_key(&feats.chroma);
            serde_json::json!({"bpm": fit.bpm, "wanderMs": fit.wander_ms, "beats": fit.beats, "barOne": first,
                               "confidence": confidence, "margin": margin, "key": key, "keyR": r})
        }
    };
    println!("{result}");
}
