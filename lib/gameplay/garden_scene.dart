import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'challenger_choreography.dart';
import 'dance_grammar.dart';
import 'ensemble_sprites.dart';
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
      for (final dancer in const ['gatekeeper', 'bartender']) {
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
    }
    final generation = ++_roomGeneration;
    final loaded = await images.load(level.background);
    if (generation != _roomGeneration) return;
    _level = level;
    _background = loaded;
    presentationBeat = null;
    exitCodaBeat = null;
    warmDown = 0;
    _resetBeat = -10;
    exitTravel = 0;
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

  ChallengerPose _challengerAt(double beat) {
    final s = session;
    if (s == null) {
      return _grammar!.dress(
        const ChallengerPose(
          frameId: 'occupied',
          state: ChallengerDanceState.occupied,
        ),
        dancer: _level!.stage.challengers.first.atlas,
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
    final pose = _choreography!.sample(
      beat: beat,
      callStartBeat: s.callStartBeat,
      started: s.phase != GardenPhase.ready,
      reducedMotion: reducedMotion,
      outcomeBeat: outcomeBeat,
      passed: passed,
      cleared: cleared,
    );
    return _grammar!.dress(
      pose,
      dancer: _level!.stage.challengers.first.atlas,
      beat: beat,
      callStartBeat: s.callStartBeat,
      callBeats: s.chart.callBeats,
      tier: s.transport.sections.isEmpty ? 0 : s.transport.tierAt(beat),
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
    _addFurniture(draws, viewport, room);
    _addGuests(draws, viewport, room, beat);
    _addLife(draws, viewport, room);
    final challenger = _challengerAt(beat);
    _addChallenger(draws, viewport, room, challenger);
    _addHero(draws, viewport, room, beat, challenger);
    draws.sort((a, b) => compareEnsembleDepth(a.order, b.order));
    for (final draw in draws) {
      draw.draw(canvas);
    }
    canvas.restore();
    super.render(canvas);
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

  void _addFurniture(
    List<_WorldDraw> draws,
    PartyViewport viewport,
    PartyRoomLayout room,
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
          frame = ensembleAmbientFrame(
            'umbrella',
            _foregroundSeconds,
            instance: i,
            reducedMotion: reducedMotion,
          );
        case PartyPropKind.plant:
          atlas = life;
          reference = 'plant_a';
          frame = ensembleAmbientFrame(
            'plant',
            _foregroundSeconds,
            instance: i,
            reducedMotion: reducedMotion,
          );
        case PartyPropKind.candle:
          atlas = life;
          reference = 'candle_a';
          frame = ensembleAmbientFrame(
            'candle',
            _foregroundSeconds,
            instance: i,
            reducedMotion: reducedMotion,
          );
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
        final candle = ensembleAmbientFrame(
          'candle',
          _foregroundSeconds,
          instance: i,
          reducedMotion: reducedMotion,
        );
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
  ) {
    final life = _ensemble!['life']!;
    final scenery = _level!.scenery;
    for (var i = 0; i < scenery.plants.length; i++) {
      final floor = scenery.plants[i];
      final projected = viewport.project(floor);
      final height = _adultHeight(viewport, room, floor) * .62;
      final frame = ensembleAmbientFrame(
        'plant',
        _foregroundSeconds,
        instance: i + 21,
        reducedMotion: reducedMotion,
      );
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
    final frame = ensembleAmbientFrame(
      'waiter',
      _foregroundSeconds,
      instance: 4,
      reducedMotion: reducedMotion,
    );
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
    // Levels may name several challengers; the scene draws the first for now.
    final challenger = _level!.stage.challengers.first;
    final floor = challenger.floorAt(pose.floorYield);
    final projected = viewport.project(floor);
    final height = _adultHeight(viewport, room, floor);
    final atlas = _ensemble![challenger.atlas]!;
    final scale = height / atlas.nativeHeight('ready');
    final ground = ui.Offset(
      projected.x + pose.rootOffsetX * scale,
      projected.y,
    );
    draws.add(
      _WorldDraw('challenger', projected.y, 10, (canvas) {
        _shadow(canvas, ground, height);
        atlas.draw(canvas, pose.frameId, ground, scale);
      }),
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
    final floor = exitTravel > 0
        ? level.heroExitFloor(departure)
        : level.stage.heroFloor(entrance: entrance, retreat: retreat);
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
      walking: s?.phase == GardenPhase.intro || exitTravel > 0 || retreat > 0,
      sideOn: exitTravel > 0 && departure.facing == DepartureFacing.sideRight,
      reducedMotion: reducedMotion,
      action: action,
      actionAge: beat - actionBeat,
      flourishAge: beat - flourishBeat,
      stumbling: stumbleAge >= 0 && stumbleAge < 1.5,
    );
    if (challenger.playerRole == PlayerDanceRole.ready &&
        s?.phase == GardenPhase.call &&
        beat - actionBeat > 1 &&
        beat - flourishBeat > 1) {
      frame = challenger.floorYield < .5 ? 'rear_turn' : 'profile';
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
    draws.add(
      _WorldDraw('macron', projected.y, 10, (canvas) {
        _shadow(canvas, _point(projected), height);
        _heroAtlas!.draw(canvas, frame, _point(projected), scale);
      }),
    );
  }
}
