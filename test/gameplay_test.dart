import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/progression.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';

void main() {
  const late = RhythmJudge.lateWindowMs;
  const perfect = RhythmJudge.perfectWindowMs;

  test('the windows lean late, and perfect still means something', () {
    // Late gets the latency estimate's slack; early stays where it was.
    expect(RhythmJudge.lateWindowMs, greaterThan(RhythmJudge.earlyWindowMs));
    expect(RhythmJudge.lateWindowMs, inInclusiveRange(200, 250));
    expect(perfect, lessThan(RhythmJudge.earlyWindowMs / 2));
    expect(RhythmJudge.guaranteedWindowMs, RhythmJudge.earlyWindowMs);
  });

  test('tap boundaries, matching limb, consumption, and expiry', () {
    final judge = RhythmJudge([
      const RhythmNote('a', Limb.leftHand, 1000),
      const RhythmNote('b', Limb.rightHand, 1500),
    ]);
    expect(judge.tap(Limb.rightFoot, 1000).grade, TapGrade.miss);
    expect(judge.tap(Limb.leftHand, 955).grade, TapGrade.perfect);
    expect(judge.tap(Limb.leftHand, 1000).grade, TapGrade.miss);
    expect(judge.expire(1500 + late), isEmpty);
    expect(judge.expire(1500 + late + 1).single.id, 'b');
    expect(judge.expire(1500 + late + 20), isEmpty);
  });

  test('wider grace accepts both edges and picks closest repeated note', () {
    const early = RhythmJudge.earlyWindowMs;
    for (final offset in [-early, late]) {
      final judge = RhythmJudge([const RhythmNote('a', Limb.leftHand, 1000)]);
      final res = judge.tap(Limb.leftHand, 1000 + offset);
      expect(res.grade, TapGrade.good);
      expect(res.timing, offset < 0 ? TapTiming.early : TapTiming.late);
      expect(res.deltaMs, offset);
    }
    for (final offset in [-early - 1, late + 1]) {
      final judge = RhythmJudge([const RhythmNote('a', Limb.leftHand, 1000)]);
      expect(judge.tap(Limb.leftHand, 1000 + offset).grade, TapGrade.miss);
    }
    for (final offset in [-perfect, perfect]) {
      final judge = RhythmJudge([const RhythmNote('a', Limb.leftHand, 1000)]);
      final res = judge.tap(Limb.leftHand, 1000 + offset);
      expect(res.grade, TapGrade.perfect);
      expect(res.timing, TapTiming.perfect);
      expect(res.deltaMs, offset);
    }
    for (final offset in [-perfect - 1, perfect + 1]) {
      final judge = RhythmJudge([const RhythmNote('a', Limb.leftHand, 1000)]);
      expect(judge.tap(Limb.leftHand, 1000 + offset).grade, TapGrade.good);
    }
    final doubles = RhythmJudge([
      const RhythmNote('a', Limb.leftHand, 1000),
      const RhythmNote('b', Limb.leftHand, 1250),
    ]);
    expect(doubles.tap(Limb.leftHand, 1140).note?.id, 'b');
    expect(doubles.tap(Limb.leftHand, 1150).note?.id, 'a');
    expect(doubles.tap(Limb.leftHand, 1250).note, isNull);
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
