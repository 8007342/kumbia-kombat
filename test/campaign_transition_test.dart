import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/progression.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';
import 'package:kumbia_kombat/music/transition_conductor.dart';

class CampaignAudio implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  int silences = 0;
  final attacks = <double>[];
  @override
  void silence() => silences++;
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {
    expect(atSeconds, greaterThanOrEqualTo(nowSeconds - .002));
    expect(durationSeconds, greaterThan(0));
    attacks.add(atSeconds);
  }
}

MusicScore score(String id) => MusicScore.fromJson(
  jsonDecode(File('assets/music/scores/$id.json').readAsStringSync())
      as Map<String, dynamic>,
);

void advance(CampaignAudio audio, double target, void Function() update) {
  while (audio.nowSeconds < target - .000001) {
    audio.nowSeconds = math.min(target, audio.nowSeconds + .02);
    update();
  }
}

void clearFight(CampaignAudio audio, GardenSession session) {
  final music = session.transport;
  void update() {
    music.pump();
    session.advance();
  }

  for (
    var cycle = 0;
    cycle < 20 && session.phase != GardenPhase.cleared;
    cycle++
  ) {
    final start = session.chart.introBeats + cycle * session.chart.cycleBeats;
    for (var i = 0; i < session.activeLimbs.length; i++) {
      final when = music.secondsAt(
        start + session.chart.callBeats + session.chart.offsets[i],
      );
      advance(audio, when, update);
      expect(
        session.tap(session.activeLimbs[i]).note,
        isNotNull,
        reason:
            '${session.progress.definition.id} cycle $cycle note $i phase ${session.phase} beat ${music.positionBeats} now ${audio.nowSeconds} target $when transport ${music.state}',
      );
    }
    final end = music.secondsAt(start + session.chart.cycleBeats - .05);
    advance(audio, end, update);
  }
  expect(session.phase, GardenPhase.cleared);
  expect(
    session.pizazz,
    0,
    reason: 'Optional swipes are never needed to clear.',
  );
}

void main() {
  test(
    'actual garden offers reach four style steps across non-scoring calls',
    () {
      final audio = CampaignAudio();
      final music = MusicTransport(
        score('garden_mojo'),
        audio,
        loop: true,
        lookaheadSeconds: .3,
      );
      final session = GardenSession(music, audio)..start();
      void update() {
        music.pump();
        session.advance();
      }

      var ornaments = 0;
      for (var cycle = 0; cycle < 2; cycle++) {
        final start =
            session.chart.introBeats + cycle * session.chart.cycleBeats;
        advance(audio, music.secondsAt(start), update);
        for (var i = 0; i < session.activeLimbs.length; i++) {
          final when = music.secondsAt(
            start + session.chart.callBeats + session.activeOffsets[i],
          );
          advance(audio, when, update);
          final result = session.tap(session.activeLimbs[i]);
          expect(result.note, isNotNull);
          if (result.note!.flourishTo != null) {
            advance(audio, when + .1, update);
            expect(
              session.flourishGesture(
                result.note!.id,
                FlourishDirection.values[ornaments % 4],
              ),
              isTrue,
            );
            ornaments++;
          }
        }
        advance(
          audio,
          music.secondsAt(start + session.chart.cycleBeats - .05),
          update,
        );
      }
      expect(ornaments, 4);
      expect(session.styleCombo, 4);
      expect(session.pizazz, 400);
      expect(session.progress.tier, 2);
      expect(session.progress.cleared, isFalse);
    },
  );

  test(
    'real garden and bar charts clear with seamless success/bridge audio',
    () {
      final audio = CampaignAudio();
      final gardenMusic = MusicTransport(
        score('garden_mojo'),
        audio,
        loop: true,
        lookaheadSeconds: .3,
      );
      final garden = GardenSession(gardenMusic, audio)..start();
      clearFight(audio, garden);
      final gardenSeconds = garden.completedAtSeconds!;
      expect(gardenSeconds, inInclusiveRange(55, 75));
      final silenceBeforeBridge = audio.silences;
      final conductor = TransitionConductor(audio, lookaheadSeconds: .3);
      final handoff = conductor.handoff(
        source: gardenMusic,
        success: score('garden_mojo_success'),
        bridge: score('garden_to_bar'),
        nextScore: score('bar_swag'),
      );
      advance(audio, handoff.nextAtSeconds, conductor.pump);
      expect(audio.silences, silenceBeforeBridge);
      for (final boundary in [
        handoff.exitAtSeconds,
        handoff.bridgeAtSeconds,
        handoff.nextAtSeconds,
      ]) {
        expect(
          audio.attacks.any((at) => (at - boundary).abs() < .0001),
          isTrue,
        );
      }

      final bar = GardenSession(
        handoff.nextTransport,
        audio,
        definition: fights[1],
        chart: FightChart.bar,
      )..start(startTransport: false);
      expect(
        audio.silences,
        silenceBeforeBridge,
        reason: 'Joining does not reset the device queue.',
      );
      clearFight(audio, bar);
      expect(bar.passedPhrases, 10);
      final finish = TransitionConductor(audio, lookaheadSeconds: .3);
      final ending = finish.finish(
        source: bar.transport,
        success: score('bar_swag_success'),
      );
      advance(audio, ending.endAtSeconds + .01, finish.pump);
      expect(finish.completed, isTrue);
      expect(audio.silences, silenceBeforeBridge);
    },
  );
}
