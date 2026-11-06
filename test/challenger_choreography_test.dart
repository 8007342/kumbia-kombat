import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/challenger_choreography.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

class ChoreographyAudio implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool get ready => true;
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {}
  @override
  void silence() {}
}

void main() {
  final chart = FightChart.garden;
  ChallengerChoreography routine() => ChallengerChoreography(
    limbs: chart.limbs,
    offsets: chart.offsets,
    callBeats: chart.callBeats,
  );
  ChallengerPose at(double relative, {bool reducedMotion = false}) =>
      routine().sample(
        beat: 20 + relative,
        callStartBeat: 20,
        reducedMotion: reducedMotion,
      );

  test(
    'every actual chart limb accents at its authored beat across all tiers',
    () {
      for (final chart in [FightChart.garden, FightChart.bar]) {
        for (var tier = 0; tier < 5; tier++) {
          for (var peak = 0; peak < 2; peak++) {
            final limbs = chart.limbsFor(tier, peak);
            final choreography = ChallengerChoreography(
              limbs: limbs,
              offsets: chart.offsets,
            );
            for (var i = 0; i < limbs.length; i++) {
              final pose = choreography.sample(
                beat: 20 + chart.offsets[i],
                callStartBeat: 20,
              );
              expect(pose.movePhase, DanceMovePhase.accent);
              expect(pose.limb, limbs[i]);
              expect(pose.noteIndex, i);
            }
          }
        }
      }
    },
  );

  test(
    'anticipation, accent, follow-through and settle fit eighth-note spacing',
    () {
      expect(at(-.1).frameId, 'anticipate_left');
      expect(at(0).frameId, 'left_hand');
      expect(at(.3).frameId, 'follow_left');
      expect(at(.5).frameId, 'settle');
      expect(at(.8).frameId, 'anticipate_right');
      expect(at(1).frameId, 'right_hand');
      expect(at(2.38).movePhase, DanceMovePhase.anticipation);
      expect(at(2.5).movePhase, DanceMovePhase.accent);
      expect(at(2.5).noteIndex, 3);
    },
  );

  test(
    'routine ends and yields before response without extending its chart',
    () {
      expect(at(6.5).movePhase, DanceMovePhase.accent);
      expect(at(6.9).state, ChallengerDanceState.settle);
      expect(at(7.1).state, ChallengerDanceState.finish);
      expect(at(7.4).state, ChallengerDanceState.cede);
      expect(at(7.7).state, ChallengerDanceState.invite);
      expect(at(7.7).playerRole, PlayerDanceRole.ready);
      // The sidestep eases on through the response's first beat.
      expect(at(8).state, ChallengerDanceState.invite);
      expect(at(8).floorYield, closeTo(yieldByHandoff, 1e-9));
      expect(at(8).playerRole, PlayerDanceRole.responding);
      expect(at(9).state, ChallengerDanceState.watch);
      expect(at(9).floorYield, 1);
      // Invitation precedes the first accepted early tap even at the faster bar tempo.
      expect(at(8 - .18 * 112 / 60).state, ChallengerDanceState.invite);
      expect(at(15.8).state, ChallengerDanceState.ready);
      expect(at(15.8).floorYield, lessThan(.5));
    },
  );

  test('clearance and recovery are explicit short social gestures', () {
    final choreography = routine();
    ChallengerPose result(
      double age, {
      bool passed = true,
      bool cleared = false,
    }) => choreography.sample(
      beat: 34 + age,
      callStartBeat: 20,
      outcomeBeat: 34,
      passed: passed,
      cleared: cleared,
    );
    expect(result(.1).frameId, 'approve');
    expect(result(.1, passed: false).frameId, 'recover');
    // By now the walk back to the mark has begun, ahead of the next call.
    expect(result(1, passed: false).state, ChallengerDanceState.ready);
    expect(result(.6, cleared: true).frameId, 'turn_out');
    expect(result(.9, cleared: true).frameId, 'cede');
    expect(result(1.1, cleared: true).frameId, 'invite');
    expect(result(20, cleared: true).frameId, 'invite');
  });

  test('reduced motion keeps legible accents and disables decorative root movement', () {
    for (var i = 0; i < 160; i++) {
      final pose = at(i / 10, reducedMotion: true);
      expect(pose.rootOffsetX, 0);
      expect(pose.floorYield, anyOf(0, 1));
      expect(challengerFrameIds, contains(pose.frameId));
    }
    expect(at(4, reducedMotion: true).frameId, 'left_foot');
  });

  test('audible tempo changes wall time, not note identity or pause pose', () {
    final audio = ChoreographyAudio();
    final music = MusicTransport(
      MusicScore(
        id: 'dance',
        beatsPerBar: 4,
        bars: 8,
        phraseBars: 2,
        tempos: [92, 112, 120, 130, 140],
        notes: [],
      ),
      audio,
      lookaheadSeconds: 30,
      loop: true,
    )..startAt(0);
    final choreography = routine();
    for (var tier = 0; tier < 2; tier++) {
      if (tier == 1) {
        music.stop();
        audio.nowSeconds = 0;
        music.startAt(0, tier: tier);
      }
      audio.nowSeconds = music.secondsAt(6.5);
      final pose = choreography.sample(
        beat: music.positionBeats,
        callStartBeat: 4,
      );
      expect(pose.noteIndex, 3);
      expect(pose.movePhase, DanceMovePhase.accent);
      music.pause();
      audio.nowSeconds += 20;
      final paused = choreography.sample(
        beat: music.positionBeats,
        callStartBeat: 4,
      );
      expect(paused.frameId, pose.frameId);
      expect(paused.rootOffsetX, pose.rootOffsetX);
    }
  });

  test(
    'early player taps prepare, late taps accent immediately, then recover',
    () {
      PlayerMovePose early(double beat) => playerMovePose(
        limb: Limb.leftFoot,
        acceptedBeat: 9.8,
        targetBeat: 10,
        beat: beat,
      );
      expect(early(9.7).phase, DanceMovePhase.idle);
      expect(early(9.8).phase, DanceMovePhase.anticipation);
      expect(early(10).frameId, 'left_foot');
      expect(early(10.3).phase, DanceMovePhase.followThrough);
      expect(early(10.55).phase, DanceMovePhase.settle);
      expect(early(10.7).phase, DanceMovePhase.idle);
      final late = playerMovePose(
        limb: Limb.rightHand,
        acceptedBeat: 10.2,
        targetBeat: 10,
        beat: 10.2,
      );
      expect(late.phase, DanceMovePhase.accent);
      expect(late.peakBeat, 10.2);
      expect(late.frameId, 'right_hand');
      expect(
        playerMovePose(
          limb: Limb.leftHand,
          acceptedBeat: 10,
          targetBeat: 10,
          beat: 10.5,
          nextRequiredBeat: 10.5,
        ).phase,
        DanceMovePhase.idle,
      );
    },
  );

  test('chart snapshots are immutable and malformed timing is rejected', () {
    final limbs = [Limb.leftHand];
    final offsets = [0.0];
    final choreography = ChallengerChoreography(limbs: limbs, offsets: offsets);
    limbs[0] = Limb.rightHand;
    offsets[0] = 1;
    expect(choreography.sample(beat: 0, callStartBeat: 0).frameId, 'left_hand');
    expect(
      () => ChallengerChoreography(limbs: [], offsets: []),
      throwsArgumentError,
    );
    expect(
      () => ChallengerChoreography(limbs: chart.limbs, offsets: [0]),
      throwsArgumentError,
    );
    expect(
      () => ChallengerChoreography(limbs: [Limb.leftHand], offsets: [8]),
      throwsArgumentError,
    );
    expect(
      () => choreography.sample(beat: double.nan, callStartBeat: 0),
      throwsArgumentError,
    );
    for (var i = 0; i < 1600; i++) {
      final pose = at(i / 100);
      expect(pose.floorYield, inInclusiveRange(0, 1));
      expect(pose.rootOffsetX.abs(), lessThanOrEqualTo(1.1));
      expect(challengerFrameIds, contains(pose.frameId));
    }
  });
}
