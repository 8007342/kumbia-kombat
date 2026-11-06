import 'dart:async';
import 'dart:convert';

import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_page.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/gesture_capture_page.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/music/game_audio.dart';
import 'package:kumbia_kombat/music/score.dart';

class _Audio implements GameAudio {
  int activations = 0;
  @override
  double nowSeconds = 0;
  @override
  bool ready = false;
  @override
  String leadShape = '';
  @override
  Future<void> activate() async {
    activations++;
    ready = true;
  }

  @override
  Future<void> dispose() async {}
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {}
  @override
  void silence() {}
}

void main() {
  testWidgets('AutoPlay pressed before the campaign has loaded isn\'t lost', (
    tester,
  ) async {
    // These caches are global, and their futures belong to the last test's zone.
    Flame.images.clearCache();
    rootBundle.clear();
    final loading = Completer<LevelRegistry>();
    final audio = _Audio();
    await tester.pumpWidget(
      MaterialApp(
        home: GardenPage(audioFactory: () => audio, levels: () => loading.future),
      ),
    );
    final button = find.byKey(const ValueKey('autoplay'));
    expect(
      tester.widget<IconButton>(button).onPressed,
      isNotNull,
      reason: 'A disabled icon is what used to ignore the press, silently.',
    );
    await tester.tap(button);
    await tester.pump();
    // It shows the choice straight away, and asks for sound inside the press.
    expect(
      find.byTooltip('AutoPlay on, with mistakes. Tap to watch it flawless.'),
      findsOneWidget,
    );
    expect(audio.activations, 1);

    // When the campaign arrives, the run starts without another press.
    final levels = await tester.runAsync(LevelRegistry.loadShipping);
    loading.complete(levels);
    final game = tester.widget<GameWidget<GardenSceneGame>>(
      find.byType(GameWidget<GardenSceneGame>),
    );
    for (var i = 0; i < 400; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      final phase = game.game!.session?.phase;
      if (phase != null && phase != GardenPhase.ready) break;
    }
    expect(game.game!.session?.phase, isNot(GardenPhase.ready));
    expect(game.game!.session, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    // The palette prepares its wardrobes in the background: let that finish.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 5));
    }
  });

  testWidgets('the capture page saves what was drawn, labelled as asked', (
    tester,
  ) async {
    String? copied;
    await tester.pumpWidget(
      MaterialApp(home: GestureCapturePage(copy: (json) => copied = json)),
    );
    expect(find.text('Tap and draw: spin'), findsOneWidget);
    await tester.dragFrom(const Offset(100, 300), const Offset(120, 0));
    await tester.pump();
    expect(find.textContaining('1 saved'), findsOneWidget);
    expect(find.text('Tap and draw: flick'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('copy-captured')));
    await tester.pump();
    final saved = jsonDecode(copied!) as List;
    expect(saved, hasLength(1), reason: 'The copy press isn\'t a stroke.');
    expect(saved.first['asked'], 'spin');
    expect((saved.first['xy'] as List).length, greaterThan(2));
    expect(saved.first['ms'], isA<List>());
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
