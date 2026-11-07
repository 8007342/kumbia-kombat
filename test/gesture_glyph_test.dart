import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/gesture_glyph.dart';
import 'package:kumbia_kombat/gameplay/gesture_shapes.dart';

void main() {
  test('a cue\'s glyph draws itself, then a ball runs the path', () {
    expect(GlyphPose.ofCue(0, reducedMotion: false).drawn, 0);
    expect(GlyphPose.ofCue(.25, reducedMotion: false).drawn, .5);
    expect(GlyphPose.ofCue(.25, reducedMotion: false).ball, isNull);
    expect(GlyphPose.ofCue(.5, reducedMotion: false).drawn, 1);
    expect(GlyphPose.ofCue(.75, reducedMotion: false).ball, .5);
    expect(GlyphPose.ofCue(1, reducedMotion: false).ball, 1);
  });

  test('reduced motion shows the whole path, still', () {
    for (final p in [0.0, .3, 1.0]) {
      final pose = GlyphPose.ofCue(p, reducedMotion: true);
      expect(pose.drawn, 1);
      expect(pose.ball, isNull);
    }
  });

  test('the glyph starts where the thumb lands and heads to the middle', () {
    const at = Offset(50, 60);
    for (final kind in GestureKind.values) {
      final points = glyphPoints(kind, at: at, size: 54, flip: false);
      expect(points.first, at);
    }
    final right = glyphPoints(GestureKind.spin, at: at, size: 54, flip: false);
    final left = glyphPoints(GestureKind.spin, at: at, size: 54, flip: true);
    expect(right.last.dx, greaterThan(at.dx));
    expect(left.last.dx, lessThan(at.dx));
  });

  test('every shape has its own drawn path', () {
    final shapes = {
      for (final kind in GestureKind.values)
        idealStroke(kind).map((p) => '$p').join(),
    };
    expect(shapes.length, GestureKind.values.length);
  });

  testWidgets('every glyph paints, on a cue and as a legend', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            for (final kind in GestureKind.values)
              for (final centred in [false, true])
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CustomPaint(
                    painter: GestureGlyphPainter(
                      kind,
                      color: Colors.white,
                      flip: centred,
                      centred: centred,
                      pose: GlyphPose.ofCue(.8, reducedMotion: false),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
