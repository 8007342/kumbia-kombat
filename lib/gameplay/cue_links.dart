import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cue_path.dart';
import 'garden_session.dart';

/// How a richer step reads without words: its two cues are tied together. A pair
/// is a plain cord between two cues travelling side by side. A split's cord
/// carries an arrowhead toward the cue that comes second. A double's two cues
/// share a lane, so a short cord joins them, and each wears a second ring (drawn
/// by the page). Nothing here reads back: the session never sees it.
class CueLink {
  const CueLink({
    required this.from,
    required this.to,
    required this.move,
    required this.demo,
    required this.opacity,
  });

  /// The cord's ends, on the rims of the two cues. [from] is the earlier press.
  final Offset from;
  final Offset to;
  final RichMove move;
  final bool demo;
  final double opacity;
}

/// Every link on screen now. A step whose first press has gone shows no cord, so
/// only what is still to be pressed stays tied. Call and response never tie.
List<CueLink> cueLinks(
  Iterable<GardenCue> cues,
  Offset Function(GardenCue cue) position,
) {
  final firsts = <(bool, int), GardenCue>{};
  final links = <CueLink>[];
  for (final cue in cues) {
    if (cue.move == null) continue;
    final key = (cue.demo, cue.step);
    final first = firsts[key];
    if (first == null) {
      firsts[key] = cue;
      continue;
    }
    final a = position(first);
    final b = position(cue);
    final apart = (b - a).distance;
    final rimA = cueExtent(first.progress) / 2;
    final rimB = cueExtent(cue.progress) / 2;
    if (apart <= rimA + rimB) continue;
    final along = (b - a) / apart;
    links.add(
      CueLink(
        from: a + along * rimA,
        to: b - along * rimB,
        move: cue.move!,
        demo: cue.demo,
        opacity: math.min(
          cueFadeIn(first.progress),
          cueFadeIn(cue.progress),
        ),
      ),
    );
  }
  return links;
}

/// The arrowhead on a split's cord: its tip and two barbs, halfway along.
List<Offset> splitArrow(CueLink link, {double size = 7}) {
  final mid = Offset.lerp(link.from, link.to, .5)!;
  final delta = link.to - link.from;
  final along = delta / delta.distance;
  final across = Offset(-along.dy, along.dx);
  final tip = mid + along * size;
  return [tip, mid + across * size * .7, mid - across * size * .7];
}

class CueLinkPainter extends CustomPainter {
  const CueLinkPainter(
    this.links, {
    required this.demoColor,
    required this.playColor,
  });
  final List<CueLink> links;
  final Color demoColor;
  final Color playColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in links) {
      final color = (link.demo ? demoColor : playColor).withValues(
        alpha: link.opacity * (link.demo ? .6 : .85),
      );
      final cord = Paint()
        ..color = color
        ..strokeWidth = link.move == RichMove.pair ? 3 : 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(link.from, link.to, cord);
      if (link.move == RichMove.split) {
        final points = splitArrow(link);
        canvas.drawPath(
          Path()
            ..moveTo(points[0].dx, points[0].dy)
            ..lineTo(points[1].dx, points[1].dy)
            ..lineTo(points[2].dx, points[2].dy)
            ..close(),
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CueLinkPainter old) => true;
}
