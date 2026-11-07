import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/gesture_data.g.dart';
import 'package:kumbia_kombat/gameplay/gesture_recognizer.dart';
import 'package:kumbia_kombat/gameplay/gesture_shapes.dart';

import '../tool/gesture/synth.dart';

/// These check the shipped data against strokes it wasn't tuned on. They use a
/// seed of their own, and the figures in tool/gesture/README.md use another.
void main() {
  final recognizer = GestureRecognizer.shipped;

  double accuracy(List<Stroke> set) {
    final moves = set.where((s) => s.label != 'none').toList();
    final right = moves.where((s) => recognizer.classify(s.xy)?.name == s.label);
    return right.length / moves.length;
  }

  test('reads a held-out set nearly always', () {
    expect(accuracy(dataset(90210, Roughness.held, 300)), greaterThan(.99));
  });

  test('stays usable on strokes rougher than anything it was tuned on', () {
    expect(accuracy(dataset(90211, Roughness.shifted, 300)), greaterThan(.94));
  });

  test('plain taps and jitter never earn a move', () {
    final synth = Synth(90212, Roughness.shifted);
    for (var i = 0; i < 2000; i++) {
      final stroke = synth.negative();
      expect(recognizer.classify(stroke.xy), isNull, reason: stroke.note);
    }
  });

  test('a stroke below the touch slop is a tap, whatever its shape', () {
    for (final kind in GestureKind.values) {
      final tiny = [
        for (final (x, y) in idealStroke(kind)) ...[x * 15, y * 15],
      ];
      expect(recognizer.classify(tiny), isNull, reason: '$kind');
    }
  });

  test('its numbers are data, and within what the research allows', () {
    expect(gestureData.minExtent, greaterThanOrEqualTo(18));
    expect(gestureData.offerExtent, greaterThan(gestureData.minExtent));
    expect(gestureData.rejectBelow, inInclusiveRange(0, 1));
    expect(recognizer.templateCount, lessThan(200));
  });

  test('every classification is cheap enough to run on a live stroke', () {
    final strokes = dataset(90213, Roughness.held, 100);
    final watch = Stopwatch()..start();
    var runs = 0;
    while (watch.elapsedMilliseconds < 100) {
      for (final s in strokes) {
        recognizer.classify(s.xy);
        runs++;
      }
    }
    // A 60 fps frame is 16,667 us. Generous, because a test machine can be busy.
    expect(watch.elapsedMicroseconds / runs, lessThan(200));
  });

  test('an empty or single-point stroke is nothing, not a crash', () {
    expect(recognizer.classify(const []), isNull);
    expect(recognizer.classify(const [3, 4]), isNull);
    expect(recognizer.classify(const [3, 4, 3, 4, 3, 4]), isNull);
  });
}
