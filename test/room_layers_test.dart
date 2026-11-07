import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/ensemble_sprites.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_layout.dart';
import 'package:kumbia_kombat/gameplay/party_up.dart';
import 'package:kumbia_kombat/gameplay/room_layers.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

import 'support/recording_canvas.dart';

Map<String, Object?> _gardenJson() =>
    jsonDecode(File('levels/garden.json').readAsStringSync())
        as Map<String, Object?>;

LevelDefinition _garden() => LevelDefinition.fromJson(_gardenJson());

(int, int) _pngSize(String path) {
  final data = ByteData.sublistView(File(path).readAsBytesSync());
  return (data.getUint32(16), data.getUint32(20));
}

RoomLayerProp _prop({
  RoomLayerMotion motion = RoomLayerMotion.sway,
  int left = 10,
  int top = 10,
  int width = 40,
  int height = 40,
  int instance = 0,
}) => RoomLayerProp(
  id: 'p',
  atlas: 'a.png',
  atlasY: 0,
  left: left,
  top: top,
  width: width,
  height: height,
  frames: 7,
  motion: motion,
  periodBeats: 2,
  instance: instance,
  kind: PartyLifeKind.plant,
);

Map<String, Object?> _withLayer(Map<String, Object?> overrides) {
  final json = _gardenJson();
  final layers = json['layers']! as Map<String, Object?>;
  final first = (layers['props']! as List).first as Map<String, Object?>;
  layers['props'] = [
    {...first, ...overrides},
  ];
  return json;
}

class _Audio implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  @override
  void silence() {}
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {}
}

/// The layer draws the scene made: (source rect left, destination bottom).
List<(double, double)> _layerDraws(GardenSceneGame scene, LevelDefinition g) {
  final atlas = _pngSize('assets/art/${g.layers.first.atlas}');
  final canvas = RecordingCanvas();
  scene.render(canvas);
  final pattern = RegExp(
    r'^drawImageRect image:' '${atlas.$1}x${atlas.$2}'
    r' \[(\S+) \S+ \S+ \S+\] \[\S+ \S+ \S+ (\S+)\]',
  );
  return [
    for (final call in canvas.calls)
      if (pattern.firstMatch(call) case final match?)
        (double.parse(match[1]!), double.parse(match[2]!)),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a table\'s drink', () {
    test('stands still until the crowd swings, or with motion reduced', () {
      for (final beat in [0.0, .5, 1.3, 77.7]) {
        expect(tableCupFrame(beat: beat, swing: 0), 'cup_2');
        expect(
          tableCupFrame(beat: beat, swing: 1, reducedMotion: true),
          'cup_2',
        );
      }
      expect(tableCupFrame(beat: -1, swing: 1), 'cup_2');
      expect(tableCupFrame(beat: double.nan, swing: 1), 'cup_2');
    });

    test('leans either way on the beat at full swing, by every drawing', () {
      expect(tableCupFrame(beat: 40, swing: 1), 'cup_4');
      expect(tableCupFrame(beat: 41, swing: 1), 'cup_0');
      expect(
        {for (var b = 40.0; b < 42; b += .02) tableCupFrame(beat: b, swing: 1)},
        {'cup_0', 'cup_1', 'cup_2', 'cup_3', 'cup_4'},
      );
    });

    test('is baked for the rooms with tables, at one height', () {
      final sets =
          (jsonDecode(File('assets/art/props/manifest.json').readAsStringSync())
                  as Map<String, Object?>)['sets']!
              as Map<String, Object?>;
      for (final id in ['garden', 'pool-garden']) {
        final frames =
            (sets[id]! as Map<String, Object?>)['frames']!
                as Map<String, Object?>;
        final heights = {
          for (var i = 0; i < 5; i++)
            ((frames['cup_$i']! as Map<String, Object?>)['rect']! as List)[3],
        };
        expect(heights.length, 1, reason: id);
      }
    });
  });

  group('the data', () {
    test('the garden names its clean plate and props', () {
      final garden = _garden();
      expect(garden.background, 'garden/garden-mansion-clean.png');
      expect(garden.layers, isNotEmpty);
      expect(garden.layers.map((p) => p.id).toSet().length, garden.layers.length);
    });

    test('every frame of every prop is inside its atlas', () {
      final garden = _garden();
      for (final prop in garden.layers) {
        final file = 'assets/art/${prop.atlas}';
        expect(File(file).existsSync(), isTrue, reason: file);
        final (width, height) = _pngSize(file);
        expect(
          prop.atlasX(prop.frames - 1) + prop.width,
          lessThanOrEqualTo(width),
          reason: prop.id,
        );
        expect(prop.atlasY + prop.height, lessThanOrEqualTo(height));
      }
    });

    for (final (id, clean, painted) in const [
      (
        'pool-garden',
        'pool-garden/pool-garden-clean.png',
        'pool-garden/pool-garden-v1-draft.png',
      ),
      ('bar', 'bar/bar-interior-clean.png', 'bar/bar-interior.png'),
    ]) {
      test('$id has a clean plate and props of its own', () {
        final level = LevelDefinition.fromJson(
          jsonDecode(File('levels/$id.json').readAsStringSync())
              as Map<String, Object?>,
        );
        expect(level.background, clean);
        expect(level.layers.length, greaterThanOrEqualTo(8));
        expect(level.layers.map((p) => p.id).toSet().length, level.layers.length);
        expect(_pngSize('assets/art/$clean'), _pngSize('assets/art/$painted'));
        for (final prop in level.layers) {
          final (width, height) = _pngSize('assets/art/${prop.atlas}');
          expect(
            prop.atlasX(prop.frames - 1) + prop.width,
            lessThanOrEqualTo(width),
            reason: prop.id,
          );
          expect(prop.atlasY + prop.height, lessThanOrEqualTo(height));
          expect(prop.placementProblem(1024, 1536), isNull, reason: prop.id);
        }
        expect(
          level.layers.map((p) => p.instance).toSet().length,
          level.layers.length,
          reason: 'props wake one by one',
        );
      });
    }

    test('the clean plate has the same size as the painting it replaces', () {
      expect(
        _pngSize('assets/art/garden/garden-mansion-clean.png'),
        _pngSize('assets/art/garden/garden-mansion.png'),
      );
    });

    test('a level without layers still loads, with none', () {
      final json = _gardenJson()..remove('layers');
      expect(LevelDefinition.fromJson(json).layers, isEmpty);
    });

    test('an unknown field or motion is refused', () {
      expect(
        () => LevelDefinition.fromJson(_withLayer({'wobble': 1})),
        throwsA(isA<LevelDataError>()),
      );
      expect(
        () => LevelDefinition.fromJson(_withLayer({'motion': 'spin'})),
        throwsA(isA<LevelDataError>()),
      );
    });

    test('two props may not share an id', () {
      final json = _gardenJson();
      final layers = json['layers']! as Map<String, Object?>;
      final first = (layers['props']! as List).first;
      layers['props'] = [first, first];
      expect(
        () => LevelDefinition.fromJson(json),
        throwsA(isA<LevelDataError>()),
      );
    });
  });

  group('off the tap band', () {
    test('every shipped prop stays clear of the band and the quiet area', () {
      final garden = _garden();
      for (final prop in garden.layers) {
        expect(prop.placementProblem(1024, 1536), isNull, reason: prop.id);
        expect(
          (prop.top + prop.height) / 1536,
          lessThan(roomLayerTapBandTop),
          reason: prop.id,
        );
      }
    });

    test('the loader refuses a prop in the band', () {
      expect(
        () => LevelDefinition.fromJson(
          _withLayer({'top': 1000, 'height': 40, 'left': 10}),
        ),
        throwsA(
          isA<LevelDataError>().having(
            (e) => e.message,
            'message',
            contains('tap band'),
          ),
        ),
      );
    });

    test('a prop crossing into the band is refused too', () {
      final top = (roomLayerTapBandTop * 1536).floor() - 5;
      expect(
        _prop(top: top, height: 20).placementProblem(1024, 1536),
        contains('tap band'),
      );
      expect(
        _prop(top: top - 20, height: 20).placementProblem(1024, 1536),
        isNull,
      );
    });

    test('the loader refuses a prop behind the opponent', () {
      expect(
        () => LevelDefinition.fromJson(
          _withLayer({'top': 600, 'height': 40, 'left': 500, 'width': 40}),
        ),
        throwsA(
          isA<LevelDataError>().having(
            (e) => e.message,
            'message',
            contains('quiet'),
          ),
        ),
      );
    });

    test('a prop may not leave the plate', () {
      expect(
        _prop(left: 1000, width: 40).placementProblem(1024, 1536),
        'leaves the plate',
      );
    });

    test('on screen, drawn props end above the band on any phone', () async {
      final garden = _garden();
      final scene = GardenSceneGame(firstLevel: () async => garden);
      for (final size in [Vector2(390, 844), Vector2(1080, 1920)]) {
        scene.onGameResize(size);
        if (!scene.isLoaded) await scene.onLoad();
        final viewport = PartyViewport(size.x, size.y);
        final band = viewport.project(
          const PartyPoint(.5, roomLayerTapBandTop),
        );
        final draws = _layerDraws(scene, garden);
        expect(draws.length, garden.layers.length);
        for (final (_, bottom) in draws) {
          expect(bottom, lessThan(band.y));
        }
      }
    });
  });

  group('the beat', () {
    test('no swing, no movement: the painted original', () {
      for (final motion in RoomLayerMotion.values) {
        final prop = _prop(motion: motion);
        for (final beat in [0.0, .5, 1.3, 77.7]) {
          expect(prop.frameAt(beat: beat, swing: 0), prop.restFrame);
        }
      }
    });

    test('at the top it moves, and only the beat decides how', () {
      for (final motion in RoomLayerMotion.values) {
        final prop = _prop(motion: motion);
        final seen = {
          for (var beat = 40.0; beat < 44; beat += .01)
            prop.frameAt(beat: beat, swing: 1),
        };
        expect(seen.length, 7, reason: '$motion uses every drawing');
        expect(
          prop.frameAt(beat: 41.3, swing: 1),
          prop.frameAt(beat: 41.3 + prop.periodBeats, swing: 1),
          reason: 'one period later is the same drawing',
        );
      }
    });

    test('both motions peak on the beat, so they hit with the music', () {
      final pulse = _prop(motion: RoomLayerMotion.pulse);
      expect(pulse.frameAt(beat: 40, swing: 1), pulse.frames - 1);
      expect(pulse.frameAt(beat: 41, swing: 1), pulse.restFrame);
      final sway = _prop();
      expect(sway.frameAt(beat: 40, swing: 1), sway.frames - 1);
      expect(sway.frameAt(beat: 41, swing: 1), 0);
    });

    test('the range grows gradually, never switching on at full size', () {
      for (final motion in RoomLayerMotion.values) {
        final prop = _prop(motion: motion);
        int reach(double swing) {
          var most = 0;
          for (var beat = 40.0; beat < 44; beat += .01) {
            final away = (prop.frameAt(beat: beat, swing: swing) -
                    prop.restFrame)
                .abs();
            most = math.max(most, away);
          }
          return most;
        }

        var last = 0;
        for (var swing = 0.0; swing <= 1; swing += .02) {
          final now = reach(swing);
          expect(now, greaterThanOrEqualTo(last));
          expect(now - last, lessThanOrEqualTo(1), reason: 'at swing $swing');
          last = now;
        }
        expect(last, prop.frames - 1 - prop.restFrame);
      }
    });

    test('props wake one by one', () {
      final woken = [
        for (var instance = 0; instance < 12; instance++)
          () {
            final prop = _prop(instance: instance);
            return prop.frameAt(beat: 40, swing: .25) != prop.restFrame;
          }(),
      ];
      expect(woken.contains(true), isTrue);
      expect(woken.contains(false), isTrue);
    });

    test('reduced motion holds the painted original at any swing', () {
      for (final motion in RoomLayerMotion.values) {
        final prop = _prop(motion: motion);
        for (var beat = 40.0; beat < 44; beat += .1) {
          expect(
            prop.frameAt(beat: beat, swing: 1, reducedMotion: true),
            prop.restFrame,
          );
        }
      }
    });

    test('a beat before the music starts, or no beat, is at rest', () {
      final prop = _prop();
      expect(prop.frameAt(beat: -1, swing: 1), prop.restFrame);
      expect(prop.frameAt(beat: double.nan, swing: 1), prop.restFrame);
    });
  });

  group('in the scene', () {
    test('at rest before the game starts, from the painted frames', () async {
      final garden = _garden();
      final scene = GardenSceneGame(firstLevel: () async => garden);
      scene.onGameResize(Vector2(390, 844));
      await scene.onLoad();
      final draws = _layerDraws(scene, garden);
      expect(draws.map((d) => d.$1), [
        for (final prop in garden.layers) prop.atlasX(prop.restFrame).toDouble(),
      ]);
    });

    test(
      'a flawless run sets them dancing, on the beat, unless motion is reduced',
      () async {
        final garden = _garden();
        final scene = GardenSceneGame(firstLevel: () async => garden);
        scene.onGameResize(Vector2(390, 844));
        await scene.onLoad();
        final audio = _Audio();
        final score = MusicScore.fromJson(
          jsonDecode(
            File('assets/music/scores/${garden.music.score}.json')
                .readAsStringSync(),
          ) as Map<String, dynamic>,
        );
        final music = MusicTransport(
          score,
          audio,
          loop: true,
          lookaheadSeconds: .3,
        );
        final session = garden.newSession(music, audio);
        scene.session = session;
        void advance(double target) {
          while (audio.nowSeconds < target - .000001) {
            audio.nowSeconds = math.min(target, audio.nowSeconds + .02);
            music.pump();
            session.advance();
            scene.update(.02);
          }
        }

        session.start();
        final rest = [
          for (final prop in garden.layers)
            prop.atlasX(prop.restFrame).toDouble(),
        ];
        expect(_layerDraws(scene, garden).map((d) => d.$1), rest);

        var moved = false;
        var cycle = 0;
        while (session.phase != GardenPhase.cleared && cycle < 40) {
          final start =
              session.chart.introBeats + cycle * session.chart.cycleBeats;
          for (var i = 0; i < session.activeLimbs.length; i++) {
            final target =
                start + session.chart.callBeats + session.chart.offsets[i];
            advance(music.secondsAt(target));
            session.tap(session.activeLimbs[i]);
            if (session.phase == GardenPhase.cleared) break;
            advance(music.secondsAt(target + .3));
            final now = _layerDraws(scene, garden).map((d) => d.$1).toList();
            if (now.join() != rest.join()) {
              moved = true;
              scene.reducedMotion = true;
              expect(_layerDraws(scene, garden).map((d) => d.$1), rest);
              scene.reducedMotion = false;
            }
          }
          cycle++;
        }
        expect(session.phase, GardenPhase.cleared);
        expect(moved, isTrue, reason: 'the top of the ladder reached the props');
      },
    );
  });
}
