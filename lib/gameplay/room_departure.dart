/// Authored views: choose a matching sprite clip, never rotate a flat sprite.
enum DepartureFacing { rear, sideRight, front }

class DeparturePose {
  const DeparturePose(this.x, this.y, this.scale, this.facing);

  /// Normalized world coordinates at the character's foot anchor, not HUD space.
  final double x;
  final double y;
  final double scale;
  final DepartureFacing facing;
}

class DepartureWaypoint {
  const DepartureWaypoint(this.progress, this.pose);
  final double progress;
  final DeparturePose pose;
}

/// Bridge progress comes from its transport beat / authored length. A renderer
/// samples this model; it cannot advance music, award clearance, or move cues.
class RoomDeparture {
  const RoomDeparture({
    required this.roomId,
    required this.nextRoomId,
    required this.bridgeScoreId,
    required this.threshold,
    required this.waypoints,
  });

  final String roomId;
  final String nextRoomId;
  final String bridgeScoreId;
  final String threshold;
  final List<DepartureWaypoint> waypoints;

  DeparturePose sample(double bridgeProgress, {bool reducedMotion = false}) {
    if (!bridgeProgress.isFinite) {
      throw ArgumentError.value(bridgeProgress, 'bridgeProgress');
    }
    final progress = bridgeProgress.clamp(0.0, 1.0);
    // An authored held view followed by destination adoption conveys travel
    // without a zoom or a moving camera in reduced-motion mode.
    if (reducedMotion) return waypoints.first.pose;
    if (progress >= 1) return waypoints.last.pose;
    for (var i = 1; i < waypoints.length; i++) {
      final from = waypoints[i - 1];
      final to = waypoints[i];
      if (progress < to.progress) {
        final t = (progress - from.progress) / (to.progress - from.progress);
        final eased = t * t * (3 - 2 * t);
        double mix(double a, double b) => a + (b - a) * eased;
        return DeparturePose(
          mix(from.pose.x, to.pose.x),
          mix(from.pose.y, to.pose.y),
          mix(from.pose.scale, to.pose.scale),
          from.pose.facing,
        );
      }
    }
    return waypoints.last.pose;
  }
}

/// Only garden is currently connected to a playable destination. Later routes
/// are storyboard data, not declarations that those rooms or sprite clips ship.
const roomDepartures = <String, RoomDeparture>{
  'garden': RoomDeparture(
    roomId: 'garden',
    nextRoomId: 'bar',
    bridgeScoreId: 'garden_to_bar',
    threshold: 'copper garden door',
    waypoints: [
      DepartureWaypoint(
        0,
        DeparturePose(.50, .67, 1, DepartureFacing.sideRight),
      ),
      DepartureWaypoint(
        .25,
        DeparturePose(.61, .64, .96, DepartureFacing.rear),
      ),
      DepartureWaypoint(1, DeparturePose(.64, .39, .55, DepartureFacing.rear)),
    ],
  ),
  'bar': RoomDeparture(
    roomId: 'bar',
    nextRoomId: 'cool-crowd',
    bridgeScoreId: 'bar_to_crowd',
    threshold: 'counter-end passage',
    waypoints: [
      DepartureWaypoint(
        0,
        DeparturePose(.50, .67, 1, DepartureFacing.sideRight),
      ),
      DepartureWaypoint(
        .65,
        DeparturePose(.82, .64, .95, DepartureFacing.rear),
      ),
      DepartureWaypoint(1, DeparturePose(.88, .48, .70, DepartureFacing.rear)),
    ],
  ),
  'cool-crowd': RoomDeparture(
    roomId: 'cool-crowd',
    nextRoomId: 'restroom',
    bridgeScoreId: 'crowd_to_restroom',
    threshold: 'opened dance circle and corridor',
    waypoints: [
      DepartureWaypoint(0, DeparturePose(.50, .67, 1, DepartureFacing.front)),
      DepartureWaypoint(.25, DeparturePose(.50, .67, 1, DepartureFacing.rear)),
      DepartureWaypoint(1, DeparturePose(.46, .34, .48, DepartureFacing.rear)),
    ],
  ),
  'restroom': RoomDeparture(
    roomId: 'restroom',
    nextRoomId: 'vip',
    bridgeScoreId: 'restroom_to_vip',
    threshold: 'restroom door wipe, then VIP stair',
    waypoints: [
      DepartureWaypoint(
        0,
        DeparturePose(.50, .67, 1, DepartureFacing.sideRight),
      ),
      DepartureWaypoint(
        .50,
        DeparturePose(.79, .62, .90, DepartureFacing.rear),
      ),
      DepartureWaypoint(1, DeparturePose(.73, .35, .50, DepartureFacing.rear)),
    ],
  ),
};
