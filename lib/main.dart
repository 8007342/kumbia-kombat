import 'package:flutter/material.dart';

import 'gameplay/garden_page.dart';
import 'gameplay/gesture_capture_page.dart';

void main() {
  runApp(const KumbiaKombatApp());
}

class KumbiaKombatApp extends StatelessWidget {
  const KumbiaKombatApp({super.key});

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
      // `?capture=gestures` records real thumbs for the recogniser's tools.
      home: Uri.base.queryParameters['capture'] == 'gestures'
          ? const GestureCapturePage()
          : const GardenPage(),
    );
  }
}
