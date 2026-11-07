import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/room_dissolve.dart';

void main() {
  test('the old room starts solid, clears smoothly and is gone at the end', () {
    expect(RoomDissolve.opacityAt(0), 1);
    expect(RoomDissolve.opacityAt(RoomDissolve.seconds), 0);
    expect(RoomDissolve.opacityAt(RoomDissolve.seconds * 3), 0);
    var previous = 1.0;
    for (var i = 1; i <= 24; i++) {
      final now = RoomDissolve.opacityAt(RoomDissolve.seconds * i / 24);
      expect(now, lessThanOrEqualTo(previous));
      previous = now;
    }
  });

  test('it has no speed at either end, and motion is optional', () {
    expect(RoomDissolve.progress(.01), lessThan(.001));
    expect(
      RoomDissolve.progress(RoomDissolve.seconds - .01),
      greaterThan(.999),
    );
    expect(RoomDissolve.growthAt(.6, reducedMotion: true), 1);
    expect(RoomDissolve.growthAt(.6, reducedMotion: false), greaterThan(1));
  });

  test('the new room is clear before the shortest intro ends', () {
    // Four beats at the fastest base tempo in the game, the lawn's 128 BPM.
    expect(RoomDissolve.seconds, lessThan(4 * 60 / 128));
  });
}
