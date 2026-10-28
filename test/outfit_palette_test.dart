import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/outfit_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'source stays visible before preparation and without shader support',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 1, 1),
        ui.Paint()..color = const ui.Color(0xff874197),
      );
      final sourcePicture = recorder.endRecording();
      final source = await sourcePicture.toImage(1, 1);
      sourcePicture.dispose();
      final supported = await OutfitPalette.load();
      final unsupported = OutfitPalette.sourceOnly();
      for (final palette in [supported, unsupported]) {
        final pictureRecorder = ui.PictureRecorder();
        palette.draw(
          ui.Canvas(pictureRecorder),
          image: source,
          source: const ui.Rect.fromLTWH(0, 0, 1, 1),
          destination: const ui.Rect.fromLTWH(0, 0, 1, 1),
          palette: OutfitColor.teal,
        );
        // Disposing while work is queued must also dispose late raster results.
        final pending = palette.prepare(source, OutfitColor.teal);
        palette.dispose();
        await pending;
        expect(palette.cachedVariantCount, 0);
        final picture = pictureRecorder.endRecording();
        final rendered = await picture.toImage(1, 1);
        final bytes = (await rendered.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!;
        expect(bytes.buffer.asUint8List(), [135, 65, 151, 255]);
        rendered.dispose();
        picture.dispose();
      }
      source.dispose();
    },
  );

  test('twelve avatars cache independent immutable wardrobe variants', () async {
    final images = <ui.Image>[];
    for (final color in [
      const ui.Color(0xff874197),
      const ui.Color(0xffa41670),
      const ui.Color(0xffc84f83),
    ]) {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 1, 1),
        ui.Paint()
          ..color = color
          ..isAntiAlias = false,
      );
      final picture = recorder.endRecording();
      images.add(await picture.toImage(1, 1));
      picture.dispose();
    }
    final palette = await OutfitPalette.load();
    try {
      for (final image in images) {
        for (final color in OutfitColor.values) {
          await palette.prepare(image, color);
        }
      }
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      for (var actor = 0; actor < 3; actor++) {
        // Teal is deliberately last, reproducing the problematic browser order.
        for (final color in OutfitColor.values.reversed) {
          final destination = ui.Rect.fromLTWH(
            color.index * 2.0,
            actor * 2.0,
            2,
            2,
          );
          palette.draw(
            canvas,
            image: images[actor],
            source: const ui.Rect.fromLTWH(0, 0, 1, 1),
            destination: destination,
            palette: color,
          );
        }
      }
      expect(palette.cachedVariantCount, 12);
      final picture = recorder.endRecording();
      final rendered = await picture.toImage(8, 6);
      picture.dispose();
      final pixels = (await rendered.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!;
      for (var actor = 0; actor < 3; actor++) {
        final colors = <String>{};
        for (final color in OutfitColor.values) {
          final offset = (actor * 2 * 8 + color.index * 2) * 4;
          final rgb = List.generate(3, (i) => pixels.getUint8(offset + i));
          colors.add(rgb.join(','));
          expect(rgb.reduce(math.max), closeTo([151, 164, 200][actor], 1));
          switch (color) {
            case OutfitColor.teal:
              expect(rgb[1], greaterThan(rgb[0]));
              expect(rgb[1], greaterThan(rgb[2]));
            case OutfitColor.blue:
              expect(rgb[2], greaterThan(rgb[0]));
              expect(rgb[2], greaterThan(rgb[1]));
            case OutfitColor.coral:
              expect(rgb[0], greaterThan(rgb[1]));
              expect(rgb[1] - rgb[2], lessThan(30));
            case OutfitColor.gold:
              expect(rgb[0], greaterThan(rgb[1]));
              expect(rgb[1] - rgb[2], greaterThan(30));
          }
        }
        expect(colors.length, 4, reason: 'All four palettes for actor $actor');
      }
      rendered.dispose();
    } finally {
      palette.dispose();
      expect(palette.cachedVariantCount, 0);
      for (final image in images) {
        image.dispose();
      }
    }
  });

  test(
    'actual ensemble clothing changes while sampled skin and hair stay intact',
    () async {
      const samples =
          <String, ({List<ui.Rect> protected, List<ui.Rect> clothing})>{
            'woman': (
              protected: [
                ui.Rect.fromLTRB(85, 70, 105, 110),
                ui.Rect.fromLTRB(112, 29, 135, 42),
                ui.Rect.fromLTRB(178, 51, 188, 83),
                ui.Rect.fromLTRB(144, 60, 155, 71),
              ],
              clothing: [
                ui.Rect.fromLTRB(164, 102, 181, 122),
                ui.Rect.fromLTRB(117, 160, 145, 200),
              ],
            ),
            'man': (
              protected: [
                ui.Rect.fromLTRB(80, 111, 96, 130),
                ui.Rect.fromLTRB(102, 96, 119, 108),
                ui.Rect.fromLTRB(117, 125, 129, 138),
              ],
              clothing: [
                ui.Rect.fromLTRB(86, 180, 106, 200),
                ui.Rect.fromLTRB(107, 223, 130, 243),
              ],
            ),
            'host': (
              protected: [
                ui.Rect.fromLTRB(100, 65, 111, 80),
                ui.Rect.fromLTRB(162, 63, 169, 74),
                ui.Rect.fromLTRB(181, 132, 191, 141),
              ],
              clothing: [
                ui.Rect.fromLTRB(180, 93, 199, 111),
                ui.Rect.fromLTRB(124, 110, 138, 129),
              ],
            ),
          };
      final palette = await OutfitPalette.load();
      try {
        for (final entry in samples.entries) {
          final codec = await ui.instantiateImageCodec(
            await File('assets/art/ensemble/guest-${entry.key}-v2.png')
                .readAsBytes(),
          );
          final atlas = (await codec.getNextFrame()).image;
          codec.dispose();
          final original = (await atlas.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!;
          await palette.prepare(atlas, OutfitColor.teal);
          expect(palette.lastPreparationError, isNull);
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          const frame = ui.Rect.fromLTWH(0, 0, 256, 256);
          palette.draw(
            canvas,
            image: atlas,
            source: frame,
            destination: frame,
            palette: OutfitColor.teal,
          );
          final picture = recorder.endRecording();
          final recolored = await picture.toImage(256, 256);
          picture.dispose();
          final output = (await recolored.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!;
          int difference(int x, int y, int channel) =>
              (original.getUint8((y * atlas.width + x) * 4 + channel) -
                      output.getUint8((y * 256 + x) * 4 + channel))
                  .abs();
          for (final region in entry.value.protected) {
            for (var y = region.top.toInt(); y < region.bottom; y++) {
              for (var x = region.left.toInt(); x < region.right; x++) {
                if (original.getUint8((y * atlas.width + x) * 4 + 3) < 128) {
                  continue;
                }
                for (var channel = 0; channel < 4; channel++) {
                  expect(
                    difference(x, y, channel),
                    lessThanOrEqualTo(2),
                    reason: '${entry.key} skin/hair at $x,$y',
                  );
                }
              }
            }
          }
          for (final region in entry.value.clothing) {
            var opaque = 0, changed = 0;
            for (var y = region.top.toInt(); y < region.bottom; y++) {
              for (var x = region.left.toInt(); x < region.right; x++) {
                if (original.getUint8((y * atlas.width + x) * 4 + 3) < 128) {
                  continue;
                }
                opaque++;
                if ([0, 1, 2].any((channel) => difference(x, y, channel) > 5)) {
                  changed++;
                }
                expect(
                  difference(x, y, 3),
                  0,
                  reason: 'Retain actual clothing alpha',
                );
              }
            }
            expect(
              changed / opaque,
              greaterThan(.35),
              reason: '${entry.key} garment $region must recolor',
            );
          }
          recolored.dispose();
          atlas.dispose();
        }
      } finally {
        palette.dispose();
      }
    },
  );

  test('GPU clothing mask preserves skin, chair, alpha and atlas cell boundaries', () async {
    const colors = [
      ui.Color(
        0xffff0000,
      ), // Adjacent atlas cell: must never bleed into source.
      ui.Color(0xff4b245e), ui.Color(0xff874197), ui.Color(0xffc878d6),
      ui.Color(0xffdc9170), // Warm skin, outside reserved clothing range.
      ui.Color(0xff694123), // Wooden chair, outside reserved clothing range.
      ui.Color(0x80874197), ui.Color(0x00000000),
    ];
    final fixture = ui.PictureRecorder();
    final fixtureCanvas = ui.Canvas(fixture);
    for (var i = 0; i < colors.length; i++) {
      fixtureCanvas.drawRect(
        ui.Rect.fromLTWH(i.toDouble(), 0, 1, 1),
        ui.Paint()
          ..color = colors[i]
          ..isAntiAlias = false,
      );
    }
    final fixturePicture = fixture.endRecording();
    final atlas = await fixturePicture.toImage(8, 1);
    fixturePicture.dispose();
    final palette = await OutfitPalette.load();
    final variants = <String>{};
    try {
      for (final color in OutfitColor.values) {
        await palette.prepare(atlas, color);
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        const destination = ui.Rect.fromLTWH(0, 0, 14, 2);
        palette.draw(
          canvas,
          image: atlas,
          source: const ui.Rect.fromLTWH(1, 0, 7, 1),
          destination: destination,
          palette: color,
        );
        final picture = recorder.endRecording();
        final result = await picture.toImage(14, 2);
        picture.dispose();
        final pixels = (await result.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!;
        List<int> pixel(int x) =>
            List.generate(4, (channel) => pixels.getUint8(x * 4 + channel));
        for (var cell = 0; cell < 7; cell++) {
          expect(
            pixel(cell * 2),
            pixel(cell * 2 + 1),
            reason: 'Nearest texel sampling',
          );
        }
        expect(pixel(6), [220, 145, 112, 255], reason: 'Skin must not recolor');
        expect(pixel(8), [
          105,
          65,
          35,
          255,
        ], reason: 'Furniture must not recolor');
        expect(pixel(10)[3], 128);
        expect(pixel(12)[3], 0);
        for (final (x, maximum) in [(0, 94), (2, 151), (4, 214), (10, 151)]) {
          expect(
            pixel(x).take(3).reduce(math.max),
            closeTo(maximum, 2),
            reason: 'Preserve source shade value, including transparent edges',
          );
        }
        variants.add(pixel(2).join(','));
        expect(pixel(0), isNot([255, 0, 0, 255]));
        result.dispose();
      }
      expect(variants.length, 4);
      // A crowd reuses the helper several times in one recorded frame. Earlier
      // draws must retain their own crop, destination and palette uniforms.
      final crowdRecorder = ui.PictureRecorder();
      final crowdCanvas = ui.Canvas(crowdRecorder);
      for (final color in OutfitColor.values) {
        final destination = ui.Rect.fromLTWH(color.index * 2.0, 0, 2, 2);
        palette.draw(
          crowdCanvas,
          image: atlas,
          source: const ui.Rect.fromLTWH(2, 0, 1, 1),
          destination: destination,
          palette: color,
        );
      }
      final crowdPicture = crowdRecorder.endRecording();
      final crowdImage = await crowdPicture.toImage(8, 2);
      crowdPicture.dispose();
      final crowdPixels = (await crowdImage.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!;
      final crowdColors = {
        for (var i = 0; i < 4; i++)
          List.generate(
            4,
            (channel) => crowdPixels.getUint8(i * 8 + channel),
          ).join(','),
      };
      expect(crowdColors, variants);
      crowdImage.dispose();
      // A later pose selects an immutable crop; destination transforms must
      // not change any shader already used by an earlier frame.
      final nextRecorder = ui.PictureRecorder();
      final nextCanvas = ui.Canvas(nextRecorder);
      const nextDestination = ui.Rect.fromLTWH(2, 0, 2, 1);
      palette.draw(
        nextCanvas,
        image: atlas,
        source: const ui.Rect.fromLTWH(4, 0, 1, 1),
        destination: nextDestination,
        palette: OutfitColor.teal,
      );
      final nextPicture = nextRecorder.endRecording();
      final nextImage = await nextPicture.toImage(4, 1);
      nextPicture.dispose();
      final nextPixels = (await nextImage.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!;
      expect(nextPixels.getUint8(3), 0);
      expect(List.generate(4, (channel) => nextPixels.getUint8(8 + channel)), [
        220,
        145,
        112,
        255,
      ]);
      nextImage.dispose();
      // Exercise consecutive animation frames, repeated actors sharing a pose,
      // mirrored parent transforms and changing destinations. The cache must
      // depend only on atlas/palette, never pose, screen position or scale.
      for (var tick = 0; tick < 60; tick++) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.translate(20, 1);
        canvas.scale(-1, 2);
        final sourceX = tick.isEven ? 2.0 : 4.0;
        for (final color in OutfitColor.values) {
          for (var copy = 0; copy < 2; copy++) {
            palette.draw(
              canvas,
              image: atlas,
              source: ui.Rect.fromLTWH(sourceX, 0, 1, 1),
              destination: ui.Rect.fromLTWH(
                color.index * 4.0,
                copy * 2.0,
                2 + tick % 2.0,
                1,
              ),
              palette: color,
            );
          }
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(22, 8);
        picture.dispose();
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!;
        for (final color in OutfitColor.values) {
          for (var copy = 0; copy < 2; copy++) {
            final x = 19 - color.index * 4;
            final y = 2 + copy * 4;
            final pixel = List.generate(
              4,
              (channel) => pixels.getUint8((y * 22 + x) * 4 + channel),
            );
            expect(
              pixel[3],
              255,
              reason: 'Guest remains visible at frame $tick',
            );
            if (tick.isOdd) {
              expect(pixel, [220, 145, 112, 255]);
            } else {
              expect(variants, contains(pixel.join(',')));
            }
          }
        }
        image.dispose();
        if (tick > 0) expect(palette.cachedVariantCount, 4);
      }
      final invalidRecorder = ui.PictureRecorder();
      expect(
        () => palette.draw(
          ui.Canvas(invalidRecorder),
          image: atlas,
          source: const ui.Rect.fromLTWH(-1, 0, 1, 1),
          destination: const ui.Rect.fromLTWH(0, 0, 1, 1),
          palette: OutfitColor.teal,
        ),
        throwsArgumentError,
      );
      invalidRecorder.endRecording().dispose();
    } finally {
      palette.dispose();
      atlas.dispose();
    }
  });
}
