import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/band.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/gesture_shapes.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_autoplay.dart';
import 'package:kumbia_kombat/gameplay/party_layout.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/thumb_layout.dart';
import 'package:kumbia_kombat/music/accent_voice.dart';
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

  group('the room', () {
    final level = _registry().byId('billiards');

    bool onPaintedFloor(PartyPoint p) {
      // The painted floor, by hand: wall feet meet the door's foot at y .378.
      if (p.y < .378) return false;
      final side = (p.x - .5).abs();
      if (side <= .21) return true;
      return p.y >= .378 + (side - .21) * .18;
    }

    test('everyone stands on the floor that is painted', () {
      final stage = level.stage;
      for (final p in [
        stage.heroHome,
        stage.heroRetreat,
        stage.heroWatch,
        stage.challengers.first.mark,
        stage.challengers.first.yieldMark,
        ...level.layout.guests.map((g) => g.floor),
        for (final player in level.scenery.band!.players) player.at,
      ]) {
        expect(onPaintedFloor(p), isTrue, reason: '${p.x} ${p.y}');
      }
    });

    test('nobody stands in front of the opponent, or on the thumbs', () {
      final mark = level.stage.challengers.first.mark.y;
      for (final g in level.layout.guests) {
        expect(g.floor.y, lessThan(mark), reason: '${g.floor.x}');
        expect(g.floor.y, lessThan(thumbBandTop));
      }
      for (final player in level.scenery.band!.players) {
        expect(player.at.y, lessThan(mark), reason: player.id);
      }
    });

    test('the players start absorbed, and all watch before a level can clear', () {
      final players = level.scenery.band!.players;
      for (final player in players) {
        expect(player.rungFor(const BandInputs(tier: 0)), 0, reason: player.id);
        expect(
          player.rungFor(const BandInputs(tier: 4)),
          player.ladder.length - 1,
          reason: '${player.id} at the top tier',
        );
      }
      // They turn one by one, not together.
      expect(
        players.map((p) => p.rungFor(const BandInputs(tier: 1))).toSet(),
        hasLength(2),
      );
    });

    test('the reward is an accent a phone can play', () {
      final accent = level.music.moveAccent!;
      expect(accent.track, 'clack');
      expect(isAccentTrack('chalk'), isTrue);
    });
  });

  group('the cue stroke', () {
    final chart = _registry().byId('billiards').chart;

    test('every pattern offers one, and it has room', () {
      for (var i = 0; i <= chart.variants.length; i++) {
        final played = chart.pattern(i);
        expect(played.offers.contains(GestureKind.flick), isTrue, reason: '$i');
        expect(chart.fairnessProblems(i, 104), isEmpty, reason: '$i');
      }
    });

    test('a flawless autoplay run lands strokes and clears', () {
      final level = _registry().byId('billiards');
      final audio = _Audio();
      final music = MusicTransport(
        _score(level.music.score),
        audio,
        loop: true,
        lookaheadSeconds: .3,
      );
      final session = level.newSession(music, audio)..start();
      final demo = PartyAutoplay(flawless: true)..enabled = true;
      final kinds = <GestureKind>{};
      while (session.phase != GardenPhase.cleared && audio.nowSeconds < 600) {
        audio.nowSeconds += .02;
        music.pump();
        session.advance();
        demo.pump(
          session,
          onMove: (move) {
            if (move.offered == GestureKind.flick) kinds.add(move.kind);
          },
        );
      }
      expect(session.phase, GardenPhase.cleared);
      expect(kinds, contains(GestureKind.flick));
      expect(session.crowd.partySwing(session.completedAtBeat!), 1);
    });

    test('a level refuses an offer it has no such move for', () {
      final json = jsonDecode(_read('billiards')) as Map<String, dynamic>;
      json['chart']['rich']['patterns']['1'][0]['offer'] = 'cartwheel';
      expect(
        () => LevelDefinition.fromJson(json),
        throwsA(isA<LevelDataError>()),
      );
    });
  });

  group('the win', () {
    final level = _registry().byId('billiards');
    final shot = level.exitShot!;
    final her = shot.actors[3];
    final head = shot.actors[2];

    test('every drawing ships', () {
      for (final image in shot.images) {
        expect(File('assets/art/$image').existsSync(), isTrue, reason: image);
      }
    });

    test('the dab lands on the downbeat, with its squeak and the dot', () {
      expect(shot.contactBeat, 8);
      expect(
        shot.cue.where((c) => c.beat == 8).map((c) => c.track),
        contains('chalk'),
      );
      expect(head.frameAt(7.9), 'closeups/duet-macron-round.png');
      expect(head.frameAt(8), 'closeups/pool-macron-wide.png');
      expect(head.frameAt(10), 'closeups/pool-macron-arc-blush.png');
      expect(her.frameAt(7.25), contains('wink'));
      expect(her.frameAt(8), contains('dab'));
    });

    test('her cue tip meets the antenna', () {
      final places = shot.sample(8, reducedMotion: false);
      expect(places[3].offset.distance, 0);
      expect(places[2].offset.distance, 0);
      expect(her.contact, isNot(head.contact));
    });

    test('she chalks and winks before the dab, in that order', () {
      final beats = her.frames.map((f) => f.beat).toList();
      expect(beats, orderedEquals([...beats]..sort()));
      expect(shot.closeupFrom, lessThan(shot.contactBeat));
      expect(shot.closeupTo, lessThanOrEqualTo(11.5));
    });

    test('two words, the second from the party theme', () {
      expect(level.copy.clearedShout, 'QUÉ CARAMBOLA');
    });
  });

  test('stills of the room through the real scene', () async {
    final level = _registry().byId('billiards');
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

    // The win's shot, on the same scene: wide, then close, then wide.
    final win = <ui.Image>[];
    for (final at in [2.0, 5.0, 6.25, 7.25, 7.75, 8.0, 8.75, 10.5, 12.0]) {
      scene.exitBeat = at;
      win.add(await _still(scene, 390, 844));
    }
    scene.exitBeat = null;
    final winRecorder = ui.PictureRecorder();
    final winCanvas = ui.Canvas(winRecorder);
    for (final (i, image) in win.indexed) {
      winCanvas.drawImage(image, ui.Offset(i * 396.0, 0), ui.Paint());
    }
    final winSheet = await winRecorder.endRecording().toImage(396 * win.length, 844);
    final winPng = await winSheet.toByteData(format: ui.ImageByteFormat.png);
    File('build/stills/billiards-win.png')
        .writeAsBytesSync(winPng!.buffer.asUint8List());

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
