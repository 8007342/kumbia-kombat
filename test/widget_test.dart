import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/main.dart';

void main() {
  testWidgets('landing page shows title banner and tagline',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KumbiaKombatApp());

    expect(find.text('🚧 UNDER CONSTRUCTION 🚧'), findsOneWidget);
    expect(find.textContaining('kumbia fighting game'), findsOneWidget);
  });
}
