enum Limb { leftHand, rightHand, leftFoot, rightFoot }

enum TapGrade { perfect, good, miss }

enum TapTiming { perfect, early, late }

enum FlourishDirection { up, right, down, left }

/// Times are audible-song milliseconds, after input/output calibration.
class RhythmNote {
  const RhythmNote(this.id, this.limb, this.atMs, {this.flourishTo});
  final String id;
  final Limb limb;
  final int atMs;
  final Limb? flourishTo;
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

  /// Gesture recognizer supplies the destination of a release, never a tap.
  bool flourish(String noteId, Limb destination, int audibleMs) {
    final note = notes.where((note) => note.id == noteId).firstOrNull;
    if (note == null || note.flourishTo != destination) return false;
    return flourishGesture(noteId, audibleMs);
  }

  /// A local directional flick decorates an eligible accepted tap. Its direction
  /// selects the performance, not another input zone or a future required note.
  bool flourishGesture(String noteId, int audibleMs) {
    final tappedAt = _successfulTapAt[noteId];
    if (tappedAt == null || _flourished.contains(noteId)) return false;
    final note = notes.firstWhere((note) => note.id == noteId);
    if (note.flourishTo == null ||
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
