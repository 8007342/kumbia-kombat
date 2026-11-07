import 'crowd_interest.dart';
import 'ensemble_sprites.dart';

/// What a thing in the room is, for how the music's tier wakes it.
enum PartyLifeKind {
  /// Lamp glows and the room's warmth. First to wake.
  light,

  /// Fronds, flowers, potted plants. They drift, and dance only at full swing.
  plant,

  /// Drifts, and dances only at full swing.
  umbrella,

  /// Lanterns: a small slow swing in time, for everyone.
  hanging,

  /// Candle and torch flames: a small flicker in time, for everyone.
  flame,

  /// Waiters. They range further, and step in time only at full swing.
  staff,
}

/// One tier step's entrance: quintic, so no speed at either end.
class _Fader {
  double from = 0, to = 0, start = 0, beats = 1;

  double at(double beat) =>
      from + (to - from) * CrowdEngagement.reveal((beat - start) / beats);

  void move(double beat, double target, double over) {
    from = at(beat);
    to = target;
    start = beat;
    beats = over;
  }
}

/// The room waking with the music's tier: "everything should slowly party up",
/// and for every player. Separate from [CrowdInterestModel.partySwing], which is
/// the skill-gated top of the ladder and still the only thing that makes staff,
/// umbrellas and plants dance.
///
/// It follows the tier's number, never its tempo, because a ladder need not get
/// faster as it climbs. It reads the music's beat and tier and hands back sizes
/// for the renderer: nothing reads it back, so it can't move music, notes or score.
///
/// The numbers are artistic starting values, not findings. Each step's entrance
/// is its own quintic, so overlapping entrances still have no sudden change of
/// speed. Entrances are far quicker than the sibling project's 110-180 s because
/// a clean level lasts about a minute, so more players may notice them.
class PartyUp {
  PartyUp({
    this.entranceBeats = defaultEntranceBeats,
    this.holdBeats = defaultHoldBeats,
    this.fadeBeats = defaultFadeBeats,
  });

  /// A room whose tiers each take [cycleBeats] x [successesPerTier] on a clean
  /// run: an entrance lasts a tier and a half, so the last one lands just before
  /// the two proof phrases are over, and the next has begun before it arrives.
  factory PartyUp.forLevel({
    required double cycleBeats,
    required int successesPerTier,
  }) => PartyUp(
    entranceBeats: cycleBeats * successesPerTier * 1.5,
    holdBeats: cycleBeats * 2,
  );

  static const defaultEntranceBeats = 24.0;

  /// A failed phrase drops the music a tier. The room holds for two phrases, so
  /// one slip doesn't visibly deflate it.
  static const defaultHoldBeats = 32.0;
  static const defaultFadeBeats = 48.0;
  static const topTier = 4;

  final double entranceBeats, holdBeats, fadeBeats;
  final _steps = List.generate(topTier, (_) => _Fader());
  final _belowSince = List<double?>.filled(topTier, null);
  double? _lastBeat;

  /// The tier last followed.
  int tier = 0;

  /// Call with the music's beat and tier. Rendering at any frame rate gives the
  /// same room, to within a frame's beat.
  void follow(double beat, int tier) {
    if (!beat.isFinite) return;
    this.tier = tier;
    final last = _lastBeat;
    if (last != null && beat < last) {
      // A retried phrase or a replay rewinds the music, not the room's memory.
      final back = last - beat;
      for (final step in _steps) {
        step.start -= back;
      }
      for (var i = 0; i < topTier; i++) {
        final since = _belowSince[i];
        if (since != null) _belowSince[i] = since - back;
      }
    }
    _lastBeat = beat;
    for (var i = 0; i < topTier; i++) {
      final step = _steps[i];
      if (tier > i) {
        _belowSince[i] = null;
        if (step.to < 1) step.move(beat, 1, entranceBeats);
      } else if (step.to > 0) {
        final since = _belowSince[i] ??= beat;
        if (beat - since >= holdBeats) {
          step.move(beat, 0, fadeBeats);
          _belowSince[i] = null;
        }
      }
    }
  }

  /// How far tier steps [first] to [last] have arrived, 0 to 1. Step 1 is the
  /// first rise above tier 0.
  double wake(double beat, {int first = 1, int last = topTier}) {
    var sum = 0.0;
    for (var i = first - 1; i < last; i++) {
      sum += _steps[i].at(beat);
    }
    return sum / (last - first + 1);
  }

  /// How awake this kind of thing is, 0 to 1. Lights wake from the first step,
  /// what moves in air from the second, flames and staff from the third, and all
  /// of it is there by the top tier. [instance] staggers props of one kind, so
  /// each wakes at its own point, as at full swing.
  double life(PartyLifeKind kind, double beat, {int instance = 0}) {
    final wakes = switch (kind) {
      PartyLifeKind.light => wake(beat),
      PartyLifeKind.plant ||
      PartyLifeKind.umbrella ||
      PartyLifeKind.hanging => wake(beat, first: 2),
      PartyLifeKind.flame || PartyLifeKind.staff => wake(beat, first: 3),
    };
    return partyPropStrength(wakes, instance);
  }
}
