import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/crowd_interest.dart';
import 'package:kumbia_kombat/gameplay/party_sprites.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> manifestJson() =>
      jsonDecode(File('assets/art/party/manifest.json').readAsStringSync())
          as Map<String, dynamic>;

  test(
    'reviewed manifest covers every selected clip in the actual PNGs',
    () async {
      final manifest = PartySpriteManifest.fromJson(manifestJson());
      for (final definition in [manifest.hero, manifest.crowd]) {
        final bytes = File('assets/art/party/${definition.image}')
            .readAsBytesSync();
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        PartySpriteAtlas(definition, image);
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        expect(
          pixels.getUint8(3),
          0,
          reason: '${definition.image} corner alpha',
        );
        var transparent = 0;
        for (var i = 3; i < pixels.lengthInBytes; i += 4) {
          if (pixels.getUint8(i) == 0) transparent++;
        }
        expect(
          transparent / (image.width * image.height),
          greaterThan(.35),
          reason: 'Characters must not draw opaque contact-sheet backdrops.',
        );
        image.dispose();
        codec.dispose();
      }
      expect(
        manifest.hero.frames['left_hand']!.source,
        isNot(manifest.hero.frames['right_hand']!.source),
      );
      expect(
        manifest.hero.frames['left_foot']!.source,
        isNot(manifest.hero.frames['right_foot']!.source),
      );
      expect(
        manifest.crowd.frames.values.map((f) => f.source).toSet(),
        hasLength(18),
      );
    },
  );

  test(
    'missing poses, invalid anchors and out-of-sheet rectangles fail loudly',
    () {
      final missing = manifestJson();
      (missing['atlases']['hero']['frames'] as Map).remove('left_hand');
      expect(
        () => PartySpriteManifest.fromJson(missing),
        throwsFormatException,
      );
      final overflow = manifestJson();
      overflow['atlases']['crowd']['frames']['guest0_clap']['rect'] = [
        0,
        0,
        9999,
        40,
      ];
      expect(
        () => PartySpriteManifest.fromJson(overflow),
        throwsFormatException,
      );
      final badAnchor = manifestJson();
      badAnchor['atlases']['hero']['frames']['rear_idle']['anchor'] = [-1, 10];
      expect(
        () => PartySpriteManifest.fromJson(badAnchor),
        throwsFormatException,
      );
      final badScale = manifestJson();
      badScale['atlases']['hero']['frames']['rear_idle']['pixelsPerUnit'] = 0;
      expect(
        () => PartySpriteManifest.fromJson(badScale),
        throwsFormatException,
      );
    },
  );

  test(
    'different crop rectangles keep their measured ground anchors fixed',
    () {
      const ground = ui.Offset(180, 400);
      for (final frame in [
        const PartySpriteFrame(
          ui.Rect.fromLTWH(20, 30, 80, 120),
          ui.Offset(35, 115),
          4,
        ),
        const PartySpriteFrame(
          ui.Rect.fromLTWH(250, 5, 140, 160),
          ui.Offset(65, 150),
          5,
        ),
      ]) {
        final drawn = frame.destination(ground, 2);
        final anchorOnScreen =
            drawn.topLeft + frame.anchor * (2 / frame.pixelsPerUnit);
        expect(anchorOnScreen, ground);
      }
    },
  );

  String hero({
    double beat = 2,
    double phaseBeat = 2,
    bool front = true,
    bool walking = false,
    bool reducedMotion = false,
    Limb? action,
    double actionAge = 10,
    double flourishAge = 10,
  }) => heroSpriteFrame(
    beat: beat,
    phaseBeat: phaseBeat,
    front: front,
    walking: walking,
    reducedMotion: reducedMotion,
    actionAge: actionAge,
    action: action,
    flourishAge: flourishAge,
  );

  test(
    'walk, groove and spin select authored silhouettes rather than transforms',
    () {
      expect(
        [for (var i = 0; i < 4; i++) hero(beat: i * .25, walking: true)]
            .toSet(),
        containsAll(['rear_walk_left', 'rear_walk_right', 'rear_idle']),
      );
      expect(
        [for (var i = 0; i < 4; i++) hero(beat: 2 + i * .25)].toSet(),
        containsAll([
          'front_idle',
          'groove_left',
          'groove_right',
          'anticipate',
        ]),
      );
      expect(
        [for (var i = 0; i < 8; i++) hero(flourishAge: i * .125)].toSet(),
        containsAll(['spin_front', 'profile', 'spin_rear', 'rear_finish']),
      );
      expect(hero(front: false), 'rear_idle');
    },
  );

  test(
    'required accents interrupt flourish and recover without turning backward',
    () {
      for (final entry in {
        Limb.leftHand: 'left_hand',
        Limb.rightHand: 'right_hand',
        Limb.leftFoot: 'left_foot',
        Limb.rightFoot: 'right_foot',
      }.entries) {
        expect(
          hero(action: entry.key, actionAge: .1, flourishAge: .5),
          entry.value,
        );
      }
      expect(hero(action: Limb.leftHand, actionAge: .35), 'anticipate');
      expect(hero(action: Limb.leftHand, actionAge: .5), 'front_idle');
      expect(
        hero(action: Limb.leftHand, actionAge: .7, phaseBeat: .4),
        isNot(anyOf('rear_turn', 'profile')),
      );
      expect(
        hero(action: Limb.leftHand, actionAge: .3, flourishAge: .1),
        'spin_front',
      );
    },
  );

  String guest({
    CrowdGuestState state = CrowdGuestState.participating,
    double beat = 0,
    double style = 0,
    bool settled = false,
    bool escorting = false,
    bool reducedMotion = false,
  }) => guestSpriteFrame(
    archetype: 1,
    state: state,
    beat: beat,
    styleEnergy: style,
    settled: settled,
    escorting: escorting,
    reducedMotion: reducedMotion,
  );

  test(
    'crowd follows individual state, style and settling with multiple poses',
    () {
      expect(
        [for (var i = 0; i < 4; i++) guest(beat: i * .5)].toSet(),
        containsAll(['guest1_step_left', 'guest1_step_right', 'guest1_clap']),
      );
      expect(guest(state: CrowdGuestState.occupied), 'guest1_occupied');
      expect(guest(state: CrowdGuestState.occupied, style: 1), 'guest1_clap');
      expect(
        guest(state: CrowdGuestState.celebrating, settled: true),
        'guest1_occupied',
      );
      expect(guest(settled: true, escorting: true, beat: .5), 'guest1_cheer');
      expect(
        guest(reducedMotion: true, beat: 0),
        guest(reducedMotion: true, beat: 10),
      );
      expect(
        hero(reducedMotion: true, beat: 0),
        hero(reducedMotion: true, beat: 10),
      );
    },
  );
}
