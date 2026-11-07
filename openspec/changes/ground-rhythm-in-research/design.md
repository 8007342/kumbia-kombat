# Design

## Context

The judge (`lib/gameplay/rhythm.dart`) compares a press's `audibleMs` to note times,
with Perfect ±75 and Good ±180. The code has no latency term (no `outputLatency`, no
calibration). Spacing is checked per grip in `MoveLimits` (`garden_session.dart`):
same spot 285 ms, thumb hop 330, cross thumb 170, same limb 400. The spec still says a
flat 250 ms.

## Decisions

1. **Correct the centre, keep the width.** Research: NMA means humans are early by tens
   of ms (Repp 2005; Repp & Su 2013). Touchscreens add 50–200 ms (Deber et al. 2015).
   Android Chrome Web Audio adds 80 to 300+ ms on cheap phones (Chromium 40103372). Our
   Good ±180 is already wider than Arcaea's 100, osu! OD5's 150 and Rhythm Quest's 125.
   *Alternative rejected:* widening the late side permanently. It hides a fixable bias
   and makes Perfect unreachable for well-calibrated players.
2. **Heard time** = AudioContext time − (outputLatency + baseLatency, when reported and
   within 0–500 ms, else a platform default) − input latency default + user offset. The
   press time is the pointer event's timestamp, mapped to the audio clock, not the frame
   that handled it.
3. **Calibration in the Rhythm Quest and Rhythm Doctor shape:** tap along to a steady
   beat. The median signed asynchrony becomes the user offset. Shift the input, never
   the audio (the Guitar Hero method).
4. **Automatic nudge is bounded and slow** (after Hamlet: "intervene just enough so that
   system behavior is relatively stable and predictable"): half the residual median,
   at phrase boundaries, capped.
5. **Alignment checks are scripts, and quality claims are playtests.** Scripts can show
   that taps sit on onsets and that syncopation sits in a band. Only listeners can say a
   seam sounds natural, so each abstract requirement names a proxy *and* a protocol.

## Risks

- `outputLatency` misreports on some Android builds. Mitigation: the plausibility
  clamp, and calibration overrides it.
- The research quotations came through search snippets, because direct page fetches
  failed from the forge. Items marked "(memory, verify)" in the cheatsheet must be
  checked before they become thresholds.
- The pass-rate bands come from an educational game (Lomas 2013) and a model study
  (Wilson 2019), so they are starting values, not laws.
