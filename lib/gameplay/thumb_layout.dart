import 'rhythm.dart';

/// Logical input stays generous and stable while the beat moves visual markers.
Limb? thumbLimbAt(double x, double y) {
  if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < .65 || y > .97) {
    return null;
  }
  final left = x < .5;
  return y < .81
      ? (left ? Limb.leftHand : Limb.rightHand)
      : (left ? Limb.leftFoot : Limb.rightFoot);
}

/// A destination depends only on the authored hit, never the animation clock.
NotePoint thumbAnchor(Limb limb, double hitBeat) {
  final left = limb == Limb.leftHand || limb == Limb.leftFoot;
  final upper = limb == Limb.leftHand || limb == Limb.rightHand;
  final step = (hitBeat * 2).round();
  final variation = (step + limb.index * 3) % 5;
  return NotePoint(
    (left ? .34 : .66) + (variation - 2) * .018,
    (upper ? .73 : .88) + ((step + limb.index) % 3 - 1) * .012,
  );
}
