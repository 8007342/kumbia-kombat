import 'rhythm.dart';

class DanceFlick {
  const DanceFlick(this.noteId, this.direction);

  final String noteId;
  final FlourishDirection direction;
}

/// Tracks one optional movement after an already judged pointer-down tap.
/// Distances are Flutter logical pixels, independent of screen resolution.
class DanceTouchGestures {
  static const minimumDistance = 24.0;
  final _touches = <int, ({double x, double y, Duration at, String noteId})>{};

  void begin({
    required int pointer,
    required double x,
    required double y,
    required Duration at,
    required RhythmNote? acceptedNote,
  }) {
    _touches.remove(pointer);
    if (acceptedNote?.flourishTo == null || !x.isFinite || !y.isFinite) return;
    _touches[pointer] = (x: x, y: y, at: at, noteId: acceptedNote!.id);
  }

  DanceFlick? end({
    required int pointer,
    required double x,
    required double y,
    required Duration at,
  }) {
    final touch = _touches.remove(pointer);
    if (touch == null || !x.isFinite || !y.isFinite) return null;
    final elapsed = at - touch.at;
    if (elapsed <= Duration.zero ||
        elapsed > const Duration(milliseconds: RhythmJudge.flourishWindowMs)) {
      return null;
    }
    final dx = x - touch.x;
    final dy = y - touch.y;
    if (dx * dx + dy * dy < minimumDistance * minimumDistance) return null;
    final direction = dx.abs() > dy.abs()
        ? (dx > 0 ? FlourishDirection.right : FlourishDirection.left)
        : (dy > 0 ? FlourishDirection.down : FlourishDirection.up);
    return DanceFlick(touch.noteId, direction);
  }

  void cancel(int pointer) => _touches.remove(pointer);

  void clear() => _touches.clear();
}
