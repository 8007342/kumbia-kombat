import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'challenger_choreography.dart';
import 'dance_grammar.dart';
import 'duet_staging.dart';
import 'ensemble_sprites.dart';
import 'exit_shot.dart';
import 'garden_session.dart';
import 'level_definition.dart';
import 'outfit_palette.dart';
import 'party_layout.dart';
import 'party_sprites.dart';
import 'progression.dart';
import 'rhythm.dart';
import 'room_departure.dart';

class _WorldDraw {
  const _WorldDraw(this.id, this.floorY, this.layer, this.draw);
  final String id;
  final double floorY;
  final int layer;
  final void Function(ui.Canvas) draw;
  ({double floorY, int layer, String id}) get order =>
      (floorY: floorY, layer: layer, id: id);
}

/// Scenery, actors and furniture share a single source-image cover transform.
/// Only music sampling controls the dance; the HUD stays outside this canvas.
class GardenSceneGame extends FlameGame {
  GardenSceneGame({required this.firstLevel});

  /// Awaited while loading, so a bad level file is reported like missing art.
  final Future<LevelDefinition> Function() firstLevel;
  GardenSession? session;
  bool reducedMotion = false;
  bool presentationPaused = false;
  Limb? action;
  double actionBeat = -10;
  double? actionTargetBeat;
  double? nextRequiredBeat;
  double flourishBeat = -10;
  double exitTravel = 0;
  double? presentationBeat;
  double? exitCodaBeat;

  /// Beats since the success score began, running on through the bridge.
  double? exitBeat;
  double warmDown = 0;
  String? artLoadError;
  PartySpriteAtlas? _heroAtlas;
  Map<String, EnsembleAtlas>? _ensemble;
  OutfitPalette? _outfits;
  ui.Image? _background;
  LevelDefinition? _level;
  double _foregroundSeconds = 0;
  double _lastBeat = 0;
  double _resetBeat = -10;
  int _roomGeneration = 0;
  ChallengerChoreography? _choreography;
  DanceGrammar? _grammar;
  GardenSession? _choreographySession;
  List<Limb>? _choreographyLimbs;
  List<double>? _choreographyOffsets;

  void resetEntrance() => _resetBeat = session?.positionBeats ?? -10;

  @override
  Color backgroundColor() => const Color(0xFF0B1821);

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/art/';
    try {
      final source = jsonDecode(
        await rootBundle.loadString('assets/art/party/manifest.json'),
      ) as Map<String, dynamic>;
      final hero = PartyAtlasDefinition.fromJson(
        Map<String, dynamic>.from(source['atlases']['hero'] as Map),
      )..requireFrames(heroFrameIds);
      final ensemble = EnsembleManifest.fromJson(
        jsonDecode(
          await rootBundle.loadString('assets/art/ensemble/manifest.json'),
        ) as Map<String, dynamic>,
      );
      final grammar = DanceGrammar.fromJson(
        jsonDecode(
          await rootBundle.loadString('assets/art/ensemble/choreography.json'),
        ) as Map<String, dynamic>,
      );
      for (final dancer in const [
        'gatekeeper',
        'bartender',
        'swing-a',
        'swing-b',
      ]) {
        grammar.requireFrames(
          dancer,
          ensemble.atlases[dancer]!.art.frames.keys,
        );
      }
      _grammar = grammar;
      final loaded = await Future.wait([
        images.load('party/${hero.image}'),
        for (final entry in ensemble.atlases.entries)
          images.load('ensemble/${entry.value.art.image}'),
      ]);
      _heroAtlas = PartySpriteAtlas(hero, loaded.first);
      var index = 1;
      _ensemble = {
        for (final entry in ensemble.atlases.entries)
          entry.key: EnsembleAtlas(entry.value, loaded[index++]),
      };
      _outfits = await OutfitPalette.load();
      await showLevel(await firstLevel());
    } catch (error) {
      artLoadError = 'Party character art could not load. Refresh to retry.';
      throw StateError('$artLoadError $error');
    }
  }

  /// Challenger animation comes exclusively from the ensemble atlas.
  Future<void> showLevel(LevelDefinition level) async {
    for (final challenger in level.stage.challengers) {
      if (!_ensemble!.containsKey(challenger.atlas)) {
        throw StateError(
          'Level ${level.id} names unknown atlas ${challenger.atlas}',
        );
      }
      final duet = level.stage.duet;
      if (duet != null) {
        _grammar!.requireClips(challenger.atlas, [
          duet.offClip,
          duet.partnerClip,
          'yield_out',
          'return_in',
        ]);
        _ensemble![challenger.atlas]!.definition.art.requireFrames([
          ...duet.pairFrames.rest,
          duet.pairFrames.arm,
          duet.pairFrames.kick,
          duet.spin.reachFrame,
        ]);
        _heroAtlas!.definition.requireFrames(duet.spin.heroFrames);
      }
    }
    final generation = ++_roomGeneration;
    final loaded = await images.load(level.background);
    for (final image in level.exitShot?.images ?? const <String>[]) {
      await images.load(image);
    }
    for (final prop in level.layers) {
      await images.load(prop.atlas);
    }
    if (generation != _roomGeneration) return;
    _level = level;
    _background = loaded;
    presentationBeat = null;
    exitCodaBeat = null;
    warmDown = 0;
    _resetBeat = -10;
    exitTravel = 0;
    exitBeat = null;
    actionBeat = -10;
    actionTargetBeat = null;
    nextRequiredBeat = null;
    flourishBeat = -10;
    _choreography = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!presentationPaused &&
        session?.phase != GardenPhase.paused &&
        dt.isFinite &&
        dt > 0) {
      _foregroundSeconds += dt;
    }
  }

  @override
  void onRemove() {
    _outfits?.dispose();
    super.onRemove();
  }

  void dance(Limb limb, {double? targetBeat, double? nextRequiredBeat}) {
    action = limb;
    actionBeat = session?.positionBeats ?? 0;
    actionTargetBeat = targetBeat;
    this.nextRequiredBeat = nextRequiredBeat;
  }

  ChallengerPose _challengerAt(double beat, {String? dancer}) {
    final atlas = dancer ?? _level!.stage.challengers.first.atlas;
    final s = session;
    if (s == null) {
      return _grammar!.dress(
        const ChallengerPose(
          frameId: 'occupied',
          state: ChallengerDanceState.occupied,
        ),
        dancer: atlas,
        beat: 0,
        callStartBeat: 0,
        reducedMotion: reducedMotion,
      );
    }
    if (_choreography == null ||
        !identical(_choreographySession, s) ||
        !identical(_choreographyLimbs, s.activeLimbs) ||
        !identical(_choreographyOffsets, s.activeOffsets)) {
      _choreography = ChallengerChoreography(
        limbs: s.activeLimbs,
        offsets: s.activeOffsets,
        callBeats: s.chart.callBeats,
      );
      _choreographySession = s;
      _choreographyLimbs = s.activeLimbs;
      _choreographyOffsets = s.activeOffsets;
    }
    final cleared = s.phase == GardenPhase.cleared;
    final passed = s.lastOutcome == null
        ? null
        : s.lastOutcome != ChallengeOutcome.retry &&
              s.lastOutcome != ChallengeOutcome.entranceReset;
    final outcomeBeat = cleared ? s.completedAtBeat : s.lastOutcomeBeat;
    final tier = s.transport.sections.isEmpty ? 0 : s.transport.tierAt(beat);
    final pose = _choreography!.sample(
      beat: beat,
      callStartBeat: s.callStartBeat,
      started: s.phase != GardenPhase.ready,
      reducedMotion: reducedMotion,
      outcomeBeat: outcomeBeat,
      passed: passed,
      cleared: cleared,
      handoffMoveBeats: _grammar!.handoffBeats(atlas, tier),
    );
    return _grammar!.dress(
      pose,
      dancer: atlas,
      beat: beat,
      callStartBeat: s.callStartBeat,
      callBeats: s.chart.callBeats,
      tier: tier,
      section: s.transport.score.sectionAt(beat),
      // The phrase result, so a clearing approval runs on without restarting.
      outcomeBeat: s.lastOutcomeBeat ?? outcomeBeat,
      reducedMotion: reducedMotion,
    );
  }

  @override
  void render(ui.Canvas canvas) {
    if (size.x <= 0 ||
        size.y <= 0 ||
        _heroAtlas == null ||
        _ensemble == null ||
        _outfits == null ||
        _level == null ||
        _background == null) {
      return;
    }
    _outfits!.holdSlowRasters = session?.running ?? false;
    final paused = presentationPaused || session?.phase == GardenPhase.paused;
    final sampledBeat = presentationBeat ?? session?.positionBeats ?? 0;
    final beat = paused ? _lastBeat : sampledBeat;
    if (!paused) _lastBeat = beat;
    final viewport = PartyViewport(
      size.x,
      size.y,
      sourceWidth: _background!.width.toDouble(),
      sourceHeight: _background!.height.toDouble(),
    );
    final room = _level!.layout;
    final backgroundRect = viewport.backgroundRect;
    canvas.save();
    canvas.scale(viewport.pixelsPerUnit);
    canvas.clipRect(
      ui.Rect.fromLTWH(
        0,
        0,
        PartyViewport.logicalWidth,
        viewport.logicalHeight,
      ),
    );
    canvas.drawImageRect(
      _background!,
      ui.Rect.fromLTWH(
        0,
        0,
        _background!.width.toDouble(),
        _background!.height.toDouble(),
      ),
      ui.Rect.fromLTWH(
        backgroundRect.left,
        backgroundRect.top,
        backgroundRect.width,
        backgroundRect.height,
      ),
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );
    _drawRoomLayers(canvas, viewport, beat);
    final bounds = ui.Rect.fromLTWH(
      0,
      0,
      PartyViewport.logicalWidth,
      viewport.logicalHeight,
    );
    canvas.drawRect(
      bounds,
      ui.Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x22101620), Color(0x00101620), Color(0x6607151E)],
          stops: [0, .45, 1],
        ).createShader(bounds),
    );

    _drawLampGlows(canvas, viewport);
    final draws = <_WorldDraw>[];
    _addFurniture(draws, viewport, room, beat);
    _addGuests(draws, viewport, room, beat);
    _addLife(draws, viewport, room, beat);
    final challenger = _challengerAt(beat);
    _addChallenger(draws, viewport, room, challenger);
    _addHero(draws, viewport, room, beat, challenger);
    draws.sort((a, b) => compareEnsembleDepth(a.order, b.order));
    for (final draw in draws) {
      draw.draw(canvas);
    }
    _drawCloseup(canvas, bounds);
    canvas.restore();
    super.render(canvas);
  }

  /// True while a close-up covers the world, for the HUD to step aside.
  bool get closeupShowing {
    final shot = _level?.exitShot;
    final at = exitBeat;
    return shot != null && at != null && shot.closeupAt(at);
  }

  void _drawCloseup(ui.Canvas canvas, ui.Rect bounds) {
    if (!closeupShowing) return;
    final shot = _level!.exitShot!;
    final at = exitBeat!;
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
    final plate = images.fromCache(shot.plate);
    final cover = math.max(
      bounds.width / plate.width,
      bounds.height / plate.height,
    );
    final plateSize = ui.Size(plate.width * cover, plate.height * cover);
    canvas.drawImageRect(
      plate,
      ui.Rect.fromLTWH(0, 0, plate.width.toDouble(), plate.height.toDouble()),
      ui.Rect.fromCenter(
        center: bounds.center,
        width: plateSize.width,
        height: plateSize.height,
      ),
      paint,
    );
    // Drop the plate back, so the fists are the only bright thing on screen.
    canvas.drawRect(bounds, ui.Paint()..color = const Color(0x8C050A10));
    final meet = ui.Offset(
      bounds.width * shot.contactPoint.dx,
      bounds.height * shot.contactPoint.dy,
    );
    final duet = _level!.stage.duet;
    final s = session;
    final mirror =
        duet != null &&
        s != null &&
        _duetWinFloors(duet, s, s.completedAtBeat ?? at).mirrored;
    if (mirror) {
      canvas.save();
      canvas.translate(meet.dx * 2, 0);
      canvas.scale(-1, 1);
    }
    for (final place in shot.sample(at, reducedMotion: reducedMotion)) {
      final art = images.fromCache(place.image);
      final origin =
          meet + place.offset - place.actor.contact * place.actor.scale;
      canvas.drawImageRect(
        art,
        ui.Rect.fromLTWH(0, 0, art.width.toDouble(), art.height.toDouble()),
        origin &
            ui.Size(
              art.width * place.actor.scale,
              art.height * place.actor.scale,
            ),
        paint,
      );
    }
    if (mirror) canvas.restore();
    for (final mote in shot.motes(at, reducedMotion: reducedMotion)) {
      canvas.drawRect(
        ui.Rect.fromCenter(
          center: meet + mote.offset,
          width: mote.size,
          height: mote.size,
        ),
        ui.Paint()
          ..color = const Color(0xFFF4E3B2).withValues(alpha: mote.opacity),
      );
    }
  }

  double _adultHeight(
    PartyViewport viewport,
    PartyRoomLayout room,
    PartyPoint floor, {
    double stature = 1,
  }) => viewport.sourceHeightToLogical(
    room.floor.standingHeightAt(floor.y, stature: stature),
  );
  ui.Offset _point(PartyPoint point) => ui.Offset(point.x, point.y);

  void _shadow(ui.Canvas canvas, ui.Offset floor, double standingHeight) {
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: floor,
        width: standingHeight * .34,
        height: standingHeight * .065,
      ),
      ui.Paint()..color = const Color(0x55030C14),
    );
  }

  void _addGuests(
    List<_WorldDraw> draws,
    PartyViewport viewport,
    PartyRoomLayout room,
    double beat,
  ) {
    final s = session;
    for (final slot in room.guests) {
      final projected = room.projectSlot(viewport, slot);
      final snapshot = s != null && slot.interestIndex != null
          ? s.crowd.guest(
              slot.interestIndex!,
              beat,
              exitBeat: s.phase == GardenPhase.cleared
                  ? exitCodaBeat ?? s.completedAtBeat
                  : null,
            )
          : null;
      final atlas =
          _ensemble!['guest${snapshot?.archetypeIndex ?? slot.archetype}']!;
      final frame = snapshot == null
          ? 'seated_idle_a'
          : ensembleGuestFrame(snapshot, reducedMotion: reducedMotion);
      final scale = projected.spriteScale(
        atlas.nativeHeight('standing_idle_a'),
      );
      final ground = _point(projected.floor);
      final palette =
          OutfitColor.values[(snapshot?.paletteIndex ?? slot.paletteIndex) %
              OutfitColor.values.length];
      draws.add(
        _WorldDraw(slot.id, projected.floor.y, 10, (canvas) {
          _shadow(canvas, ground, projected.standingHeight);
          atlas.draw(
            canvas,
            frame,
            ground,
            scale,
            flipX: !slot.facingRight,
            outfits: _outfits,
            palette: palette,
          );
        }),
      );
    }
  }

  /// The crowd's flawless reveal, easing back out as the room cools at the win.
  double _partySwing(double beat) =>
      (session?.crowd.partySwing(beat) ?? 0) * (1 - warmDown);

  /// Props cut out of the plate. They sit on it, under the shading and all the
  /// people, exactly as they did when they were painted into it.
  void _drawRoomLayers(ui.Canvas canvas, PartyViewport viewport, double beat) {
    final swing = _partySwing(beat);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
    for (final prop in _level!.layers) {
      final frame = prop.frameAt(
        beat: beat,
        swing: swing,
        reducedMotion: reducedMotion,
      );
      final at = prop.screenRect(viewport);
      canvas.drawImageRect(
        images.fromCache(prop.atlas),
        ui.Rect.fromLTWH(
          prop.atlasX(frame).toDouble(),
          prop.atlasY.toDouble(),
          prop.width.toDouble(),
          prop.height.toDouble(),
        ),
        ui.Rect.fromLTWH(at.left, at.top, at.width, at.height),
        paint,
      );
    }
  }

  String _propFrame(String kind, int instance, double beat) =>
      ensemblePartyFrame(
        kind,
        _foregroundSeconds,
        beat: beat,
        swing: _partySwing(beat),
        instance: instance,
        reducedMotion: reducedMotion,
      );

  void _addFurniture(
    List<_WorldDraw> draws,
    PartyViewport viewport,
    PartyRoomLayout room,
    double beat,
  ) {
    final furniture = _ensemble!['furniture']!;
    final life = _ensemble!['life']!;
    for (var i = 0; i < room.props.length; i++) {
      final prop = room.props[i];
      if (prop.bakedIntoStarter) continue;
      final projected = viewport.project(prop.floor);
      final adult = _adultHeight(viewport, room, prop.floor);
      late final EnsembleAtlas atlas;
      late final String frame;
      late final String reference;
      switch (prop.kind) {
        case PartyPropKind.chair:
          final owner = room.guests
              .where((g) => g.homePropId == prop.id)
              .firstOrNull;
          if (owner?.chairIncluded == true) continue;
          atlas = furniture;
          frame = owner?.facingRight == false ? 'chair_left' : 'chair_right';
          reference = frame;
        case PartyPropKind.table:
          atlas = furniture;
          frame = 'table';
          reference = frame;
        case PartyPropKind.umbrella:
          atlas = life;
          reference = 'umbrella_a';
          frame = _propFrame('umbrella', i, beat);
        case PartyPropKind.plant:
          atlas = life;
          reference = 'plant_a';
          frame = _propFrame('plant', i, beat);
        case PartyPropKind.candle:
          atlas = life;
          reference = 'candle_a';
          frame = _propFrame('candle', i, beat);
        case PartyPropKind.drink:
          continue; // Drinks belong to the authored seated poses.
      }
      final scale = adult * prop.heightInAdults / atlas.nativeHeight(reference);
      // A hanging plant's measured pivot is its top cord; depth still belongs
      // to the pot below it, rather than the elevated attachment point.
      final propGround = prop.kind == PartyPropKind.plant
          ? ui.Offset(projected.x, projected.y - adult * prop.heightInAdults)
          : _point(projected);
      draws.add(
        _WorldDraw(prop.id, projected.y, 0, (canvas) {
          atlas.draw(canvas, frame, propGround, scale);
        }),
      );
      if (prop.kind == PartyPropKind.table) {
        final candle = _propFrame('candle', i, beat);
        final candleGround = ui.Offset(
          projected.x,
          projected.y - adult * prop.heightInAdults * .92,
        );
        draws.add(
          _WorldDraw('${prop.id}-candle', projected.y, 1, (canvas) {
            life.draw(
              canvas,
              candle,
              candleGround,
              adult * .16 / life.nativeHeight('candle_a'),
            );
          }),
        );
      }
    }
  }

  void _addLife(
    List<_WorldDraw> draws,
    PartyViewport viewport,
    PartyRoomLayout room,
    double beat,
  ) {
    final life = _ensemble!['life']!;
    final scenery = _level!.scenery;
    for (var i = 0; i < scenery.plants.length; i++) {
      final floor = scenery.plants[i];
      final projected = viewport.project(floor);
      final height = _adultHeight(viewport, room, floor) * .62;
      final frame = _propFrame('plant', i + 21, beat);
      draws.add(
        _WorldDraw('plant-$i', projected.y, 0, (canvas) {
          life.draw(
            canvas,
            frame,
            ui.Offset(projected.x, projected.y - height),
            height / life.nativeHeight('plant_a'),
          );
        }),
      );
    }
    final waiter = scenery.waiter;
    if (waiter == null) return;
    final waiterX = reducedMotion
        ? waiter.home.x
        : waiter.home.x + waiter.swayX * math.sin(_foregroundSeconds * .11);
    final floor = PartyPoint(waiterX, waiter.home.y);
    final projected = viewport.project(floor);
    final height = _adultHeight(viewport, room, floor);
    final frame = _propFrame('waiter', 4, beat);
    draws.add(
      _WorldDraw('waiter', projected.y, 10, (canvas) {
        _shadow(canvas, _point(projected), height);
        life.draw(
          canvas,
          frame,
          _point(projected),
          height / life.nativeHeight('waiter_a'),
        );
      }),
    );
  }

  void _drawLampGlows(ui.Canvas canvas, PartyViewport viewport) {
    // Centers measured against the painted lamps, under the same cover crop.
    final sources = _level!.scenery.lamps;
    for (var i = 0; i < sources.length; i++) {
      final center = _point(viewport.project(sources[i]));
      final gain = partyAmbientAt(
        _foregroundSeconds,
        instance: i,
        reducedMotion: reducedMotion,
      ).lightGain;
      const radius = 2.0;
      canvas.drawCircle(
        center,
        radius,
        ui.Paint()
          ..shader = ui.Gradient.radial(center, radius, [
            const ui.Color(0xffffce83).withValues(alpha: .045 * gain),
            const ui.Color(0x00ffce83),
          ]),
      );
    }
  }

  void _addChallenger(
    List<_WorldDraw> draws,
    PartyViewport viewport,
    PartyRoomLayout room,
    ChallengerPose pose,
  ) {
    final challengers = _level!.stage.challengers;
    final beat = _lastBeat;
    final duet = challengers.length > 1;
    final placements = <_DancerPlacement>[];
    for (final (i, challenger) in challengers.indexed) {
      var dressed = i == 0
          ? pose
          : _challengerAt(beat, dancer: challenger.atlas);
      // Calm camera keeps the pair on their marks; yielding still moves them.
      var floor = challenger.floorAt(
        dressed.floorYield,
        beat: reducedMotion ? 0 : beat,
      );
      var mirrored = false;
      DuetRole? role;
      final placed = _duetPlace(i, challenger.atlas, dressed, beat);
      if (placed != null) {
        floor = placed.floor;
        mirrored = placed.mirrored;
        role = placed.role;
        dressed = placed.frame == null ? dressed : dressed.withFrame(placed.frame!);
      }
      final projected = viewport.project(floor);
      final height = _adultHeight(
        viewport,
        room,
        floor,
        stature: challenger.stature,
      );
      final atlas = _ensemble![challenger.atlas]!;
      final scale = height / atlas.nativeHeight('ready');
      placements.add(
        _DancerPlacement(
          atlas: atlas,
          frame: dressed.frameId,
          ground: ui.Offset(
            projected.x + dressed.rootOffsetX * scale,
            projected.y,
          ),
          footY: projected.y,
          height: height,
          scale: scale,
          mirrored: mirrored,
          role: role,
        ),
      );
    }
    _joinHands(placements, viewport, room, beat);
    for (final dancer in placements) {
      draws.add(
        _WorldDraw('challenger', dancer.footY, 10, (canvas) {
          _shadow(canvas, dancer.ground, dancer.height);
          // Dancers who travel in depth scale smoothly, or their pixels crawl.
          dancer.atlas.draw(
            canvas,
            dancer.frame,
            dancer.ground,
            dancer.scale,
            flipX: dancer.mirrored,
            filter: duet ? ui.FilterQuality.low : ui.FilterQuality.none,
          );
        }),
      );
    }
  }

  /// Closes whatever gap depth and drawing leave, so held hands meet on screen.
  /// Only where each stands is drawn differently: nothing here reads back.
  void _joinHands(
    List<_DancerPlacement> dancers,
    PartyViewport viewport,
    PartyRoomLayout room,
    double beat,
  ) {
    if (dancers.length != 2) return;
    final [a, b] = dancers;
    if (a.role == DuetRole.pair && b.role == DuetRole.pair) {
      final (handA, handB) = (a.hand, b.hand);
      if (handA == null || handB == null) return;
      final half = (handB - handA) / 2;
      a.ground += half;
      b.ground -= half;
      return;
    }
    final turning = _heroSpinNow(beat);
    if (turning == null) return;
    final held = _heroHandDuring(turning, viewport, room);
    final dancer = dancers[turning.spin.dancer];
    final hand = dancer.hand;
    if (held != null && hand != null && dancer.role == DuetRole.spinning) {
      dancer.ground += held - hand;
    }
  }

  /// The spin in progress, or null. Reads the music's beat and the beat the last
  /// flourish landed on, nothing else; calm camera has no spin.
  DuetSpin? _spinNow(double beat) {
    final duet = _level!.stage.duet;
    final s = session;
    if (duet == null ||
        s == null ||
        reducedMotion ||
        s.phase == GardenPhase.cleared ||
        (beat >= _resetBeat && beat - _resetBeat < 2)) {
      return null;
    }
    return duet.spinFrom(
      flourishBeat: flourishBeat,
      beat: beat,
      callStartBeat: s.callStartBeat,
      introBeats: s.chart.introBeats,
      callBeats: s.chart.callBeats,
    );
  }

  /// Mācron's drawing while he is turning, or null when he isn't.
  ({DuetSpin spin, String frame, bool flip})? _heroSpinNow(double beat) {
    final spin = _spinNow(beat);
    if (spin == null) return null;
    final t = beat - session!.callStartBeat;
    if (!spin.isTurning(t)) return null;
    final spec = _level!.stage.duet!.spin;
    final index = ((t - spin.from) / spec.beats * spec.heroFrames.length).floor();
    return (
      spin: spin,
      frame: spec.heroFrames[index.clamp(0, spec.heroFrames.length - 1)],
      flip: spin.floor.x > _level!.stage.heroHome.x,
    );
  }

  /// Where his held hand is. He stays home through a spin.
  ui.Offset? _heroHandDuring(
    ({DuetSpin spin, String frame, bool flip}) turning,
    PartyViewport viewport,
    PartyRoomLayout room,
  ) {
    final floor = _level!.stage.heroFloor(entrance: 1, retreat: 0);
    final projected = viewport.project(floor);
    final height = _adultHeight(viewport, room, floor, stature: .35);
    final reference = _heroAtlas!.definition.frames['front_idle']!;
    final scale = height / (reference.source.height / reference.pixelsPerUnit);
    return _heroAtlas!.definition.frames[turning.frame]?.holdAt(
      _point(projected),
      scale,
      flipX: turning.flip,
    );
  }

  /// A pair's place and drawing from the level's floor pattern, or null when the
  /// level has none. Reads the beat and the pose only: art can't move the music.
  ({PartyPoint floor, String? frame, bool mirrored, DuetRole? role})? _duetPlace(
    int dancer,
    String atlas,
    ChallengerPose pose,
    double beat,
  ) {
    final level = _level!;
    final duet = level.stage.duet;
    final s = session;
    if (duet == null || s == null) return null;
    final chart = s.chart;
    final heroX = level.stage.heroHome.x;
    if (s.phase == GardenPhase.cleared) {
      final won = s.completedAtBeat ?? beat;
      final wins = _duetWinFloors(duet, s, won);
      final onLeft = dancer == 0 ? !wins.mirrored : wins.mirrored;
      final out = duet.exitSample(
        onLeft: onLeft,
        from: dancer == 0 ? wins.first : wins.second,
        e: exitBeat ?? 0,
        reducedMotion: reducedMotion,
      );
      return (
        floor: out.floor,
        frame: out.reaching ? duet.exit.reachFrame : null,
        mirrored: out.mirrored,
        role: null,
      );
    }
    final turn = duet.turnIndex(
      s.callStartBeat,
      chart.introBeats,
      chart.cycleBeats,
    );
    // Once the win is decided they hold there until the shot takes them to the
    // sides, so the walk out starts from where they are seen to be.
    final place = duet.sample(
      dancer: dancer,
      turn: turn,
      t: (s.completedAtBeat ?? beat) - s.callStartBeat,
      callBeats: chart.callBeats,
      floorYield: pose.floorYield,
      heroX: heroX,
      spin: s.completedAtBeat == null ? _spinNow(beat) : null,
      reducedMotion: reducedMotion,
    );
    final grammar = _grammar!;
    final telling =
        pose.state == ChallengerDanceState.approve ||
        pose.state == ChallengerDanceState.recover;
    final String? frame = switch (place.role) {
      DuetRole.pair when s.phase == GardenPhase.ready || telling => null,
      DuetRole.pair => duet.pairFrame(
        onLeft: place.onLeft,
        limb: pose.limb,
        phase: pose.movePhase,
        beat: reducedMotion ? 0 : beat,
      ),
      DuetRole.partner when pose.state != ChallengerDanceState.watch => null,
      DuetRole.partner =>
        reducedMotion ? null : grammar.clipFrame(atlas, duet.partnerClip, beat),
      DuetRole.spinning => duet.spin.reachFrame,
      DuetRole.offTurn when s.phase == GardenPhase.ready => null,
      DuetRole.offTurn =>
        reducedMotion
            ? grammar.calmFrame(atlas)
            : grammar.clipFrame(atlas, duet.offClip, beat),
      // The phrase's approval or recovery still reads, on the way back.
      DuetRole.incoming when telling => null,
      DuetRole.incoming => grammar.clipAlong(atlas, 'return_in', place.travel),
    };
    final held = place.role == DuetRole.pair && telling;
    return (
      floor: place.floor,
      frame: frame,
      mirrored: held ? false : place.mirrored,
      role: place.role,
    );
  }

  ({PartyPoint first, PartyPoint second, bool mirrored}) _duetWinFloors(
    LevelDuet duet,
    GardenSession s,
    double won,
  ) {
    final chart = s.chart;
    final turn = duet.turnIndex(
      s.callStartBeat,
      chart.introBeats,
      chart.cycleBeats,
    );
    PartyPoint at(int dancer) => duet.floorAtWin(
      dancer: dancer,
      turn: turn,
      t: won - s.callStartBeat,
      callBeats: chart.callBeats,
      heroX: _level!.stage.heroHome.x,
    );
    final first = at(0);
    final second = at(1);
    return (
      first: first,
      second: second,
      mirrored: LevelDuet.closeupMirrored(first.x, second.x),
    );
  }

  void _addHero(
    List<_WorldDraw> draws,
    PartyViewport viewport,
    PartyRoomLayout room,
    double beat,
    ChallengerPose challenger,
  ) {
    final s = session;
    final entrance = s?.phase == GardenPhase.intro
        ? (beat / s!.chart.introBeats).clamp(0.0, 1.0)
        : 1.0;
    final resetAge = beat - _resetBeat;
    final retreat = resetAge >= 0 && resetAge < 2
        ? math.sin(resetAge / 2 * math.pi)
        : 0.0;
    final level = _level!;
    final departure = level.route.sample(
      exitTravel,
      reducedMotion: reducedMotion,
    );
    final shot = level.exitShot;
    final shotBeat = exitBeat;
    var floor = exitTravel > 0
        ? level.heroExitFloor(departure)
        : level.stage.heroFloor(entrance: entrance, retreat: retreat);
    // Off his turn he steps back from home; he walks in straight to that spot.
    final watchSpot = level.stage.heroWatch;
    var callAge = s == null ? 0.0 : beat - s.callStartBeat;
    // A spin that overflowed into the call: he finishes it at home, then steps out.
    final duetSpin = level.stage.duet?.spin;
    if (duetSpin != null && s != null && !reducedMotion && flourishBeat < s.callStartBeat) {
      final heldUntil = flourishBeat + duetSpin.beats - s.callStartBeat;
      if (heldUntil > 0 && callAge < heldUntil + HeroWatch.stepOutBeats) {
        callAge = math.max(0, callAge - heldUntil);
      }
    }
    final firstCall = s != null && s.callStartBeat <= s.chart.introBeats;
    final inCall = s?.phase == GardenPhase.call && !reducedMotion;
    final watching = reducedMotion || exitTravel > 0
        ? 0.0
        : s?.phase == GardenPhase.intro
        ? entrance
        : inCall
        ? HeroWatch.at(callAge, s!.chart.callBeats, firstCall: firstCall)
        : 0.0;
    final watchWalking =
        inCall &&
        HeroWatch.walking(callAge, s!.chart.callBeats, firstCall: firstCall);
    final home = level.stage.heroFloor(entrance: 1, retreat: 0);
    floor = PartyPoint(
      floor.x + (watchSpot.x - home.x) * watching,
      floor.y + (watchSpot.y - home.y) * watching,
    );
    var shotWalking = false;
    if (shot != null && s?.phase == GardenPhase.cleared) {
      final step = shotBeat == null ? 0.0 : shot.stepAt(shotBeat);
      // The cinematic is the way out, so he stays on this step afterwards.
      floor = PartyPoint(
        home.x + (shot.heroStep.dx - home.x) * step,
        home.y + (shot.heroStep.dy - home.y) * step,
      );
      shotWalking = shotBeat != null && shot.walkingAt(shotBeat);
    }
    final projected = viewport.project(floor);
    final height = _adultHeight(viewport, room, floor, stature: .35);
    final reference = _heroAtlas!.definition.frames['front_idle']!;
    final scale = height / (reference.source.height / reference.pixelsPerUnit);
    final stumbleAge = beat - (s?.lastStumbleBeat ?? -100);
    var frame = heroSpriteFrame(
      beat: beat,
      phaseBeat: s?.phaseBeat ?? 0,
      front:
          s?.phase == GardenPhase.response || s?.phase == GardenPhase.cleared,
      walking:
          s?.phase == GardenPhase.intro ||
          exitTravel > 0 ||
          retreat > 0 ||
          shotWalking ||
          watchWalking,
      sideOn: exitTravel > 0 && departure.facing == DepartureFacing.sideRight,
      reducedMotion: reducedMotion,
      action: action,
      actionAge: beat - actionBeat,
      flourishAge: beat - flourishBeat,
      stumbling: stumbleAge >= 0 && stumbleAge < 1.5,
    );
    var hop = 0.0;
    if (shot != null &&
        s?.phase == GardenPhase.cleared &&
        exitTravel == 0 &&
        !shotWalking &&
        beat - flourishBeat >= 1) {
      if (shotBeat == null || shotBeat < shot.celebrateUntil) {
        final party = Celebration.at(
          beat - (s!.completedAtBeat ?? beat),
          reducedMotion: reducedMotion,
        );
        frame = party.frame;
        hop = party.hop;
      } else if (shotBeat >= shot.closeupTo) {
        // Back from the close-up, dancing out the music's cool-down.
        final party = Celebration.at(
          shotBeat - shot.closeupTo + Celebration.grooveBeat,
          reducedMotion: reducedMotion,
        );
        frame = party.frame;
        hop = party.hop;
      } else {
        // Waiting for the close-up: facing the challenger for a fist, by default.
        frame = shot.heroWaitFrame;
      }
    }
    if (inCall &&
        !watchWalking &&
        retreat == 0 &&
        beat - actionBeat > 1 &&
        beat - flourishBeat > 1 &&
        stumbleAge >= 1.5) {
      final time = HeroWatch.tapAlong(beat, s!.transport.tierAt(beat));
      frame = time.frame;
      hop = time.hop;
    }
    var activeMove =
        action != null && beat - actionBeat >= 0 && beat - actionBeat < .65;
    if (action != null &&
        actionTargetBeat != null &&
        (actionBeat >= flourishBeat || beat - flourishBeat >= 1)) {
      final move = playerMovePose(
        limb: action!,
        acceptedBeat: actionBeat,
        targetBeat: actionTargetBeat!,
        beat: beat,
        nextRequiredBeat: nextRequiredBeat,
      );
      if (move.phase != DanceMovePhase.idle) {
        frame = move.frameId;
        activeMove = true;
      }
    }
    if (s != null && s.phase == GardenPhase.response && !s.progress.cleared) {
      final responseEnd = s.callStartBeat + s.chart.cycleBeats;
      final lastRequired =
          s.callStartBeat + s.chart.callBeats + s.activeOffsets.last;
      final handoverStart = math.max(lastRequired + .65, responseEnd - 1);
      if (handoverStart < responseEnd) {
        frame =
            ensembleHeroHandoverFrame(
              role: challenger.playerRole,
              responseProgress:
                  (beat - handoverStart) / (responseEnd - handoverStart),
              activeMove: activeMove,
              activeFlourish:
                  beat - flourishBeat >= 0 && beat - flourishBeat < 1,
              reducedMotion: reducedMotion,
            ) ??
            frame;
      }
    }
    // Turning under her hand. It plays over his moves for its length: the taps
    // and their marks carry on below, untouched, and nothing here reads back.
    final turning = _heroSpinNow(beat);
    if (turning != null) {
      frame = turning.frame;
      hop = 0;
    }
    draws.add(
      _WorldDraw('macron', projected.y, 10, (canvas) {
        _shadow(canvas, _point(projected), height * (1 - hop * .5));
        _heroAtlas!.draw(
          canvas,
          frame,
          _point(projected).translate(0, -height * hop),
          scale,
          flipX: turning?.flip ?? false,
          // His art is far larger than he is drawn: mipmaps keep it steady.
          filter: ui.FilterQuality.medium,
        );
      }),
    );
  }
}

/// One dancer of a pair, placed for this frame, before her hand is joined.
class _DancerPlacement {
  _DancerPlacement({
    required this.atlas,
    required this.frame,
    required this.ground,
    required this.footY,
    required this.height,
    required this.scale,
    required this.mirrored,
    required this.role,
  });
  final EnsembleAtlas atlas;
  final String frame;
  ui.Offset ground;
  final double footY, height, scale;
  final bool mirrored;
  final DuetRole? role;

  ui.Offset? get hand => atlas.definition.art.frames[frame]?.holdAt(
    ground,
    scale,
    flipX: atlas.definition.flipFor(frame, facingFlip: mirrored),
  );
}
