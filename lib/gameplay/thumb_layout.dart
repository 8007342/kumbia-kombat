import 'rhythm.dart';

/// The tap band and its split, as fractions of the screen.
const thumbBandTop = .65;
const thumbBandSplit = .81;
const thumbBandBottom = .97;

/// The middle of the four landing spots, and how far each sits from it.
const thumbPadCentre = NotePoint(.5, .805);
const thumbPadReachX = .20;
const thumbPadReachY = .09;

bool limbIsLeft(Limb limb) => limb == Limb.leftHand || limb == Limb.leftFoot;

bool limbIsUpper(Limb limb) => limb == Limb.leftHand || limb == Limb.rightHand;

/// The pad's quadrant under a point. Tells which ring dents for a stray tap, and
/// keeps each ring on its own side. Notes are judged near their ring instead:
/// see `tap_resolution.dart`.
Limb? thumbLimbAt(double x, double y) {
  if (!x.isFinite ||
      !y.isFinite ||
      x < 0 ||
      x > 1 ||
      y < thumbBandTop ||
      y > thumbBandBottom) {
    return null;
  }
  final left = x < .5;
  return y < thumbBandSplit
      ? (left ? Limb.leftHand : Limb.rightHand)
      : (left ? Limb.leftFoot : Limb.rightFoot);
}

/// A limb's resting spot. Each note lands a little off it: see `cue_path.dart`.
NotePoint thumbHome(Limb limb) => NotePoint(
  thumbPadCentre.x + (limbIsLeft(limb) ? -thumbPadReachX : thumbPadReachX),
  thumbPadCentre.y + (limbIsUpper(limb) ? -thumbPadReachY : thumbPadReachY),
);
