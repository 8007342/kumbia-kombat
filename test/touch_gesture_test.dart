import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/gesture_shapes.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/touch_gesture.dart';

RhythmNote _note(GestureKind? offer) => RhythmNote(
  'style',
  Limb.leftHand,
  1000,
  flourishTo: Limb.rightFoot,
  offer: offer,
);

/// Draws a path through the tracker, one point at a time. Returns the result if
/// it landed before the lift, and how much of the path that took.
({DanceStrokeResult? early, double share, DanceStrokeResult? lifted}) _draw(
  List<(double, double)> path, {
  GestureKind? offer,
  double size = 80,
}) {
  final gestures = DanceTouchGestures()
    ..begin(pointer: 7, x: 100, y: 100, acceptedNote: _note(offer));
  for (var i = 1; i < path.length; i++) {
    final (x, y) = path[i];
    final done = gestures.move(pointer: 7, x: 100 + x * size, y: 100 + y * size);
    if (done != null) {
      return (early: done, share: i / (path.length - 1), lifted: null);
    }
  }
  final (x, y) = path.last;
  return (
    early: null,
    share: 1,
    lifted: gestures.end(pointer: 7, x: 100 + x * size, y: 100 + y * size),
  );
}

void main() {
  test('every drawn glyph is read as itself, both ways, at any size', () {
    for (final kind in GestureKind.values) {
      for (final flip in [false, true]) {
        for (final size in [40.0, 80.0, 160.0]) {
          final result = _draw(idealStroke(kind, flip: flip), size: size);
          expect(result.lifted?.kind, kind, reason: '$kind $flip $size');
        }
      }
    }
  });

  test('an offered shape lands without waiting for the lift', () {
    for (final kind in [
      GestureKind.spin,
      GestureKind.wave,
      GestureKind.stomp,
      GestureKind.circle,
    ]) {
      final result = _draw(idealStroke(kind), offer: kind);
      expect(result.early?.kind, kind, reason: '$kind');
      expect(result.share, lessThanOrEqualTo(1), reason: '$kind');
    }
  });

  test('a sideways drag only earns a wave if it really goes round', () {
    // A thumb swinging sideways, curved 50 degrees.
    final swing = [
      for (var i = 0; i <= 30; i++)
        (
          (math.sin((i / 30 - .5) * 50 * math.pi / 180) + math.sin(25 * math.pi / 180)) * 1.2,
          (math.cos(25 * math.pi / 180) - math.cos((i / 30 - .5) * 50 * math.pi / 180)) * 1.2,
        ),
    ];
    final result = _draw(swing, offer: GestureKind.wave);
    expect(result.early, isNull, reason: 'It never finished the semi-circle.');
    expect(result.lifted?.kind, GestureKind.spin);
  });

  test('a stroke that isn\'t what was asked still counts as what it was', () {
    final result = _draw(idealStroke(GestureKind.spin), offer: GestureKind.stomp);
    expect(result.lifted?.kind, GestureKind.spin);
    expect(result.lifted?.stroke.noteId, 'style');
  });

  test('sideways picks the side, and round shapes pick which way round', () {
    expect(
      _draw(idealStroke(GestureKind.spin)).lifted?.direction,
      FlourishDirection.right,
    );
    expect(
      _draw(idealStroke(GestureKind.spin, flip: true)).lifted?.direction,
      FlourishDirection.left,
    );
    expect(
      _draw(idealStroke(GestureKind.stomp)).lifted?.direction,
      FlourishDirection.up,
    );
    expect(
      _draw(idealStroke(GestureKind.wave)).lifted?.direction,
      isNot(_draw(idealStroke(GestureKind.wave, flip: true)).lifted?.direction),
    );
  });

  test('a plain tap and a jittering thumb earn nothing and leave no trail', () {
    final gestures = DanceTouchGestures()
      ..begin(pointer: 1, x: 50, y: 50, acceptedNote: _note(GestureKind.spin));
    expect(gestures.end(pointer: 1, x: 50, y: 50), isNull);
    expect(gestures.strokes, isEmpty);

    gestures.begin(pointer: 2, x: 50, y: 50, acceptedNote: _note(null));
    final wobble = math.Random(4);
    for (var i = 0; i < 90; i++) {
      gestures.move(
        pointer: 2,
        x: 50 + wobble.nextDouble() * 18 - 9,
        y: 50 + wobble.nextDouble() * 18 - 9,
      );
    }
    expect(gestures.end(pointer: 2, x: 50, y: 50), isNull);
  });

  test('a note without an invitation, or no note, tracks nothing', () {
    final gestures = DanceTouchGestures()
      ..begin(pointer: 1, x: 0, y: 0, acceptedNote: null)
      ..begin(
        pointer: 2,
        x: 0,
        y: 0,
        acceptedNote: const RhythmNote('plain', Limb.leftHand, 1000),
      );
    expect(gestures.live, isEmpty);
    expect(gestures.end(pointer: 1, x: 90, y: 0), isNull);
    expect(gestures.end(pointer: 2, x: 90, y: 0), isNull);
  });

  test('pointer identity, cancellation and clearing all void a stroke', () {
    DanceTouchGestures started() => DanceTouchGestures()
      ..begin(pointer: 7, x: 0, y: 0, acceptedNote: _note(GestureKind.spin));
    expect(started().end(pointer: 8, x: 90, y: 0), isNull);
    final once = started();
    expect(once.end(pointer: 7, x: 90, y: 0), isNotNull);
    expect(once.end(pointer: 7, x: 90, y: 0), isNull);
    final cancelled = started()..cancel(7);
    expect(cancelled.end(pointer: 7, x: 90, y: 0), isNull);
    expect(cancelled.strokes, isEmpty, reason: 'No visible failure at all.');
    expect((started()..clear()).end(pointer: 7, x: 90, y: 0), isNull);
    final invalid = started();
    expect(invalid.move(pointer: 7, x: double.nan, y: 0), isNull);
    expect(invalid.end(pointer: 7, x: 0, y: double.infinity), isNull);
  });

  test('a held pointer can\'t grow without bound, and keeps its shape', () {
    final gestures = DanceTouchGestures()
      ..begin(pointer: 1, x: 0, y: 0, acceptedNote: _note(null));
    for (var i = 0; i < 5000; i++) {
      gestures.move(pointer: 1, x: i * .05, y: 0);
    }
    expect(gestures.live.single.xy.length, lessThanOrEqualTo(2 * 256 + 2));
    expect(gestures.end(pointer: 1, x: 250, y: 0)?.kind, GestureKind.spin);
  });

  test('settling reads what\'s been drawn so far', () {
    final gestures = DanceTouchGestures()
      ..begin(pointer: 1, x: 0, y: 0, acceptedNote: _note(GestureKind.stomp));
    for (final (x, y) in idealStroke(GestureKind.spin)) {
      gestures.move(pointer: 1, x: x * 80, y: y * 80);
    }
    expect(gestures.settle(1)?.kind, GestureKind.spin);
    expect(gestures.live, isEmpty);
  });

  test('a finished trail is forgotten once it has faded', () {
    var now = 10.0;
    final gestures = DanceTouchGestures(clock: () => now)
      ..begin(pointer: 1, x: 0, y: 0, acceptedNote: _note(null));
    gestures.end(pointer: 1, x: 90, y: 0);
    expect(gestures.strokes, hasLength(1));
    now += DanceTouchGestures.fadeSeconds + .01;
    gestures.prune();
    expect(gestures.strokes, isEmpty);
  });
}
