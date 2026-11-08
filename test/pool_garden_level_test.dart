import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_layout.dart';
import 'package:kumbia_kombat/gameplay/thumb_layout.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

import 'support/recording_canvas.dart';

/// The draft pool lawn, on real game code, as the campaign's third level.
const _plate = 'assets/art/pool-garden/pool-garden-clean.png';

String _read(String id) => File('levels/$id.json').readAsStringSync();

LevelRegistry _campaign() =>
    LevelRegistry.parse(File('levels/index.json').readAsStringSync(), _read);

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

MusicScore _score(String id) => MusicScore.fromJson(
  jsonDecode(File('assets/music/scores/$id.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// Logical height of Mācron on a 390x844 phone at a foot position.
double _heroLogical(LevelDefinition level, double footY) {
  final viewport = PartyViewport(390, 844);
  return viewport.sourceHeightToLogical(
    level.layout.floor.standingHeightAt(footY, stature: .35),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the lawn follows the garden and leads to the bar, over bridges written for it', () {
    final levels = _campaign();
    expect(levels.campaign.map((s) => s.level.id), [
      'garden',
      'pool-garden',
      'bar',
      'cool-crowd',
      'billiards',
      'comedor',
      'salon',
    ]);
    expect(levels.campaign[0].bridgeToNext, 'garden_to_pool');
    expect(levels.campaign[1].bridgeToNext, 'pool_to_bar');
    expect(levels.campaign.last.next, isNull);
  });

  test('the pair travel in depth, without touching the thumbs', () {
    // The turn by turn rules are in duet_staging_test.dart. This keeps the owner's
    // older ruling: they move toward and away from the viewer, at the floor's size.
    final level = _campaign().byId('pool-garden');
    final [a, b] = level.stage.challengers;
    expect(b.stature, lessThan(a.stature));
    final duet = level.stage.duet!;
    final plane = level.layout.floor;
    final heights = <double>[];
    for (var turn = 0; turn < duet.turns.length; turn++) {
      for (var t = 0.0; t < level.chart.cycleBeats; t += .25) {
        final yielded = t >= level.chart.callBeats ? 1.0 : 0.0;
        for (final dancer in [0, 1]) {
          final p = duet
              .sample(
                dancer: dancer,
                turn: turn,
                t: t,
                callBeats: level.chart.callBeats,
                floorYield: yielded,
                heroX: level.stage.heroHome.x,
              )
              .floor;
          expect(p.y, lessThan(level.stage.heroHome.y));
          expect(thumbLimbAt(.5, p.y), isNull);
          heights.add(plane.standingHeightAt(p.y));
        }
      }
    }
    final nearest = heights.reduce((x, y) => x > y ? x : y);
    final farthest = heights.reduce((x, y) => x < y ? x : y);
    expect(nearest / farthest, greaterThan(1.3));
  });

  test('the level file parses, and its floor is the compiled room\'s', () {
    final level = _campaign().byId('pool-garden');
    final floor = jsonDecode(
      File('art_runs/rooms/pool-garden/floor.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final plane = level.layout.floor;
    expect(plane.horizonY, closeTo(floor['horizonY'] as double, 1e-4));
    final eye = (plane.referenceFootY - plane.horizonY) / plane.referenceHeight;
    expect(eye, closeTo(floor['eyeHeightAdults'] as num, .01));
    expect(level.stage.challengers.length, 2);
  });

  test(
    'Mācron reads near garden size and the dance stays above the thumbs',
    () {
      final levels = _campaign();
      final level = levels.byId('pool-garden');
      final garden = levels.byId('garden');
      final near = _heroLogical(level, level.stage.heroHome.y);
      final gardenNear = _heroLogical(garden, garden.stage.heroHome.y);
      expect(gardenNear, closeTo(38.4, .3));
      expect(near, greaterThan(gardenNear * .88));

      // Feet at home and the challenger's whole mark are above the tap band.
      expect(thumbLimbAt(.5, level.stage.heroHome.y), isNull);
      for (final challenger in level.stage.challengers) {
        expect(thumbLimbAt(.5, challenger.mark.y), isNull);
        expect(thumbLimbAt(.5, challenger.yieldMark.y), isNull);
      }
      // The route ends inside what a 390x844 phone shows (source x .153-.847).
      final end = level.route.waypoints.last.pose;
      expect(end.x, inInclusiveRange(.17, .83));
    },
  );

  test('a session clears on the real rules, on its own chart', () {
    final level = _campaign().byId('pool-garden');
    final audio = _Audio();
    final music = MusicTransport(
      _score(level.music.score),
      audio,
      loop: true,
      lookaheadSeconds: .3,
    );
    final session = level.newSession(music, audio)..start();
    expect(session.progress.definition.id, 'pool-garden');
    void advance(double target) {
      while (audio.nowSeconds < target - 1e-6) {
        audio.nowSeconds = (audio.nowSeconds + .02).clamp(0, target);
        music.pump();
        session.advance();
      }
    }

    for (var cycle = 0; cycle < 60 && !session.progress.cleared; cycle++) {
      final start = session.chart.introBeats + cycle * session.chart.cycleBeats;
      final played = session.chart.patternFor(
        session.progress.tier,
        session.progress.fullTierSuccesses,
      );
      for (var i = 0; i < played.limbs.length; i++) {
        advance(
          music.secondsAt(start + session.chart.callBeats + played.offsets[i]),
        );
        expect(session.tap(played.limbs[i]).note, isNotNull);
      }
      advance(music.secondsAt(start + session.chart.cycleBeats - .05));
    }
    // At this tempo the last swipe's window outlasts the phrase, and the win
    // must still land within a second, not after another whole call.
    expect(session.progress.cleared, isTrue);
    advance(audio.nowSeconds + 1);
    expect(session.phase, GardenPhase.cleared);
  });

  test('the real scene draws the plate, cast and props from the level', () async {
    final level = _campaign().byId('pool-garden');
    final bytes = File(_plate).readAsBytesSync();
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
    final plate = (await codec.getNextFrame()).image;
    expect(plate.width, 1024);
    expect(plate.height, 1536);

    final scene = GardenSceneGame(firstLevel: () async => level);
    scene.images.add(level.background, plate);
    scene.onGameResize(Vector2(390, 844));
    await scene.onLoad();
    final audio = _Audio();
    final music = MusicTransport(
      _score(level.music.score),
      audio,
      loop: true,
      lookaheadSeconds: .3,
    );
    scene.session = level.newSession(music, audio);

    final canvas = RecordingCanvas();
    scene.render(canvas);
    expect(
      canvas.calls.where((c) => c.contains('image:1024x1536')),
      isNotEmpty,
    );
    expect(
      canvas.calls.where((c) => c.startsWith('drawCircle ')).length,
      level.scenery.lamps.length,
    );

    // A picture of the runtime for review: the same render call, at phone size.
    final recorder = ui.PictureRecorder();
    final real = ui.Canvas(recorder);
    scene.render(real);
    final image = await recorder.endRecording().toImage(390, 844);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build').createSync(recursive: true);
    File('build/pool-garden-runtime.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
}
