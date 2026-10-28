import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/touch_gesture.dart';

const _styleNote = RhythmNote(
  'style',
  Limb.leftHand,
  1000,
  flourishTo: Limb.rightFoot,
);

void main() {
  DanceTouchGestures started({RhythmNote? note = _styleNote}) {
    return DanceTouchGestures()..begin(
      pointer: 7,
      x: 100,
      y: 100,
      at: const Duration(seconds: 1),
      acceptedNote: note,
    );
  }

  DanceFlick? release(
    DanceTouchGestures gestures, {
    int pointer = 7,
    double x = 124,
    double y = 100,
    int atMs = 1200,
  }) => gestures.end(
    pointer: pointer,
    x: x,
    y: y,
    at: Duration(milliseconds: atMs),
  );

  test('short local flicks distinguish all four musical directions', () {
    for (final entry in {
      FlourishDirection.up: (100.0, 76.0),
      FlourishDirection.right: (124.0, 100.0),
      FlourishDirection.down: (100.0, 124.0),
      FlourishDirection.left: (76.0, 100.0),
    }.entries) {
      final result = release(started(), x: entry.value.$1, y: entry.value.$2);
      expect(result?.direction, entry.key);
      expect(result?.noteId, 'style');
    }
    expect(release(started(), x: 123.9), isNull);
    expect(release(started(), x: 100), isNull);
    expect(
      release(started(), x: 123, y: 120)?.direction,
      FlourishDirection.right,
    );
  });

  test('pointer-up cannot create style after a miss or ordinary tap', () {
    expect(release(started(note: null)), isNull);
    expect(
      release(started(note: const RhythmNote('plain', Limb.leftHand, 1000))),
      isNull,
    );
  });

  test('pointer identity, cancellation and pause clear pending gestures', () {
    final gestures = started();
    expect(release(gestures, pointer: 8), isNull);
    expect(release(gestures), isNotNull);
    expect(release(gestures), isNull);
    expect(release(started()..cancel(7)), isNull);
    expect(release(started()..clear()), isNull);
  });

  test('time boundary rejects stale, reversed and invalid movement', () {
    expect(release(started(), atMs: 1400), isNotNull);
    expect(release(started(), atMs: 1401), isNull);
    expect(release(started(), atMs: 1000), isNull);
    expect(release(started(), atMs: 999), isNull);
    expect(release(started(), x: double.nan), isNull);
    expect(release(started(), y: double.infinity), isNull);
  });

  test(
    'late tap keeps its credit and full flick window without eating a note',
    () {
      final judge = RhythmJudge([
        _styleNote,
        const RhythmNote('next', Limb.rightFoot, 1600),
      ]);
      final tap = judge.tap(Limb.leftHand, 1180);
      expect(tap.timing, TapTiming.late);
      final gestures = DanceTouchGestures()
        ..begin(
          pointer: 1,
          x: 100,
          y: 100,
          at: const Duration(milliseconds: 1180),
          acceptedNote: tap.note,
        );
      final flick = gestures.end(
        pointer: 1,
        x: 76,
        y: 100,
        at: const Duration(milliseconds: 1580),
      );
      expect(flick?.direction, FlourishDirection.left);
      expect(judge.flourishGesture(flick!.noteId, 1580), isTrue);
      expect(judge.flourishGesture(flick.noteId, 1580), isFalse);
      expect(judge.flourish('style', Limb.rightFoot, 1580), isFalse);
      expect(judge.pizazz, 100);
      expect(judge.tap(Limb.rightFoot, 1600).grade, TapGrade.perfect);
    },
  );

  test('an omitted or invalid flick never penalizes the accepted tap', () {
    final judge = RhythmJudge([_styleNote]);
    expect(judge.flourishGesture('unknown', 1100), isFalse);
    expect(judge.flourishGesture('style', 1100), isFalse);
    expect(judge.tap(Limb.leftHand, 1000).grade, TapGrade.perfect);
    expect(judge.flourishGesture('style', 1401), isFalse);
    expect(judge.expire(1500), isEmpty);
    expect(judge.pizazz, 0);
    expect(judge.tap(Limb.leftHand, 1500).note, isNull);
  });

  test('unmarked notes cannot earn style through a direct recognizer call', () {
    final judge = RhythmJudge([const RhythmNote('plain', Limb.leftHand, 1000)]);
    judge.tap(Limb.leftHand, 1000);
    expect(judge.flourishGesture('plain', 1100), isFalse);
    expect(judge.flourish('missing', Limb.leftHand, 1100), isFalse);
  });
}
