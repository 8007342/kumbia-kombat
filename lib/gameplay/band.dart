import 'crowd_interest.dart';
import 'dance_floor.dart';
import 'party_layout.dart';

/// A raised floor painted into the plate. [deck] is its top as the plate shows
/// it, and [outline] is the floor underneath, which nobody on the floor can enter.
class RoomPlatform {
  RoomPlatform({
    required this.lift,
    required this.deck,
    required this.horizonY,
    required double eyeHeightAdults,
  }) : _rise = 1 - lift / eyeHeightAdults {
    outline = [
      for (final corner in deck) groundUnder(corner),
    ];
  }

  /// Deck height, in adult heights.
  final double lift;

  /// May run off the plate, as a platform cut by its edge does.
  final List<PartyPoint> deck;
  late final List<PartyPoint> outline;
  final double horizonY, _rise;

  /// The floor straight under a point on the deck. Someone with their feet there
  /// is sized by the floor plane at this point, and that alone makes them about
  /// 31% taller than the floor's plane gives at their feet: they stand nearer the
  /// camera's eye level, and verticals stay vertical.
  PartyPoint groundUnder(PartyPoint onDeck) =>
      PartyPoint(onDeck.x, horizonY + (onDeck.y - horizonY) / _rise);

  static bool _inside(List<PartyPoint> shape, PartyPoint point) {
    var inside = false;
    for (var i = 0, j = shape.length - 1; i < shape.length; j = i++) {
      final (a, b) = (shape[i], shape[j]);
      if ((a.y > point.y) != (b.y > point.y) &&
          point.x < a.x + (b.x - a.x) * (point.y - a.y) / (b.y - a.y)) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Whether a point on the floor is under the platform.
  bool covers(PartyPoint floor) => _inside(outline, floor);

  /// Whether a point in the picture is on the deck's top.
  bool holds(PartyPoint feet) => _inside(deck, feet);
}

/// What a rung of a band's ladder listens to. The owner's words are "as the player
/// game improves", which [form] reads most directly. [tier] and [partySwing] are
/// here because the band's own proposal reads those, so choosing is a data edit:
/// `plan/levels/indoor-party-2026-11-07.md`.
enum BandInput {
  /// The player's recent form, eased: `CrowdInterestModel.recentForm`.
  form,

  /// The music's tier, 0 to 4.
  tier,

  /// `CrowdInterestModel.partySwing`, the skill-gated top of the ladder.
  partySwing,
}

/// What the band can hear right now. It reads these and nothing reads it back.
class BandInputs {
  const BandInputs({this.form = 0, this.tier = 0, this.partySwing = 0});
  final double form, partySwing;
  final int tier;

  double of(BandInput input) => switch (input) {
    BandInput.form => form,
    BandInput.tier => tier.toDouble(),
    BandInput.partySwing => partySwing,
  };
}

/// One step of a player's ladder: what they play, and the one input that earns it.
class BandRung {
  const BandRung({required this.clip, required this.input, required this.from});
  final FloorClip clip;
  final BandInput input;
  final double from;
}

/// Someone in the band. Their [ladder] runs from their calmest playing to their
/// liveliest: a foot tap, then swinging the instrument, or as the art draws it.
class BandPlayer {
  const BandPlayer({
    required this.id,
    required this.atlas,
    required this.feet,
    required this.at,
    required this.ladder,
    required this.reference,
    this.palette,
    this.stature = 1,
    this.flipX = false,
    this.beatOffset = 0,
    this.lateBy = 0,
  });
  final String id;
  final String atlas;

  /// Where their feet are on the plate: on the deck, if there is one.
  final PartyPoint feet;

  /// The floor under them: the plane sizes and sorts them from here.
  final PartyPoint at;
  final List<BandRung> ladder;

  /// The drawing whose height is their standing height, so nobody grows or
  /// shrinks between poses.
  final String reference;

  /// Which outfit a guest drawing wears; null for art with its own colours.
  final int? palette;
  final double stature;
  final bool flipX;

  /// So the band isn't one body. Whole beats keep each of them on the music.
  final double beatOffset;

  /// Added to each rung's threshold above the first, so they liven one by one.
  final double lateBy;

  Iterable<String> get frames => [
    reference,
    for (final rung in ladder) ...rung.clip.frames,
  ];

  /// Which rung these inputs earn: the highest one whose own input has reached it.
  int rungFor(BandInputs inputs) {
    for (var i = ladder.length - 1; i > 0; i--) {
      final rung = ladder[i];
      if (inputs.of(rung.input) >= rung.from + lateBy) return i;
    }
    return 0;
  }

  /// Their drawing now. [inputs] is read once a bar, so a change of rung lands on
  /// a downbeat. Reduced motion holds each rung's first drawing: still the meter.
  String frameAt(
    double beat,
    BandInputs Function(double bar) inputs, {
    int beatsPerBar = 4,
    bool reducedMotion = false,
  }) {
    final bar = (beat / beatsPerBar).floorToDouble() * beatsPerBar;
    return ladder[rungFor(inputs(bar))].clip.at(
      beat + beatOffset,
      reducedMotion: reducedMotion,
    );
  }
}

/// Everything a level says about its band. [standIn] marks borrowed drawings, so
/// a test can say the band's own art is still owed.
class LevelBand {
  const LevelBand({required this.players, required this.standIn});
  final List<BandPlayer> players;
  final bool standIn;
}

/// The player's recent form as the band hears it, 0 to 1, eased. A scraping player
/// at the top tier keeps a band on this input calm, and a player who picks up gets
/// a band that picks up. It reads the music's beat and hands back a size for the
/// renderer; nothing reads it back. The numbers are starting values.
class BandEnergy {
  BandEnergy({this.entranceBeats = defaultEntranceBeats});

  /// One response phrase and a bit: a change lands while the player can still
  /// connect it to what they just did.
  static const defaultEntranceBeats = 24.0;
  final double entranceBeats;

  double _from = 0, _to = 0, _start = 0;
  double? _lastBeat;

  double at(double beat) =>
      _from + (_to - _from) * CrowdEngagement.reveal((beat - _start) / entranceBeats);

  void follow(double beat, double target) {
    if (!beat.isFinite) return;
    final last = _lastBeat;
    // A retried phrase rewinds the music, not what the band has heard.
    if (last != null && beat < last) _start -= last - beat;
    _lastBeat = beat;
    if ((target - _to).abs() < .001) return;
    _from = at(beat);
    _to = target;
    _start = beat;
  }
}
