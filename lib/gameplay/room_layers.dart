import 'dart:math' as math;

import 'ensemble_sprites.dart';
import 'party_layout.dart';

/// How a layered prop answers the beat.
enum RoomLayerMotion {
  /// Leans either way, reaching each side on a beat: palms, hanging lanterns.
  sway,

  /// Rises from rest to peak on the beat, and falls back: flowers, flames.
  pulse,
}

/// The tap band and the quiet area behind the opponent, as fractions of the
/// plate. A layer may not reach either one: moving art there would read as a
/// cue. `plan/levels/next-level-plan.md`, "Party-up and full swing".
const roomLayerTapBandTop = .65;
const roomLayerTapBandBottom = .97;
const roomLayerQuietLeft = .35;
const roomLayerQuietRight = .65;
const roomLayerQuietTop = .3;
const roomLayerQuietBottom = .6;

/// A prop cut out of a room's plate. Its frames sit side by side in [atlas],
/// [restFrame] being the painted original, so at rest the room is unchanged and
/// nothing has to appear: the layer is there from the start, at its final anchor,
/// and only its range grows.
class RoomLayerProp {
  const RoomLayerProp({
    required this.id,
    required this.atlas,
    required this.atlasY,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.frames,
    required this.motion,
    required this.periodBeats,
    required this.instance,
  });

  final String id;

  /// Under `assets/art/`. Props may share an atlas, and levels may share props.
  final String atlas;
  final int atlasY;

  /// Plate pixels; each frame's box is the prop's whole reach at any frame.
  final int left, top, width, height;
  final int frames;
  final RoomLayerMotion motion;
  final double periodBeats;

  /// Decides when this prop wakes, the same way as every other party prop.
  final int instance;

  /// Empty pixels between frames, so nearest sampling can't bleed.
  static const gutter = 2;

  int get restFrame => motion == RoomLayerMotion.sway ? frames ~/ 2 : 0;
  int atlasX(int frame) => frame * (width + gutter);

  /// The frame for this moment. Reads the music beat and the crowd's swing and
  /// returns a drawing's index: it can't reach the music, the notes or the score.
  int frameAt({
    required double beat,
    required double swing,
    bool reducedMotion = false,
  }) {
    if (reducedMotion || !beat.isFinite || beat < 0) return restFrame;
    final strength = partyPropStrength(swing, instance);
    if (strength <= 0) return restFrame;
    final onBeat = math.cos(2 * math.pi * beat / periodBeats);
    return switch (motion) {
      RoomLayerMotion.sway =>
        restFrame + (restFrame * strength * onBeat).round(),
      RoomLayerMotion.pulse =>
        ((frames - 1) * strength * (1 + onBeat) / 2).round(),
    };
  }

  /// A problem with this prop's placement on a [plateWidth] x [plateHeight]
  /// plate, or null. Used by the level loader, so bad data can't ship.
  String? placementProblem(int plateWidth, int plateHeight) {
    final x0 = left / plateWidth, x1 = (left + width) / plateWidth;
    final y0 = top / plateHeight, y1 = (top + height) / plateHeight;
    if (left < 0 || top < 0 || x1 > 1 || y1 > 1) return 'leaves the plate';
    if (y1 > roomLayerTapBandTop && y0 < roomLayerTapBandBottom) {
      return 'reaches the tap band (y $y1)';
    }
    if (x1 > roomLayerQuietLeft &&
        x0 < roomLayerQuietRight &&
        y1 > roomLayerQuietTop &&
        y0 < roomLayerQuietBottom) {
      return 'reaches the quiet area behind the opponent';
    }
    return null;
  }

  /// Where the prop sits on screen, under the same cover fit as the plate.
  PartyRect screenRect(PartyViewport viewport) {
    final at = viewport.project(
      PartyPoint(left / viewport.sourceWidth, top / viewport.sourceHeight),
    );
    return PartyRect(
      at.x,
      at.y,
      width * viewport.sourceScale,
      height * viewport.sourceScale,
    );
  }
}
