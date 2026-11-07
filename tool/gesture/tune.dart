// Picks the recogniser's data on the validation set only, and writes it to
// lib/gameplay/gesture_data.g.dart. Held-out and rough sets are never read here.
//
//   dart run tool/gesture/tune.dart [--seed N]
//
// ignore_for_file: avoid_relative_lib_imports
import 'dart:io';

import '../../lib/gameplay/gesture_recognizer.dart';
import '../../lib/gameplay/gesture_shapes.dart';
import 'synth.dart';

const _minExtent = 24.0;
const _jitterExtent = 36.0;
const _offerExtent = 30.0;

GestureData _data(
  int steps,
  List<double> tilts,
  List<double> bends,
  List<double> sweeps,
  int angles,
  List<double> stomps, {
  double reject = -2,
}) => GestureData(
  steps: steps,
  minExtent: _minExtent,
  rejectBelow: reject,
  jitterExtent: _jitterExtent,
  lineTilts: tilts,
  lineBends: bends,
  waveSweeps: sweeps,
  roundAngles: angles,
  stompTilts: stomps,
  offerExtent: _offerExtent,
);

void main(List<String> args) {
  final seedAt = args.indexOf('--seed');
  final seed = seedAt < 0 ? 1852 : int.parse(args[seedAt + 1]);
  // The same seed offset as compare.dart's validation set.
  final validate = tuningSet(seed + 1, 1000);
  final moves = validate.where((s) => s.label != 'none').toList();
  final scribbles = Synth(seed + 5, Roughness.held);
  final noise = [for (var i = 0; i < 1000; i++) scribbles.scribble()];

  double accuracy(GestureRecognizer r) {
    var right = 0;
    for (final s in moves) {
      if (r.classify(s.xy)?.name == s.label) right++;
    }
    return right / moves.length;
  }

  ({GestureData data, double accuracy, int templates})? best;
  const tiltChoices = <List<double>>[
    [0],
    [-25, 0, 25],
  ];
  const bendChoices = <List<double>>[
    [0],
    [-50, 0, 50],
  ];
  const sweepChoices = <List<double>>[
    [180],
    [150, 210],
    [150, 180, 210],
  ];
  const stompChoices = <List<double>>[
    [0],
    [-15, 15],
    [-15, 0, 15],
  ];
  for (final steps in const [16, 24, 32]) {
    for (final tilts in tiltChoices) {
      for (final bends in bendChoices) {
        for (final sweeps in sweepChoices) {
          for (final angles in const [8, 12, 16]) {
            for (final stomps in stompChoices) {
              final data = _data(steps, tilts, bends, sweeps, angles, stomps);
              final r = GestureRecognizer(data);
              final a = accuracy(r);
              // Prefer fewer numbers unless accuracy is really better.
              final size = r.templateCount * (2 * steps + 2);
              final current = best;
              final currentSize = current == null
                  ? 1 << 30
                  : current.templates * (2 * current.data.steps + 2);
              if (current == null ||
                  a > current.accuracy + .0001 ||
                  (a >= current.accuracy - .0001 && size < currentSize)) {
                best = (data: data, accuracy: a, templates: r.templateCount);
              }
            }
          }
        }
      }
    }
  }
  final chosen = best!;
  stdout.writeln(
    'templates: ${chosen.templates}, validation ${chosen.accuracy}',
  );

  // The reject line: as high as it goes before a real move falls out. Drawing a
  // shape on a scribble costs nothing; refusing a real shape is the complaint.
  final d = chosen.data;
  var reject = -2.0;
  for (var line = .5; line <= .98; line += .01) {
    final data = _data(
      d.steps,
      d.lineTilts,
      d.lineBends,
      d.waveSweeps,
      d.roundAngles,
      d.stompTilts,
      reject: line,
    );
    final r = GestureRecognizer(data);
    final a = accuracy(r);
    if (a < chosen.accuracy - .0002) break;
    reject = line;
    final named = noise.where((s) {
      final k = r.classify(s.xy);
      return k != null && k != GestureKind.flick && k != GestureKind.spin;
    }).length;
    stdout.writeln(
      'reject ${line.toStringAsFixed(2)}: moves $a, '
      'scribbles named ${named / noise.length}',
    );
  }
  String list(List<double> v) => '[${v.join(', ')}]';
  File('lib/gameplay/gesture_data.g.dart').writeAsStringSync('''
// Written by tool/gesture/tune.dart (seed $seed). Don't edit by hand: change the
// generator or the search, and run it again. See tool/gesture/README.md.
import 'gesture_shapes.dart';

const gestureData = GestureData(
  steps: ${d.steps},
  minExtent: $_minExtent,
  rejectBelow: ${reject.toStringAsFixed(2)},
  jitterExtent: $_jitterExtent,
  lineTilts: ${list(d.lineTilts)},
  lineBends: ${list(d.lineBends)},
  waveSweeps: ${list(d.waveSweeps)},
  roundAngles: ${d.roundAngles},
  stompTilts: ${list(d.stompTilts)},
  offerExtent: $_offerExtent,
);
''');
}
