import 'dart:math' as math;

/// The moves a stroke can be. Null means it wasn't a move at all: a plain tap,
/// or a thumb settling. Pure Dart, so the tools under `tool/gesture/` share it.
enum GestureKind {
  /// A sideways drag. It may curve: a thumb moving sideways swings in an arc.
  spin,

  /// A short stroke that's up, down, or not any shape in particular. The move
  /// any eligible note accepts, so a shape that falls short still earns this.
  flick,

  /// A semi-circle: a hand wave, in any orientation, either way round.
  wave,

  /// Up and down, or down and up: a foot stomp.
  stomp,

  /// A full circle, either way round.
  circle,
}

/// One stroke's ideal path, starting at the origin, about one unit across.
/// y grows down, as on screen. [flip] mirrors it sideways, so a move can head
/// toward the middle of the screen. Used by the cue glyphs, the guide, and
/// autoplay's thumb, so what the game draws is what it asks for.
List<(double, double)> idealStroke(
  GestureKind kind, {
  bool flip = false,
  int points = 33,
}) {
  final side = flip ? -1.0 : 1.0;
  final path = <(double, double)>[];
  for (var i = 0; i < points; i++) {
    final t = i / (points - 1);
    final (x, y) = switch (kind) {
      GestureKind.spin => (t, -.09 * math.sin(math.pi * t)),
      GestureKind.flick => (0.0, -t),
      // An arch: out, up and over, and down the far side.
      GestureKind.wave => (
        .5 - .5 * math.cos(math.pi * t),
        -.5 * math.sin(math.pi * t),
      ),
      // Up and straight back down the same line.
      GestureKind.stomp => (0.0, t < .5 ? -2 * t : -2 + 2 * t),
      // From the bottom, once right round.
      GestureKind.circle => (
        .5 * math.sin(2 * math.pi * t),
        -.5 + .5 * math.cos(2 * math.pi * t),
      ),
    };
    path.add((x * side, y));
  }
  return path;
}

/// Everything the recogniser reads that isn't code. Written by
/// `tool/gesture/tune.dart` into `gesture_data.g.dart`: nothing here is tuned by
/// editing runtime code. Angles are degrees.
class GestureData {
  const GestureData({
    required this.steps,
    required this.minExtent,
    required this.rejectBelow,
    required this.jitterExtent,
    required this.lineTilts,
    required this.lineBends,
    required this.waveSweeps,
    required this.roundAngles,
    required this.stompTilts,
    required this.offerExtent,
  });

  /// Even steps a stroke is resampled to before matching.
  final int steps;

  /// Below this box, in logical pixels, a stroke is a tap: above the 18 of
  /// Flutter's touch slop, and the same 24 flicks always needed.
  final double minExtent;

  /// A best match under this is no shape at all.
  final double rejectBelow;

  /// A shapeless stroke smaller than this is jitter. Larger, it's the plain flick.
  final double jitterExtent;

  /// How a line's template family leans and curves.
  final List<double> lineTilts;
  final List<double> lineBends;

  /// How far round a semi-circle's templates go.
  final List<double> waveSweeps;

  /// How many start headings the round shapes' templates are spread over.
  final int roundAngles;
  final List<double> stompTilts;

  /// The box an offered shape needs before it can finish without waiting for the
  /// lift. A little more than [minExtent], so a move can't land on a wobble.
  final double offerExtent;
}
