import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'landing/landing_page.dart';

void main() {
  runApp(const KumbiaKombatApp());
}

class KumbiaKombatApp extends StatelessWidget {
  const KumbiaKombatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KumbiaKombat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5C518),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget.controlled(gameFactory: LandingPageGame.new),
          const SafeArea(child: UnderConstructionBanner()),
        ],
      ),
    );
  }
}

class UnderConstructionBanner extends StatelessWidget {
  const UnderConstructionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(height: 24),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5C518),
            border: Border.all(color: Colors.black, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(4, 4)),
            ],
          ),
          child: const Text(
            '🚧 UNDER CONSTRUCTION 🚧',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.black,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 32),
          child: Text(
            'A kumbia fighting game is being built here.\n¡Vuelva pronto!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
