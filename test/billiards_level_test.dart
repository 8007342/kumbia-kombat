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

/// The billiard room, on real game code and its real level file:
/// `plan/levels/billiards-2026-11-07.md`.
String _read(String id) => File('levels/$id.json').readAsStringSync();

LevelRegistry _registry() =>
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

  test('stills of the room through the real scene', () async {
    final registry = _registry().reviewing('billiards');
    final level = registry.first;
    final scene = GardenSceneGame(firstLevel: () async => level);
    scene.onGameResize(Vector2(390, 844));
    await scene.onLoad();
    await scene.showLevel(level);
    Directory('build/stills').createSync(recursive: true);
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
    final rows = <ui.Image>[];
    Future<void> at(double beat) async {
      advance(music.secondsAt(beat));
      rows.add(await _still(scene, 390, 844));
    }

    await at(3);
    await at(11);
    await at(chart.introBeats + 2);
    await at(chart.introBeats + chart.callBeats + 2);
    final beat = session.positionBeats;
    for (var i = 0; i < 40; i++) {
      session.crowd.resolvePhrase(sequence: 1000 + i, passed: true, beat: beat);
    }
    scene.presentationBeat = beat + 70;
    rows.add(await _still(scene, 390, 844));
    scene.presentationBeat = null;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    for (final (i, image) in rows.indexed) {
      canvas.drawImage(image, ui.Offset(i * 396.0, 0), ui.Paint());
    }
    final sheet = await recorder.endRecording().toImage(396 * rows.length, 844);
    final png = await sheet.toByteData(format: ui.ImageByteFormat.png);
    File('build/stills/billiards.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
}
