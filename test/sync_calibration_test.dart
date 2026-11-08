import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/sync_calibration.dart';
import 'package:kumbia_kombat/gameplay/sync_overlay.dart';

void main() {
  SyncCalibration run() => SyncCalibration(firstClickMs: 1000);

  group('the tap-along', () {
    test('a steady late player measures late, by the median', () {
      final cal = run();
      for (var i = 4; i < 20; i++) {
        cal.tap(cal.clicksMs[i] + 80 + (i.isEven ? 12 : -12));
      }
      expect(cal.deltasMs, hasLength(16));
      expect(cal.offsetMs, 80);
    });

    test('count-in taps and taps past the end are not counted', () {
      final cal = run();
      for (var i = 0; i < 4; i++) {
        cal.tap(cal.clicksMs[i]);
      }
      cal.tap(cal.endMs + 400);
      expect(cal.deltasMs, isEmpty);
      expect(cal.offsetMs, isNull);
    });

    test('a stumble does not move the result, and too few taps give none', () {
      final cal = run();
      for (var i = 4; i < 12; i++) {
        cal.tap(cal.clicksMs[i] - 30);
      }
      cal.tap(cal.clicksMs[12] + 280);
      expect(cal.kept, hasLength(8));
      expect(cal.offsetMs, -30);
      final few = run();
      for (var i = 4; i < 4 + SyncCalibration.minimumTaps - 1; i++) {
        few.tap(few.clicksMs[i]);
      }
      expect(few.offsetMs, isNull);
    });

    test('a Bluetooth-late player still measures, up to the cap', () {
      final cal = run();
      for (var i = 4; i < 20; i++) {
        cal.tap(cal.clicksMs[i] + 240);
      }
      expect(cal.offsetMs, 240);
      final worse = run();
      for (var i = 4; i < 20; i++) {
        worse.tap(worse.clicksMs[i] + 290);
      }
      expect(worse.offsetMs, SyncCalibration.maxOffsetMs);
      expect(SyncCalibration.maxOffsetMs, lessThan(cal.beatMs / 2));
    });
  });

  group('the auto-nudge', () {
    test('takes a steady lean whole at first, then half, up to its cap', () {
      // Deltas are measured on the judged clock, so after a move they're what
      // is left over.
      final nudge = AutoNudge();
      expect(nudge.phrase([150, 140, 160, 150]), 150);
      expect(nudge.phrase([40, 40, 40, 40]), 170);
      expect(nudge.phrase([400, 400, 400, 400]), AutoNudge.capMs);
      expect(AutoNudge.capMs, SyncCalibration.maxOffsetMs);
    });

    test('learns from near misses: a Bluetooth lean past the window', () {
      // Every tap missed the 260 ms late window; the near misses still say
      // where the player is.
      final nudge = AutoNudge();
      expect(nudge.phrase([300, 320, 310, 290, 305]), AutoNudge.capMs);
    });

    test('leaves small leans and short phrases alone', () {
      final nudge = AutoNudge();
      expect(nudge.phrase([20, 25, 30, 10]), 0);
      expect(nudge.phrase([100, 100, 100]), 0);
      expect(nudge.phrase([-70, -70, -70, -70]), -70);
      expect(nudge.phrase([-70, -70, -70, -70]), -105);
    });
  });

  test('the sync bar puts early left and late right', () {
    expect(SyncBarPainter.position(0), .5);
    expect(SyncBarPainter.position(-100), lessThan(.5));
    expect(SyncBarPainter.position(100), greaterThan(.5));
  });

  testWidgets('the overlay plays its clicks and saves what it measures', (
    tester,
  ) async {
    var now = 0;
    final clicks = <double>[];
    int? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            SyncCalibrationOverlay(
              activate: () async {},
              nowMs: () => now,
              judgeOffsetMs: () => 100,
              eventAgeMs: (_) => 0,
              click: (at, {required bool accent}) => clicks.add(at),
              saved: null,
              onSave: (offset) => saved = offset,
              onClose: () {},
            ),
          ],
        ),
      ),
    );
    expect(find.text('SYNC'), findsOneWidget);
    await tester.tap(find.text('START  >'));
    await tester.pump();
    expect(clicks, hasLength(20));
    // Each tap reaches the game 100 ms after its click, and the game already
    // takes off 100 ms: this player is right on.
    for (var i = 4; i < 20; i++) {
      now = (clicks[i] * 1000).round() + 100;
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
    }
    now = (clicks.last * 1000).round() + 1000;
    await tester.pump(const Duration(milliseconds: 20));
    expect(saved, 0);
    expect(find.text('IN SYNC'), findsOneWidget);
  });
}
