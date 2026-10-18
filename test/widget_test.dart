import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/main.dart';

void main() {
  testWidgets('garden opens with a clear start action and one-thumb options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KumbiaKombatApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('KUMBIA\nKOMBAT'), findsOneWidget);
    expect(find.text('ENTRA AL RITMO  >'), findsOneWidget);
    expect(find.textContaining('THUMB REACH'), findsNothing);
    expect(find.textContaining('CALM CAMERA'), findsOneWidget);
    expect(find.text('01  /  THE GARDEN'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Dispose tickers/game/audio so the start screen never leaves a timer behind.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
