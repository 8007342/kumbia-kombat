import 'rhythm.dart';
import 'thumb_layout.dart';

/// Where a cue travels and lands. Presentation only: the session never reads
/// this, and a tap is judged by its zone (`thumbLimbAt`), never by this point,
/// so nothing here can move the music, the notes or the score.

/// The most a note's landing spot may stray from its limb's home, as fractions
/// of the screen. Every note's variation is bounded by these two numbers.
const cueLandingJitterX = .04;
const cueLandingJitterY = .018;

/// The share of [cueLandingJitterX] a note always strays. On-beat notes land
/// outward of home and off-beat notes inward, so a half-beat double never lands
/// twice on one spot.
const cueLandingMinimumStray = .5;

/// How far from the play area's centre a cue may be born, as fractions of the
/// screen. It's always on its own limb's side, so no path crosses a quadrant.
const cueStartNearX = .012;
const cueStartFarX = .05;
const cueStartNearY = .006;
const cueStartFarY = .028;

/// How far a path bows toward the corner beside its target: 0 is a straight
/// line. Hands sweep wider than feet, and each note varies by [cueBendJitter].
const cueHandBend = .85;
const cueFootBend = .6;
const cueBendJitter = .1;

/// Cues fade in over this share of their approach, so new ones don't crowd the
/// centre of the play area.
const cueFadeInSpan = .3;

/// The drawn landing ring's radius, in logical pixels. Kept inside its zone.
const cueRingRadius = 29.0;

/// Drawn size of a moving cue, in logical pixels.
double cueExtent(double progress) => 25 + progress.clamp(0.0, 1.0) * 21;

/// Opacity factor for a cue's approach: 0 at birth, 1 from [cueFadeInSpan] on,
/// with no sudden start or stop. Fading isn't motion, so reduced motion keeps it.
double cueFadeIn(double progress) {
  final t = (progress / cueFadeInSpan).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// One note's whole journey, in logical pixels: a quadratic curve that stays
/// inside the box between its start and its landing, so a landing on screen
/// means the whole path is on screen.
class CuePath {
  const CuePath(this.start, this.control, this.landing);
  final NotePoint start;
  final NotePoint control;
  final NotePoint landing;

  NotePoint at(double progress) {
    final t = progress.clamp(0.0, 1.0);
    final a = (1 - t) * (1 - t);
    final b = 2 * (1 - t) * t;
    final c = t * t;
    return NotePoint(
      a * start.x + b * control.x + c * landing.x,
      a * start.y + b * control.y + c * landing.y,
    );
  }
}

/// The same note on the same screen always gets the same path. It depends only
/// on the note's move, beat and id, and never on a clock or a shared generator.
///
/// The move sets the bend: a path leaves the centre sideways toward its limb's
/// side, then rises into a hand's spot or drops onto a foot's. Reduced motion
/// gives a straight line to the limb's home, with no variation.
CuePath cuePath({
  required Limb limb,
  required double beat,
  required String id,
  required double width,
  required double height,
  bool reducedMotion = false,
}) {
  final side = limbIsLeft(limb) ? -1.0 : 1.0;
  final rise = limbIsUpper(limb) ? -1.0 : 1.0;
  final home = thumbHome(limb);
  final draw = _NoteDraws(id, beat);

  // Every draw is taken in the same order, so each value stays reproducible.
  final strayX = draw.next();
  final strayY = draw.next();
  final startX = draw.next();
  final startY = draw.next();
  final bend = draw.next();

  final onBeat = (beat * 2).round().isEven;
  final landingX = reducedMotion
      ? home.x
      : home.x +
            side *
                (onBeat ? 1 : -1) *
                cueLandingJitterX *
                (cueLandingMinimumStray +
                    (1 - cueLandingMinimumStray) * strayX);
  final landingY = reducedMotion
      ? home.y
      : home.y + (strayY * 2 - 1) * cueLandingJitterY;
  final landing = _insideZone(limb, landingX, landingY, width, height);

  double between(double near, double far, double draw) =>
      near + (far - near) * (reducedMotion ? .5 : draw);
  final start = NotePoint(
    (thumbPadCentre.x + side * between(cueStartNearX, cueStartFarX, startX)) *
        width,
    (thumbPadCentre.y + rise * between(cueStartNearY, cueStartFarY, startY)) *
        height,
  );

  final midX = (start.x + landing.x) / 2;
  final midY = (start.y + landing.y) / 2;
  final amount = reducedMotion
      ? 0.0
      : (limbIsUpper(limb) ? cueHandBend : cueFootBend) +
            (bend * 2 - 1) * cueBendJitter;
  // The corner beside the target, on the limb's own side, at the start's height.
  return CuePath(
    start,
    NotePoint(
      midX + (landing.x - midX) * amount,
      midY + (start.y - midY) * amount,
    ),
    landing,
  );
}

/// A limb's resting ring when no note is due, in logical pixels.
NotePoint cueHome(Limb limb, {required double width, required double height}) {
  final home = thumbHome(limb);
  return _insideZone(limb, home.x, home.y, width, height);
}

/// Keeps the whole ring inside the zone that judges it, whatever the screen.
NotePoint _insideZone(
  Limb limb,
  double x,
  double y,
  double width,
  double height,
) {
  final left = limbIsLeft(limb) ? 0.0 : width / 2;
  final top = (limbIsUpper(limb) ? thumbBandTop : thumbBandSplit) * height;
  final bottom =
      (limbIsUpper(limb) ? thumbBandSplit : thumbBandBottom) * height;
  return NotePoint(
    _within(x * width, left + cueRingRadius, left + width / 2 - cueRingRadius),
    _within(y * height, top + cueRingRadius, bottom - cueRingRadius),
  );
}

double _within(double value, double low, double high) =>
    low > high ? (low + high) / 2 : value.clamp(low, high);

/// A small seeded generator (Lehmer's, modulus 2^31 - 1). Every product stays
/// under 2^47, so Dart on the web, where integers are doubles, gets exactly the
/// same numbers as native. A multiply-based 32-bit hash wouldn't.
class _NoteDraws {
  _NoteDraws(String id, double beat) {
    // A sixteenth of a beat absorbs the rounding of a beat recovered from a
    // note's millisecond time, so it still names the same note.
    for (final unit in [...id.codeUnits, (beat * 16).round()]) {
      _state = (_state * _multiplier + unit + 1) % _modulus;
    }
    next();
    next();
  }

  static const _modulus = 2147483647;
  static const _multiplier = 48271;
  int _state = 20112;

  double next() {
    _state = (_state * _multiplier) % _modulus;
    return _state / _modulus;
  }
}
