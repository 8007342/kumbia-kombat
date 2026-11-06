import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/cue_path.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/thumb_layout.dart';

/// Portrait sizes the game can get, including small phones under browser bars.
/// The page never gets wider than 500.
const _screens = [
  (320.0, 454.0),
  (320.0, 568.0),
  (360.0, 640.0),
  (375.0, 667.0),
  (390.0, 664.0),
  (390.0, 844.0),
  (412.0, 915.0),
  (430.0, 932.0),
  (500.0, 700.0),
  (500.0, 1000.0),
];

CuePath _path(
  Limb limb,
  double beat,
  String id,
  (double, double) screen, {
  bool reducedMotion = false,
}) => cuePath(
  limb: limb,
  beat: beat,
  id: id,
  width: screen.$1,
  height: screen.$2,
  reducedMotion: reducedMotion,
);

double _distance(NotePoint a, NotePoint b) =>
    math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

/// Many ids and beats, in the shape the session really uses.
Iterable<(Limb, double, String)> _notes() sync* {
  for (final limb in Limb.values) {
    for (var quarter = 0; quarter < 480; quarter++) {
      yield (limb, quarter / 4, 'garden:${quarter % 5}:0:0:${quarter % 8}');
    }
  }
}

class _Note {
  const _Note(this.limb, this.beat, this.id);
  final Limb limb;
  final double beat;
  final String id;
}

Limb _limb(Object? name) => Limb.values.byName(name as String);

/// Every level's phrases, called then answered, run into each other, so the
/// seam where a call's last note meets the next phrase is covered too.
Map<String, List<_Note>> _charts() {
  final charts = <String, List<_Note>>{};
  for (final level in ['garden', 'bar', 'pool-garden']) {
    final data = jsonDecode(
      File('levels/$level.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final chart = data['chart'] as Map<String, dynamic>;
    final offsets = [for (final o in chart['offsets'] as List) o as num];
    final phrases = <List<Limb>>[
      [for (final l in chart['limbs'] as List) _limb(l)],
      for (final v in chart['variants'] as List)
        [for (final l in v as List) _limb(l)],
    ];
    final notes = <_Note>[];
    var base = 4.0;
    for (final (p, limbs) in phrases.indexed) {
      for (final turn in [0.0, 8.0]) {
        for (var i = 0; i < limbs.length; i++) {
          notes.add(
            _Note(limbs[i], base + turn + offsets[i], '$level:$p:0:0:$i'),
          );
        }
      }
      base += 16;
    }
    charts[level] = notes;
  }
  return charts;
}

void main() {
  group('the same note always gets the same path', () {
    test('two runs agree, and nothing depends on call order', () {
      final first = [
        for (final (limb, beat, id) in _notes())
          _path(limb, beat, id, (390, 844)),
      ];
      final second = [
        for (final (limb, beat, id) in _notes().toList().reversed)
          _path(limb, beat, id, (390, 844)),
      ].reversed.toList();
      for (var i = 0; i < first.length; i++) {
        for (final t in [0.0, .3, .7, 1.0]) {
          expect(second[i].at(t).x, first[i].at(t).x);
          expect(second[i].at(t).y, first[i].at(t).y);
        }
      }
    });

    test('a beat recovered from a millisecond time names the same note', () {
      final exact = _path(Limb.rightFoot, 12.5, 'bar:1:0:0:2', (390, 844));
      for (final drift in [-.002, -.0005, .0005, .002]) {
        final recovered = _path(Limb.rightFoot, 12.5 + drift, 'bar:1:0:0:2', (
          390,
          844,
        ));
        expect(recovered.landing.x, exact.landing.x);
        expect(recovered.landing.y, exact.landing.y);
      }
    });

    test('the beat and the id both change where a note goes', () {
      final base = _path(Limb.leftHand, 12, 'bar:1:0:0:2', (390, 844));
      final later = _path(Limb.leftHand, 20, 'bar:1:0:0:2', (390, 844));
      final other = _path(Limb.leftHand, 12, 'bar:1:0:0:3', (390, 844));
      expect(later.landing.y, isNot(base.landing.y));
      expect(other.landing.y, isNot(base.landing.y));
    });
  });

  group('variation is real and bounded', () {
    test('landings stray from home by no more than the named limits', () {
      const screen = (390.0, 844.0);
      final spots = <String>{};
      final strays = <double>[];
      for (final (limb, beat, id) in _notes()) {
        final landing = _path(limb, beat, id, screen).landing;
        final home = thumbHome(limb);
        final dx = (landing.x / screen.$1 - home.x).abs();
        final dy = (landing.y / screen.$2 - home.y).abs();
        expect(dx, lessThanOrEqualTo(cueLandingJitterX + 1e-9));
        expect(dy, lessThanOrEqualTo(cueLandingJitterY + 1e-9));
        strays.add(dy / cueLandingJitterY);
        spots.add('${landing.x}:${landing.y}');
      }
      expect(spots.length, greaterThan(_notes().length * .9));
      // The draws actually spread across the range, not just wobble near zero.
      expect(strays.reduce(math.max), greaterThan(.95));
      final mean = strays.reduce((a, b) => a + b) / strays.length;
      expect(mean, closeTo(.5, .05));
    });

    test('starts are near the pad centre, varied, on the note\'s own side', () {
      const screen = (390.0, 844.0);
      final starts = <String>{};
      for (final (limb, beat, id) in _notes()) {
        final start = _path(limb, beat, id, screen).start;
        final dx = start.x / screen.$1 - thumbPadCentre.x;
        final dy = start.y / screen.$2 - thumbPadCentre.y;
        expect(
          dx.abs(),
          inInclusiveRange(cueStartNearX - 1e-9, cueStartFarX + 1e-9),
        );
        expect(
          dy.abs(),
          inInclusiveRange(cueStartNearY - 1e-9, cueStartFarY + 1e-9),
        );
        expect(dx < 0, limbIsLeft(limb));
        expect(dy < 0, limbIsUpper(limb));
        starts.add('${start.x}:${start.y}');
      }
      expect(starts.length, greaterThan(_notes().length * .9));
    });

    test('the pad is wider than it was, around the same middle', () {
      for (final limb in Limb.values) {
        final home = thumbHome(limb);
        // The previous homes were .34/.66 across and .73/.88 down.
        expect((home.x - .5).abs(), greaterThan(.16));
        expect((home.y - .805).abs(), greaterThan(.075));
        expect((home.x - .5).abs(), closeTo(thumbPadReachX, 1e-9));
        expect((home.y - .805).abs(), closeTo(thumbPadReachY, 1e-9));
      }
    });
  });

  group('fair on every phone', () {
    test('the whole ring is inside the zone that judges it', () {
      for (final screen in _screens) {
        final (w, h) = screen;
        for (final (limb, beat, id) in _notes()) {
          final c = _path(limb, beat, id, screen).landing;
          for (final corner in [
            (c.x - cueRingRadius, c.y - cueRingRadius),
            (c.x + cueRingRadius, c.y - cueRingRadius),
            (c.x - cueRingRadius, c.y + cueRingRadius),
            (c.x + cueRingRadius, c.y + cueRingRadius),
          ]) {
            expect(
              thumbLimbAt(corner.$1 / w, corner.$2 / h),
              limb,
              reason: '$screen $limb $beat',
            );
          }
        }
        for (final limb in Limb.values) {
          final c = cueHome(limb, width: w, height: h);
          expect(thumbLimbAt(c.x / w, (c.y - cueRingRadius) / h), limb);
          expect(thumbLimbAt(c.x / w, (c.y + cueRingRadius) / h), limb);
        }
      }
    });

    test('the path stays on screen, in its quadrant, inside the tap band', () {
      for (final screen in _screens) {
        final (w, h) = screen;
        for (final (limb, beat, id) in _notes()) {
          for (final reduced in [false, true]) {
            final path = _path(limb, beat, id, screen, reducedMotion: reduced);
            for (var i = 0; i <= 20; i++) {
              final t = i / 20;
              final p = path.at(t);
              final radius = cueExtent(t) / 2;
              expect(p.x - radius, greaterThanOrEqualTo(0));
              expect(p.x + radius, lessThanOrEqualTo(w));
              // Inside the band is below every HUD element, which all sit in
              // the top bars or above y .65.
              expect(p.y - radius, greaterThanOrEqualTo(thumbBandTop * h));
              expect(p.y + radius, lessThanOrEqualTo(thumbBandBottom * h));
              // Its centre never crosses into another quadrant of the pad.
              expect(p.x < w / 2, limbIsLeft(limb));
              expect(p.y < thumbPadCentre.y * h, limbIsUpper(limb));
            }
          }
        }
      }
    });
  });

  group('the curve follows the move', () {
    test('it bows outward on the limb\'s own side, then into its target', () {
      for (final (limb, beat, id) in _notes()) {
        final path = _path(limb, beat, id, (390, 844));
        final middle = path.at(.5);
        final chordX = (path.start.x + path.landing.x) / 2;
        final chordY = (path.start.y + path.landing.y) / 2;
        // Sideways first: further out than the straight line, nearer the
        // start's height, for all four limbs, mirrored left and right.
        expect(middle.x < chordX, limbIsLeft(limb));
        expect(
          (middle.y - path.start.y).abs(),
          lessThan((chordY - path.start.y).abs()),
        );
        // Then a hand rises into its spot and a foot drops onto its own.
        expect(path.landing.y < path.at(.95).y, limbIsUpper(limb));
      }
    });

    test(
      'even the tightest hand sweeps at least as wide as the widest foot',
      () {
        expect(
          cueHandBend - cueBendJitter,
          greaterThanOrEqualTo(cueFootBend + cueBendJitter),
        );
      },
    );

    test('reduced motion is a straight line to the limb\'s home', () {
      for (final screen in _screens) {
        final (w, h) = screen;
        for (final (limb, beat, id) in _notes().take(120)) {
          final path = _path(limb, beat, id, screen, reducedMotion: true);
          final home = cueHome(limb, width: w, height: h);
          expect(path.landing.x, home.x);
          expect(path.landing.y, home.y);
          final middle = path.at(.5);
          expect(middle.x, closeTo((path.start.x + path.landing.x) / 2, 1e-9));
          expect(middle.y, closeTo((path.start.y + path.landing.y) / 2, 1e-9));
        }
      }
    });
  });

  test('a cue fades in smoothly, and is whole well before it lands', () {
    expect(cueFadeIn(0), 0);
    expect(cueFadeIn(cueFadeInSpan), 1);
    expect(cueFadeIn(1), 1);
    expect(cueFadeIn(-1), 0);
    expect(cueFadeIn(2), 1);
    var last = 0.0;
    for (var i = 1; i <= 100; i++) {
      final now = cueFadeIn(i / 100);
      expect(now, greaterThanOrEqualTo(last));
      // Smoothstep's steepest slope is 1.5 times a straight fade's.
      expect(now - last, lessThanOrEqualTo(1.5 * .01 / cueFadeInSpan + 1e-9));
      last = now;
    }
  });

  group('notes on screen together', () {
    test('landing rings of different limbs can never touch', () {
      for (final (w, h) in _screens) {
        // Closest possible across: both pulled to their inner limit.
        final across =
            2 * (thumbPadReachX - cueLandingJitterX) * w - 2 * cueRingRadius;
        expect(across, greaterThan(0), reason: '$w x $h');
        // Closest possible down: each ring is inside its own half of the band,
        // and the band's split lies between them.
        for (final (_, beat, id) in _notes().take(480)) {
          final hand = _path(Limb.leftHand, beat, id, (w, h)).landing;
          final foot = _path(Limb.leftFoot, beat, id, (w, h)).landing;
          expect(hand.y + cueRingRadius, lessThanOrEqualTo(thumbBandSplit * h));
          expect(
            foot.y - cueRingRadius,
            greaterThanOrEqualTo(thumbBandSplit * h),
          );
        }
      }
    });

    test('in real charts, faded-in cues of different limbs stay apart', () {
      for (final MapEntry(key: level, value: notes) in _charts().entries) {
        for (final screen in _screens) {
          final last = notes.last.beat + 1;
          for (var step = 0; step < (last * 16).ceil(); step++) {
            final beat = step / 16;
            final live = [
              for (final n in notes)
                if (beat >= n.beat - 2 && beat <= n.beat + .5) n,
            ];
            for (var i = 0; i < live.length; i++) {
              for (var j = i + 1; j < live.length; j++) {
                final a = live[i];
                final b = live[j];
                if (a.limb == b.limb) continue;
                final ta = ((beat - a.beat + 2) / 2).clamp(0.0, 1.0);
                final tb = ((beat - b.beat + 2) / 2).clamp(0.0, 1.0);
                if (ta < cueFadeInSpan || tb < cueFadeInSpan) continue;
                final apart = _distance(
                  _path(a.limb, a.beat, a.id, screen).at(ta),
                  _path(b.limb, b.beat, b.id, screen).at(tb),
                );
                expect(
                  apart,
                  greaterThanOrEqualTo((cueExtent(ta) + cueExtent(tb)) / 2),
                  reason: '$level $screen beat $beat ${a.limb} ${b.limb}',
                );
              }
            }
          }
        }
      }
    });

    test('half-beat doubles land on two separate spots', () {
      for (final screen in _screens) {
        final (w, _) = screen;
        for (var half = 0; half < 400; half++) {
          for (final limb in Limb.values) {
            final a = _path(limb, half / 2, 'x:0:0:0:2', screen).landing;
            final b = _path(limb, (half + 1) / 2, 'x:0:0:0:3', screen).landing;
            expect(
              _distance(a, b),
              greaterThanOrEqualTo(
                2 * cueLandingMinimumStray * cueLandingJitterX * w - 1e-9,
              ),
            );
          }
        }
      }
    });

    test('same-limb notes in real charts never sit on top of each other', () {
      // A shared lane rules out a full gap at half a beat, because small
      // variation can't part two cues this size. So this holds a floor instead,
      // as a share of a cue's size, using a generous half beat on screen after
      // landing. Different limbs do get a full gap: see the test above.
      const leastApart = .35;
      var measured = double.infinity;
      for (final notes in _charts().values) {
        for (final screen in _screens) {
          for (var i = 0; i < notes.length; i++) {
            for (var j = i + 1; j < notes.length; j++) {
              final a = notes[i];
              final b = notes[j];
              final gap = (a.beat - b.beat).abs();
              if (a.limb != b.limb || gap > 2.5 || gap == 0) continue;
              for (var step = 0; step <= 40; step++) {
                final beat = math.max(a.beat, b.beat) - 2 + step / 16;
                if (beat > math.min(a.beat, b.beat) + .5) break;
                final ta = ((beat - a.beat + 2) / 2).clamp(0.0, 1.0);
                final tb = ((beat - b.beat + 2) / 2).clamp(0.0, 1.0);
                if (ta < cueFadeInSpan || tb < cueFadeInSpan) continue;
                final apart = _distance(
                  _path(a.limb, a.beat, a.id, screen).at(ta),
                  _path(b.limb, b.beat, b.id, screen).at(tb),
                );
                final ratio = apart / ((cueExtent(ta) + cueExtent(tb)) / 2);
                measured = math.min(measured, ratio);
              }
            }
          }
        }
      }
      expect(measured, greaterThanOrEqualTo(leastApart));
    });
  });
}
