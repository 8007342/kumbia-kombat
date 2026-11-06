import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_page.dart';
import 'package:kumbia_kombat/gameplay/tap_feedback.dart';
import 'package:kumbia_kombat/music/game_audio.dart';
import 'package:kumbia_kombat/music/score.dart';

class PendingAudio implements GameAudio {
  final activation = Completer<void>();
  int scheduled = 0;
  @override
  String leadShape = 'triangle';
  @override
  double nowSeconds = 0;
  @override
  bool ready = false;
  @override
  Future<void> activate() => activation.future;
  @override
  Future<void> dispose() async {}
  @override
  void silence() {}
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {
    scheduled++;
  }
}

void main() {
  testWidgets('late audio permission cannot start a hidden fight', (
    tester,
  ) async {
    final audio = PendingAudio();
    await tester.pumpWidget(
      MaterialApp(home: GardenPage(audioFactory: () => audio)),
    );
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      if (tester.widget<FilledButton>(find.byType(FilledButton)).onPressed !=
          null) {
        break;
      }
    }
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('ENTRA AL RITMO  >'));
    await tester.pump();
    expect(find.text('WAKING THE MUSIC…'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    audio.ready = true;
    audio.activation.complete();
    await tester.pump(const Duration(milliseconds: 100));
    expect(audio.scheduled, 0);
    // No run began: the signals that replace the old labels never came up.
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is FeedbackPainter,
      ),
      findsNothing,
    );
    expect(find.text('ENTRA AL RITMO  >'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
