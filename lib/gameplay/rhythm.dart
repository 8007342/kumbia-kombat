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

  /// A tap this close to its note, either way, is perfect. Unchanged: it is
  /// already wider than most rhythm games' best grade. See
  /// `plan/feel-2026-11-07.md` for every number here.
  static const perfectWindowMs = 75;

  /// How early a tap may come and still count. Unchanged at 180: people tap a
  /// little ahead of a beat, never far ahead.
  static const earlyWindowMs = 180;

  /// How late a tap may come and still count. Past it the note is missed. Was
  /// 180. The extra 50 ms covers what the latency estimate gets wrong (browsers
  /// report it roughly, some not at all) until there is a tap calibration.
  static const lateWindowMs = 230;

  /// The wider side of the good window: how long a note stays open after its
  /// beat, and the most either side that any tap is judged against it.
  static const goodWindowMs = earlyWindowMs > lateWindowMs
      ? earlyWindowMs
      : lateWindowMs;

  /// The part of a tap's window, either side, that a chart keeps clear of
  /// anything else: an optional move offered between two notes, or the end of
  /// the phrase. It stays at the old 180 ms good window, so widening the window
  /// for phones took no moves away and broke no chart. The rest is best effort:
  /// a tap there can share time with a move, which only costs the move, and the
  /// last note's may be cut by the phrase's end, which costs nothing the old
  /// window gave.
  static const guaranteedWindowMs = 180;
  static const flourishWindowMs = 400;

  /// Whether a tap [signedDeltaMs] after its note (negative is early) counts.
  static bool inWindow(int signedDeltaMs) =>
      signedDeltaMs >= -earlyWindowMs && signedDeltaMs <= lateWindowMs;

  final List<RhythmNote> notes;
  final Set<String> _resolved = {};

  TapResult tap(Limb limb, int audibleMs) {
    RhythmNote? closest;
    var distance = goodWindowMs + 1;
    for (final note in notes) {
      final signed = audibleMs - note.atMs;
      final delta = signed.abs();
      if (!_resolved.contains(note.id) &&
          note.limb == limb &&
          inWindow(signed) &&
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
              audibleMs > note.atMs + lateWindowMs,
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
