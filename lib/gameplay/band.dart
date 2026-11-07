import 'crowd_interest.dart';
import 'dance_floor.dart';
import 'party_layout.dart';

/// A raised floor painted into the plate. Its outline is where the floor plane
/// runs under it, so people on it are sized by the same plane as everyone else.
class RoomPlatform {
  const RoomPlatform({required this.lift, required this.outline});

  /// Deck height, in adult heights at that spot.
  final double lift;

  /// In plate fractions: the floor it stands on.
  final List<PartyPoint> outline;

  bool covers(PartyPoint floor) {
    var inside = false;
    for (var i = 0, j = outline.length - 1; i < outline.length; j = i++) {
      final (a, b) = (outline[i], outline[j]);
      if ((a.y > floor.y) != (b.y > floor.y) &&
          floor.x < a.x + (b.x - a.x) * (floor.y - a.y) / (b.y - a.y)) {
        inside = !inside;
      }
    }
    return inside;
  }
}

/// Someone in the band. Their [ladder] runs from their calmest playing to their
/// liveliest: a foot tap, then swinging the instrument, or as the art draws it.
class BandPlayer {
  const BandPlayer({
    required this.id,
    required this.atlas,
    required this.at,
    required this.ladder,
    required this.reference,
    this.palette,
    this.stature = 1,
    this.flipX = false,
    this.beatOffset = 0,
  });
  final String id;
  final String atlas;

  /// On the floor, under the deck: the plane sizes and sorts them from here.
  final PartyPoint at;
  final List<FloorClip> ladder;

  /// The drawing whose height is their standing height, so nobody grows or
  /// shrinks between poses.
  final String reference;

  /// Which outfit a guest drawing wears; null for art with its own colours.
  final int? palette;
  final double stature;
  final bool flipX;

  /// So the band isn't one body. Whole beats keep each of them on the music.
  final double beatOffset;

  Iterable<String> get frames => [
    reference,
    for (final rung in ladder) ...rung.frames,
  ];

  /// Their drawing now. [energy] is read once a bar, so a change of rung lands on
  /// a downbeat. Reduced motion holds each rung's first drawing: still the meter.
  String frameAt(
    double beat,
    double Function(double beat) energy, {
    int beatsPerBar = 4,
    bool reducedMotion = false,
  }) {
    final bar = (beat / beatsPerBar).floorToDouble() * beatsPerBar;
    final rung = (energy(bar) * ladder.length).floor().clamp(
      0,
      ladder.length - 1,
    );
    return ladder[rung].at(beat + beatOffset, reducedMotion: reducedMotion);
  }
}

/// Everything a level says about its band. [standIn] marks borrowed drawings, so
/// a test can say the band's own art is still owed.
class LevelBand {
  const LevelBand({required this.players, required this.standIn});
  final List<BandPlayer> players;
  final bool standIn;
}

/// How lively the band is, 0 to 1. It follows the player's recent form, never the
/// tier: a scraping player at the top tier keeps the band calm, and a player who
/// picks up gets a band that picks up. It reads the music's beat and hands back a
/// size for the renderer; nothing reads it back. The numbers are starting values.
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
