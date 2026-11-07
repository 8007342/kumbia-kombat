import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'band.dart';
import 'challenger_choreography.dart';
import 'dance_floor.dart';
import 'dance_grammar.dart';
import 'duet_staging.dart';
import 'ensemble_sprites.dart';
import 'exit_shot.dart';
import 'garden_session.dart';
import 'gesture_shapes.dart';
import 'level_definition.dart';
import 'outfit_palette.dart';
import 'party_layout.dart';
import 'party_sprites.dart';
import 'party_up.dart';
import 'progression.dart';
import 'rhythm.dart';
import 'room_departure.dart';
import 'room_dissolve.dart';
import 'room_layers.dart';

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
  RoomDissolve? _dissolve;
  bool presentationPaused = false;
  Limb? action;
  double actionBeat = -10;
  double? actionTargetBeat;
  double? nextRequiredBeat;

  /// The other limb when the latest press finished a pair: he dances both.
  Limb? actionPartner;
  double flourishBeat = -10;

  /// Which move the flourish is, so what he does matches what the thumb drew.
  GestureKind flourishMove = GestureKind.spin;
  Limb flourishLimb = Limb.rightHand;
  double exitTravel = 0;
  double? presentationBeat;
  double? exitCodaBeat;

  /// Beats since the success score began, running on through the bridge.
  double? exitBeat;
  double warmDown = 0;
  String? artLoadError;
  PartySpriteAtlas? _heroAtlas;
  Map<String, EnsembleAtlas>? _ensemble;
  Map<String, EnsembleAtlasDefinition>? _propSets;
  EnsembleAtlas? _props;
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
  PartyUp _partyUp = PartyUp();
  GardenSession? _partyUpSession;
  BandEnergy _bandEnergy = BandEnergy();

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
      final propSets = jsonDecode(
        await rootBundle.loadString('assets/art/props/manifest.json'),
      ) as Map<String, dynamic>;
      _propSets = {
        for (final entry in (propSets['sets'] as Map).entries)
          entry.key as String: EnsembleAtlasDefinition.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      };
      _outfits = await OutfitPalette.load();
      await showLevel(await firstLevel());
    } catch (error) {
      artLoadError = 'Party character art could not load. Refresh to retry.';
      throw StateError('$artLoadError $error');
    }
  }

  /// Challenger animation comes exclusively from the ensemble atlas.
  Future<void> showLevel(LevelDefinition level, {bool dissolve = false}) async {
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
          duet.exit.danceClip,
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
      final away = challenger.facingAway;
      if (away != null) {
        _ensemble![challenger.atlas]!.definition.art.requireFrames(away.frames);
      }
    }
    for (final player in level.scenery.band?.players ?? const <BandPlayer>[]) {
      final atlas = _ensemble![player.atlas];
      if (atlas == null) {
        throw StateError('Level ${level.id} names unknown atlas ${player.atlas}');
      }
      atlas.definition.art.requireFrames(player.frames);
    }
    final dance = level.floorDance;
    if (dance != null) {
      for (final atlas in const ['guest0', 'guest1', 'guest2']) {
        _ensemble![atlas]!.definition.art.requireFrames(dance.frames);
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
    final propSet = level.propSet == null ? null : _propSets![level.propSet];
    if (level.propSet != null && propSet == null) {
      throw StateError(
        'Level ${level.id} names unknown props ${level.propSet}',
      );
    }
    final propImage = propSet == null
        ? null
        : await images.load('props/${propSet.art.image}');
    if (generation != _roomGeneration) return;
    if (dissolve) _startDissolve();
    _props = propSet == null ? null : EnsembleAtlas(propSet, propImage!);
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
    actionPartner = null;
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
      final fading = _dissolve;
      if (fading != null) {
        fading.elapsed += dt;
        if (fading.done) {
          fading.dispose();
          _dissolve = null;
        }
      }
    }
  }

  /// Keeps the frame on screen now, to clear away over the room about to load.
  void _startDissolve() {
    if (size.x <= 0 || size.y <= 0 || _level == null) return;
    final scale = math.min(
      ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1,
      2.0,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(scale);
    render(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (size.x * scale).ceil(),
      (size.y * scale).ceil(),
    );
    picture.dispose();
    _dissolve?.dispose();
    _dissolve = RoomDissolve(image, scale: scale);
  }

  @override
  void onRemove() {
    _dissolve?.dispose();
    _dissolve = null;
    _outfits?.dispose();
    super.onRemove();
  }

  void dance(
    Limb limb, {
    double? targetBeat,
    double? nextRequiredBeat,
    Limb? partner,
  }) {
    action = limb;
    actionPartner = partner;
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
    _renderRoom(canvas);
    super.render(canvas);
    _dissolve?.render(canvas, size.x, size.y, reducedMotion: reducedMotion);
  }

  void _renderRoom(ui.Canvas canvas) {
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
    _followTier(beat);
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

    _drawLampGlows(canvas, viewport, beat);
    final draws = <_WorldDraw>[];
    _addFurniture(draws, viewport, room, beat);
    _addGuests(draws, viewport, room, beat);
    _addLife(draws, viewport, room, beat);
    _addBand(draws, viewport, room, beat);
    final challenger = _challengerAt(beat);
    _addChallenger(draws, viewport, room, challenger);
    _addHero(draws, viewport, room, beat, challenger);
    draws.sort((a, b) => compareEnsembleDepth(a.order, b.order));
    final occluders = _level!.scenery.occluders;
    final hiding = [
      for (final occluder in occluders)
        (
          viewport.project(PartyPoint(0, occluder.frontY)).y,
          ui.Path()
            ..fillType = ui.PathFillType.evenOdd
            ..addRect(bounds)
            ..addPolygon([
              for (final point in occluder.outline)
                _point(viewport.project(point)),
            ], true),
        ),
    ];
    for (final draw in draws) {
      final behind = hiding.where((h) => draw.floorY < h.$1);
      if (behind.isEmpty) {
        draw.draw(canvas);
        continue;
      }
      canvas.save();
      for (final (_, outside) in behind) {
        canvas.clipPath(outside, doAntiAlias: false);
      }
      draw.draw(canvas);
      canvas.restore();
    }
    _drawCloseup(canvas, bounds);
    canvas.restore();
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
      final size = ui.Size(
        art.width * place.actor.scale,
        art.height * place.actor.scale,
      );
      final unflip = mirror && place.actor.keepsReading;
      if (unflip) {
        canvas.save();
        canvas.translate((origin.dx + size.width / 2) * 2, 0);
        canvas.scale(-1, 1);
      }
      canvas.drawImageRect(
        art,
        ui.Rect.fromLTWH(0, 0, art.width.toDouble(), art.height.toDouble()),
        origin & size,
        paint,
      );
      if (unflip) canvas.restore();
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
    final dance = _level!.floorDance;
    for (final slot in room.guests) {
      if (slot.onFloor && dance != null) {
        _addFloorGuest(draws, viewport, room, slot, dance, beat);
        continue;
      }
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

  /// Someone already on the dance floor. They make way when the fight starts and
  /// answer the player like everyone else, but on their feet, and they stay on
  /// them: at a win they keep dancing until the room dissolves.
  void _addFloorGuest(
    List<_WorldDraw> draws,
    PartyViewport viewport,
    PartyRoomLayout room,
    PartyGuestSlot slot,
    FloorDance dance,
    double beat,
  ) {
    final parting = slot.partTo == null ? null : dance.parting;
    final place = floorGuestAt(
      slot,
      parting?.along(beat, slot.partDelay, reducedMotion: reducedMotion) ?? 0,
    );
    final projected = room.projectSlot(viewport, slot, at: place);
    final index = slot.interestIndex!;
    final danceBeat = parting?.danceBeat(beat, slot.partDelay) ?? beat;
    final snapshot = session?.crowd.guest(index, beat);
    final pose = snapshot == null
        ? (
            frame: dance.ownThing.at(index * .371, reducedMotion: reducedMotion),
            facesIn: false,
          )
        : floorGuestPose(
            snapshot,
            dance,
            danceBeat: danceBeat,
            reducedMotion: reducedMotion,
          );
    final atlas =
        _ensemble!['guest${snapshot?.archetypeIndex ?? slot.archetype}']!;
    final scale = projected.spriteScale(atlas.nativeHeight('standing_idle_a'));
    final ground = _point(projected.floor);
    final palette =
        OutfitColor.values[(snapshot?.paletteIndex ?? slot.paletteIndex) %
            OutfitColor.values.length];
    final facesRight = pose.facesIn ? slot.facingRight : !slot.facingRight;
    draws.add(
      _WorldDraw(slot.id, projected.floor.y, 10, (canvas) {
        _shadow(canvas, ground, projected.standingHeight);
        atlas.draw(
          canvas,
          pose.frame,
          ground,
          scale,
          flipX: !facesRight,
          outfits: _outfits,
          palette: palette,
        );
      }),
    );
  }

  /// The band on their platform, livened by whatever each rung of their ladder
  /// listens to. Reads the beat and those numbers, and only picks drawings.
  void _addBand(
    List<_WorldDraw> draws,
    PartyViewport viewport,
    PartyRoomLayout room,
    double beat,
  ) {
    final band = _level!.scenery.band;
    if (band == null) return;
    final lift = _level!.scenery.platform?.lift ?? 0;
    final s = session;
    for (final player in band.players) {
      final atlas = _ensemble![player.atlas]!;
      final floor = viewport.project(player.at);
      final height = _adultHeight(
        viewport,
        room,
        player.at,
        stature: player.stature,
      );
      final ground = ui.Offset(floor.x, floor.y - height * lift);
      final frame = player.frameAt(
        beat,
        (bar) => BandInputs(
          form: _bandEnergy.at(bar),
          tier: _partyUp.tier,
          partySwing: _partySwing(bar),
        ),
        beatsPerBar: s?.transport.score.beatsPerBar ?? 4,
        reducedMotion: reducedMotion,
      );
      final palette = player.palette;
      draws.add(
        _WorldDraw('band-${player.id}', floor.y, 10, (canvas) {
          _shadow(canvas, ground, height);
          atlas.draw(
            canvas,
            frame,
            ground,
            height / atlas.nativeHeight(player.reference),
            flipX: player.flipX,
            outfits: palette == null ? null : _outfits,
            palette: palette == null
                ? null
                : OutfitColor.values[palette % OutfitColor.values.length],
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
        life: _life(prop.kind, beat, prop.instance),
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

  /// The room wakes with the music's tier, for every player. A new session starts
  /// a new room near still; a won room holds as it is and cools with [warmDown].
  void _followTier(double beat) {
    final s = session;
    if (s == null || _level == null) return;
    if (!identical(_partyUpSession, s)) {
      _partyUpSession = s;
      _partyUp = PartyUp.forLevel(
        cycleBeats: s.chart.cycleBeats,
        successesPerTier: _level!.rules.successesPerTier,
      );
      _bandEnergy = BandEnergy();
    }
    final hold = s.phase == GardenPhase.cleared || s.transport.sections.isEmpty;
    _partyUp.follow(beat, hold ? _partyUp.tier : s.transport.tierAt(beat));
    if (_level!.scenery.band != null) {
      _bandEnergy.follow(beat, s.crowd.recentForm);
    }
  }

  double _life(PartyLifeKind kind, double beat, int instance) =>
      _partyUp.life(kind, beat, instance: instance) * (1 - warmDown);

  /// Drift in the room's first tier, as a share of the drawn movement.
  static const _nearStillRange = .34;

  double _driftRange(double life) =>
      _nearStillRange + (1 - _nearStillRange) * life;

  String _propFrame(String kind, int instance, double beat) {
    final life = _life(switch (kind) {
      'umbrella' => PartyLifeKind.umbrella,
      'plant' => PartyLifeKind.plant,
      'candle' => PartyLifeKind.flame,
      _ => PartyLifeKind.staff,
    }, beat, instance);
    return ensemblePartyFrame(
      kind,
      _foregroundSeconds,
      beat: beat,
      swing: _partySwing(beat),
      instance: instance,
      reducedMotion: reducedMotion,
      range: _driftRange(life),
      onBeat: kind == 'candle' ? life * .5 : 0,
    );
  }

  void _addFurniture(
    List<_WorldDraw> draws,
    PartyViewport viewport,
    PartyRoomLayout room,
    double beat,
  ) {
    final baked = _props;
    final furniture = baked ?? _ensemble!['furniture']!;
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
        case PartyPropKind.stool:
          final owner = room.guests
              .where((g) => g.homePropId == prop.id)
              .firstOrNull;
          if (owner?.chairIncluded == true) continue;
          atlas = baked ?? furniture;
          frame = 'stool';
          reference = frame;
        case PartyPropKind.table:
          atlas = furniture;
          // The baked sets draw two tables, so a room isn't one table repeated.
          frame = baked == null ? 'table' : (i.isEven ? 'table_a' : 'table_b');
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
        // A prop set that bakes a drink dances it at full swing.
        if (baked != null && baked.definition.art.frames.containsKey('cup_2')) {
          final cup = tableCupFrame(
            beat: beat,
            swing: _partySwing(beat),
            instance: i,
            reducedMotion: reducedMotion,
          );
          final cupGround = ui.Offset(
            projected.x + adult * (i.isEven ? .11 : -.11),
            // The table's drawing is taller than its top, by the drinks on it.
            projected.y - adult * prop.heightInAdults * .72,
          );
          draws.add(
            _WorldDraw('${prop.id}-cup', projected.y, 2, (canvas) {
              baked.draw(
                canvas,
                cup,
                cupGround,
                adult * .2 / baked.nativeHeight('cup_2'),
              );
            }),
          );
        }
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
        : waiter.home.x +
              waiter.swayX *
                  _driftRange(_life(PartyLifeKind.staff, beat, 4)) *
                  math.sin(_foregroundSeconds * .11);
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

  /// Soft light drifting over the walls. It wakes with the music's tier, on every
  /// run, and under reduced motion it stays put and only brightens.
  void _drawWallLight(ui.Canvas canvas, PartyViewport viewport, double beat) {
    final light = _level!.scenery.wallLight;
    if (light == null) return;
    final life = _life(PartyLifeKind.light, beat, 0);
    if (life <= 0) return;
    final phase = reducedMotion ? .25 : (beat / light.periodBeats) % 1;
    for (final (i, zone) in light.zones.indexed) {
      final points = [for (final p in zone) viewport.project(p)];
      final path = ui.Path()..moveTo(points.first.x, points.first.y);
      for (final p in points.skip(1)) {
        path.lineTo(p.x, p.y);
      }
      path.close();
      final box = path.getBounds();
      final sweep = math.sin(2 * math.pi * (phase + i * .37));
      final centre = ui.Offset(
        box.center.dx + sweep * box.width * .35,
        box.center.dy + math.cos(2 * math.pi * (phase + i * .37)) * box.height * .2,
      );
      final radius = box.longestSide * .55;
      canvas.save();
      canvas.clipPath(path);
      canvas.drawCircle(
        centre,
        radius,
        ui.Paint()
          ..shader = ui.Gradient.radial(centre, radius, [
            const ui.Color(0xff9ec8ff).withValues(alpha: .34 * life),
            const ui.Color(0x00b08cff),
          ]),
      );
      canvas.restore();
    }
  }

  void _drawLampGlows(ui.Canvas canvas, PartyViewport viewport, double beat) {
    _drawWallLight(canvas, viewport, beat);
    // The whole room warms from above, ending before the tap band, with no moving
    // edge: for a room with no layers yet, this and the lamps are most of its life.
    final warmth = _life(PartyLifeKind.light, beat, 0);
    if (warmth > 0) {
      final bounds = ui.Rect.fromLTWH(
        0,
        0,
        PartyViewport.logicalWidth,
        viewport.logicalHeight * roomLayerTapBandTop,
      );
      canvas.drawRect(
        bounds,
        ui.Paint()
          ..blendMode = ui.BlendMode.softLight
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFB45E).withValues(alpha: .4 * warmth),
              const Color(0x00FFB45E),
            ],
          ).createShader(bounds),
      );
    }
    // Centers measured against the painted lamps, under the same cover crop.
    final sources = _level!.scenery.lamps;
    for (var i = 0; i < sources.length; i++) {
      final center = _point(viewport.project(sources[i]));
      final gain = partyAmbientAt(
        _foregroundSeconds,
        instance: i,
        reducedMotion: reducedMotion,
      ).lightGain;
      final life = _life(PartyLifeKind.light, beat, i);
      // Breathes over a bar once awake: never a flash. Brightness alone under
      // reduced motion, so the room is still the meter there.
      final breath = reducedMotion
          ? 1.0
          : 1 + .12 * life * math.cos(2 * math.pi * beat / 4);
      final radius = 2.0 + 10 * life;
      canvas.drawCircle(
        center,
        radius,
        ui.Paint()
          ..shader = ui.Gradient.radial(center, radius, [
            const ui.Color(
              0xffffce83,
            ).withValues(alpha: (.045 + .3 * life) * gain * breath),
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
      // Mācron walks over for the shot, and a lone dancer comes in to meet him.
      final shot = _level!.exitShot;
      final meet = challenger.meetMark;
      if (meet != null &&
          shot != null &&
          session?.phase == GardenPhase.cleared) {
        final at = exitBeat == null ? 0.0 : shot.stepAt(exitBeat!);
        floor = PartyPoint(
          floor.x + (meet.x - floor.x) * at,
          floor.y + (meet.y - floor.y) * at,
        );
      }
      final s = session;
      if (s == null || s.phase == GardenPhase.ready || s.phase == GardenPhase.intro) {
        final away = challenger.facingAway?.frameAt(
          beat,
          _level!.chart.introBeats,
          reducedMotion: reducedMotion,
        );
        if (away != null) dressed = dressed.withFrame(away);
      }
      var mirrored = false;
      DuetRole? role;
      final placed = _duetPlace(i, challenger.atlas, dressed, beat);
      if (placed != null) {
        floor = placed.floor;
        mirrored = placed.mirrored;
        role = placed.role;
        dressed = placed.frame == null
            ? dressed
            : dressed.withFrame(placed.frame!);
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
    final index = ((t - spin.from) / spec.beats * spec.heroFrames.length)
        .floor();
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
  ({PartyPoint floor, String? frame, bool mirrored, DuetRole? role})?
  _duetPlace(int dancer, String atlas, ChallengerPose pose, double beat) {
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
        closeupTo: level.exitShot?.closeupTo ?? double.infinity,
        reducedMotion: reducedMotion,
      );
      return (
        floor: out.floor,
        frame: out.reaching
            ? duet.exit.reachFrame
            : out.dancing
            ? _grammar!.clipFrame(atlas, duet.exit.danceClip, beat)
            : null,
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
        partner: pose.partnerLimb,
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
    final entersAt = _level!.stage.heroEntersAt;
    final entrance = s?.phase == GardenPhase.intro
        ? ((beat - entersAt) / (s!.chart.introBeats - entersAt)).clamp(0.0, 1.0)
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
    // Off his turn he leaves the floor, back and then to the side, and comes home
    // the same way. He walks in straight to where he waits. Reduced motion cuts
    // to each place, so the floor still belongs to one dancer at a time.
    var callAge = s == null ? 0.0 : beat - s.callStartBeat;
    // A spin that overflowed into the call: he finishes it at home, then steps out.
    final duetSpin = level.stage.duet?.spin;
    if (duetSpin != null &&
        s != null &&
        !reducedMotion &&
        flourishBeat < s.callStartBeat) {
      final heldUntil = flourishBeat + duetSpin.beats - s.callStartBeat;
      if (heldUntil > 0 && callAge < heldUntil + HeroWatch.stepOutBeats) {
        callAge = math.max(0, callAge - heldUntil);
      }
    }
    final firstCall = s != null && s.callStartBeat <= s.chart.introBeats;
    final inCall = s?.phase == GardenPhase.call && !reducedMotion;
    final home = level.stage.heroFloor(entrance: 1, retreat: 0);
    final off = exitTravel > 0
        ? home
        : s?.phase == GardenPhase.intro
        ? PartyPoint(
            home.x + (level.stage.heroAside.x - home.x) * entrance,
            home.y + (level.stage.heroAside.y - home.y) * entrance,
          )
        : s?.phase == GardenPhase.call
        ? level.stage.heroDuringCall(
            callAge,
            s!.chart.callBeats,
            firstCall: firstCall,
            reducedMotion: reducedMotion,
          )
        : home;
    final watchWalking =
        inCall &&
        HeroWatch.walking(callAge, s!.chart.callBeats, firstCall: firstCall);
    floor = PartyPoint(floor.x + off.x - home.x, floor.y + off.y - home.y);
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
      flourishMove: flourishMove,
      flourishLimb: flourishLimb,
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
        partnerLimb: actionPartner,
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
