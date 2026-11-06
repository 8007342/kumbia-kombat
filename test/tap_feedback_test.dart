import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/tap_feedback.dart';

FeedbackMark _tap(TapTiming timing, int deltaMs, {int combo = 0}) =>
    FeedbackMark.tap(timing, Offset.zero, deltaMs: deltaMs, combo: combo);

MarkPose _at(FeedbackMark mark, double age, {bool reducedMotion = false}) =>
    mark.pose(age, reducedMotion: reducedMotion);

void main() {
  group('early and late part by more than colour', () {
    final early = _tap(TapTiming.early, -120);
    final late = _tap(TapTiming.late, 120);

    test('shape: early stops short of the ring, late runs past it', () {
      expect(_at(early, 0).sweep, lessThan(1));
      expect(_at(late, 0).sweep, greaterThan(1));
      expect(_at(_tap(TapTiming.perfect, 10), 0).sweep, 1);
    });

    test('motion: early shrinks inward, late swells outward', () {
      expect(_at(early, .2).scale, lessThan(_at(early, 0).scale));
      expect(_at(late, .2).scale, greaterThan(_at(late, 0).scale));
    });

    test('effects: early droplets rise, late embers fall', () {
      for (final spark in _at(early, .2).sparks) {
        expect(spark.offset.dy, lessThan(0));
      }
      for (final spark in _at(late, .2).sparks) {
        expect(spark.offset.dy, greaterThan(0));
      }
    });

    test('colour as well, and every kind has its own', () {
      final colours = {
        for (final kind in MarkKind.values)
          if (kind != MarkKind.phrase) FeedbackMark(kind, Offset.zero).color,
      };
      expect(colours, hasLength(4));
    });

    test('the further off, the bigger the gap or the tail', () {
      expect(
        _at(_tap(TapTiming.early, -170), 0).sweep,
        lessThan(_at(_tap(TapTiming.early, -80), 0).sweep),
      );
      expect(
        _at(_tap(TapTiming.late, 170), 0).sweep,
        greaterThan(_at(_tap(TapTiming.late, 80), 0).sweep),
      );
    });

    test('calm camera keeps the shape and drops the motion and sparks', () {
      for (final mark in [early, late]) {
        final calm = _at(mark, .2, reducedMotion: true);
        expect(calm.sweep, _at(mark, 0).sweep);
        expect(calm.scale, 1);
        expect(calm.sparks, isEmpty);
      }
    });
  });

  test('a mark clears before the fastest notes come round again', () {
    expect(FeedbackMark.lifeSeconds, lessThan(.281));
    expect(_at(_tap(TapTiming.perfect, 0), 0).opacity, 1);
    expect(
      _at(_tap(TapTiming.perfect, 0), FeedbackMark.lifeSeconds).opacity,
      0,
    );
  });

  test('flow and a style chain show as more sparks, not a number', () {
    expect(
      _at(_tap(TapTiming.perfect, 0, combo: 5), .1).sparks.length,
      greaterThan(_at(_tap(TapTiming.perfect, 0), .1).sparks.length),
    );
    expect(
      FeedbackMark(MarkKind.flourish, Offset.zero, chain: 3).sparkCount,
      greaterThan(FeedbackMark(MarkKind.flourish, Offset.zero).sparkCount),
    );
    // Follow-throughs are sparks alone: the ring is for how a tap landed.
    expect(FeedbackMark(MarkKind.flourish, Offset.zero).hasRing, isFalse);
  });

  group('whose turn it is', () {
    TurnLook look(GardenPhase phase, {double beat = 0, int flow = 0}) =>
        TurnLook.of(phase, beat: beat, flow: flow, reducedMotion: false);

    test('the band dims for the call and lights for the response', () {
      final call = look(GardenPhase.call);
      final response = look(GardenPhase.response);
      expect(call.color, isNot(response.color));
      expect(response.glow, greaterThan(call.glow));
      expect(response.ring, greaterThan(call.ring));
    });

    test('flow fills the band', () {
      expect(
        look(GardenPhase.response, flow: 6).glow,
        greaterThan(look(GardenPhase.response).glow),
      );
    });

    test('the intro breathes with the beat, and calm camera holds still', () {
      expect(
        look(GardenPhase.intro).ring,
        greaterThan(look(GardenPhase.intro, beat: .75).ring),
      );
      expect(
        TurnLook.of(
          GardenPhase.intro,
          beat: 0,
          flow: 0,
          reducedMotion: true,
        ).ring,
        TurnLook.of(
          GardenPhase.intro,
          beat: .75,
          flow: 0,
          reducedMotion: true,
        ).ring,
      );
    });

    test('a failed phrase dulls the band', () {
      final dull = TurnLook.of(
        GardenPhase.response,
        beat: 0,
        flow: 4,
        reducedMotion: false,
        sagging: true,
      );
      expect(dull.glow, lessThan(look(GardenPhase.call).glow));
    });
  });
}
