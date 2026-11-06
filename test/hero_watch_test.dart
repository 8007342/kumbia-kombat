import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/exit_shot.dart';

void main() {
  const call = 8.0;

  test('he steps back, holds, and is home before his first tap', () {
    expect(HeroWatch.at(0, call), 0);
    expect(HeroWatch.at(HeroWatch.stepOutBeats, call), 1);
    expect(HeroWatch.at(4, call), 1);
    expect(HeroWatch.at(call - HeroWatch.homeBeforeResponse, call), 0);
    expect(HeroWatch.at(call, call), 0);
    expect(HeroWatch.at(9, call), 0);
  });

  test('the step never jumps, on any call', () {
    for (final first in [false, true]) {
      var last = HeroWatch.at(first ? .01 : 0, call, firstCall: first);
      for (var t = .02; t < call; t += .01) {
        final now = HeroWatch.at(t, call, firstCall: first);
        expect((now - last).abs(), lessThan(.02), reason: 't $t first $first');
        last = now;
      }
    }
  });

  test('the first call starts on the spot he walked in to', () {
    expect(HeroWatch.at(0, call, firstCall: true), 1);
    expect(HeroWatch.walking(0, call, firstCall: true), isFalse);
    expect(HeroWatch.walking(0, call), isTrue);
  });

  test('keeping time speeds up and lifts with the music', () {
    expect(HeroWatch.tapAlong(0, 0).frame, HeroWatch.tapAlong(1.5, 0).frame);
    expect(
      HeroWatch.tapAlong(0, 2).frame,
      isNot(HeroWatch.tapAlong(1, 2).frame),
    );
    expect(HeroWatch.tapAlong(.5, 2).hop, 0);
    expect(HeroWatch.tapAlong(.5, 3).hop, greaterThan(0));
  });
}
