#!/usr/bin/env python3
"""Build the owner's listening pages (plan/music-rebuild.md, stages 2 and 4).

Takes the best timed takes per room, plus the synth capture for rooms that name one, cuts
same-length excerpts at equal loudness, and shuffles them behind letters. A page can also
carry ladders: tiers of one level played in order under plain labels, not blind. The answer
key stays outside the served folder, so the page can't give it away.

  python3 -I tool/music/build_listening.py [--page pilot|themes] <run dir> <served dir>
  python3 -I tool/music/build_listening.py --add-ladder <ladder> <run dir> <served dir>

--add-ladder puts one more ladder from LADDERS into a built page, and changes nothing else:
no letters, no other excerpts, no answer key. Use it while someone is still comparing the page.

The run dir holds <room>/timing.json and takes from measure_takes.py, plus synth/<room>.wav
for a room with a synth, and <ladder>/<tier>.flac with <tier>.timing.json for a ladder. Picks are by timing only,
since nobody has heard them. Files in the served dir that this page doesn't use are left alone.
"""
import argparse
import json
import pathlib
import re
import secrets
import subprocess
import sys

PAGES = {
    "pilot": {
        "intro": "Each room has four 30-second excerpts at matched loudness. One is the current synth, and three are generated takes. Rank each room best to worst, and say which you would ship over the synth if you can tell.",
        "picks": 3,
        "rooms": {
            "garden": {"title": "Garden", "brief": "Warm night cumbia at the mansion gates, 98 BPM", "synth_tempo": 98 / 99.97},
            "lawn": {"title": "Pool lawn", "brief": "Fast, joyful swing for two dancers, 144 BPM", "synth_tempo": 1.0},
        },
        "ladders": {},
    },
    "themes": {
        "intro": "Two new rooms, then two ladders. In each room the letters are shuffled generated takes at matched loudness, with no synth among them. Rank each room best to worst.",
        "picks": 4,
        "rooms": {
            "bar": {"title": "Bar", "brief": "Cooler, swaggering, indoor, under lanterns, 106 BPM"},
            "party": {"title": "Indoor party", "brief": "Cool midnight Latin boogaloo with a salsa-disco lift, 124 BPM"},
        },
        "ladders": {
            "ladder-garden": {"title": "Ladder: Garden", "tiers": [("low", "92 BPM"), ("mid", "98 BPM"), ("high", "104 BPM")]},
            "ladder-lawn": {"title": "Ladder: Pool lawn", "tiers": [("low", "128 BPM"), ("mid", "144 BPM"), ("high", "160 BPM")]},
        },
    },
}
# Added to a page already built, with --add-ladder.
LADDERS = {
    "ladder-lawn-2": {"title": "Pool lawn ladder, second try", "tiers": [("low", "128 BPM"), ("mid", "144 BPM"), ("high", "160 BPM")]},
    "ladder-bar": {"title": "Ladder: Bar", "tiers": [("low", "100 BPM"), ("mid", "106 BPM"), ("high", "112 BPM")]},
    "ladder-party": {"title": "Ladder: Indoor party", "tiers": [("low", "112 BPM"), ("mid", "124 BPM"), ("high", "136 BPM")]},
}
SECONDS = 30
LADDER_SECONDS = 40
TAKE_START = 15
SYNTH_START = 0.5
TARGET_MEAN_DB = -18.0
LETTERS = "ABCD"


def best_takes(folder, picks):
    timing = json.loads((folder / "timing.json").read_text())
    passed = [(name, t) for name, t in timing.items() if t["passed"]]
    passed.sort(key=lambda kv: abs(kv[1]["error_pct"]) + kv[1]["wander_ms"] / 20)
    return [name for name, _ in passed[:picks]]


def mean_db(source, start, filters, seconds):
    chain = ",".join(filters + ["volumedetect"])
    log = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-ss", str(start), "-t", str(seconds),
         "-i", str(source), "-af", chain, "-f", "null", "-"],
        check=True, capture_output=True, text=True,
    ).stderr
    return float(re.search(r"mean_volume: (-?[\d.]+) dB", log).group(1))


def excerpt(source, start, out, tempo=1.0, seconds=SECONDS):
    tempo_filter = [f"atempo={tempo:.5f}"] if tempo != 1.0 else []
    gain = TARGET_MEAN_DB - mean_db(source, start, tempo_filter, seconds)
    chain = tempo_filter + [
        f"volume={gain:.2f}dB",
        "alimiter=limit=0.95:level=false",
        "afade=t=in:d=1",
        f"afade=t=out:st={seconds - 1}:d=1",
        f"apad=whole_dur={seconds}",
        f"atrim=duration={seconds}",
    ]
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-ss", str(start), "-t", str(seconds * tempo), "-i", str(source),
         "-af", ",".join(chain), "-ar", "48000", "-ac", "2", "-map_metadata", "-1", str(out)],
        check=True,
    )


PAGE = """<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Listening Page</title>
<style>
:root{--bg:#101522;--ink:#fff3d6;--dim:#b9b09a;--line:#39415a}
body{margin:0;background:var(--bg);color:var(--ink);font:17px/1.5 system-ui;padding:24px 16px}
main{max-width:640px;margin:auto}h2{margin:32px 0 0}p{margin:6px 0 14px;color:var(--dim)}
.row{display:flex;align-items:center;gap:12px;border-top:1px solid var(--line);padding:10px 0}
.row b{width:1.5em;font-size:20px}.row b.tier{width:2.5em;font-size:17px}.row em{color:var(--dim);font-style:normal;margin-left:auto}button{font:inherit;min-width:7em;padding:8px 14px;background:var(--ink);color:var(--bg);border:0;border-radius:6px;cursor:pointer}
</style>
<main><h1>Listening</h1>
<p>{intro}</p>
{sections}
</main>
<script>
// Plain buttons, not the browser's player: its length readout and buffered bar give away
// which file is smaller, and so which excerpt is the synth.
const audio=new Audio();let current=null,queue=[],owner=null;
const label=()=>{const t=Math.floor(audio.currentTime);if(current&&current.nextElementSibling)current.nextElementSibling.textContent=Math.floor(t/60)+':'+String(t%60).padStart(2,'0')};
const start=b=>{current=b;audio.src=b.dataset.src;audio.play();b.textContent='Pause'};
const stop=()=>{if(current)current.textContent='Play';if(owner)owner.textContent='Play in order';current=null;queue=[];owner=null};
audio.addEventListener('timeupdate',label);
audio.addEventListener('ended',()=>{const q=queue;if(current)current.textContent='Play';if(q.length){current=null;start(q.shift())}else{stop()}});
document.querySelectorAll('button[data-src]').forEach(b=>b.addEventListener('click',()=>{
 if(current===b){if(audio.paused){audio.play();b.textContent='Pause'}else{audio.pause();b.textContent='Play'}return}
 stop();start(b);
}));
// A ladder's button plays its tiers low to high, so the question is heard as asked: one song growing?
document.querySelectorAll('button[data-order]').forEach(b=>b.addEventListener('click',()=>{
 if(owner===b){stop();audio.pause();return}
 stop();owner=b;b.textContent='Stop';
 const tiers=[...document.querySelectorAll('button[data-src^="'+b.dataset.order+'/"]')];
 start(tiers.shift());queue=tiers;
}));
</script></html>
"""


def ladder_section(ladder, info, run, served):
    folder = served / ladder
    folder.mkdir(parents=True, exist_ok=True)
    rows = []
    for tier, note in info["tiers"]:
        excerpt(run / ladder / f"{tier}.flac", TAKE_START, folder / f"{tier}.flac", seconds=LADDER_SECONDS)
        # Not blind, so the page says what the filter measured: a model can miss the tempo it's asked for.
        timing = json.loads((run / ladder / f"{tier}.timing.json").read_text())[f"{tier}.flac"]
        note = f"{note} asked, {timing['measured_bpm']:.1f} measured"
        rows.append(f'<div class="row"><b class="tier">{tier}</b><button type="button" data-src="{ladder}/{tier}.flac">Play</button><span>0:00</span><em>{note}</em></div>')
    order = f'<button type="button" data-order="{ladder}">Play in order</button>'
    return f"<h2>{info['title']}</h2><p>Not blind. 40 seconds of each tier from the same point in the take, at matched loudness, so any growth comes from the arrangement and tempo and not from volume. Does this read as one song growing, or as three songs?</p>{order}" + "".join(rows)


def add_ladder(ladder, run, served):
    index = served / "index.html"
    page = index.read_text()
    marker = f'data-order="{ladder}"'
    if marker in page:
        sys.exit(f"{ladder} is already on {index}")
    section = ladder_section(ladder, LADDERS[ladder], run, served)
    if page.count("</main>") != 1:
        sys.exit(f"can't find where to add the section in {index}")
    index.write_text(page.replace("</main>", section + "\n</main>"))
    print("added", ladder, "to", index)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--page", choices=PAGES, default="pilot")
    parser.add_argument("--add-ladder", choices=LADDERS)
    parser.add_argument("run", type=pathlib.Path)
    parser.add_argument("served", type=pathlib.Path)
    args = parser.parse_args()
    if args.add_ladder:
        return add_ladder(args.add_ladder, args.run, args.served)
    page, run, served = PAGES[args.page], args.run, args.served
    key = {}
    sections = []
    rng = secrets.SystemRandom()
    for room, info in page["rooms"].items():
        folder = served / room
        folder.mkdir(parents=True, exist_ok=True)
        entries = [(run / room / name, TAKE_START, f"take {name}", 1.0) for name in best_takes(run / room, page["picks"])]
        if "synth_tempo" in info:
            entries.append((run / "synth" / f"{room}.wav", SYNTH_START, "synth", info["synth_tempo"]))
        rng.shuffle(entries)
        key[room] = {}
        rows = []
        for letter, (source, start, label, tempo) in zip(LETTERS, entries):
            excerpt(source, start, folder / f"{letter}.flac", tempo)
            key[room][letter] = label
            rows.append(f'<div class="row"><b>{letter}</b><button type="button" data-src="{room}/{letter}.flac">Play</button><span>0:00</span></div>')
        sections.append(f"<h2>{info['title']}</h2><p>{info['brief']}</p>" + "".join(rows))
    for ladder, info in page["ladders"].items():
        sections.append(ladder_section(ladder, info, run, served))
    html = PAGE.replace("{intro}", page["intro"]).replace("{sections}", "\n".join(sections))
    (served / "index.html").write_text(html)
    (run / "listening-key.json").write_text(json.dumps(key, indent=1) + "\n")
    print("built", served / "index.html", "; key in", run / "listening-key.json")


if __name__ == "__main__":
    main()
