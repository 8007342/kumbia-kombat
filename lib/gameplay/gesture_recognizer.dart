import 'dart:math' as math;
import 'dart:typed_data';

import 'gesture_data.g.dart';
import 'gesture_shapes.dart';
import 'rhythm.dart';

/// Why templates and not a trained model: `tool/gesture/README.md`, with numbers.
///
/// Reads a finished or growing stroke and names its shape: the path is resampled
/// to even steps, so speed plays no part, then compared by cosine with a small
/// set of ideal paths in every direction the shape allows. There's no rotation
/// search, because direction is what separates a spin from a flick. Timing stays
/// with the tap: a gesture is pass or nothing.
class GestureReading {
  const GestureReading(this.kind, this.score, this.extent);

  /// Null: it wasn't a move.
  final GestureKind? kind;

  /// The best template's cosine, 1 at most. 0 when it never reached a shape.
  final double score;

  /// The longer side of the stroke's box, in logical pixels.
  final double extent;
}

class GestureRecognizer {
  GestureRecognizer([this.data = gestureData])
    : _x = Float64List(data.steps + 1),
      _y = Float64List(data.steps + 1),
      _v = Float64List(2 * data.steps + 2) {
    _build();
  }

  /// One shared instance: its templates are built once, on first use.
  static final shipped = GestureRecognizer();

  final GestureData data;
  final Float64List _x, _y, _v;
  final _kinds = <GestureKind>[];
  late Float64List _templates;

  int get templateCount => _kinds.length;

  /// [xy] holds x0, y0, x1, y1, ... in logical pixels. Allocates nothing but its
  /// answer, so it can run on every few pixels of a live stroke.
  GestureReading read(List<double> xy) {
    final extent = _resample(xy);
    if (extent < data.minExtent) return GestureReading(null, 0, extent);
    final stride = _v.length;
    var best = -2.0;
    var at = 0;
    for (var t = 0; t < _kinds.length; t++) {
      final offset = t * stride;
      var score = 0.0;
      for (var i = 0; i < stride; i++) {
        score += _v[i] * _templates[offset + i];
      }
      if (score > best) {
        best = score;
        at = t;
      }
    }
    if (best < data.rejectBelow) {
      return GestureReading(
        extent < data.jitterExtent ? null : GestureKind.flick,
        best,
        extent,
      );
    }
    return GestureReading(_kinds[at], best, extent);
  }

  GestureKind? classify(List<double> xy) => read(xy).kind;

  /// Fills [_v] with the stroke's unit-length, centred path. Returns its extent.
  double _resample(List<double> xy) {
    final steps = data.steps;
    final n = xy.length ~/ 2;
    if (n < 2) return 0;
    var length = 0.0;
    for (var i = 1; i < n; i++) {
      length += _segment(xy, i);
    }
    if (length <= 0) return 0;
    var seg = 1;
    var walked = 0.0;
    var span = _segment(xy, 1);
    for (var i = 0; i <= steps; i++) {
      final along = length * i / steps;
      while (seg < n - 1 && walked + span < along) {
        walked += span;
        seg++;
        span = _segment(xy, seg);
      }
      final f = span <= 0 ? 0.0 : ((along - walked) / span).clamp(0.0, 1.0);
      _x[i] = xy[2 * seg - 2] + (xy[2 * seg] - xy[2 * seg - 2]) * f;
      _y[i] = xy[2 * seg - 1] + (xy[2 * seg + 1] - xy[2 * seg - 1]) * f;
    }
    // The box is measured on the raw points, because resampling can cut a corner.
    var (minX, maxX, minY, maxY) = (xy[0], xy[0], xy[1], xy[1]);
    for (var i = 1; i < n; i++) {
      minX = math.min(minX, xy[2 * i]);
      maxX = math.max(maxX, xy[2 * i]);
      minY = math.min(minY, xy[2 * i + 1]);
      maxY = math.max(maxY, xy[2 * i + 1]);
    }
    _normalise(_x, _y, _v, 0);
    return math.max(maxX - minX, maxY - minY);
  }

  static double _segment(List<double> xy, int i) {
    final dx = xy[2 * i] - xy[2 * i - 2];
    final dy = xy[2 * i + 1] - xy[2 * i - 1];
    return math.sqrt(dx * dx + dy * dy);
  }

  void _normalise(Float64List x, Float64List y, Float64List out, int offset) {
    var (cx, cy) = (0.0, 0.0);
    for (var i = 0; i < x.length; i++) {
      cx += x[i];
      cy += y[i];
    }
    cx /= x.length;
    cy /= x.length;
    var norm = 0.0;
    for (var i = 0; i < x.length; i++) {
      final (dx, dy) = (x[i] - cx, y[i] - cy);
      norm += dx * dx + dy * dy;
    }
    norm = math.max(math.sqrt(norm), 1e-9);
    for (var i = 0; i < x.length; i++) {
      out[offset + 2 * i] = (x[i] - cx) / norm;
      out[offset + 2 * i + 1] = (y[i] - cy) / norm;
    }
  }

  void _build() {
    final strokes = <(GestureKind, List<double>)>[];
    void add(GestureKind kind, List<(double, double)> path, double degrees) {
      final a = degrees * math.pi / 180;
      final (c, s) = (math.cos(a), math.sin(a));
      strokes.add((
        kind,
        [
          for (final (x, y) in path) ...[x * c - y * s, x * s + y * c],
        ],
      ));
    }

    for (final tilt in data.lineTilts) {
      for (final bend in data.lineBends) {
        final line = _arc(bend);
        add(GestureKind.spin, line, tilt);
        add(GestureKind.spin, line, 180 + tilt);
        add(GestureKind.flick, line, 90 + tilt);
        add(GestureKind.flick, line, -90 + tilt);
      }
    }
    for (var i = 0; i < data.roundAngles; i++) {
      final angle = 360.0 * i / data.roundAngles;
      for (final sign in const [-1.0, 1.0]) {
        for (final sweep in data.waveSweeps) {
          add(GestureKind.wave, _arc(sweep * sign), angle);
        }
        add(GestureKind.circle, _arc(360 * sign), angle);
      }
    }
    for (final tilt in data.stompTilts) {
      final stomp = idealStroke(GestureKind.stomp);
      add(GestureKind.stomp, stomp, tilt);
      add(GestureKind.stomp, stomp, 180 + tilt);
    }
    final stride = _v.length;
    _templates = Float64List(strokes.length * stride);
    for (final (index, (kind, xy)) in strokes.indexed) {
      _resampleInto(xy);
      _normalise(_x, _y, _templates, index * stride);
      _kinds.add(kind);
    }
  }

  /// A template has no box to measure, and its first point is its own.
  void _resampleInto(List<double> xy) {
    final copy = data.steps;
    final n = xy.length ~/ 2;
    var length = 0.0;
    for (var i = 1; i < n; i++) {
      length += _segment(xy, i);
    }
    var seg = 1;
    var walked = 0.0;
    var span = _segment(xy, 1);
    for (var i = 0; i <= copy; i++) {
      final along = length * i / copy;
      while (seg < n - 1 && walked + span < along) {
        walked += span;
        seg++;
        span = _segment(xy, seg);
      }
      final f = span <= 0 ? 0.0 : ((along - walked) / span).clamp(0.0, 1.0);
      _x[i] = xy[2 * seg - 2] + (xy[2 * seg] - xy[2 * seg - 2]) * f;
      _y[i] = xy[2 * seg - 1] + (xy[2 * seg + 1] - xy[2 * seg - 1]) * f;
    }
  }

  /// A path turning steadily through [degrees], its middle heading along x.
  static List<(double, double)> _arc(double degrees) {
    const n = 40;
    final total = degrees * math.pi / 180;
    var (x, y) = (0.0, 0.0);
    final path = <(double, double)>[(0, 0)];
    for (var i = 1; i <= n; i++) {
      final heading = total * (i / n - .5);
      x += math.cos(heading) / n;
      y += math.sin(heading) / n;
      path.add((x, y));
    }
    return path;
  }
}

/// Which way a finished stroke went, as one of the score's four ornaments: the
/// sideways way for a spin, the first leg's way for a stomp, and for a round
/// shape, which way round. It picks a sound and a look, never whether it counts.
FlourishDirection moveHeading(GestureKind kind, List<double> xy) {
  final n = xy.length ~/ 2;
  if (n < 2) return FlourishDirection.right;
  final (dx, dy) = (xy[2 * n - 2] - xy[0], xy[2 * n - 1] - xy[1]);
  switch (kind) {
    case GestureKind.spin:
      return dx >= 0 ? FlourishDirection.right : FlourishDirection.left;
    case GestureKind.flick:
      if (dx.abs() > dy.abs()) {
        return dx >= 0 ? FlourishDirection.right : FlourishDirection.left;
      }
      return dy >= 0 ? FlourishDirection.down : FlourishDirection.up;
    case GestureKind.stomp:
      for (var i = 1; i < n; i++) {
        final leg = xy[2 * i + 1] - xy[1];
        if (leg.abs() >= 8) return leg < 0 ? FlourishDirection.up : FlourishDirection.down;
      }
      return FlourishDirection.down;
    case GestureKind.wave || GestureKind.circle:
      // The shoelace sum says which way round: on screen, y grows down.
      var area = 0.0;
      for (var i = 1; i < n; i++) {
        area +=
            (xy[2 * i - 2] - xy[0]) * (xy[2 * i + 1] - xy[1]) -
            (xy[2 * i] - xy[0]) * (xy[2 * i - 1] - xy[1]);
      }
      return area >= 0 ? FlourishDirection.right : FlourishDirection.left;
  }
}
