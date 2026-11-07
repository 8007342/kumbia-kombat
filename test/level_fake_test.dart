import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_page.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/music/accent_voice.dart';
import 'package:kumbia_kombat/music/game_audio.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';
import 'package:kumbia_kombat/music/transition_conductor.dart';

import 'support/recording_canvas.dart';

/// The whole of a new level: this text, and one line in a campaign index. It
/// borrows the bar's art and score, and differs from the bar in every number
/// so that anything still hard-wired to a room shows up. Not in the shipping
/// list. Its intro is 12 beats, three times the two shipped rooms'.
String _nightBar({
  String id = 'night-bar',
  String title = 'THE NIGHT BAR',
  String exitShot = '',
}) =>
    '''
{
  "id": "$id",
  "title": "$title",
  "background": "bar/bar-interior.png",
  "music": { "score": "bar_swag", "successScore": "bar_swag_success", "leadShape": "square" },
  "rules": { "metric": "Glow", "cleanSeconds": 40, "successesPerTier": 1, "finalChallenges": 1, "resetAfterFailures": 3, "earlyHitRatio": 0.5 },
  "chart": {
    "introBeats": 12, "callBeats": 8, "flourishDestination": "rightHand",
    "offsets": [0, 2, 4, 6],
    "limbs": ["leftFoot", "rightFoot", "leftHand", "rightHand"],
    "variants": [["rightHand", "leftHand", "rightFoot", "leftFoot"]]
  },
  "stage": {
    "calibration": "unverifiedStoryboard",
    "floor": { "horizonY": 0.20, "referenceFootY": 0.42, "referenceHeight": 0.18 },
    "heroHome": [0.40, 0.66], "heroEntrance": [0.30, 0.74], "heroRetreat": [0.35, 0.70],
    "challengers": [
      { "id": "left", "atlas": "gatekeeper", "mark": [0.42, 0.48], "yieldMark": [0.25, 0.48] },
      { "id": "right", "atlas": "bartender", "mark": [0.60, 0.48], "yieldMark": [0.75, 0.48] }
    ]
  },
  "crowd": {
    "budgets": { "interested": 7, "following": 6, "standing": 4, "cheering": 2 },
    "guests": [[0.2, 0.5], [0.8, 0.5], [0.3, 0.4], [0.7, 0.4]],
    "props": [{ "id": "night-table", "kind": "table", "at": [0.5, 0.36], "heightInAdults": 0.43, "widthInAdults": 0.9 }]
  },
  "scenery": { "lamps": [[0.1, 0.1], [0.5, 0.1], [0.9, 0.1]], "plants": [[0.12, 0.45]] },
  "departure": {
    "threshold": "the night bar's far door", "originY": 0.66,
    "waypoints": [
      { "at": 0, "x": 0.40, "y": 0.66, "facing": "sideRight" },
      { "at": 1, "x": 0.80, "y": 0.34, "facing": "rear" }
    ]
  },
  "copy": { "invitation": "Glow or go home.", "clearedTitle": "PURO\\nGLOW" }$exitShot
}
''';

/// Garden and bar come from their real files, unedited: inserting a level only
/// touches the campaign index.
LevelRegistry _extended() {
  const index = '''
{ "campaign": [
  { "level": "garden", "bridgeToNext": "garden_to_bar" },
  { "level": "bar", "bridgeToNext": "bar_to_crowd" },
  { "level": "night-bar", "bridgeToNext": "crowd_to_restroom" },
  { "level": "after-hours" }
] }
''';
  return LevelRegistry.parse(
    index,
    (id) => switch (id) {
      'night-bar' => _nightBar(),
      'after-hours' => _nightBar(id: id, title: 'AFTER HOURS'),
      _ => File('levels/$id.json').readAsStringSync(),
    },
  );
}

MusicScore _score(String id) => MusicScore.fromJson(
  jsonDecode(File('assets/music/scores/$id.json').readAsStringSync())
      as Map<String, dynamic>,
);

class _Audio implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  int silences = 0;
  final attacks = <double>[];
  @override
  void silence() => silences++;
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {
    expect(atSeconds, greaterThanOrEqualTo(nowSeconds - .002));
    attacks.add(atSeconds);
  }
}

void _advance(_Audio audio, double target, void Function() update) {
  while (audio.nowSeconds < target - .000001) {
    audio.nowSeconds = math.min(target, audio.nowSeconds + .02);
    update();
  }
}

/// Perfect taps for any chart: reads only what the session exposes.
void _clear(_Audio audio, GardenSession session) {
  final music = session.transport;
  void update() {
    music.pump();
    session.advance();
  }

  for (
    var cycle = 0;
    cycle < 60 && !session.progress.cleared;
    cycle++
  ) {
    final start = session.chart.introBeats + cycle * session.chart.cycleBeats;
    final played = session.chart.patternFor(session.progress.tier, session.progress.fullTierSuccesses);
    for (var i = 0; i < played.limbs.length; i++) {
      final at = start + session.chart.callBeats + played.offsets[i];
      _advance(audio, music.secondsAt(at), update);
      expect(
        session.tap(played.limbs[i]).note,
        isNotNull,
        reason: '${session.progress.definition.id} cycle $cycle note $i',
      );
    }
    _advance(
      audio,
      music.secondsAt(start + session.chart.cycleBeats - .05),
      update,
    );
  }
  // A late last note's optional move may outlast the phrase. The win holds for it.
  _advance(audio, audio.nowSeconds + 1, update);
  expect(session.phase, GardenPhase.cleared);
}

/// The audio a [GameAudio]-driven page uses, ticking on the test's fake clock.
class _PageAudio implements GameAudio {
  @override
  String leadShape = 'triangle';
  @override
  double nowSeconds = 0;
  @override
  bool ready = false;
  @override
  Future<void> activate() async => ready = true;
  @override
  Future<void> dispose() async {}
  @override
  void silence() {}
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {
    if (isAccentTrack(note.track)) {
      accents.add(note.track);
    }
  }

  final accents = <String>[];
}

String _exitShot({
  required double contact,
  required double closeupTo,
  required String hit,
}) =>
    '''
,
  "exitShot": {
    "plate": "closeups/garden-plate.png",
    "celebrateUntil": 1, "walkFrom": 1, "walkTo": 2,
    "heroStep": [0.5, 0.6],
    "closeupFrom": ${contact - 1}, "contactBeat": $contact, "closeupTo": $closeupTo,
    "contactPoint": [0.5, 0.32],
    "actors": [
      { "approach": "closeups/mc-approach.png", "impact": "closeups/mc-impact.png",
        "contact": [89, 34], "scale": 1.1, "entry": [-130, 90], "recoil": [-5, 3] }
    ],
    "cue": [{ "beat": $contact, "track": "$hit", "pitch": 60, "velocity": 127 }]
  }
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a level made of data alone clears and hands off on the real code', () {
    final levels = _extended();
    expect(levels.levels.map((level) => level.id), [
      'garden',
      'bar',
      'night-bar',
      'after-hours',
    ]);
    final audio = _Audio();
    var music = MusicTransport(
      _score(levels.first.music.score),
      audio,
      loop: true,
      lookaheadSeconds: .3,
    );
    var session = levels.first.newSession(music, audio)..start();
    final clearSeconds = <String, double>{};

    for (final step in levels.campaign) {
      final level = step.level;
      expect(session.progress.definition.id, level.id);
      expect(session.chart, same(level.chart));
      expect(session.crowd.profile, same(level.crowd));

      final startedAt = audio.nowSeconds;
      _clear(audio, session);
      clearSeconds[level.id] = session.completedAtSeconds! - startedAt;

      final conductor = TransitionConductor(audio, lookaheadSeconds: .3);
      final next = step.next;
      if (next == null) {
        final finish = conductor.finish(
          source: music,
          success: _score(level.music.successScore),
        );
        _advance(
          audio,
          finish.success.secondsAt(finish.success.score.lengthBeats) + .1,
          conductor.pump,
        );
        expect(conductor.completed, isTrue);
        continue;
      }
      final silences = audio.silences;
      final handoff = conductor.handoff(
        source: music,
        success: _score(level.music.successScore),
        bridge: _score(step.bridgeToNext!),
        nextScore: _score(next.music.score),
      );
      _advance(audio, handoff.nextAtSeconds, conductor.pump);
      expect(audio.silences, silences, reason: 'Handoffs must not cut sound');
      for (final boundary in [
        handoff.exitAtSeconds,
        handoff.bridgeAtSeconds,
        handoff.nextAtSeconds,
      ]) {
        expect(
          audio.attacks.any((at) => (at - boundary).abs() < .0001),
          isTrue,
        );
      }
      music = handoff.nextTransport;
      session = next.newSession(music, audio)..start(startTransport: false);
    }

    // Unchanged neighbours, and a fake level ruled entirely by its own data.
    expect(clearSeconds['garden'], closeTo(60.667, .001));
    expect(clearSeconds['bar'], closeTo(93.167, .2)); // Joined mid-beat grid.
    final night = levels.byId('night-bar');
    expect(clearSeconds['night-bar'], lessThan(clearSeconds['bar']!));
    expect(night.rules.requiredHits(4, atPeak: false), 2);
    expect(night.rules.requiredHits(4, atPeak: true), 4);
    expect(night.crowd.interested, 7);
    expect(night.stage.challengers.map((c) => c.id), ['left', 'right']);
    expect(night.scenery.waiter, isNull);
    final middle = night.stage.heroFloor(entrance: .5, retreat: 0);
    expect(middle.x, closeTo(.35, 1e-9));
    expect(middle.y, closeTo(.70, 1e-9));
  });

  test('the real scene draws the fake level from its own marks', () async {
    final levels = _extended();
    final scene = GardenSceneGame(firstLevel: () async => levels.first);
    scene.onGameResize(Vector2(390, 844));
    await scene.onLoad();

    final audio = _Audio();
    List<String> drawn(LevelDefinition level) {
      final music = MusicTransport(
        _score(level.music.score),
        audio,
        loop: true,
        lookaheadSeconds: .3,
      );
      scene.session = level.newSession(music, audio);
      final canvas = RecordingCanvas();
      scene.render(canvas);
      return canvas.calls;
    }

    int count(List<String> calls, String name) =>
        calls.where((call) => call.startsWith('$name ')).length;

    final bar = levels.byId('bar');
    final night = levels.byId('night-bar');
    await scene.showLevel(bar);
    final barCalls = drawn(bar);
    await scene.showLevel(night);
    final nightCalls = drawn(night);

    // Same plate, so the path can't be what decided anything.
    expect(night.background, bar.background);
    expect(count(barCalls, 'drawCircle'), bar.scenery.lamps.length);
    expect(count(nightCalls, 'drawCircle'), night.scenery.lamps.length);
    // 4 guests, their chairs, the table and its candle, 1 plant, no waiter,
    // both challengers and the hero.
    expect(count(nightCalls, 'drawOval'), 4 + 2 + 1);
    expect(count(barCalls, 'drawOval'), 12 + 1 + 1 + 1);
    expect(nightCalls, isNot(barCalls));
    expect(nightCalls.length, lessThan(barCalls.length));
  });

  testWidgets('the real page plays a data-only campaign from start to finish', (
    tester,
  ) async {
    const index = '''
{ "campaign": [
  { "level": "night-bar", "bridgeToNext": "bar_to_crowd" },
  { "level": "after-hours" }
] }
''';
    final levels = LevelRegistry.parse(
      index,
      (id) => id == 'night-bar'
          // Contact on the bridge's downbeat, as the shipped rooms have it.
          ? _nightBar(exitShot: _exitShot(contact: 8, closeupTo: 10, hit: 'bump'))
          // The last level has no bridge, so its shot must fit the success score.
          : _nightBar(
              id: id,
              title: 'AFTER HOURS',
              exitShot: _exitShot(contact: 4, closeupTo: 6, hit: 'glug'),
            ),
    );
    final audio = _PageAudio();
    await tester.pumpWidget(
      MaterialApp(
        home: GardenPage(audioFactory: () => audio, levels: () async => levels),
      ),
    );

    Future<void> settle(bool Function() done) async {
      for (var i = 0; i < 200 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(done(), isTrue);
    }

    await settle(
      () =>
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed !=
          null,
    );
    expect(find.text('01  /  THE NIGHT BAR'), findsOneWidget);
    expect(find.text('Glow or go home.'), findsOneWidget);
    expect(find.text('01 / 02'), findsOneWidget);

    // AUTO starts the run from the same gesture, then plays through real input.
    await tester.tap(find.byKey(const ValueKey('autoplay')));
    await tester.pump();
    final game = tester.widget<GameWidget<GardenSceneGame>>(
      find.byType(GameWidget<GardenSceneGame>),
    );
    await settle(() => game.game!.session?.phase != GardenPhase.ready);

    // From the first beat to the end screen, the only words on screen are the
    // two big ones at each room's highlight.
    final words = <String>{};
    bool ended() => find.text('OTRA VUELTA  >').evaluate().isNotEmpty;
    // Two levels of up to about 90 s each, plus one transition.
    for (var frame = 0; frame < 15000 && !ended(); frame++) {
      audio.nowSeconds += .02;
      await tester.pump(const Duration(milliseconds: 20));
      if (!ended()) {
        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          words.add(text.data ?? '');
        }
      }
    }

    final session = game.game!.session!;
    expect(session.progress.definition.id, 'after-hours');
    expect(session.chart, same(levels.byId('after-hours').chart));
    expect(session.crowd.profile, same(levels.byId('after-hours').crowd));
    expect(session.phase, GardenPhase.cleared);
    expect(words, {'PURO', 'GLOW'});
    // The room with a bridge and the last room without one both sound their hit.
    expect(audio.accents, ['bump', 'glug']);
    // The end screen keeps the big words and a way to go again, and that's all.
    expect(find.text('PURO\nGLOW'), findsOneWidget);
    expect(find.text('OTRA VUELTA  >'), findsOneWidget);
    expect(find.text('RESPECT EARNED'), findsNothing);
    expect(find.textContaining('PIZAZZ'), findsNothing);
    expect(audio.leadShape, 'square');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
