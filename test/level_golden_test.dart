import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

import 'support/recording_canvas.dart';

/// Before/after proof for the level registry. `goldens/levels_before.json` was
/// written by this harness against the two-room code, before the registry
/// existed (`flutter test --dart-define=UPDATE_LEVEL_GOLDEN=true` on this file).
/// It records every canvas call the real scene makes for both rooms, plus the
/// crowd numbers and clear times, so a difference in any mark shows up here.
///
/// Rewritten for the owner's tenth round, which moved people on purpose. Comparing
/// the two files: every clear time, score and tier held, and the bar's twelve
/// guests kept the same crowd numbers. Only canvas calls and the garden's bigger
/// cast moved.
const _goldenPath = 'test/goldens/levels_before.json';

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

Future<GardenSceneGame> _loadScene(LevelRegistry levels) async {
  final scene = GardenSceneGame(firstLevel: () async => levels.first);
  scene.onGameResize(Vector2(390, 844));
  await scene.onLoad();
  return scene;
}

Future<Map<String, Object?>> _fingerprint(
  GardenSceneGame scene,
  LevelDefinition level,
) async {
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

  // Layers are the one thing added since this was recorded, and have their own
  // tests. Leaving them out proves everything else is still where it was.
  final layerDraws = {
    for (final prop in level.layers)
      () {
        final atlas = scene.images.fromCache(prop.atlas);
        return 'drawImageRect image:${atlas.width}x${atlas.height} ';
      }(),
  };
  final samples = <String, Object?>{};
  void sample(String label) {
    final canvas = RecordingCanvas();
    scene.render(canvas);
    canvas.calls.removeWhere((call) => layerDraws.any(call.startsWith));
    samples[label] = {
      'beat': RecordingCanvas.round(session.positionBeats),
      'phase': session.phase.name,
      'tier': session.progress.tier,
      'crowd': [
        for (var i = 0; i < 12; i++)
          () {
            final guest = session.crowd.guest(i, session.positionBeats);
            return '${guest.state.name}/${guest.clip.name}/'
                '${guest.interest.toStringAsFixed(4)}/'
                '${guest.archetypeIndex}/${guest.paletteIndex}';
          }(),
      ],
      'canvas': canvas.calls,
    };
  }

  void advance(double target) {
    while (audio.nowSeconds < target - .000001) {
      audio.nowSeconds = math.min(target, audio.nowSeconds + .02);
      music.pump();
      session.advance();
      scene.update(.02);
    }
  }

  sample('ready');
  session.start();
  for (final beat in [1.0, 2.5, 3.75]) {
    advance(music.secondsAt(beat));
    sample('intro@$beat');
  }
  scene.reducedMotion = true;
  sample('intro-calm');
  scene.reducedMotion = false;

  var cycle = 0;
  while (session.phase != GardenPhase.cleared && cycle < 40) {
    final start = session.chart.introBeats + cycle * session.chart.cycleBeats;
    if (cycle < 2) {
      advance(music.secondsAt(start + 1));
      sample('call$cycle');
    }
    for (var i = 0; i < session.activeLimbs.length; i++) {
      final limb = session.activeLimbs[i];
      final target = start + session.chart.callBeats + session.chart.offsets[i];
      advance(music.secondsAt(target));
      session.tap(limb);
      if (session.phase == GardenPhase.cleared) break;
      scene.dance(limb, targetBeat: target);
      if (cycle == 0 && i.isEven) {
        advance(music.secondsAt(target + .25));
        sample('response$cycle-$i');
      }
    }
    advance(music.secondsAt(start + session.chart.cycleBeats - .05));
    if (cycle == 0) {
      scene.resetEntrance();
      advance(music.secondsAt(start + session.chart.cycleBeats + .9));
      sample('retreat');
    }
    cycle++;
  }
  expect(session.phase, GardenPhase.cleared);
  sample('cleared');
  scene.exitCodaBeat = session.positionBeats;
  scene.warmDown = .5;
  for (final travel in [.1, .25, .6, 1.0]) {
    scene.exitTravel = travel;
    sample('exit@$travel');
  }
  scene.reducedMotion = true;
  scene.exitTravel = .6;
  sample('exit-calm');
  scene.reducedMotion = false;
  scene.onGameResize(Vector2(1080, 1920));
  sample('exit-wide');
  scene.onGameResize(Vector2(390, 844));

  return {
    'clearedAtSeconds': session.completedAtSeconds!.toStringAsFixed(6),
    'clearedAtBeat': session.completedAtBeat!.toStringAsFixed(6),
    'perfects': session.perfects,
    'requiredHits': [
      for (final atPeak in [false, true])
        session.progress.definition.requiredHits(8, atPeak: atPeak),
    ],
    'lastLimbs': [for (final limb in session.activeLimbs) limb.name],
    'samples': samples,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'both shipped rooms draw and score exactly as they did before',
    () async {
      final levels = await LevelRegistry.loadShipping();
      final scene = await _loadScene(levels);
      final actual = {
        // Added levels get their own tests; this proof covers the two original rooms,
        // wherever the campaign order puts them.
        for (final id in ['garden', 'bar'])
          id: await _fingerprint(scene, levels.byId(id)),
      };
      final file = File(_goldenPath);
      if (const bool.fromEnvironment('UPDATE_LEVEL_GOLDEN')) {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(
          '${const JsonEncoder.withIndent(' ').convert(actual)}\n',
        );
      }
      final before =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(jsonDecode(jsonEncode(actual)), before);
    },
  );
}
