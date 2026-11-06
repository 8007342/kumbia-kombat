import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/gesture_shapes.dart';
import 'package:kumbia_kombat/gameplay/party_autoplay.dart';
import 'package:kumbia_kombat/gameplay/progression.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
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

/// The lawn's offsets and its top tempo: the tightest room there is.
const _lawn = FightChart(
  limbs: [
    Limb.leftHand,
    Limb.rightHand,
    Limb.leftFoot,
    Limb.rightFoot,
    Limb.leftHand,
    Limb.rightHand,
    Limb.leftFoot,
    Limb.rightHand,
  ],
  offsets: [0, 1, 1.75, 3, 4, 5, 5.75, 6.75],
);

class _Run {
  _Run({double bpm = 160, FightChart chart = _lawn})
    : audio = _Audio() {
    transport = MusicTransport(
      MusicScore(
        id: 'test',
        beatsPerBar: 4,
        bars: 4,
        phraseBars: 1,
        tempos: List.filled(5, bpm),
        notes: const [],
      ),
      audio,
      loop: true,
    );
    session = GardenSession(transport, audio, chart: chart)..start();
  }
  final _Audio audio;
  late final MusicTransport transport;
  late final GardenSession session;

  void toSeconds(double target) {
    while (audio.nowSeconds + .02 < target) {
      audio.nowSeconds += .02;
      transport.pump();
      session.advance();
    }
    audio.nowSeconds = target;
    transport.pump();
    session.advance();
  }

  double secondsOf(double beat) => transport.secondsAt(beat);

  /// Plays one response from [start], skipping [drop]. Returns the last note hit.
  RhythmNote? respond(double start, {Set<int> drop = const {}, double lateBy = 0}) {
    RhythmNote? last;
    for (var i = 0; i < session.activeLimbs.length; i++) {
      if (drop.contains(i)) continue;
      toSeconds(secondsOf(start + session.activeOffsets[i]) + lateBy);
      last = session.tap(session.activeLimbs[i]).note ?? last;
    }
    return last;
  }
}

void main() {
  group('a move outlives the phrase', () {
    test('a late tap keeps its whole window across the rollover at 160 BPM', () {
      final run = _Run();
      final session = run.session;
      final note = run.respond(12, lateBy: .18)!;
      final tappedAt = run.audio.nowSeconds;
      // The phrase rolls over 1.25 beats after the note, 469 ms: before a late
      // tap's window is out. This used to be refused.
      run.toSeconds(tappedAt + .395);
      expect(session.positionBeats, greaterThan(20), reason: 'Rolled over.');
      expect(session.phase, GardenPhase.call);
      final move = session.optionalMove(
        note.id,
        GestureKind.spin,
        FlourishDirection.right,
      );
      expect(move, isNotNull);
      expect(session.pizazz, 100);
      expect(move!.limb, note.limb);
    });

    test('a move landing in the next phrase isn\'t counted for that phrase', () {
      final run = _Run();
      final session = run.session;
      final note = run.respond(12)!;
      run.toSeconds(run.audio.nowSeconds + .55);
      expect(session.phase, GardenPhase.call);
      expect(
        session.flourishGesture(note.id, FlourishDirection.up),
        isTrue,
      );
      // Play the next phrase with nothing added: it must report no gestures, and
      // so grade the same as a phrase that never had one.
      run.respond(28);
      expect(session.pizazz, 100);
    });

    test('the last note has beats, and they scale with the tempo', () {
      for (final bpm in [100.0, 160.0]) {
        final run = _Run(bpm: bpm);
        final session = run.session;
        final note = run.respond(12)!;
        final tappedAt = run.audio.nowSeconds;
        final ends = session.moveEndsAt(note.id)!;
        expect(ends - tappedAt, closeTo(lastNoteMoveBeats * 60 / bpm, .002));
        run.toSeconds(ends + (moveDeadlineGraceMs + 20) / 1000);
        expect(
          session.flourishGesture(note.id, FlourishDirection.up),
          isFalse,
          reason: '$bpm',
        );
        expect(session.pizazz, 0);
      }
    });

    test('a mid-phrase note keeps the flourish window', () {
      final run = _Run(
        bpm: 100,
        chart: const FightChart(limbs: [Limb.leftHand, Limb.rightFoot], offsets: [0, 4]),
      );
      final session = run.session;
      run.toSeconds(run.secondsOf(12));
      final note = session.tap(Limb.leftHand).note!;
      expect(
        session.moveEndsAt(note.id)! - run.audio.nowSeconds,
        closeTo(RhythmJudge.flourishWindowMs / 1000, .002),
      );
    });

    test('only an accepted tap opens a move, and only once', () {
      final run = _Run();
      final session = run.session;
      expect(
        session.flourishGesture('nothing', FlourishDirection.up),
        isFalse,
      );
      final note = run.respond(12)!;
      // At the very instant of the press, a stroke can't have happened yet.
      expect(session.flourishGesture(note.id, FlourishDirection.up), isFalse);
      run.toSeconds(run.audio.nowSeconds + .1);
      expect(session.flourishGesture(note.id, FlourishDirection.up), isTrue);
      expect(session.flourishGesture(note.id, FlourishDirection.down), isFalse);
      expect(session.pizazz, 100);
    });
  });

  group('credit', () {
    test('a recovering player earns the retry, and a pause replay doesn\'t', () {
      final run = _Run(bpm: 100);
      final session = run.session;
      // Miss enough to fail: the same phrase comes round again, same note ids.
      final failed = run.respond(12, drop: {0, 1, 2})!;
      run.toSeconds(run.audio.nowSeconds + .2);
      expect(session.flourishGesture(failed.id, FlourishDirection.up), isTrue);
      expect(session.pizazz, 100);

      run.toSeconds(run.secondsOf(27));
      expect(session.lastOutcome, ChallengeOutcome.retry);
      final retried = run.respond(28)!;
      expect(retried.id, failed.id, reason: 'The very same phrase and note.');
      run.toSeconds(run.audio.nowSeconds + .2);
      expect(session.flourishGesture(retried.id, FlourishDirection.up), isTrue);
      expect(session.pizazz, 200, reason: 'He danced it again: that counts.');
    });

    test('a pause replays the performance without paying twice', () {
      final run = _Run(bpm: 100);
      final session = run.session;
      final note = run.respond(12)!;
      run.toSeconds(run.audio.nowSeconds + .2);
      expect(session.flourishGesture(note.id, FlourishDirection.up), isTrue);
      expect(session.pizazz, 100);
      session.pause();
      expect(session.lastOptionalMove, isNull);
      expect(
        session.moveEndsAt(note.id),
        isNull,
        reason: 'A pause closes what was open.',
      );
    });
  });

  group('ignoring optional moves costs nothing', () {
    /// The same taps with moves ignored, performed, or fumbled must leave the
    /// required game identical: hits, combo, grades, tier, tempo, results, time.
    List<Object?> play(String how) {
      final run = _Run(bpm: 120);
      final session = run.session;
      final results = <Object?>[];
      final random = math.Random(5);
      for (var phrase = 0; phrase < 12; phrase++) {
        final start = 12 + phrase * 16.0;
        // Every third phrase drops enough to fail.
        final drop = phrase % 3 == 2 ? {0, 1, 2} : const <int>{};
        for (var i = 0; i < session.activeLimbs.length; i++) {
          if (drop.contains(i)) continue;
          run.toSeconds(run.secondsOf(start + session.activeOffsets[i]) + .03);
          final result = session.tap(session.activeLimbs[i]);
          results.add('${result.grade}:${result.deltaMs}:${session.combo}');
          final note = result.note;
          if (note == null || note.offer == null) continue;
          final after = run.audio.nowSeconds + .05 + random.nextDouble() * .1;
          if (how == 'performed') {
            if (i < session.activeLimbs.length - 1) continue;
            run.toSeconds(after);
            session.optionalMove(note.id, note.offer!, FlourishDirection.up);
          } else if (how == 'too late') {
            // A real attempt that only comes after its time ran out.
            run.toSeconds(after);
            session.optionalMove('${note.id}?', GestureKind.wave, FlourishDirection.left);
          }
        }
        run.toSeconds(run.secondsOf(start + 7.9));
        results.add([
          session.phase,
          session.progress.tier,
          session.progress.consecutiveFailures,
          session.passedPhrases,
          session.lastOutcome,
          session.perfects,
          run.transport.currentTier,
          run.audio.nowSeconds,
          session.requiredHits,
        ].join('|'));
      }
      return results;
    }

    test('moves ignored, performed or fumbled change nothing required', () {
      final ignored = play('ignored');
      expect(play('performed'), ignored);
      expect(play('too late'), ignored);
    });
  });

  group('what a note offers', () {
    test('sideways first, then the limb\'s own move on the last note', () {
      GestureKind offer(Limb limb, int tier, {bool last = true}) =>
          gestureOffer(limb: limb, lastNote: last, tier: tier);
      expect(offer(Limb.leftHand, 0), GestureKind.spin);
      expect(offer(Limb.leftFoot, 0), GestureKind.spin);
      expect(offer(Limb.leftHand, 1), GestureKind.wave);
      expect(offer(Limb.rightHand, 2), GestureKind.wave);
      expect(offer(Limb.leftFoot, 1), GestureKind.stomp);
      expect(offer(Limb.rightFoot, 4), GestureKind.stomp);
      expect(offer(Limb.rightHand, 3), GestureKind.circle);
      // Mid-phrase there's no room for more than a sideways stroke.
      expect(offer(Limb.leftHand, 4, last: false), GestureKind.spin);
    });

    test('a cue and its note agree, and notes without room offer nothing', () {
      final run = _Run();
      run.toSeconds(run.secondsOf(12 + 6.4));
      final cue = run.session.visibleCues.lastWhere((c) => !c.demo);
      expect(cue.offer, isNotNull);
      final note = run.session.tap(cue.limb);
      expect(note.note?.offer, cue.offer);
      // The lawn's mid-phrase notes are too tightly packed at this speed.
      final inside = run.session.activeLimbs.length - 2;
      expect(
        run.session.visibleCues.where(
          (c) => !c.demo && c.beat == 12 + run.session.activeOffsets[inside],
        ).every((c) => c.offer == null),
        isTrue,
      );
    });
  });

  group('the hook', () {
    test('says which limb and move landed, for anything that reacts', () {
      final run = _Run();
      final session = run.session;
      expect(session.lastOptionalMove, isNull);
      final note = run.respond(12)!;
      run.toSeconds(run.audio.nowSeconds + .1);
      session.optionalMove(note.id, GestureKind.spin, FlourishDirection.left);
      final move = session.lastOptionalMove!;
      expect(move.limb, note.limb);
      expect(move.kind, GestureKind.spin);
      expect(move.offered, note.offer);
      expect(move.direction, FlourishDirection.left);
      expect(move.credited, isTrue);
      expect(move.beat, closeTo(session.positionBeats, .001));
    });
  });

  group('AutoPlay', () {
    test('cycles off, with errors, flawless, and back to off', () {
      final auto = PartyAutoplay();
      expect(auto.mode, AutoplayMode.off);
      auto.mode = auto.nextMode;
      expect(auto.mode, AutoplayMode.withErrors);
      expect(auto.enabled, isTrue);
      expect(auto.flawless, isFalse);
      auto.mode = auto.nextMode;
      expect(auto.mode, AutoplayMode.flawless);
      expect(auto.flawless, isTrue);
      auto.mode = auto.nextMode;
      expect(auto.mode, AutoplayMode.off);
      expect(auto.enabled, isFalse);
    });

    test('the flawless URL makes flawless the first press', () {
      final auto = PartyAutoplay(startFlawless: true);
      auto.mode = auto.nextMode;
      expect(auto.mode, AutoplayMode.flawless);
      auto.mode = auto.nextMode;
      expect(auto.mode, AutoplayMode.withErrors);
      auto.mode = auto.nextMode;
      expect(auto.mode, AutoplayMode.off);
    });

    test('it performs each offered move through the real recogniser', () {
      final run = _Run(bpm: 120);
      final auto = PartyAutoplay(flawless: true)..enabled = true;
      final seen = <OptionalMove>[];
      while (run.session.phase != GardenPhase.cleared &&
          run.audio.nowSeconds < 300) {
        run.audio.nowSeconds += .02;
        run.transport.pump();
        run.session.advance();
        auto.pump(run.session, onMove: seen.add);
      }
      expect(run.session.phase, GardenPhase.cleared);
      expect(seen, isNotEmpty);
      for (final move in seen) {
        expect(move.kind, move.offered, reason: '${move.noteId} ${move.limb}');
      }
      final kinds = seen.map((m) => m.kind).toSet();
      expect(kinds, contains(GestureKind.spin));
      expect(kinds.length, greaterThan(1), reason: 'More than one shape shown.');
    });

    test('a stroke in the air stops with a pause, changing nothing', () {
      final run = _Run(bpm: 120);
      final auto = PartyAutoplay(flawless: true)..enabled = true;
      while (run.session.phase != GardenPhase.response) {
        run.audio.nowSeconds += .02;
        run.transport.pump();
        run.session.advance();
        auto.pump(run.session);
      }
      final before = run.session.pizazz;
      auto.suspend();
      run.session.pause();
      expect(run.session.pizazz, before);
    });
  });
}
