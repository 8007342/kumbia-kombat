import 'package:flutter/material.dart';

import 'gameplay/garden_page.dart';

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
      home: const GardenPage(),
    );
  }
}
