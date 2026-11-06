import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_sprites.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

import 'support/recording_canvas.dart';

String _read(String id) => File('levels/$id.json').readAsStringSync();

MusicScore _score(String id) => MusicScore.fromJson(
  jsonDecode(File('assets/music/scores/$id.json').readAsStringSync())
      as Map<String, dynamic>,
);

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final level = LevelRegistry.parse(
    File('levels/index.json').readAsStringSync(),
    _read,
  ).byId('pool-garden');
  final hero = PartyAtlasDefinition.fromJson(
    Map<String, dynamic>.from(
      ((jsonDecode(File('assets/art/party/manifest.json').readAsStringSync())
              as Map)['atlases']
          as Map)['hero'] as Map,
    ),
  );

  /// Plays [cycles] calls and answers, tapping every note on its beat. With
  /// [spinning], every answer lands a flourish on its third note, as far as the
  /// scene can tell. Returns what the player would be scored, and the frames.
  Future<({String score, Set<String> heroRects, Set<double> reviewed})> play(
    WidgetTester tester, {
    required bool spinning,
    int cycles = 3,
    String? review,
  }) async {
    late String score;
    final rects = <String>{};
    final reviewed = <double>{};
    await tester.runAsync(() async {
      final scene = GardenSceneGame(firstLevel: () async => level);
      scene.onGameResize(Vector2(390, 844));
      await scene.onLoad();
      final audio = _Audio();
      final music = MusicTransport(
        _score(level.music.score),
        audio,
        loop: true,
        lookaheadSeconds: .3,
      );
      final session = level.newSession(music, audio)..start();
      scene.session = session;
      void advance(double target) {
        while (audio.nowSeconds < target - 1e-6) {
          audio.nowSeconds = (audio.nowSeconds + .02).clamp(0, target);
          music.pump();
          session.advance();
        }
      }

      Future<void> look(String name) async {
        final canvas = RecordingCanvas();
        scene.render(canvas);
        for (final call in canvas.calls) {
          for (final frame in level.stage.duet!.spin.heroFrames) {
            final r = hero.frames[frame]!.source;
            final text =
                '[${r.left.toStringAsFixed(5)} ${r.top.toStringAsFixed(5)} '
                '${r.width.toStringAsFixed(5)} ${r.height.toStringAsFixed(5)}]';
            if (call.contains(text)) rects.add(frame);
          }
        }
        if (review == null) return;
        final directory = Directory('build/$review')..createSync(recursive: true);
        final recorder = ui.PictureRecorder();
        scene.render(ui.Canvas(recorder));
        final image = await recorder.endRecording().toImage(390, 844);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${directory.path}/$name.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      }

      final chart = session.chart;
      final log = <String>[];
      for (var cycle = 0; cycle < cycles; cycle++) {
        final start = chart.introBeats + cycle * chart.cycleBeats;
        advance(music.secondsAt(start + 2));
        if (cycle < 2) await look('c$cycle-call');
        for (var i = 0; i < chart.offsets.length; i++) {
          advance(music.secondsAt(start + chart.callBeats + chart.offsets[i]));
          final note = session.tap(session.activeLimbs[i]);
          log.add('$cycle/$i/${note.grade}');
          if (i == 2 && spinning) {
            scene.flourishBeat = session.positionBeats;
            for (final after in [.25, .75, 1.25, 1.75]) {
              final at = scene.flourishBeat + after;
              if (at < start + chart.callBeats + chart.offsets[3]) {
                advance(music.secondsAt(at));
                await look('c$cycle-spin$after');
                reviewed.add(after);
              }
            }
          }
        }
        advance(music.secondsAt(start + chart.cycleBeats - .1));
        await look('c$cycle-end');
        log.add(
          'perfects ${session.perfects} phase ${session.phase} '
          'position ${session.positionBeats.toStringAsFixed(4)} '
          'limbs ${session.activeLimbs} offsets ${session.activeOffsets}',
        );
      }
      score = log.join('\n');
    });
    return (score: score, heroRects: rects, reviewed: reviewed);
  }

  testWidgets('a spin draws his held turn, and the score never knows', (
    tester,
  ) async {
    final plain = await play(tester, spinning: false);
    final spun = await play(tester, spinning: true, review: 'pair-review');
    expect(plain.heroRects, isEmpty, reason: 'no flourish, no spin');
    expect(spun.heroRects, isNotEmpty, reason: 'a landed flourish shows');
    expect(spun.score, plain.score);
  });
}
