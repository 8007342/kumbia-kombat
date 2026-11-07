import 'dart:math' as math;

import 'garden_session.dart';
import 'gesture_recognizer.dart';
import 'gesture_shapes.dart';
import 'rhythm.dart';

enum StrokeState { tracing, landed, faded }

/// One thumb's path after an accepted tap, in logical pixels. The page draws it.
class DanceStroke {
  DanceStroke(this.pointer, this.noteId, this.limb, this.offer, double x, double y)
    : xy = [x, y];
  final int pointer;
  final String noteId;
  final Limb limb;
  final GestureKind? offer;
  final List<double> xy;
  StrokeState state = StrokeState.tracing;
  double? endedAt;

  /// Length in pixels when it was last read, so a live stroke isn't read on
  /// every coalesced event.
  double _readAtLength = 0;
  double _length = 0;
}

/// A stroke that amounts to a move. Nothing has been credited yet: pass it to
/// [landStroke].
class DanceStrokeResult {
  const DanceStrokeResult(this.stroke, this.kind, this.direction);
  final DanceStroke stroke;
  final GestureKind kind;
  final FlourishDirection direction;
}

/// Hands a recognised stroke to the session, and says how it ended for drawing.
OptionalMove? landStroke(GardenSession session, DanceStrokeResult result) {
  final move = session.optionalMove(
    result.stroke.noteId,
    result.kind,
    result.direction,
  );
  result.stroke.state = move == null ? StrokeState.faded : StrokeState.landed;
  return move;
}

/// Tracks optional movement after an already judged pointer-down tap. It sits
/// behind the tap: a tap's time is the press and its ring was decided then, so
/// nothing here can create, move or take away a required note. Distances are
/// logical pixels, independent of screen resolution.
class DanceTouchGestures {
  DanceTouchGestures({GestureRecognizer? recognizer, double Function()? clock})
    : _recognizer = recognizer ?? GestureRecognizer.shipped,
      _clock = clock ?? (() => 0);

  /// Long enough for the trail to crumble or flare.
  static const fadeSeconds = .35;

  /// Plenty for any stroke in its time limit, and a bound on a stuck pointer.
  static const _pointLimit = 256;
  static const _readEveryPixels = 6.0;

  final GestureRecognizer _recognizer;
  final double Function() _clock;
  final _live = <int, DanceStroke>{};
  final _ended = <DanceStroke>[];

  /// Everything worth drawing right now, oldest first.
  Iterable<DanceStroke> get strokes sync* {
    yield* _ended;
    yield* _live.values;
  }

  Iterable<DanceStroke> get live => _live.values;

  void begin({
    required int pointer,
    required double x,
    required double y,
    required RhythmNote? acceptedNote,
  }) {
    _live.remove(pointer);
    if (acceptedNote?.flourishTo == null || !x.isFinite || !y.isFinite) return;
    _live[pointer] = DanceStroke(
      pointer,
      acceptedNote!.id,
      acceptedNote.limb,
      acceptedNote.offer,
      x,
      y,
    );
  }

  /// Adds a point. Returns a result as soon as the offered shape is complete:
  /// the thumb needn't lift, so one held a moment too long can't lose the move.
  DanceStrokeResult? move({
    required int pointer,
    required double x,
    required double y,
  }) {
    final stroke = _live[pointer];
    if (stroke == null || !x.isFinite || !y.isFinite) return null;
    _add(stroke, x, y);
    if (stroke.offer == null ||
        stroke._length - stroke._readAtLength < _readEveryPixels) {
      return null;
    }
    stroke._readAtLength = stroke._length;
    final reading = _recognizer.read(stroke.xy);
    if (reading.kind != stroke.offer ||
        reading.extent < _recognizer.data.offerExtent) {
      return null;
    }
    return _finish(stroke, reading.kind);
  }

  /// The thumb lifted. Whatever it drew counts, even if it wasn't what was asked:
  /// a shape that falls short still earns the plain flick.
  DanceStrokeResult? end({
    required int pointer,
    required double x,
    required double y,
  }) {
    final stroke = _live[pointer];
    if (stroke == null) return null;
    if (x.isFinite && y.isFinite) _add(stroke, x, y);
    return _finish(stroke, _recognizer.classify(stroke.xy));
  }

  /// Time's up, or the room ended: read what's been drawn so far.
  DanceStrokeResult? settle(int pointer) {
    final stroke = _live[pointer];
    return stroke == null
        ? null
        : _finish(stroke, _recognizer.classify(stroke.xy));
  }

  /// The system took the touch. No failure to show: the tap is already safe.
  void cancel(int pointer) => _live.remove(pointer);

  void clear() {
    _live.clear();
    _ended.clear();
  }

  /// Forgets strokes that have finished fading.
  void prune() {
    final now = _clock();
    _ended.removeWhere((s) => now - (s.endedAt ?? now) >= fadeSeconds);
  }

  void _add(DanceStroke stroke, double x, double y) {
    final xy = stroke.xy;
    final dx = x - xy[xy.length - 2];
    final dy = y - xy[xy.length - 1];
    stroke._length += math.sqrt(dx * dx + dy * dy);
    if (xy.length >= 2 * _pointLimit) {
      // Keep the whole path's shape: halve its detail rather than its length.
      var keep = 0;
      for (var i = 0; i < xy.length; i += 4) {
        xy[keep++] = xy[i];
        xy[keep++] = xy[i + 1];
      }
      xy.length = keep;
    }
    xy
      ..add(x)
      ..add(y);
  }

  DanceStrokeResult? _finish(DanceStroke stroke, GestureKind? kind) {
    _live.remove(stroke.pointer);
    stroke.endedAt = _clock();
    if (kind == null) {
      // A plain tap has nothing to crumble. Only a real attempt leaves dust.
      stroke.state = StrokeState.faded;
      if (stroke._length >= _recognizer.data.minExtent / 2) _ended.add(stroke);
      return null;
    }
    _ended.add(stroke);
    return DanceStrokeResult(stroke, kind, moveHeading(kind, stroke.xy));
  }
}
