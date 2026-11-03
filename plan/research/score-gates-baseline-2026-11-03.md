# Complexity gate baseline, shipped scores (2026-11-03)

`node tool/music/compose/gates.mjs --report` on `assets/music` as shipped. The gates
measure patterns in note data. They say nothing about how these scores sound, and
nobody has listened to this comparison.

All five shipped scores fail, as design D3 predicted.

| Score | Pitched bars repeating | Melody bars repeating | Lead phrases distinct | Answer phrases distinct | Chord roots | Section progressions | Independence |
|---|---:|---:|---:|---:|---:|---:|---:|
| garden_mojo | 0.922 | 0.854 | 0.125 | 0.188 | 4 | 1 | 0.837 |
| bar_swag | 0.922 | 0.854 | 0.125 | 0.188 | 4 | 1 | 0.875 |
| crowd_duende | 0.914 | 0.833 | 0.188 | 0.188 | 3 | 1 | 0.836 |
| restroom_nerve | 0.828 | 0.667 | 0.375 | 0.375 | 3 | 1 | 0.859 |
| vip_presence | 0.914 | 0.833 | 0.188 | 0.188 | 4 | 1 | 0.777 |

"Repeating" counts a bar that copies or transposes an earlier bar in the same track.
Bass and guitar are at 0.94–0.97 in every score: one pattern, transposed.

Where the shipped scores already pass: independence (limit 0.55), lead pitch entropy
(0.59–0.72, limit 0.45), and lead bar rhythms (4 each, limit 4, so barely). Tier
density mostly passes; crowd_duende (1.048) and vip_presence (1.041) miss the 1.05
step at tier 3, and restroom_nerve's tier 3 is the one velocity failure (0.545).

The thresholds in `gates.mjs` are starting values chosen after seeing these numbers,
so that failure of the shipped scores is partly by construction. They separate
"one transposed pattern" from "varied writing"; listening decides where they settle.
