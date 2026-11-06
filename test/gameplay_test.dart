import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/progression.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';

void main() {
  test('tap boundaries, matching limb, consumption, and expiry', () {
    final judge = RhythmJudge([
      const RhythmNote('a', Limb.leftHand, 1000),
      const RhythmNote('b', Limb.rightHand, 1500),
    ]);
    expect(judge.tap(Limb.rightFoot, 1000).grade, TapGrade.miss);
    expect(judge.tap(Limb.leftHand, 955).grade, TapGrade.perfect);
    expect(judge.tap(Limb.leftHand, 1000).grade, TapGrade.miss);
    expect(judge.expire(1680), isEmpty);
    expect(judge.expire(1681).single.id, 'b');
    expect(judge.expire(1700), isEmpty);
  });

  test('wider grace accepts both edges and picks closest repeated note', () {
    for (final offset in [-180, 180]) {
      final judge = RhythmJudge([const RhythmNote('a', Limb.leftHand, 1000)]);
      final res = judge.tap(Limb.leftHand, 1000 + offset);
      expect(res.grade, TapGrade.good);
      expect(res.timing, offset < 0 ? TapTiming.early : TapTiming.late);
      expect(res.deltaMs, offset);
    }
    for (final offset in [-181, 181]) {
      final judge = RhythmJudge([const RhythmNote('a', Limb.leftHand, 1000)]);
      expect(judge.tap(Limb.leftHand, 1000 + offset).grade, TapGrade.miss);
    }
    for (final offset in [-75, 75]) {
      final judge = RhythmJudge([const RhythmNote('a', Limb.leftHand, 1000)]);
      final res = judge.tap(Limb.leftHand, 1000 + offset);
      expect(res.grade, TapGrade.perfect);
      expect(res.timing, TapTiming.perfect);
      expect(res.deltaMs, offset);
    }
    final doubles = RhythmJudge([
      const RhythmNote('a', Limb.leftHand, 1000),
      const RhythmNote('b', Limb.leftHand, 1250),
    ]);
    expect(doubles.tap(Limb.leftHand, 1140).note?.id, 'b');
    expect(doubles.tap(Limb.leftHand, 1150).note?.id, 'a');
    expect(doubles.tap(Limb.leftHand, 1250).note, isNull);
  });

  test('flourish follows success once and cannot consume a future tap', () {
    final judge = RhythmJudge([
      const RhythmNote('a', Limb.leftHand, 1000, flourishTo: Limb.rightFoot),
      const RhythmNote('b', Limb.rightFoot, 1600),
    ]);
    expect(judge.flourish('a', Limb.rightFoot, 1050), isFalse);
    expect(judge.tap(Limb.leftHand, 1110).grade, TapGrade.good);
    expect(judge.flourish('a', Limb.rightFoot, 1410), isTrue);
    expect(judge.flourish('a', Limb.rightFoot, 1410), isFalse);
    expect(judge.pizazz, 100);
    expect(judge.tap(Limb.rightFoot, 1600).grade, TapGrade.perfect);
  });

  test('VIP needs full-tier sustain and failure clears the streak', () {
    final fight = FightProgress(fights.last);
    for (var i = 0; i < 12; i++) {
      fight.resolve(passed: true);
    }
    expect(fight.tier, 4);
    expect(fight.cleared, isFalse);
    fight.resolve(passed: true);
    fight.resolve(passed: false);
    expect(fight.tier, 3);
    expect(fight.fullTierSuccesses, 0);
    for (var i = 0; i < 6; i++) {
      expect(fight.resolve(passed: true), ChallengeOutcome.advanced);
    }
    expect(fight.resolve(passed: true), ChallengeOutcome.cleared);
  });

  test('repeated misses reset current fight and success breaks miss chain', () {
    final fight = FightProgress(fights.last);
    fight.resolve(passed: false);
    fight.resolve(passed: false);
    fight.resolve(passed: true);
    expect(fight.consecutiveFailures, 0);
    fight.resolve(passed: false);
    fight.resolve(passed: false);
    expect(fight.resolve(passed: false), ChallengeOutcome.entranceReset);
    expect(fight.entranceResets, 1);
    expect(fight.tier, 0);
  });
}
