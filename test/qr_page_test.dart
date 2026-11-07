import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/qr/qr_page.dart';
import 'package:kumbia_kombat/review_links.dart';

void main() {
  test('the share code carries exactly the game\'s address', () {
    expect(ReviewLinks.shareUrl, 'https://kumbias.tlatoani.net');
    final qr = shareQr();
    // Version 3 holds 35 bytes at level Q; the address is 28.
    expect(qr.typeNumber, lessThanOrEqualTo(3));
    expect(qr.moduleCount, 17 + 4 * qr.typeNumber);
  });

  testWidgets('the drawn code matches the encoder module for module, quiet zone '
      'and all', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const side = 330.0;
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: ShareCode(side: side)),
      ),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('share-qr-pixels')),
    );
    final (image, rgba, png) = (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      return (image, rgba!, png!);
    }))!;
    // For a decoder outside Flutter: tool/console/decode_qr.py reads this file.
    Directory('build').createSync(recursive: true);
    File('build/share-qr.png').writeAsBytesSync(png.buffer.asUint8List());

    final qr = shareQr();
    final (:module, :origin) = QrPainter.layout(side, qr.moduleCount);
    expect(module, greaterThanOrEqualTo(8), reason: 'big enough for any camera');
    double luma(double x, double y) {
      final i = (y.floor() * image.width + x.floor()) * 4;
      final r = rgba.getUint8(i), g = rgba.getUint8(i + 1), b = rgba.getUint8(i + 2);
      return (.2126 * r + .7152 * g + .0722 * b) / 255;
    }

    for (var row = 0; row < qr.moduleCount; row++) {
      for (var col = 0; col < qr.moduleCount; col++) {
        final value = luma(
          origin + (col + .5) * module,
          origin + (row + .5) * module,
        );
        if (qr.isDark(row, col)) {
          expect(value, lessThan(.2), reason: 'dark module $row,$col');
        } else {
          expect(value, greaterThan(.85), reason: 'light module $row,$col');
        }
      }
    }
    // The quiet zone, four modules wide on every side, is light all round.
    final quiet = origin - ShareCode.quietModules * module;
    for (var k = 0; k < qr.moduleCount + 8; k++) {
      final along = quiet + (k + .5) * module;
      for (final (x, y) in [
        (along, quiet + module / 2),
        (along, origin + (qr.moduleCount + 3.5) * module),
        (quiet + module / 2, along),
        (origin + (qr.moduleCount + 3.5) * module, along),
      ]) {
        expect(luma(x, y), greaterThan(.85), reason: 'quiet zone at $x,$y');
      }
    }
  });

  testWidgets('the share page shows the title, the code and the address', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: QrPage(animate: false)));
    await tester.pump();
    expect(find.text('KUMBIA'), findsOneWidget);
    expect(find.byKey(const Key('share-qr')), findsOneWidget);
    expect(find.text('kumbias.tlatoani.net'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
