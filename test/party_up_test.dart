import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/crowd_interest.dart';
import 'package:kumbia_kombat/gameplay/ensemble_sprites.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_up.dart';
import 'package:kumbia_kombat/gameplay/progression.dart';
import 'package:kumbia_kombat/gameplay/room_layers.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

import 'support/recording_canvas.dart';

class _Audio implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  @override
  void silence() {}
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {}
}

/// Climbs one tier every [every] beats from beat 0, sampling at a fixed step.
PartyUp _climbed({
  double to = 400,
  double every = 16,
  double step = 1 / 3,
  PartyUp? into,
}) {
  final up = into ?? PartyUp();
  for (var beat = 0.0; beat <= to; beat += step) {
    up.follow(beat, math.min(4, (beat / every).floor()));
  }
  return up;
}

RoomLayerProp _layer(
  PartyLifeKind kind, {
  RoomLayerMotion motion = RoomLayerMotion.sway,
  double period = 2,
}) => RoomLayerProp(
  id: 'p',
  atlas: 'a.png',
  atlasY: 0,
  left: 0,
  top: 0,
  width: 10,
  height: 10,
  frames: 7,
  motion: motion,
  periodBeats: period,
  instance: 0,
  kind: kind,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('in the real scene, with no taps at all', () {
    /// Runs [level] with its music climbing, nobody playing. Returns what the
    /// room draws at the bottom and top of the ladder, and the session.
    Future<(List<String>, List<String>, GardenSession)> climb(
      String id,
    ) async {
      final levels = await LevelRegistry.loadShipping();
      final level = levels.byId(id);
      final scene = GardenSceneGame(firstLevel: () async => level);
      scene.onGameResize(Vector2(390, 844));
      await scene.onLoad();
      final audio = _Audio();
      final music = MusicTransport(
        MusicScore.fromJson(
          jsonDecode(
                File(
                  'assets/music/scores/${level.music.score}.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>,
        ),
        audio,
        loop: true,
        lookaheadSeconds: .3,
      );
      final session = level.newSession(music, audio);
      scene.session = session;
      session.start();
      void to(double beat) {
        while (audio.nowSeconds < music.secondsAt(beat) - 1e-6) {
          audio.nowSeconds += .05;
          music.pump();
          scene.update(.05);
          scene.render(RecordingCanvas());
        }
      }

      List<String> draw() {
        final canvas = RecordingCanvas();
        scene.render(canvas);
        return canvas.calls;
      }

      to(8);
      final low = draw();
      var beat = 8.0;
      for (var tier = 1; tier <= 4; tier++) {
        music.requestTier(tier);
        beat += 48;
        to(beat);
      }
      to(beat + 48);
      expect(session.crowd.partySwing(beat + 48), 0, reason: 'nobody played');
      return (low, draw(), session);
    }

    double radius(String call) =>
        double.parse(call.split(') ').last.split(' ').first);

    for (final id in ['garden', 'pool-garden', 'bar']) {
      test('$id: the lamps grow and the room warms', () async {
        final (low, high, _) = await climb(id);
        final lowLamps = low.where((c) => c.startsWith('drawCircle '));
        final highLamps = high.where((c) => c.startsWith('drawCircle '));
        expect(lowLamps.length, highLamps.length);
        expect(lowLamps.map(radius), everyElement(2));
        expect(highLamps.map(radius), everyElement(12));
        // The warmth is one more wash, before the people.
        final washes = high.where((c) => c.startsWith('drawRect ')).length;
        expect(washes, low.where((c) => c.startsWith('drawRect ')).length + 1);
      });
    }

    test('the climb costs the session nothing: art only reads', () async {
      final (_, _, session) = await climb('bar');
      expect(session.perfects, 0);
      expect(session.progress.tier, 0, reason: 'only the music was moved');
      expect(session.combo, 0);
    });
  });

  group('the room wakes with the tier', () {
    test('it starts still, and every kind is awake at the top tier', () {
      final fresh = PartyUp()..follow(0, 0);
      for (final kind in PartyLifeKind.values) {
        expect(fresh.life(kind, 500), 0, reason: kind.name);
        expect(_climbed().life(kind, 400), 1, reason: kind.name);
      }
    });

    test('lights wake first, then what moves in air, then flames and staff', () {
      final up = PartyUp();
      for (var beat = 0.0; beat <= 100; beat += .5) {
        up.follow(beat, 1);
      }
      expect(up.life(PartyLifeKind.light, 100), greaterThan(0));
      expect(up.life(PartyLifeKind.plant, 100), 0);
      for (var beat = 100.0; beat <= 200; beat += .5) {
        up.follow(beat, 2);
      }
      expect(up.life(PartyLifeKind.plant, 200), greaterThan(0));
      expect(up.life(PartyLifeKind.umbrella, 200), greaterThan(0));
      expect(up.life(PartyLifeKind.hanging, 200), greaterThan(0));
      expect(up.life(PartyLifeKind.flame, 200), 0);
      expect(up.life(PartyLifeKind.staff, 200), 0);
      for (var beat = 200.0; beat <= 300; beat += .5) {
        up.follow(beat, 3);
      }
      expect(up.life(PartyLifeKind.flame, 300), greaterThan(0));
      expect(up.life(PartyLifeKind.staff, 300), greaterThan(0));
    });

    test('an entrance has no speed at either end and never jumps', () {
      final up = PartyUp()..follow(0, 1);
      double at(double beat) => up.wake(beat, last: 1);
      expect(at(.05), closeTo(0, .0001), reason: 'starts from a standstill');
      expect(1 - at(23.95), closeTo(0, .0001), reason: 'arrives at a standstill');
      for (var beat = 0.0; beat < 24; beat += .05) {
        expect(at(beat + .05) - at(beat), lessThan(.01), reason: 'at $beat');
        expect(at(beat + .05), greaterThanOrEqualTo(at(beat)));
      }
    });

    test('overlapping entrances keep their speed continuous', () {
      final up = PartyUp();
      for (var beat = 0.0; beat <= 16; beat += .25) {
        up.follow(beat, 1);
      }
      up.follow(16, 2); // The first step is still arriving.
      double speed(double beat) => up.wake(beat) - up.wake(beat - .01);
      expect((speed(16.01) - speed(16)).abs(), lessThan(.0001));
    });

    test('frozen on pause: the same beat gives the same room', () {
      final up = _climbed(to: 30);
      final before = up.wake(30);
      for (var i = 0; i < 100; i++) {
        up.follow(30, up.tier);
      }
      expect(up.wake(30), before);
    });

    test('the same room at any frame rate, to within a frame', () {
      final fast = _climbed(to: 60, step: 1 / 60);
      final slow = _climbed(to: 60, step: 1 / 3);
      for (final kind in PartyLifeKind.values) {
        expect(
          fast.life(kind, 60),
          closeTo(slow.life(kind, 60), .03),
          reason: kind.name,
        );
      }
    });

    test('it follows the tier, not the tempo: the same beats, any BPM', () {
      // Nothing here takes a tempo, so the lawn's 144, 160, 136 order can't
      // lower the room when the BPM falls: beats and tier numbers are all it sees.
      final up = PartyUp();
      var last = 0.0;
      const owners = [144, 160, 136];
      expect(owners.last, lessThan(owners.first));
      for (var beat = 0.0; beat <= 96; beat += .25) {
        up.follow(beat, (beat / 32).floor().clamp(0, 2));
        final now = up.wake(beat);
        expect(now, greaterThanOrEqualTo(last), reason: 'at $beat');
        last = now;
      }
    });

    test('a failed phrase does not deflate the room: it holds, then fades', () {
      final up = _climbed(to: 200);
      final top = up.wake(200, first: 4, last: 4);
      expect(top, 1);
      up.follow(200, 3);
      up.follow(220, 3);
      expect(up.wake(220, first: 4, last: 4), 1, reason: 'still holding');
      up.follow(232, 3);
      up.follow(256, 3);
      final fading = up.wake(256, first: 4, last: 4);
      expect(fading, inExclusiveRange(0, 1), reason: 'slow');
      up.follow(280, 3);
      expect(up.wake(280.01, first: 4, last: 4), closeTo(0, .001));
    });

    test('climbing back within the hold cancels the fade', () {
      final up = _climbed(to: 200);
      up.follow(201, 3);
      up.follow(215, 4);
      up.follow(300, 4);
      expect(up.wake(300), 1);
    });

    test('a retry rewinds the music, not what the room remembers', () {
      final up = PartyUp();
      for (var beat = 0.0; beat <= 40; beat += .5) {
        up.follow(beat, 1);
      }
      // Halfway through the next entrance, then the phrase is replayed.
      up.follow(40, 2);
      up.follow(50, 2);
      final before = up.wake(50);
      up.follow(34, 2);
      expect(up.wake(34), closeTo(before, 1e-9));
    });

    test('a poor run that clears still gets all of the life', () {
      // Clearing takes tier 4, so a scrappy run that recovers ends awake.
      const rules = FightDefinition('t', 'x', 60, 1, 2, 5);
      final progress = FightProgress(rules);
      final up = PartyUp.forLevel(cycleBeats: 16, successesPerTier: 1);
      var beat = 0.0;
      for (final passed in [
        true, false, true, true, false, true, true, true, false, true, true,
        true, true, true,
      ]) {
        for (var i = 0; i < 64; i++) {
          beat += .25;
          up.follow(beat, progress.tier);
        }
        progress.resolve(passed: passed);
      }
      expect(progress.cleared, isTrue);
      for (var i = 0; i < 64; i++) {
        beat += .25;
        up.follow(beat, up.tier);
      }
      expect(up.wake(beat), closeTo(1, .02));
    });

    test('entrances are sized to the level, landing before the clear', () {
      final garden = PartyUp.forLevel(cycleBeats: 16, successesPerTier: 1);
      final bar = PartyUp.forLevel(cycleBeats: 16, successesPerTier: 2);
      expect(garden.entranceBeats, 24);
      expect(bar.entranceBeats, 48);
      expect(bar.holdBeats, 32);
    });
  });

  group('full swing stays skill-gated', () {
    test('at the top tier without swing, drifting props ignore the beat', () {
      for (final kind in ['plant', 'umbrella', 'waiter']) {
        for (var seconds = 0.0; seconds < 12; seconds += .37) {
          final frames = {
            for (final beat in [0.0, .25, .5, 1.0, 1.75, 3.0])
              ensemblePartyFrame(
                kind,
                seconds,
                beat: beat,
                swing: 0,
                instance: 3,
              ),
          };
          expect(frames.length, 1, reason: '$kind at $seconds s');
        }
      }
    });

    test('flames do move in time for everyone, and only as far as life lets', () {
      final low = {
        for (var beat = 0.0; beat < 1; beat += .05)
          ensemblePartyFrame('candle', 1, beat: beat, swing: 0, onBeat: .1),
      };
      final high = {
        for (var beat = 0.0; beat < 1; beat += .05)
          ensemblePartyFrame('candle', 1, beat: beat, swing: 0, onBeat: .5),
      };
      expect(high.length, greaterThan(low.length));
      expect(high, isNot(contains('candle_d')), reason: 'the top is for swing');
    });

    test('swing still dances them, and is earned only by play', () {
      final danced = {
        for (var beat = 0.0; beat < 4; beat += .1)
          ensemblePartyFrame('umbrella', 1, beat: beat, swing: 1),
      };
      expect(danced.length, 4);
      final crowd = CrowdInterestModel(rampPhrases: 4);
      final up = _climbed();
      expect(up.wake(400), 1);
      expect(crowd.partySwing(400), 0, reason: 'tier alone never makes swing');
    });

    test('a plant layer drifts far less than it dances, and slower', () {
      final plant = _layer(PartyLifeKind.plant);
      final drift = [
        for (var beat = 0.0; beat < 8; beat += .25)
          plant.frameAt(beat: beat, swing: 0, life: 1),
      ];
      final dance = [
        for (var beat = 0.0; beat < 8; beat += .25)
          plant.frameAt(beat: beat, swing: 1),
      ];
      int reach(List<int> f) => f.reduce(math.max) - f.reduce(math.min);
      expect(reach(drift), 2, reason: 'one frame either way');
      expect(reach(dance), 6);
      // Period is four times the dance's: no return to the start in two beats.
      expect(plant.frameAt(beat: 4, swing: 0, life: 1), lessThan(3));
    });

    test('a layer is unchanged at rest, and grows from it', () {
      final lantern = _layer(PartyLifeKind.hanging, period: 4);
      expect(lantern.frameAt(beat: 0, swing: 0), lantern.restFrame);
      expect(lantern.frameAt(beat: 0, swing: 0, life: .01), lantern.restFrame);
      final flame = _layer(
        PartyLifeKind.flame,
        motion: RoomLayerMotion.pulse,
        period: 1,
      );
      expect(flame.frameAt(beat: .5, swing: 0, life: 1), flame.restFrame);
      expect(flame.frameAt(beat: 0, swing: 0, life: 1), greaterThan(0));
    });
  });

  group('the room near still, and reduced motion', () {
    test('drift grows with range and at 1 is the drawn loop', () {
      Set<String> seen(double range) => {
        for (var s = 0.0; s < 9; s += .05)
          ensembleAmbientFrame('plant', s, range: range),
      };
      expect(seen(1), {'plant_a', 'plant_b', 'plant_c', 'plant_d'});
      expect(seen(.34), {'plant_a', 'plant_b'});
      expect(seen(0), {'plant_a'});
    });

    test('every prop holds still under reduced motion, whatever the tier', () {
      for (final kind in ['plant', 'umbrella', 'candle', 'waiter']) {
        for (var beat = 0.0; beat < 4; beat += .3) {
          expect(
            ensemblePartyFrame(
              kind,
              beat,
              beat: beat,
              swing: 1,
              range: 1,
              onBeat: .5,
              reducedMotion: true,
            ),
            '${kind}_a',
          );
        }
      }
      final lantern = _layer(PartyLifeKind.hanging);
      expect(
        lantern.frameAt(beat: 3, swing: 0, life: 1, reducedMotion: true),
        lantern.restFrame,
      );
    });
  });

  group('the shipped rooms', () {
    final levels = {
      for (final id in ['garden', 'pool-garden', 'bar'])
        id: LevelDefinition.fromJson(
          jsonDecode(File('levels/$id.json').readAsStringSync())
              as Map<String, Object?>,
        ),
    };

    test('every garden layer says what it is', () {
      final kinds = {for (final p in levels['garden']!.layers) p.id: p.kind};
      expect(kinds['fronds-left'], PartyLifeKind.plant);
      expect(kinds['lantern-left'], PartyLifeKind.hanging);
      expect(kinds['flame-left'], PartyLifeKind.flame);
    });

    test('the lawn and the bar have layers, lamps and staff to wake', () {
      for (final id in ['pool-garden', 'bar']) {
        final level = levels[id]!;
        expect(level.layers, isNotEmpty, reason: id);
        expect(level.scenery.lamps.length, greaterThanOrEqualTo(6), reason: id);
        expect(level.scenery.waiter, isNotNull, reason: id);
      }
    });

    test('the waiters stay clear of the tap band as their range grows', () {
      for (final level in levels.values) {
        final waiter = level.scenery.waiter!;
        expect(waiter.home.y, lessThan(roomLayerTapBandTop), reason: level.id);
        expect(waiter.home.x - waiter.swayX, greaterThan(.15), reason: level.id);
        expect(waiter.home.x + waiter.swayX, lessThan(.85), reason: level.id);
      }
    });
  });
}
