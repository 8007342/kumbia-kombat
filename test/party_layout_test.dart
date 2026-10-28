import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/party_layout.dart';

void main() {
  test(
    'scenery and anchors share centered cover on narrow and tall phones',
    () {
      for (final size in [(360.0, 640.0), (390.0, 844.0), (412.0, 915.0)]) {
        final viewport = PartyViewport(size.$1, size.$2);
        expect(viewport.logicalHeight * viewport.pixelsPerUnit, size.$2);
        final rect = viewport.backgroundRect;
        expect(rect.width, greaterThanOrEqualTo(180));
        expect(rect.height, greaterThanOrEqualTo(viewport.logicalHeight));
        final center = viewport.project(const PartyPoint(.5, .5));
        expect(center.x, closeTo(90, 1e-9));
        expect(center.y, closeTo(viewport.logicalHeight / 2, 1e-9));
        for (final point in [
          const PartyPoint(.27, .38),
          const PartyPoint(.71, .44),
        ]) {
          final restored = viewport.unproject(viewport.project(point));
          expect(restored.x, closeTo(point.x, 1e-9));
          expect(restored.y, closeTo(point.y, 1e-9));
        }
      }
    },
  );

  test(
    'scaling follows floor distance and keeps seated support on its chair',
    () {
      final viewport = PartyViewport(360, 640);
      for (final room in partyRoomLayouts.values) {
        expect(
          room.floor.standingHeightAt(.55),
          greaterThan(room.floor.standingHeightAt(.40)),
        );
        expect(
          room.floor.standingHeightAt(.40, stature: .25),
          closeTo(room.floor.standingHeightAt(.40) / 4, 1e-9),
        );
        for (final slot in room.guests) {
          final guest = room.projectSlot(viewport, slot);
          expect(guest.standingHeight, greaterThan(0));
          expect(guest.seat.y, lessThan(guest.floor.y));
          expect(
            guest.spriteScale(40) * 40,
            closeTo(guest.standingHeight, 1e-9),
          );
          if (slot.seated) {
            final chair = room.props.singleWhere(
              (prop) => prop.id == slot.homePropId,
            );
            final floor = viewport.project(chair.floor);
            expect(floor.x, guest.floor.x);
            expect(floor.y, guest.floor.y);
          }
        }
      }
    },
  );

  test(
    'inspected rooms retain twelve seated guests with persistent chairs',
    () {
      for (final id in ['garden', 'bar']) {
        final room = partyRoomLayouts[id]!;
        expect(room.calibration, PartyCalibration.inspectedStarter);
        expect(
          room.guests.map((slot) => slot.id).toSet().length,
          room.guests.length,
        );
        expect(
          room.guests
              .map((slot) => slot.interestIndex)
              .whereType<int>()
              .toSet(),
          Set<int>.from(List.generate(12, (i) => i)),
        );
        expect(
          room.guests
              .where((slot) => slot.seated && !slot.chairIncluded)
              .length,
          12,
        );
      }
      for (final id in ['cool-crowd', 'restroom', 'vip']) {
        expect(
          partyRoomLayouts[id]!.calibration,
          PartyCalibration.unverifiedStoryboard,
        );
      }
    },
  );

  test('chair support and stature are independent of seated sprite bounds', () {
    final viewport = PartyViewport(360, 640);
    for (final room in partyRoomLayouts.values) {
      for (final slot in room.guests) {
        final guest = room.projectSlot(viewport, slot);
        expect(
          guest.floor.y - guest.seat.y,
          closeTo(guest.standingHeight * .37, 1e-9),
        );
        final chair = room.props.singleWhere(
          (prop) => prop.id == slot.homePropId,
        );
        expect(chair.heightInAdults, .80);
        expect(chair.widthInAdults, .53);
        expect(slot.paletteIndex, inInclusiveRange(0, 3));
      }
    }
  });

  test(
    'ambient life is bounded, continuous, independently phased and pausable',
    () {
      for (var tick = 0; tick < 6000; tick++) {
        final time = tick / 60;
        final sample = partyAmbientAt(time);
        final next = partyAmbientAt(time + 1 / 60);
        expect(sample.windRadians.abs(), lessThanOrEqualTo(.026));
        expect(sample.lightGain, inInclusiveRange(.88, 1));
        expect((next.lightGain - sample.lightGain).abs(), lessThan(.001));
        expect(partyAmbientAt(time).lightGain, sample.lightGain);
      }
      expect(
        partyAmbientAt(3, instance: 0).windRadians,
        isNot(partyAmbientAt(3, instance: 1).windRadians),
      );
      expect(partyAmbientAt(3, reducedMotion: true).windRadians, 0);
      expect(partyAmbientAt(300, reducedMotion: true).lightGain, .94);
    },
  );

  test('invalid viewport and floor data fail explicitly', () {
    expect(() => PartyViewport(0, 640), throwsArgumentError);
    expect(() => PartyViewport(360, double.nan), throwsArgumentError);
    expect(
      () => partyRoomLayouts['garden']!.floor.scaleAt(.2),
      throwsArgumentError,
    );
    expect(() => partyAmbientAt(double.infinity), throwsArgumentError);
  });
}
