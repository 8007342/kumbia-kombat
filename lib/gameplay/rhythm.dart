import 'dart:math' as math;

enum Limb { leftHand, rightHand, leftFoot, rightFoot }

enum TapGrade { perfect, good, miss }

/// Times are audible-song milliseconds, after input/output calibration.
class RhythmNote {
  const RhythmNote(this.id, this.limb, this.atMs, {this.flourishTo});
  final String id;
  final Limb limb;
  final int atMs;
  final Limb? flourishTo;
}

class TapResult {
  const TapResult(this.grade, this.note);
  final TapGrade grade;
  final RhythmNote? note;
}

class RhythmJudge {
  RhythmJudge(List<RhythmNote> notes) : notes = List.unmodifiable(notes);
  static const perfectWindowMs = 45;
  static const goodWindowMs = 110;
  static const flourishWindowMs = 300;
  final List<RhythmNote> notes;
  final Set<String> _resolved = {};
  final Set<String> _flourished = {};
  final Map<String, int> _successfulTapAt = {};
  int pizazz = 0;

  TapResult tap(Limb limb, int audibleMs) {
    RhythmNote? closest;
    var distance = goodWindowMs + 1;
    for (final note in notes) {
      final delta = (note.atMs - audibleMs).abs();
      if (!_resolved.contains(note.id) &&
          note.limb == limb &&
          delta < distance) {
        closest = note;
        distance = delta;
      }
    }
    if (closest == null) return const TapResult(TapGrade.miss, null);
    _resolved.add(closest.id);
    _successfulTapAt[closest.id] = audibleMs;
    return TapResult(
      distance <= perfectWindowMs ? TapGrade.perfect : TapGrade.good,
      closest,
    );
  }

  /// Gesture recognizer supplies the destination of a release, never a tap.
  bool flourish(String noteId, Limb destination, int audibleMs) {
    final tappedAt = _successfulTapAt[noteId];
    if (tappedAt == null || _flourished.contains(noteId)) return false;
    final note = notes.firstWhere((note) => note.id == noteId);
    if (note.flourishTo != destination ||
        audibleMs <= tappedAt ||
        audibleMs - tappedAt > flourishWindowMs) {
      return false;
    }
    _flourished.add(noteId);
    pizazz += 100;
    return true;
  }

  List<RhythmNote> expire(int audibleMs) {
    final missed = notes
        .where(
          (note) =>
              !_resolved.contains(note.id) &&
              audibleMs > note.atMs + goodWindowMs,
        )
        .toList();
    _resolved.addAll(missed.map((note) => note.id));
    return missed;
  }
}

class NotePoint {
  const NotePoint(this.x, this.y);
  final double x;
  final double y;
}

/// Normalized screen coordinates. A bounded curve cannot cross into another
/// quadrant: the destination remains readable even while the trail twists.
NotePoint tornadoPosition(
  Limb limb,
  double progress, {
  bool reducedMotion = false,
}) {
  final t = progress.clamp(0.0, 1.0);
  final left = limb == Limb.leftHand || limb == Limb.leftFoot;
  final upper = limb == Limb.leftHand || limb == Limb.rightHand;
  final twist = reducedMotion ? 0.0 : math.sin(t * math.pi * 2) * .025;
  final dx = .05 + .36 * t;
  final dy = .05 + .35 * t;
  return NotePoint(
    .5 + (left ? -dx : dx) + twist,
    .5 + (upper ? -dy : dy) - twist,
  );
}
