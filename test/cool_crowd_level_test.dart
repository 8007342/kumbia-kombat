import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/band.dart';
import 'package:kumbia_kombat/gameplay/crowd_interest.dart';
import 'package:kumbia_kombat/gameplay/dance_floor.dart';
import 'package:kumbia_kombat/gameplay/ensemble_sprites.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_layout.dart';
import 'package:kumbia_kombat/gameplay/progression.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/thumb_layout.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

/// The indoor party, on real game code and its real level file. It isn't in the
/// campaign yet: the owner's ruling and how it was built are in
/// `plan/levels/indoor-party-2026-11-07.md`.
String _read(String id) => File('levels/$id.json').readAsStringSync();

LevelRegistry _registry() =>
    LevelRegistry.parse(File('levels/index.json').readAsStringSync(), _read);

LevelDefinition _level() => _registry().reviewLevels['cool-crowd']!;

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

/// A figure on the plate, in plate fractions: as wide as half its height, feet
/// on the floor point. Its height is along the image's y, its width along x.
ui.Rect _body(PartyFloorPlane plane, PartyPoint at, {double stature = 1}) {
  final height = plane.standingHeightAt(at.y, stature: stature);
  // A plate is 2:3, so a height in y fractions is 1.5 times that in x fractions.
  final half = height * 1.5 * .25;
  return ui.Rect.fromLTRB(at.x - half, at.y - height, at.x + half, at.y);
}

Map<String, Object?> _editedJson(void Function(Map<String, dynamic> json) edit) {
  final json = jsonDecode(_read('cool-crowd')) as Map<String, dynamic>;
  edit(json);
  return json;
}

Matcher _refused(String part) => throwsA(
  isA<LevelDataError>().having((e) => e.toString(), 'message', contains(part)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hidden, but real', () {
    test('it stays off the campaign, and a review link reaches it alone', () {
      final registry = _registry();
      expect(registry.levels.map((l) => l.id), isNot(contains('cool-crowd')));
      expect(registry.reviewing(null), same(registry));
      final review = registry.reviewing('cool-crowd');
      expect(review.levels.map((l) => l.id), ['cool-crowd']);
      expect(review.campaign.single.next, isNull);
      expect(review.campaign.single.bridgeToNext, isNull);
      expect(review.roomScoreIds, ['crowd_duende']);
      expect(review.exitScoreIds, {'crowd_duende_success'});
    });

    test('a review link also opens a campaign level, and refuses a stranger', () {
      final registry = _registry();
      expect(registry.reviewing('bar').first.id, 'bar');
      expect(() => registry.reviewing('nowhere'), throwsArgumentError);
    });

    test('joining the campaign is a data change', () {
      final index = jsonDecode(File('levels/index.json').readAsStringSync())
          as Map<String, dynamic>;
      index.remove('review');
      (index['campaign'] as List).last['bridgeToNext'] = 'bar_to_crowd';
      (index['campaign'] as List).add({'level': 'cool-crowd'});
      final registry = LevelRegistry.parse(jsonEncode(index), _read);
      expect(registry.campaign.last.level.id, 'cool-crowd');
      expect(registry.exitScoreIds, contains('bar_to_crowd'));
    });

    test('everything it names is on disk', () {
      final level = _level();
      expect(File('assets/art/${level.background}').existsSync(), isTrue);
      for (final id in [level.music.score, level.music.successScore]) {
        expect(File('assets/music/scores/$id.json').existsSync(), isTrue);
      }
      expect(File('assets/music/scores/bar_to_crowd.json').existsSync(), isTrue);
    });

    test('the room uses the owner-approved title and the shared combo', () {
      final level = _level();
      expect(level.copy.titleWords, ['QUÉ', 'FLOW']);
      final upcoming = _registry().upcomingOpponents.firstWhere(
        (o) => o.id == 'blinblin',
      );
      expect(level.hardestCombo!.name, upcoming.hardestCombo!.name);
      expect(level.hardestCombo!.status, HardestComboStatus.proposal);
    });
  });

  group('the crowd starts in the middle and opens the floor', () {
    test('those in the middle part; those outside dance in place', () {
      final level = _level();
      final guests = level.layout.guests;
      expect(guests.every((g) => g.onFloor), isTrue);
      expect(guests.length, greaterThan(CrowdInterestModel.castSize));
      final moving = guests.where((g) => g.partTo != null);
      final staying = guests.where((g) => g.partTo == null);
      expect(moving.length, greaterThanOrEqualTo(10));
      expect(staying.length, greaterThanOrEqualTo(5));
      for (final g in moving) {
        expect(g.floor.x, inInclusiveRange(.33, .67), reason: g.id);
      }
      for (final g in staying) {
        expect(g.floor.x, isNot(inInclusiveRange(.33, .67)), reason: g.id);
      }
      expect(level.layout.props, isEmpty, reason: 'nobody here has a seat');
    });

    test('the floor is open by the first call, nearest the dancer first', () {
      final level = _level();
      final parting = level.floorDance!.parting!;
      final intro = level.chart.introBeats;
      expect(parting.end, lessThanOrEqualTo(intro));
      for (final g in level.layout.guests.where((g) => g.partTo != null)) {
        expect(parting.along(parting.from - .01, g.partDelay), 0);
        expect(parting.along(intro, g.partDelay), 1, reason: g.id);
        expect(g.partDelay, inInclusiveRange(0, parting.stagger));
      }
      double near(PartyGuestSlot g) => (g.floor.x - .5).abs() + (g.floor.y - .47).abs();
      final moving = level.layout.guests.where((g) => g.partTo != null).toList()
        ..sort((a, b) => a.partDelay.compareTo(b.partDelay));
      expect(near(moving.first), lessThan(near(moving.last)));
    });

    test('they enter and settle with no speed at either end', () {
      final parting = _level().floorDance!.parting!;
      const edge = .02;
      expect(parting.along(parting.from + edge, 0), lessThan(.001));
      expect(parting.along(parting.from + parting.beats - edge, 0), greaterThan(.999));
    });

    test('their dance slows through the move, with no jump in its drawings', () {
      final parting = _level().floorDance!.parting!;
      var previous = parting.danceBeat(parting.from - 1, 0);
      var slowest = 1.0;
      const step = .05;
      for (var b = parting.from - 1 + step; b < parting.from + parting.beats + 1; b += step) {
        final now = parting.danceBeat(b, 0);
        final rate = (now - previous) / step;
        expect(rate, greaterThan(0), reason: 'never backwards, at $b');
        slowest = math.min(slowest, rate);
        previous = now;
      }
      expect(slowest, closeTo(parting.slowTo, .01));
      expect(parting.danceBeat(parting.from - 1, 0), parting.from - 1);
    });

    test('reduced motion cuts them over, with nothing sliding', () {
      final parting = _level().floorDance!.parting!;
      for (var b = 0.0; b < 16; b += .1) {
        final a = parting.along(b, 0, reducedMotion: true);
        expect(a == 0 || a == 1, isTrue);
      }
    });

    test('after parting nobody is on the thumbs, the fight or the quiet area', () {
      final level = _level();
      final plane = level.layout.floor;
      final stage = level.stage;
      final challenger = stage.challengers.single;
      final fight = {
        'hero home': _body(plane, stage.heroHome, stature: .35),
        'hero back mark': _body(plane, stage.heroWatch, stature: .35),
        'hero aside': _body(plane, stage.heroAside, stature: .35),
        'opponent': _body(plane, challenger.mark, stature: challenger.stature),
        'opponent aside': _body(plane, challenger.yieldMark, stature: challenger.stature),
      };
      for (final g in level.layout.guests) {
        final place = g.partTo ?? g.floor;
        expect(place.y, lessThan(thumbBandTop), reason: g.id);
        expect(g.floor.y, lessThan(thumbBandTop), reason: g.id);
        final body = _body(plane, place);
        for (final entry in fight.entries) {
          expect(
            body.overlaps(entry.value),
            isFalse,
            reason: '${g.id} at ${place.x},${place.y} on ${entry.key}',
          );
        }
        // The quiet column behind the opponent stays quiet through play.
        final quiet = const ui.Rect.fromLTRB(.35, .3, .65, .6);
        expect(body.overlaps(quiet), isFalse, reason: '${g.id} in the quiet area');
      }
    });

    test('he can be seen among them from the start', () {
      final level = _level();
      final challenger = level.stage.challengers.single;
      final plane = level.layout.floor;
      final him = _body(plane, challenger.mark, stature: challenger.stature);
      final middle = ui.Rect.fromCenter(
        center: him.center,
        width: him.width * .5,
        height: him.height,
      );
      for (final g in level.layout.guests) {
        if (g.floor.y <= challenger.mark.y) continue; // Behind him, he's in front.
        expect(_body(plane, g.floor).overlaps(middle), isFalse, reason: g.id);
      }
    });

    test('the band keeps its heads and shoulders in sight over the crowd', () {
      final level = _level();
      final plane = level.layout.floor;
      final lift = level.scenery.platform!.lift;
      for (final player in level.scenery.band!.players) {
        final height = plane.standingHeightAt(player.at.y);
        final feet = player.at.y - height * lift;
        final upper = ui.Rect.fromLTRB(
          player.at.x - height * .25,
          feet - height,
          player.at.x + height * .25,
          feet - height * 2 / 3,
        );
        for (final g in level.layout.guests) {
          final place = g.partTo ?? g.floor;
          if (place.y <= player.at.y) continue;
          expect(
            _body(plane, place).overlaps(upper),
            isFalse,
            reason: '${g.id} hides ${player.id}',
          );
        }
      }
    });

    test('a bad parting is refused', () {
      expect(
        () => LevelDefinition.fromJson(_editedJson((json) {
          json['crowd']['floorDance']['parting']['from'] = 11;
        })),
        _refused('must be open'),
      );
      expect(
        () => LevelDefinition.fromJson(_editedJson((json) {
          (json['crowd']['guests'] as List).first['partTo'] = [.3, .8];
        })),
        _refused('parts onto the tap band'),
      );
      expect(
        () => LevelDefinition.fromJson(_editedJson((json) {
          (json['crowd']['guests'] as List).first['partTo'] = [.1, .45];
        })),
        _refused('is on the platform'),
      );
      expect(
        () => LevelDefinition.fromJson(_editedJson((json) {
          (json['crowd'] as Map).remove('floorDance');
        })),
        _refused('crowd.floorDance'),
      );
    });
  });

  group('the room is still the meter', () {
    final dance = _level().floorDance!;

    List<({String frame, bool facesIn})> poses(
      CrowdInterestModel crowd,
      double beat,
    ) => [
      for (var i = 0; i < crowd.guestCount; i++)
        floorGuestPose(crowd.guest(i, beat), dance, danceBeat: beat),
    ];

    CrowdInterestModel run(List<PhraseReport?> phrases, {int guests = 21}) {
      final crowd = CrowdInterestModel(rampPhrases: 9, arcPhrases: 11, guestCount: guests);
      for (final (i, phrase) in phrases.indexed) {
        crowd.resolvePhrase(
          sequence: i,
          passed: phrase != null,
          beat: 12.0 + i * 16,
          report: phrase,
        );
      }
      return crowd;
    }

    test('at the start they are dancing, turned away, doing their own thing', () {
      final all = poses(run(const []), 0);
      expect(all.every((p) => !p.facesIn), isTrue);
      expect(all.map((p) => p.frame).toSet(), everyElement(isIn(dance.ownThing.frames)));
    });

    test('nobody ever sits, however the run goes', () {
      const clean = PhraseReport(notes: 8, hits: 8, perfects: 0);
      const scrappy = PhraseReport(notes: 8, hits: 6, perfects: 0);
      for (final script in [
        [for (var i = 0; i < 11; i++) clean],
        [for (var i = 0; i < 11; i++) scrappy],
        [scrappy, null, null, scrappy, clean, null, clean, clean, scrappy, clean, clean],
      ]) {
        final crowd = run(script);
        for (var b = 0.0; b < 12 + 16.0 * 14; b += .25) {
          for (final pose in poses(crowd, b)) {
            expect(pose.frame, isNot(startsWith('seated')));
            expect(pose.frame, isNot(startsWith('notice')));
            expect(pose.frame, isNot(startsWith('sit_down')));
            expect(pose.frame, isNot(startsWith('stand_up')));
          }
        }
      }
    });

    test('a clean run ends with everyone celebrating, facing the fight', () {
      const clean = PhraseReport(notes: 8, hits: 8, perfects: 0);
      final crowd = run([for (var i = 0; i < 11; i++) clean]);
      final beat = 12.0 + 16.0 * 12;
      expect(poses(crowd, beat).every((p) => p.facesIn), isTrue);
      for (var i = 0; i < crowd.guestCount; i++) {
        expect(crowd.guest(i, beat).state, CrowdGuestState.celebrating);
      }
    });

    test('a poor run that clears is warm: all face the fight and dance, and it costs some of the cheer', () {
      const scrappy = PhraseReport(notes: 8, hits: 6, perfects: 0);
      final crowd = run([for (var i = 0; i < 11; i++) scrappy]);
      final beat = 12.0 + 16.0 * 12;
      expect(poses(crowd, beat).every((p) => p.facesIn), isTrue);
      final states = [for (var i = 0; i < crowd.guestCount; i++) crowd.guest(i, beat).state];
      expect(states, isNot(contains(CrowdGuestState.occupied)));
      expect(states, isNot(contains(CrowdGuestState.celebrating)));
    });

    test('losing the room turns some of them back to their own thing', () {
      final crowd = run([for (var i = 0; i < 2; i++) PhraseReport.plain]);
      final warm = poses(crowd, 80).where((p) => p.facesIn).length;
      for (var i = 0; i < 12; i++) {
        crowd.resolvePhrase(sequence: 10 + i, passed: false, beat: 90.0 + i * 16);
      }
      final cold = poses(crowd, 400).where((p) => p.facesIn).length;
      expect(cold, lessThan(warm));
    });
  });

  group('the band', () {
    test('stands on the platform, every player with a ladder to climb', () {
      final level = _level();
      final band = level.scenery.band!;
      expect(band.players.length, greaterThanOrEqualTo(3));
      expect(band.standIn, isTrue, reason: 'their art is owed: see the plan note');
      for (final player in band.players) {
        expect(level.scenery.platform!.covers(player.at), isTrue, reason: player.id);
        expect(player.ladder.length, greaterThanOrEqualTo(3));
      }
      final manifest = EnsembleManifest.fromJson(
        jsonDecode(File('assets/art/ensemble/manifest.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      for (final player in band.players) {
        manifest.atlases[player.atlas]!.art.requireFrames(player.frames);
      }
    });

    test('a player off the platform is refused', () {
      expect(
        () => LevelDefinition.fromJson(_editedJson((json) {
          (json['scenery']['band']['players'] as List).first['at'] = [.5, .47];
        })),
        _refused('off the platform'),
      );
    });

    test('its energy follows the player, separately from the tier', () {
      CrowdInterestModel played(PhraseReport report) {
        final crowd = CrowdInterestModel(rampPhrases: 9, arcPhrases: 11);
        for (var i = 0; i < 9; i++) {
          crowd.resolvePhrase(sequence: i, passed: true, beat: i * 16.0, report: report);
        }
        return crowd;
      }

      // Passing every phrase reaches the top tier however cleanly it's done, because
      // progression only counts passes: only how they went differs here.
      final fight = FightProgress(_level().rules);
      for (var i = 0; i < 9; i++) {
        fight.resolve(passed: true);
      }
      expect(fight.tier, 4);
      final clean = played(const PhraseReport(notes: 8, hits: 8, perfects: 0));
      final scrappy = played(const PhraseReport(notes: 8, hits: 6, perfects: 0));
      expect(clean.recentForm, greaterThan(.9));
      expect(scrappy.recentForm, inInclusiveRange(.35, .55));
    });

    test('a player who improves gets a livelier band, right away', () {
      final crowd = CrowdInterestModel(rampPhrases: 9, arcPhrases: 11);
      var i = 0;
      void phrases(int count, PhraseReport report) {
        for (var n = 0; n < count; n++) {
          crowd.resolvePhrase(sequence: i, passed: true, beat: i++ * 16.0, report: report);
        }
      }

      phrases(4, const PhraseReport(notes: 8, hits: 6, perfects: 0));
      final before = crowd.recentForm;
      phrases(3, const PhraseReport(notes: 8, hits: 8, perfects: 0));
      expect(crowd.recentForm, greaterThan(before + .15));
    });

    test('energy eases in with no speed at either end, and survives a rewind', () {
      final energy = BandEnergy()..follow(0, 1);
      expect(energy.at(0), 0);
      expect(energy.at(.5), lessThan(.001));
      final middle = energy.at(12);
      expect(middle, closeTo(.5, .01));
      expect(energy.at(BandEnergy.defaultEntranceBeats), 1);
      energy.follow(12, 1);
      energy.follow(4, 1); // A retried phrase rewinds the music by eight beats.
      expect(energy.at(4), closeTo(middle, .01));
    });

    test('rungs change on a downbeat, and a higher energy plays a higher rung', () {
      final player = _level().scenery.band!.players.first;
      final rung = player.ladder;
      String at(double beat, double energy) =>
          player.frameAt(beat, (_) => energy, beatsPerBar: 4);
      expect(rung.first.frames, contains(at(8, 0)));
      expect(rung.last.frames, contains(at(8, .99)));
      // Energy crossing a rung mid-bar waits for the next bar.
      double rising(double bar) => bar < 8 ? 0 : .99;
      expect(
        rung.first.frames,
        contains(player.frameAt(7.5, rising, beatsPerBar: 4)),
      );
      expect(
        rung.last.frames,
        contains(player.frameAt(8, rising, beatsPerBar: 4)),
      );
    });

    test('under reduced motion each rung holds one drawing, and still differs', () {
      final player = _level().scenery.band!.players.first;
      final calm = {
        for (var b = 0.0; b < 16; b += .25)
          player.frameAt(b, (_) => 0, reducedMotion: true),
      };
      final lively = {
        for (var b = 0.0; b < 16; b += .25)
          player.frameAt(b, (_) => .99, reducedMotion: true),
      };
      expect(calm, hasLength(1));
      expect(lively, hasLength(1));
      expect(calm, isNot(lively));
    });
  });

  group('the BlinBlin dancer', () {
    test('dances with his back to the room until the first call, then turns', () {
      final level = _level();
      final away = level.stage.challengers.single.facingAway!;
      final intro = level.chart.introBeats;
      expect(away.back.frames, contains(away.frameAt(0, intro)));
      expect(away.back.frames, contains(away.frameAt(intro - away.turnBeats - .01, intro)));
      expect(away.turn, contains(away.frameAt(intro - .01, intro)));
      expect(away.frameAt(intro, intro), isNull);
      expect(away.frameAt(1, intro, reducedMotion: true), away.back.frames.first);
      expect(
        away.frameAt(intro - .01, intro, reducedMotion: true),
        away.back.frames.first,
      );
    });

    test('Mācron enters after the room is seen, and he reaches his place', () {
      final level = _level();
      expect(level.stage.heroEntersAt, greaterThan(0));
      expect(level.stage.heroEntersAt, lessThan(level.chart.introBeats));
      expect(level.stage.heroEntrance.x, lessThan(.153), reason: 'off a phone');
    });
  });

  group('the real scene', () {
    Future<ui.Image> still(GardenSceneGame scene) async {
      scene.onGameResize(Vector2(390, 844));
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      scene.render(canvas);
      final ring = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const ui.Color(0xCCFFFFFF);
      for (final limb in Limb.values) {
        final home = thumbHome(limb);
        canvas.drawCircle(ui.Offset(home.x * 390, home.y * 844), 390 * .09, ring);
      }
      return recorder.endRecording().toImage(390, 844);
    }

    Future<void> render({required bool reducedMotion, required String name}) async {
      final level = _level();
      final registry = _registry();
      final scene = GardenSceneGame(firstLevel: () async => registry.first);
      scene.onGameResize(Vector2(390, 844));
      await scene.onLoad();
      await scene.showLevel(level);
      scene.reducedMotion = reducedMotion;
      final audio = _Audio();
      final music = MusicTransport(
        MusicScore.fromJson(
          jsonDecode(File('assets/music/scores/${level.music.score}.json').readAsStringSync())
              as Map<String, dynamic>,
        ),
        audio,
        loop: true,
        lookaheadSeconds: .3,
      );
      final session = level.newSession(music, audio);
      scene.session = session;
      session.start();
      void advance(double target) {
        while (audio.nowSeconds < target - 1e-6) {
          audio.nowSeconds = math.min(target, audio.nowSeconds + .02);
          music.pump();
          session.advance();
          scene.update(.02);
        }
      }

      await still(scene);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final rows = <ui.Image>[];
      Future<void> at(double beat) async {
        advance(music.secondsAt(beat));
        rows.add(await still(scene));
      }

      await at(.5); // The crowd in the middle, his back to the room.
      await at(5.5);
      await at(8); // Slowing, moving aside, Mācron walking in.
      await at(10.5); // He's turning.
      await at(12.5); // The first call, on an open floor.
      await at(12 + 16 + 2); // The second call.
      await at(12 + 16 + 8 + 2); // Mācron's answer.
      // A flawless run's end: the whole room up, and the band at its liveliest.
      final beat = session.positionBeats;
      for (var i = 0; i < 40; i++) {
        session.crowd.resolvePhrase(sequence: 1000 + i, passed: true, beat: beat);
      }
      scene.presentationBeat = beat + 70;
      await still(scene);
      scene.presentationBeat = beat + 72;
      rows.add(await still(scene));
      scene.presentationBeat = null;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      for (final (i, image) in rows.indexed) {
        canvas.drawImage(image, ui.Offset(i * 396.0, 0), ui.Paint());
      }
      final sheet = await recorder.endRecording().toImage(396 * rows.length, 844);
      final png = await sheet.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/stills').createSync(recursive: true);
      File('build/stills/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    }

    test('a real run clears it: the room fills, the band livens, and nobody sits', () async {
      final level = _level();
      final registry = _registry();
      final scene = GardenSceneGame(firstLevel: () async => registry.first);
      scene.onGameResize(Vector2(390, 844));
      await scene.onLoad();
      await scene.showLevel(level);
      final audio = _Audio();
      final music = MusicTransport(
        MusicScore.fromJson(
          jsonDecode(File('assets/music/scores/${level.music.score}.json').readAsStringSync())
              as Map<String, dynamic>,
        ),
        audio,
        loop: true,
        lookaheadSeconds: .3,
      );
      final session = level.newSession(music, audio);
      scene.session = session;
      session.start();
      void advance(double target) {
        while (audio.nowSeconds < target - 1e-6) {
          audio.nowSeconds = math.min(target, audio.nowSeconds + .02);
          music.pump();
          session.advance();
          scene.update(.02);
        }
      }

      await still(scene);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final frames = <ui.Image>[];
      var cycle = 0;
      var last = 0.0;
      for (; cycle < 60 && session.phase != GardenPhase.cleared; cycle++) {
        final start = level.chart.introBeats + cycle * level.chart.cycleBeats;
        for (var i = 0; i < session.activeLimbs.length; i++) {
          advance(music.secondsAt(start + level.chart.callBeats + level.chart.offsets[i]));
          expect(session.tap(session.activeLimbs[i]).note, isNotNull);
        }
        last = start + level.chart.cycleBeats - .05;
        advance(music.secondsAt(last));
        if (cycle == 2 || cycle == 6) frames.add(await still(scene));
      }
      expect(session.phase, GardenPhase.cleared);
      expect(cycle, 11, reason: 'two phrases a tier, then three proofs');
      expect(session.crowd.recentForm, greaterThan(.9));
      frames.add(await still(scene));
      for (var i = 0; i < session.crowd.guestCount; i++) {
        expect(session.crowd.guest(i, last).state, CrowdGuestState.celebrating);
      }
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      for (final (i, image) in frames.indexed) {
        canvas.drawImage(image, ui.Offset(i * 396.0, 0), ui.Paint());
      }
      final sheet = await recorder.endRecording().toImage(396 * frames.length, 844);
      final png = await sheet.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/stills').createSync(recursive: true);
      File('build/stills/cool-crowd-run.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    test('draws every moment of the opening and of play', () async {
      await render(reducedMotion: false, name: 'cool-crowd');
    });

    test('draws them under reduced motion too', () async {
      await render(reducedMotion: true, name: 'cool-crowd-reduced');
    });
  });
}
