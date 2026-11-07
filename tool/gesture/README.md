# How the game reads a drawn stroke

The owner asked whether a little trained model, like sibling project Atrapa's, would make tap+drag easy to detect. This is the comparison, and why the game uses **templates**.

## What Atrapa actually uses

Not a JEPA, and nothing called JEV: neither word appears in its repository (shallow clone, read only, never run). It ships a plain feed-forward network, `atrapa-dense-v1`: 252 inputs, two ReLU layers of 64 and 32, 3 outputs, 18,371 parameters and about 73 KB. It's trained in pure Dart, first by imitating a scripted bot and then by REINFORCE self-play. Its `LocalPolicy` runs it in Dart with no plugin, which works on the web. It plays a game, so it has to learn a judgement no one can write down. Telling a line from a circle is a much smaller problem.

## Result

Seed 1852, `dart run tool/gesture/compare.dart`. Five moves, 10,000 strokes per set. Accuracy is the share of moves read as the shape that was drawn. All candidates share the same touch-slop check, so plain taps can't differ.

| Candidate | Held-out | Rougher than any training | Wild jitter earning a move | Size | Time on this machine |
|---|---|---|---|---|---|
| **Templates, shipped** | **99.98%** | **97.58%** | **32%** | 66 ideal paths, built from 13 numbers | 2.0 us native, 2.2 us JS |
| Rules on measures, numbers searched (the research's route) | 96.84% | 86.16% | 64% | 5 numbers | 3.5 us |
| Nearest neighbour, 40 samples a class | 96.08% | 94.94% | 64% | 200 samples | 8.5 us |
| Nearest neighbour, every training sample | 100.00% | 99.02% | 64% | 20,000 samples | 1,471 us |
| Trained, 16 hidden, on headings | 99.96% | 96.86% | 64% | 613 parameters, 2.4 KB | 2.9 us |
| Trained, 16 hidden, on positions | 99.99% | 98.71% | 64% | 645 parameters, 2.6 KB | 3.5 us |
| Trained, 32 hidden, on positions | 99.98% | 98.82% | 64% | 1,285 parameters, 5.1 KB | 4.0 us |
| Trained, 16 hidden, on measures | 100.00% | 98.50% | 64% | 213 parameters, 0.9 KB | 3.6 us |

Plain taps and thumb roll earned nothing for any candidate, in either set: 0 of 2,000. That's by construction, because those strokes stay under the 24-pixel slop line. The wild-jitter column is the honest test of that line: a shaky thumb wandering up to 40 pixels, which no real press should do. Only the templates have a score to refuse it with. The networks could have one added.

Times are for the JIT `compare.dart`, except the first row's, from `bench.dart` compiled with `dart compile exe` and `dart compile js`, run under Node. No phone was available. Even at 20 times slower that's about 44 us, against a 16,667 us frame, and the live stroke only reads every 6 pixels. It allocates nothing but its answer. There are no weights and no asset.

The shipped templates' confusion, held-out then rough. Rows are what was drawn:

```
held-out  spin  flick   wave  stomp circle   none
spin      2000      0      0      0      0      0
flick        0   2000      0      0      0      0
wave         0      0   2000      0      0      0
stomp        0      0      0   1998      2      0
circle       0      0      0      0   2000      0
none         0      0      0      0      0   2000

rough     spin  flick   wave  stomp circle   none
spin      1936      2     62      0      0      0
flick        1   1931     68      0      0      0
wave         8      6   1957      0     24      5
stomp        0      6      1   1970     15      8
circle       0     29      1      0   1964      6
none         0      0      0      0      0   2000
```

## Why templates, when a network scored higher

On the rough set the best small network reads 1.1 points more. That's real, not noise. It's still not worth having, for four reasons:

- **The gap barely reaches the player.** Moves are pass or nothing, and any move on an eligible note earns the same credit. Over half the templates' rough errors are a line curved up to 75 degrees read as a wave. That's the wrong flourish, not a lost one. A drawn move earning nothing happened 19 times in 10,000. Nine of those are the slop line every candidate shares, and the other 10 are the price of refusing wild jitter, which is what the 32% column buys.
- **A network here learns my generator.** Every stroke comes from `synth.dart`. The rough column says little about real thumbs for either, and a network has more room to fit my assumptions.
- **Real strokes are cheaper to add.** A captured stroke that's misread can become one more template, with no retraining, and anyone can draw what the templates are.
- **It reads partial strokes without having trained on them.** A move lands as soon as its shape is complete, so the recogniser runs on growing strokes. Templates just work on those. A network would need them in its training set.

The research report's rules came last, as the owner's "weird juggling" warned they might: a curved thumb defeats them. The report's reasons for rules were that the game only verifies an offered shape, and that each leg could light up live. The first is kept, because a move lands early only if it's what was offered. The second isn't: nothing lights per leg yet, and the trail flares when the shape lands.

If real thumbs show a gap that matters, `train.py` is ready and needs no PyTorch.

## What the numbers can't say

**Nothing here has touched a phone or a person.** All strokes are synthetic: size, arcs, wobble, hooks, noise and timing come from my guesses, and the rough set is only my guess made rougher. Before trusting these, on an iPhone and an Android phone, with one and two thumbs:

- Open the game with `?capture=gestures`, draw what it asks, press Copy, and save it. `dart run tool/gesture/compare.dart --real captured.json` then gives the same table for real strokes. Nothing leaves the phone unless pasted.
- How a real thumb arcs on a sideways drag. It decides how often a spin reads as a wave, which is the most common error above.
- Whether a wave or circle fits in time at 160 BPM. The research's times come from a pen model.
- Whether anyone notices the invitation without being told. Only a person can say whether the drawn paths answer "still not clear".

## Reproducing it

The data file comes from the tuner, and only ever sees the tuning set. The rough set is drawn only by `compare.dart`.

```sh
dart run tool/gesture/tune.dart        # writes lib/gameplay/gesture_data.g.dart
OUT=~/.cache/tillandsias-project/gesture
dart run tool/gesture/compare.dart --export "$OUT"
uv run tool/gesture/train.py --data "$OUT" --features positions --hidden 16 --out "$OUT/positions-16.json"
dart run tool/gesture/compare.dart --mlp "$OUT/positions-16.json" --confusion
dart compile exe tool/gesture/bench.dart -o "$OUT/bench" && "$OUT/bench"
```

Keep outputs out of the source tree: the forge's disk for it is small. No weights are committed, because no trained model ships.

| File | What it is |
|---|---|
| `synth.dart` | The stroke generator, the one source of all data |
| `tune.dart` | Searches the template family on the tuning set and writes the data file |
| `compare.dart` | The table above, and `--real` for captured strokes |
| `train.py` | The small network, in numpy alone |
| `rules.dart` | The research's rules, kept only for this comparison |
| `bench.dart` | Time per stroke, compiled |
