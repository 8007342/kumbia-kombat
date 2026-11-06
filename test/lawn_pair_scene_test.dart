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
  Future<({String score, Set<String> heroRects})> play(
    WidgetTester tester, {
    required bool spinning,
    int cycles = 3,
    String? review,
  }) async {
    late String score;
    final rects = <String>{};
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
                '${r.right.toStringAsFixed(5)} ${r.bottom.toStringAsFixed(5)}]';
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
      // Everything the music reaches, in order: taps, and looks at the picture.
      final moments = <(double, void Function(), String?)>[];
      for (var cycle = 0; cycle < cycles; cycle++) {
        final start = chart.introBeats + cycle * chart.cycleBeats;
        moments.add((start + 2, () {}, 'c$cycle-call'));
        moments.add((start + chart.callBeats + 3.5, () {}, 'c$cycle-answer'));
        for (var i = 0; i < chart.offsets.length; i++) {
          final at = start + chart.callBeats + chart.offsets[i];
          moments.add((
            at,
            () => log.add('$cycle/$i/${session.tap(session.activeLimbs[i]).grade}'),
            null,
          ));
          // The third note's flourish, then on the second turn the very last
          // note's, which runs on into the next call.
          if (spinning && (i == 2 || (i == chart.offsets.length - 1 && cycle == 1))) {
            final tag = i == 2 ? 'c$cycle-spin' : 'c$cycle-overflow';
            moments.add((at + 1e-6, () => scene.flourishBeat = at, null));
            for (var after = .125; after < 2; after += .25) {
              moments.add((at + after, () {}, '$tag$after'));
            }
            if (i != 2) {
              for (final after in [2.25, 2.75, 3.5]) {
                moments.add((at + after, () {}, '$tag$after'));
              }
            }
          }
        }
        moments.add((
          start + chart.cycleBeats - .1,
          () => log.add(
            'perfects ${session.perfects} phase ${session.phase} '
            'position ${session.positionBeats.toStringAsFixed(4)} '
            'limbs ${session.activeLimbs} offsets ${session.activeOffsets}',
          ),
          null,
        ));
      }
      moments.sort((x, y) => x.$1.compareTo(y.$1));
      for (final (beat, act, name) in moments) {
        advance(music.secondsAt(beat));
        act();
        if (name != null) await look(name);
      }
      score = log.join('\n');
    });
    return (score: score, heroRects: rects);
  }

  testWidgets('a spin draws his held turn, and the score never knows', (
    tester,
  ) async {
    final plain = await play(tester, spinning: false);
    final spun = await play(tester, spinning: true, review: 'pair-review');
    expect(plain.heroRects, isEmpty, reason: 'no flourish, no spin');
    expect(
      spun.heroRects,
      level.stage.duet!.spin.heroFrames.toSet(),
      reason: 'a landed flourish plays his whole turn',
    );
    expect(spun.score, plain.score);
  });
}
