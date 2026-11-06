import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/exit_shot.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_layout.dart';

/// Two floor points are the same place, near enough for an eased route.
class PartyPointMatcher extends Matcher {
  const PartyPointMatcher(this.x, this.y);
  final double x, y;
  @override
  bool matches(Object? item, Map<dynamic, dynamic> state) {
    final p = item as dynamic;
    return ((p.x as double) - x).abs() < 1e-9 &&
        ((p.y as double) - y).abs() < 1e-9;
  }

  @override
  Description describe(Description description) =>
      description.add('the floor point ($x, $y)');
}

void main() {
  const call = 8.0;

  LevelRegistry campaign() => LevelRegistry.parse(
    File('levels/index.json').readAsStringSync(),
    (id) => File('levels/$id.json').readAsStringSync(),
  );

  test('he goes back and then to the side, and comes home the same way', () {
    for (final level in campaign().levels) {
      final stage = level.stage;
      PartyPointMatcher near(PartyPoint p) => PartyPointMatcher(p.x, p.y);
      expect(stage.heroDuringCall(0, call), near(stage.heroHome));
      expect(
        stage.heroDuringCall(HeroWatch.stepOutBeats / 2, call),
        near(stage.heroWatch),
      );
      expect(
        stage.heroDuringCall(HeroWatch.stepOutBeats, call),
        near(stage.heroAside),
      );
      final inEnd = call - HeroWatch.homeBeforeResponse;
      final inStart = inEnd - HeroWatch.stepInBeats;
      expect(stage.heroDuringCall(inStart, call), near(stage.heroAside));
      expect(
        stage.heroDuringCall((inStart + inEnd) / 2, call),
        near(stage.heroWatch),
      );
      expect(stage.heroDuringCall(inEnd, call), near(stage.heroHome));
    }
  });

  test('reduced motion cuts: outside for the call, home for the answer', () {
    for (final level in campaign().levels) {
      final stage = level.stage;
      for (final t in [0.0, .5, 3.0, 7.0]) {
        final at = stage.heroDuringCall(t, call, reducedMotion: true);
        expect(at.x, stage.heroAside.x, reason: 't $t');
        expect(at.y, stage.heroAside.y, reason: 't $t');
      }
      final home = stage.heroDuringCall(7.9, call, reducedMotion: true);
      expect(home.x, stage.heroHome.x);
    }
  });

  test('a short call fits the whole route in, and he is home in time', () {
    for (final short in [2.0, 4.0]) {
      expect(HeroWatch.at(0, short), 0);
      expect(
        HeroWatch.at(short - HeroWatch.homeBeforeResponse, short),
        closeTo(0, 1e-9),
      );
      final peak = [
        for (var t = 0.0; t < short; t += .05) HeroWatch.at(t, short),
      ].reduce((a, b) => a > b ? a : b);
      expect(peak, closeTo(1, .02));
    }
  });

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

  test('he taps at first, then claps on two and four, then on every beat', () {
    expect(HeroWatch.tapAlong(0, 0).frame, HeroWatch.tapAlong(1.5, 0).frame);
    expect(HeroWatch.tapAlong(0, 0).frame, startsWith('rear_walk'));
    expect(HeroWatch.tapAlong(1, 1).frame, 'clap_together');
    expect(HeroWatch.tapAlong(3, 2).frame, 'clap_together');
    expect(HeroWatch.tapAlong(2, 2).frame, 'clap_apart');
    expect(HeroWatch.tapAlong(2, 3).frame, 'clap_together');
    expect(HeroWatch.tapAlong(.5, 2).hop, 0);
    expect(HeroWatch.tapAlong(.5, 3).hop, greaterThan(0));
  });

  test('every frame he keeps time with is in his atlas', () {
    final hero =
        (jsonDecode(
                  File('assets/art/party/manifest.json').readAsStringSync(),
                )['atlases']
                as Map)['hero']
            as Map;
    final frames = hero['frames'] as Map;
    for (var tier = 0; tier < 5; tier++) {
      for (var beat = 0.0; beat < 8; beat += .125) {
        expect(frames, contains(HeroWatch.tapAlong(beat, tier).frame));
      }
    }
  });
}
