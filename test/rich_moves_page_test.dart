import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/cue_path.dart';
import 'package:kumbia_kombat/gameplay/garden_page.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/outfit_palette.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/music/game_audio.dart';
import 'package:kumbia_kombat/music/score.dart';

/// The test font is too wide for the header on a phone, so use the widest stage.
const _width = 500.0;
const _height = 900.0;

/// A page's audio on a clock the test turns by hand. It records every volume
/// change and every attack, and is the only place the fade can reach.
class _Audio implements GameAudio, MusicFader {
  @override
  String leadShape = 'triangle';
  @override
  double nowSeconds = 0;
  @override
  bool ready = false;
  int activations = 0;
  bool refuse = false;
  @override
  Future<void> activate() async {
    activations++;
    if (refuse) throw StateError('no sound');
    ready = true;
  }

  @override
  Future<void> dispose() async {}
  @override
  void silence() {}
  final attacks = <double>[];
  final tracks = <String>[];
  int countInTicks = 0;
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {
    attacks.add(atSeconds);
    tracks.add(note.track);
    if (note.track == 'pulse' && note.pitch == 76 && note.velocity == 45) {
      countInTicks++;
    }
  }

  final fades = <({double at, double seconds})>[];
  @override
  void fadeMusicIn({required double atSeconds, required double seconds}) =>
      fades.add((at: atSeconds, seconds: seconds));
}


/// The real page, on a campaign whose opening phrase holds all three moves.
LevelRegistry _campaign({bool clack = false}) => LevelRegistry.parse(
  File('levels/index.json').readAsStringSync(),
  (id) {
    final text = File('levels/$id.json').readAsStringSync();
    if (id != 'garden') return text;
    final data = jsonDecode(text) as Map<String, dynamic>;
    if (clack) {
      (data['music'] as Map<String, dynamic>)['moveAccent'] = {
        'track': 'clack',
        'pitch': 60,
        'velocity': 110,
      };
    }
    (data['chart'] as Map<String, dynamic>)['rich'] = {
      'limits': {
        'pairToleranceMs': 80,
        'sameSpotMs': 285,
        'thumbHopMs': 330,
        'crossThumbMs': 170,
        'sameLimbMs': 400,
        'phraseEndMs': 100,
      },
      'patterns': {
        '0': [
          {'at': 0, 'limb': 'leftHand', 'move': 'pair', 'with': 'rightHand'},
          {'at': 1, 'limb': 'leftFoot', 'move': 'doubleTap', 'gap': .75},
          {'at': 3, 'limb': 'leftHand', 'move': 'split', 'with': 'rightHand', 'gap': .5},
          {'at': 4, 'limb': 'rightFoot'},
          {'at': 5, 'limb': 'leftFoot'},
          {'at': 5.5, 'limb': 'rightHand'},
          {'at': 6, 'limb': 'leftHand'},
          {'at': 7, 'limb': 'rightFoot'},
        ],
      },
    };
    return jsonEncode(data);
  },
);

class _Run {
  _Run(this.tester, this.audio);
  final WidgetTester tester;
  final _Audio audio;

  GardenSceneGame get scene => tester
      .widget<GameWidget<GardenSceneGame>>(
        find.byType(GameWidget<GardenSceneGame>),
      )
      .game!;
  GardenSession get session => scene.session!;

  Future<void> settle(bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(done(), isTrue);
  }

  /// Turns the audio clock, and lets the page's own timers and frames run.
  Future<void> play(double seconds) async {
    for (var left = seconds; left > 1e-9; left -= .02) {
      audio.nowSeconds += .02;
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Plays to [offset] beats into the first response.
  Future<void> untilOffset(double offset) async {
    final chart = session.chart;
    final at = session.transport.secondsAt(
      chart.introBeats + chart.callBeats + offset,
    );
    await play(math.max(0, at - audio.nowSeconds));
  }

}

Future<_Run> _startRun(
  WidgetTester tester, {
  bool calm = false,
  LevelRegistry? levels,
}) async {
  tester.view.physicalSize = const Size(_width, _height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // These caches are global, and their futures belong to the last test's zone.
  Flame.images.clearCache();
  rootBundle.clear();
  final audio = _Audio();
  await tester.pumpWidget(
    MaterialApp(
      home: GardenPage(
        audioFactory: () => audio,
        levels: () async => levels ?? _campaign(),
      ),
    ),
  );
  final run = _Run(tester, audio);
  await run.settle(
    () =>
        find.byType(FilledButton).evaluate().isNotEmpty &&
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed !=
            null,
  );
  if (calm) {
    await tester.tap(find.textContaining('CALM CAMERA'));
    await tester.pump();
  }
  await tester.tap(find.text('ENTRA AL RITMO  >'));
  await run.settle(() => run.session.phase != GardenPhase.ready);
  await run.play(.5);
  return run;
}

Future<void> _end(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  // The palette prepares its wardrobes in the background: let that finish.
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => (await OutfitPalette.load()).dispose());

  testWidgets('Q, W, A and S play every richer move', (tester) async {
    final run = await _startRun(tester);
    await run.untilOffset(0);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    expect(run.session.richStepsCompleted, 1);
    expect(run.scene.actionPartner, Limb.leftHand);

    await run.untilOffset(1);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(run.session.richStepsCompleted, 1);
    await run.untilOffset(1.75);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(run.session.richStepsCompleted, 2);
    expect(run.scene.actionPartner, isNull);

    await run.untilOffset(3);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await run.untilOffset(3.5);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    expect(run.session.richStepsCompleted, 3);
    expect(run.session.pizazz, 3 * richStepPizazz);
    await _end(tester);
  });

  testWidgets('a room with a reward sound plays it when a richer step lands', (
    tester,
  ) async {
    final run = await _startRun(tester, levels: _campaign(clack: true));
    await run.untilOffset(0);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    expect(run.audio.tracks, isNot(contains('clack')));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    expect(run.session.richStepsCompleted, 1);
    expect(run.audio.tracks.where((t) => t == 'clack'), hasLength(1));
    await _end(tester);
  });

  testWidgets('two thumbs down at once both land, near their own rings', (
    tester,
  ) async {
    final run = await _startRun(tester);
    await run.untilOffset(-.5);
    await tester.pump();
    // Both cues of the pair are up, tied, and the page draws them without trouble.
    final pair = run.session.visibleCues
        .where((c) => !c.demo && c.step == 0)
        .toList();
    expect(pair, hasLength(2));
    expect(pair.map((c) => c.move), everyElement(RichMove.pair));
    await run.untilOffset(0);
    final at = [
      for (final cue in pair)
        cuePath(
          limb: cue.limb,
          beat: cue.beat,
          id: cue.id,
          width: _width,
          height: _height,
        ).landing,
    ];
    final left = await tester.startGesture(Offset(at[0].x, at[0].y));
    final right = await tester.startGesture(Offset(at[1].x, at[1].y));
    await tester.pump();
    expect(run.session.richStepsCompleted, 1);
    expect(run.session.combo, 2);
    await left.up();
    await right.up();
    await tester.pump();
    await _end(tester);
  });

  testWidgets('one thumb on a pair still lands the step, and costs nothing', (
    tester,
  ) async {
    final run = await _startRun(tester);
    await run.untilOffset(0);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await run.untilOffset(.5);
    await tester.pump();
    expect(run.session.combo, 1);
    expect(run.session.richStepsCompleted, 0);
    await _end(tester);
  });
}
