import 'dart:math' as math;

import 'garden_session.dart';
import 'rhythm.dart';

/// Which ring a touch belongs to. This only picks the limb to hand the session:
/// the session and its judge still decide timing, score and which note of that
/// limb is consumed, so nothing here can move the music, the notes or the score.

/// The least reach of a ring's tap area, in logical pixels, from the ring's
/// centre, on any phone. Material's touch target is 48 across and Apple's is 44.
/// A circle 144 across is three of Material's targets, and a clumsy thumb that
/// lands a whole thumb's width off its ring still counts.
const tapAreaRadiusFloor = 72.0;

/// On wider phones the rings spread with the screen, so the areas do too.
const tapAreaWidthShare = .2;

/// How far a tap may land from a ring's centre and still count.
double tapAreaRadius(double width) =>
    math.max(tapAreaRadiusFloor, width * tapAreaWidthShare);

/// A ring a tap could belong to right now.
class TapCandidate {
  const TapCandidate(this.limb, this.landing, this.timingOffMs);
  final Limb limb;
  final NotePoint landing;

  /// How far the note is from the tap in time, in milliseconds, either way.
  final int timingOffMs;
}

/// The response notes a tap could be judged against now. Uses the judge's own
/// millisecond rounding and window, and leaves out demonstrations.
List<TapCandidate> openTapCandidates({
  required Iterable<GardenCue> cues,
  required int nowMs,
  required double Function(double beat) secondsAt,
  required NotePoint Function(GardenCue cue) landing,
}) {
  final open = <TapCandidate>[];
  for (final cue in cues) {
    if (cue.demo) continue;
    final off = ((secondsAt(cue.beat) * 1000).round() - nowMs).abs();
    if (off <= RhythmJudge.goodWindowMs) {
      open.add(TapCandidate(cue.limb, landing(cue), off));
    }
  }
  return open;
}

/// The nearest ring whose area holds the point. Areas of different limbs overlap
/// by design, and nearest splits them down the middle. Equal distances go to the
/// note closer in time. Null means the tap was stray: it must cost nothing.
TapCandidate? resolveTap({
  required double x,
  required double y,
  required double radius,
  required Iterable<TapCandidate> candidates,
}) {
  if (!x.isFinite || !y.isFinite) return null;
  TapCandidate? best;
  var bestDistance = double.infinity;
  for (final candidate in candidates) {
    final dx = x - candidate.landing.x;
    final dy = y - candidate.landing.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > radius) continue;
    if (distance < bestDistance ||
        (distance == bestDistance &&
            candidate.timingOffMs < best!.timingOffMs)) {
      best = candidate;
      bestDistance = distance;
    }
  }
  return best;
}
