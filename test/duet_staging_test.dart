import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/challenger_choreography.dart';
import 'package:kumbia_kombat/gameplay/dance_grammar.dart';
import 'package:kumbia_kombat/gameplay/duet_staging.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_layout.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/thumb_layout.dart';

String _read(String id) => File('levels/$id.json').readAsStringSync();

LevelDefinition _lawn() => LevelRegistry.parse(
  File('levels/index.json').readAsStringSync(),
  _read,
).byId('pool-garden');

/// Too close to pass through: nearer than a body's width, and nearer in depth too.
bool _clear(PartyPoint a, PartyPoint b, {double x = .11, double y = .06}) =>
    (a.x - b.x).abs() >= x || (a.y - b.y).abs() >= y;

void main() {
  final level = _lawn();
  final duet = level.stage.duet!;
  final call = level.chart.callBeats;
  final cycle = level.chart.cycleBeats;
  final hero = level.stage.heroHome;
  final watch = level.stage.heroWatch;
  final choreography = ChallengerChoreography(
    limbs: level.chart.limbs,
    offsets: level.chart.offsets,
    callBeats: call,
  );

  double yieldAt(double t, double handoff) => choreography
      .sample(beat: t, callStartBeat: 0, handoffMoveBeats: handoff)
      .floorYield;

  DuetSample at(int dancer, int turn, double t, {double handoff = 0, bool calm = false}) =>
      duet.sample(
        dancer: dancer,
        turn: turn,
        t: t,
        callBeats: call,
        floorYield: yieldAt(t, handoff),
        heroX: hero.x,
        reducedMotion: calm,
      );

  /// Every beat of every turn, with the two ways a call can end: plain, or a spin.
  Iterable<(int, double, double)> everyMoment() sync* {
    for (var turn = 0; turn < duet.turns.length; turn++) {
      for (final handoff in [0.0, 1.5, 3.0]) {
        for (var t = 0.0; t < cycle; t += .125) {
          yield (turn, t, handoff);
        }
      }
    }
  }

  group('the pattern', () {
    test('the lead alternates, and each dancer gets a turn', () {
      for (var i = 0; i < duet.turns.length; i++) {
        expect(
          duet.turns[i].lead,
          isNot(duet.turns[(i + 1) % duet.turns.length].lead),
          reason: 'turn $i',
        );
      }
      expect(duet.turns.map((t) => t.lead).toSet(), {0, 1});
    });

    test('a turn comes from the call grid, so a skipped frame loses nothing', () {
      final intro = level.chart.introBeats;
      expect(duet.turnIndex(intro, intro, cycle), 0);
      expect(duet.turnIndex(intro + cycle, intro, cycle), 1);
      expect(
        duet.turnIndex(intro + cycle * duet.turns.length, intro, cycle),
        0,
      );
    });

    test('she ends each turn on a different mark from her last', () {
      for (final dancer in [0, 1]) {
        final ends = [
          for (final turn in duet.turns)
            if (turn.lead == dancer) turn.end,
        ];
        expect(ends.length, greaterThanOrEqualTo(2));
        for (var i = 0; i < ends.length; i++) {
          final next = ends[(i + 1) % ends.length];
          final moved =
              (ends[i].x - next.x).abs() + (ends[i].y - next.y).abs();
          expect(moved, greaterThan(.03), reason: 'dancer $dancer, end $i');
        }
        // And she isn't going back to one spot: every end is its own place.
        expect(
          ends.map((p) => (p.x, p.y)).toSet().length,
          ends.length,
          reason: 'dancer $dancer',
        );
      }
    });

    test('nobody jumps: each turn hands over exactly where the last one left', () {
      for (var turn = 0; turn < duet.turns.length; turn++) {
        final next = turn + 1;
        for (final dancer in [0, 1]) {
          final end = at(dancer, turn, cycle);
          final start = at(dancer, next, 0);
          expect(end.floor.x, closeTo(start.floor.x, 1e-9), reason: 'turn $turn');
          expect(end.floor.y, closeTo(start.floor.y, 1e-9), reason: 'turn $turn');
        }
      }
    });

    test('no one moves quicker than a walk, even between beats', () {
      for (final (turn, t, handoff) in everyMoment()) {
        for (final dancer in [0, 1]) {
          final a = at(dancer, turn, t, handoff: handoff).floor;
          final b = at(dancer, turn, t + .125, handoff: handoff).floor;
          final step = (a.x - b.x).abs() + (a.y - b.y).abs();
          expect(step, lessThan(.06), reason: 'turn $turn beat $t dancer $dancer');
        }
      }
    });
  });

  group('off the turn', () {
    test('she stays off the tap band and inside a phone\'s picture', () {
      for (final (turn, t, handoff) in everyMoment()) {
        for (final dancer in [0, 1]) {
          for (final calm in [false, true]) {
            final p = at(dancer, turn, t, handoff: handoff, calm: calm).floor;
            expect(p.y, lessThan(thumbBandTop), reason: 'turn $turn beat $t');
            expect(thumbLimbAt(.5, p.y), isNull);
            // A 390x844 phone shows source x .153-.847, and she is about .12 wide.
            expect(p.x, inInclusiveRange(.2, .8), reason: 'turn $turn beat $t');
          }
        }
      }
    });

    test('she never crosses through Mācron or the active dancer', () {
      for (final (turn, t, handoff) in everyMoment()) {
        final lead = duet.turns[turn].lead;
        final off = at(1 - lead, turn, t, handoff: handoff).floor;
        final active = at(lead, turn, t, handoff: handoff).floor;
        final reason = 'turn $turn beat $t handoff $handoff';
        expect(_clear(off, active), isTrue, reason: '$reason: $off, $active');
        // Mācron is small, but stands in front: stay clear of both his spots.
        expect(_clear(off, hero, x: .09), isTrue, reason: '$reason: at home');
        expect(_clear(off, watch, x: .09), isTrue, reason: '$reason: watching');
      }
    });

    test('calm camera keeps them clear too, on still marks', () {
      for (final (turn, t, _) in everyMoment()) {
        final lead = duet.turns[turn].lead;
        final off = at(1 - lead, turn, t, calm: true).floor;
        final active = at(lead, turn, t, calm: true).floor;
        expect(_clear(off, active), isTrue, reason: 'turn $turn beat $t');
        expect(at(1 - lead, turn, t, calm: true).moving, isFalse);
      }
    });

    test('she steps slowly, and sometimes all the way to the other side', () {
      var switches = 0;
      for (var turn = 0; turn < duet.turns.length; turn++) {
        final dancer = 1 - duet.turns[turn].lead;
        final from = at(dancer, turn, 0).floor;
        final to = at(dancer, turn, cycle - duet.incomingBeats).floor;
        final crossed = (from.x - hero.x).sign != (to.x - hero.x).sign;
        if (crossed) {
          switches++;
          // Behind everybody: the whole crossing is upstage of the active dancer.
          for (var t = 0.0; t < cycle - duet.incomingBeats; t += .125) {
            final off = at(dancer, turn, t).floor;
            final active = at(1 - dancer, turn, t).floor;
            if ((off.x - active.x).abs() < .11) {
              expect(off.y, lessThan(active.y), reason: 'turn $turn beat $t');
            }
          }
        }
        // A slow step: no faster than a third of the picture in a bar.
        for (var t = 0.0; t < cycle - duet.incomingBeats; t += .25) {
          final a = at(dancer, turn, t).floor;
          final b = at(dancer, turn, t + .25).floor;
          expect((a.x - b.x).abs(), lessThan(.025), reason: 'turn $turn beat $t');
        }
      }
      expect(switches, greaterThanOrEqualTo(2));
      expect(switches, lessThan(duet.turns.length));
    });

    test('off-turn plays with her skirt, from drawings both atlases hold', () {
      final grammar = DanceGrammar.fromJson(
        jsonDecode(
          File('assets/art/ensemble/choreography.json').readAsStringSync(),
        ) as Map<String, dynamic>,
      );
      final manifest =
          jsonDecode(
                File('assets/art/ensemble/manifest.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final dancer in ['swing-a', 'swing-b']) {
        final frames =
            ((manifest['atlases'] as Map)[dancer] as Map)['frames'] as Map;
        grammar.requireFrames(dancer, frames.keys.cast<String>());
        final seen = {
          for (var beat = 0.0; beat < 4; beat += 1)
            grammar.clipFrame(dancer, duet.offClip, beat),
        };
        expect(seen.length, 4, reason: dancer);
        expect(seen.every((f) => f.startsWith('skirt_')), isTrue);
        expect(frames.containsKey(duet.exit.reachFrame), isTrue);
      }
    });
  });

  group('with Mācron', () {
    test('the lead dances beside him through his answer, on either side', () {
      final sides = <bool>{};
      for (var turn = 0; turn < duet.turns.length; turn++) {
        final lead = duet.turns[turn].lead;
        final answering = at(lead, turn, call + 3);
        expect(answering.role, DuetRole.partner, reason: 'turn $turn');
        expect(_clear(answering.floor, hero, x: .1), isTrue);
        // Close enough to read as dancing together.
        expect((answering.floor.x - hero.x).abs(), lessThan(.2));
        expect(answering.mirrored, answering.floor.x < hero.x);
        sides.add(answering.floor.x < hero.x);
      }
      expect(sides, {true, false});
    });

    test('a spin finishes on the mark before she steps away', () {
      for (var turn = 0; turn < duet.turns.length; turn++) {
        final lead = duet.turns[turn].lead;
        final spinning = choreography.sample(
          beat: call + .5,
          callStartBeat: 0,
          handoffMoveBeats: 3,
        );
        expect(spinning.state, ChallengerDanceState.handoffMove);
        final place = duet.sample(
          dancer: lead,
          turn: turn,
          t: call + .5,
          callBeats: call,
          floorYield: spinning.floorYield,
          heroX: hero.x,
        );
        expect(place.floor.x, closeTo(duet.turns[turn].call.x, 1e-9));
        expect(place.floor.y, closeTo(duet.turns[turn].call.y, 1e-9));
        expect(place.role, DuetRole.lead);
      }
    });

    test('the staging reads the chart, and leaves it as it found it', () {
      final before = [...level.chart.offsets];
      final limbs = <Limb>[...level.chart.limbs];
      for (final (turn, t, handoff) in everyMoment()) {
        at(0, turn, t, handoff: handoff);
      }
      expect(level.chart.offsets, before);
      expect(level.chart.limbs, limbs);
    });
  });

  group('a win', () {
    final exit = duet.exit;
    final step = level.exitShot!.heroStep;
    final heroAt = PartyPoint(step.dx, step.dy);

    test('each keeps the side she was on, and Mācron dances between them', () {
      expect(exit.left.x, lessThan(heroAt.x - .1));
      expect(exit.right.x, greaterThan(heroAt.x + .1));
      expect(exit.leftReach.x, lessThan(heroAt.x));
      expect(exit.rightReach.x, greaterThan(heroAt.x));
      for (var turn = 0; turn < duet.turns.length; turn++) {
        for (final t in [call + 1, call + 4, call + 7.9]) {
          final first = duet.floorAtWin(
            dancer: 0,
            turn: turn,
            t: t,
            callBeats: call,
            heroX: hero.x,
          );
          final second = duet.floorAtWin(
            dancer: 1,
            turn: turn,
            t: t,
            callBeats: call,
            heroX: hero.x,
          );
          final mirrored = LevelDuet.closeupMirrored(first.x, second.x);
          expect(mirrored, first.x > second.x);
          for (var e = 0.0; e < level.exitShot!.closeupFrom; e += .125) {
            final one = duet.exitSample(
              onLeft: !mirrored,
              from: first,
              e: e,
            ).floor;
            final two = duet.exitSample(
              onLeft: mirrored,
              from: second,
              e: e,
            ).floor;
            final left = mirrored ? two : one;
            final right = mirrored ? one : two;
            expect(left.x, lessThan(right.x), reason: 'turn $turn beat $e');
            expect(one.y, lessThan(thumbBandTop));
            expect(two.y, lessThan(thumbBandTop));
          }
        }
      }
    });

    test('the reach comes last and is quick, into the close-up', () {
      final shot = level.exitShot!;
      expect(exit.sideBeats, lessThanOrEqualTo(exit.reachFrom));
      expect(exit.reachTo, lessThanOrEqualTo(shot.closeupFrom));
      expect(exit.reachTo - exit.reachFrom, lessThanOrEqualTo(1));
      final before = duet.exitSample(
        onLeft: true,
        from: exit.left,
        e: exit.reachFrom - .01,
      );
      expect(before.reaching, isFalse);
      final during = duet.exitSample(onLeft: true, from: exit.left, e: exit.reachFrom);
      expect(during.reaching, isTrue);
      // The drawing leans toward the picture's left, so on the left it mirrors.
      expect(during.mirrored, isTrue);
      expect(
        duet.exitSample(onLeft: false, from: exit.right, e: exit.reachFrom).mirrored,
        isFalse,
      );
    });

    test('calm camera holds them at the sides, with no reach', () {
      for (var e = 0.0; e < 8; e += .25) {
        final place = duet.exitSample(
          onLeft: true,
          from: exit.right,
          e: e,
          reducedMotion: true,
        );
        expect(place.floor.x, exit.left.x);
        expect(place.reaching, isFalse);
      }
    });
  });

  test('the parser refuses a pattern the floor can\'t hold', () {
    Map<String, dynamic> json() =>
        jsonDecode(_read('pool-garden')) as Map<String, dynamic>;
    Map<String, dynamic> duetOf(Map<String, dynamic> level) =>
        (level['stage'] as Map<String, dynamic>)['duet'] as Map<String, dynamic>;

    final onBand = json();
    (duetOf(onBand)['marks'] as Map)['call0'] = [.47, .66];
    expect(() => LevelDefinition.fromJson(onBand), throwsA(isA<LevelDataError>()));

    final repeated = json();
    final turns = duetOf(repeated)['turns'] as List;
    (turns[1] as Map)['lead'] = 'swing-a';
    expect(() => LevelDefinition.fromJson(repeated), throwsA(isA<LevelDataError>()));

    final sameEnd = json();
    final again = duetOf(sameEnd)['turns'] as List;
    (again[2] as Map)['end'] = (again[0] as Map)['end'];
    expect(() => LevelDefinition.fromJson(sameEnd), throwsA(isA<LevelDataError>()));

    final stray = json();
    (duetOf(stray)['marks'] as Map)['nobody'] = [.5, .5];
    expect(() => LevelDefinition.fromJson(stray), throwsA(isA<LevelDataError>()));
  });
}
