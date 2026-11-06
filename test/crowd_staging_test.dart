import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/crowd_interest.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_layout.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/thumb_layout.dart';

/// The owner's tenth round, as data the levels must keep to. Art only: nothing
/// here reaches the music, the notes or the score.
LevelRegistry _campaign() => LevelRegistry.parse(
  File('levels/index.json').readAsStringSync(),
  (id) => File('levels/$id.json').readAsStringSync(),
);

/// What a 390x844 phone shows of a plate, as [screenX] reads it.
double _screenX(double plateX) {
  final viewport = PartyViewport(390, 844);
  return viewport.project(PartyPoint(plateX, 0)).x / PartyViewport.logicalWidth;
}

/// Every place a floor pattern can put a dancer, sampled over all its turns.
Iterable<PartyPoint> _dancerFloors(LevelDefinition level) sync* {
  for (final challenger in level.stage.challengers) {
    if (level.stage.duet == null) {
      for (var u = 0.0; u <= 1; u += .05) {
        yield challenger.floorAt(u);
      }
    }
  }
  final duet = level.stage.duet;
  if (duet == null) return;
  for (var turn = 0; turn < duet.turns.length; turn++) {
    for (var t = 0.0; t < level.chart.cycleBeats; t += .25) {
      for (final dancer in [0, 1]) {
        yield duet
            .sample(
              dancer: dancer,
              turn: turn,
              t: t,
              callBeats: level.chart.callBeats,
              floorYield: t >= level.chart.callBeats ? 1 : 0,
              heroX: level.stage.heroHome.x,
            )
            .floor;
      }
    }
  }
}

void main() {
  final levels = _campaign();
  final garden = levels.byId('garden');
  final bar = levels.byId('bar');
  final lawn = levels.byId('pool-garden');
  final rooms = [garden, bar, lawn];

  group('the bar', () {
    test('has its back row at the bar and two rows in front, on stools', () {
      final guests = bar.layout.guests;
      final rows = guests.map((g) => g.floor.y).toSet().toList()..sort();
      // Each row sits on one line of the floor, so a third layer can't creep in.
      final front = rows.where((y) => y > .35).toList();
      expect(front.length, 2, reason: 'rows in front: $front');
      final back = guests.where((g) => g.floor.y <= .35).toList();
      expect(back.length, greaterThanOrEqualTo(5));
      expect(
        bar.layout.props.where((p) => p.kind == PartyPropKind.chair),
        isEmpty,
      );
      expect(
        bar.layout.props.where((p) => p.kind == PartyPropKind.stool),
        isNotEmpty,
      );
    });

    test('its back row sits on the stools painted at the bar', () {
      final painted = bar.layout.guests.where((g) => g.chairIncluded).toList();
      expect(painted.length, 5);
      // Nothing is drawn under them: a guest with a stool of ours has a prop.
      for (final guest in bar.layout.guests) {
        final prop = bar.layout.props.singleWhere(
          (p) => p.id == guest.homePropId,
        );
        expect(prop.kind, PartyPropKind.stool);
      }
    });
  });

  group('the garden and the lawn', () {
    for (final (level, before) in [(garden, 12), (lawn, 6)]) {
      test('${level.id} has many more guests, at tables, in depth', () {
        final guests = level.layout.guests;
        expect(guests.length, greaterThan(before * 3 ~/ 2));
        final tables = level.layout.props.where(
          (p) => p.kind == PartyPropKind.table,
        );
        expect(tables.length, greaterThanOrEqualTo(guests.length ~/ 3));
        // Sprinkled in depth: guests on many lines of the floor, both sides.
        expect(guests.map((g) => g.floor.y).toSet().length, greaterThan(6));
        expect(guests.where((g) => g.floor.x < .5), isNotEmpty);
        expect(guests.where((g) => g.floor.x > .5), isNotEmpty);
        // Two guests never share a floor point, or one would just hide the other.
        final spots = guests.map((g) => '${g.floor.x},${g.floor.y}').toSet();
        expect(spots.length, guests.length);
      });
    }
  });

  group('every room stays readable', () {
    for (final level in rooms) {
      final floors = [
        for (final g in level.layout.guests) (g.id, g.floor),
        for (final p in level.layout.props) (p.id, p.floor),
      ];
      test('${level.id}: nothing stands on the tap band or off the phone', () {
        for (final (id, floor) in floors) {
          expect(floor.y, lessThan(thumbBandTop), reason: id);
          expect(floor.x, inInclusiveRange(.15, .85), reason: id);
        }
      });

      test('${level.id}: nothing stands on the hero\'s marks', () {
        final stage = level.stage;
        for (final mark in [
          stage.heroHome,
          stage.heroWatch,
          stage.heroAside,
          stage.heroEntrance,
        ]) {
          for (final (id, floor) in floors) {
            final apart =
                (floor.x - mark.x).abs() > .08 || (floor.y - mark.y).abs() > .06;
            expect(apart, isTrue, reason: '$id at ${mark.x},${mark.y}');
          }
        }
      });

      test('${level.id}: nothing stands where a dancer goes', () {
        for (final at in _dancerFloors(level)) {
          for (final (id, floor) in floors) {
            final apart =
                (floor.x - at.x).abs() > .04 || (floor.y - at.y).abs() > .025;
            expect(apart, isTrue, reason: '$id at ${at.x},${at.y}');
          }
        }
      });

      test('${level.id}: the middle of the floor stays open to the back', () {
        for (final (id, floor) in floors) {
          if (id.contains('umbrella')) continue;
          expect((floor.x - .5).abs(), greaterThan(.03), reason: id);
        }
        // The lawn's floor runs off to one side: its dancers' test covers it.
        if (level.stage.duet != null) return;
        final middle = level.layout.guests.where(
          (g) =>
              (g.floor.x - .5).abs() < .1 &&
              g.floor.y > level.layout.floor.horizonY + .14,
        );
        expect(middle, isEmpty);
      });

      test('${level.id}: the first to dance are spread across the room', () {
        final order = level.layout.guests;
        final count = CrowdEngagement.warmFloorOf(order.length);
        // Ranks fill by column: the same order the crowd model uses.
        final ranks = <int>[
          for (var column = 0; column < 4; column++)
            for (var i = column; i < order.length; i += 4) i,
        ].take(count);
        final left = ranks.where((i) => order[i].floor.x < .5).length;
        // The room's own balance: the lawn seats more on its lawn side.
        final share = order.where((g) => g.floor.x < .5).length / order.length;
        expect((left - count * share).abs(), lessThanOrEqualTo(1.5));
      });
    }
  });

  group('non-dancers stay outside', () {
    for (final level in rooms) {
      test('${level.id}: Mācron waits off the floor, clear of the rings', () {
        final stage = level.stage;
        expect(
          (stage.heroAside.x - stage.heroHome.x).abs(),
          greaterThan(.15),
        );
        final ringEdge = thumbHome(Limb.leftHand).x - .09;
        expect(_screenX(stage.heroAside.x), lessThan(ringEdge));
        // Back means toward the viewer here, because he faces the room.
        expect(stage.heroWatch.y, greaterThan(stage.heroHome.y));
      });
    }

    test('an opponent leaves the middle of the floor for his turn', () {
      for (final level in [garden, bar]) {
        final challenger = level.stage.challengers.single;
        expect((challenger.yieldMark.x - .5).abs(), greaterThan(.15));
      }
    });
  });

  group('his retreat and the floor patterns', () {
    for (final level in rooms) {
      test('${level.id}: no dancer is where he walks, all through a call', () {
        final call = level.chart.callBeats;
        for (var t = 0.0; t < call; t += .25) {
          final hero = level.stage.heroDuringCall(t, call);
          final duet = level.stage.duet;
          final dancers = duet == null
              ? [level.stage.challengers.single.mark]
              : [
                  for (var turn = 0; turn < duet.turns.length; turn++)
                    for (final dancer in [0, 1])
                      duet
                          .sample(
                            dancer: dancer,
                            turn: turn,
                            t: t,
                            callBeats: call,
                            floorYield: 0,
                            heroX: level.stage.heroHome.x,
                          )
                          .floor,
                ];
          for (final at in dancers) {
            expect(hero.y - at.y, greaterThan(.04), reason: 't $t');
          }
        }
      });
    }
  });

  group('opponents stand out', () {
    double guestTallest(LevelDefinition level) => level.layout.guests
        .map((g) => level.layout.floor.standingHeightAt(g.floor.y))
        .reduce(math.max);

    for (final level in [garden, bar]) {
      test('${level.id}: forward of every guest, and moderately larger', () {
        final challenger = level.stage.challengers.single;
        for (final guest in level.layout.guests) {
          expect(challenger.mark.y, greaterThan(guest.floor.y), reason: guest.id);
        }
        // Moderately: still a person on this floor, not a giant.
        expect(challenger.stature, inInclusiveRange(1.05, 1.2));
        final height = level.layout.floor.standingHeightAt(
          challenger.mark.y,
          stature: challenger.stature,
        );
        expect(height / guestTallest(level), greaterThan(1.1));
        // And above the HUD's strip, on the same floor as everyone else.
        expect(challenger.mark.y - height, greaterThan(.1));
      });

      test('${level.id}: comes back to the shot, from off the floor', () {
        final challenger = level.stage.challengers.single;
        final meet = challenger.meetMark!;
        final step = level.exitShot!.heroStep;
        expect(
          (meet.x - step.dx).abs(),
          lessThan((challenger.yieldMark.x - step.dx).abs()),
        );
      });
    }

    test('the pair keep their difference in height, at the larger size', () {
      final [a, b] = lawn.stage.challengers;
      expect(a.stature, greaterThan(b.stature));
      expect(b.stature, greaterThanOrEqualTo(1));
    });
  });

  group('the room is the meter, at any size', () {
    /// Everything the crowd arc reads, for a run of the given phrases.
    CrowdInterestModel run(int guests, PhraseReport report, {int phrases = 10}) {
      final crowd = CrowdInterestModel(
        rampPhrases: 8,
        arcPhrases: 10,
        guestCount: guests,
      );
      for (var i = 0; i < phrases; i++) {
        crowd.resolvePhrase(
          sequence: i,
          passed: true,
          beat: 4.0 + 16 * i,
          report: report,
        );
      }
      return crowd;
    }

    const scrape = PhraseReport(notes: 8, hits: 6, perfects: 0);
    const clean = PhraseReport(notes: 8, hits: 8, perfects: 8);

    test('the warm floor is a share of the room, not a count', () {
      expect(CrowdEngagement.warmFloorOf(12), CrowdEngagement.warmFloorOfTwelve);
      for (final guests in [6, 12, 18, 24, 26, 36, 48]) {
        final share = CrowdEngagement.warmFloorOf(guests) / guests;
        expect(share, inInclusiveRange(.3, .45), reason: '$guests guests');
      }
    });

    for (final guests in [6, 12, 25, 40]) {
      test('$guests guests: a poor clear has that share dancing', () {
        final crowd = run(guests, scrape);
        final late = 4.0 + 16 * 10 + 40;
        final standing = [
          for (var i = 0; i < guests; i++) crowd.guest(i, late).standing,
        ].where((up) => up).length;
        expect(standing, CrowdEngagement.warmFloorOf(guests));
      });

      test('$guests guests: a clean run has everyone up before the clear', () {
        final crowd = run(guests, clean, phrases: 9);
        // The clear comes a phrase after the ninth pass.
        final clear = 4.0 + 16 * 9 + 16;
        for (var i = 0; i < guests; i++) {
          final guest = crowd.guest(i, clear);
          expect(guest.standing, isTrue, reason: 'guest $i');
          expect(guest.transitioning, isFalse, reason: 'guest $i');
        }
      });

      test('$guests guests: every budget of twelve means the whole room', () {
        const profile = CrowdStageProfile('x', 12, 12, 12, 12);
        for (var rank = 0; rank < guests; rank++) {
          expect(profile.ceiling(rank, guests), CrowdGuestState.celebrating);
        }
        const half = CrowdStageProfile('x', 12, 12, 6, 6);
        final up = [
          for (var rank = 0; rank < guests; rank++)
            half.ceiling(rank, guests) == CrowdGuestState.celebrating,
        ].where((yes) => yes).length;
        expect(up, (guests / 2).ceil());
      });

      test('$guests guests: all seated again in the same time at the exit', () {
        final crowd = run(guests, clean);
        const exit = 400.0;
        for (var i = 0; i < guests; i++) {
          final guest = crowd.guest(i, exit + 16, exitBeat: exit);
          expect(guest.standing, isFalse, reason: 'guest $i');
        }
      });
    }

    test('a flourish reaches the same share of a bigger room, as fast', () {
      for (final guests in [12, 36]) {
        final crowd = run(guests, clean, phrases: 2);
        crowd.adorn(0, 100, chain: 1);
        final moved = [
          for (var i = 0; i < guests; i++)
            crowd.guest(i, 100.5).styleEnergy > 0,
        ].where((yes) => yes).length;
        expect(moved, (guests / 6).ceil());
      }
    });

    test('a level hands the crowd exactly the guests it seats', () {
      expect(
        jsonDecode(File('levels/garden.json').readAsStringSync())['crowd']['guests']
            .length,
        garden.layout.guests.length,
      );
    });
  });
}
