import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/party_autoplay.dart';
import 'package:kumbia_kombat/gameplay/progression.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transition_conductor.dart';
import 'package:kumbia_kombat/music/transport.dart';

class DemoAudio implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {}
  @override
  void silence() {}
}

MusicScore loadScore(String id) => MusicScore.fromJson(
  jsonDecode(File('assets/music/scores/$id.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  test(
    'imperfect demo clears both real rooms through genuine input and handoff',
    () {
      final audio = DemoAudio();
      final demo = PartyAutoplay()..enabled = true;
      final gardenMusic = MusicTransport(
        loadScore('garden_mojo'),
        audio,
        loop: true,
        lookaheadSeconds: .3,
      );
      var session = GardenSession(gardenMusic, audio)..start();
      var taps = 0;
      var goods = 0;
      var perfects = 0;
      var ornaments = 0;
      void perform() => demo.pump(
        session,
        onTap: (limb) {
          final result = session.tap(limb);
          taps++;
          if (result.grade == TapGrade.good) goods++;
          if (result.grade == TapGrade.perfect) perfects++;
          return result;
        },
        onFlourish: (_) => ornaments++,
      );
      void clearRoom() {
        final deadline = audio.nowSeconds + 260;
        var failures = 0;
        var decreases = 0;
        var previousStumble = session.lastStumbleBeat;
        var previousInterest = 0.0;
        while (session.phase != GardenPhase.cleared &&
            audio.nowSeconds < deadline) {
          audio.nowSeconds += .02;
          session.transport.pump();
          session.advance();
          perform();
          final afterFirstPump = taps;
          perform();
          expect(
            taps,
            afterFirstPump,
            reason: 'Same-frame pumps never double tap.',
          );
          if (session.lastStumbleBeat != previousStumble) {
            failures++;
            previousStumble = session.lastStumbleBeat;
          }
          final interest = session.crowd.guests.fold(
            0.0,
            (sum, guest) => sum + guest.interest,
          );
          if (interest < previousInterest) decreases++;
          previousInterest = interest;
        }
        expect(session.phase, GardenPhase.cleared);
        expect(failures, 2);
        // The two failures, plus slow cooling after any dropped note.
        expect(decreases, greaterThanOrEqualTo(2));
        expect(session.pizazz, greaterThan(0));
        expect(session.crowd.peakSupported, isTrue);
      }

      clearRoom();
      final conductor = TransitionConductor(audio, lookaheadSeconds: .3);
      final handoff = conductor.handoff(
        source: gardenMusic,
        success: loadScore('garden_mojo_success'),
        bridge: loadScore('garden_to_bar'),
        nextScore: loadScore('bar_swag'),
      );
      final beforeBridge = taps;
      while (audio.nowSeconds < handoff.nextAtSeconds) {
        audio.nowSeconds += .02;
        conductor.pump();
        perform();
      }
      expect(taps, beforeBridge);
      session = GardenSession(
        handoff.nextTransport,
        audio,
        definition: fights[1],
        chart: FightChart.bar,
      )..start(startTransport: false);
      clearRoom();
      expect(goods, greaterThan(0));
      expect(perfects, greaterThan(goods));
      expect(ornaments, greaterThan(2));
    },
  );

  test(
    'off cancels a pending flick and pause reconstructs the replay safely',
    () {
      final audio = DemoAudio();
      final music = MusicTransport(
        loadScore('garden_mojo'),
        audio,
        loop: true,
        lookaheadSeconds: .3,
      );
      final session = GardenSession(music, audio)..start();
      final demo = PartyAutoplay()..enabled = true;
      var taps = 0;
      var eligible = false;
      void pump() => demo.pump(
        session,
        onTap: (limb) {
          taps++;
          final result = session.tap(limb);
          if (result.note?.flourishTo != null) eligible = true;
          return result;
        },
      );
      void tick() {
        audio.nowSeconds += .02;
        music.pump();
        session.advance();
        pump();
      }

      while (!eligible && audio.nowSeconds < 20) {
        tick();
      }
      expect(eligible, isTrue);
      demo.enabled = false;
      final beforeOff = taps;
      for (var i = 0; i < 15; i++) {
        tick();
      }
      expect(taps, beforeOff);
      expect(session.pizazz, 0);
      demo.enabled = true;
      pump();
      expect(
        session.pizazz,
        0,
        reason: 'Cancelled ornaments are not resurrected.',
      );
      session.pause();
      pump();
      final beforePause = taps;
      for (var i = 0; i < 100; i++) {
        tick();
      }
      expect(taps, beforePause);
      session.resume();
      while (music.countingIn) {
        pump();
        expect(taps, beforePause);
        tick();
      }
      final deadline = audio.nowSeconds + 16;
      while (taps == beforePause && audio.nowSeconds < deadline) {
        tick();
      }
      expect(
        taps,
        greaterThan(beforePause),
        reason: 'Replay has a new audio-window identity.',
      );
      demo.enabled = false;
      final afterReplay = taps;
      for (var i = 0; i < 100; i++) {
        tick();
      }
      expect(taps, afterReplay);
    },
  );
}
