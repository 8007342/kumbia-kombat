import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'garden_session.dart';
import 'rhythm.dart';

/// What the player sees instead of words. Each mark reads by shape and motion as
/// well as colour, because gold and orange are close under colour blindness. See
/// Part 6 of `plan/research/touch-gestures-and-feedback-2026-11-06.md`.
enum MarkKind { perfect, early, late, flourish, phrase }

const _gold = Color(0xFFFFC35F);
const _mint = Color(0xFF7CE2C4);
const _cream = Color(0xFFFFF0D1);
const _ink = Color(0xFF101F29);
const _blue = Color(0xFF72DDF7);

/// Moved redder than the old orange to part from gold, short of saturated red.
const _ember = Color(0xFFFF7F5C);

class MarkSpark {
  const MarkSpark(this.offset, this.size, this.opacity);
  final Offset offset;
  final double size;
  final double opacity;
}

/// One moment of a mark. [sweep] is how far round the ring runs, in turns from
/// twelve o'clock: short of 1 stopped early, past 1 ran late.
class MarkPose {
  const MarkPose({
    required this.sweep,
    required this.scale,
    required this.opacity,
    required this.sparks,
  });
  final double sweep;
  final double scale;
  final double opacity;
  final List<MarkSpark> sparks;
}

/// Born when a tap is judged. Pure, so a test can check early and late differ.
class FeedbackMark {
  FeedbackMark(this.kind, this.point, {this.miss = 0, this.chain = 0});

  /// Accepted tap at its timing, with [deltaMs] sized against the judge's windows.
  factory FeedbackMark.tap(
    TapTiming timing,
    Offset point, {
    required int deltaMs,
    int combo = 0,
  }) {
    const span = RhythmJudge.goodWindowMs - RhythmJudge.perfectWindowMs;
    final miss = ((deltaMs.abs() - RhythmJudge.perfectWindowMs) / span).clamp(
      0.0,
      1.0,
    );
    return FeedbackMark(switch (timing) {
      TapTiming.perfect => MarkKind.perfect,
      TapTiming.early => MarkKind.early,
      TapTiming.late => MarkKind.late,
    }, point, miss: miss, chain: combo);
  }

  /// Gone before the next note, even at the lawn's 281 ms gap.
  static const lifeSeconds = .27;

  /// Above the touch, because the thumb covers the ring it's pressing.
  static const liftAboveTouch = 70.0;

  final MarkKind kind;
  final Offset point;

  /// How far outside the perfect window, 0 to 1. Sizes the gap or the tail.
  final double miss;

  /// Steps in a row, or the style chain. More of it, more sparks.
  final int chain;
  double? bornAt;

  Color get color => switch (kind) {
    MarkKind.perfect || MarkKind.phrase => _gold,
    MarkKind.early => _blue,
    MarkKind.late => _ember,
    MarkKind.flourish => _mint,
  };

  /// Marks with a ring say how the tap landed. The others are only sparks.
  bool get hasRing =>
      kind == MarkKind.perfect || kind == MarkKind.early || kind == MarkKind.late;

  int get sparkCount => switch (kind) {
    MarkKind.perfect => 3 + math.min(chain, 5),
    MarkKind.early || MarkKind.late => 2,
    MarkKind.flourish => 6 + 3 * math.min(chain, 4),
    MarkKind.phrase => 10,
  };

  MarkPose pose(double age, {required bool reducedMotion}) {
    final t = (age / lifeSeconds).clamp(0.0, 1.0);
    final sweep = switch (kind) {
      MarkKind.early => .88 - .28 * miss,
      MarkKind.late => 1.12 + .28 * miss,
      _ => 1.0,
    };
    if (reducedMotion) {
      return MarkPose(sweep: sweep, scale: 1, opacity: 1, sparks: const []);
    }
    final eased = 1 - (1 - t) * (1 - t);
    final scale = switch (kind) {
      MarkKind.early => 1 - .3 * eased,
      MarkKind.late => 1 + .35 * eased,
      _ => 1 + .1 * eased,
    };
    return MarkPose(
      sweep: sweep,
      scale: scale,
      opacity: t < .6 ? 1 : (1 - t) / .4,
      sparks: _sparks(t, eased),
    );
  }

  List<MarkSpark> _sparks(double t, double eased) {
    final fade = 1 - t;
    return [
      for (var i = 0; i < sparkCount; i++)
        switch (kind) {
          // Sparks rise off the closed ring.
          MarkKind.perfect => MarkSpark(
            Offset((i - (sparkCount - 1) / 2) * 7, -14 - 22 * eased),
            2.5,
            fade,
          ),
          // Early drifts up and late sinks, so they part without colour.
          MarkKind.early => MarkSpark(
            Offset(i.isEven ? -9 : 9, -6 - 16 * eased),
            3,
            fade,
          ),
          MarkKind.late => MarkSpark(
            Offset(i.isEven ? -10 : 10, 8 + 18 * eased * eased),
            3,
            fade,
          ),
          // A flourish throws them all round.
          MarkKind.flourish => MarkSpark(
            Offset.fromDirection(
              i / sparkCount * math.pi * 2 - math.pi / 2,
              12 + 44 * eased,
            ),
            3,
            fade,
          ),
          // A phrase passed: a low spray up from the tap band.
          MarkKind.phrase => MarkSpark(
            Offset((i - (sparkCount - 1) / 2) * 22, -12 - (28 + i % 3 * 12) * eased),
            3,
            fade,
          ),
        },
    ];
  }
}

/// Paints the marks still alive at [now], on a thin dark outline for busy rooms.
class FeedbackPainter extends CustomPainter {
  FeedbackPainter(this.marks, this.now, {required this.reducedMotion});
  final List<FeedbackMark> marks;
  final double now;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    for (final mark in marks) {
      final age = now - (mark.bornAt ?? now);
      if (age < 0 || age >= FeedbackMark.lifeSeconds) continue;
      final pose = mark.pose(age, reducedMotion: reducedMotion);
      final at = mark.hasRing
          ? mark.point.translate(0, -FeedbackMark.liftAboveTouch)
          : mark.point;
      for (final spark in pose.sparks) {
        _spark(canvas, mark, at + spark.offset, spark);
      }
      if (mark.hasRing) _ring(canvas, mark, at, pose);
    }
  }

  void _spark(Canvas canvas, FeedbackMark mark, Offset at, MarkSpark spark) {
    final fill = Paint()..color = mark.color.withValues(alpha: spark.opacity);
    // Droplets are round, embers are square, and the rest are diamonds.
    switch (mark.kind) {
      case MarkKind.early:
        canvas.drawCircle(at, spark.size, fill);
      case MarkKind.late:
        canvas.drawRect(
          Rect.fromCircle(center: at, radius: spark.size),
          fill,
        );
      default:
        canvas.drawPath(_star(at, spark.size * 1.5, .4), fill);
    }
  }

  void _ring(Canvas canvas, FeedbackMark mark, Offset at, MarkPose pose) {
    final radius = 20 * pose.scale;
    final box = Rect.fromCircle(center: at, radius: radius);
    final color = mark.color.withValues(alpha: pose.opacity);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = _ink.withValues(alpha: .75 * pose.opacity);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = color;
    const top = -math.pi / 2;
    final around = math.min(pose.sweep, 1.0) * math.pi * 2;
    canvas.drawArc(box, top, around, false, outline);
    canvas.drawArc(box, top, around, false, stroke);
    switch (mark.kind) {
      case MarkKind.perfect:
        final star = _star(at, 13, .34);
        canvas.drawPath(star, outline..strokeWidth = 4);
        canvas.drawPath(star, Paint()..color = color);
      case MarkKind.early:
        // A chevron at the end of the short ring, pointing on to twelve.
        final end = top + around;
        final tip = at + Offset.fromDirection(end, radius);
        final ahead = end + math.pi / 2;
        final path = Path()
          ..moveTo(
            tip.dx + 7 * math.cos(ahead + 2.5),
            tip.dy + 7 * math.sin(ahead + 2.5),
          )
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(
            tip.dx + 7 * math.cos(ahead - 2.5),
            tip.dy + 7 * math.sin(ahead - 2.5),
          );
        canvas.drawPath(path, outline..strokeWidth = 5);
        canvas.drawPath(path, stroke);
      case MarkKind.late:
        // The overrun leaves the ring: a tail flying off past twelve.
        final tailLength = (pose.sweep - 1) * radius * 6;
        final start = at + Offset(0, -radius);
        final tail = Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(
            start.dx + tailLength * .6,
            start.dy - 1,
            start.dx + tailLength,
            start.dy - tailLength * .55,
          );
        canvas.drawPath(tail, outline);
        canvas.drawPath(tail, stroke);
      default:
        break;
    }
  }

  Path _star(Offset at, double radius, double waist) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final reach = i.isEven ? radius : radius * waist;
      final point = at + Offset.fromDirection(i * math.pi / 4 - math.pi / 2, reach);
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(FeedbackPainter oldDelegate) => true;
}

/// Whose turn it is, shown by the tap band's light and rings rather than a label.
class TurnLook {
  const TurnLook(this.color, this.glow, this.ring);

  /// How long a failed phrase dulls the band.
  static const sagSeconds = .6;

  final Color color;

  /// How strongly the band lights up from the bottom of the screen.
  final double glow;

  /// How strongly the resting rings show.
  final double ring;

  /// [beat] pulses the band no faster than the beat, the limit for a large area.
  /// [flow] is steps in a row: a player in flow gets a fuller band.
  factory TurnLook.of(
    GardenPhase phase, {
    required double beat,
    required int flow,
    required bool reducedMotion,
    bool sagging = false,
  }) {
    if (sagging) return const TurnLook(_cream, .06, .22);
    final since = beat - beat.floorToDouble();
    final pulse = reducedMotion ? 0.0 : (1 - since) * (1 - since);
    return switch (phase) {
      // Feel the pulse: the rings breathe with the beat before there's anything to do.
      GardenPhase.intro => TurnLook(_cream, .06 + .08 * pulse, .3 + .35 * pulse),
      // Watch: the band dims and takes the demonstration's colour.
      GardenPhase.call => const TurnLook(_gold, .08, .18),
      // Your turn: bright, in the response cues' colour, and fuller as flow builds.
      _ => TurnLook(
        _mint,
        .18 + .05 * pulse + .02 * math.min(flow, 8),
        .5 + .15 * pulse,
      ),
    };
  }
}
