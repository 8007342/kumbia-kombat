// The research report's route, kept only as a comparison: hand-written rules on
// measures of a stroke. See README.md for why it wasn't chosen.
import 'dart:math' as math;

import '../../lib/gameplay/gesture_shapes.dart'; // ignore: avoid_relative_lib_imports

class Measure {
  Measure(List<double> xy) {
    final n = xy.length ~/ 2;
    const steps = 32;
    final segs = <double>[for (var i = 1; i < n; i++) _seg(xy, i)];
    final total = segs.fold(0.0, (a, b) => a + b);
    path = total;
    final x = <double>[], y = <double>[];
    var seg = 0;
    var walked = 0.0;
    for (var i = 0; i <= steps; i++) {
      final along = total * i / steps;
      while (seg < segs.length - 1 && walked + segs[seg] < along) {
        walked += segs[seg];
        seg++;
      }
      final f = segs.isEmpty || segs[seg] <= 0
          ? 0.0
          : ((along - walked) / segs[seg]).clamp(0.0, 1.0);
      x.add(xy[2 * seg] + (xy[2 * seg + 2] - xy[2 * seg]) * f);
      y.add(xy[2 * seg + 1] + (xy[2 * seg + 3] - xy[2 * seg + 1]) * f);
    }
    final cx = x.reduce((a, b) => a + b) / x.length;
    final cy = y.reduce((a, b) => a + b) / y.length;
    var (xx, xy2, yy) = (0.0, 0.0, 0.0);
    for (var i = 0; i < x.length; i++) {
      xx += (x[i] - cx) * (x[i] - cx);
      xy2 += (x[i] - cx) * (y[i] - cy);
      yy += (y[i] - cy) * (y[i] - cy);
    }
    final spread = math.sqrt((xx - yy) * (xx - yy) + 4 * xy2 * xy2);
    final major = (xx + yy + spread) / 2;
    final minor = math.max(0.0, (xx + yy - spread) / 2);
    thinness = major <= 0 ? 0 : math.sqrt(minor / major);
    vertical = (.5 * math.atan2(2 * xy2, xx - yy)).abs() > math.pi / 4;
    netDx = x.last - x.first;
    netDy = y.last - y.first;
    net = math.sqrt(netDx * netDx + netDy * netDy);
    straightness = total <= 0 ? 1 : net / total;
    var stray = 0.0;
    for (var i = 1; i < steps; i++) {
      final (dx, dy) = (x[i] - x[0], y[i] - y[0]);
      final off = net <= 0
          ? math.sqrt(dx * dx + dy * dy)
          : (dx * netDy - dy * netDx).abs() / net;
      stray = math.max(stray, off);
    }
    bulge = stray / math.max(net, 1e-6);
    const span = 3;
    var signed = 0.0;
    double? last;
    for (var i = span; i <= steps; i++) {
      final h = math.atan2(y[i] - y[i - span], x[i] - x[i - span]);
      if (last != null) {
        var d = h - last;
        while (d > math.pi) {
          d -= 2 * math.pi;
        }
        while (d <= -math.pi) {
          d += 2 * math.pi;
        }
        signed += d;
      }
      last = h;
    }
    turning = signed.abs() / (2 * math.pi);
  }
  late final double path, net, straightness, thinness, bulge, turning;
  late final double netDx, netDy;
  late final bool vertical;

  static double _seg(List<double> xy, int i) {
    final dx = xy[2 * i] - xy[2 * i - 2];
    final dy = xy[2 * i + 1] - xy[2 * i - 1];
    return math.sqrt(dx * dx + dy * dy);
  }
}

class RuleNumbers {
  const RuleNumbers(
    this.closedBelow,
    this.retraceThinnerThan,
    this.circleTurn,
    this.waveTurn,
    this.waveBulge,
  );
  final double closedBelow, retraceThinnerThan, circleTurn, waveTurn, waveBulge;
}

/// Gating happens before this, the same as for every other candidate.
GestureKind ruleKind(Measure m, RuleNumbers t) {
  if (m.straightness < t.closedBelow) {
    if (m.thinness < t.retraceThinnerThan) {
      return m.vertical ? GestureKind.stomp : GestureKind.spin;
    }
    if (m.turning >= t.circleTurn) return GestureKind.circle;
    return m.turning >= t.waveTurn ? GestureKind.wave : GestureKind.flick;
  }
  if (m.turning >= t.circleTurn) return GestureKind.circle;
  if (m.bulge >= t.waveBulge && m.turning >= t.waveTurn) return GestureKind.wave;
  return m.netDx.abs() >= m.netDy.abs() ? GestureKind.spin : GestureKind.flick;
}
