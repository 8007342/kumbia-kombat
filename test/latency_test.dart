import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/music/game_audio_contract.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

class _Audio implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {}
  @override
  void silence() {}
}

void main() {
  group('the latency to compensate', () {
    test('output latency, with the base latency it sits on', () {
      expect(chooseOutputLatency(output: .12, base: .01), closeTo(.13, 1e-9));
      expect(chooseOutputLatency(output: .12), closeTo(.12, 1e-9));
    });
    test('base latency alone when that is all a browser says', () {
      expect(chooseOutputLatency(base: .02), closeTo(.02, 1e-9));
      // Chrome reports 0 before the first sound: that is no report.
      expect(chooseOutputLatency(output: 0, base: .02), closeTo(.02, 1e-9));
    });
    test('a sane default when nothing is reported', () {
      expect(chooseOutputLatency(), defaultOutputLatencySeconds);
      expect(
        chooseOutputLatency(output: double.nan, base: -1),
        defaultOutputLatencySeconds,
      );
    });
    test('the override wins, zero included, and nothing goes past half a second',
        () {
      expect(chooseOutputLatency(output: .12, override: .2), .2);
      expect(chooseOutputLatency(output: .12, override: 0), 0);
      expect(chooseOutputLatency(output: 3), .5);
      expect(chooseOutputLatency(override: 9), .5);
    });
  });

  group('a session on a late phone', () {
    late _Audio audio;
    late MusicTransport transport;
    late GardenSession garden;
    const latency = .15;

    // To the audio clock, in beats at 120 BPM.
    void at(double beat) {
      final target = transport.secondsAt(beat);
      while (audio.nowSeconds + .02 < target) {
        audio.nowSeconds += .02;
        transport.pump();
        garden.advance();
      }
      audio.nowSeconds = target;
      transport.pump();
      garden.advance();
    }

    // What the player hears at [beat] reaches the speaker this much later.
    double heard(double beat) => beat + latency * 2;

    setUp(() {
      audio = _Audio();
      transport = MusicTransport(
        MusicScore(
          id: 'garden',
          beatsPerBar: 4,
          bars: 4,
          phraseBars: 1,
          tempos: [120, 120, 120, 120, 120],
          notes: [],
        ),
        audio,
        loop: true,
      );
      garden = GardenSession(transport, audio)
        ..outputLatencySeconds = latency
        ..start();
    });

    test('a tap on the beat as heard is perfect', () {
      for (var i = 0; i < garden.activeLimbs.length; i++) {
        at(heard(12 + garden.activeOffsets[i]));
        final result = garden.tap(garden.activeLimbs[i]);
        expect(result.grade, TapGrade.perfect, reason: 'note $i');
        expect(result.deltaMs, 0);
      }
      at(heard(18.5) + RhythmJudge.lateWindowMs / 500 + .02);
      expect(garden.passedPhrases, 1);
      expect(garden.perfects, 8);
    });

    test('a tap on the beat of the audio clock is early by the latency', () {
      at(12);
      final result = garden.tap(garden.activeLimbs.first);
      expect(result.deltaMs, -150);
      expect(result.timing, TapTiming.early);
    });

    test('a response cue lands when its beat is heard', () {
      at(heard(12));
      final cue = garden.visibleCues.firstWhere((c) => !c.demo && c.beat == 12);
      expect(cue.progress, closeTo(1, 1e-6));
    });

    test('the early grace before the first response still counts', () {
      // The full early window before the first note, as heard: still the call.
      at(heard(12) - RhythmJudge.earlyWindowMs / 500);
      expect(garden.phase, GardenPhase.call);
      expect(garden.tap(garden.activeLimbs.first).grade, TapGrade.good);
    });

    test('the touch delay is judged, not drawn', () {
      garden.inputLatencySeconds = .04;
      at(heard(12) + .04 * 2);
      final cue = garden.visibleCues.firstWhere((c) => !c.demo && c.beat == 12);
      expect(cue.progress, closeTo(1, 1e-6), reason: 'drawn to the sound');
      final result = garden.tap(garden.activeLimbs.first);
      expect(result.deltaMs, 0);
      expect(result.grade, TapGrade.perfect);
    });

    test('a tap too early for the grace is out of turn and costs nothing', () {
      at(heard(12) - (RhythmJudge.earlyWindowMs + 1) / 500);
      expect(garden.tap(garden.activeLimbs.first).note, isNull);
      expect(garden.lastTapOutOfTurn, isTrue);
      expect(garden.combo, 0);
      expect(garden.lastGrade, isNull, reason: 'an ignored tap is no grade');
      for (var i = 0; i < garden.activeLimbs.length; i++) {
        at(heard(12 + garden.activeOffsets[i]));
        expect(garden.tap(garden.activeLimbs[i]).grade, TapGrade.perfect);
      }
      at(heard(18.5) + RhythmJudge.lateWindowMs / 500 + .02);
      expect(garden.passedPhrases, 1);
      expect(garden.combo, 8);
    });

    test('latency never pushes the decision past the phrase end margin', () {
      garden.outputLatencySeconds = GardenSession.maxOutputLatencySeconds;
      for (var i = 0; i < garden.activeLimbs.length; i++) {
        at(12 + garden.activeOffsets[i] + 1);
        garden.tap(garden.activeLimbs[i]);
      }
      // The response ends at beat 20; the chart's margin is 100 ms, 0.2 beats.
      at(20 - .2 - .01);
      expect(garden.passedPhrases, 0);
      at(20 - .2 + .01);
      expect(garden.lastOutcome, isNotNull);
    });
  });
}
