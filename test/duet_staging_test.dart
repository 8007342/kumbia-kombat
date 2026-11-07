import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/challenger_choreography.dart';
import 'package:kumbia_kombat/gameplay/dance_grammar.dart';
import 'package:kumbia_kombat/gameplay/duet_staging.dart';
import 'package:kumbia_kombat/gameplay/ensemble_sprites.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_layout.dart';
import 'package:kumbia_kombat/gameplay/party_sprites.dart';
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

  /// Whoever isn't partnering, through his answer, after she has stepped off.
  Iterable<(int, double)> answerMoments() sync* {
    for (var turn = 0; turn < duet.turns.length; turn++) {
      for (var t = call + 1; t < cycle - duet.incomingBeats; t += .125) {
        yield (turn, t);
      }
    }
  }

  group('their turn: a pair', () {
    test('both dance the call together, on marks that end somewhere new', () {
      for (var turn = 0; turn < duet.turns.length; turn++) {
        final now = duet.turns[turn];
        for (var t = 0.0; t < call - 1; t += .125) {
          final a = at(0, turn, t);
          final b = at(1, turn, t);
          expect(a.role, DuetRole.pair, reason: 'turn $turn beat $t');
          expect(b.role, DuetRole.pair, reason: 'turn $turn beat $t');
          // Side by side, level, at hand's reach, one each side of the middle.
          expect(a.floor.y, closeTo(b.floor.y, 1e-9));
          expect((a.floor.x - b.floor.x).abs(), closeTo(duet.spread * 2, 1e-9));
          final left = now.left == 0 ? a : b;
          final right = now.left == 0 ? b : a;
          expect(left.floor.x, lessThan(right.floor.x));
          expect(left.onLeft, isTrue);
          expect(right.onLeft, isFalse);
          // Each faces the other: drawn reaching right, the right one mirrors.
          expect(left.mirrored, isFalse);
          expect(right.mirrored, isTrue);
        }
        final moved =
            (now.from.x - now.to.x).abs() + (now.from.y - now.to.y).abs();
        expect(moved, greaterThan(.05), reason: 'they travel on turn $turn');
      }
      final ends = duet.turns.map((t) => (t.to.x, t.to.y)).toSet();
      expect(ends.length, duet.turns.length);
    });

    test('calm camera keeps the pair on still marks, still a pair', () {
      for (var turn = 0; turn < duet.turns.length; turn++) {
        for (var t = 0.0; t < call; t += .5) {
          expect(at(0, turn, t, calm: true).role, DuetRole.pair);
          expect(at(0, turn, t, calm: true).floor.x, at(0, turn, 0, calm: true).floor.x);
        }
      }
    });

    test('the chart reads: each limb shows on its own side, by one dancer', () {
      for (final limb in Limb.values) {
        for (final phase in [DanceMovePhase.accent, DanceMovePhase.followThrough]) {
          final left = duet.pairFrame(onLeft: true, limb: limb, phase: phase, beat: 1);
          final right = duet.pairFrame(onLeft: false, limb: limb, phase: phase, beat: 1);
          final hand = limb == Limb.leftHand || limb == Limb.rightHand;
          final shown = hand ? duet.pairFrames.arm : duet.pairFrames.kick;
          // A dancer faces us, so a left limb is on the picture's right.
          final pictureLeft = limb == Limb.rightHand || limb == Limb.rightFoot;
          expect(left, pictureLeft ? shown : isIn(duet.pairFrames.rest));
          expect(right, pictureLeft ? isIn(duet.pairFrames.rest) : shown);
        }
        for (final phase in [DanceMovePhase.anticipation, DanceMovePhase.settle]) {
          expect(
            duet.pairFrame(onLeft: true, limb: limb, phase: phase, beat: 1),
            isIn(duet.pairFrames.rest),
          );
        }
      }
    });
  });

  group('his turn: one partners him', () {
    test('his partner alternates, and both get turns on either side', () {
      for (var i = 0; i < duet.turns.length; i++) {
        expect(
          duet.turns[i].partner,
          isNot(duet.turns[(i + 1) % duet.turns.length].partner),
          reason: 'turn $i',
        );
      }
      expect(duet.turns.map((t) => t.partner).toSet(), {0, 1});
      final sides = {for (final t in duet.turns) (t.partner, t.dance.x < hero.x)};
      expect(sides.length, 4, reason: 'each dancer dances on each side of him');
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

    test('she steps out on the side she danced the call on, crossing nobody', () {
      for (final now in duet.turns) {
        final onLeft = now.partner == now.left;
        expect(now.dance.x < hero.x, onLeft);
        expect(now.off.x > hero.x, onLeft, reason: 'the other goes the other way');
      }
    });

    test('she dances beside him, on either side, then rejoins the pair', () {
      for (var turn = 0; turn < duet.turns.length; turn++) {
        final partner = duet.turns[turn].partner;
        final answering = at(partner, turn, call + 3);
        expect(answering.role, DuetRole.partner, reason: 'turn $turn');
        expect(answering.floor.x, duet.turns[turn].dance.x);
        expect(answering.mirrored, answering.floor.x < hero.x);
        expect(_clear(answering.floor, hero, x: .1), isTrue);
        expect((answering.floor.x - hero.x).abs(), lessThan(.2));
        expect(answering.floor.y, lessThan(thumbBandTop));
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

  group('the other one, at a side', () {
    test('everyone stays off the tap band and inside a phone\'s picture', () {
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

    test('off the turn she is outside the floor: to the side or behind', () {
      for (final (turn, t) in answerMoments()) {
        final other = duet.turns[turn].other;
        final p = at(other, turn, t);
        expect(p.role, DuetRole.offTurn, reason: 'turn $turn beat $t');
        // Well upstage of the band, and of where he and his partner dance.
        expect(p.floor.y, lessThanOrEqualTo(.53), reason: 'turn $turn beat $t');
        expect(hero.y - p.floor.y, greaterThan(.11));
      }
      for (final turn in duet.turns) {
        // She starts at the edge of the picture, not in the middle of the floor.
        expect((turn.off.x - hero.x).abs(), greaterThan(.14));
      }
    });

    test('she never crosses through Mācron or his partner', () {
      for (final (turn, t) in answerMoments()) {
        final now = duet.turns[turn];
        final off = at(now.other, turn, t).floor;
        final partner = at(now.partner, turn, t).floor;
        final reason = 'turn $turn beat $t';
        expect(_clear(off, partner), isTrue, reason: '$reason: $off, $partner');
        expect(_clear(off, hero, x: .09), isTrue, reason: '$reason: at home');
        expect(_clear(off, watch, x: .09), isTrue, reason: '$reason: watching');
      }
    });

    test('walking back to the pair, nobody passes through anybody', () {
      for (var turn = 0; turn < duet.turns.length; turn++) {
        for (var t = cycle - duet.incomingBeats; t < cycle; t += .125) {
          final a = at(0, turn, t).floor;
          final b = at(1, turn, t).floor;
          expect(_clear(a, b, x: .09), isTrue, reason: 'turn $turn beat $t: $a, $b');
          // He is tiny and in front: she may pass just behind him, not through him.
          expect(_clear(a, hero, x: .07, y: .045), isTrue, reason: 'turn $turn beat $t: $a');
          expect(_clear(b, hero, x: .07, y: .045), isTrue, reason: 'turn $turn beat $t: $b');
        }
      }
    });

    test('calm camera keeps her still, off the floor', () {
      for (final (turn, t) in answerMoments()) {
        final other = duet.turns[turn].other;
        final still = at(other, turn, t, calm: true);
        expect(still.moving, isFalse);
        expect(still.role, DuetRole.offTurn);
      }
    });

    test('she steps slowly, and sometimes all the way to the other side', () {
      var switches = 0;
      for (var turn = 0; turn < duet.turns.length; turn++) {
        final dancer = duet.turns[turn].other;
        final from = at(dancer, turn, call + 1).floor;
        final to = at(dancer, turn, cycle - duet.incomingBeats).floor;
        final crossed = (from.x - hero.x).sign != (to.x - hero.x).sign;
        if (crossed) {
          switches++;
          // Behind everybody: the whole crossing is upstage of his partner.
          for (var t = call + 1; t < cycle - duet.incomingBeats; t += .125) {
            final off = at(dancer, turn, t).floor;
            final active = at(1 - dancer, turn, t).floor;
            expect(off.y, lessThan(active.y), reason: 'turn $turn beat $t');
          }
        }
        // A slow step: no faster than a third of the picture in a bar.
        for (var t = call + 1; t < cycle - duet.incomingBeats; t += .25) {
          final a = at(dancer, turn, t).floor;
          final b = at(dancer, turn, t + .25).floor;
          expect((a.x - b.x).abs(), lessThan(.03), reason: 'turn $turn beat $t');
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

  group('a flourish: she spins him', () {
    final intro = level.chart.introBeats;
    // A flourish at [t] into turn [turn]'s call-and-answer, on the music's grid.
    double beatOf(int turn, double t) => intro + turn * cycle + t;
    DuetSpin? spinAt(double flourish, double beat, int turn) => duet.spinFrom(
      flourishBeat: flourish,
      beat: beat,
      callStartBeat: beatOf(turn, 0),
      introBeats: intro,
      callBeats: call,
    );

    test('it is his partner of that turn who holds his hand, at her place', () {
      for (var turn = 0; turn < duet.turns.length; turn++) {
        final flourish = beatOf(turn, call + 2);
        final spin = spinAt(flourish, flourish + .5, turn)!;
        expect(spin.dancer, duet.turns[turn].partner);
        final place = duet.sample(
          dancer: spin.dancer,
          turn: turn,
          t: call + 2.5,
          callBeats: call,
          floorYield: 1,
          heroX: hero.x,
          spin: spin,
        );
        expect(place.role, DuetRole.spinning);
        expect(place.floor.x, duet.turns[turn].dance.x);
        expect(place.floor.y, duet.turns[turn].dance.y);
        // The reach is drawn toward the picture's right, so she mirrors on his right.
        expect(place.mirrored, place.floor.x > hero.x);
      }
    });

    test('a flourish that was never landed has no spin, and nothing moves', () {
      // The scene's flourishBeat only changes on an accepted flourish.
      const never = -10.0;
      for (var t = 0.0; t < cycle; t += .25) {
        expect(spinAt(never, beatOf(1, t), 1), isNull);
      }
      final before = at(duet.turns[1].partner, 1, call + 3);
      expect(before.role, DuetRole.partner);
      // And a spin before its beat hasn't started: a flourish can't look ahead.
      expect(spinAt(beatOf(1, call + 3), beatOf(1, call + 2), 1), isNull);
    });

    test('a spin overflowing the turn finishes mid-floor, then she rejoins', () {
      for (var turn = 0; turn < duet.turns.length; turn++) {
        final now = duet.turns[turn];
        final next = turn + 1;
        // On the very last note of his answer: all of it runs past the turn's end.
        final flourish = beatOf(turn, call + level.chart.offsets.last);
        final over = flourish + duet.spin.beats;
        final overAt = over - beatOf(next, 0);
        expect(overAt, greaterThan(0), reason: 'this flourish does overflow');
        DuetSample inNext(double t) => duet.sample(
          dancer: now.partner,
          turn: next,
          t: t,
          callBeats: call,
          floorYield: 0,
          heroX: hero.x,
          spin: spinAt(flourish, beatOf(next, t), next),
        );
        for (var t = 0.0; t < overAt - 1e-6; t += .125) {
          final p = inNext(t);
          expect(p.role, DuetRole.spinning, reason: 'turn $turn beat $t');
          expect(p.floor.x, now.dance.x);
          expect(p.floor.y, now.dance.y);
        }
        // And nobody teleports: she leaves from where she held him, at a walk.
        var last = now.dance;
        for (var t = overAt; t < overAt + duet.spin.catchUpBeats + 1; t += .125) {
          final p = inNext(t);
          final step = (p.floor.x - last.x).abs() + (p.floor.y - last.y).abs();
          expect(step, lessThan(.09), reason: 'turn $turn beat $t');
          last = p.floor;
        }
        expect(inNext(overAt + duet.spin.catchUpBeats + .5).role, DuetRole.pair);
      }
    });

    test('it is cosmetic: the chart and the sampler never know', () {
      final before = [...level.chart.offsets];
      final limbs = <Limb>[...level.chart.limbs];
      for (var turn = 0; turn < duet.turns.length; turn++) {
        for (var t = 0.0; t < cycle; t += .125) {
          final spin = spinAt(beatOf(turn, call + 1), beatOf(turn, t), turn);
          for (final dancer in [0, 1]) {
            final spun = duet.sample(
              dancer: dancer,
              turn: turn,
              t: t,
              callBeats: call,
              floorYield: yieldAt(t, 0),
              heroX: hero.x,
              spin: spin,
            );
            // Only his partner, and only while he spins, is any different.
            if (spin == null || dancer != spin.dancer) {
              final plain = at(dancer, turn, t);
              expect(spun.floor.x, plain.floor.x);
              expect(spun.floor.y, plain.floor.y);
              expect(spun.role, plain.role);
            }
          }
        }
      }
      expect(level.chart.offsets, before);
      expect(level.chart.limbs, limbs);
      // No beat, note or score goes in: only art-side numbers cross this API,
      // and the session source has no way to reach it.
      final session = File('lib/gameplay/garden_session.dart').readAsStringSync();
      expect(session.contains('duet_staging'), isFalse);
      expect(session.contains('DuetSpin'), isFalse);
    });

    test('calm camera has no spin: she stays on her mark', () {
      final flourish = beatOf(0, call + 2);
      final partner = duet.turns[0].partner;
      final place = duet.sample(
        dancer: partner,
        turn: 0,
        t: call + 2.5,
        callBeats: call,
        floorYield: 1,
        heroX: hero.x,
        spin: spinAt(flourish, flourish + .5, 0),
        reducedMotion: true,
      );
      expect(place.role, DuetRole.partner);
    });

    group('at game size, on a 390x844 phone', () {
      final manifest =
          jsonDecode(
                File('assets/art/ensemble/manifest.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final party =
          jsonDecode(
                File('assets/art/party/manifest.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final heroAtlas = PartyAtlasDefinition.fromJson(
        Map<String, dynamic>.from((party['atlases'] as Map)['hero'] as Map),
      );
      final viewport = PartyViewport(390, 844);
      final room = level.stage;
      final floorPlane = level.layout.floor;
      EnsembleAtlasDefinition dancerAtlas(int dancer) =>
          EnsembleAtlasDefinition.fromJson(
            Map<String, dynamic>.from(
              (manifest['atlases'] as Map)[level.stage.challengers[dancer].atlas]
                  as Map,
            ),
          );
      double dancerHeight(int dancer, PartyPoint floor) =>
          viewport.sourceHeightToLogical(
            floorPlane.standingHeightAt(
              floor.y,
              stature: level.stage.challengers[dancer].stature,
            ),
          );
      Offset ground(PartyPoint floor) {
        final p = viewport.project(floor);
        return Offset(p.x, p.y);
      }

      Offset dancerHand(int dancer, String frame, PartyPoint floor, bool flip) {
        final atlas = dancerAtlas(dancer);
        final scale = dancerHeight(dancer, floor) / atlas.nativeHeight('ready');
        return atlas.art.frames[frame]!.holdAt(
          ground(floor),
          scale,
          flipX: flip,
        )!;
      }

      test('every drawing that holds a hand says where the hand is', () {
        for (final dancer in [0, 1]) {
          final atlas = dancerAtlas(dancer).art;
          for (final frame in [
            ...duet.pairFrames.rest,
            duet.pairFrames.arm,
            duet.pairFrames.kick,
            duet.spin.reachFrame,
          ]) {
            expect(atlas.frames[frame]?.hold, isNotNull, reason: '$dancer $frame');
          }
        }
        for (final frame in duet.spin.heroFrames) {
          expect(heroAtlas.frames[frame]?.hold, isNotNull, reason: frame);
        }
      });

      test('his hand stays on one spot, whichever way he faces', () {
        final first = heroAtlas.frames[duet.spin.heroFrames.first]!;
        for (final frame in duet.spin.heroFrames) {
          final f = heroAtlas.frames[frame]!;
          expect(f.hold!.dx - f.anchor.dx, closeTo(first.hold!.dx - first.anchor.dx, 1));
          expect(f.hold!.dy - f.anchor.dy, closeTo(first.hold!.dy - first.anchor.dy, 1));
        }
      });

      test('her hand reaches his from her mark, closing at most a step', () {
        final reference = heroAtlas.frames['front_idle']!;
        final height = viewport.sourceHeightToLogical(
          floorPlane.standingHeightAt(room.heroHome.y, stature: .35),
        );
        final scale = height / (reference.source.height / reference.pixelsPerUnit);
        final px = viewport.pixelsPerUnit;
        for (final now in duet.turns) {
          final flip = now.dance.x > hero.x;
          final his = heroAtlas.frames[duet.spin.heroFrames.first]!.holdAt(
            ground(hero),
            scale,
            flipX: flip,
          )!;
          final hers = dancerHand(now.partner, duet.spin.reachFrame, now.dance, flip);
          final gap = (his - hers) * px;
          expect(gap.dx.abs(), lessThan(14), reason: 'a ${now.partner}: $gap');
          expect(gap.dy.abs(), lessThan(14), reason: 'a ${now.partner}: $gap');
        }
      });

      test('the pair\'s hands meet, closing at most a step, at every mark', () {
        final px = viewport.pixelsPerUnit;
        for (final now in duet.turns) {
          for (final middle in [now.from, now.to]) {
            final leftFloor = PartyPoint(middle.x - duet.spread, middle.y);
            final rightFloor = PartyPoint(middle.x + duet.spread, middle.y);
            for (final a in [...duet.pairFrames.rest, duet.pairFrames.arm, duet.pairFrames.kick]) {
              for (final b in [...duet.pairFrames.rest, duet.pairFrames.arm, duet.pairFrames.kick]) {
                final gap =
                    (dancerHand(now.left, a, leftFloor, false) -
                        dancerHand(1 - now.left, b, rightFloor, true)) *
                    px;
                expect(gap.dx.abs(), lessThan(40), reason: '$a $b $gap at $middle');
                // 30 at stature 1, scaled with the dancers' 1.12: the same pose, drawn larger.
                expect(gap.dy.abs(), lessThan(33.6), reason: '$a $b $gap at $middle');
              }
            }
          }
        }
      });
    });
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

    test('they keep dancing at the sides, either side of the kiss', () {
      final shot = level.exitShot!;
      DuetExitSample at(double e, {bool onLeft = true}) => duet.exitSample(
        onLeft: onLeft,
        from: exit.left,
        e: e,
        closeupTo: shot.closeupTo,
      );
      // On their marks before the reach.
      expect(at(exit.sideBeats).dancing, isTrue);
      expect(at(exit.sideBeats).floor.x, exit.left.x);
      expect(at(exit.reachFrom).dancing, isFalse);
      // They don't hold the reach: back in the wide shot they step out again.
      final back = at(shot.closeupTo);
      expect(back.reaching, isFalse);
      expect(back.dancing, isTrue);
      expect(back.floor.x, exit.leftReach.x);
      final settled = at(shot.closeupTo + exit.backBeats);
      expect(settled.floor.x, exit.left.x);
      expect(settled.floor.y, exit.left.y);
      expect(shot.closeupTo + exit.backBeats, lessThan(16));
      // Facing him from each side, the way a partner does.
      expect(at(shot.closeupTo).mirrored, isTrue);
      expect(at(shot.closeupTo, onLeft: false).mirrored, isFalse);
    });

    test('the dance they keep up really moves, on every beat of the hold', () {
      final grammar = DanceGrammar.fromJson(
        jsonDecode(
              File('assets/art/ensemble/choreography.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      for (final dancer in ['swing-a', 'swing-b']) {
        final frames = [
          for (var beat = 12.0; beat < 16; beat += 1)
            grammar.clipFrame(dancer, exit.danceClip, beat),
        ];
        expect(frames.toSet().length, frames.length, reason: dancer);
      }
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
    (duetOf(onBand)['marks'] as Map)['pair0From'] = [.47, .66];
    expect(() => LevelDefinition.fromJson(onBand), throwsA(isA<LevelDataError>()));

    final repeated = json();
    final turns = duetOf(repeated)['turns'] as List;
    (turns[1] as Map)['partner'] = 'swing-a';
    expect(() => LevelDefinition.fromJson(repeated), throwsA(isA<LevelDataError>()));

    final sameEnd = json();
    final again = duetOf(sameEnd)['turns'] as List;
    (again[2] as Map)['to'] = (again[0] as Map)['to'];
    expect(() => LevelDefinition.fromJson(sameEnd), throwsA(isA<LevelDataError>()));

    final stray = json();
    (duetOf(stray)['marks'] as Map)['nobody'] = [.5, .5];
    expect(() => LevelDefinition.fromJson(stray), throwsA(isA<LevelDataError>()));

    final offFloor = json();
    duetOf(offFloor)['partnerGap'] = .5;
    expect(() => LevelDefinition.fromJson(offFloor), throwsA(isA<LevelDataError>()));
  });
}
