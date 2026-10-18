import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/progression.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

class FakeAudio implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  int silences = 0;
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {}
  @override
  void silence() {
    silences++;
  }
}

void main() {
  late FakeAudio audio;
  late MusicTransport transport;
  late GardenSession garden;
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

  void playResponse(double start) {
    final limbs = garden.chart.limbs;
    final offsets = garden.chart.offsets;
    for (var i = 0; i < limbs.length; i++) {
      at(start + offsets[i]);
      expect(garden.tap(limbs[i]).grade, TapGrade.perfect);
    }
    at(start + (garden.progress.cleared ? 7.5 : 6.9));
    if (garden.progress.cleared && garden.phase != GardenPhase.cleared) {
      at(start + 7.5);
    }
  }

  setUp(() {
    audio = FakeAudio();
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
    garden = GardenSession(transport, audio)..start();
  });

  test(
    'intro and call are non-scoring; cues preview and full fight clears',
    () {
      at(3);
      expect(garden.phase, GardenPhase.intro);
      expect(garden.tap(Limb.leftHand).note, isNull);
      at(10);
      expect(garden.phase, GardenPhase.call);
      expect(
        garden.visibleCues.any((cue) => !cue.demo && cue.beat == 12),
        isTrue,
      );
      for (var cycle = 0; cycle < 6; cycle++) {
        playResponse(12 + cycle * 16);
      }
      expect(garden.phase, GardenPhase.cleared);
      expect(garden.progress.fullTierSuccesses, 2);
      expect(garden.passedPhrases, 6);
      expect(garden.completedAtSeconds, isNotNull);
      expect(transport.state, TransportState.playing);
    },
  );

  test('missing phrases retries then entrance reset without game over', () {
    for (var cycle = 0; cycle < 5; cycle++) {
      at(18.9 + cycle * 16);
    }
    expect(garden.progress.entranceResets, 1);
    expect(garden.progress.tier, 0);
    expect(garden.running, isTrue);
    expect(garden.phase, GardenPhase.response);
  });

  test('joining bridge transport preserves anchor and queued audio', () {
    transport.stop();
    transport.start(leadSeconds: 3);
    final anchor = transport.secondsAt(0);
    final silences = audio.silences;
    garden = GardenSession(transport, audio)..start(startTransport: false);
    expect(transport.secondsAt(0), anchor);
    expect(audio.silences, silences);
    expect(garden.phase, GardenPhase.intro);
    at(12);
    expect(garden.tap(Limb.leftHand).grade, TapGrade.perfect);
    transport.stop();
    expect(
      () => GardenSession(transport, audio).start(startTransport: false),
      throwsStateError,
    );
  });

  test('resume count-in is one tempo-matched bar and hides cues/input', () {
    transport.stop();
    transport = MusicTransport(
      MusicScore(
        id: 'slow',
        beatsPerBar: 4,
        bars: 4,
        phraseBars: 1,
        tempos: [90, 90, 90, 90, 90],
        notes: [],
      ),
      audio,
      loop: true,
    );
    garden = GardenSession(transport, audio)..start();
    at(8);
    garden.pause();
    garden.resume();
    expect(transport.secondsAt(4) - audio.nowSeconds, closeTo(8 / 3, 1e-9));
    expect(transport.countingIn, isTrue);
    expect(garden.visibleCues, isEmpty);
    expect(garden.tap(Limb.leftHand).note, isNull);
    at(12);
    expect(garden.tap(Limb.leftHand).grade, TapGrade.perfect);
  });

  test(
    'first response accepts full early window but demo taps do not score',
    () {
      at(4);
      expect(garden.tap(Limb.leftHand).note, isNull);
      at(11.638); // 181 ms early at 120 BPM.
      expect(garden.tap(Limb.leftHand).note, isNull);
      at(11.64); // Exactly 180 ms early.
      expect(garden.phase, GardenPhase.call);
      expect(garden.tap(Limb.leftHand).grade, TapGrade.good);
      for (var i = 1; i < garden.chart.limbs.length; i++) {
        at(12 + garden.chart.offsets[i]);
        garden.tap(garden.chart.limbs[i]);
      }
      at(18.9);
      expect(garden.progress.tier, 1);
      expect(garden.passedPhrases, 1);
    },
  );

  test('full-tier sustain waits for audible tier four phrase', () {
    transport.stop();
    transport = MusicTransport(
      MusicScore(
        id: 'garden',
        beatsPerBar: 4,
        bars: 4,
        phraseBars: 4,
        tempos: [120, 120, 120, 120, 120],
        notes: [],
      ),
      audio,
      loop: true,
    );
    garden = GardenSession(transport, audio)..start();
    for (var cycle = 0; cycle < 4; cycle++) {
      playResponse(12 + cycle * 16);
    }
    expect(garden.progress.tier, 4);
    playResponse(76);
    expect(garden.progress.fullTierSuccesses, 0);
    expect(garden.phase, GardenPhase.response);
    playResponse(92);
    expect(garden.progress.fullTierSuccesses, 1);
    playResponse(108);
    expect(garden.phase, GardenPhase.cleared);
  });

  test('bar chart teaches feet and clears after ten passing responses', () {
    transport.stop();
    garden = GardenSession(
      transport,
      audio,
      definition: fights[1],
      chart: FightChart.bar,
    )..start();
    for (var cycle = 0; cycle < 10; cycle++) {
      playResponse(12 + cycle * 16);
    }
    expect(garden.phase, GardenPhase.cleared);
    expect(garden.progress.definition.metric, 'Swag');
    expect(garden.passedPhrases, 10);
  });

  test('pause replays phrase and credited flourish cannot be farmed', () {
    String playUntilFlourish() {
      String id = '';
      for (var i = 0; i < garden.chart.limbs.length; i++) {
        at(12 + garden.chart.offsets[i]);
        id = garden.tap(garden.chart.limbs[i]).note!.id;
      }
      at(18.6);
      expect(garden.flourish(id, Limb.rightFoot), isTrue);
      return id;
    }

    final firstId = playUntilFlourish();
    expect(garden.pizazz, 100);
    expect(garden.perfects, 8);
    garden.pause();
    expect(garden.phase, GardenPhase.paused);
    expect(transport.positionBeats, 4);
    garden.resume();
    expect(playUntilFlourish(), firstId);
    expect(garden.pizazz, 100);
    expect(garden.perfects, 8);
  });

  test(
    'final swipe can finish after approval without extending result time',
    () {
      for (var cycle = 0; cycle < 5; cycle++) {
        playResponse(12 + cycle * 16);
      }
      const start = 92.0;
      String lastId = '';
      for (var i = 0; i < garden.chart.limbs.length; i++) {
        at(start + garden.chart.offsets[i]);
        lastId = garden.tap(garden.chart.limbs[i]).note!.id;
      }
      at(start + 6.9);
      final approvalAt = garden.completedAtSeconds;
      expect(approvalAt, isNotNull);
      expect(garden.phase, GardenPhase.response);
      expect(garden.tap(Limb.leftHand).note, isNull);
      at(start + 7); // 250 ms after the final accepted press.
      expect(garden.flourish(lastId, Limb.rightFoot), isTrue);
      expect(garden.pizazz, 100);
      expect(garden.completedAtSeconds, approvalAt);
      at(start + 7.5);
      expect(garden.phase, GardenPhase.cleared);
      expect(garden.completedAtSeconds, approvalAt);
      expect(transport.state, TransportState.playing);
    },
  );
}
