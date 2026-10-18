import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'garden_session.dart';
import 'rhythm.dart';

/// Scene motion follows the song; the touch HUD is a separate fixed overlay.
class GardenSceneGame extends FlameGame {
  GardenSession? session;
  bool reducedMotion = false;
  Limb? action;
  double actionBeat = -10;
  double flourishBeat = -10;
  double exitTravel = 0;
  ui.Image? _background;
  ui.Image? _gatekeeper;
  double _ambient = 0;
  double _resetBeat = -10;
  double? _clearedAt;

  void resetEntrance() {
    _resetBeat = session?.positionBeats ?? -10;
  }

  @override
  Color backgroundColor() => const Color(0xFF0B1821);

  int _roomGeneration = 0;

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/art/';
    await showRoom('garden/garden-mansion.png', 'garden/gatekeeper.png');
  }

  Future<void> showRoom(String background, String challenger) async {
    final generation = ++_roomGeneration;
    final loaded = await Future.wait([
      images.load(background),
      images.load(challenger),
    ]);
    if (generation != _roomGeneration) return;
    _background = loaded[0];
    _gatekeeper = loaded[1];
    _clearedAt = null;
    _resetBeat = -10;
    exitTravel = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _ambient += dt;
  }

  void dance(Limb limb) {
    action = limb;
    actionBeat = session?.positionBeats ?? 0;
  }

  @override
  void render(ui.Canvas canvas) {
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;
    final beat = session?.positionBeats ?? _ambient * .6;
    final playing = session?.running ?? false;
    final cleared = session?.phase == GardenPhase.cleared;
    final pulse = reducedMotion ? 0.0 : math.sin(beat * math.pi * 2);
    final sway = reducedMotion ? 0.0 : math.sin(beat * math.pi / 4) * w * .006;
    canvas.save();
    canvas.translate(sway, 0);
    if (_background != null) {
      paintImage(
        canvas: canvas,
        rect: ui.Rect.fromLTWH(-8, -8, w + 16, h + 16),
        image: _background!,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.none,
      );
    }
    final shade = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x77101620), Color(0x00101620), Color(0xBB07151E)],
        stops: [0, .45, 1],
      ).createShader(ui.Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w, h), shade);
    // The challenger moves aside on acceptance, opening the approach.
    if (cleared) {
      _clearedAt ??= _ambient;
    } else {
      _clearedAt = null;
    }
    final accepted = cleared
        ? ((_ambient - _clearedAt!) / .8).clamp(0.0, 1.0)
        : 0.0;
    final hostX = w * (.51 + .25 * accepted);
    final hostY = h * .43 + (playing ? pulse * 1.5 : 0);
    _shadow(canvas, ui.Offset(hostX, hostY + h * .05), w * .14);
    if (_gatekeeper != null) {
      paintImage(
        canvas: canvas,
        rect: ui.Rect.fromCenter(
          center: ui.Offset(hostX, hostY - h * .025),
          width: w * .30,
          height: h * .24,
        ),
        image: _gatekeeper!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
      );
    }
    // Original aligned code-native pixel sprite. No concept-sheet slicing.
    final entrance = session?.phase == GardenPhase.intro
        ? (beat / 4).clamp(0.0, 1.0)
        : 1.0;
    final resetAge = beat - _resetBeat;
    final retreat = resetAge >= 0 && resetAge < 2
        ? math.sin(resetAge / 2 * math.pi)
        : 0.0;
    final robotY =
        h * (.76 - entrance * .09 + retreat * .09 - exitTravel * .16);
    final robotX = w * .5;
    _shadow(canvas, ui.Offset(robotX, robotY + 20), w * .14);
    canvas.save();
    canvas.translate(robotX, robotY);
    final zoom = reducedMotion ? 1.0 : 1 + pulse.abs() * .012;
    final scale = (w / 150).clamp(1.8, 3.0) * zoom * (1 - exitTravel * .35);
    canvas.scale(scale);
    final flourish = beat - flourishBeat >= 0 && beat - flourishBeat < 1;
    final hit = beat - actionBeat >= 0 && beat - actionBeat < .45;
    final front = hit || flourish;
    if (flourish && !reducedMotion) {
      canvas.scale(
        math.cos((beat - flourishBeat) * math.pi * 2).abs() * .8 + .2,
        1,
      );
    }
    _robot(
      canvas,
      beat + exitTravel * 8,
      front: front,
      dancing: playing || exitTravel > 0,
      hit: hit,
    );
    canvas.restore();
    // A handful of restrained fireflies, behind the fixed controls.
    for (var i = 0; i < 8; i++) {
      final x = w * (.07 + ((i * .137) % .86));
      final y = h * (.32 + ((i * .093) % .36));
      final alpha = .15 + .15 * math.sin(_ambient + i).abs();
      canvas.drawRect(
        ui.Rect.fromLTWH(
          x,
          y + (reducedMotion ? 0 : math.sin(_ambient + i) * 3),
          2,
          2,
        ),
        Paint()..color = const Color(0xFFFFD27A).withValues(alpha: alpha),
      );
    }
    canvas.restore();
    super.render(canvas);
  }

  void _shadow(ui.Canvas canvas, ui.Offset center, double width) {
    canvas.drawOval(
      ui.Rect.fromCenter(center: center, width: width, height: width * .22),
      Paint()..color = const Color(0x77030C14),
    );
  }

  void _robot(
    ui.Canvas canvas,
    double beat, {
    required bool front,
    required bool dancing,
    required bool hit,
  }) {
    const ink = Color(0xFF102A35);
    const shell = Color(0xFFF0E4C9);
    const shade = Color(0xFFBAAF99);
    const teal = Color(0xFF367A78);
    const cyan = Color(0xFF77F8DE);
    void pixel(double x, double y, double w, double h, Color color) {
      canvas.drawRect(ui.Rect.fromLTWH(x, y, w, h), Paint()..color = color);
    }

    final step = dancing && !reducedMotion
        ? math.sin(beat * math.pi) * 1.8
        : 0.0;
    pixel(-3, -35, 6, 4, ink);
    pixel(-1, -33, 2, 6, teal);
    pixel(-2, -36, 4, 4, cyan);
    pixel(-11, -29, 22, 18, ink);
    pixel(-10, -28, 20, 16, shell);
    pixel(-8, -29, 16, 1, shell);
    pixel(8, -26, 2, 12, shade);
    if (front) {
      pixel(-8, -25, 16, 9, ink);
      pixel(-5, -22, 3, 3, cyan);
      pixel(2, -22, 3, 3, cyan);
      pixel(-2, -18, 4, 1, teal);
    } else {
      pixel(-6, -24, 12, 8, shade);
      pixel(-5, -23, 10, 6, shell);
      pixel(-3, -21, 6, 1, teal);
      pixel(-3, -19, 6, 1, teal);
    }
    pixel(-8, -12, 16, 15, ink);
    pixel(-7, -11, 14, 12, shell);
    pixel(-7, -2, 14, 3, teal);
    pixel(-3, -8, 6, 3, front ? cyan : shade);
    final leftUp = hit && action == Limb.leftHand;
    final rightUp = hit && action == Limb.rightHand;
    pixel(-13, leftUp ? -22 : -10, 5, 12, ink);
    pixel(-12, leftUp ? -21 : -9, 4, 10, shell);
    pixel(8, rightUp ? -22 : -10, 5, 12, ink);
    pixel(8, rightUp ? -21 : -9, 4, 10, shell);
    pixel(8, rightUp ? -16 : -4, 4, 2, teal);
    final leftStep = hit && action == Limb.leftFoot ? -3.0 : step;
    final rightStep = hit && action == Limb.rightFoot ? -3.0 : -step;
    pixel(-7, 2 + leftStep, 6, 7, ink);
    pixel(-6, 3 + leftStep, 4, 4, teal);
    pixel(-8, 7 + leftStep, 7, 3, shell);
    pixel(1, 2 + rightStep, 6, 7, ink);
    pixel(2, 3 + rightStep, 4, 4, teal);
    pixel(1, 7 + rightStep, 7, 3, shell);
  }
}
