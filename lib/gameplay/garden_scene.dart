import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'garden_session.dart';
import 'crowd_interest.dart';
import 'rhythm.dart';
import 'room_departure.dart';

class Spectator {
  const Spectator({
    required this.relX,
    required this.relY,
    required this.scale,
    required this.facingRight,
    required this.archetype,
    required this.primaryColor,
    required this.accentColor,
    required this.skinColor,
  });

  final double relX;
  final double relY;
  final double scale;
  final bool facingRight;
  final int archetype; // 0: Sipper/Lounger, 1: Dancer/Hat, 2: Vibing guest
  final Color primaryColor;
  final Color accentColor;
  final Color skinColor;
}

const _gardenSpectators = [
  Spectator(
    relX: 0.14,
    relY: 0.49,
    scale: 0.82,
    facingRight: true,
    archetype: 0,
    primaryColor: Color(0xFF264653),
    accentColor: Color(0xFF2A9D8F),
    skinColor: Color(0xFFE76F51),
  ),
  Spectator(
    relX: 0.27,
    relY: 0.43,
    scale: 0.74,
    facingRight: true,
    archetype: 1,
    primaryColor: Color(0xFF5A189A),
    accentColor: Color(0xFF9D4EDD),
    skinColor: Color(0xFFF4A261),
  ),
  Spectator(
    relX: 0.73,
    relY: 0.42,
    scale: 0.75,
    facingRight: false,
    archetype: 2,
    primaryColor: Color(0xFFE63946),
    accentColor: Color(0xFFFFB703),
    skinColor: Color(0xFFE07A5F),
  ),
  Spectator(
    relX: 0.86,
    relY: 0.48,
    scale: 0.85,
    facingRight: false,
    archetype: 0,
    primaryColor: Color(0xFF0077B6),
    accentColor: Color(0xFF00B4D8),
    skinColor: Color(0xFFF4A261),
  ),
  Spectator(
    relX: 0.63,
    relY: 0.38,
    scale: 0.62,
    facingRight: false,
    archetype: 1,
    primaryColor: Color(0xFF4A4E69),
    accentColor: Color(0xFF9A8C98),
    skinColor: Color(0xFFE76F51),
  ),
];

const _barSpectators = [
  Spectator(
    relX: 0.12,
    relY: 0.50,
    scale: 0.88,
    facingRight: true,
    archetype: 0,
    primaryColor: Color(0xFF7209B7),
    accentColor: Color(0xFFF72585),
    skinColor: Color(0xFFF4A261),
  ),
  Spectator(
    relX: 0.25,
    relY: 0.46,
    scale: 0.80,
    facingRight: true,
    archetype: 2,
    primaryColor: Color(0xFF3F37C9),
    accentColor: Color(0xFF4CC9F0),
    skinColor: Color(0xFFE07A5F),
  ),
  Spectator(
    relX: 0.74,
    relY: 0.45,
    scale: 0.80,
    facingRight: false,
    archetype: 1,
    primaryColor: Color(0xFFD90429),
    accentColor: Color(0xFFEF233C),
    skinColor: Color(0xFFE76F51),
  ),
  Spectator(
    relX: 0.88,
    relY: 0.51,
    scale: 0.90,
    facingRight: false,
    archetype: 0,
    primaryColor: Color(0xFF008000),
    accentColor: Color(0xFF55A630),
    skinColor: Color(0xFFF4A261),
  ),
  Spectator(
    relX: 0.38,
    relY: 0.39,
    scale: 0.66,
    facingRight: true,
    archetype: 2,
    primaryColor: Color(0xFFFF0054),
    accentColor: Color(0xFFFF5400),
    skinColor: Color(0xFFE07A5F),
  ),
];

/// Scene motion follows the song; the touch HUD is a separate fixed overlay.
class GardenSceneGame extends FlameGame {
  GardenSession? session;
  bool reducedMotion = false;
  Limb? action;
  double actionBeat = -10;
  double flourishBeat = -10;
  double exitTravel = 0;
  // Supplied from the continuing conductor through approval and travel.
  double? presentationBeat;
  double warmDown = 0;
  ui.Image? _background;
  ui.Image? _gatekeeper;
  String _currentBackground = 'garden/garden-mansion.png';
  double _ambient = 0;
  double _resetBeat = -10;

  bool get isBar => _currentBackground.contains('bar');

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
    _currentBackground = background;
    final generation = ++_roomGeneration;
    final loaded = await Future.wait([
      images.load(background),
      images.load(challenger),
    ]);
    if (generation != _roomGeneration) return;
    _background = loaded[0];
    _gatekeeper = loaded[1];
    presentationBeat = null;
    warmDown = 0;
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
    final beat = presentationBeat ?? session?.positionBeats ?? _ambient * .6;
    final playing = session?.running ?? false;
    final cleared = session?.phase == GardenPhase.cleared;
    final combo = session?.combo ?? 0;

    final pulse = reducedMotion ? 0.0 : math.sin(beat * math.pi * 2);
    final sway = reducedMotion ? 0.0 : math.sin(beat * math.pi / 4) * w * .006;
    canvas.save();
    canvas.translate(sway, 0);

    // 1. Background layer
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

    // 2. Party Crowd / Spectators in Depth
    _drawSpectators(canvas, w, h, beat, cleared);

    // 3. Challenger / Gatekeeper
    final approvalBeat = session?.completedAtBeat ?? beat;
    final accepted = cleared
        ? ((beat - approvalBeat) / 2).clamp(0.0, 1.0)
        : 0.0;
    final hostX = w * (.51 + .25 * accepted);
    final hostY = h * .43 + (playing ? pulse * 1.5 : 0);
    _shadow(canvas, ui.Offset(hostX, hostY + h * .05), w * .14);

    if (_gatekeeper != null) {
      canvas.save();
      // Subtle rhythmic dance sway for the challenger
      if (!reducedMotion && playing) {
        final challengerBounce = math.sin(beat * math.pi) * 1.5;
        canvas.translate(0, challengerBounce);
      }
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

      // Challenger demonstration indicator during call phase
      if (session?.phase == GardenPhase.call) {
        _drawChallengerCallDemo(canvas, hostX, hostY, w, h, beat);
      }
      canvas.restore();
    }

    // 4. Procedural movement proof; production authored atlases remain planned.
    final entrance = session?.phase == GardenPhase.intro
        ? (beat / 4).clamp(0.0, 1.0)
        : 1.0;
    final resetAge = beat - _resetBeat;
    final retreat = resetAge >= 0 && resetAge < 2
        ? math.sin(resetAge / 2 * math.pi)
        : 0.0;
    final departure = roomDepartures[isBar ? 'bar' : 'garden']!.sample(
      exitTravel,
      reducedMotion: reducedMotion,
    );
    final robotY = exitTravel > 0
        ? h * departure.y
        : h * (.76 - entrance * .09 + retreat * .09);
    final robotX = w * (exitTravel > 0 ? departure.x : .5);
    _shadow(canvas, ui.Offset(robotX, robotY + 20), w * .14);

    canvas.save();
    canvas.translate(robotX, robotY);
    final zoom = reducedMotion ? 1.0 : 1 + pulse.abs() * .012;
    final scale =
        (w / 150).clamp(1.8, 3.0) *
        zoom *
        (exitTravel > 0 ? departure.scale : 1);
    canvas.scale(scale);

    final flourish = beat - flourishBeat >= 0 && beat - flourishBeat < 1;
    final hit = beat - actionBeat >= 0 && beat - actionBeat < .45;
    final front = exitTravel > 0 ? false : hit || flourish || cleared;

    final stumbleAge = beat - (session?.lastStumbleBeat ?? -100);
    final stumbling = stumbleAge >= 0 && stumbleAge < 1.5;
    if (stumbling && !reducedMotion) {
      // A tiny recovery step, never a fall, collision penalty or humiliation.
      canvas.translate((stumbleAge < .5 ? 2 : -1), 1);
    }
    _drawMacron(
      canvas,
      beat + exitTravel * 8,
      front: front,
      dancing: playing || exitTravel > 0,
      hit: hit,
      flourish: flourish,
      cleared: cleared,
      action: action,
      actionAge: beat - actionBeat,
      flourishAge: beat - flourishBeat,
      combo: combo,
    );
    canvas.restore();

    // 5. Celebration Confetti & Fireflies
    if (cleared && warmDown < .65 && !reducedMotion) {
      _drawConfetti(canvas, w, h, beat);
    } else {
      for (var i = 0; i < 8; i++) {
        final x = w * (.07 + ((i * .137) % .86));
        final y = h * (.32 + ((i * .093) % .36));
        final alpha = .15 + .15 * math.sin(beat * .5 + i).abs();
        canvas.drawRect(
          ui.Rect.fromLTWH(
            x,
            y + (reducedMotion ? 0 : math.sin(beat * .5 + i) * 3),
            2,
            2,
          ),
          Paint()..color = const Color(0xFFFFD27A).withValues(alpha: alpha),
        );
      }
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

  void _drawSpectators(
    ui.Canvas canvas,
    double w,
    double h,
    double beat,
    bool cleared,
  ) {
    final list = isBar ? _barSpectators : _gardenSpectators;
    for (var i = 0; i < list.length; i++) {
      final spec = list[i];
      final guest = session?.crowd.guest(i, beat);
      final state = guest?.state ?? CrowdGuestState.occupied;
      // Each guest settles separately; a pair continues clapping the exit.
      final settleAt = .15 + i * .16;
      final settled = cleared && warmDown > settleAt;
      final escorting = cleared && warmDown > 0 && i % 3 == 0 && warmDown < .9;
      final styleEnergy = guest?.styleEnergy ?? 0;
      final attentive =
          !settled && (state != CrowdGuestState.occupied || styleEnergy > .1);
      final dancing =
          !settled &&
          (state == CrowdGuestState.participating ||
              state == CrowdGuestState.celebrating);
      final cheering =
          escorting ||
          (!settled &&
              (state == CrowdGuestState.celebrating || styleEnergy > .2));
      final following = !settled && state == CrowdGuestState.following;
      final noticing = !settled && state == CrowdGuestState.curious;
      final localBeat = beat + i * .25;
      final pose = (localBeat * 2).floor() % 4;
      final foot = reducedMotion || !dancing
          ? 0.0
          : const [0.0, -2.0, 0.0, 2.0][pose];
      final bounce = reducedMotion
          ? 0.0
          : dancing
          ? const [0.0, 1.0, 0.0, 2.0][pose]
          : following
          ? (pose.isEven ? 0.0 : .5)
          : 0.0;
      final charScale = spec.scale * (w / 180).clamp(1.1, 2.0);
      final sx = w * spec.relX;
      final sy = h * spec.relY;
      _shadow(canvas, ui.Offset(sx, sy + charScale * 2), charScale * 12);
      canvas.save();
      canvas.translate(
        sx.roundToDouble(),
        (sy - bounce * charScale).roundToDouble(),
      );
      canvas.scale(spec.facingRight ? charScale : -charScale, charScale);
      _drawSingleSpectator(
        canvas,
        spec,
        cheering: cheering,
        facingPlayer: attentive || escorting,
        armAngle: pose.isEven ? -.2 : .2,
        isBar: isBar,
        footStep: foot,
        pointing: noticing && i.isEven,
        footTapping: following && !reducedMotion && pose.isOdd,
      );
      canvas.restore();
    }
  }

  void _drawSingleSpectator(
    ui.Canvas canvas,
    Spectator spec, {
    required bool cheering,
    required bool facingPlayer,
    required double armAngle,
    required bool isBar,
    required double footStep,
    required bool pointing,
    required bool footTapping,
  }) {
    void px(double x, double y, double w, double h, Color c) {
      canvas.drawRect(ui.Rect.fromLTWH(x, y, w, h), Paint()..color = c);
    }

    const ink = Color(0xFF101B24);
    final outfit = spec.primaryColor;
    final trim = spec.accentColor;
    final skin = spec.skinColor;

    // Head and Hair/Hat
    px(-4, -28, 8, 8, skin);
    if (spec.archetype == 1) {
      // Stylish retro hat/beret
      px(-6, -31, 12, 3, trim);
      px(-4, -33, 8, 2, trim);
    } else {
      // Cool party hairstyle
      px(-5, -31, 10, 4, outfit);
    }

    // Eyes / Glasses
    if (facingPlayer) {
      if (cheering) {
        // Joyful squint / celebration eyes
        px(-2, -26, 2, 1, ink);
        px(1, -26, 2, 1, ink);
        px(-1, -24, 3, 2, const Color(0xFFE63946)); // Smile
      } else {
        // Looking at the dance floor
        px(-3, -26, 3, 2, const Color(0xFF7CE2C4)); // Cool shades
        px(1, -26, 3, 2, const Color(0xFF7CE2C4));
      }
    } else {
      // Turned away / side glance
      px(1, -26, 2, 2, ink);
    }

    // Torso / Jacket
    px(-5, -20, 10, 12, outfit);
    px(-2, -20, 4, 12, trim); // Lapel / vest trim

    // Arms
    if (cheering) {
      // Both arms raised high celebrating!
      px(-8, -25 + armAngle * 4, 3, 9, outfit);
      px(-9, -28 + armAngle * 4, 4, 3, skin);
      px(5, -25 - armAngle * 4, 3, 9, outfit);
      px(6, -28 - armAngle * 4, 4, 3, skin);
      if (isBar) {
        // Cocktail glass raised
        px(7, -33 - armAngle * 4, 3, 5, const Color(0xFFFFD166));
      }
    } else if (pointing) {
      // A neighbor-facing "look over there" gesture before joining the groove.
      px(-7, -19, 3, 8, outfit);
      px(4, -20, 8, 3, outfit);
      px(11, -21, 4, 2, skin);
    } else if (facingPlayer) {
      // One arm resting, one holding drink or clapping
      px(-7, -19, 3, 8, outfit);
      px(4, -18, 3, 7, outfit);
      px(5, -13, 3, 3, isBar ? const Color(0xFF06D6A0) : skin);
    } else {
      // Arms crossed or relaxed
      px(-6, -18, 12, 4, outfit);
    }

    // Legs / Lower body
    px(-4 + footStep, -8, 4, 9, const Color(0xFF1D2D44));
    px(-footStep, -8, 4, 9, const Color(0xFF1D2D44));
    px(-5 + footStep, 0, 4, 2, ink);
    px(1 - footStep, footTapping ? -1 : 0, 4, 2, ink);
  }

  void _drawChallengerCallDemo(
    ui.Canvas canvas,
    double hostX,
    double hostY,
    double w,
    double h,
    double beat,
  ) {
    // Demonstration aura pulsing when challenger is performing call notes
    final pulse = math.sin(beat * math.pi * 4).abs();
    final auraPaint = Paint()
      ..color = const Color(0x66FFC35F).withValues(alpha: 0.2 + 0.3 * pulse)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12);

    canvas.drawCircle(
      ui.Offset(hostX, hostY - h * 0.03),
      w * 0.16 + pulse * 6,
      auraPaint,
    );
  }

  void _drawMacron(
    ui.Canvas canvas,
    double beat, {
    required bool front,
    required bool dancing,
    required bool hit,
    required bool flourish,
    required bool cleared,
    required Limb? action,
    required double actionAge,
    required double flourishAge,
    required int combo,
  }) {
    const ink = Color(0xFF102A35);
    const shell = Color(0xFFF0E4C9);
    const shade = Color(0xFFBAAF99);
    const teal = Color(0xFF367A78);
    const cyan = Color(0xFF77F8DE);
    const gold = Color(0xFFFFC35F);

    void pixel(double x, double y, double w, double h, Color color) {
      canvas.drawRect(ui.Rect.fromLTWH(x, y, w, h), Paint()..color = color);
    }

    // 1. Dance state kinematics
    final isLH = hit && action == Limb.leftHand;
    final isRH = hit && action == Limb.rightHand;
    final isLF = hit && action == Limb.leftFoot;
    final isRF = hit && action == Limb.rightFoot;

    // Flourish spin calculation
    if (flourish && !reducedMotion) {
      final spinAngle = (flourishAge * math.pi * 2);
      canvas.scale(math.cos(spinAngle).abs() * 0.8 + 0.2, 1);
    }

    // Idle kumbia bounce
    final idleBounce = dancing && !reducedMotion
        ? math.sin(beat * math.pi * 2).abs() * 1.5
        : 0.0;
    final footStep = dancing && !reducedMotion
        ? math.sin(beat * math.pi) * 2.2
        : 0.0;

    final bodyYOffset = -idleBounce;

    // 2. Antenna with secondary sway & glow
    final antennaSway = reducedMotion
        ? 0.0
        : (isLH ? -2.0 : (isRH ? 2.0 : math.sin(beat * math.pi) * 1.5));
    pixel(-3 + antennaSway, -37 + bodyYOffset, 6, 4, ink);
    pixel(-1 + antennaSway, -35 + bodyYOffset, 2, 6, teal);
    pixel(-2 + antennaSway, -38 + bodyYOffset, 4, 4, combo >= 5 ? gold : cyan);

    // 3. Head casing
    pixel(-11, -29 + bodyYOffset, 22, 18, ink);
    pixel(-10, -28 + bodyYOffset, 20, 16, shell);
    pixel(-8, -29 + bodyYOffset, 16, 1, shell);
    pixel(8, -26 + bodyYOffset, 2, 12, shade);

    // 4. Face Display
    if (front || cleared) {
      // Screen background
      pixel(-8, -25 + bodyYOffset, 16, 9, ink);
      if (cleared) {
        // Joyful victory expression (^ _ ^)
        pixel(-6, -23 + bodyYOffset, 4, 2, cyan);
        pixel(2, -23 + bodyYOffset, 4, 2, cyan);
        pixel(-2, -20 + bodyYOffset, 4, 2, gold);
      } else if (isLH || isRH) {
        // High-energy dance expression
        pixel(-5, -23 + bodyYOffset, 3, 3, cyan);
        pixel(2, -23 + bodyYOffset, 3, 3, cyan);
        pixel(-2, -19 + bodyYOffset, 4, 1, teal);
      } else {
        // Attentive rhythm visor
        pixel(-5, -22 + bodyYOffset, 3, 3, cyan);
        pixel(2, -22 + bodyYOffset, 3, 3, cyan);
        pixel(-2, -18 + bodyYOffset, 4, 1, teal);
      }
    } else {
      // Rear casing seams
      pixel(-6, -24 + bodyYOffset, 12, 8, shade);
      pixel(-5, -23 + bodyYOffset, 10, 6, shell);
      pixel(-3, -21 + bodyYOffset, 6, 1, teal);
      pixel(-3, -19 + bodyYOffset, 6, 1, teal);
    }

    // 5. Torso
    pixel(-8, -12 + bodyYOffset, 16, 15, ink);
    pixel(-7, -11 + bodyYOffset, 14, 12, shell);
    pixel(-7, -2 + bodyYOffset, 14, 3, teal);
    pixel(
      -3,
      -8 + bodyYOffset,
      6,
      3,
      front ? (combo >= 4 ? gold : cyan) : shade,
    );

    // 6. Arms and Modular Right-Arm Cuff
    final leftUp = isLH || cleared;
    final rightUp = isRH || cleared;

    // Left Arm
    final leftArmY = leftUp ? -24.0 : -10.0;
    pixel(-14, leftArmY + bodyYOffset, 6, 12, ink);
    pixel(-13, leftArmY + 1 + bodyYOffset, 4, 10, shell);
    if (leftUp) {
      pixel(-13, leftArmY - 2 + bodyYOffset, 4, 3, cyan);
    }

    // Right Arm with Special Cuff
    final rightArmY = rightUp ? -24.0 : -10.0;
    pixel(8, rightArmY + bodyYOffset, 6, 12, ink);
    pixel(9, rightArmY + 1 + bodyYOffset, 4, 10, shell);
    // Modular right-arm cuff glow
    final cuffColor = combo >= 6 ? gold : teal;
    pixel(8, rightArmY + (rightUp ? 8 : 6) + bodyYOffset, 6, 3, cuffColor);
    if (rightUp) {
      pixel(9, rightArmY - 2 + bodyYOffset, 4, 3, cyan);
    }

    // 7. Legs with Kumbia Step & Weight Shift
    final leftStep = isLF ? -4.5 : footStep;
    final rightStep = isRF ? -4.5 : -footStep;

    pixel(-7, 2 + leftStep, 6, 8, ink);
    pixel(-6, 3 + leftStep, 4, 5, teal);
    pixel(-8, 8 + leftStep, 7, 3, shell);

    pixel(1, 2 + rightStep, 6, 8, ink);
    pixel(2, 3 + rightStep, 4, 5, teal);
    pixel(1, 8 + rightStep, 7, 3, shell);
  }

  void _drawConfetti(ui.Canvas canvas, double w, double h, double beat) {
    const colors = [
      Color(0xFFFFC35F),
      Color(0xFF7CE2C4),
      Color(0xFFFF70A6),
      Color(0xFF70D6FF),
      Color(0xFFFFFFFF),
    ];

    for (var i = 0; i < 28; i++) {
      final t = (beat * 0.4 + i * 0.23) % 1.0;
      final x = w * ((i * 0.173 + math.sin(beat * .75 + i) * 0.05) % 1.0);
      final y = h * (0.15 + 0.8 * t);
      final rotation = (beat * 1.5 + i) % (math.pi * 2);
      final color = colors[i % colors.length];

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRect(
        const ui.Rect.fromLTWH(-3, -2, 6, 4),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }
}
