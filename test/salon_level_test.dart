import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/exit_shot.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/gesture_shapes.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_autoplay.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/thumb_layout.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

/// El Salón de Espejos, on real game code and its real level file:
/// `plan/levels/salon-2026-11-07.md` for the design and
/// `plan/levels/salon-wiring-2026-11-07.md` for what is wired and checked.
String _read(String id) => File('levels/$id.json').readAsStringSync();

LevelRegistry _registry() =>
    LevelRegistry.parse(File('levels/index.json').readAsStringSync(), _read);

Map<String, dynamic> _json() =>
    jsonDecode(_read('salon')) as Map<String, dynamic>;

Matcher _refused(String text) => throwsA(
  isA<LevelDataError>().having((e) => e.toString(), 'error', contains(text)),
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

MusicScore _score(String id) => MusicScore.fromJson(
  jsonDecode(File('assets/music/scores/$id.json').readAsStringSync())
      as Map<String, dynamic>,
);

Map<String, dynamic> _atlases() =>
    (jsonDecode(File('assets/art/ensemble/manifest.json').readAsStringSync())
            as Map<String, dynamic>)['atlases']
        as Map<String, dynamic>;

Set<String> _frames(String atlas) =>
    ((_atlases()[atlas] as Map)['frames'] as Map).keys.cast<String>().toSet();

/// The tempos its tiers play: BOLERO's ladder, 108, 116 and 124 BPM.
const _tierBpm = [108.0, 108.0, 116.0, 116.0, 124.0];

/// The win's beats, as long as the success score that plays them: a last level's
/// shot must fit it, because the beat clock stops with the music.
const _successBeats = 16.0;

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

Future<void> _sheet(List<ui.Image> images, String path) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (final (i, image) in images.indexed) {
    canvas.drawImage(image, ui.Offset(i * 396.0, 0), ui.Paint());
  }
  final sheet = await recorder.endRecording().toImage(
    396 * images.length,
    844,
  );
  final png = await sheet.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the last level, after billiards, with Charm and its title', () {
    final registry = _registry();
    final campaign = registry.campaign;
    expect(campaign.last.level.id, 'salon');
    final billiards = campaign[campaign.length - 2];
    expect(billiards.level.id, 'billiards');
    expect(billiards.next, same(campaign.last.level));
    final salon = campaign.last.level;
    expect(salon.title, 'EL SALÓN DE ESPEJOS');
    expect(salon.rules.metric, 'Charm');
    expect(salon.copy.clearedShout, 'QUÉ ELEGANCIA');
    expect(salon.hardestCombo!.name, 'EL GIRO DE TERCIOPELO');
  });

  group('the chart, a cha-cha', () {
    final chart = _registry().byId('salon').chart;

    test('fair at every tier, by the guaranteed window', () {
      for (var tier = 0; tier < 5; tier++) {
        for (var peak = 0; peak < (tier == 4 ? 3 : 1); peak++) {
          final index = chart.patternIndex(tier, peak);
          expect(
            chart.fairnessProblems(index, _tierBpm[tier]),
            isEmpty,
            reason: 'tier $tier',
          );
        }
      }
    });

    test('every rich pattern dances triples: a split, then the first side', () {
      for (var i = 1; i <= chart.variants.length; i++) {
        final steps = chart.richPatterns[i]!;
        final splits = steps.where((s) => s.move == RichMove.split).toList();
        expect(splits, hasLength(2), reason: '$i');
        for (final split in splits) {
          expect(split.gap, .5, reason: '$i: the and of the cha-cha-chá');
          final chaIndex = steps.indexOf(split) + 1;
          final cha = steps[chaIndex];
          expect(cha.at, split.at + 1, reason: '$i');
          expect(cha.move, isNull, reason: '$i');
          expect(limbIsLeft(cha.limb), limbIsLeft(split.limb), reason: '$i');
        }
      }
    });

    test('the same limb never comes back inside a beat and a half', () {
      for (var i = 0; i <= chart.variants.length; i++) {
        final played = chart.pattern(i);
        for (var a = 0; a < played.limbs.length; a++) {
          for (var b = a + 1; b < played.limbs.length; b++) {
            if (played.limbs[a] != played.limbs[b]) continue;
            expect(
              played.offsets[b] - played.offsets[a],
              greaterThanOrEqualTo(1.5),
              reason: 'pattern $i',
            );
          }
        }
      }
    });

    test('richer at each tier, ending each phrase with an invitation to spin', () {
      var previous = -1;
      for (var tier = 0; tier < 5; tier++) {
        final played = chart.pattern(chart.patternIndex(tier, 0));
        expect(
          played.richSteps,
          greaterThanOrEqualTo(previous),
          reason: 'tier $tier',
        );
        previous = played.richSteps;
      }
      expect(previous, greaterThan(chart.pattern(1).richSteps));
      for (var i = 0; i <= chart.variants.length; i++) {
        expect(chart.pattern(i).offers.last, GestureKind.spin, reason: '$i');
      }
    });

    test('a flawless autoplay run clears it', () {
      final level = _registry().byId('salon');
      final audio = _Audio();
      final music = MusicTransport(
        _score(level.music.score),
        audio,
        loop: true,
        lookaheadSeconds: .3,
      );
      final session = level.newSession(music, audio)..start();
      final demo = PartyAutoplay(flawless: true)..enabled = true;
      while (session.phase != GardenPhase.cleared && audio.nowSeconds < 600) {
        audio.nowSeconds += .02;
        music.pump();
        session.advance();
        demo.pump(session);
      }
      expect(session.phase, GardenPhase.cleared);
    });
  });

  group('the win', () {
    final level = _registry().byId('salon');
    final shot = level.exitShot!;

    test('every drawing ships, in the atlases that draw it', () {
      for (final image in shot.images) {
        expect(File('assets/art/$image').existsSync(), isTrue, reason: image);
      }
      final his = _frames(level.stage.challengers.single.atlas);
      for (final clip in shot.opponent) {
        expect(his, containsAll(clip.frames.toSet()));
      }
      final applause = shot.applause!;
      for (final guest in level.layout.guests) {
        final atlas = guest.atlas ?? 'guest${guest.archetype}';
        expect(
          _frames(atlas),
          containsAll(applause.frames.toSet()),
          reason: atlas,
        );
      }
    });

    test('he bows toward Mācron, who stands on his picture-right', () {
      // His bow is drawn facing left; the atlas mirrors it, so it faces right.
      final frames =
          (_atlases()['terciopelo'] as Map)['frames'] as Map<String, dynamic>;
      final bow = shot.opponent.firstWhere((c) => c.frames.contains('bow_a'));
      for (final frame in bow.frames.toSet()) {
        expect((frames[frame] as Map)['mirror'], isTrue, reason: frame);
      }
      expect(
        shot.heroStep.dx,
        greaterThan(level.stage.challengers.single.meetMark!.x),
      );
    });

    test('the story runs in order: bow, close-up, flare and applause, the walk out', () {
      final bow = shot.opponent.firstWhere((c) => c.from > 0);
      expect(bow.from + bow.lengthBeats, lessThanOrEqualTo(shot.closeupFrom));
      expect(shot.keepsake!.from, greaterThan(shot.contactBeat));
      expect(shot.keepsake!.from, lessThan(shot.closeupTo));
      expect(shot.flare!.from, shot.closeupTo);
      expect(shot.applause!.from, greaterThanOrEqualTo(shot.closeupTo));
      final sweep = shot.opponent.firstWhere((c) => c.from > shot.closeupTo);
      expect(sweep.from, lessThanOrEqualTo(shot.walkOut!.from));
      expect(shot.walkOut!.from, greaterThanOrEqualTo(shot.closeupTo));
    });

    test('the shot, the title and the walk all fit the success score', () {
      expect(shot.closeupTo, lessThanOrEqualTo(_successBeats));
      expect(shot.titleUntil, lessThanOrEqualTo(_successBeats));
      expect(shot.walkOut!.to, lessThanOrEqualTo(_successBeats));
      for (final hit in shot.cue) {
        expect(hit.beat, lessThan(_successBeats - .25));
      }
    });

    test('he is through the doors by the end, and fades only at them', () {
      final walk = shot.walkOut!;
      expect(walk.opacityAt(walk.from, reducedMotion: false), 1);
      expect(walk.opacityAt(walk.to - walk.fadeBeats, reducedMotion: false), 1);
      expect(walk.opacityAt(walk.to, reducedMotion: false), 0);
      expect(walk.opacityAt(walk.to - .01, reducedMotion: true), 1);
      expect(walk.opacityAt(walk.to, reducedMotion: true), 0);
      final door = level.heroExitFloor(level.route.sample(1));
      expect(door.y, lessThan(level.stage.challengers.single.mark.y));
    });

    test('the lamps swell once and settle, with no jump at either end', () {
      final flare = shot.flare!;
      expect(flare.at(flare.from), 0);
      expect(flare.at(flare.from + flare.rise), closeTo(flare.gain, 1e-9));
      expect(flare.at(flare.from + flare.beats), 0);
      expect(flare.at(flare.from + .01), lessThan(.01));
      expect(flare.at(flare.from + flare.beats - .01), lessThan(.01));
    });

    test('the rose changes hands on the downbeat, with a soft sound', () {
      expect(shot.contactBeat % 1, 0);
      final at = shot.cue.where((c) => c.beat == shot.contactBeat);
      expect(at, isNotEmpty);
      expect(shot.throwsDust, isFalse);
    });
  });

  group('the loader refuses', () {
    LevelDefinition edited(void Function(Map<String, dynamic> shot) edit) {
      final json = _json();
      edit(json['exitShot'] as Map<String, dynamic>);
      return LevelDefinition.fromJson(json);
    }

    test('a walk out that starts inside the close-up', () {
      expect(
        () => edited((s) => (s['walkOut'] as Map)['from'] = s['closeupFrom']),
        _refused('walkOut'),
      );
    });

    test('a flare inside the close-up', () {
      expect(
        () => edited((s) => (s['flare'] as Map)['from'] = s['contactBeat']),
        _refused('wide shot'),
      );
    });

    test('opponent clips out of order', () {
      expect(
        () => edited((s) => (s['opponent'] as List).last['from'] = 0),
        _refused('must start after'),
      );
    });

    test('a keepsake that arrives after the close-up', () {
      expect(
        () => edited((s) => (s['keepsake'] as Map)['from'] = 20),
        _refused('keepsake'),
      );
    });

    test('a misspelt field', () {
      expect(
        () => edited((s) => (s['walkOut'] as Map)['fade'] = 1),
        _refused('fade'),
      );
    });
  });

  test('a clip holds its last drawing, or loops, and reduced motion holds', () {
    const once = ExitShotClip(from: 2, frames: ['a', 'b', 'c'], beatsPerFrame: 1);
    expect(once.frameAt(2.5, reducedMotion: false), 'a');
    expect(once.frameAt(3, reducedMotion: false), 'b');
    expect(once.frameAt(9, reducedMotion: false), 'c');
    expect(once.frameAt(2, reducedMotion: true), 'c');
    const loop = ExitShotClip(
      from: 0,
      frames: ['a', 'b'],
      beatsPerFrame: .5,
      loop: true,
    );
    expect(loop.frameAt(1.25, reducedMotion: false), 'a');
    expect(loop.frameAt(1.75, reducedMotion: false), 'b');
  });

  test('stills of the room and its win through the real scene', () async {
    final level = _registry().byId('salon');
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
    final demo = PartyAutoplay(flawless: true)..enabled = true;
    void advance(double target) {
      while (audio.nowSeconds < target - 1e-6 &&
          session.phase != GardenPhase.cleared) {
        audio.nowSeconds = math.min(target, audio.nowSeconds + .02);
        music.pump();
        session.advance();
        demo.pump(session);
        scene.update(.02);
      }
    }

    await _still(scene, 390, 844);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final chart = level.chart;
    final opening = <ui.Image>[];
    Future<void> at(double beat) async {
      advance(music.secondsAt(beat));
      opening.add(await _still(scene, 390, 844));
    }

    await at(3);
    await at(chart.introBeats + 2);
    await at(chart.introBeats + chart.callBeats + 2.25);
    await _sheet(opening, 'build/stills/salon-opening.png');

    // A real win, then the shot's beats on the same scene.
    advance(600);
    expect(session.phase, GardenPhase.cleared);
    final win = <ui.Image>[];
    for (final beat in [1.0, 3.0, 5.0, 6.25, 8.0, 10.25, 11.75, 13.5, 15.0]) {
      scene.exitBeat = beat;
      win.add(await _still(scene, 390, 844));
    }
    await _sheet(win, 'build/stills/salon-win.png');
  });
}
