import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transition_conductor.dart';
import 'package:kumbia_kombat/music/transport.dart';

class GraceAudio implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  final attacks = <double>[];
  @override
  void silence() {}
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {
    expect(atSeconds, greaterThanOrEqualTo(nowSeconds));
    attacks.add(atSeconds);
  }
}

MusicScore loadScore(String id) => MusicScore.fromJson(
  jsonDecode(File('assets/music/scores/$id.json').readAsStringSync())
      as Map<String, dynamic>,
);

MusicTransport playing(GraceAudio audio, {double? grace}) {
  final transport = grace == null
      ? MusicTransport(
          loadScore('garden_mojo'),
          audio,
          loop: true,
          lookaheadSeconds: .3,
        )
      : MusicTransport(
          loadScore('garden_mojo'),
          audio,
          loop: true,
          lookaheadSeconds: .3,
          starvationGraceSeconds: grace,
        );
  transport.start();
  audio.nowSeconds = .2;
  transport.pump();
  return transport;
}

void main() {
  test('a stall inside the grace keeps playing and drops the missed notes', () {
    final audio = GraceAudio();
    final transport = playing(audio, grace: 1.5);
    final before = transport.scheduledThroughSeconds;

    audio.nowSeconds = before + 1.2;
    audio.attacks.clear();
    transport.pump();

    expect(transport.state, TransportState.playing);
    expect(transport.droppedNotes, greaterThan(0));
    expect(audio.attacks, everyElement(greaterThanOrEqualTo(audio.nowSeconds)));
    expect(transport.scheduledThroughSeconds, audio.nowSeconds + .3);
  });

  test('a stall past the grace still pauses at the last safe beat', () {
    final audio = GraceAudio();
    final transport = playing(audio, grace: 1.5);
    final safeBeat = transport.beatAt(transport.scheduledThroughSeconds);

    audio.nowSeconds = transport.scheduledThroughSeconds + 1.6;
    transport.pump();

    expect(transport.state, TransportState.paused);
    expect(transport.positionBeats, closeTo(safeBeat, 1e-9));
  });

  test('the default grace keeps the strict 25 ms behaviour', () {
    final audio = GraceAudio();
    final transport = playing(audio);

    audio.nowSeconds = transport.scheduledThroughSeconds + .03;
    transport.pump();

    expect(transport.state, TransportState.paused);
  });

  test('the conductor applies its grace to the transports it starts', () {
    final audio = GraceAudio();
    final source = playing(audio, grace: 1.5);
    final conductor = TransitionConductor(
      audio,
      lookaheadSeconds: .3,
      starvationGraceSeconds: 1.5,
    );
    final finish = conductor.finish(
      source: source,
      success: loadScore('garden_mojo_success'),
    );
    expect(finish.success.starvationGraceSeconds, 1.5);

    audio.nowSeconds = source.scheduledThroughSeconds + 1.2;
    conductor.pump();
    expect(conductor.isPaused, isFalse);

    audio.nowSeconds = source.scheduledThroughSeconds + 1.6;
    conductor.pump();
    expect(conductor.isPaused, isTrue);
  });
}
