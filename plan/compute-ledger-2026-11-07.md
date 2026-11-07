# Compute ledger, 2026-11-07: cloud against local

Refreshed 2026-11-07 14:07 UTC after the party and billiards merged into `game`. The first report, taken mid-batch, said 3h32m, 339 images and 30 takes. To refresh again, run `tool/metrics/ledger.py`, and `tool/metrics/ledger.py --json > plan/compute-ledger-2026-11-07.json` for the job-level record. The full table is at the end of this note.

## The short answer

- **Pictures and music:** every image and audio generation job in these transcripts ran on the local GPU. No cloud image or audio generator appears among the tools called.
- **Local GPU:** 9h35m of image model running and 15 minutes of audio model running, over a 15h04m session, for 1,009 image outputs and 79 audio outputs. Queue waits add 3 hours. The checkouts' own `plan/compute-ledger.jsonl` lines, which also count the agents' worktrees, record 19h27m of image GPU work.
- **Cloud:** still doing all the orchestration: 17 agents, 1,729 replies, 2.49 million output tokens. At least one cloud model was generating for 3h47m of the 15h04m.
- **Cloud vision:** 297 images read into a cloud model, about 400,000 tokens on first reading.
- **Local vision:** 347 ledger lines covering 751 checks, 53 minutes of local model time. It works as a pre-filter that counts heads and hands in a crop of one figure. It still misses things a person sees, such as a second head drawn on a coat or a four-armed frame, so the final picks were still made by eye, which means the cloud.

## What's in `assets/` today

On `game` after the party and billiards merges.

| Source | Files | Size |
| --- | --- | --- |
| Local model, music | 50 (25 takes, each in two codecs) | 31.7 MB |
| Local model, art | 86 | 13.3 MB |
| Local model editing an older built-in imagegen plate | 4 | 5.1 MB |
| Built-in imagegen from earlier sessions, not this GPU | 15 | 26.2 MB |

So of 76 MB of generated art and audio, 59% is purely local, 7% is local edits and 34% is older imagegen art. All the rendered music is local. Those 15 imagegen files are the remaining cloud-era art, including Mācron's own sprites and the original party guests.

Sorting is by run and commit, in `tool/metrics/asset_provenance.json`, not by checking each pixel. Nothing is unclassified now: the band, BlinBlin, guests, pool players, billiards plate and props have rules. New art needs a line in that file or it will be unclassified.

## What's measured and what isn't

**Measured:** tokens as the API reported them, tool calls, images returned to a cloud model, timestamps, and the `elapsed_s` and `stages_ms` of the 27 image and audio jobs whose results appear in a transcript.

**Proxy:** cloud compute time isn't knowable from here. Tokens and "model wait" stand in for it. Model wait is the time from a request to its reply, so it includes network, retries and Anthropic's own queueing. It says nothing about the hardware used. There are no dollar or energy figures, because none are known.

**Estimates:**
- 71 of the 93 image jobs were queued and never polled to the end, so they're known only from their job folder. Their GPU time comes from the gaps between output files. Against the 22 jobs where both figures exist, this reads about 20% low, because it misses the first image's model load. So the 2 hours is a slight undercount.
- Queue wait is only known for jobs in a transcript, so the real wait is higher than the 48m45s shown.
- Image tokens are width x height / 750.

**Not covered:**
- Sessions before this one. Their transcripts aren't on disk, so all earlier work has no cloud figures and no GPU time.
- Earlier outputs are only partly counted. The all-time count of 655 images and 127 takes (178.8 minutes) covers only outputs whose provenance file survives. Earlier raw art is largely gone.
- Local CPU work (mixing, pixel finishing, builds) unless an agent logged it. Bash wall time of 3h14m is the nearest figure, and it's poor: it includes builds and waiting, and background commands count as nothing.
- Local vision run outside `vision.py`. 12 Bash commands called the model or the helper, and those using the one-liner in the brief left no ledger line.

**This record can be lost.** Job folders are deleted when the forge shuts down, and earlier transcripts have already gone. That's why the JSON snapshot is committed. It should be rerun before any shutdown.

## How good is the local vision model?

`qwen2.5vl:7b`, 58 calls. The right answers are my own reading of the images. It's a small sample, run once each at temperature 0, so treat it as a guide.

| Test | Result |
| --- | --- |
| Whole sheet, BlinBlin pass 1, with its obvious B0 fault | **Failed 3 of 3.** "Any faults?" gave all clear. Told one was faulty, it invented a missing arm on B2. Asked about a small man, it said B1. |
| One figure, "is there an anatomy fault?" | Found B0. Missed a pasted extra arm and hand. For a pasted second head it answered "NO... with a second head attached". No false alarms on 13 clean figures. |
| One figure, "how many heads?" | **7 of 7**, including B0 and the pasted head. |
| One figure, "how many hands?" | 5 of 6 exact. The clean figures all got 2 and B0 got 4. The pasted arm got 4 when I count 3, which would still flag it. |
| Body seen from front or back | 8 of 8. On B0 it said back, which is true of the large figure, and didn't mention the small one. |
| Is the face visible? | **4 of 9.** It misses heads turned on back views, such as B2's clear profile, and said F2's face was hidden. This is the "wrong facing" fault, and it can't be relied on. |
| Legs crossed | 9 of 10, with one false yes. All four positives are the same seated pose, so this is weak evidence. It doesn't show it can spot *oddly* crossed legs. |
| Which way is the finger pointing? | 4 of 4, including a mirrored copy as a control. |

**How to use it:**
- Crop to one figure. Don't give it whole sheets.
- Ask it to count heads and hands, and flag anything other than 1 and 2.
- Use direct questions for crossed legs and pointing.
- Look yourself at any turned-head check, and at anything a count flags.
- A clean result isn't a pass. Only a few real faults were tried, and a missing limb wasn't tried at all.

The two pasted faults are crude cut-and-paste jobs, which should be easier than real ones. B0 is the only real anatomy fault in the test.

**Speed:** 2.6 seconds per call on average, 4.4 at most, and under a second for many counting answers. That's about 15 tokens per second, with the model already on the GPU. The cold load time wasn't measured, because the model was already loaded for every call. `vision.py` releases the GPU: `/api/ps` was empty after its `keep_alive 0` call.

The one-liner in the brief sets no `keep_alive`, so it uses ollama's default. The model was holding 9.4 to 9.8 GB when I checked, though I can't say whose call left it there. Studio jobs evict it themselves, so this isn't a blocker. `vision.py` is still the better choice, because it also leaves a ledger line.

## Full table

```
Compute ledger, measured 2026-11-07T02:35:21+00:00
Measured: tokens, tool calls, images, timestamps, studio job times. Proxy for cloud compute: tokens and
waiting on the model. Estimate: image tokens; GPU time of jobs known only from their folder. No costs.

CLOUD, 1 session(s) on disk, 16 agents. Earlier sessions' transcripts are gone, so they aren't here.
agent     label                                  msgs  input   cache read  cache write     output       span  model wait  tools  images
--------  -------------------------------------  ----  -----  -----------  -----------  ---------  ---------  ----------  -----  ------
main      main                                    162    394   48,386,686      476,368    198,343   3h27m50s    0h31m26s    307      17
a5cbcbdb  Rendered music in the game              126    318   31,249,465      862,440    187,108   1h29m01s    0h29m17s    187       4
a6ed5545  Band sprite family art (GPU)            105    224   24,604,090      570,903    149,143   1h53m15s    0h24m12s    152      24
a2066dfe  Indoor plate and room layers (GPU)       94    204   23,558,045      588,065    129,759   1h22m04s    0h20m29s    169      40
aabf0680  BlinBlin full sprite wave (GPU)          84    188   19,985,157    1,176,811    118,903   2h10m29s    0h17m55s    115      14
a6a80bff  Double taps and paired-spot charts       54    114   10,026,528      286,593    133,768   0h29m07s    0h20m33s     62       2
aff31ce4  Indoor party level with dancing crowd    40     86    9,919,285      626,349    123,956   1h10m49s    0h18m55s     51       9
a38ab185  Offline mixing and loop assets           38     90    6,221,246      456,775    123,334   1h00m46s    0h19m25s     44       0
aeed335a  Party-up by tier and hardest combos      32     66    5,668,189      225,071     79,156   0h16m44s    0h12m04s     45       8
a08bc6e7  Unified style guide, cinematic rules     27     60    4,080,017      210,649     62,607   0h11m01s    0h09m33s     39       5
aed49975  Finish and wire indoor party level       22     52    2,496,828      168,560     35,097   0h06m50s    0h05m20s     33       0
a65304d4  Build and wire billiards level           19     46    2,444,350      192,425     34,062   0h06m10s    0h05m44s     31       1
af7c4e67  Party people review and pairs            16     38    1,719,453      156,964     32,491   0h06m20s    0h05m08s     26       5
ae4812ba  Pool Player sprites (GPU)                17     42    1,572,542      132,341     27,108   0h06m16s    0h04m12s     26       1
a35d4ebb  Compute ledger, cloud versus local       17     34    1,344,461      118,775     48,246   0h07m52s    0h07m21s     27       5
a7f9f2b7  Music method and pool room theme          9     24      785,722      139,939     13,220   0h02m12s    0h02m04s     26       0
TOTAL                                             862  1,980  194,062,064    6,389,028  1,496,301  14h06m53s    3h53m46s   1340     135

Wall clock, first event to last: 3h31m59s. At least one model generating: 1h42m34s.
Agent spans and model waits overlap, so their totals exceed the wall clock.

model            input   cache read  cache write     output
---------------  -----  -----------  -----------  ---------
claude-opus-5-5  1,980  194,062,064    6,389,028  1,496,301

CLOUD VISION: 135 images returned to a cloud model, 117 distinct sources, 38.5 MB.
About 206,551 tokens on first reading (estimate, w x h / 750), already inside the totals above.
Rereading them from cache each later turn is inside cache read and can't be split out.
Images pasted into prompts, counted apart: 0.
source     images
---------  ------
Read .png     135

TOOL CALLS. Wall is call to result, so it includes queueing, and background commands return at once.
tool                                 calls      wall
-----------------------------------  -----  --------
Bash                                   783  3h18m38s
Read                                   166  0h04m22s
browser_cdp                             65  0h01m01s
SendMessage                             62  0h47m07s
browser_eval                            57  0h04m04s
studio_queue_workflow                   31  0h00m24s
ToolSearch                              27  0h00m03s
studio_run_workflow                     26  5h32m10s
studio_job_status                       21  0h00m34s
browser_screenshot                      18  0h00m39s
Agent                                   15  0h00m00s
browser_navigate                        10  0h00m22s
browser_open                             7  0h06m37s
browser_close                            7  0h00m02s
gpu_status                               6  0h01m53s
SendUserFile                             5  0h00m52s
Write                                    4  0h00m00s
ListAgents                               3  0h00m00s
preview_status                           3  0h00m12s
studio_models                            3  0h00m03s
studio_status                            3  0h00m00s
browser_console_tail                     2  0h00m00s
TaskStop                                 2  0h00m00s
Monitor                                  2  0h00m03s
WebSearch                                2  0h00m12s
WebFetch                                 2  0h00m00s
tillandsias_lane_version                 1  0h00m00s
studio_start                             1  0h00m08s
preview_publish                          1  0h00m03s
Skill                                    1  0h03m00s
tillandsias_index                        1  0h00m00s
mcp__project-info__sibling_projects      1  0h00m00s
studio_finish_pixels                     1  0h00m03s
mcp__forge-plan__msg_recv                1  0h00m00s

LOCAL GPU, one row per kind. GPU run excludes queue wait; elapsed includes it.
kind   jobs  outputs   GPU run  queue wait   elapsed     audio  jobs with estimated run
-----  ----  -------  --------  ----------  --------  --------  -----------------------
audio     5       30  0h05m42s    0h00m00s  0h05m42s  42.3 min                        0
image    93      339  1h53m10s    0h48m45s  6h08m51s                                 71

Submissions refused or failed before running: 5.

run                           jobs  outputs   GPU run
----------------------------  ----  -------  --------
blinblin-v1-20261107c           34      134  0h46m01s
blinblin-v1-20261107a            8       32  0h10m34s
ace-xl-turbo                     5       30  0h05m42s
layers                          11       22  0h05m41s
band-bass-v1-20261107a           3       12  0h04m00s
band-bass-v1-20261107b           2        8  0h03m27s
blinblin-20261106a               2        8  0h03m04s
blinblin-v1-20261107b            2        8  0h02m51s
band-bass-3q-20261107b           2        8  0h02m42s
pool-player-20261107a            2        8  0h02m35s
billiards                        3        8  0h02m28s
blinblin-20261106b               2        8  0h01m56s
cool-crowd                       3        7  0h01m53s
band-bass-sheet-20261107b        1        4  0h01m37s
band-bass-sheet-20261107a        1        4  0h01m32s
band-congas-sheet-20261107a      1        4  0h01m24s
band-marimba-sheet-20261107a     1        4  0h01m23s
band-congas-3q-20261107b         1        4  0h01m23s
band-trumpet-sheet-20261107a     1        4  0h01m23s
band-marimba-sheet-20261107c     1        4  0h01m22s
band-congas-sheet-20261107b      1        4  0h01m22s
band-marimba-sheet-20261107b     1        4  0h01m21s
band-trumpet-sheet-20261107b     1        4  0h01m21s
band-marimba-sheet-20261107d     1        4  0h01m21s
band-marimba-3q-20261107a        1        4  0h01m21s
band-trumpet-3q-20261107b        1        4  0h01m19s
band-congas-3q-20261107a         1        4  0h01m19s
band-marimba-3q-20261107b        1        4  0h01m18s
band-trumpet-3q-20261107a        1        4  0h01m18s
band-bass-3q-20261107a           1        4  0h01m18s
band-congas-3q-20261107c         1        4  0h01m17s
crowd-props                      1        4  0h01m07s

LOCAL, plan/compute-ledger.jsonl across checkouts. gpu-* lines repeat the jobs above and aren't added to them.
kind          lines  items   seconds
------------  -----  -----  --------
local-vision      3     58  0h02m15s

Bash commands calling the local vision model: 12. Without vision.py they leave no ledger line.

ALL-TIME LOCAL OUTPUTS with a provenance file, by content, 2026-11-06T19:11:27Z to 2026-11-07T02:34:58Z:
655 images, 127 audio takes, 178.8 min read from FLAC headers (0 takes unreadable).
No compute time exists for those made before this session's transcripts.

IN assets/, media files only, classified by tool/metrics/asset_provenance.json:
Named = the file's name appears in lib/, levels/, a manifest or pubspec.yaml, which doesn't prove it's on screen.
Each rendered music take ships twice, as .m4a and .ogg.
class / medium                files    bytes  named files  named bytes
----------------------------  -----  -------  -----------  -----------
local-model / audio              80  29.0 MB           80      29.0 MB
builtin-imagegen / art           15  27.4 MB           13      23.8 MB
local-model / art                47   8.5 MB           46       7.6 MB
local-edit-of-imagegen / art      4   5.1 MB            4       5.1 MB
reference-not-shipped / art       1   2.8 MB            0       0.0 MB
authored-code / audio            44   0.3 MB           14       0.0 MB
third-party / art                 1   0.2 MB            1       0.2 MB
unclassified / art                3   0.0 MB            3       0.0 MB
authored-code / art               4   0.0 MB            0       0.0 MB

Unclassified: assets/art/props/bar.png, assets/art/props/garden.png, assets/art/props/pool-garden.png
```
