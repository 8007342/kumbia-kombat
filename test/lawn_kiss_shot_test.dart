import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/exit_shot.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/music/accent_voice.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

/// The lawn's way out: the two dancers kiss Mācron's cheeks. The kiss lands in the
/// 8 beats of the success score; the close-up then holds into the bridge's 8.
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
  final levels = LevelRegistry.parse(
    File('levels/index.json').readAsStringSync(),
    _read,
  );
  final level = levels.byId('pool-garden');
  final shot = level.exitShot!;
  final macron = shot.actors.first;
  final dancers = shot.actors.sublist(1, 3);

  String imageAt(ExitShotActor actor, double beat) => shot
      .sample(beat, reducedMotion: false)
      .firstWhere((p) => identical(p.actor, actor))
      .image;

  test('every image is a real file, small enough to commit', () {
    for (final image in shot.images.toSet()) {
      final file = File('assets/art/$image');
      expect(file.existsSync(), isTrue, reason: image);
      expect(file.lengthSync(), lessThan(400 * 1024), reason: image);
    }
    expect(shot.actors.length, 6);
  });

  test('the kiss lands in the success score and holds half way into the bridge', () {
    final step = levels.campaign.singleWhere((s) => s.level.id == level.id);
    final length = _score(level.music.successScore).lengthBeats;
    final bridge = _score(step.bridgeToNext!).lengthBeats;
    expect(length, 8);
    // Only the bridge's length counts here. Its tempo can change with the music.
    expect(bridge, 8);
    expect(shot.contactBeat, lessThan(length));
    for (final hit in shot.cue) {
      expect(hit.beat, lessThan(length));
    }
    expect(shot.closeupTo, length + bridge / 2);
    expect(shot.titleUntil, shot.closeupTo);
    // Nothing in the shot names the next room: the campaign's bridge is enough,
    // and routeAt cools the room down over whatever music follows.
    expect(step.next, isNotNull);
    expect(shot.routeAt(shot.closeupTo, length + bridge), 0);
    expect(shot.routeAt(length + bridge, length + bridge), 1);
  });

  test('the long hold keeps time, from the bridge on, and only then', () {
    final start = _score(level.music.successScore).lengthBeats;
    final body = shot.actors[4];
    // Shy until the bridge starts, then his arms swing on each beat.
    final swings = [
      for (var beat = start; beat < shot.closeupTo; beat += 1)
        imageAt(body, beat),
    ];
    expect(imageAt(body, start - .01), contains('body-shy'));
    for (var i = 1; i < swings.length; i++) {
      expect(swings[i], isNot(swings[i - 1]));
    }
    // The pair lean as mirror images, and never before the bridge.
    final a = dancers.first.sway!;
    final b = dancers.last.sway!;
    expect(a.from, start);
    expect(a.at(start), ui.Offset.zero);
    expect(a.at(shot.contactBeat), ui.Offset.zero);
    for (var beat = start; beat < shot.closeupTo; beat += .25) {
      expect(a.at(beat).dx, closeTo(-b.at(beat).dx, 1e-9));
      expect(a.at(beat).dy, closeTo(b.at(beat).dy, 1e-9));
    }
    expect(a.at(start + a.beats / 4), isNot(ui.Offset.zero));
    // The hit eases apart at its own pace, however long the close-up holds.
    final settled = shot.sample(
      shot.contactBeat + shot.recoilBeats!,
      reducedMotion: false,
    );
    final later = shot.sample(start - .01, reducedMotion: false);
    expect(settled[1].offset, later[1].offset);
  });

  test('his whole body shows: head under the kisses, the rest over the hedge', () {
    final body = shot.actors[4];
    final logo = shot.actors[5];
    // The hedge hides where the dancers are cut off, and he stands in front of it.
    expect(shot.actors[3].approach, 'closeups/duet-hedge.png');
    expect(body.approach, contains('duet-macron-body'));
    expect(logo.approach, 'closeups/duet-macron-logo.png');
    // One figure: the three layers line up to the pixel, and none of them moves.
    for (final part in [body, logo]) {
      expect(part.contact, macron.contact);
      expect(part.scale, macron.scale);
      expect(part.entry, ui.Offset.zero);
      expect(part.recoil, ui.Offset.zero);
    }
    // The art is 400 by 440 with his soles at 425. All of it fits the 180-unit
    // view, and his feet stop above the title's band, at 58% of a 390-unit height.
    final left = 180 * shot.contactPoint.dx - macron.contact.dx * macron.scale;
    expect(left, greaterThanOrEqualTo(0));
    expect(left + 400 * macron.scale, lessThanOrEqualTo(180));
    final bottom = 390 * shot.contactPoint.dy + (440 - macron.contact.dy) * macron.scale;
    expect(bottom, lessThan(390 * .58));
  });

  test('both kisses land together, on the contact beat', () {
    final atContact = shot.sample(shot.contactBeat, reducedMotion: false);
    for (final dancer in dancers) {
      final place = atContact.firstWhere((p) => identical(p.actor, dancer));
      expect(place.image, dancer.impact, reason: dancer.impact);
      expect(place.offset, ui.Offset.zero);
    }
    // The same drawings change at the same beats on both sides.
    expect(
      dancers.first.frames.map((f) => f.beat),
      dancers.last.frames.map((f) => f.beat),
    );
    expect(dancers.first.entry.dx, -dancers.last.entry.dx);
    // The contact point is the middle of the picture, so the pair sit either side.
    expect(shot.contactPoint.dx, .5);
  });

  test('his round eyes turn to arcs, and the blush comes after', () {
    expect(imageAt(macron, shot.closeupFrom), contains('round'));
    expect(imageAt(macron, shot.contactBeat), contains('wide'));
    final afterwards = [
      for (var beat = shot.contactBeat; beat < shot.closeupTo; beat += .25)
        imageAt(macron, beat),
    ];
    final arc = afterwards.indexWhere((i) => i.endsWith('-arc.png'));
    final blush = afterwards.indexWhere((i) => i.endsWith('-arc-blush.png'));
    expect(arc, greaterThan(0));
    expect(blush, greaterThan(arc));
    expect(afterwards.last, endsWith('-arc-blush.png'));
    // Every drawing has its turn before the close-up ends.
    expect(macron.frames.last.beat, lessThan(shot.closeupTo));
  });

  test('the drawings differ only in the eyes and blush', () async {
    Future<(int, int, ByteData)> pixels(String image) async {
      final bytes = File('assets/art/$image').readAsBytesSync();
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final art = (await codec.getNextFrame()).image;
      return (
        art.width,
        art.height,
        (await art.toByteData(format: ui.ImageByteFormat.rawRgba))!,
      );
    }

    final (w, h, round) = await pixels('closeups/duet-macron-round.png');
    for (final name in ['wide', 'squash', 'arc', 'arc-blush']) {
      final (w2, h2, other) = await pixels('closeups/duet-macron-$name.png');
      expect((w2, h2), (w, h), reason: name);
      // Nothing outside the face and cheeks moves, so his head can't flicker.
      for (var y = 0; y < h; y += 3) {
        for (var x = 0; x < w; x += 3) {
          // The screen and the cheeks below it.
          if (y >= 95 && y <= 250) continue;
          final at = (y * w + x) * 4;
          expect(
            other.getUint32(at),
            round.getUint32(at),
            reason: '$name at $x,$y',
          );
        }
      }
    }
  });

  test('calm camera holds one clear picture: kiss, arcs and blush', () {
    for (var beat = shot.closeupFrom; beat < shot.closeupTo; beat += .25) {
      final places = shot.sample(beat, reducedMotion: true);
      expect(places.first.image, endsWith('-arc-blush.png'));
      for (final place in places) {
        expect(place.offset, ui.Offset.zero);
      }
      expect(places[1].image, contains('-kiss'));
      expect(places[2].image, contains('-kiss'));
    }
  });

  test('QUÉ FINO lands on the contact, and it is the only text', () {
    expect(level.copy.titleWords, ['QUÉ', 'FINO']);
    expect(shot.titleAt(shot.contactBeat - .01, reducedMotion: false), isNull);
    final hit = shot.titleAt(shot.contactBeat, reducedMotion: false)!;
    expect(hit.scale, greaterThan(1));
    expect(shot.titleUntil - shot.contactBeat, greaterThanOrEqualTo(3));
    expect(shot.titleUntil, shot.closeupTo);
  });

  test('a soft sound lands on the contact, and moves nothing in the music', () {
    final peck = shot.cue.first;
    expect(peck.track, 'peck');
    expect(peck.beat, shot.contactBeat);
    expect(isCueTrack('peck'), isTrue);
    // Softer than the fist bump: this is a tender moment.
    expect(accentPeak('peck', 127), lessThan(accentPeak('bump', 127)));
    final score = _score(level.music.successScore);
    final mixed = shot.mixCue(score, 0);
    expect(mixed.tempos, score.tempos);
    expect(mixed.lengthBeats, score.lengthBeats);
    expect(mixed.notes.length, score.notes.length + shot.cue.length);
    // Still heard over what the score plays on that beat.
    final under = score.notes
        .where((note) => note.beat == peck.beat)
        .fold(0.0, (sum, n) => sum + n.velocity / 127 * .18 * .32 * 1.3);
    expect(accentPeak('peck', peck.velocity), greaterThan(under * 1.5));
  });

  test('no dust flies at a kiss, though a fist bump keeps its own', () {
    expect(shot.motes(shot.contactBeat, reducedMotion: false), isEmpty);
    expect(
      levels.byId('garden').exitShot!.motes(
        levels.byId('garden').exitShot!.contactBeat,
        reducedMotion: false,
      ),
      isNotEmpty,
    );
    expect(shot.heroWaitFrame, 'front_idle');
    expect(levels.byId('garden').exitShot!.heroWaitFrame, 'rear_idle');
  });

  testWidgets('the real scene plays the whole level and then the shot', (
    tester,
  ) async {
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
      final directory = Directory('build/duet-review')
        ..createSync(recursive: true);

      Future<void> save(String name) async {
        final recorder = ui.PictureRecorder();
        scene.render(ui.Canvas(recorder));
        final image = await recorder.endRecording().toImage(390, 844);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${directory.path}/$name.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      }

      void advance(double target) {
        while (audio.nowSeconds < target - 1e-6) {
          audio.nowSeconds = (audio.nowSeconds + .02).clamp(0, target);
          music.pump();
          session.advance();
        }
      }

      final chart = session.chart;
      for (var cycle = 0; cycle < 60 && !session.progress.cleared; cycle++) {
        final start = chart.introBeats + cycle * chart.cycleBeats;
        // Stills and taps, in the order the music reaches them.


        final moments = <(double, int?)>[
          for (final beat in [1.0, 5.0, 8.5, 11.0, 13.0, 15.0]) (beat, null),
          for (var i = 0; i < chart.offsets.length; i++) (chart.callBeats + chart.offsets[i], i),
        ]..sort((x, y) => x.$1.compareTo(y.$1));
        for (final (beat, note) in moments) {
          advance(music.secondsAt(start + beat));
          if (note != null) {
            session.tap(session.activeLimbs[note]);
          } else if (cycle < 6) {
            await save('turn$cycle-beat${beat.toStringAsFixed(1)}');
          } else {
            scene.render(ui.Canvas(ui.PictureRecorder()));
          }
        }
        advance(music.secondsAt(start + chart.cycleBeats - .05));
      }
      expect(session.progress.cleared, isTrue);
      advance(audio.nowSeconds + 1);
      expect(session.phase, GardenPhase.cleared);
      for (var beat = 0.0; beat < 8; beat += .25) {
        scene.exitBeat = beat;
        scene.render(ui.Canvas(ui.PictureRecorder()));
        if (beat == beat.floorToDouble() || beat == 4.5 || beat == 2.75) {
          await save('exit-beat${beat.toStringAsFixed(2)}');
        }
      }
    });
  });
}
