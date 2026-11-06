// Time per classification, compiled the way the game ships: `dart compile exe`
// for a phone's native code and `dart compile js` for the web build. No phone
// was available: multiply by a phone's slowdown. See README.md.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:math' as math;

import '../../lib/gameplay/gesture_recognizer.dart';
import 'synth.dart';

/// Same arithmetic as a 645-parameter network, on seeded weights. Only for time.
class _Net {
  _Net(int inputs, int hidden, int outputs) {
    final r = math.Random(1);
    w1 = [for (var i = 0; i < inputs * hidden; i++) r.nextDouble() - .5];
    w2 = [for (var i = 0; i < hidden * outputs; i++) r.nextDouble() - .5];
    _in = inputs;
    _hidden = List.filled(hidden, 0);
    _out = List.filled(outputs, 0);
  }
  late final List<double> w1, w2;
  late final int _in;
  late final List<double> _hidden, _out;
  int run(List<double> x) {
    for (var h = 0; h < _hidden.length; h++) {
      var s = 0.0;
      for (var i = 0; i < _in; i++) {
        s += w1[h * _in + i] * x[i];
      }
      _hidden[h] = s > 0 ? s : 0;
    }
    var best = 0;
    for (var o = 0; o < _out.length; o++) {
      var s = 0.0;
      for (var h = 0; h < _hidden.length; h++) {
        s += w2[o * _hidden.length + h] * _hidden[h];
      }
      _out[o] = s;
      if (s > _out[best]) best = o;
    }
    return best;
  }
}

void main() {
  final strokes = dataset(7, Roughness.held, 200);
  var points = 0;
  for (final s in strokes) {
    points += s.xy.length ~/ 2;
  }
  void time(String name, void Function(List<double>) f) {
    for (var warm = 0; warm < 20; warm++) {
      strokes.forEach((s) => f(s.xy));
    }
    final watch = Stopwatch()..start();
    var runs = 0;
    while (watch.elapsedMilliseconds < 1000) {
      for (final s in strokes) {
        f(s.xy);
        runs++;
      }
    }
    print(
      '$name: ${(watch.elapsedMicroseconds / runs).toStringAsFixed(2)} us '
      'a stroke, mean ${points ~/ strokes.length} points',
    );
  }

  final shipped = GestureRecognizer.shipped;
  var sink = 0;
  time('templates, ${shipped.templateCount}', (xy) {
    if (shipped.classify(xy) != null) sink++;
  });
  final net = _Net(34, 16, 5);
  final x = List<double>.filled(34, .1);
  time('network forward pass only, 645 parameters', (xy) {
    sink += net.run(x);
  });
  print('sink $sink');
}
