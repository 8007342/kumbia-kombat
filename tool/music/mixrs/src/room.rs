//! The steps around layer.py for one room, so each room is built the same way.
//! Ported from tool/music/layer/room.py (deleted 2026-11-10); compare/layer_golden.sh checks it.
//!
//!   mixrs room plan LEVEL    tempos and stretch ratios, from levels.json
//!   mixrs room stage LEVEL   copy low/high into /work/tmp/audio for rubberband
//!   mixrs room wire LEVEL    copy the stretched files back, point levels.json at them
//!
//! Between stage and wire, run audio.transform time_stretch on each staged file with the
//! ratio `plan` prints, writing <tier>-<bpm>.wav beside it. Tempos: low is mid / 1.03 and
//! high mid * 1.03, rounded to whole BPM (owner, 2026-11-09). The `native` tier (mid
//! unless tiers.json says otherwise) plays the take at its own tempo; the others are stretched.

use crate::np::{py_round, round_to};
use serde_json::{json, Map, Value};
use std::path::{Path, PathBuf};

const LIFT: f64 = 1.03;
const ORDER: [&str; 3] = ["low", "mid", "high"];

fn root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../..")
}

fn expand(p: &str) -> PathBuf {
    match p.strip_prefix("~/") {
        Some(rest) => PathBuf::from(std::env::var("HOME").expect("HOME")).join(rest),
        None => PathBuf::from(p),
    }
}

fn read(path: &Path) -> Value {
    serde_json::from_slice(&std::fs::read(path).unwrap_or_else(|e| panic!("{}: {e}", path.display()))).expect("json")
}

fn copy(from: &Path, to: &Path) {
    std::fs::copy(from, to).unwrap_or_else(|e| panic!("copy {} -> {}: {e}", from.display(), to.display()));
}

/// json.dumps(value, indent=1, ensure_ascii=False): serde's pretty printer at one space.
fn python_indent1(v: &Value) -> String {
    let mut out = Vec::new();
    let fmt = serde_json::ser::PrettyFormatter::with_indent(b" ");
    let mut ser = serde_json::Serializer::with_formatter(&mut out, fmt);
    serde::Serialize::serialize(v, &mut ser).expect("serialize");
    String::from_utf8(out).expect("utf8")
}

/// `levels` and `stage` default to the repo's levels.json and /work/tmp/audio/layered;
/// the golden check points them at copies.
pub fn room(cmd: &str, lid: &str, levels: Option<&Path>, stage: Option<&Path>) -> Value {
    let levels_path = levels.map(Path::to_path_buf).unwrap_or_else(|| root().join("tool/music/mix/levels.json"));
    let stage = stage.map(Path::to_path_buf).unwrap_or_else(|| PathBuf::from("/work/tmp/audio/layered"));
    let spec = read(&root().join("tool/music/layer/tiers.json"));
    let mut cfg = read(&levels_path);
    let room_spec = &spec["levels"][lid];
    assert!(room_spec.is_object(), "{lid} isn't in tiers.json");
    let out_dir = format!("{}/{}", spec["outDir"].as_str().unwrap(), lid);
    let out = expand(&format!("{}/{}", spec["mastersDir"].as_str().unwrap(), out_dir));
    let lv = cfg["levels"].as_array_mut().unwrap().iter_mut().find(|l| l["id"] == lid).unwrap_or_else(|| panic!("no level {lid}"));
    let mid = lv["tiers"].as_array().unwrap().iter().find(|t| t["name"] == "mid").expect("a mid tier");
    let m = py_round(mid["bpm"].as_f64().unwrap());
    let bpm: Vec<(&str, i64)> = vec![("low", py_round(m as f64 / LIFT)), ("mid", m), ("high", py_round(m as f64 * LIFT))];
    let of = |name: &str| bpm.iter().find(|(k, _)| *k == name).map(|(_, v)| *v).unwrap_or_else(|| panic!("no tier {name}"));
    let native = room_spec.get("native").and_then(Value::as_str).unwrap_or("mid").to_string();
    let ratio = |name: &str| round_to(of(&native) as f64 / of(name) as f64, 6);
    let stretched: Vec<&str> = ORDER.iter().copied().filter(|t| *t != native).collect();
    match cmd {
        "plan" => {
            let b: Map<String, Value> = bpm.iter().map(|(k, v)| (k.to_string(), json!(v))).collect();
            let r: Map<String, Value> = bpm.iter().map(|(k, _)| (k.to_string(), json!(ratio(k)))).collect();
            json!({"bpm": b, "ratio": r, "native": native, "base": room_spec["base"]})
        }
        "stage" => {
            let dir = stage.join(lid);
            std::fs::create_dir_all(&dir).expect("stage dir");
            let mut lines = Vec::new();
            for t in &stretched {
                copy(&out.join(format!("{t}.wav")), &dir.join(format!("{t}.wav")));
                lines.push(json!({"staged": dir.join(format!("{t}.wav")), "ratio": ratio(t),
                                  "write": dir.join(format!("{t}-{}.wav", of(t)))}));
            }
            json!(lines)
        }
        "wire" => {
            for t in &stretched {
                let name = format!("{t}-{}.wav", of(t));
                copy(&stage.join(lid).join(&name), &out.join(&name));
                copy(&stage.join(lid).join(format!("{name}.provenance.json")), &out.join(format!("{name}.provenance.json")));
            }
            let grid = lv.get("gridTier").and_then(Value::as_str).unwrap_or("mid").to_string();
            let mut wired = Vec::new();
            for t in lv["tiers"].as_array_mut().unwrap() {
                let t = t.as_object_mut().unwrap();
                let n = t["name"].as_str().unwrap().to_string();
                t.shift_remove("layer");
                t.insert("eq".into(), json!([]));
                t.insert("bpm".into(), json!(of(&n)));
                // The native tier is the approved take's own file, untouched: the mixer's beat
                // and bar-one analysis is level-sensitive, and a trimmed copy moved terraza's
                // bar one by a beat. A native tier with gains of its own (the party narrows its
                // sides) is the layered file, written unscaled.
                let source = if n == native {
                    let gains = &room_spec["tiers"][n.as_str()];
                    let has = gains.as_object().is_some_and(|g| !g.is_empty());
                    if has { format!("{out_dir}/{n}.wav") } else { room_spec["base"].as_str().unwrap().to_string() }
                } else {
                    format!("{out_dir}/{n}-{}.wav", of(&n))
                };
                t.insert("source".into(), json!(source));
                // Followers sit at the grid tier's beats times their stretch against it.
                if n == grid {
                    t.shift_remove("followScale");
                } else {
                    t.insert("followScale".into(), json!(round_to(ratio(&n) / ratio(&grid), 6)));
                }
                wired.push(json!([n, t["bpm"], t["source"], t.get("followScale")]));
            }
            std::fs::write(&levels_path, python_indent1(&cfg) + "\n").expect("write levels.json");
            json!(wired)
        }
        _ => panic!("room: plan, stage or wire, not {cmd}"),
    }
}
