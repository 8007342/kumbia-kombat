import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/challenger_choreography.dart';
import 'package:kumbia_kombat/gameplay/crowd_interest.dart';
import 'package:kumbia_kombat/gameplay/ensemble_sprites.dart';
import 'package:kumbia_kombat/gameplay/party_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('hero hands back the floor within the final rest in pose order', () {
    expect(
      [0.0, .3, .6, .9].map(
        (progress) => ensembleHeroHandoverFrame(
          role: progress < .25
              ? PlayerDanceRole.finishing
              : PlayerDanceRole.waiting,
          responseProgress: progress,
        ),
      ),
      ['spin_front', 'profile', 'rear_turn', 'rear_idle'],
    );
    for (final progress in [-.1, 1.1, double.nan]) {
      expect(
        ensembleHeroHandoverFrame(
          role: PlayerDanceRole.finishing,
          responseProgress: progress,
        ),
        isNull,
      );
    }
    for (final progress in [.1, .4, .7, 1.0]) {
      expect(
        ensembleHeroHandoverFrame(
          role: PlayerDanceRole.finishing,
          responseProgress: progress,
          activeMove: true,
        ),
        isNull,
      );
      expect(
        ensembleHeroHandoverFrame(
          role: PlayerDanceRole.finishing,
          responseProgress: progress,
          activeFlourish: true,
        ),
        isNull,
      );
      expect(
        ensembleHeroHandoverFrame(
          role: PlayerDanceRole.celebrating,
          responseProgress: progress,
        ),
        isNull,
      );
      expect(
        ensembleHeroHandoverFrame(
          role: PlayerDanceRole.finishing,
          responseProgress: progress,
          reducedMotion: true,
        ),
        progress < .5 ? 'front_idle' : 'rear_idle',
      );
    }
  });
  Map<String, dynamic> json() =>
      jsonDecode(File('assets/art/ensemble/manifest.json').readAsStringSync())
          as Map<String, dynamic>;

  test(
    'all nine actual sheets supply 456 explicit bounded transparent frames',
    () async {
      final manifest = EnsembleManifest.fromJson(json());
      expect(manifest.atlases.keys, containsAll(EnsembleManifest.atlasIds));
      expect(
        manifest.atlases.values.fold(
          0,
          (count, atlas) => count + atlas.art.frames.length,
        ),
        456,
      );
      for (final definition in manifest.atlases.values) {
        final codec = await ui.instantiateImageCodec(
          File('assets/art/ensemble/${definition.art.image}').readAsBytesSync(),
        );
        final image = (await codec.getNextFrame()).image;
        EnsembleAtlas(definition, image);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var transparent = 0;
        for (var i = 3; i < bytes.lengthInBytes; i += 4) {
          if (bytes.getUint8(i) == 0) transparent++;
        }
        expect(
          transparent / (image.width * image.height),
          greaterThan(.3),
          reason:
              '${definition.art.image} must not show contact-sheet backdrops',
        );
        image.dispose();
        codec.dispose();
      }
    },
  );

  test(
    'missing art and malformed mirror metadata fail without static fallback',
    () {
      final missing = json();
      (missing['atlases'] as Map).remove('gatekeeper');
      expect(() => EnsembleManifest.fromJson(missing), throwsFormatException);
      final badFrame = json();
      (badFrame['atlases']['guest1']['frames'] as Map).remove('sit_down_d');
      expect(() => EnsembleManifest.fromJson(badFrame), throwsFormatException);
      final badMirror = json();
      badMirror['atlases']['bartender']['frames']['right_foot']['mirror'] =
          'yes';
      expect(() => EnsembleManifest.fromJson(badMirror), throwsFormatException);
      final outside = json();
      outside['atlases']['life']['frames']['candle_a']['rect'] = [
        99999,
        0,
        10,
        10,
      ];
      expect(() => EnsembleManifest.fromJson(outside), throwsFormatException);
    },
  );

  test('anatomical correction composes with room facing by XOR', () {
    final data = json();
    for (final id in ['gatekeeper', 'bartender']) {
      // The v3 sheets draw each side, so mirroring is only exercised here.
      final frames = data['atlases'][id]['frames'] as Map;
      expect(frames['right_foot']['mirror'], isNot(true));
      frames['right_foot']['mirror'] = true;
    }
    final manifest = EnsembleManifest.fromJson(data);
    for (final id in ['gatekeeper', 'bartender']) {
      final atlas = manifest.atlases[id]!;
      expect(atlas.flipFor('right_foot'), isTrue);
      expect(atlas.flipFor('right_foot', facingFlip: true), isFalse);
      expect(atlas.flipFor('left_foot'), isFalse);
      expect(atlas.flipFor('left_foot', facingFlip: true), isTrue);
    }
  });

  CrowdGuestSnapshot snapshot(
    CrowdClip clip,
    double beat, {
    bool transition = false,
    double duration = 2,
  }) => CrowdGuestSnapshot(
    interest: .5,
    state: CrowdGuestState.following,
    styleEnergy: 0,
    reactionBeat: 0,
    clip: clip,
    clipBeat: beat,
    clipDurationBeats: duration,
    transitioning: transition,
    standing: false,
    archetypeIndex: 0,
    paletteIndex: 0,
    phaseOffset: 0,
  );

  test(
    'stand and sit play all four keys once; loops preserve authored timing',
    () {
      for (final entry in {
        CrowdClip.standUp: 'stand_up',
        CrowdClip.sitDown: 'sit_down',
      }.entries) {
        expect(
          [
            for (final time in [0.0, .5, 1.0, 1.5, 2.0, 3.0])
              ensembleGuestFrame(snapshot(entry.key, time, transition: true)),
          ],
          [
            '${entry.value}_a',
            '${entry.value}_b',
            '${entry.value}_c',
            '${entry.value}_d',
            '${entry.value}_d',
            '${entry.value}_d',
          ],
        );
      }
      expect(
        ensembleGuestFrame(snapshot(CrowdClip.stepTouch, 2.0)),
        'step_touch_a',
      );
      expect(
        ensembleGuestFrame(snapshot(CrowdClip.seatedIdle, 4, duration: 8)),
        'seated_idle_b',
      );
      expect(
        ensembleGuestFrame(snapshot(CrowdClip.seatedFollow, 1)),
        'seated_follow_b',
      );
      expect(
        ensembleGuestFrame(
          snapshot(CrowdClip.seatedFollow, 1),
          reducedMotion: true,
        ),
        'seated_follow_a',
      );
      expect(
        ensembleGuestFrame(
          snapshot(CrowdClip.standUp, 1, transition: true),
          reducedMotion: true,
        ),
        'stand_up_c',
      );
    },
  );

  test(
    'seated and standing crops retain one standing stature and floor anchor',
    () {
      final manifest = EnsembleManifest.fromJson(json());
      for (final size in [(360.0, 640.0), (390.0, 844.0)]) {
        final viewport = PartyViewport(size.$1, size.$2);
        for (final room in [
          partyRoomLayouts['garden']!,
          partyRoomLayouts['bar']!,
        ]) {
          for (final slot in room.guests) {
            final guest = room.projectSlot(viewport, slot);
            final atlas = manifest.atlases['guest${slot.archetype}']!;
            final scale = guest.spriteScale(
              atlas.nativeHeight('standing_idle_a'),
            );
            expect(
              scale * atlas.nativeHeight('standing_idle_a'),
              closeTo(guest.standingHeight, 1e-9),
            );
            for (final frameId in ensembleGuestFrameIds) {
              final frame = atlas.art.frames[frameId]!;
              final floor = ui.Offset(guest.floor.x, guest.floor.y);
              final destination = frame.destination(floor, scale);
              final actual =
                  destination.topLeft +
                  frame.anchor * (scale / frame.pixelsPerUnit);
              expect(actual.dx, closeTo(floor.dx, 1e-9));
              expect(actual.dy, closeTo(floor.dy, 1e-9));
            }
            final chair = room.props.singleWhere(
              (p) => p.id == slot.homePropId,
            );
            expect(viewport.project(chair.floor).y, guest.floor.y);
          }
        }
      }
    },
  );

  test(
    'depth order keeps furniture behind its person and nearby actors in front',
    () {
      final order = [
        (floorY: 150.0, layer: 10, id: 'robot'),
        (floorY: 100.0, layer: 10, id: 'guest'),
        (floorY: 100.0, layer: 0, id: 'chair'),
        (floorY: 75.0, layer: 0, id: 'umbrella'),
        (floorY: 120.0, layer: 10, id: 'challenger'),
      ]..sort(compareEnsembleDepth);
      expect(order.map((o) => o.id), [
        'umbrella',
        'chair',
        'guest',
        'challenger',
        'robot',
      ]);
    },
  );

  test(
    'ambient loops use different local periods and hold when clock is frozen',
    () {
      for (final kind in ['plant', 'umbrella', 'candle', 'waiter']) {
        final frames = {
          for (var i = 0; i < 200; i++) ensembleAmbientFrame(kind, i / 10),
        };
        expect(frames, {'${kind}_a', '${kind}_b', '${kind}_c', '${kind}_d'});
        expect(ensembleAmbientFrame(kind, 3), ensembleAmbientFrame(kind, 3));
        expect(
          ensembleAmbientFrame(kind, 100, reducedMotion: true),
          '${kind}_a',
        );
      }
      expect(
        ensembleAmbientFrame('plant', 2),
        isNot(ensembleAmbientFrame('plant', 2, instance: 1)),
      );
    },
  );
}
