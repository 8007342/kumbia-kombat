import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/thumb_layout.dart';

void main() {
  test(
    'all authored beat destinations remain inside their generous thumb cell',
    () {
      for (final limb in Limb.values) {
        final destinations = <String>{};
        for (var halfBeat = 0; halfBeat < 2000; halfBeat++) {
          final beat = halfBeat / 2;
          final point = thumbAnchor(limb, beat);
          expect(thumbLimbAt(point.x, point.y), limb);
          expect(point.x, inInclusiveRange(.29, .71));
          expect(point.y, inInclusiveRange(.71, .90));
          expect(thumbAnchor(limb, beat).x, point.x);
          expect(thumbAnchor(limb, beat).y, point.y);
          destinations.add('${point.x}:${point.y}');
        }
        expect(destinations.length, greaterThan(1));
      }
    },
  );

  test(
    'touch regions remain stable and ignore scene and browser-edge taps',
    () {
      expect(thumbLimbAt(.1, .66), Limb.leftHand);
      expect(thumbLimbAt(.9, .8), Limb.rightHand);
      expect(thumbLimbAt(.1, .82), Limb.leftFoot);
      expect(thumbLimbAt(.9, .96), Limb.rightFoot);
      for (final point in [
        const NotePoint(.5, .64),
        const NotePoint(.5, .98),
        const NotePoint(-.1, .8),
        const NotePoint(1.1, .8),
        const NotePoint(double.nan, .8),
      ]) {
        expect(thumbLimbAt(point.x, point.y), isNull);
      }
    },
  );
}
