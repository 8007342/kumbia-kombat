# Tasks

## 1. Timing (FEEL)

- [ ] 1.1 Compute heard time with the latency terms and clamp; verify unit tests with a fake clock and reported latencies of 0, 0.04, 0.9 (rejected) and absent
- [ ] 1.2 Timestamp presses from pointer events on the audio clock; verify a frame stall of 100 ms doesn't change a tap's delta
- [ ] 1.3 Add the tap-along calibration and per-device storage; verify that 12 synthetic taps at +60 ms give an offset of 60 ± 5, and that outliers past 150 ms are dropped
- [ ] 1.4 Add the bounded auto-nudge and the bias log; verify the cap and that it changes only at phrase boundaries

## 2. Charts (ALIGN)

- [ ] 2.1 Write the onset-alignment audit over rendered audio; verify it reports each level's share of required notes within 20 ms of an onset, and lists silent taps
- [ ] 2.2 Write the syncopation index and metric-position report per tier; verify on a hand-made all-on-beat and an all-off-beat fixture
- [ ] 2.3 Fix charts that fail; verify fairnessProblems is empty at each level's tempos, and the audit passes

## 3. Music

- [ ] 3.1 Write the seam report (bar-grid continuity, loudness jump, centroid jump, pitch-class overlap); verify on the current transitions and record the baseline
- [ ] 3.2 Report tension curves and peak placement per score; verify a fixture with an instrument entry at a tier boundary passes

## 4. Playtest

- [ ] 4.1 Run the protocol in `plan/research/rhythm-music-engagement-2026-11-07.md` section 10 with 6+ players; record the medians against the pass bars
