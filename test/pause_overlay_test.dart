import 'dart:convert';
import 'dart:io';

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
import 'package:kumbia_kombat/gameplay/pause_overlay.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/tap_resolution.dart';
import 'package:kumbia_kombat/music/game_audio.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

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
  int countInTicks = 0;
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {
    attacks.add(atSeconds);
    if (note.track == 'pulse' && note.pitch == 76 && note.velocity == 45) {
      countInTicks++;
    }
  }

  final fades = <({double at, double seconds})>[];
  @override
  void fadeMusicIn({required double atSeconds, required double seconds}) =>
      fades.add((at: atSeconds, seconds: seconds));
}

LevelRegistry _campaign() => LevelRegistry.parse(
  File('levels/index.json').readAsStringSync(),
  (id) => File('levels/$id.json').readAsStringSync(),
);

MusicScore _score(String id) => MusicScore.fromJson(
  jsonDecode(File('assets/music/scores/$id.json').readAsStringSync())
      as Map<String, dynamic>,
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

  Finder get overlay => find.byType(VcrPauseOverlay);
  VcrPauseOverlay get veil => tester.widget(overlay);

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

  Future<void> pauseButton() async {
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
  }

  /// Taps the frame away from the icon, and waits for the resume to be accepted.
  Future<void> tapFrame() async {
    await tester.tapAt(const Offset(30, 200));
    await settle(() => session.phase != GardenPhase.paused);
    await tester.pump();
  }

  /// Plays until a response note is near its time, and returns it.
  Future<GardenCue> untilNoteOpen() async {
    for (var i = 0; i < 2000; i++) {
      await play(.02);
      for (final cue in session.visibleCues.where((c) => !c.demo)) {
        final at = session.transport.secondsAt(cue.beat);
        if ((at - audio.nowSeconds).abs() < .03) return cue;
      }
    }
    fail('No note came up');
  }
}

Future<_Run> _startRun(WidgetTester tester, {bool calm = false}) async {
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
        levels: () async => _campaign(),
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

  // The palette caches its shader for good. Loaded here, that future belongs to
  // no test's fake clock, so every page below can await it.
  setUpAll(() async => (await OutfitPalette.load()).dispose());

  group('the fade', () {
    test('runs from whole to gone, smoothly, inside the count-in', () {
      final fade = ResumeFade()
        ..begin(now: 10, anchor: 12, reducedMotion: false);
      expect(fade.opacityAt(10), 1);
      expect(fade.endsAt, 10 + resumeFadeSeconds);
      expect(fade.opacityAt(fade.endsAt), 0);
      var last = 1.0;
      for (var i = 1; i <= 120; i++) {
        final now = fade.opacityAt(10 + i / 100);
        expect(now, lessThanOrEqualTo(last));
        expect(last - now, lessThan(.03));
        last = now;
      }
    });

    test('a short count-in cuts it short, so it never outlasts the lead', () {
      final fade = ResumeFade()
        ..begin(now: 10, anchor: 10.4, reducedMotion: false);
      expect(fade.endsAt, closeTo(10.4, 1e-9));
      final none = ResumeFade()
        ..begin(now: 10, anchor: 10, reducedMotion: false);
      expect(none.opacityAt(10), 0);
    });

    test('calm is shorter, and nothing is guarded before the first resume', () {
      expect(resumeFadeSecondsCalm, lessThan(resumeFadeSeconds / 2));
      expect(musicFadeSecondsCalm, lessThan(musicFadeSeconds / 2));
      final fade = ResumeFade();
      expect(fade.opacityAt(0), 0);
      expect(fade.guardsPauseAt(0), isFalse);
      fade.begin(now: 10, anchor: 12, reducedMotion: true);
      expect(fade.endsAt, 10 + resumeFadeSecondsCalm);
      expect(fade.guardsPauseAt(10.1), isTrue);
      expect(fade.guardsPauseAt(10 + resumeDoubleTapGuardSeconds), isFalse);
    });
  });

  group('the noise', () {
    test('is slow and faint enough to be no flash risk', () {
      // WCAG 2.3.1: at most three flashes a second, and a flash needs a swing of
      // at least 10% of full luminance. This clears both on its own.
      expect(vcrNoiseStepsPerSecond, lessThan(3));
      expect(vcrNoisePeakOpacity, lessThan(.1));
      expect(vcrBandFillOpacity, lessThan(.1));
      expect(vcrBandDriftPerSecond, lessThan(.05));
      // Two wide bands can overlap: a streak over both still isn't a flash.
      expect(1 - (1 - vcrNoisePeakOpacity) * (1 - vcrNoisePeakOpacity), lessThan(.1));
      final steps = <int>{
        for (var i = 0; i < 1000; i++)
          vcrNoiseAt(i / 100, reducedMotion: false).step,
      };
      expect(steps.length, lessThanOrEqualTo(10 * vcrNoiseStepsPerSecond + 1));
    });

    test('the moving band is wide, and comes round again unbroken', () {
      final bands = vcrNoiseAt(0, reducedMotion: false).bands;
      expect(bands.first.height, greaterThanOrEqualTo(.4));
      expect(bands.first.height, greaterThan(bands.last.height * 10));
      // A band's top wraps, so no moment can leave it stuck off the screen.
      for (var i = 0; i < 400; i++) {
        final band = vcrNoiseAt(i * 2.0, reducedMotion: false).bands.first;
        expect(band.top, inInclusiveRange(0, 1));
      }
    });

    test('the same moment always draws the same frame', () {
      final a = vcrNoiseAt(3.7, reducedMotion: false);
      final b = vcrNoiseAt(3.7, reducedMotion: false);
      expect(a.step, b.step);
      expect(a.jitter, b.jitter);
      expect(a.bands.first.top, b.bands.first.top);
    });

    test('jitters only slightly, and reduced motion holds perfectly still', () {
      expect(vcrJitterPixels, lessThanOrEqualTo(2));
      final jitters = {
        for (var i = 0; i < 100; i++)
          vcrNoiseAt(i / 10, reducedMotion: false).jitter,
      };
      expect(jitters.length, greaterThan(1));
      final first = vcrNoiseAt(0, reducedMotion: true);
      for (var i = 0; i < 100; i++) {
        final still = vcrNoiseAt(i / 3, reducedMotion: true);
        expect(still.jitter, 0);
        expect(still.step, first.step);
        for (var band = 0; band < still.bands.length; band++) {
          expect(still.bands[band].top, first.bands[band].top);
        }
      }
    });
  });

  group('resume keeps the music', () {
    test('every room: the fade is over long before a scored note can come', () {
      for (final step in _campaign().campaign) {
        final level = step.level;
        final score = _score(level.music.score);
        final fastest = score.tempos.reduce((a, b) => a > b ? a : b);
        final beat = 60 / fastest;
        final bar = score.beatsPerBar * beat;
        // The count-in always has time for the picture's fade.
        expect(resumeFadeSeconds, lessThanOrEqualTo(bar), reason: level.id);
        // A resume replays from a call, so the first judged note is a whole call
        // after the music restarts, less its early window.
        final firstWindow =
            level.chart.callBeats * beat - RhythmJudge.earlyWindowMs / 1000;
        expect(musicFadeSeconds, lessThan(firstWindow), reason: level.id);
      }
    });
  });

  group('on the real page', () {
    testWidgets('pause shows the frame and the bars, and no words', (
      tester,
    ) async {
      final run = await _startRun(tester);
      await run.pauseButton();

      expect(run.overlay, findsOneWidget);
      expect(run.veil.showPlay, isFalse);
      expect(run.veil.opacity, 1);
      expect(
        find.descendant(of: run.overlay, matching: find.byType(Text)),
        findsNothing,
      );
      for (final gone in [
        'TAKE A BREATH',
        'STILL\nGROOVIN’.',
        'Your groove will wait for you.',
        'SEGUIMOS  >',
        'K / K',
        'KUMBIA KOLISEUM',
      ]) {
        expect(find.text(gone), findsNothing);
      }
      expect(find.byType(FilledButton), findsNothing);
      // The game stays there under it, and AutoPlay stays reachable above it.
      expect(find.byType(GameWidget<GardenSceneGame>), findsOneWidget);
      expect(find.byKey(const ValueKey('autoplay')), findsOneWidget);

      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(find.bySemanticsLabel('Paused. Tap to resume.'), findsOneWidget);
      semantics.dispose();
      await _end(tester);
    });

    testWidgets('AutoPlay can be toggled without resuming', (tester) async {
      final run = await _startRun(tester);
      await run.pauseButton();
      await tester.tap(find.byKey(const ValueKey('autoplay')));
      await tester.pump();
      expect(run.session.phase, GardenPhase.paused);
      expect(find.byTooltip('AutoPlay on, with mistakes. Tap to watch it flawless.'), findsOneWidget);
      await _end(tester);
    });

    testWidgets('AutoPlay goes round three states, and flawless is gold', (
      tester,
    ) async {
      final run = await _startRun(tester);
      final button = find.byKey(const ValueKey('autoplay'));
      Icon robot() => tester.widget<Icon>(
        find.descendant(of: button, matching: find.byType(Icon)).first,
      );
      final off = robot().color;
      expect(find.byTooltip('AutoPlay off. Tap to watch it with mistakes.'), findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      expect(find.byTooltip('AutoPlay on, with mistakes. Tap to watch it flawless.'), findsOneWidget);
      expect(robot().color, isNot(off));
      await tester.tap(button);
      await tester.pump();
      expect(find.byTooltip('AutoPlay flawless. Tap to turn it off.'), findsOneWidget);
      expect(robot().color, const Color(0xFFFFC35F));
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      expect(find.byTooltip('AutoPlay off. Tap to watch it with mistakes.'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(run.session.phase, isNot(GardenPhase.paused));
      await _end(tester);
    });

    testWidgets('a tap anywhere turns it to play, then it fades into the beat', (
      tester,
    ) async {
      final run = await _startRun(tester);
      await run.pauseButton();
      final frozen = run.session.transport.positionBeats;
      run.audio.attacks.clear();

      await run.tapFrame();
      expect(run.veil.showPlay, isTrue);
      expect(run.veil.onResume, isNull);
      expect(run.veil.opacity, closeTo(1, .01));

      final transport = run.session.transport;
      expect(transport.countingIn, isTrue);
      expect(transport.positionBeats, frozen);
      final anchor = transport.secondsAt(frozen);
      final bar =
          transport.score.beatsPerBar *
          60 /
          transport.score.tempos[transport.currentTier];
      expect(anchor - run.audio.nowSeconds, closeTo(bar, 1e-9));
      // One bar's ticks, and the swell begins exactly where the music does.
      expect(run.audio.countInTicks, 4);
      final fade = run.audio.fades.single;
      expect(fade.at, anchor);
      expect(fade.seconds, musicFadeSeconds);

      // The picture clears before the count-in does, so input opens unveiled.
      await run.play(resumeFadeSeconds * .5);
      expect(run.veil.opacity, inExclusiveRange(.2, .8));
      await run.play(resumeFadeSeconds * .5 + .04);
      expect(run.overlay, findsNothing);
      expect(transport.countingIn, isTrue);
      expect(run.session.visibleCues, isEmpty);

      // The song runs from the frozen beat, at its tempo, right on the anchor.
      await run.play(anchor + 1 - run.audio.nowSeconds);
      expect(
        transport.positionBeats,
        closeTo(
          frozen + transport.score.tempos[transport.currentTier] / 60,
          .05,
        ),
      );
      expect(transport.secondsAt(frozen), anchor);
      expect(run.session.running, isTrue);
      // Only the bar's own ticks come before the anchor. The song waits for it.
      expect(run.audio.attacks.where((a) => a < anchor), hasLength(4));
      expect(run.audio.attacks.where((a) => a >= anchor), isNotEmpty);
      await _end(tester);
    });

    testWidgets('a double tap resumes once, and doesn\'t pause again', (
      tester,
    ) async {
      final run = await _startRun(tester);
      await run.pauseButton();
      run.audio.countInTicks = 0;
      final before = run.audio.activations;

      await tester.tapAt(const Offset(30, 200));
      await tester.tapAt(const Offset(30, 200));
      await run.settle(() => run.session.phase != GardenPhase.paused);
      await tester.pump();
      await tester.tapAt(const Offset(30, 200));
      await tester.pump();
      expect(run.audio.fades, hasLength(1));
      expect(run.audio.countInTicks, 4);
      expect(run.audio.activations, before + 1);
      expect(run.session.running, isTrue);

      // The bounce can land on the pause button too. That's still the same thumb.
      await run.pauseButton();
      expect(run.session.running, isTrue);
      await _end(tester);
    });

    testWidgets('pausing during the fade pauses at the same beat', (
      tester,
    ) async {
      final run = await _startRun(tester);
      await run.pauseButton();
      final frozen = run.session.transport.positionBeats;
      await run.tapFrame();
      await run.play(resumeDoubleTapGuardSeconds + .1);
      expect(run.veil.opacity, lessThan(1));

      await run.pauseButton();
      expect(run.session.phase, GardenPhase.paused);
      expect(run.session.transport.state, TransportState.paused);
      expect(run.session.transport.positionBeats, frozen);
      expect(run.veil.opacity, 1);
      expect(run.veil.showPlay, isFalse);
      expect(run.veil.onResume, isNotNull);

      // Time passing while paused moves nothing, and the next resume is fresh.
      await run.play(3);
      expect(run.session.transport.positionBeats, frozen);
      await run.tapFrame();
      expect(run.veil.showPlay, isTrue);
      expect(run.veil.opacity, closeTo(1, .01));
      expect(run.audio.fades, hasLength(2));
      expect(run.session.transport.positionBeats, frozen);
      expect(run.audio.fades.last.at, run.session.transport.secondsAt(frozen));
      await _end(tester);
    });

    testWidgets('hiding the page mid-fade pauses, even inside the guard', (
      tester,
    ) async {
      final run = await _startRun(tester);
      await run.pauseButton();
      final frozen = run.session.transport.positionBeats;
      await run.tapFrame();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(run.session.phase, GardenPhase.paused);
      expect(run.veil.opacity, 1);
      expect(run.veil.showPlay, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(run.session.phase, GardenPhase.paused);
      expect(run.session.transport.positionBeats, frozen);
      await run.tapFrame();
      expect(run.session.running, isTrue);
      await _end(tester);
    });

    testWidgets('hiding the page during play lands on the pause frame', (
      tester,
    ) async {
      final run = await _startRun(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(run.session.phase, GardenPhase.paused);
      expect(run.overlay, findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _end(tester);
    });

    testWidgets('a failed resume says so in words, and can be tried again', (
      tester,
    ) async {
      final run = await _startRun(tester);
      await run.pauseButton();
      run.audio.refuse = true;
      await tester.tapAt(const Offset(30, 200));
      await run.settle(
        () => find.textContaining('Sound needs').evaluate().isNotEmpty,
      );
      expect(run.session.phase, GardenPhase.paused);
      expect(run.veil.showPlay, isFalse);
      expect(run.audio.fades, isEmpty);

      run.audio.refuse = false;
      await run.tapFrame();
      expect(find.textContaining('Sound needs'), findsNothing);
      expect(run.session.running, isTrue);
      await _end(tester);
    });

    testWidgets('calm camera: a still frame and a shorter fade', (
      tester,
    ) async {
      final run = await _startRun(tester, calm: true);
      await run.pauseButton();
      expect(run.veil.reducedMotion, isTrue);
      await run.tapFrame();
      expect(run.audio.fades.single.seconds, musicFadeSecondsCalm);
      await run.play(resumeFadeSecondsCalm + .04);
      expect(run.overlay, findsNothing);
      await _end(tester);
    });

    testWidgets('pausing in the doorway to the next room works the same way', (
      tester,
    ) async {
      final run = await _startRun(tester);
      await tester.tap(find.byKey(const ValueKey('autoplay')));
      // The exit waits on the next room's art, which needs real time to load.
      for (var i = 0; i < 20000 && run.scene.exitCodaBeat == null; i++) {
        await run.play(.02);
        if (i % 500 == 0) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
      }
      expect(run.session.phase, GardenPhase.cleared);
      await run.play(.2);

      await run.pauseButton();
      expect(run.veil.showPlay, isFalse);
      expect(run.veil.opacity, 1);
      expect(run.session.transport.state, TransportState.paused);
      final frozen = run.session.transport.positionBeats;

      await tester.tapAt(const Offset(30, 200));
      await run.settle(() => run.audio.fades.isNotEmpty);
      await tester.pump();
      expect(run.veil.showPlay, isTrue);
      expect(run.session.transport.positionBeats, frozen);
      await run.play(resumeFadeSeconds + .04);
      expect(run.overlay, findsNothing);
      await _end(tester);
    });

    testWidgets('a note counts near its ring, and only there', (tester) async {
      final run = await _startRun(tester);
      final cue = await run.untilNoteOpen();
      final landing = cuePath(
        limb: cue.limb,
        beat: cue.beat,
        id: cue.id,
        width: _width,
        height: _height,
      ).landing;
      final session = run.session;
      bool waiting() =>
          session.visibleCues.any((c) => c.id == cue.id && !c.demo);

      // Far from every ring, and in the middle of the screen: costs nothing.
      final combo = session.combo;
      await tester.tapAt(const Offset(_width / 2, 200));
      await tester.pump();
      expect(waiting(), isTrue);
      expect(session.combo, combo);

      // A clumsy thumb, well off the ring's own edge, but in its area.
      final reach = tapAreaRadius(_width) * .85;
      final inward = landing.x < _width / 2 ? reach : -reach;
      await tester.tapAt(Offset(landing.x - inward, landing.y));
      await tester.pump();
      expect(waiting(), isFalse);
      expect(session.combo, combo + 1);
      await _end(tester);
    });

    testWidgets('the pad\'s far corner is stray, even on the note\'s own side', (
      tester,
    ) async {
      final run = await _startRun(tester);
      final cue = await run.untilNoteOpen();
      final landing = cuePath(
        limb: cue.limb,
        beat: cue.beat,
        id: cue.id,
        width: _width,
        height: _height,
      ).landing;
      final radius = tapAreaRadius(_width);
      final session = run.session;
      // Straight up or down from the ring, past its area, staying on its side.
      final y = landing.y - radius - 4;
      final combo = session.combo;
      await tester.tapAt(Offset(landing.x, y));
      await tester.pump();
      expect(session.visibleCues.any((c) => c.id == cue.id && !c.demo), isTrue);
      expect(session.combo, combo);
      await _end(tester);
    });
  });
}
