import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gesture_shapes.dart';
import 'touch_gesture.dart';

/// How a move is invited and how it's answered, without a word. Everything draws
/// the path itself: the same [idealStroke] AutoPlay's thumb walks and the
/// recogniser looks for. Art only: this reads the stroke and changes nothing.

const _ink = Color(0xFF101F29);
const _mint = Color(0xFF7CE2C4);
const _gold = Color(0xFFFFC35F);
const _dust = Color(0xFFB9B2A4);

/// Glyph size on a cue, and the guide's size under a held thumb, in logical
/// pixels. Bigger than the cue itself, because the path is the message.
const cueGlyphSize = 54.0;
const guideGlyphSize = 96.0;

/// How a glyph is drawn at one moment. Pure, so a test can read it.
class GlyphPose {
  const GlyphPose(this.drawn, this.ball);

  /// The share of the path already drawn, 0 to 1.
  final double drawn;

  /// How far along the path the running ball is, or null with none.
  final double? ball;

  /// The path draws itself over the cue's first half, then a ball runs it at the
  /// speed it'll be wanted. Reduced motion shows the whole path, still.
  factory GlyphPose.ofCue(double progress, {required bool reducedMotion}) {
    if (reducedMotion) return const GlyphPose(1, null);
    final p = progress.clamp(0.0, 1.0);
    return GlyphPose(
      (p / .5).clamp(0.0, 1.0),
      p < .5 ? null : (p - .5) / .5,
    );
  }
}

/// Screen points for a move's ideal path, starting at [at].
List<Offset> glyphPoints(
  GestureKind kind, {
  required Offset at,
  required double size,
  required bool flip,
}) => [
  for (final (x, y) in idealStroke(kind, flip: flip))
    at.translate(x * size, y * size),
];

Path _path(List<Offset> points, double share) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  final last = (points.length - 1) * share.clamp(0.0, 1.0);
  for (var i = 1; i <= last.floor(); i++) {
    path.lineTo(points[i].dx, points[i].dy);
  }
  final f = last - last.floor();
  if (f > 0 && last.ceil() < points.length) {
    final a = points[last.floor()];
    final b = points[last.ceil()];
    path.lineTo(a.dx + (b.dx - a.dx) * f, a.dy + (b.dy - a.dy) * f);
  }
  return path;
}

/// A dot where the thumb lands, the path out of it, and an arrowhead saying which
/// way it runs: "press here and draw this". Stomp's retrace shows as a head at
/// both ends, because the second leg overlays the first.
class GestureGlyphPainter extends CustomPainter {
  const GestureGlyphPainter(
    this.kind, {
    required this.color,
    required this.pose,
    required this.flip,
    this.size = cueGlyphSize,
    this.centred = false,
  });
  final GestureKind kind;
  final Color color;
  final GlyphPose pose;
  final bool flip;
  final double size;

  /// Centre the whole path in the box, rather than start it there. For a legend.
  final bool centred;

  @override
  void paint(Canvas canvas, Size box) {
    var at = box.center(Offset.zero);
    var points = glyphPoints(kind, at: at, size: size, flip: flip);
    if (centred) {
      final bounds = Rect.fromPoints(
        Offset(
          points.map((p) => p.dx).reduce(math.min),
          points.map((p) => p.dy).reduce(math.min),
        ),
        Offset(
          points.map((p) => p.dx).reduce(math.max),
          points.map((p) => p.dy).reduce(math.max),
        ),
      );
      final shift = at - bounds.center;
      at += shift;
      points = [for (final p in points) p + shift];
    }
    final path = _path(points, pose.drawn);
    canvas.drawPath(path, _line(_ink.withValues(alpha: .8), 6));
    canvas.drawPath(path, _line(color, 3));
    canvas.drawCircle(at, 4.5, Paint()..color = _ink.withValues(alpha: .8));
    canvas.drawCircle(at, 3, Paint()..color = color);
    if (pose.drawn >= 1) {
      _head(canvas, points[points.length - 2], points.last, color);
      if (kind == GestureKind.stomp) {
        final mid = points.length ~/ 2;
        _head(canvas, points[mid - 1], points[mid], color);
      }
    }
    final ball = pose.ball;
    if (ball != null) {
      final spot = points[((points.length - 1) * ball).round()];
      canvas.drawCircle(spot, 6, Paint()..color = _ink.withValues(alpha: .8));
      canvas.drawCircle(spot, 4.5, Paint()..color = _gold);
    }
  }

  @override
  bool shouldRepaint(GestureGlyphPainter oldDelegate) =>
      oldDelegate.pose.drawn != pose.drawn ||
      oldDelegate.pose.ball != pose.ball ||
      oldDelegate.kind != kind ||
      oldDelegate.flip != flip ||
      oldDelegate.color != color;
}

Paint _line(Color color, double width) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..strokeWidth = width
  ..color = color;

void _head(Canvas canvas, Offset from, Offset to, Color color) {
  final a = (to - from).direction;
  final head = Path()
    ..moveTo(
      to.dx + 8 * math.cos(a + 2.5),
      to.dy + 8 * math.sin(a + 2.5),
    )
    ..lineTo(to.dx, to.dy)
    ..lineTo(
      to.dx + 8 * math.cos(a - 2.5),
      to.dy + 8 * math.sin(a - 2.5),
    );
  canvas.drawPath(head, _line(_ink.withValues(alpha: .8), 6));
  canvas.drawPath(head, _line(color, 3));
}

/// The thumb's own trail and, while it's down, a dotted guide for the rest of the
/// offered shape, starting from wherever the thumb landed. A trail that landed
/// flares gold. One that didn't crumbles to dust, silently: no miss, no shake.
class StrokeTrailPainter extends CustomPainter {
  StrokeTrailPainter(
    this.strokes, {
    required this.now,
    required this.reducedMotion,
    required this.flipOf,
  });
  final List<DanceStroke> strokes;
  final double now;
  final bool reducedMotion;
  final bool Function(DanceStroke stroke) flipOf;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final points = [
        for (var i = 0; i + 1 < stroke.xy.length; i += 2)
          Offset(stroke.xy[i], stroke.xy[i + 1]),
      ];
      if (stroke.state == StrokeState.tracing) {
        _guide(canvas, stroke, points.first);
        _trail(canvas, points, _mint, 4, 1);
        continue;
      }
      final age = now - (stroke.endedAt ?? now);
      final t = (age / DanceTouchGestures.fadeSeconds).clamp(0.0, 1.0);
      if (points.length < 2) continue;
      if (stroke.state == StrokeState.landed) {
        _trail(canvas, points, _gold, 4 + (reducedMotion ? 0 : 5 * t), 1 - t);
      } else if (reducedMotion) {
        _trail(canvas, points, _dust, 3, 1 - t);
      } else {
        _dustOf(canvas, points, t);
      }
    }
  }

  void _guide(Canvas canvas, DanceStroke stroke, Offset at) {
    final offer = stroke.offer;
    if (offer == null) return;
    final guide = glyphPoints(
      offer,
      at: at,
      size: guideGlyphSize,
      flip: flipOf(stroke),
    );
    final dot = Paint()..color = _mint.withValues(alpha: .75);
    final under = Paint()..color = _ink.withValues(alpha: .55);
    for (var i = 2; i < guide.length; i += 2) {
      canvas.drawCircle(guide[i], 3.4, under);
      canvas.drawCircle(guide[i], 2.2, dot);
    }
    _head(canvas, guide[guide.length - 2], guide.last, _mint);
  }

  void _trail(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double width,
    double opacity,
  ) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      _line(_ink.withValues(alpha: .6 * opacity), width + 3),
    );
    canvas.drawPath(path, _line(color.withValues(alpha: opacity), width));
  }

  void _dustOf(Canvas canvas, List<Offset> points, double t) {
    final fill = Paint()..color = _dust.withValues(alpha: (1 - t) * .8);
    final step = math.max(1, points.length ~/ 16);
    for (var i = 0; i < points.length; i += step) {
      final drift = i.isEven ? -1.0 : 1.0;
      canvas.drawCircle(
        points[i].translate(drift * 5 * t, 12 * t * t),
        2 * (1 - t) + .5,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(StrokeTrailPainter oldDelegate) => true;
}
