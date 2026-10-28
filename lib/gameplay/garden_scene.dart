import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'garden_session.dart';
import 'crowd_interest.dart';
import 'rhythm.dart';
import 'room_departure.dart';
import 'party_sprites.dart';

class Spectator {
  const Spectator({
    required this.relX,
    required this.relY,
    required this.scale,
    required this.facingRight,
    required this.archetype,
  });

  final double relX;
  final double relY;
  final double scale;
  final bool facingRight;
  final int archetype; // 0: Sipper/Lounger, 1: Dancer/Hat, 2: Vibing guest
}

const _gardenSpectators = [
  Spectator(
    relX: 0.14,
    relY: 0.49,
    scale: 0.82,
    facingRight: true,
    archetype: 0,
  ),
  Spectator(
    relX: 0.27,
    relY: 0.43,
    scale: 0.74,
    facingRight: true,
    archetype: 1,
  ),
  Spectator(
    relX: 0.73,
    relY: 0.42,
    scale: 0.75,
    facingRight: false,
    archetype: 2,
  ),
  Spectator(
    relX: 0.86,
    relY: 0.48,
    scale: 0.85,
    facingRight: false,
    archetype: 0,
  ),
  Spectator(
    relX: 0.63,
    relY: 0.38,
    scale: 0.62,
    facingRight: false,
    archetype: 1,
  ),
];

const _barSpectators = [
  Spectator(
    relX: 0.12,
    relY: 0.50,
    scale: 0.88,
    facingRight: true,
    archetype: 0,
  ),
  Spectator(
    relX: 0.25,
    relY: 0.46,
    scale: 0.80,
    facingRight: true,
    archetype: 2,
  ),
  Spectator(
    relX: 0.74,
    relY: 0.45,
    scale: 0.80,
    facingRight: false,
    archetype: 1,
  ),
  Spectator(
    relX: 0.88,
    relY: 0.51,
    scale: 0.90,
    facingRight: false,
    archetype: 0,
  ),
  Spectator(
    relX: 0.38,
    relY: 0.39,
    scale: 0.66,
    facingRight: true,
    archetype: 2,
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
  String? artLoadError;
  PartySpriteAtlas? _heroAtlas;
  PartySpriteAtlas? _crowdAtlas;
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
    try {
      final manifest = PartySpriteManifest.fromJson(
        jsonDecode(
          await rootBundle.loadString('assets/art/party/manifest.json'),
        ) as Map<String, dynamic>,
      );
      final sheets = await Future.wait([
        images.load('party/${manifest.hero.image}'),
        images.load('party/${manifest.crowd.image}'),
      ]);
      _heroAtlas = PartySpriteAtlas(manifest.hero, sheets[0]);
      _crowdAtlas = PartySpriteAtlas(manifest.crowd, sheets[1]);
      await showRoom('garden/garden-mansion.png', 'garden/gatekeeper.png');
    } catch (error) {
      artLoadError = 'Party character art could not load. Refresh to retry.';
      throw StateError('$artLoadError $error');
    }
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
    actionBeat = -10;
    flourishBeat = -10;
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
    if (_heroAtlas == null || _crowdAtlas == null) return;
    final beat = presentationBeat ?? session?.positionBeats ?? _ambient * .6;
    final playing = session?.running ?? false;
    final cleared = session?.phase == GardenPhase.cleared;

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

    // 4. Reviewed raster poses, anchored consistently to the same ground point.
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

    final scale =
        (w / 150).clamp(1.8, 3.0) * (exitTravel > 0 ? departure.scale : 1);
    final stumbleAge = beat - (session?.lastStumbleBeat ?? -100);
    final stumbling = stumbleAge >= 0 && stumbleAge < 1.5;
    final frame = heroSpriteFrame(
      beat: beat,
      phaseBeat: session?.phaseBeat ?? 0,
      front: session?.phase == GardenPhase.response || cleared,
      walking:
          session?.phase == GardenPhase.intro || exitTravel > 0 || retreat > 0,
      sideOn: exitTravel > 0 && departure.facing == DepartureFacing.sideRight,
      reducedMotion: reducedMotion,
      action: action,
      actionAge: beat - actionBeat,
      flourishAge: beat - flourishBeat,
      stumbling: stumbling,
    );
    _heroAtlas!.draw(canvas, frame, ui.Offset(robotX, robotY + 20), scale);

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
      final settled = cleared && warmDown > .15 + i * .16;
      final escorting = cleared && warmDown > 0 && i % 3 == 0 && warmDown < .9;
      final frame = guestSpriteFrame(
        archetype: spec.archetype,
        state: guest?.state ?? CrowdGuestState.occupied,
        beat: beat + i * .25,
        styleEnergy: guest?.styleEnergy ?? 0,
        settled: settled,
        escorting: escorting,
        reducedMotion: reducedMotion,
      );
      final scale = spec.scale * (w / 180).clamp(1.1, 2.0);
      final ground = ui.Offset(w * spec.relX, h * spec.relY + scale * 2);
      _shadow(canvas, ground, scale * 14);
      _crowdAtlas!.draw(canvas, frame, ground, scale, flipX: !spec.facingRight);
    }
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
