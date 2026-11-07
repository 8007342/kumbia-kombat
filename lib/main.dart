import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'console/console_page.dart';
import 'gameplay/garden_page.dart';
import 'gameplay/gesture_capture_page.dart';
import 'qr/qr_page.dart';
import 'review_links.dart';

void main() {
  runApp(const KumbiaKombatApp());
}

class KumbiaKombatApp extends StatelessWidget {
  const KumbiaKombatApp({super.key, this.route});

  /// Which page to open; the browser's URL when null. `lib/review_links.dart`.
  final AppRoute? route;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kumbia Kombat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Kumbia',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5C518),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: switch (route ?? routeFor(Uri.base, readPath: kIsWeb)) {
        // `?capture=gestures` records real thumbs for the recogniser's tools.
        AppRoute.gestures => const GestureCapturePage(),
        AppRoute.console => const ConsolePage(),
        AppRoute.qr => const QrPage(),
        AppRoute.game => const GardenPage(),
      },
    );
  }
}
