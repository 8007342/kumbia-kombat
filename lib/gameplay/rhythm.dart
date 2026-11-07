import 'gesture_shapes.dart';

enum Limb { leftHand, rightHand, leftFoot, rightFoot }

enum TapGrade { perfect, good, miss }

enum TapTiming { perfect, early, late }

enum FlourishDirection { up, right, down, left }

/// Times are audible-song milliseconds, after input/output calibration.
class RhythmNote {
  const RhythmNote(
    this.id,
    this.limb,
    this.atMs, {
    this.flourishTo,
    this.offer,
  });
  final String id;
  final Limb limb;
  final int atMs;
  final Limb? flourishTo;

  /// The move this note invites after its tap, if any. Taps alone are enough.
  final GestureKind? offer;
}

class TapResult {
  const TapResult(this.grade, this.note, {this.deltaMs = 0, this.timing});
  final TapGrade grade;
  final RhythmNote? note;
  final int deltaMs;
  final TapTiming? timing;
}

class RhythmJudge {
  RhythmJudge(List<RhythmNote> notes) : notes = List.unmodifiable(notes);
  static const perfectWindowMs = 75;
  static const goodWindowMs = 180;
  static const flourishWindowMs = 400;
  final List<RhythmNote> notes;
  final Set<String> _resolved = {};

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
    final signedDelta = audibleMs - closest.atMs;
    final isPerfect = distance <= perfectWindowMs;
    final timing = isPerfect
        ? TapTiming.perfect
        : (signedDelta < 0 ? TapTiming.early : TapTiming.late);
    return TapResult(
      isPerfect ? TapGrade.perfect : TapGrade.good,
      closest,
      deltaMs: signedDelta,
      timing: timing,
    );
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
