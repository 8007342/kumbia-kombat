// Synthetic strokes: the only training and test data until real thumbs are
// captured. Nothing here came from a person. See README.md.
import 'dart:math' as math;

/// Labels: a GestureKind's name, or 'none' for a stroke that must earn nothing.
class Stroke {
  Stroke(this.label, this.xy, this.note);
  final String label;

  /// x0, y0, x1, y1, ... in logical pixels, starting at the press.
  final List<double> xy;
  final String note;
}

/// How rough a thumb is. [held] and [moderate] are what training and tuning see,
/// and the held-out set is drawn from [held]. Nothing sees [shifted] until the
/// final comparison: it's rougher than all of it, a crude stand-in for real thumbs.
class Roughness {
  const Roughness({
    required this.sizeLow,
    required this.sizeHigh,
    required this.noise,
    required this.wobble,
    required this.arcDegrees,
    required this.lineTilt,
    required this.squash,
    required this.hook,
    required this.slowest,
  });
  final double sizeLow, sizeHigh, noise, wobble, arcDegrees, lineTilt, squash;
  final double hook, slowest;

  static const held = Roughness(
    sizeLow: 34,
    sizeHigh: 130,
    noise: 1.2,
    wobble: .05,
    arcDegrees: 55,
    lineTilt: 30,
    squash: .3,
    hook: 6,
    slowest: 1,
  );
  static const moderate = Roughness(
    sizeLow: 30,
    sizeHigh: 160,
    noise: 1.7,
    wobble: .07,
    arcDegrees: 65,
    lineTilt: 34,
    squash: .38,
    hook: 8,
    slowest: 1.3,
  );
  static const shifted = Roughness(
    sizeLow: 26,
    sizeHigh: 190,
    noise: 2.2,
    wobble: .09,
    arcDegrees: 75,
    lineTilt: 38,
    squash: .45,
    hook: 11,
    slowest: 1.6,
  );
}

class Synth {
  Synth(int seed, this.rough) : _r = math.Random(seed);
  final math.Random _r;
  final Roughness rough;

  double _between(double a, double b) => a + _r.nextDouble() * (b - a);
  double _gauss() =>
      math.sqrt(-2 * math.log(1 - _r.nextDouble())) *
      math.cos(2 * math.pi * _r.nextDouble());
  double _sign() => _r.nextBool() ? 1 : -1;
  double _degrees(double d) => d * math.pi / 180;

  /// Ideal path for a label, in unit scale.
  List<(double, double)> _ideal(String label) {
    const n = 90;
    switch (label) {
      case 'spin' || 'flick':
        // A line with the thumb's swing: the arc is the hard part of a spin.
        final arc = _degrees(_between(0, rough.arcDegrees)) * _sign();
        final tilt = _degrees(_between(-rough.lineTilt, rough.lineTilt));
        final base = label == 'spin'
            ? (_r.nextBool() ? 0.0 : math.pi)
            : (_r.nextBool() ? math.pi / 2 : -math.pi / 2);
        return _integrate(n, (s) => base + tilt + arc * (s - .5));
      case 'wave':
        final sweep = _degrees(_between(135, 235)) * _sign();
        final start = _r.nextDouble() * math.pi * 2;
        return _integrate(n, (s) => start + sweep * s);
      case 'circle':
        final sweep = _degrees(_between(300, 420)) * _sign();
        final start = _r.nextDouble() * math.pi * 2;
        return _integrate(n, (s) => start + sweep * s);
      case 'stomp':
        // Two legs, not equal, and a little apart on the way back.
        final tilt = _degrees(_between(-22, 22));
        final first = _r.nextBool() ? -1.0 : 1.0;
        final back = _between(.65, 1.2);
        final apart = _between(-.16, .16);
        final round = _between(.0, .1);
        final turn = 1 / (1 + back);
        final path = <(double, double)>[];
        for (var i = 0; i < n; i++) {
          final s = i / (n - 1);
          final along = s < turn
              ? s / turn
              : 1 - (s - turn) / (1 - turn) * back;
          final x =
              apart * math.max(0, s - turn) / (1 - turn) +
              round * math.exp(-math.pow((s - turn) / .05, 2));
          final y = first * along;
          path.add((
            x * math.cos(tilt) - y * math.sin(tilt),
            x * math.sin(tilt) + y * math.cos(tilt),
          ));
        }
        return path;
      default:
        throw ArgumentError(label);
    }
  }

  List<(double, double)> _integrate(int n, double Function(double) heading) {
    var x = 0.0, y = 0.0;
    final path = <(double, double)>[(0, 0)];
    for (var i = 1; i < n; i++) {
      final a = heading(i / (n - 1));
      x += math.cos(a) / (n - 1);
      y += math.sin(a) / (n - 1);
      path.add((x, y));
    }
    return path;
  }

  /// Stretch, wobble, hooks, noise, and irregular sampling: what a thumb and a
  /// touch screen do to an ideal shape.
  Stroke stroke(String label) {
    final ideal = _ideal(label);
    var (minX, maxX, minY, maxY) = (0.0, 0.0, 0.0, 0.0);
    for (final (x, y) in ideal) {
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    final extent = math.max(maxX - minX, maxY - minY);
    final size = _between(rough.sizeLow, rough.sizeHigh) / math.max(extent, .3);
    final squash = 1 + _between(-rough.squash, rough.squash);
    final squashAngle = _r.nextDouble() * math.pi * 2;
    final (ca, sa) = (math.cos(squashAngle), math.sin(squashAngle));
    final (wf1, wf2) = (_between(.7, 2.3), _between(2.2, 5));
    final (wp1, wp2) = (_r.nextDouble() * 6.28, _r.nextDouble() * 6.28);
    final wobble = rough.wobble * size * extent * _r.nextDouble();
    final jitter = rough.noise * _r.nextDouble();
    final path = <(double, double)>[];
    for (var i = 0; i < ideal.length; i++) {
      final s = i / (ideal.length - 1);
      var (x, y) = ideal[i];
      // Stretching only applies to rotation-free shapes: lines keep their heading.
      if (label == 'wave' || label == 'circle') {
        final u = (x * ca + y * sa) * squash;
        final v = -x * sa + y * ca;
        x = u * ca - v * sa;
        y = u * sa + v * ca;
      }
      x *= size;
      y *= size;
      final fade = math.sin(math.pi * s);
      x += wobble * fade * math.sin(2 * math.pi * wf1 * s + wp1);
      y += wobble * fade * math.sin(2 * math.pi * wf2 * s + wp2);
      path.add((x, y));
    }
    // The press rolls a little, and the lift flicks off a little.
    final hookIn = _hook(path.first, .7);
    final hookOut = _hook(path.last, 1);
    final full = [...hookIn.reversed, ...path, ...hookOut];
    return Stroke(label, _sample(full, jitter), '');
  }

  List<(double, double)> _hook((double, double) from, double share) {
    final length = rough.hook * _r.nextDouble() * share;
    final angle = _r.nextDouble() * math.pi * 2;
    return [
      for (var i = 1; i <= 4; i++)
        (
          from.$1 + math.cos(angle) * length * i / 4,
          from.$2 + math.sin(angle) * length * i / 4,
        ),
    ];
  }

  /// A minimum-jerk speed profile sampled at 60 to 120 Hz, with dropped events.
  List<double> _sample(List<(double, double)> path, double jitter) {
    final lengths = <double>[0];
    for (var i = 1; i < path.length; i++) {
      final dx = path[i].$1 - path[i - 1].$1;
      final dy = path[i].$2 - path[i - 1].$2;
      lengths.add(lengths.last + math.sqrt(dx * dx + dy * dy));
    }
    final total = lengths.last;
    // Roughly 2.5 ms a pixel for a practised thumb, slower for a careful one.
    final seconds = (.06 + total * .0025) * _between(.6, rough.slowest * 1.5);
    final rate = _between(60, 120);
    final samples = math.max(4, (seconds * rate).round());
    final xy = <double>[];
    var seg = 0;
    for (var i = 0; i < samples; i++) {
      if (i > 0 && i < samples - 1 && _r.nextDouble() < .08) continue;
      final t = i / (samples - 1);
      final eased = t * t * t * (10 + t * (-15 + 6 * t));
      final at = eased * total;
      while (seg < lengths.length - 2 && lengths[seg + 1] < at) {
        seg++;
      }
      final span = lengths[seg + 1] - lengths[seg];
      final f = span <= 0 ? 0.0 : (at - lengths[seg]) / span;
      final x = path[seg].$1 + (path[seg + 1].$1 - path[seg].$1) * f;
      final y = path[seg].$2 + (path[seg + 1].$2 - path[seg].$2) * f;
      xy
        ..add(x + _gauss() * jitter)
        ..add(y + _gauss() * jitter);
    }
    // The press is the origin: that's where the stroke is measured from.
    final (ox, oy) = (xy[0], xy[1]);
    for (var i = 0; i < xy.length; i += 2) {
      xy[i] -= ox;
      xy[i + 1] -= oy;
    }
    return xy;
  }

  /// Plain taps and jitter: every one of these must earn nothing.
  Stroke negative() {
    final kind = _r.nextInt(4);
    final xy = <double>[0, 0];
    var x = 0.0, y = 0.0;
    switch (kind) {
      case 0: // A plain tap: down and up, with a pixel or so of noise.
        final count = _r.nextInt(5);
        for (var i = 0; i < count; i++) {
          xy
            ..add(_gauss() * .8)
            ..add(_gauss() * .8);
        }
      case 1: // A thumb rolling as it presses.
        final a = _r.nextDouble() * math.pi * 2;
        final reach = _between(3, 13);
        for (var i = 1; i <= 8; i++) {
          xy
            ..add(math.cos(a) * reach * i / 8 + _gauss() * .7)
            ..add(math.sin(a) * reach * i / 8 + _gauss() * .7);
        }
      case 2: // Held still for a while, jittering around the press.
        final bound = _between(4, 10);
        for (var i = 0; i < 60; i++) {
          x = (x + _gauss() * 1.6).clamp(-bound, bound);
          y = (y + _gauss() * 1.6).clamp(-bound, bound);
          xy
            ..add(x)
            ..add(y);
        }
      default: // A short slide that never reaches a real stroke.
        final a = _r.nextDouble() * math.pi * 2;
        final reach = _between(8, 19);
        for (var i = 1; i <= 12; i++) {
          xy
            ..add(math.cos(a) * reach * i / 12 + _gauss() * .9)
            ..add(math.sin(a) * reach * i / 12 + _gauss() * .9);
        }
    }
    return Stroke('none', xy, const ['tap', 'roll', 'jitter', 'slide'][kind]);
  }

  /// A long aimless scribble. It may earn the plain flick, never a named shape.
  Stroke scribble() {
    final xy = <double>[0, 0];
    var (x, y) = (0.0, 0.0);
    var a = _r.nextDouble() * 6.28;
    final turns = 3 + _r.nextInt(4);
    for (var leg = 0; leg < turns; leg++) {
      a += _between(1.2, 3.0) * _sign();
      final length = _between(20, 60);
      for (var i = 1; i <= 6; i++) {
        x += math.cos(a) * length / 6 + _gauss() * .8;
        y += math.sin(a) * length / 6 + _gauss() * .8;
        xy
          ..add(x)
          ..add(y);
      }
    }
    return Stroke('scribble', xy, 'scribble');
  }
}

const moveLabels = ['spin', 'flick', 'wave', 'stomp', 'circle'];

/// A balanced set: [perClass] of every move and of plain taps and jitter.
/// What training and tuning see: half [Roughness.held], half [Roughness.moderate].
List<Stroke> tuningSet(int seed, int perClass) => [
  ...dataset(seed, Roughness.held, perClass ~/ 2),
  ...dataset(seed + 100, Roughness.moderate, perClass ~/ 2),
];

List<Stroke> dataset(int seed, Roughness rough, int perClass) {
  final synth = Synth(seed, rough);
  return [
    for (final label in moveLabels)
      for (var i = 0; i < perClass; i++) synth.stroke(label),
    for (var i = 0; i < perClass; i++) synth.negative(),
  ];
}
