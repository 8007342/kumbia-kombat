# mixrs

The memory-heavy and number-crunching parts of `tool/music/mix/mix.py`, in Rust. `mix.py` still
owns the config, the manifest, the report and the pass and fail rules, and calls this binary.
ffmpeg still does all encoding, decoding and ebur128 loudness.

    cargo build --release          # mix.py does this itself; put CARGO_TARGET_DIR off /home/forge/src
    cargo test --release
    MIXRS_THREADS=4                # the default

`MIX_ENGINE=python` runs the original Python, which is kept as the reference the comparison needs
and as the fallback if cargo is missing. `MIXRS=PATH` names a built binary. `MIXRS_LOG=FILE` appends
each run's wall time and peak.

## What happened

A 12-worker build took 11 GB of the forge's 12 GB and stalled everything for 20 minutes. The cause
was memory, not compute. Measured below, the biggest single items were:

- `hpss` over a whole take, for layered tiers: 2.8 GB added (median filters over a full spectrogram).
- `shelf_eq`'s whole-take FFT: 1.2 GB added.
- The parent process keeping every tier's grid and loop: 1.7 GB on the four-level config.
- Whole-take frame matrices in `beat_features` (380 MB), `onset_envelope` (190 MB) and the `fit_tempo` matrix (150 MB).

Twelve workers multiplied all of that except the parent.

## Before and after

Measured with `compare/peak_tree.py`, polling `/proc` every 50 ms, at one worker, with the machine
shared with other agents, so the times are approximate. "Tree" sums RSS across the process tree,
including the `uv` wrapper, the Python parent and any ffmpeg running. mixrs ran at 4 threads.

| Build | Engine | Wall | Largest process | Tree |
|---|---|---|---:|---:|
| bar (layered) | whole-take separation, as when the forge stalled | 44.8 s | 3446 MB | 3481 MB |
| bar | Python, MUSIC's cap (0392982) | 37.6 s | 1529 MB | 1912 MB |
| bar | **mixrs** | **16.2 s** | **185 MB** | **300 MB** |
| all five levels | Python, MUSIC's cap | 162.9 s | 1529 MB | 2114 MB |
| all five levels | **mixrs** | **66.2 s** | **240 MB** | **331 MB** |
| verify, all five | Python | 28.2 s | 431 MB | 465 MB |
| verify, all five | **mixrs** | **15.2 s** | **193 MB** | **227 MB** |

By level with mixrs (wall, largest, tree): garden 10.9 s, 159, 272 MB. pool-garden 14.3 s, 224, 313 MB.
bar 16.2 s, 185, 300 MB. cool-crowd 13.8 s, 167, 266 MB. billiards 12.0 s, 158, 285 MB.

**The 300 MB target:** mixrs itself peaks at 179 MB. The whole tree is 266 to 313 MB, so pool-garden
misses by 13 MB when the wrapper, the parent and ffmpeg are all counted. Its largest process (224 MB)
is the Python parent doing `cut_table`, which is still numpy.

The 12-worker case wasn't re-run, on purpose. Its 11 GB is MUSIC's measurement.

### By step

Python, whole-take separation, bar. Peak is the process's, "added" is what the step added on top.

| Step | Calls | Own time | Peak | Added |
|---|---:|---:|---:|---:|
| ffmpeg encode | 17 | 13.3 s | 820 MB | 65 MB |
| `_hpss_block` | 5 | 11.4 s | 3314 MB | 2839 MB |
| ffmpeg loudness | 32 | 6.5 s | 930 MB | 131 MB |
| `shelf_eq` | 5 | 3.9 s | 1769 MB | 1180 MB |
| ffmpeg decode | 45 | 3.2 s | 821 MB | 94 MB |
| `beat_features` | 5 | 1.6 s | 1105 MB | 381 MB |
| `wsola` | 6 | 1.2 s | 764 MB | 186 MB |
| `onset_envelope` | 10 | 1.1 s | 833 MB | 190 MB |
| `fit_tempo` | 10 | 0.7 s | 843 MB | 149 MB |

mixrs, all five levels. Peak leaves out ffmpeg, which is its own process.

| Subcommand | Runs | Total | Peak |
|---|---:|---:|---:|
| `prepare` | 22 | 36.4 s | 179 MB |
| `write-asset` | 25 | 25.4 s | 94 MB |
| `verify-take` | 30 | 10.7 s | 62 MB |
| `verify-segment` | 20 | 1.1 s | 8 MB |
| `bridge` | 4 | 0.5 s | 134 MB |
| `success` | 6 | 0.4 s | 68 MB |
| `transition` (garden and bar on the older config) | 10 | 1.2 s | 142 MB |

`tool/music/measure_takes.py` (0.31 s, 48 MB) and `tool/music/ladder_measures.py` (0.36 s, 226 MB) on
one take are neither hot nor large, so they aren't ported.

## How the memory went away

- Spectral analysis reads a frame, keeps the 25 numbers it needs and drops the spectrum. rayon works on
  batches of frames, each with its own small buffers, and all share one read-only take.
- Samples are f32. Sums, gains and FFT frames are f64, so the answers don't move.
- A tier's grid and loop wait on disk, on the cache disk, not in the parent. mix.py memory-maps the loop. A tag reads only its window of the grid.
- Separation works in the same 10 s blocks as mix.py. Only a window of the audio is ever separated.
- The shelf EQ uses overlap-save with 64k FFT blocks instead of one FFT of the whole take. Takes have awkward lengths, and that FFT alone took 700 MB in Rust. Against the whole-take FFT on a test signal the residual is -151 dB (`block_eq_matches_a_whole_take_fft`).
- WSOLA implies its padding and sums frame energies when asked, instead of keeping a running total of the take. It replaces the FFT correlation with a direct one, as splices are rare.

## Does it match the Python?

`compare/compare.py` on two full builds, with the same config, both engines. What was checked:

**Decisions: all equal, on 5 levels and on the 2 older levels.** Bar one, loop start, measured key,
splice count, entry bars, tag bars, decode offsets, total bars. Every value in `report.json` that comes
from analysis matched to its printed precision. `mix.py verify` gave 0 failures on both engines.

**Audio before encoding: residual under the signal.**

| Config | Assets | Median | Worst |
|---|---:|---:|---:|
| Five levels, layered | 25 | -146.7 dB | -45.6 dB, garden/high; the next worst is -144.4 dB |
| Older config, garden and bar, with transitions | 21 | -152.1 dB | -147.8 dB |

The limit in the script is -80 dB. **Garden/high is the one exception, and it's explained, not fixed:**
its ceiling came out at -1.9 dB in Python and -1.5 dB in Rust, because the decoded AAC peak fell on
different sides of the -0.3 dB limit. Both results are within the limit.

**Why the AAC numbers aren't held to tolerances:** ffmpeg's AAC encoder is deterministic but chaotic.
The same audio encoded twice nulls to -179 dB. The same audio with last-bit noise moves to -25 dB. So
Python's and Rust's AAC files differ audibly in a null test and may not differ to a listener; nobody
here can hear, so that part is a fair question for the owner. It also means the decoded AAC peak test
can flip on a rounding error, by up to 0.8 dB here, in either engine. That was already true of the
Python and comparing two engines is what exposed it.

Compare rules in full are at the top of `compare/compare.py`. Numeric tolerances were set after seeing
the first comparison, so they describe what was found rather than a bar set in advance. Decisions were
always required to be equal. In that first comparison the only numbers past the tolerances were on AAC
rows or on garden/high.

Tests: 12 in Rust, including a real take where the master exists. `mix.py --self-test` passes on both
engines. That needed one fix to a test failure that was already there: `verify_layers` found no window
on an 8-bar loop.

## Would a GPU help?

Not with this, and it wasn't tried: the forge has no general GPU route and none is coming soon.
Reasons, from the numbers above:

- The problem was memory, and streaming fixed it. A GPU has less memory, and it's shared with art jobs.
- The FFTs are small (1024 to 4096 points), and a transfer for each batch would cost about what the FFT does. That's my estimate, not a measurement.
- ffmpeg dominates the remaining time, and libopus, its AAC encoder and ebur128 have no GPU path. The bar level took 22.9 s on 1 thread, 14.7 s on 2, 16.2 s on 4 and 13.9 s on 8. Threads stop helping after 2, as the rest is ffmpeg.
- Where it could matter: real-time-scale neural work, such as source separation with a model instead of median filters. That's a different feature with a different question.

## Licences

All dependencies are permissive, by `cargo metadata`: 47 crates, MIT and Apache-2.0 mostly, one Zlib
(foldhash), one with Unicode-3.0 (unicode-ident). Direct: clap, num-complex, rayon, realfft, serde_json.

## Not done

- `cut_table`, `bar_features` and `verify_layers` stay in numpy. They now use the batched analysis, and they're the largest thing left.
- `join_lab.py`, `shared_grid.py` and `listen` stay in Python.
- rubato isn't used: the warp is mix.py's own WSOLA and the 22 kHz mono comes from ffmpeg.
