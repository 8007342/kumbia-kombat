#!/usr/bin/env python3
"""Build the owner's blind listening page (plan/music-rebuild.md, stage 2).

Takes the best timed takes per level plus the synth capture, cuts same-length excerpts at
equal loudness, and shuffles them behind the letters A to D. The answer key stays outside
the served folder, so the page can't give it away.

  python3 -I tool/music/build_listening.py <pilot dir> <served dir>

The pilot dir holds <level>/timing.json and takes from measure_takes.py, plus
synth/<level>.wav. Picks are by timing only, since nobody has heard them.
"""
import json
import pathlib
import re
import secrets
import subprocess
import sys

LEVELS = {
    "garden": {"title": "Garden", "brief": "Warm night cumbia at the mansion gates, 98 BPM", "synth_tempo": 98 / 99.97},
    "lawn": {"title": "Pool lawn", "brief": "Fast, joyful swing for two dancers, 144 BPM", "synth_tempo": 1.0},
}
PICKS = 3
SECONDS = 30
TAKE_START = 15
SYNTH_START = 0.5
TARGET_MEAN_DB = -18.0
LETTERS = "ABCD"


def best_takes(folder):
    timing = json.loads((folder / "timing.json").read_text())
    passed = [(name, t) for name, t in timing.items() if t["passed"]]
    passed.sort(key=lambda kv: abs(kv[1]["error_pct"]) + kv[1]["wander_ms"] / 20)
    return [name for name, _ in passed[:PICKS]]


def mean_db(source, start, filters):
    chain = ",".join(filters + ["volumedetect"])
    log = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-ss", str(start), "-t", str(SECONDS),
         "-i", str(source), "-af", chain, "-f", "null", "-"],
        check=True, capture_output=True, text=True,
    ).stderr
    return float(re.search(r"mean_volume: (-?[\d.]+) dB", log).group(1))


def excerpt(source, start, out, tempo=1.0):
    tempo_filter = [f"atempo={tempo:.5f}"] if tempo != 1.0 else []
    gain = TARGET_MEAN_DB - mean_db(source, start, tempo_filter)
    chain = tempo_filter + [
        f"volume={gain:.2f}dB",
        "alimiter=limit=0.95:level=false",
        "afade=t=in:d=1",
        f"afade=t=out:st={SECONDS - 1}:d=1",
        f"apad=whole_dur={SECONDS}",
        f"atrim=duration={SECONDS}",
    ]
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-ss", str(start), "-t", str(SECONDS * tempo), "-i", str(source),
         "-af", ",".join(chain), "-ar", "48000", "-ac", "2", "-map_metadata", "-1", str(out)],
        check=True,
    )


PAGE = """<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Blind Listening</title>
<style>
:root{--bg:#101522;--ink:#fff3d6;--dim:#b9b09a;--line:#39415a}
body{margin:0;background:var(--bg);color:var(--ink);font:17px/1.5 system-ui;padding:24px 16px}
main{max-width:640px;margin:auto}h2{margin:32px 0 0}p{margin:6px 0 14px;color:var(--dim)}
.row{display:flex;align-items:center;gap:12px;border-top:1px solid var(--line);padding:10px 0}
.row b{width:1.5em;font-size:20px}button{font:inherit;min-width:7em;padding:8px 14px;background:var(--ink);color:var(--bg);border:0;border-radius:6px;cursor:pointer}
</style>
<main><h1>Blind listening</h1>
<p>Each room has four 30-second excerpts at matched loudness. One is the current synth, and three are generated takes. Rank each room best to worst, and say which you would ship over the synth if you can tell.</p>
{sections}
</main>
<script>
// Plain buttons, not the browser's player: its length readout and buffered bar give away
// which file is smaller, and so which excerpt is the synth.
const audio=new Audio();let current=null;
const label=()=>{const t=Math.floor(audio.currentTime);if(current)current.nextElementSibling.textContent=Math.floor(t/60)+':'+String(t%60).padStart(2,'0')};
audio.addEventListener('timeupdate',label);
audio.addEventListener('ended',()=>{current.textContent='Play';current=null});
document.querySelectorAll('button').forEach(b=>b.addEventListener('click',()=>{
 if(current===b){if(audio.paused){audio.play();b.textContent='Pause'}else{audio.pause();b.textContent='Play'}return}
 if(current)current.textContent='Play';
 current=b;audio.src=b.dataset.src;audio.play();b.textContent='Pause';
}));
</script></html>
"""


def main():
    pilot, served = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    key = {}
    sections = []
    rng = secrets.SystemRandom()
    for level, info in LEVELS.items():
        folder = served / level
        folder.mkdir(parents=True, exist_ok=True)
        entries = [(pilot / level / name, TAKE_START, f"take {name}", 1.0) for name in best_takes(pilot / level)]
        entries.append((pilot / "synth" / f"{level}.wav", SYNTH_START, "synth", info["synth_tempo"]))
        rng.shuffle(entries)
        key[level] = {}
        rows = []
        for letter, (source, start, label, tempo) in zip(LETTERS, entries):
            excerpt(source, start, folder / f"{letter}.flac", tempo)
            key[level][letter] = label
            rows.append(f'<div class="row"><b>{letter}</b><button type="button" data-src="{level}/{letter}.flac">Play</button><span>0:00</span></div>')
        sections.append(f"<h2>{info['title']}</h2><p>{info['brief']}</p>" + "".join(rows))
    (served / "index.html").write_text(PAGE.replace("{sections}", "\n".join(sections)))
    (pilot / "listening-key.json").write_text(json.dumps(key, indent=1) + "\n")
    print("built", served / "index.html", "; key in", pilot / "listening-key.json")


if __name__ == "__main__":
    main()
