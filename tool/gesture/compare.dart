// Compares recognisers on synthetic strokes. See README.md for how to read it.
//
//   dart run tool/gesture/compare.dart [--seed N] [--export dir] [--mlp a,b]
//       [--report file] [--confusion] [--real captured.json]
//
// The app's lib folder is imported by relative path on purpose: this script must
// run with plain `dart`, without Flutter.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../lib/gameplay/gesture_data.g.dart';
import '../../lib/gameplay/gesture_recognizer.dart';
import '../../lib/gameplay/gesture_shapes.dart';
import 'rules.dart';
import 'synth.dart';

typedef Classify = GestureKind? Function(List<double> xy);

final _shipped = GestureRecognizer.shipped;

/// The same box every candidate checks first, so tap figures compare fairly.
bool belowSlop(List<double> xy) => _shipped.read(xy).extent < gestureData.minExtent;

GestureKind _kind(String label) =>
    GestureKind.values.firstWhere((k) => k.name == label);

/// Even steps along the path, translated to start at the origin.
List<double> resample(List<double> xy, int steps) {
  final n = xy.length ~/ 2;
  double len(int s) {
    final dx = xy[2 * s] - xy[2 * s - 2], dy = xy[2 * s + 1] - xy[2 * s - 1];
    return math.sqrt(dx * dx + dy * dy);
  }

  var total = 0.0;
  for (var i = 1; i < n; i++) {
    total += len(i);
  }
  final out = <double>[];
  var seg = 1;
  var walked = 0.0;
  for (var i = 0; i <= steps; i++) {
    final at = total * i / steps;
    while (seg < n - 1 && walked + len(seg) < at) {
      walked += len(seg);
      seg++;
    }
    final l = len(seg);
    final f = l <= 0 ? 0.0 : ((at - walked) / l).clamp(0.0, 1.0);
    out
      ..add(xy[2 * seg - 2] + (xy[2 * seg] - xy[2 * seg - 2]) * f - xy[0])
      ..add(xy[2 * seg - 1] + (xy[2 * seg + 1] - xy[2 * seg - 1]) * f - xy[1]);
  }
  return out;
}

/// Unit-length segment headings: size-free, and direction matters.
List<double> headings(List<double> path) {
  final out = <double>[];
  for (var i = 2; i < path.length; i += 2) {
    final dx = path[i] - path[i - 2], dy = path[i + 1] - path[i - 1];
    final l = math.max(math.sqrt(dx * dx + dy * dy), 1e-9);
    out
      ..add(dx / l)
      ..add(dy / l);
  }
  return out;
}

/// Position vector: centred on the mean, scaled to unit length.
List<double> shapeVector(List<double> path) {
  var (cx, cy) = (0.0, 0.0);
  final n = path.length ~/ 2;
  for (var i = 0; i < n; i++) {
    cx += path[2 * i];
    cy += path[2 * i + 1];
  }
  cx /= n;
  cy /= n;
  return _unit([
    for (var i = 0; i < n; i++) ...[path[2 * i] - cx, path[2 * i + 1] - cy],
  ]);
}

List<double> _unit(List<double> v) {
  final norm = math.sqrt(v.fold(0.0, (a, b) => a + b * b));
  return [for (final x in v) x / math.max(norm, 1e-9)];
}

double dot(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += a[i] * b[i];
  }
  return s;
}

/// Resampled-path nearest neighbour over real training samples.
class Neighbours {
  Neighbours(List<Stroke> train, {this.steps = 16}) {
    for (final s in train) {
      if (s.label == 'none' || belowSlop(s.xy)) continue;
      _labels.add(s.label);
      _vectors.add(shapeVector(resample(s.xy, steps)));
    }
  }
  final int steps;
  final _labels = <String>[];
  final _vectors = <List<double>>[];
  int get count => _labels.length;

  GestureKind? call(List<double> xy) {
    if (belowSlop(xy)) return null;
    final v = shapeVector(resample(xy, steps));
    var best = -2.0;
    var at = 0;
    for (var i = 0; i < _vectors.length; i++) {
      final score = dot(v, _vectors[i]);
      if (score > best) {
        best = score;
        at = i;
      }
    }
    return _kind(_labels[at]);
  }
}

/// What the small networks see: `raw` is the path's headings, `positions` its
/// centred points, and `measures` the numbers the rules read.
List<double> mlpInput(List<double> xy, String features, int steps) {
  if (features == 'raw') return headings(resample(xy, steps));
  if (features == 'positions') return shapeVector(resample(xy, steps));
  final m = Measure(xy);
  final l = math.max(m.net, 1e-6);
  return [
    m.straightness,
    m.thinness,
    math.min(m.bulge, 3) / 3,
    math.min(m.turning, 1.5),
    m.vertical ? 1.0 : 0.0,
    m.netDx.abs() / l,
    m.netDy.abs() / l,
  ];
}

/// A little dense network, as exported by train.py.
class Mlp {
  Mlp(Map<String, dynamic> json)
    : features = json['features'] as String,
      steps = (json['steps'] as num).toInt(),
      labels = (json['labels'] as List).cast<String>(),
      layers = [
        for (final raw in json['layers'] as List)
          (
            [
              for (final row in raw['w'] as List)
                [for (final v in row as List) (v as num).toDouble()],
            ],
            [for (final v in raw['b'] as List) (v as num).toDouble()],
          ),
      ];
  final String features;
  final int steps;
  final List<String> labels;
  final List<(List<List<double>>, List<double>)> layers;

  int get parameters => layers.fold(
    0,
    (sum, l) => sum + l.$2.length + l.$1.length * l.$1.first.length,
  );

  GestureKind? call(List<double> xy) {
    if (belowSlop(xy)) return null;
    var x = mlpInput(xy, features, steps);
    for (var li = 0; li < layers.length; li++) {
      final (w, b) = layers[li];
      final out = List<double>.filled(b.length, 0);
      for (var o = 0; o < b.length; o++) {
        var s = b[o];
        final row = w[o];
        for (var i = 0; i < x.length; i++) {
          s += row[i] * x[i];
        }
        out[o] = li == layers.length - 1 ? s : (s > 0 ? s : 0);
      }
      x = out;
    }
    var at = 0;
    for (var i = 1; i < x.length; i++) {
      if (x[i] > x[at]) at = i;
    }
    return _kind(labels[at]);
  }
}

Map<String, dynamic> evaluate(Classify f, List<Stroke> set) {
  final confusion = <String, Map<String, int>>{};
  var movesRight = 0, moves = 0;
  var noneTotal = 0, noneWrong = 0;
  for (final s in set) {
    final got = f(s.xy)?.name ?? 'none';
    final row = confusion[s.label] ??= {};
    row[got] = (row[got] ?? 0) + 1;
    if (s.label == 'none') {
      noneTotal++;
      if (got != 'none') noneWrong++;
    } else {
      moves++;
      if (got == s.label) movesRight++;
    }
  }
  return {
    'moveAccuracy': movesRight / math.max(moves, 1),
    'tapFalsePositive': noneWrong / math.max(noneTotal, 1),
    'confusion': confusion,
  };
}

double microsPerClassify(Classify f, List<Stroke> set) {
  final strokes = set.where((s) => s.label != 'none').take(600).toList();
  // Warm up, so the figure isn't the compiler at work.
  for (var i = 0; i < 3; i++) {
    for (final s in strokes) {
      f(s.xy);
    }
  }
  final watch = Stopwatch()..start();
  var runs = 0;
  while (watch.elapsedMilliseconds < 400) {
    for (final s in strokes) {
      f(s.xy);
      runs++;
    }
  }
  return watch.elapsedMicroseconds / runs;
}

List<Stroke> _stratified(List<Stroke> train, int each) => [
  for (final label in moveLabels)
    ...train.where((s) => s.label == label).take(each),
];

/// The rules get a fair chance: their numbers are searched on the validation set.
RuleNumbers tuneRules(List<Stroke> validation, int seed) {
  final rows = [
    for (final s in validation)
      if (s.label != 'none' && !belowSlop(s.xy)) (s.label, Measure(s.xy)),
  ];
  final r = math.Random(seed);
  double between(double a, double b) => a + r.nextDouble() * (b - a);
  var best = const RuleNumbers(.35, .3, .72, .28, .2);
  var bestRight = -1;
  for (var i = 0; i < 600; i++) {
    final t = RuleNumbers(
      between(.15, .5),
      between(.12, .5),
      between(.6, .9),
      between(.15, .5),
      between(.1, .5),
    );
    var right = 0;
    for (final (label, m) in rows) {
      if (ruleKind(m, t).name == label) right++;
    }
    if (right > bestRight) {
      bestRight = right;
      best = t;
    }
  }
  return best;
}

void _printConfusion(Map confusion) {
  const columns = [...moveLabels, 'none'];
  stdout.writeln('${''.padRight(8)}${columns.map((c) => c.padLeft(7)).join()}');
  for (final row in columns) {
    final cells = (confusion[row] ?? {}) as Map;
    stdout.writeln(
      '${row.padRight(8)}${columns.map((c) => '${cells[c] ?? 0}'.padLeft(7)).join()}',
    );
  }
}

/// Real strokes saved by the capture page: `?capture=gestures`. Their label is
/// what the page asked for, which is what a person meant to draw.
List<Stroke> readCaptured(String path) => [
  for (final raw in jsonDecode(File(path).readAsStringSync()) as List)
    Stroke(
      raw['asked'] as String,
      [for (final v in raw['xy'] as List) (v as num).toDouble()],
      'real',
    ),
];

void main(List<String> args) {
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i < 0 ? null : args[i + 1];
  }

  final seed = int.parse(option('seed') ?? '1852');
  final real = option('real');
  if (real != null) {
    final set = readCaptured(real);
    final result = evaluate(GestureRecognizer.shipped.classify, set);
    stdout.writeln(
      '${set.length} real strokes: moves ${result['moveAccuracy']}, '
      'taps earning something ${result['tapFalsePositive']}',
    );
    _printConfusion(result['confusion'] as Map);
    return;
  }
  final train = tuningSet(seed, 4000);
  final validate = tuningSet(seed + 1, 1000);
  final heldOut = dataset(seed + 2, Roughness.held, 2000);
  final shifted = dataset(seed + 3, Roughness.shifted, 2000);

  final exportTo = option('export');
  if (exportTo != null) {
    Directory(exportTo).createSync(recursive: true);
    for (final features in ['raw', 'positions', 'measures']) {
      for (final (name, set) in [('train', train), ('validate', validate)]) {
        final rows = [
          for (final s in set)
            if (!belowSlop(s.xy))
              {'x': mlpInput(s.xy, features, 16), 'y': s.label},
        ];
        File(
          '$exportTo/$features-$name.json',
        ).writeAsStringSync(jsonEncode(rows));
      }
    }
    stdout.writeln('exported to $exportTo');
    return;
  }

  final numbers = tuneRules(validate, seed);
  final neighbours = Neighbours(train);
  final small = Neighbours(_stratified(train, 40));
  final candidates = <(String, String, Classify)>[
    (
      'templates (shipped)',
      '${_shipped.templateCount} templates, ${_shipped.templateCount * (2 * gestureData.steps + 2)} numbers, built from ${gestureData.lineTilts.length + gestureData.lineBends.length + gestureData.waveSweeps.length + gestureData.stompTilts.length + 5} parameters',
      _shipped.classify,
    ),
    (
      'rules on measures, numbers searched',
      '5 numbers',
      (xy) => belowSlop(xy) ? null : ruleKind(Measure(xy), numbers),
    ),
    (
      'nearest neighbour, 40 samples a class',
      '${small.count} samples x 34 numbers',
      small.call,
    ),
    (
      'nearest neighbour, all training samples',
      '${neighbours.count} samples x 34 numbers',
      neighbours.call,
    ),
  ];
  for (final file in (option('mlp') ?? '').split(',')) {
    if (file.isEmpty) continue;
    final mlp = Mlp(
      jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>,
    );
    candidates.add((
      'trained MLP: ${file.split('/').last}',
      '${mlp.parameters} parameters, ${mlp.parameters * 4} bytes',
      mlp.call,
    ));
  }
  final scribbles = Synth(seed + 4, Roughness.held);
  final scribbleSet = [for (var i = 0; i < 2000; i++) scribbles.scribble()];
  final report = <Map<String, dynamic>>[];
  for (final (name, size, f) in candidates) {
    final held = evaluate(f, heldOut);
    final rough = evaluate(f, shifted);
    var named = 0;
    for (final s in scribbleSet) {
      final k = f(s.xy);
      if (k != null && k != GestureKind.flick && k != GestureKind.spin) named++;
    }
    final micros = microsPerClassify(f, heldOut);
    report.add({
      'name': name,
      'size': size,
      'heldOut': held,
      'shifted': rough,
      'scribbleNamedShape': named / scribbleSet.length,
      'microseconds': micros,
    });
    String pct(Object? v) => (100 * (v as double)).toStringAsFixed(2);
    stdout.writeln(
      '${name.padRight(46)} held ${pct(held['moveAccuracy'])}%  '
      'rough ${pct(rough['moveAccuracy'])}%  '
      'tapFP ${pct(held['tapFalsePositive'])}/'
      '${pct(rough['tapFalsePositive'])}%  '
      'scribble-named ${pct(named / scribbleSet.length)}%  '
      '${micros.toStringAsFixed(1)} us  [$size]',
    );
  }
  final out = option('report');
  if (out != null) {
    File(
      out,
    ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(report));
  }
  if (args.contains('--confusion')) {
    for (final r in report) {
      stdout.writeln('\n${r['name']} held-out');
      _printConfusion((r['heldOut'] as Map)['confusion'] as Map);
      stdout.writeln('${r['name']} rough');
      _printConfusion((r['shifted'] as Map)['confusion'] as Map);
    }
  }
}
