import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Landing screen: animated hazard-stripe background with the KumbiaKombat
/// title and under-construction banner overlaid as widgets.
class LandingPageGame extends FlameGame
    with HasGameReference<LandingPageGame> {
  @override
  Color backgroundColor() => const Color(0xFF1A1A1A);

  @override
  Future<void> onLoad() async {
    await add(HazardStripesComponent());
    await add(
      TextComponent(
        text: 'KumbiaKombat',
        position: Vector2(size.x / 2, size.y * 0.38),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: size.x.clamp(48, 120),
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            color: const Color(0xFFF5C518),
            shadows: const [
              Shadow(
                color: Colors.black,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    for (final component in children.whereType<TextComponent>()) {
      component.position = Vector2(size.x / 2, size.y * 0.38);
      component.textRenderer = TextPaint(
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: size.x.clamp(48, 120),
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          color: const Color(0xFFF5C518),
          shadows: const [
            Shadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
          ],
        ),
      );
    }
  }
}

/// Full-screen diagonal yellow/black stripes that slowly scroll, the classic
/// construction-site motif.
class HazardStripesComponent extends PositionComponent
    with HasGameReference<LandingPageGame> {
  static const _stripeWidth = 48.0;
  double _offset = 0;

  @override
  void onMount() {
    super.onMount();
    size = game.size;
    position = Vector2.zero();
    anchor = Anchor.topLeft;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _offset = (_offset + 30 * dt) % (_stripeWidth * 2);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint();
    canvas.save();
    canvas.rotate(math.pi / 4);
    final diagonal = math.sqrt(size.x * size.x + size.y * size.y) * 2;
    for (var x = -diagonal + _offset; x < diagonal; x += _stripeWidth * 2) {
      paint.color = const Color(0xFFF5C518);
      canvas.drawRect(Rect.fromLTWH(x, -diagonal, _stripeWidth, diagonal * 3),
          paint);
      paint.color = const Color(0xFF111111);
      canvas.drawRect(
          Rect.fromLTWH(x + _stripeWidth, -diagonal, _stripeWidth, diagonal * 3),
          paint);
    }
    canvas.restore();
    // Darken so the title reads clearly on top.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0x66000000),
    );
  }
}
