import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/room_departure.dart';

void main() {
  test(
    'routes stay within authored travel bounds and land at the threshold',
    () {
      for (final route in roomDepartures.values) {
        expect(route.waypoints.first.progress, 0);
        expect(route.waypoints.last.progress, 1);
        for (var i = 1; i < route.waypoints.length; i++) {
          expect(
            route.waypoints[i].progress,
            greaterThan(route.waypoints[i - 1].progress),
          );
        }
        final poses = route.waypoints.map((waypoint) => waypoint.pose).toList();
        final minX = poses.map((pose) => pose.x).reduce(math.min);
        final maxX = poses.map((pose) => pose.x).reduce(math.max);
        final minY = poses.map((pose) => pose.y).reduce(math.min);
        final maxY = poses.map((pose) => pose.y).reduce(math.max);
        for (var frame = 0; frame <= 240; frame++) {
          final pose = route.sample(frame / 240);
          expect(pose.x, inInclusiveRange(minX, maxX));
          expect(pose.y, inInclusiveRange(minY, maxY));
          expect(pose.scale.isFinite && pose.scale > 0, isTrue);
        }
        final start = route.sample(-1);
        expect(start.x, poses.first.x);
        expect(start.y, poses.first.y);
        expect(route.sample(1), same(poses.last));
        expect(route.sample(2), same(poses.last));
      }
    },
  );

  test('view changes use the authored corner and keep spatial continuity', () {
    final garden = roomDepartures['garden']!;
    expect(garden.sample(.249999).facing, DepartureFacing.sideRight);
    expect(garden.sample(.25).facing, DepartureFacing.rear);
    expect(garden.sample(.249999).x, closeTo(garden.sample(.25).x, .00001));
    expect(garden.sample(.249999).y, closeTo(garden.sample(.25).y, .00001));
  });

  test(
    'reduced motion holds a meaningful departure pose through the bridge',
    () {
      for (final route in roomDepartures.values) {
        for (final progress in [0.0, .25, .5, .75, 1.0]) {
          expect(
            route.sample(progress, reducedMotion: true),
            same(route.waypoints.first.pose),
          );
        }
      }
    },
  );

  test('invalid musical progress cannot silently teleport a character', () {
    final garden = roomDepartures['garden']!;
    for (final invalid in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(() => garden.sample(invalid), throwsArgumentError);
    }
  });
}
