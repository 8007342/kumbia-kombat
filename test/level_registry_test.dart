import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/crowd_interest.dart';
import 'package:kumbia_kombat/gameplay/garden_page.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_layout.dart';
import 'package:kumbia_kombat/gameplay/progression.dart';
import 'package:kumbia_kombat/gameplay/room_departure.dart';
import 'package:kumbia_kombat/music/game_audio.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

String _file(String id) => File('levels/$id.json').readAsStringSync();

LevelRegistry _shipping() =>
    LevelRegistry.parse(File('levels/index.json').readAsStringSync(), _file);

Map<String, Object?> _bar() => jsonDecode(_file('bar')) as Map<String, Object?>;

/// Parses a single-level campaign holding the bar's data after [edit].
LevelDefinition _editedBar(void Function(Map<String, dynamic> bar) edit) {
  final bar = _bar();
  edit(bar);
  return LevelDefinition.fromJson(bar);
}

Matcher _dataError(String path) => throwsA(
  isA<LevelDataError>().having((error) => error.path, 'path', contains(path)),
);

class _NoAudio implements GameAudio {
  @override
  String leadShape = 'triangle';
  @override
  double nowSeconds = 0;
  @override
  bool ready = false;
  @override
  Future<void> activate() async {}
  @override
  Future<void> dispose() async {}
  @override
  void silence() {}
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {}
}

class _ClockOnly implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  @override
  void silence() {}
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {}
}

void main() {
  test('play complexity rises through the campaign, whatever the tempo', () {
    // The owner's rule, tenth round: speed is only one factor, so the slower bar
    // must still ask more than the lawn before it. Twelfth round: richer moves are
    // how it grows. So this counts them, along with the offbeat share, across every
    // pattern a level can play. It says nothing about how a run feels, which needs
    // a player.
    List<ChartPattern> patterns(FightChart chart) => [
      for (var i = 0; i <= chart.variants.length; i++) chart.pattern(i),
    ];
    double offbeat(FightChart chart) {
      final notes = [for (final p in patterns(chart)) ...p.offsets];
      return notes.where((beat) => beat % 1 != 0).length / notes.length;
    }

    int rich(FightChart chart) =>
        patterns(chart).fold(0, (sum, p) => sum + p.richSteps);
    final charts = [for (final step in _shipping().campaign) step.level.chart];
    expect(rich(charts[0]), 0, reason: 'the Garden stays simple, as the opener');
    expect(rich(charts[1]), greaterThan(rich(charts[0])));
    expect(rich(charts[2]), greaterThan(rich(charts[1])));
    expect(offbeat(charts[1]), greaterThanOrEqualTo(offbeat(charts[0])));
    expect(offbeat(charts[2]), greaterThan(offbeat(charts[1])));
    expect(rich(charts[3]), greaterThan(rich(charts[2])));
    expect(offbeat(charts[3]), greaterThan(offbeat(charts[2])));
  });

  group('shipping levels match the two-room code they replaced', () {
    final levels = _shipping();

    for (final (index, id, chart) in [
      (0, 'garden', FightChart.garden),
      (1, 'bar', FightChart.bar),
    ]) {
      test('$id rules, chart and crowd numbers', () {
        final level = levels.byId(id);
        final rules = fights[index];
        expect(level.rules.id, rules.id);
        expect(level.rules.metric, rules.metric);
        expect(level.rules.cleanSeconds, rules.cleanSeconds);
        expect(level.rules.successesPerTier, rules.successesPerTier);
        expect(level.rules.finalChallenges, rules.finalChallenges);
        expect(level.rules.resetAfterFailures, rules.resetAfterFailures);
        for (final notes in [1, 4, 7, 8, 16]) {
          for (final atPeak in [false, true]) {
            expect(
              level.rules.requiredHits(notes, atPeak: atPeak),
              rules.requiredHits(notes, atPeak: atPeak),
            );
          }
        }

        expect(level.chart.limbs, chart.limbs);
        expect(level.chart.offsets, chart.offsets);
        expect(level.chart.variants, chart.variants);
        expect(level.chart.callBeats, chart.callBeats);
        expect(level.chart.introBeats, chart.introBeats);
        expect(level.chart.flourishDestination, chart.flourishDestination);

        final crowd = CrowdStageProfile.forRoom(id);
        expect(level.crowd.roomId, crowd.roomId);
        expect(level.crowd.interested, crowd.interested);
        expect(level.crowd.following, crowd.following);
        expect(level.crowd.standing, crowd.standing);
        expect(level.crowd.cheering, crowd.cheering);
      });

      test('$id floor, guests, props and route', () {
        final level = levels.byId(id);
        final layout = partyRoomLayouts[id]!;
        expect(level.layout.calibration, layout.calibration);
        expect(level.layout.floor.horizonY, layout.floor.horizonY);
        expect(level.layout.floor.referenceFootY, layout.floor.referenceFootY);
        expect(
          level.layout.floor.referenceHeight,
          layout.floor.referenceHeight,
        );
        // Who sits where left this comparison with the owner's tenth round: the
        // rules for it are in crowd_staging_test.dart.

        final route = roomDepartures[id]!;
        expect(level.route.threshold, route.threshold);
        String stop(DepartureWaypoint w) =>
            '${w.progress} ${w.pose.x} ${w.pose.y} ${w.pose.facing}';
        expect(
          level.route.waypoints.map(stop).toList(),
          route.waypoints.map(stop).toList(),
        );
      });
    }

    test('marks that used to be inline in the scene', () {
      final garden = levels.byId('garden');
      final bar = levels.byId('bar');
      for (final (level, homeY, challengerY, sideX, sideY) in [
        // Forward and further aside since the owner's tenth round.
        (garden, .69, .565, .70, .535),
        (bar, .62, .48, .69, .455),
      ]) {
        for (final entrance in [0.0, .25, .6, 1.0]) {
          for (final retreat in [0.0, .5, 1.0]) {
            final hero = level.stage.heroFloor(
              entrance: entrance,
              retreat: retreat,
            );
            expect(hero.x, closeTo(.5, 1e-9));
            expect(
              hero.y,
              closeTo(homeY + (1 - entrance) * .07 + retreat * .04, 1e-9),
            );
          }
        }
        for (final yielded in [0.0, .3, 1.0]) {
          final mark = level.stage.challengers.single.floorAt(yielded);
          // Moved from x .70 on 2026-11-05: a seated guest hid the dancer there.
          expect(mark.x, closeTo(.5 + (sideX - .5) * yielded, 1e-9));
          expect(
            mark.y,
            closeTo(challengerY + (sideY - challengerY) * yielded, 1e-9),
          );
        }
        for (final travel in [0.0, .1, .5, .9, 1.0]) {
          final pose = level.route.sample(travel);
          final exit = level.heroExitFloor(pose);
          expect(exit.x, pose.x);
          expect(exit.y, closeTo(homeY + pose.y - .67, 1e-9));
        }
      }
      expect(garden.stage.challengers.single.atlas, 'gatekeeper');
      expect(bar.stage.challengers.single.atlas, 'bartender');
    });

    test(
      'order, bridge, count and copy are what the page used to hard-code',
      () {
        expect(levels.levels.map((level) => level.id), [
          'garden',
          'pool-garden',
          'bar',
          'cool-crowd',
        ]);
        expect(levels.displayTotal, 5);
        final [garden, lawn, bar, party] = levels.campaign;
        expect(garden.next, same(lawn.level));
        expect(garden.bridgeToNext, 'garden_to_pool');
        expect(lawn.next, same(bar.level));
        expect(lawn.bridgeToNext, 'pool_to_bar');
        expect(bar.next, same(party.level));
        expect(bar.bridgeToNext, 'bar_to_crowd');
        expect(party.next, isNull);
        expect(party.bridgeToNext, isNull);
        expect(levels.exitScoreIds, {
          'garden_mojo_success',
          'garden_to_pool',
          'pool_swing_success',
          'pool_to_bar',
          'bar_swag_success',
          'bar_to_crowd',
          'crowd_duende_success',
        });
        expect(garden.level.copy.clearedShout, 'MUCHO MOJO');
        expect(bar.level.copy.clearedShout, 'MUY SUAVE');
        expect(lawn.level.copy.clearedShout, 'QUÉ FINO');
        expect(garden.level.rules.metric.toUpperCase(), 'MOJO');
        expect(bar.level.rules.metric.toUpperCase(), 'SWAG');
      },
    );

    test('planned rooms stay planned', () {
      for (final id in ['restroom', 'vip']) {
        expect(fights.map((fight) => fight.id), contains(id));
        expect(() => levels.byId(id), throwsArgumentError);
      }
    });

    test('everything a shipping level names exists on disk', () {
      final manifest = jsonDecode(
        File('assets/art/ensemble/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final atlases = manifest['atlases'] as Map<String, dynamic>;
      for (final step in levels.campaign) {
        final level = step.level;
        expect(File('assets/art/${level.background}').existsSync(), isTrue);
        for (final prop in level.layers) {
          expect(File('assets/art/${prop.atlas}').existsSync(), isTrue);
        }
        for (final score in [
          level.music.score,
          level.music.successScore,
          ?step.bridgeToNext,
        ]) {
          expect(File('assets/music/scores/$score.json').existsSync(), isTrue);
        }
        for (final challenger in level.stage.challengers) {
          expect(atlases, contains(challenger.atlas));
        }
      }
    });
  });

  group('unknown ids fail loudly instead of becoming the garden', () {
    test('crowd lookup has no fallback room', () {
      expect(
        () => CrowdStageProfile.forRoom('no-such-room'),
        throwsArgumentError,
      );
    });

    test('a session for an unlisted room with no budgets is refused', () {
      final audio = _ClockOnly();
      final music = MusicTransport(
        MusicScore.fromJson(
          jsonDecode(
            File('assets/music/scores/bar_swag.json').readAsStringSync(),
          ) as Map<String, dynamic>,
        ),
        audio,
      );
      expect(
        () => GardenSession(
          music,
          audio,
          definition: const FightDefinition(
            'no-such-room',
            'Cool',
            60,
            1,
            2,
            5,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('registry lookup names the missing level', () {
      expect(() => _shipping().byId('no-such-room'), throwsArgumentError);
    });

    test('the campaign refuses a level file it cannot find', () {
      expect(
        () => LevelRegistry.parse(
          '{"campaign": [{"level": "no-such-level"}]}',
          _file,
        ),
        throwsA(isA<PathNotFoundException>()),
      );
    });

    test('a background path never picks a room', () {
      final level = _editedBar((bar) {
        bar['id'] = 'pool-garden';
        bar['background'] = 'pool/bar-stools.png';
        (bar['stage'] as Map)['heroHome'] = [.3, .7];
      });
      expect(level.stage.heroHome.x, .3);
      expect(level.layout.id, 'pool-garden');
      expect(level.crowd.roomId, 'pool-garden');
      expect(level.layout.guests.first.id, 'pool-garden-guest-0');
    });

    test('the scene refuses an atlas it does not have', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final scene = GardenSceneGame(firstLevel: () async => _shipping().first);
      await scene.onLoad();
      final level = _editedBar((bar) {
        (((bar['stage'] as Map)['challengers'] as List).first as Map)['atlas'] =
            'lifeguard';
      });
      await expectLater(scene.showLevel(level), throwsStateError);
    });

    testWidgets('a bad level file stops the page with an error, not a room', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GardenPage(
            audioFactory: _NoAudio.new,
            levels: () async =>
                throw const LevelDataError('bar.json', 'broken on purpose'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('The garden could not load. Please refresh.'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.textContaining('THE GARDEN'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      // The scene reports the same failure as art that could not load.
      tester.takeException();
    });
  });

  group('level data is validated at load', () {
    void refused(
      String why,
      String path,
      void Function(Map<String, dynamic>) edit,
    ) {
      test(why, () => expect(() => _editedBar(edit), _dataError(path)));
    }

    Map<String, dynamic> of(Map<String, dynamic> bar, String key) =>
        bar[key] as Map<String, dynamic>;

    refused('a misspelt field', 'level', (bar) => bar['backgroud'] = 'x.png');
    refused('a misspelt nested field', 'stage', (bar) {
      of(bar, 'stage')['heroHomee'] = [.5, .5];
    });
    refused('a missing section', 'level.copy', (bar) => bar.remove('copy'));
    refused('a title that is one word', 'copy.clearedTitle', (bar) {
      of(bar, 'copy')['clearedTitle'] = 'SUAVE';
    });
    refused('a title of three words', 'copy.clearedTitle', (bar) {
      of(bar, 'copy')['clearedTitle'] = 'MUY\nMUY SUAVE';
    });
    refused('a text line the game no longer shows', 'copy', (bar) {
      of(bar, 'copy')['clearedClaim'] = 'THE BAR IS YOURS.';
    });
    refused('a cue with no such sound', 'cue[0].track', (bar) {
      ((of(bar, 'exitShot')['cue'] as List)[0] as Map)['track'] = 'kazoo';
    });
    refused('a limb that does not exist', 'chart.limbs[0]', (bar) {
      (of(bar, 'chart')['limbs'] as List)[0] = 'tail';
    });
    refused('offsets that do not match the limbs', 'level.chart', (bar) {
      (of(bar, 'chart')['offsets'] as List).removeLast();
    });
    refused('a variant with a different note count', 'level.chart', (bar) {
      ((of(bar, 'chart')['variants'] as List).first as List).removeLast();
    });
    refused('an intro of no length', 'chart.introBeats', (bar) {
      of(bar, 'chart')['introBeats'] = 0;
    });
    refused('a mark off the image', 'stage.heroHome[1]', (bar) {
      of(bar, 'stage')['heroHome'] = [.5, 1.2];
    });
    refused('a hero above the horizon', 'stage.heroHome', (bar) {
      of(bar, 'stage')['heroHome'] = [.5, .1];
    });
    refused('a guest above the horizon', 'crowd.guests[0]', (bar) {
      (of(bar, 'crowd')['guests'] as List)[0] = [.2, .1];
    });
    refused('a floor with its horizon below the feet', 'stage.floor', (bar) {
      of(of(bar, 'stage'), 'floor')['horizonY'] = .5;
    });
    refused('a level with no challenger', 'stage.challengers', (bar) {
      of(bar, 'stage')['challengers'] = <Object?>[];
    });
    refused('two challengers with one id', 'stage.challengers', (bar) {
      final dancers = of(bar, 'stage')['challengers'] as List;
      dancers.add(dancers.first);
    });
    refused('budgets that are not cumulative', 'crowd.budgets', (bar) {
      of(of(bar, 'crowd'), 'budgets')['following'] = 9;
    });
    refused('more guests than a phone is asked to draw', 'crowd.guests', (bar) {
      final crowd = of(bar, 'crowd');
      crowd['guests'] = List.filled(CrowdInterestModel.maxGuests + 1, [.2, .4]);
    });
    refused('a guest on the tap band', 'crowd.guests[0]', (bar) {
      of(bar, 'crowd')['guests'] = [
        [.2, .7],
      ];
    });
    refused('a table on the tap band', 'crowd.props[0]', (bar) {
      of(bar, 'crowd')['props'] = [
        {
          'id': 'x',
          'kind': 'table',
          'at': [.2, .7],
          'heightInAdults': .43,
          'widthInAdults': .6,
        },
      ];
    });
    refused('a stool placed by hand', 'props[0].kind', (bar) {
      of(bar, 'crowd')['props'] = [
        {
          'id': 'x',
          'kind': 'stool',
          'at': [.5, .5],
          'heightInAdults': 1,
          'widthInAdults': 1,
        },
      ];
    });
    refused('a chair placed by hand', 'props[0].kind', (bar) {
      of(bar, 'crowd')['props'] = [
        {
          'id': 'x',
          'kind': 'chair',
          'at': [.5, .5],
          'heightInAdults': 1,
          'widthInAdults': 1,
        },
      ];
    });
    refused('a lead shape the synth cannot play', 'music.leadShape', (bar) {
      of(bar, 'music')['leadShape'] = 'kazoo';
    });
    refused('an unknown facing', 'waypoints[0].facing', (bar) {
      ((of(bar, 'departure')['waypoints'] as List).first as Map)['facing'] =
          'sideways';
    });
    refused('a route that stops short', 'departure.waypoints', (bar) {
      (of(bar, 'departure')['waypoints'] as List).removeLast();
    });
    refused('a route that runs backwards', 'waypoints[1]', (bar) {
      ((of(bar, 'departure')['waypoints'] as List)[1] as Map)['at'] = 0;
    });

    String index(List<Map<String, Object?>> campaign, {int? total}) =>
        jsonEncode({'displayTotal': ?total, 'campaign': campaign});

    test('a file holding a different level', () {
      expect(
        () => LevelRegistry.parse(
          index([
            {'level': 'bar'},
          ]),
          (_) => _file('garden'),
        ),
        _dataError('bar.json'),
      );
    });
    test('a level listed twice', () {
      expect(
        () => LevelRegistry.parse(
          index([
            {'level': 'bar', 'bridgeToNext': 'x'},
            {'level': 'bar'},
          ]),
          _file,
        ),
        _dataError('campaign[1]'),
      );
    });
    test('a level with no bridge to the next', () {
      expect(
        () => LevelRegistry.parse(
          index([
            {'level': 'garden'},
            {'level': 'bar'},
          ]),
          _file,
        ),
        _dataError('campaign[0].bridgeToNext'),
      );
    });
    test('a bridge out of the last level', () {
      expect(
        () => LevelRegistry.parse(
          index([
            {'level': 'bar', 'bridgeToNext': 'x'},
          ]),
          _file,
        ),
        _dataError('campaign[0].bridgeToNext'),
      );
    });
    test('an empty campaign', () {
      expect(
        () => LevelRegistry.parse(index([]), _file),
        _dataError('index.campaign'),
      );
    });
    test('a display total smaller than the campaign', () {
      expect(
        () => LevelRegistry.parse(
          index([
            {'level': 'garden', 'bridgeToNext': 'x'},
            {'level': 'bar'},
          ], total: 1),
          _file,
        ),
        _dataError('index.displayTotal'),
      );
    });
    test('the display total defaults to the campaign length', () {
      final levels = LevelRegistry.parse(
        index([
          {'level': 'bar'},
        ]),
        _file,
      );
      expect(levels.displayTotal, 1);
    });
  });
}
