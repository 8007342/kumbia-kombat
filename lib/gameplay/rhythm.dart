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
  const TapResult(
    this.grade,
    this.note, {
    this.deltaMs = 0,
    this.timing,
    this.nearMissDeltaMs,
  });
  final TapGrade grade;
  final RhythmNote? note;
  final int deltaMs;
  final TapTiming? timing;

  /// A miss that was aimed at an open note: how far after it (negative is
  /// before). Null for a hit or a stray tap.
  final int? nearMissDeltaMs;
}

class RhythmJudge {
  RhythmJudge(List<RhythmNote> notes) : notes = List.unmodifiable(notes);

  /// A tap this close to its note, either way, is perfect. Was 75. 90 is
  /// StepMania's third grade (Great, ±90 ms at its default judge), on hardware
  /// with almost no input delay; a phone's touch screen alone varies by tens of
  /// milliseconds. See `plan/feel-2026-11-08.md` for every number here.
  static const perfectWindowMs = 90;

  /// How early a tap may come and still count. Was 180, which is StepMania's
  /// widest grade (Boo) at its default judge, on arcade pads with no latency.
  /// The extra 40 ms is for a phone: touch latency varies by device and frame.
  static const earlyWindowMs = 220;

  /// How late a tap may come and still count. Past it the note is missed. Was
  /// 200. Late gets more than early: every unmeasured delay on a phone (audio
  /// output the browser under-reports, the touch screen, a busy frame) makes a
  /// tap read late, never early. The auto-nudge then takes the steady part off.
  static const lateWindowMs = 260;

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

  /// How long after the last note a won room waits for a final swipe, on top
  /// of [flourishWindowMs]. The old late window, kept when the late window grew
  /// for phones: the exit, success music and bridge are timed from it. A swipe
  /// after a very late last tap only gets a little less time.
  static const settleLateMs = 200;

  /// How far outside the window a tap still reads as aimed at a note rather
  /// than stray. It never counts as a hit, and costs nothing. It's shown as a
  /// faint early or late mark, so the player sees which way they're off, and
  /// it tells the auto-nudge about a steady offset the window can't reach, as
  /// with Bluetooth headphones.
  static const nearEarlyMs = 400;
  static const nearLateMs = 500;

  /// Whether a tap [signedDeltaMs] after a note is aimed at it: in its window,
  /// or a near miss.
  static bool inReach(int signedDeltaMs) =>
      signedDeltaMs >= -nearEarlyMs && signedDeltaMs <= nearLateMs;

  /// Whether a tap [signedDeltaMs] after its note (negative is early) counts.
  static bool inWindow(int signedDeltaMs) =>
      signedDeltaMs >= -earlyWindowMs && signedDeltaMs <= lateWindowMs;

  final List<RhythmNote> notes;
  final Set<String> _resolved = {};

  /// Notes a tap took. An expired note isn't here, so a late near miss can
  /// still find it.
  final Set<String> _tapped = {};

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
    if (closest == null) {
      return TapResult(
        TapGrade.miss,
        null,
        nearMissDeltaMs: nearMiss(limb, audibleMs),
      );
    }
    _resolved.add(closest.id);
    _tapped.add(closest.id);
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

  /// The signed distance to the nearest open note of [limb] within reach, for
  /// a tap outside every window. Null when nothing is in reach.
  int? nearMiss(Limb limb, int audibleMs) {
    int? best;
    for (final note in notes) {
      if (_tapped.contains(note.id) || note.limb != limb) continue;
      final signed = audibleMs - note.atMs;
      if (!inReach(signed)) continue;
      if (best == null || signed.abs() < best.abs()) best = signed;
    }
    return best;
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
