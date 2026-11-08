import 'dart:io';

import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_page.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/music_mixer.dart';
import 'package:kumbia_kombat/gameplay/outfit_palette.dart';
import 'package:kumbia_kombat/gameplay/room_dissolve.dart';
import 'package:kumbia_kombat/music/game_audio.dart';
import 'package:kumbia_kombat/music/accent_voice.dart';
import 'package:kumbia_kombat/music/rendered_music.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

class _Voice implements ClipVoice {
  _Voice(this.clip, this.at, this.offset);
  final RenderedClip clip;
  final double at;
  final double offset;
  double? stoppedAt;
  @override
  void stopAt(double atSeconds, {double fadeSeconds = .01}) =>
      stoppedAt = atSeconds;
}

/// The page's audio with rendered clips, on a clock the test turns by hand.
class _Audio implements GameAudio, MusicFader, RenderedAudio {
  _Audio({this.failDecode = false});
  final bool failDecode;
  @override
  String leadShape = 'triangle';
  @override
  double nowSeconds = 0;
  @override
  bool ready = false;
  final decoded = <String>{};
  final fetched = <String>{};
  final released = <String>[];
  final voices = <_Voice>[];
  final notes = <ScoreNote>[];
  final mixes = <RenderedMix>[];

  @override
  Future<void> activate() async => ready = true;
  @override
  Future<void> dispose() async {}
  @override
  void silence() {}
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) =>
      notes.add(note);
  @override
  void fadeMusicIn({required double atSeconds, required double seconds}) {}
  @override
  bool clipReady(RenderedClip clip) => decoded.contains(clip.id);
  @override
  ClipVoice playClip(
    RenderedClip clip, {
    required double atSeconds,
    required double offsetSeconds,
    double fadeInSeconds = 0,
  }) {
    final voice = _Voice(clip, atSeconds, offsetSeconds);
    voices.add(voice);
    return voice;
  }

  @override
  Future<void> fetchClip(RenderedClip clip) async => fetched.add(clip.id);
  @override
  Future<void> decodeClip(RenderedClip clip) async {
    if (failDecode) throw StateError('bad file');
    decoded.add(clip.id);
  }

  @override
  void releaseClip(RenderedClip clip) {
    released.add(clip.id);
    decoded.remove(clip.id);
  }

  @override
  void setMix(RenderedMix mix) => mixes.add(mix);
  @override
  void clipGainChanged(RenderedClip clip) {}
  @override
  int get decodedBytes => 0;
  @override
  int get compressedBytes => 0;
}

LevelRegistry _campaign() => LevelRegistry.parse(
  File('levels/index.json').readAsStringSync(),
  (id) => File('levels/$id.json').readAsStringSync(),
);

Future<GardenSession> _start(
  WidgetTester tester,
  _Audio audio, {
  String? level,
}) async {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Flame.images.clearCache();
  rootBundle.clear();
  await tester.pumpWidget(
    MaterialApp(
      home: GardenPage(
        audioFactory: () => audio,
        levels: () async => _campaign().reviewing(level),
      ),
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
        find.byType(FilledButton).evaluate().isNotEmpty &&
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed !=
            null,
  );
  await tester.tap(find.text('ENTRA AL RITMO  >'));
  GardenSession session() => tester
      .widget<GameWidget<GardenSceneGame>>(
        find.byType(GameWidget<GardenSceneGame>),
      )
      .game!
      .session!;
  await settle(() => session().phase != GardenPhase.ready);
  for (var i = 0; i < 25; i++) {
    audio.nowSeconds += .02;
    await tester.pump(const Duration(milliseconds: 20));
  }
  return session();
}

Future<void> _end(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The palette caches its shader for good; see pause_overlay_test.dart.
  setUpAll(() async => (await OutfitPalette.load()).dispose());

  testWidgets('the real bar hands to the real party on rendered music', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Flame.images.clearCache();
    rootBundle.clear();
    final audio = _Audio();
    final levels = LevelRegistry.parse(
      '{ "campaign": [ { "level": "bar", "bridgeToNext": "bar_to_crowd" }, { "level": "cool-crowd" } ] }',
      (id) => File('levels/$id.json').readAsStringSync(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GardenPage(audioFactory: () => audio, levels: () async => levels),
      ),
    );
    for (var i = 0; i < 400; i++) {
      final button = find.byType(FilledButton);
      if (button.evaluate().isNotEmpty &&
          tester.widget<FilledButton>(button).onPressed != null) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('autoplay')));
    await tester.pump();
    final game = tester
        .widget<GameWidget<GardenSceneGame>>(
          find.byType(GameWidget<GardenSceneGame>),
        )
        .game!;
    for (var i = 0; i < 300 && game.session?.phase == GardenPhase.ready; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    bool ended() => find.text('OTRA VUELTA  >').evaluate().isNotEmpty;
    var entryChecked = false;
    for (var frame = 0; frame < 24000 && !ended(); frame++) {
      audio.nowSeconds += .02;
      await tester.pump(const Duration(milliseconds: 20));
      // Let the page's own awaits finish whenever a room changes hands.
      if (frame % 50 == 0) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      final session = game.session;
      if (session?.progress.definition.id == 'cool-crowd') entryChecked = true;
    }
    expect(
      ended(),
      isTrue,
      reason:
          '${game.session?.progress.definition.id} ${game.session?.phase} '
          '${game.session?.positionBeats} ${audio.nowSeconds} '
          '${audio.voices.map((v) => v.clip.id).toSet()}',
    );
    expect(entryChecked, isTrue);
    // The room clears before his walk starts. Worked out, not measured here: how
    // many frames the page takes to adopt a room depends on this machine's load.
    final party = levels.byId('cool-crowd');
    final beatSeconds = 60 / audio.voices
        .firstWhere((v) => v.clip.id == 'cool-crowd/low')
        .clip
        .bpm;
    expect(RoomDissolve.seconds, lessThan(party.stage.heroEntersAt * beatSeconds));
    final clips = audio.voices.map((v) => v.clip.id).toList();
    expect(clips, contains('bar/successShort'));
    expect(clips, isNot(contains('bar/success')));
    expect(clips, contains('bar/bridge'));
    expect(clips, contains('cool-crowd/success'));
    final accents = audio.notes.map((n) => n.track).where(isAccentTrack).toList();
    expect(accents, containsAllInOrder(['clink', 'glug', 'nod', 'nod']));
    await _end(tester);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
    'the comedor hands to the real salon over its bridge, and both walk out',
    (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Flame.images.clearCache();
      rootBundle.clear();
      final audio = _Audio();
      final levels = LevelRegistry.parse(
        '{ "campaign": [ { "level": "comedor", "bridgeToNext": "comedor_to_salon" }, { "level": "salon" } ] }',
        (id) => File('levels/$id.json').readAsStringSync(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GardenPage(audioFactory: () => audio, levels: () async => levels),
        ),
      );
      for (var i = 0; i < 400; i++) {
        final button = find.byType(FilledButton);
        if (button.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(button).onPressed != null) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('autoplay')));
      await tester.pump();
      final game = tester
          .widget<GameWidget<GardenSceneGame>>(
            find.byType(GameWidget<GardenSceneGame>),
          )
          .game!;
      for (var i = 0; i < 300 && game.session?.phase == GardenPhase.ready; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      bool ended() => find.text('OTRA VUELTA  >').evaluate().isNotEmpty;
      var reachedSalon = false;
      var sawWalkOut = false;
      var sawComedorWalkOut = false;
      for (var frame = 0; frame < 30000 && !ended(); frame++) {
        audio.nowSeconds += .02;
        await tester.pump(const Duration(milliseconds: 20));
        if (frame % 50 == 0) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        final session = game.session;
        if (session?.progress.definition.id == 'salon') reachedSalon = true;
        final walk = levels.byId('salon').exitShot!.walkOut!;
        final beat = game.exitBeat;
        final comedorWalk = levels.byId('comedor').exitShot!.walkOut!;
        if (!reachedSalon && beat != null && comedorWalk.walkingAt(beat)) {
          sawComedorWalkOut = true;
        }
        if (reachedSalon && beat != null && walk.walkingAt(beat)) {
          sawWalkOut = true;
        }
      }
      expect(
        ended(),
        isTrue,
        reason:
            '${game.session?.progress.definition.id} ${game.session?.phase} '
            '${game.session?.positionBeats} ${audio.nowSeconds}',
      );
      expect(reachedSalon, isTrue);
      expect(sawWalkOut, isTrue, reason: 'the win walks out before the end');
      expect(sawComedorWalkOut, isTrue, reason: 'out through the service door');
      final clips = audio.voices.map((v) => v.clip.id).toList();
      expect(clips, contains('salon/low'));
      expect(clips, contains('salon/success'));
      final accents = audio.notes.map((n) => n.track).where(isAccentTrack).toList();
      expect(
        accents,
        containsAllInOrder(['clink', 'glug', 'glug', 'nod', 'peck', 'peck']),
      );
      expect(find.text('QUÉ\nELEGANCIA'), findsWidgets);
      await _end(tester);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );

  testWidgets('the indoor party plays its own takes, not the synth', (
    tester,
  ) async {
    final audio = _Audio();
    final session = await _start(tester, audio, level: 'cool-crowd');
    expect(session.transport.currentClip?.id, 'cool-crowd/low');
    expect(audio.voices.single.clip.id, 'cool-crowd/low');
    expect(session.transport.currentBpm, closeTo(112, .01));
    expect(audio.notes, isEmpty);
    await _end(tester);
  });

  testWidgets('a run starts on the first take, with no synth song', (
    tester,
  ) async {
    final audio = _Audio();
    final session = await _start(tester, audio);
    expect(session.transport.currentClip?.id, 'garden/low');
    expect(audio.voices.single.clip.id, 'garden/low');
    expect(audio.voices.single.offset, closeTo(.25, .1));
    expect(session.transport.currentBpm, closeTo(92, .01));
    expect(audio.notes, isEmpty);
    expect(audio.mixes, isNotEmpty);
    // The mixer is the owner's alone, and needs its flag.
    expect(find.byType(MusicMixerPanel), findsNothing);
    await _end(tester);
  });

  testWidgets('a decode failure still starts the run, on the synth', (
    tester,
  ) async {
    final audio = _Audio(failDecode: true);
    final session = await _start(tester, audio);
    expect(session.transport.state, TransportState.playing);
    expect(session.transport.currentClip, isNull);
    expect(audio.voices, isEmpty);
    expect(audio.notes, isNotEmpty);
    // Same clock as if the take had played, so the chart's times don't move.
    expect(session.transport.currentBpm, closeTo(92, .01));
    await _end(tester);
  });

  test('copied settings hold levels, not timing', () {
    final clip = RenderedClip(
      id: 't',
      bpm: 100,
      bars: 4,
      beatsPerBar: 4,
      files: const {'opus': 'a.ogg'},
      startSeconds: .25,
      loopEndSeconds: 10,
      gainDb: -2,
    );
    final json = mixerJson(const RenderedMix(musicDb: -3), {
      'lawn': RenderedLevel(
        id: 'lawn',
        tierTakes: const ['a', 'a', 'a', 'a', 'a'],
        takes: {'a': clip},
      ),
    });
    expect(json, contains('"musicDb": -3.0'));
    expect(json, contains('"gainDb": -2.0'));
    expect(json, isNot(contains('bpm')));
    expect(json, isNot(contains('loop')));
    expect(musicMixerRequested, isFalse);
  });
}
