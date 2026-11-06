import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/thumb_layout.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

/// Pictures of the real scene for review, at phone size, in `build/stills/`: one
/// row per room, with the rings where the thumbs land drawn over them. Every room
/// must also draw at each of these moments, which is what this test holds.
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

Future<ui.Image> _still(GardenSceneGame scene, int w, int h) async {
  scene.onGameResize(Vector2(w.toDouble(), h.toDouble()));
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  scene.render(canvas);
  final ring = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const ui.Color(0xCCFFFFFF);
  for (final limb in Limb.values) {
    final home = thumbHome(limb);
    canvas.drawCircle(ui.Offset(home.x * w, home.y * h), w * .09, ring);
  }
  return recorder.endRecording().toImage(w, h);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every room draws its crowd at each moment of a turn', () async {
    final levels = await LevelRegistry.loadShipping();
    final scene = GardenSceneGame(firstLevel: () async => levels.first);
    scene.onGameResize(Vector2(390, 844));
    await scene.onLoad();
    Directory('build/stills').createSync(recursive: true);
    for (final level in levels.levels) {
      await scene.showLevel(level);
      final audio = _Audio();
      final music = MusicTransport(
        _score(level.music.score),
        audio,
        loop: true,
        lookaheadSeconds: .3,
      );
      final session = level.newSession(music, audio);
      scene.session = session;
      session.start();
      void advance(double target) {
        while (audio.nowSeconds < target - 1e-6) {
          audio.nowSeconds = math.min(target, audio.nowSeconds + .02);
          music.pump();
          session.advance();
          scene.update(.02);
        }
      }

      await _still(scene, 390, 844);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final chart = level.chart;
      final rows = <(String, ui.Image)>[];
      Future<void> at(String name, double beat) async {
        advance(music.secondsAt(beat));
        rows.add((name, await _still(scene, 390, 844)));
      }

      await at('call', chart.introBeats + 2);
      await at('out-back', chart.introBeats + chart.cycleBeats + .9);
      await at('out-side', chart.introBeats + chart.cycleBeats + 2.2);
      await at('answer', chart.introBeats + chart.cycleBeats + chart.callBeats + 2);
      // The top of the ladder: the whole room up, as a good run leaves it.
      final beat = session.positionBeats;
      for (var i = 0; i < 40; i++) {
        session.crowd.resolvePhrase(sequence: 1000 + i, passed: true, beat: beat);
      }
      scene.presentationBeat = beat + 70;
      rows.add(('full-swing', await _still(scene, 390, 844)));
      scene.presentationBeat = null;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      for (final (i, (_, image)) in rows.indexed) {
        canvas.drawImage(image, ui.Offset(i * 396.0, 0), ui.Paint());
      }
      final sheet = await recorder.endRecording().toImage(
        396 * rows.length,
        844,
      );
      final png = await sheet.toByteData(format: ui.ImageByteFormat.png);
      File('build/stills/${level.id}.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    }
  });
}
