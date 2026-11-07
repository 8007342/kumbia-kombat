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
import 'package:kumbia_kombat/music/rendered_music.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

/// The indoor party, on real game code and its real level file. The owner's
/// ruling and how it was built are in
/// `plan/levels/indoor-party-2026-11-07.md`.
String _read(String id) => File('levels/$id.json').readAsStringSync();

LevelRegistry _registry() =>
    LevelRegistry.parse(File('levels/index.json').readAsStringSync(), _read);

LevelDefinition _level() => _registry().byId('cool-crowd');

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

  group('in the campaign, after the bar', () {
    test('a review link still reaches it alone', () {
      final registry = _registry();
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

    test('the bar hands over with its short tag, and the gulp spans both', () {
      final registry = _registry();
      final bar = registry.campaign[2];
      expect(bar.next!.id, 'cool-crowd');
      expect(bar.bridgeToNext, 'bar_to_crowd');
      expect(bar.level.music.successScore, 'bar_swag_success');
      final manifest = RenderedManifest.fromJson(
        jsonDecode(
          File('assets/music/rendered/manifest.json').readAsStringSync(),
        ),
      ).levels['bar']!;
      final short = manifest.successToward('cool-crowd')!;
      expect(short.id, manifest.successShort!.id);
      // Alone on a review link, the long tag still carries the whole shot.
      expect(manifest.successToward(null)!.id, manifest.success!.id);
      final length = short.bars * short.beatsPerBar + 0.0;
      final bridge = manifest.bridge!;
      final shot = bar.level.exitShot!;
      expect(shot.contactBeat, length, reason: 'the bridge downbeat');
      expect(
        shot.closeupTo,
        lessThanOrEqualTo(length + bridge.bars * bridge.beatsPerBar),
      );
      expect(manifest.bridgeTo, 'cool-crowd');
      expect(manifest.bridge!.bpm, closeTo(manifest.takes['high']!.bpm, .01));
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
      expect(level.hardestCombo!.name, 'All That Glitters');
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
      for (final player in level.scenery.band!.players) {
        final height = plane.standingHeightAt(player.at.y);
        final upper = ui.Rect.fromLTRB(
          player.feet.x - height * .25,
          player.feet.y - height,
          player.feet.x + height * .25,
          player.feet.y - height * 2 / 3,
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

    test('at the start they are dancing, busy with each other or themselves', () {
      final all = poses(run(const []), 0);
      expect(all.every((p) => !p.facesIn), isTrue);
      expect(
        all.map((p) => p.frame).toSet(),
        everyElement(isIn(dance.frames)),
      );
    });

    test('most of the floor dances in couples, and faces all ways', () {
      final guests = _level().layout.guests;
      final coupled = guests.where((g) => g.partner != null).toList();
      expect(coupled.length, greaterThanOrEqualTo(10));
      for (final guest in coupled) {
        final other = guests[guest.partner!];
        expect(other.partner, guests.indexOf(guest));
        // Side by side, at both ends of a parting, at the reach GUESTS measured:
        // .40 to .44 of an adult apart, which scales with distance on the floor.
        // On this plate an adult is (y - horizon) of the plate's width.
        for (final (mine, theirs) in [
          (guest.floor, other.floor),
          if (guest.partTo != null) (guest.partTo!, other.partTo!),
        ]) {
          final adults = (mine.x - theirs.x).abs() / (mine.y - .25);
          expect(adults, inInclusiveRange(.39, .45), reason: guest.id);
          expect(mine.y, theirs.y, reason: guest.id);
        }
        expect(guest.occupiedFacingRight, guest.floor.x < other.floor.x);
        expect(guest.partDelay, other.partDelay);
      }
      final facing = guests.map((g) => g.occupiedFacingRight).toSet();
      expect(facing, {true, false});
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

  group('plate A', () {
    final room = jsonDecode(File('tool/art/rooms/cool-crowd.json').readAsStringSync())
        as Map<String, dynamic>;
    final floor = jsonDecode(File('art_runs/rooms/cool-crowd/floor.json').readAsStringSync())
        as Map<String, dynamic>;

    test('the level uses the room spec\'s camera', () {
      final plane = _level().layout.floor;
      final camera = room['camera'] as Map<String, dynamic>;
      expect(plane.horizonY, camera['horizonY']);
      expect(plane.vanishingX, camera['vanishingX']);
      // Adult height at a foot y is (y - horizon) / eye.
      expect(
        (plane.referenceFootY - plane.horizonY) / plane.referenceHeight,
        closeTo(camera['eyeHeightAdults'] as double, 1e-9),
      );
      final table = partyRoomLayouts['cool-crowd']!.floor;
      expect(table.horizonY, plane.horizonY);
      expect(table.referenceHeight, plane.referenceHeight);
    });

    test('the platform is the plate\'s measured bandstand', () {
      final platform = _level().scenery.platform!;
      final bandstand = (floor['platforms'] as List).single as Map<String, dynamic>;
      expect(bandstand['id'], 'bandstand');
      expect(platform.lift, bandstand['heightAdults']);
      final corners = bandstand['topCornersFrac'] as List;
      expect(platform.deck, hasLength(corners.length));
      for (final (i, corner) in corners.indexed) {
        expect(platform.deck[i].x, (corner as List)[0]);
        expect(platform.deck[i].y, corner[1]);
      }
    });

    test('everyone on the floor stands on floor the plate really has', () async {
      final bytes = File('art_runs/rooms/cool-crowd/ids.png').readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      final pixels = (await image.toByteData())!;
      final ids = floor['ids'] as Map<String, dynamic>;
      final walkable = {ids['floor'], ids['joint']};
      void onFloor(String who, PartyPoint p) {
        final x = (p.x * image.width).floor().clamp(0, image.width - 1);
        final y = (p.y * image.height).floor().clamp(0, image.height - 1);
        // A grey image decodes with its id in every colour channel.
        final id = pixels.getUint8((y * image.width + x) * 4);
        expect(walkable, contains(id), reason: '$who at ${p.x},${p.y}');
      }

      final level = _level();
      for (final g in level.layout.guests) {
        onFloor(g.id, g.floor);
        if (g.partTo != null) onFloor(g.id, g.partTo!);
      }
      final stage = level.stage;
      final dancer = stage.challengers.single;
      for (final (name, mark) in [
        ('home', stage.heroHome),
        ('entrance', stage.heroEntrance),
        ('retreat', stage.heroRetreat),
        ('back mark', stage.heroWatch),
        ('aside', stage.heroAside),
        ('opponent', dancer.mark),
        ('opponent aside', dancer.yieldMark),
        ('meet', dancer.meetMark!),
      ]) {
        onFloor(name, mark);
      }
    });
  });

  group('the rendered music', () {
    test('this level has takes of its own, found by its id', () {
      // `lib/music/rendered_music.dart`, on `work/1855-rend`, looks a level's music
      // up by level id, so a review link gets it with no change here.
      final manifest = jsonDecode(File('assets/music/rendered/manifest.json').readAsStringSync())
          as Map<String, dynamic>;
      final music = (manifest['levels'] as Map)[_level().id] as Map<String, dynamic>;
      expect(music['tierTakes'], ['low', 'low', 'mid', 'mid', 'high']);
      final takes = music['takes'] as Map<String, dynamic>;
      expect({for (final e in takes.entries) e.key: e.value['bpm']}, {
        'low': 112.0,
        'mid': 124.0,
        'high': 136.0,
      });
      for (final take in takes.values) {
        for (final file in (take['files'] as Map).values) {
          expect(File(file as String).existsSync(), isTrue, reason: file);
        }
      }
      expect(music['success'], isNotNull);
    });
  });

  group('the band', () {
    final band = _level().scenery.band!;
    final player = band.players.firstWhere((p) => p.id == 'bass');

    test('stands on the deck, every player with a ladder to climb', () {
      final level = _level();
      expect(band.players.length, greaterThanOrEqualTo(3));
      expect(band.standIn, isTrue, reason: 'their art is owed: see the plan note');
      for (final p in band.players) {
        expect(level.scenery.platform!.holds(p.feet), isTrue, reason: p.id);
        expect(p.ladder.length, greaterThanOrEqualTo(3));
      }
      final manifest = EnsembleManifest.fromJson(
        jsonDecode(File('assets/art/ensemble/manifest.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      for (final p in band.players) {
        manifest.atlases[p.atlas]!.art.requireFrames(p.frames);
      }
    });

    test('a raised deck makes them about 31% taller than the floor at their feet', () {
      final level = _level();
      final plane = level.layout.floor;
      for (final p in band.players) {
        final height = plane.standingHeightAt(p.at.y);
        // Band note: (footY - horizon) / 1.146 by its measured .35, 1.14 at .36.
        expect(height, closeTo((p.feet.y - .25) / 1.14, 1e-9), reason: p.id);
        expect(height / ((p.feet.y - .25) / 1.5), closeTo(1.316, .001));
        // The feet are where the deck lifts them.
        expect(p.at.y - height * level.scenery.platform!.lift, closeTo(p.feet.y, 1e-9));
        expect(p.at.x, p.feet.x);
      }
    });

    test('a few guests dance in front of them, over them by depth, on a phone', () {
      final level = _level();
      final plane = level.layout.floor;
      final platform = level.scenery.platform!;
      final front = platform.deck.map((c) => platform.groundUnder(c).y).reduce(math.max);
      final around = [
        for (final g in level.layout.guests)
          if (g.partTo == null && g.floor.y >= front && g.floor.x < .3) g,
      ];
      expect(around.length, greaterThanOrEqualTo(3));
      const phoneLeft = 157 / 1024;
      expect(around.where((g) => g.floor.x >= phoneLeft), isNotEmpty);
      // Whoever a phone shows whole keeps head and shoulders above those in front.
      final shown = band.players.where((p) => p.feet.x > phoneLeft);
      expect(shown.length, greaterThanOrEqualTo(2));
      for (final p in shown) {
        final height = plane.standingHeightAt(p.at.y);
        for (final g in around) {
          expect(g.floor.y, greaterThan(p.at.y), reason: 'drawn over ${p.id}');
          expect(_body(plane, g.floor).top, greaterThan(p.feet.y - height * 2 / 3));
        }
      }
    });

    test('until the art comes, stand-ins face the crowd: toward picture right', () {
      for (final p in band.players) {
        expect(p.flipX, isFalse, reason: p.id);
      }
    });

    test('a player off the deck is refused', () {
      expect(
        () => LevelDefinition.fromJson(_editedJson((json) {
          (json['scenery']['band']['players'] as List).first['feet'] = [.5, .47];
        })),
        _refused('is off the platform'),
      );
    });

    test('each rung names the one input that earns it, and any can be chosen by data', () {
      expect(player.rungFor(const BandInputs()), 0);
      expect(player.rungFor(const BandInputs(form: .4)), 1);
      expect(player.rungFor(const BandInputs(form: .8)), 2);
      // Today every rung reads form, so tier and swing alone move nothing.
      expect(player.rungFor(const BandInputs(tier: 4, partySwing: 1)), 0);

      final other = _editedJson((json) {
        final rungs = json['scenery']['band']['ladders']['standIn'] as List;
        rungs[1]['input'] = 'tier';
        rungs[1]['from'] = 2;
        rungs[2]['input'] = 'partySwing';
        rungs[2]['from'] = .25;
      });
      final proposal = LevelDefinition.fromJson(other).scenery.band!.players
          .firstWhere((p) => p.id == 'bass');
      expect(proposal.rungFor(const BandInputs(form: 1)), 0);
      expect(proposal.rungFor(const BandInputs(tier: 2)), 1);
      expect(proposal.rungFor(const BandInputs(tier: 2, partySwing: .5)), 2);
    });

    test('they liven one at a time', () {
      final rungs = {
        for (final p in band.players) p.id: p.rungFor(const BandInputs(form: .78)),
      };
      expect(rungs['bass'], 2);
      expect(rungs['trumpet'], 1);
    });

    test('form follows the player, separately from the tier', () {
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
      expect(player.rungFor(BandInputs(form: clean.recentForm)), 2);
      expect(player.rungFor(BandInputs(form: scrappy.recentForm)), 1);
    });

    test('a player who improves late still gets the top rung, where the party swing doesn\'t', () {
      final crowd = CrowdInterestModel(rampPhrases: 9, arcPhrases: 11);
      var i = 0;
      void phrases(int count, PhraseReport report) {
        for (var n = 0; n < count; n++) {
          crowd.resolvePhrase(sequence: i, passed: true, beat: i++ * 16.0, report: report);
        }
      }

      phrases(6, const PhraseReport(notes: 8, hits: 6, perfects: 0));
      final before = crowd.recentForm;
      expect(player.rungFor(BandInputs(form: before)), 1);
      phrases(5, const PhraseReport(notes: 8, hits: 8, perfects: 0));
      expect(crowd.fullSwingEarned, isFalse, reason: 'six scrapes of eleven hold the average down');
      expect(player.rungFor(BandInputs(form: crowd.recentForm)), 2);
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

    test('rungs change on a downbeat', () {
      final rungs = player.ladder;
      BandInputs rising(double bar) => BandInputs(form: bar < 8 ? 0 : .99);
      expect(rungs.first.clip.frames, contains(player.frameAt(7.5, rising)));
      expect(rungs.last.clip.frames, contains(player.frameAt(8, rising)));
    });

    test('under reduced motion each rung holds one drawing, and still differs', () {
      Set<String> held(double form) => {
        for (var b = 0.0; b < 16; b += .25)
          player.frameAt(b, (_) => BandInputs(form: form), reducedMotion: true),
      };
      expect(held(0), hasLength(1));
      expect(held(.99), hasLength(1));
      expect(held(0), isNot(held(.99)));
    });
  });

  test('a step in time never shows the pointing drawing', () {
    final frames = {
      for (var b = 0.0; b < 8; b += .05)
        ensembleClipFrame(CrowdClip.stepTouch, beat: b, duration: 2),
    };
    expect(frames, isNot(contains('step_touch_b')));
    expect(frames.length, greaterThanOrEqualTo(3));
    final level = _level();
    for (final p in level.scenery.band!.players) {
      expect(p.frames, isNot(contains('step_touch_b')), reason: p.id);
    }
    expect(level.floorDance!.frames, isNot(contains('step_touch_b')));
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
        // The call has begun, so these are this phrase's notes.
        advance(music.secondsAt(start + .5));
        if (session.phase == GardenPhase.cleared) break;
        final limbs = session.activeLimbs;
        final offsets = session.activeOffsets;
        for (var i = 0; i < limbs.length; i++) {
          advance(music.secondsAt(start + level.chart.callBeats + offsets[i]));
          expect(session.tap(limbs[i]).note, isNotNull);
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
      // The win's shot, through the real scene, on the beats that matter.
      final won = <ui.Image>[];
      final shot = level.exitShot!;
      scene.exitCodaBeat = last;
      for (final beat in [
        1.0,
        shot.walkTo - .25,
        shot.closeupFrom + .25,
        4.0,
        shot.contactBeat,
        shot.closeupTo - .25,
        shot.closeupTo + .1,
      ]) {
        scene.exitBeat = beat;
        scene.presentationBeat = last + beat;
        won.add(await still(scene));
      }
      scene.exitBeat = null;
      scene.presentationBeat = null;
      final winRecorder = ui.PictureRecorder();
      final winCanvas = ui.Canvas(winRecorder);
      for (final (i, image) in won.indexed) {
        winCanvas.drawImage(image, ui.Offset(i * 396.0, 0), ui.Paint());
      }
      final winSheet = await winRecorder.endRecording().toImage(396 * won.length, 844);
      final winPng = await winSheet.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/stills').createSync(recursive: true);
      File('build/stills/cool-crowd-win.png').writeAsBytesSync(winPng!.buffer.asUint8List());

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
