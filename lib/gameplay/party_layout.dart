import 'dart:math' as math;

class PartyPoint {
  const PartyPoint(this.x, this.y);
  final double x, y;
}

class PartyRect {
  const PartyRect(this.left, this.top, this.width, this.height);
  final double left, top, width, height;
}

/// One centered cover transform for painted scenery, actors and prop anchors.
/// Values returned here are logical units. Scale the world canvas once by
/// [pixelsPerUnit]; the Flutter input/HUD overlay must remain outside it.
class PartyViewport {
  PartyViewport(
    this.width,
    this.height, {
    this.sourceWidth = 1024,
    this.sourceHeight = 1536,
    this.overscan = 0,
  }) {
    for (final value in [width, height, sourceWidth, sourceHeight]) {
      if (!value.isFinite || value <= 0) throw ArgumentError.value(value);
    }
    if (!overscan.isFinite || overscan < 0) {
      throw ArgumentError.value(overscan, 'overscan');
    }
  }

  static const logicalWidth = 180.0;
  final double width, height, sourceWidth, sourceHeight;

  /// Logical world units, not physical display pixels.
  final double overscan;
  double get logicalHeight => height / pixelsPerUnit;
  double get pixelsPerUnit => width / logicalWidth;
  double get sourceScale => math.max(
    (logicalWidth + overscan * 2) / sourceWidth,
    (logicalHeight + overscan * 2) / sourceHeight,
  );
  PartyRect get backgroundRect => PartyRect(
    (logicalWidth - sourceWidth * sourceScale) / 2,
    (logicalHeight - sourceHeight * sourceScale) / 2,
    sourceWidth * sourceScale,
    sourceHeight * sourceScale,
  );
  PartyPoint project(PartyPoint sourceNormalized) {
    final rect = backgroundRect;
    return PartyPoint(
      rect.left + sourceNormalized.x * rect.width,
      rect.top + sourceNormalized.y * rect.height,
    );
  }

  PartyPoint unproject(PartyPoint logical) {
    final rect = backgroundRect;
    return PartyPoint(
      (logical.x - rect.left) / rect.width,
      (logical.y - rect.top) / rect.height,
    );
  }

  double sourceHeightToLogical(double normalizedHeight) =>
      normalizedHeight * sourceHeight * sourceScale;
}

/// An art-directed single-plane approximation, not recovered camera geometry.
/// All values use fractions of the SOURCE image height, before cover cropping.
class PartyFloorPlane {
  const PartyFloorPlane({
    required this.horizonY,
    required this.referenceFootY,
    required this.referenceHeight,
    this.vanishingX = .5,
  }) : assert(horizonY >= 0 && horizonY < referenceFootY),
       assert(referenceFootY <= 1 && referenceHeight > 0);
  final double horizonY, referenceFootY, referenceHeight, vanishingX;

  double scaleAt(double footY) {
    if (!footY.isFinite || footY <= horizonY || footY > 1) {
      throw ArgumentError.value(footY, 'footY', 'Must be on the visible floor');
    }
    return (footY - horizonY) / (referenceFootY - horizonY);
  }

  double standingHeightAt(double footY, {double stature = 1}) {
    if (!stature.isFinite || stature <= 0) {
      throw ArgumentError.value(stature, 'stature');
    }
    return referenceHeight * scaleAt(footY) * stature;
  }
}

enum PartyActivity { seatedChat, seatedDrink, standingChat, sipping, waiting }

enum PartyPropKind { chair, stool, table, umbrella, drink, candle, plant }

/// What a guest sits on. [painted] is part of the plate, so nothing is drawn.
enum PartySeat {
  chair,
  stool,
  painted,

  /// On their feet from the start, on a dance floor. No seat is drawn.
  standing,
}

enum PartyCalibration { inspectedStarter, unverifiedStoryboard }

class PartyGuestSlot {
  const PartyGuestSlot(
    this.id,
    this.floor, {
    required this.activity,
    this.archetype = 0,
    this.interestIndex,
    this.homePropId,
    this.facingRight = true,
    this.stature = 1,
    this.seatHeightInAdults = .37,
    this.paletteIndex = 0,
    this.chairIncluded = false,
    this.partTo,
    this.partDelay = 0,
  });

  /// Where this dance-floor guest moves to when the floor opens, or null if they
  /// dance in place. Their [floor] is where they start.
  final PartyPoint? partTo;

  /// Beats after the first of them starts: see `CrowdParting`.
  final double partDelay;
  final String id;
  final PartyPoint floor;
  final PartyActivity activity;
  final int archetype;

  /// Stable mapping into the twelve-person interest model; rendering never
  /// changes that model.
  final int? interestIndex;
  final String? homePropId;
  final bool facingRight;
  final double stature;
  final double seatHeightInAdults;
  final int paletteIndex;
  final bool chairIncluded;
  bool get seated =>
      activity == PartyActivity.seatedChat ||
      activity == PartyActivity.seatedDrink;

  /// On a dance floor rather than in a seat.
  bool get onFloor => activity == PartyActivity.standingChat;
}

class PartyPropSlot {
  const PartyPropSlot(
    this.id,
    this.kind,
    this.floor, {
    this.heightInAdults = .45,
    this.widthInAdults = .45,
    this.bakedIntoStarter = false,
  });
  final String id;
  final PartyPropKind kind;
  final PartyPoint floor;
  final double heightInAdults, widthInAdults;
  final bool bakedIntoStarter;
}

class ProjectedPartyGuest {
  const ProjectedPartyGuest(
    this.slot,
    this.floor,
    this.standingHeight,
    this.seat,
  );
  final PartyGuestSlot slot;

  /// Shadow/depth-sort anchor never follows breathing, cheering or head bobs.
  final PartyPoint floor;
  final double standingHeight;

  /// Art-review support point. Runtime seated/standing clips both retain their
  /// original floor pivot; do not move a floor-anchored sprite to this point.
  final PartyPoint seat;

  double spriteScale(double nativeStandingHeight) {
    if (!nativeStandingHeight.isFinite || nativeStandingHeight <= 0) {
      throw ArgumentError.value(nativeStandingHeight, 'nativeStandingHeight');
    }
    return standingHeight / nativeStandingHeight;
  }
}

class PartyRoomLayout {
  const PartyRoomLayout({
    required this.id,
    required this.floor,
    required this.guests,
    this.props = const [],
    this.calibration = PartyCalibration.unverifiedStoryboard,
  });
  final String id;
  final PartyFloorPlane floor;
  final List<PartyGuestSlot> guests;
  final List<PartyPropSlot> props;
  final PartyCalibration calibration;

  /// [at] is where they are now, for someone who moves. Their size follows it.
  ProjectedPartyGuest projectSlot(
    PartyViewport viewport,
    PartyGuestSlot slot, {
    PartyPoint? at,
  }) {
    final place = at ?? slot.floor;
    final ground = viewport.project(place);
    final height = viewport.sourceHeightToLogical(
      floor.standingHeightAt(place.y, stature: slot.stature),
    );
    return ProjectedPartyGuest(
      slot,
      ground,
      height,
      PartyPoint(ground.x, ground.y - height * slot.seatHeightInAdults),
    );
  }
}

List<PartyGuestSlot> seatedGuestSlots(
  String room,
  List<PartyPoint> anchors, {
  List<PartySeat>? seats,
  List<PartyPoint?>? partTo,
  List<double>? partDelays,
}) =>
    List.unmodifiable([
      for (var i = 0; i < anchors.length; i++)
        PartyGuestSlot(
          '$room-guest-$i',
          anchors[i],
          activity: seats?[i] == PartySeat.standing
              ? PartyActivity.standingChat
              : i.isEven
              ? PartyActivity.seatedChat
              : PartyActivity.seatedDrink,
          partTo: partTo?[i],
          partDelay: partDelays?[i] ?? 0,
          archetype: i % 3,
          interestIndex: i,
          paletteIndex: i ~/ 3,
          homePropId: '$room-chair-$i',
          // Someone who moves faces the way they'll end up, so they never flip.
          facingRight: (partTo?[i] ?? anchors[i]).x < .5,
          chairIncluded: seats?[i] == PartySeat.painted,
        ),
    ]);

final _gardenGuests = seatedGuestSlots('garden', const [
  // Foreground pair: allowed to crop at narrow edges, but their actual chair
  // and interest IDs remain the original slots 0–1.
  PartyPoint(.20, .610),
  PartyPoint(.80, .610),
  PartyPoint(.24, .460),
  PartyPoint(.76, .460),
  PartyPoint(.31, .408),
  PartyPoint(.69, .408),
  PartyPoint(.24, .360),
  PartyPoint(.31, .360),
  PartyPoint(.38, .360),
  PartyPoint(.62, .360),
  PartyPoint(.69, .360),
  PartyPoint(.76, .360),
]);
final _barGuests = seatedGuestSlots('bar', const [
  // Match the bar's steeper floor without duplicating people or chairs.
  PartyPoint(.20, .480),
  PartyPoint(.80, .480),
  PartyPoint(.23, .400),
  PartyPoint(.77, .400),
  PartyPoint(.31, .370),
  PartyPoint(.69, .370),
  PartyPoint(.23, .335),
  PartyPoint(.32, .335),
  PartyPoint(.41, .335),
  PartyPoint(.59, .335),
  PartyPoint(.68, .335),
  PartyPoint(.77, .335),
]);

List<PartyPropSlot> chairSlotsFor(
  List<PartyGuestSlot> guests, {
  List<PartySeat>? seats,
}) => [
  for (final (i, guest) in guests.indexed)
    if (seats?[i] == PartySeat.standing)
      ...const <PartyPropSlot>[]
    else if (seats != null && seats[i] != PartySeat.chair)
      PartyPropSlot(
        guest.homePropId!,
        PartyPropKind.stool,
        guest.floor,
        // Its seat meets the same .37 as a chair's, so the seated poses need no
        // new drawings: only the back goes, which is the clutter.
        heightInAdults: .39,
        widthInAdults: .3,
      )
    else
      PartyPropSlot(
        guest.homePropId!,
        PartyPropKind.chair,
        guest.floor,
        // Reviewed high-back source: 476 px tall, 317 px wide; its seat is
        // ~219 px above the floor. At .80 adult heights the seat sits at .368.
        heightInAdults: .80,
        widthInAdults: .53,
      ),
];

/// Storyboard layouts. The game reads layouts from `levels/*.json`; garden and
/// bar stay here as the frozen reference they are compared with.
final partyRoomLayouts = Map<String, PartyRoomLayout>.unmodifiable({
  'garden': PartyRoomLayout(
    id: 'garden',
    calibration: PartyCalibration.inspectedStarter,
    floor: const PartyFloorPlane(
      horizonY: .255,
      referenceFootY: .40,
      referenceHeight: .094,
    ),
    guests: _gardenGuests,
    props: List.unmodifiable([
      ...chairSlotsFor(_gardenGuests),
      const PartyPropSlot(
        'garden-table-left',
        PartyPropKind.table,
        PartyPoint(.31, .370),
        heightInAdults: .43,
        widthInAdults: .9,
      ),
      const PartyPropSlot(
        'garden-table-right',
        PartyPropKind.table,
        PartyPoint(.69, .370),
        heightInAdults: .43,
        widthInAdults: .9,
      ),
      const PartyPropSlot(
        'garden-umbrella-left',
        PartyPropKind.umbrella,
        PartyPoint(.30, .350),
        heightInAdults: 1.35,
        widthInAdults: 1.5,
      ),
      const PartyPropSlot(
        'garden-umbrella-right',
        PartyPropKind.umbrella,
        PartyPoint(.70, .350),
        heightInAdults: 1.35,
        widthInAdults: 1.5,
      ),
    ]),
  ),
  'bar': PartyRoomLayout(
    id: 'bar',
    calibration: PartyCalibration.inspectedStarter,
    floor: const PartyFloorPlane(
      horizonY: .205,
      referenceFootY: .40,
      referenceHeight: .23,
    ),
    guests: _barGuests,
    props: List.unmodifiable(chairSlotsFor(_barGuests)),
  ),
  // Future art contracts, not calibrated existing rooms.
  'cool-crowd': const PartyRoomLayout(
    id: 'cool-crowd',
    floor: PartyFloorPlane(
      horizonY: .24,
      referenceFootY: .43,
      referenceHeight: .12,
    ),
    guests: [],
  ),
  'restroom': const PartyRoomLayout(
    id: 'restroom',
    floor: PartyFloorPlane(
      horizonY: .23,
      referenceFootY: .42,
      referenceHeight: .13,
    ),
    guests: [],
  ),
  'vip': const PartyRoomLayout(
    id: 'vip',
    floor: PartyFloorPlane(
      horizonY: .25,
      referenceFootY: .42,
      referenceHeight: .11,
    ),
    guests: [],
  ),
});

class PartyAmbientSample {
  const PartyAmbientSample(this.windRadians, this.lightGain);
  final double windRadians, lightGain;
}

/// Local life is independent of the music and never signals a judgment.
/// Supply a foreground-only clock which freezes while paused/backgrounded.
PartyAmbientSample partyAmbientAt(
  double foregroundSeconds, {
  int instance = 0,
  bool reducedMotion = false,
}) {
  if (!foregroundSeconds.isFinite || foregroundSeconds < 0) {
    throw ArgumentError.value(foregroundSeconds, 'foregroundSeconds');
  }
  if (reducedMotion) return const PartyAmbientSample(0, .94);
  final phase = instance * 2.399963229728653;
  return PartyAmbientSample(
    .018 * math.sin(foregroundSeconds * .55 + phase) +
        .008 * math.sin(foregroundSeconds * .23 + phase * .7),
    .94 +
        .04 * math.sin(foregroundSeconds * .7 + phase) +
        .02 * math.sin(foregroundSeconds * 1.1 + phase * .6),
  );
}
