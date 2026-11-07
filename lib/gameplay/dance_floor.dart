import 'dart:math' as math;

import 'crowd_interest.dart';
import 'ensemble_sprites.dart';
import 'party_layout.dart';

/// A looped run of drawings, on the music's beat.
class FloorClip {
  const FloorClip(this.frames, this.beatsPerFrame);
  final List<String> frames;
  final double beatsPerFrame;

  String at(double beat, {bool reducedMotion = false}) {
    if (reducedMotion || !beat.isFinite) return frames.first;
    final step = (beat / beatsPerFrame).floor() % frames.length;
    return frames[step];
  }
}

/// How the people on a dance floor make way when the fight starts. A pure
/// function of the music's beat: they part once, in beats, and a pause or a retry
/// can't move anybody but by moving the music. Nothing reads it back.
class CrowdParting {
  const CrowdParting({
    required this.from,
    required this.beats,
    required this.stagger,
    required this.slowTo,
  });

  /// The beat of the level the first of them starts to slow and move.
  final double from;

  /// How long each takes, from the moment they start.
  final double beats;

  /// Between the first to start and the last, nearest the dancer first.
  final double stagger;

  /// Their dance's speed at the middle of their move, as a share of the music's.
  final double slowTo;

  /// Beat by which everyone has arrived.
  double get end => from + stagger + beats;

  /// How far along their way someone is, 0 to 1, with no speed at either end.
  /// Reduced motion holds them, then cuts: the same story, nothing sliding.
  double along(double beat, double delay, {bool reducedMotion = false}) {
    final u = (beat - from - delay) / beats;
    if (reducedMotion) return u >= .5 ? 1 : 0;
    return CrowdEngagement.reveal(u);
  }

  /// The beat their own dance is at. It runs with the music, eases to [slowTo]
  /// through the move and back, and never jumps: this is the integral of that
  /// speed, so the drawings stay in order and only take longer.
  double danceBeat(double beat, double delay) {
    final u = ((beat - from - delay) / beats).clamp(0.0, 1.0);
    final lost = u / 2 - math.sin(2 * math.pi * u) / (4 * math.pi);
    return beat - (1 - slowTo) * beats * lost;
  }
}

/// What people already dancing do, read from the same crowd model as a seated
/// room. The model goes on saying how interested each one is, so the room is
/// still the meter and every rule of how it fills still holds. Only the picture
/// differs: "uninterested" here means busy with their own night, mostly with each
/// other, in pairs, and facing whichever way that puts them. The owner's correction
/// of the first version, where everyone turned away from the fight.
class FloorDance {
  const FloorDance({
    required this.ownThing,
    required this.glance,
    this.occupied = const {},
    this.castGlance,
    this.sidestep,
    this.following,
    this.parting,
  });

  /// Not interested yet, for someone from the shared guest atlases.
  final FloorClip ownThing;

  /// Starting to notice: slowed down and turned toward the fight.
  final FloorClip glance;

  /// The rest are for people a level casts by atlas, who only ever dance and have
  /// their own drawings. Named ways of being busy: a couple, a back to the room.
  final Map<String, FloorClip> occupied;
  final FloorClip? castGlance;

  /// Moving aside, facing the way they go. Without it they glide.
  final FloorClip? sidestep;

  /// In time and facing the fight, in place of the crowd's `step_touch`.
  final FloorClip? following;
  final CrowdParting? parting;

  /// The drawings a shared guest atlas must have.
  Iterable<String> get frames => [...ownThing.frames, ...glance.frames];

  /// The drawings an atlas cast as [occupied] must have.
  Iterable<String> castFrames(String? occupiedAs) => [
    ...?occupied[occupiedAs]?.frames,
    ...?castGlance?.frames,
    ...?sidestep?.frames,
    ...?following?.frames,
  ];
}

/// A floor guest's drawing, and whether they face the fight. [danceBeat] is from
/// [CrowdParting.danceBeat]. Clips a seated room needs for getting up and sitting
/// down come out as dancing, because nobody here has anywhere to sit.
({String frame, bool facesIn}) floorGuestPose(
  CrowdGuestSnapshot guest,
  FloorDance dance, {
  required double danceBeat,
  bool reducedMotion = false,
  bool cast = false,
  String? occupied,
  double? phaseOffset,
}) {
  final local = danceBeat + (phaseOffset ?? guest.phaseOffset);
  String loop(CrowdClip clip) => ensembleClipFrame(
    clip,
    beat: guest.clipBeat,
    duration: 2,
    reducedMotion: reducedMotion,
  );
  return switch (guest.clip) {
    CrowdClip.seatedIdle => (
      frame: ((cast ? dance.occupied[occupied] : null) ?? dance.ownThing).at(
        local,
        reducedMotion: reducedMotion,
      ),
      facesIn: false,
    ),
    CrowdClip.notice => (
      frame: ((cast ? dance.castGlance : null) ?? dance.glance).at(
        local,
        reducedMotion: reducedMotion,
      ),
      facesIn: true,
    ),
    CrowdClip.seatedFollow || CrowdClip.standUp || CrowdClip.stepTouch
        when cast && dance.following != null => (
      frame: dance.following!.at(local, reducedMotion: reducedMotion),
      facesIn: true,
    ),
    CrowdClip.seatedFollow || CrowdClip.standUp => (
      frame: loop(CrowdClip.stepTouch),
      facesIn: true,
    ),
    CrowdClip.sitDown || CrowdClip.standingIdle
        when cast && dance.following != null => (
      frame: dance.following!.at(local, reducedMotion: reducedMotion),
      facesIn: true,
    ),
    CrowdClip.sitDown => (frame: loop(CrowdClip.standingIdle), facesIn: true),
    _ => (
      frame: ensembleGuestFrame(guest, reducedMotion: reducedMotion),
      facesIn: true,
    ),
  };
}

/// Which way someone moving aside faces: where they're going. Null when they don't
/// travel sideways, or aren't moving at all.
bool? floorGuestTravelsRight(PartyGuestSlot slot) {
  final to = slot.partTo;
  if (to == null || to.x == slot.floor.x) return null;
  return to.x > slot.floor.x;
}

/// A floor guest's place on the floor at [along].
PartyPoint floorGuestAt(PartyGuestSlot slot, double along) {
  final to = slot.partTo;
  if (to == null) return slot.floor;
  return PartyPoint(
    slot.floor.x + (to.x - slot.floor.x) * along,
    slot.floor.y + (to.y - slot.floor.y) * along,
  );
}
